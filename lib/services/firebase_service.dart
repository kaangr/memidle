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
  Future<void> rateMeme(String memeId, int rating, String userId) async {
    try {
      print('📊 Rating meme: $memeId with rating: $rating by user: $userId');
      final memeDoc = await _firestore.collection('memes').doc(memeId).get();
      final memeData = memeDoc.data();
      
      if (memeData == null) {
        throw Exception('Meme not found');
      }

      // Kendi meme'ini oylamamalı
      if (memeData['userId'] == userId) {
        throw Exception('You cannot rate your own meme');
      }

      // Kullanıcının daha önce bu meme'e oy verip vermediğini kontrol et
      final ratingDoc = await _firestore
          .collection('memes')
          .doc(memeId)
          .collection('ratings')
          .doc(userId)
          .get();

      if (ratingDoc.exists) {
        throw Exception('You have already rated this meme');
      }

      // Yeni rating'i kaydet
      await _firestore
          .collection('memes')
          .doc(memeId)
          .collection('ratings')
          .doc(userId)
          .set({
        'rating': rating,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Mevcut rating değerlerini al
      final currentTotalRatings = (memeData['totalRatings'] ?? 0) as int;
      double currentAverageRating;
      final rawAvgRating = memeData['averageRating'];
      if (rawAvgRating == null) {
        currentAverageRating = 0.0;
      } else if (rawAvgRating is int) {
        currentAverageRating = rawAvgRating.toDouble();
      } else {
        currentAverageRating = (rawAvgRating as num).toDouble();
      }

      // Yeni değerleri hesapla
      final newTotalRatings = currentTotalRatings + 1;
      final newAverageRating = ((currentAverageRating * currentTotalRatings) + rating) / newTotalRatings;

      // Meme'i güncelle
      await _firestore.collection('memes').doc(memeId).update({
        'totalRatings': newTotalRatings,
        'averageRating': newAverageRating,
      });

      print('✅ Rating saved successfully');
    } catch (e) {
      print('❌ Rate meme error: $e');
      rethrow;
    }
  }

  // Kullanıcının bir meme'e daha önce oy verip vermediğini kontrol et
  Future<bool> canRateMeme(String memeId, String userId) async {
    try {
      final memeDoc = await _firestore.collection('memes').doc(memeId).get();
      final memeData = memeDoc.data();
      
      if (memeData == null) return false;
      
      // Kendi meme'ini oylayamaz
      if (memeData['userId'] == userId) return false;

      // Daha önce oy verip vermediğini kontrol et
      final ratingDoc = await _firestore
          .collection('memes')
          .doc(memeId)
          .collection('ratings')
          .doc(userId)
          .get();

      return !ratingDoc.exists;
    } catch (e) {
      print('❌ Check can rate error: $e');
      return false;
    }
  }

  // Memidle puanı için yeni metod
  Future<bool> canGiveMemidle(String userId, String memeId) async {
    try {
      // Kendi meme'ini kontrol et
      final memeDoc = await _firestore.collection('memes').doc(memeId).get();
      final memeData = memeDoc.data();
      if (memeData?['userId'] == userId) {
        return false; // Kendi meme'ine puan veremez
      }

      // Günlük puanlama hakkını kontrol et
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data();
      
      final lastMemidleDate = userData?['lastMemidleDate']?.toDate();
      if (lastMemidleDate != null) {
        final lastDate = DateTime(
          lastMemidleDate.year,
          lastMemidleDate.month,
          lastMemidleDate.day,
        );
        if (lastDate.isAtSameMomentAs(today)) {
          return false; // Bugün zaten kullanmış
        }
      }
      
      return true;
    } catch (e) {
      print('❌ Check Memidle error: $e');
      return false;
    }
  }

  Future<void> giveMemidle(String userId, String memeId) async {
    try {
      // Meme sahibinin ID'sini al
      final memeDoc = await _firestore.collection('memes').doc(memeId).get();
      final memeOwnerId = memeDoc.data()?['userId'] as String;
      
      // Meme sahibine puan ekle
      final ownerDoc = await _firestore.collection('users').doc(memeOwnerId).get();
      final currentPoints = (ownerDoc.data()?['points'] ?? 0) as int;
      
      await _firestore.collection('users').doc(memeOwnerId).update({
        'points': currentPoints + 50,
      });
      
      // Puanlayan kullanıcının son Memidle tarihini güncelle
      await _firestore.collection('users').doc(userId).update({
        'lastMemidleDate': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('❌ Give Memidle error: $e');
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

  Future<void> saveMeme(String userId, String imageUrl, {bool isPublic = false}) async {
    print('💾 Saving meme for user: $userId');
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        print('❌ User document not found for ID: $userId');
        throw Exception('User not found');
      }

      // Meme'i kaydedelim
      final memeRef = await _firestore.collection('memes').add({
        'userId': userId,
        'imageUrl': imageUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'totalRatings': 0,
        'averageRating': 0.0,  // Double olarak başlat
        'username': userDoc.data()?['username'] ?? 'Unknown',
        'isPublic': isPublic,  // Yeni alan
        'totalMemidlePoints': 0,  // Yeni alan
        'memidleCount': 0,  // Yeni alan
      });

      print('✅ Meme saved successfully with ID: ${memeRef.id}');
    } catch (e) {
      print('❌ Error saving meme: $e');
      rethrow;
    }
  }
} 