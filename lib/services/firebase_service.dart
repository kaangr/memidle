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
      // Önce email/password ile kayıt
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Sonra Firestore'a kullanıcı bilgilerini kaydet
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

  Future<UserCredential> loginUser(String email, String password) async {
    try {
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
      String fileName = 'memes/$userId/${DateTime.now().millisecondsSinceEpoch}.png';
      Reference ref = _storage.ref().child(fileName);
      await ref.putFile(imageFile);
      String downloadUrl = await ref.getDownloadURL();

      DocumentReference memeRef = await _firestore.collection('memes').add({
        'userId': userId,
        'imageUrl': downloadUrl,
        'texts': texts,
        'createdAt': FieldValue.serverTimestamp(),
        'averageRating': 0,
        'totalRatings': 0,
        'totalPoints': 0,
        'memidleCount': 0,
      });

      return memeRef.id;
    } catch (e) {
      print('Upload meme error: $e');
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
} 