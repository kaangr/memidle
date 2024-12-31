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
    UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    await _firestore.collection('users').doc(userCredential.user!.uid).set({
      'username': username,
      'email': email,
      'createdAt': FieldValue.serverTimestamp(),
      'dailyMemidle': null, // Son Memidle kullanım tarihi
      'points': 0,
    });

    return userCredential;
  }

  Future<UserCredential> loginUser(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // Meme işlemleri
  Future<String> uploadMeme(File imageFile, String userId, List<Map<String, dynamic>> texts) async {
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
  }

  // Puanlama sistemi
  Future<void> rateMeme(String memeId, String userId, double rating) async {
    // Kullanıcının daha önce bu meme'i puanlayıp puanlamadığını kontrol et
    DocumentSnapshot ratingDoc = await _firestore
        .collection('ratings')
        .doc('${memeId}_${userId}')
        .get();

    if (!ratingDoc.exists) {
      await _firestore.runTransaction((transaction) async {
        DocumentSnapshot memeDoc = await transaction.get(_firestore.collection('memes').doc(memeId));
        
        double currentAvg = memeDoc.get('averageRating') ?? 0;
        int totalRatings = memeDoc.get('totalRatings') ?? 0;
        
        double newAvg = ((currentAvg * totalRatings) + rating) / (totalRatings + 1);
        
        transaction.set(_firestore.collection('ratings').doc('${memeId}_${userId}'), {
          'userId': userId,
          'memeId': memeId,
          'rating': rating,
          'createdAt': FieldValue.serverTimestamp(),
        });

        transaction.update(_firestore.collection('memes').doc(memeId), {
          'averageRating': newAvg,
          'totalRatings': totalRatings + 1,
        });
      });
    }
  }

  // Memidle sistemi
  Future<bool> canUseMemidle(String userId) async {
    DocumentSnapshot userDoc = await _firestore.collection('users').doc(userId).get();
    Timestamp? lastMemidle = userDoc.get('dailyMemidle');
    
    if (lastMemidle == null) return true;
    
    DateTime lastUse = lastMemidle.toDate();
    DateTime now = DateTime.now();
    
    return !DateTime(lastUse.year, lastUse.month, lastUse.day)
        .isAtSameMomentAs(DateTime(now.year, now.month, now.day));
  }

  Future<void> useMemidle(String memeId, String userId) async {
    if (await canUseMemidle(userId)) {
      await _firestore.runTransaction((transaction) async {
        DocumentReference memeRef = _firestore.collection('memes').doc(memeId);
        DocumentReference userRef = _firestore.collection('users').doc(userId);
        
        transaction.update(memeRef, {
          'totalPoints': FieldValue.increment(50),
          'memidleCount': FieldValue.increment(1),
        });
        
        transaction.update(userRef, {
          'dailyMemidle': FieldValue.serverTimestamp(),
        });
      });
    }
  }

  // Social feed
  Stream<QuerySnapshot> getMemesFeed() {
    return _firestore
        .collection('memes')
        .orderBy('createdAt', descending: true)
        .limit(10)
        .snapshots();
  }
} 