import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Kullanıcı işlemleri
  Future<UserCredential> registerUser(String username, String password, String email) async {
    try {
      // Önce username'in benzersiz olduğunu kontrol et
      final usernameCheck = await _firestore
          .collection('users')
          .where('username', isEqualTo: username)
          .get();

      if (usernameCheck.docs.isNotEmpty) {
        throw Exception('Username already exists');
      }

      // Email/password ile kayıt
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Firestore'a kullanıcı bilgilerini kaydet
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'username': username,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
        'dailyMemidle': null,
        'points': 0,
      });

      return userCredential;
    } catch (e) {
      print('Registration error: $e');
      rethrow;
    }
  }

  Future<UserCredential> signInWithEmailAndPassword(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Kullanıcı giriş yaptıktan sonra Firestore'da kullanıcı dokümanını kontrol et
      final userDoc = await _firestore.collection('users').doc(userCredential.user!.uid).get();
      
      // Eğer kullanıcı dokümanı yoksa oluştur
      if (!userDoc.exists) {
        final username = email.split('@')[0]; // Email'den username oluştur
        await _firestore.collection('users').doc(userCredential.user!.uid).set({
          'email': email,
          'username': username,
          'createdAt': FieldValue.serverTimestamp(),
          'dailyMemidle': null,
          'points': 0,
        });
      }

      return userCredential;
    } catch (e) {
      print('🔥 Login Error: $e');
      rethrow;
    }
  }

  // Meme işlemleri
  Future<String?> uploadMeme(File file) async {
    try {
      // Authentication kontrolü
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Token'ı yenile
      final idToken = await user.getIdToken(true);
      print('User ID Token refreshed: ${idToken != null}');
      print('Current User ID: ${user.uid}');

      final fileName = '${DateTime.now().millisecondsSinceEpoch}.png';
      final storagePath = 'memes/${user.uid}/$fileName';
      
      print('Starting upload to path: $storagePath');
      
      final storageRef = _storage.ref().child(storagePath);
      
      // Metadata ekle
      final metadata = SettableMetadata(
        contentType: 'image/png',
        customMetadata: {
          'userId': user.uid,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      
      // Upload işlemi
      print('Starting file upload...');
      final uploadTask = await storageRef.putFile(file, metadata);
      print('Upload completed. Getting download URL...');
      
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      print('Download URL obtained: $downloadUrl');
      
      return downloadUrl;
    } catch (e, stackTrace) {
      print('Upload error: $e');
      print('Stack trace: $stackTrace');
      rethrow; // Hatayı yukarı fırlat
    }
  }

  // Kullanıcı bilgilerini al
  Future<Map<String, dynamic>> getUserInfo(String userId) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(userId).get();
      return doc.data() as Map<String, dynamic>;
    } catch (e) {
      print('Get user info error: $e');
      rethrow;
    }
  }

  // Kullanıcının memelerini al
  Stream<QuerySnapshot> getUserMemes(String userId) {
    return _firestore
        .collection('memes')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Meme derecelendirme
  Future<void> rateMeme(String memeId, String userId, double rating) async {
    try {
      // Kullanıcının daha önce bu meme'i derecelendirip derecelendirmediğini kontrol et
      DocumentReference memeRef = _firestore.collection('memes').doc(memeId);
      DocumentReference ratingRef = _firestore
          .collection('memes')
          .doc(memeId)
          .collection('ratings')
          .doc(userId);

      await _firestore.runTransaction((transaction) async {
        DocumentSnapshot memeDoc = await transaction.get(memeRef);
        DocumentSnapshot ratingDoc = await transaction.get(ratingRef);

        if (!ratingDoc.exists) {
          // Yeni derecelendirme
          double currentAverage = (memeDoc.data() as Map<String, dynamic>)['averageRating'] ?? 0.0;
          int totalRatings = (memeDoc.data() as Map<String, dynamic>)['totalRatings'] ?? 0;

          double newAverage = ((currentAverage * totalRatings) + rating) / (totalRatings + 1);

          transaction.update(memeRef, {
            'averageRating': newAverage,
            'totalRatings': totalRatings + 1,
          });

          transaction.set(ratingRef, {
            'rating': rating,
            'timestamp': FieldValue.serverTimestamp(),
          });
        }
      });
    } catch (e) {
      print('Rate meme error: $e');
      rethrow;
    }
  }

  // Memidle kullanım kontrolü
  Future<bool> canUseMemidle(String userId) async {
    try {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(userId).get();
      Timestamp? lastMemidle = (userDoc.data() as Map<String, dynamic>)['dailyMemidle'];
      
      if (lastMemidle == null) return true;
      
      DateTime lastUse = lastMemidle.toDate();
      DateTime now = DateTime.now();
      
      return !_isSameDay(lastUse, now);
    } catch (e) {
      print('Check Memidle error: $e');
      return false;
    }
  }

  // Memidle kullanımı
  Future<void> useMemidle(String memeId, String userId) async {
    try {
      if (!await canUseMemidle(userId)) {
        throw Exception('Memidle already used today');
      }

      await _firestore.runTransaction((transaction) async {
        DocumentReference memeRef = _firestore.collection('memes').doc(memeId);
        DocumentReference userRef = _firestore.collection('users').doc(userId);

        // Meme'in puanını güncelle
        transaction.update(memeRef, {
          'memidleCount': FieldValue.increment(1),
          'totalPoints': FieldValue.increment(50),
        });

        // Kullanıcının Memidle kullanım zamanını güncelle
        transaction.update(userRef, {
          'dailyMemidle': FieldValue.serverTimestamp(),
          'points': FieldValue.increment(50),
        });
      });
    } catch (e) {
      print('Use Memidle error: $e');
      rethrow;
    }
  }

  // Yardımcı metod - aynı gün kontrolü
  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
  }

  // Username'den email bulma
  Future<String?> getEmailFromUsername(String username) async {
    try {
      final QuerySnapshot result = await _firestore
          .collection('users')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();

      if (result.docs.isNotEmpty) {
        return (result.docs.first.data() as Map<String, dynamic>)['email'] as String;
      }
      return null;
    } catch (e) {
      print('Error getting email from username: $e');
      return null;
    }
  }

  Future<void> deleteAccount(String userId) async {
    try {
      // Kullanıcının memelerini al
      final memes = await _firestore
          .collection('memes')
          .where('userId', isEqualTo: userId)
          .get();

      // Storage'dan resimleri sil
      for (var meme in memes.docs) {
        final memeData = meme.data();
        final imageUrl = memeData['imageUrl'] as String;
        final storageRef = FirebaseStorage.instance.refFromURL(imageUrl);
        await storageRef.delete();
      }

      // Firestore'dan memeleri sil
      for (var meme in memes.docs) {
        await meme.reference.delete();
      }

      // Kullanıcı dokümanını sil
      await _firestore.collection('users').doc(userId).delete();

      // Firebase Auth'dan kullanıcıyı sil
      await _auth.currentUser?.delete();
    } catch (e) {
      print('Delete account error: $e');
      rethrow;
    }
  }

  Future<void> saveMeme(String userId, String imageUrl) async {
    print('💾 Saving meme for user: $userId');
    try {
      // Önce kullanıcının var olduğunu kontrol edelim
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        print('❌ User document not found for ID: $userId');
        throw Exception('User not found');
      }

      // Meme'i kaydedelim
      final memeRef = await _firestore.collection('memes').add({
        'userId': userId,  // Gerçek kullanıcı ID'si
        'imageUrl': imageUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'totalRatings': 0,
        'averageRating': 0,
        'username': userDoc.data()?['username'] ?? 'Unknown', // Username'i de ekleyelim
      });

      print('✅ Meme saved successfully with ID: ${memeRef.id}');
      print('👤 Saved for user: ${userDoc.data()?['username']}');

    } catch (e) {
      print('❌ Error saving meme: $e');
      rethrow;
    }
  }
} 