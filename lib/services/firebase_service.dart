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

  Future<UserCredential> loginWithUsernameOrEmail(String usernameOrEmail, String password) async {
    try {
      String email = usernameOrEmail;
      
      // Eğer @ işareti yoksa, bu bir username'dir
      if (!usernameOrEmail.contains('@')) {
        final foundEmail = await getEmailFromUsername(usernameOrEmail);
        if (foundEmail == null) {
          throw Exception('Username not found');
        }
        email = foundEmail;
      }

      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      print('Login error: $e');
      rethrow;
    }
  }

  // Meme işlemleri
 Future<String> uploadMeme(File imageFile, String userId, List<Map<String, dynamic>> texts) async {
  try {
    print('Starting upload process...');
    print('User ID: $userId');
    
    // Dosya kontrolü
    if (!await imageFile.exists()) {
      throw Exception('Image file does not exist');
    }
    print('File exists at path: ${imageFile.path}');

    // Storage referansını oluştur
    final storageRef = FirebaseStorage.instance.ref();
    final userMemeRef = storageRef.child('memes/$userId');
    final fileName = DateTime.now().millisecondsSinceEpoch.toString() + '.png';
    final fileRef = userMemeRef.child(fileName);
    
    print('Storage path: memes/$userId/$fileName');

    // Metadata oluştur
    final metadata = SettableMetadata(
      contentType: 'image/png',
      customMetadata: {'userId': userId}
    );

    // Resmi yükle
    print('Starting file upload...');
    await fileRef.putFile(imageFile, metadata);
    print('Upload completed');

    // URL al
    final downloadUrl = await fileRef.getDownloadURL();
    print('Download URL: $downloadUrl');

    // Firestore'a kaydet
    final memeRef = await _firestore.collection('memes').add({
      'userId': userId,
      'imageUrl': downloadUrl,
      'texts': texts,
      'createdAt': FieldValue.serverTimestamp(),
      'averageRating': 0,
      'totalRatings': 0,
      'totalPoints': 0,
      'memidleCount': 0,
    });

    print('Meme saved to Firestore with ID: ${memeRef.id}');
    return memeRef.id;

  } catch (e, stackTrace) {
    print('Upload error: $e');
    print('Stack trace: $stackTrace');
    rethrow;
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
} 