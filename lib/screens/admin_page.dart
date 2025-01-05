import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_storage/firebase_storage.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  int _userCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchUserCount();
  }

  Future<void> _fetchUserCount() async {
    final QuerySnapshot usersSnapshot = await _firestore.collection('users').get();
    setState(() {
      _userCount = usersSnapshot.size;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
      ),
      body: _buildAdminPanel(),
    );
  }

  Widget _buildAdminPanel() {
    return Column(
      children: [
        const Text(
          'Admin Paneli',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        Text(
          'Toplam Kullanıcı Sayısı: $_userCount',
          style: const TextStyle(fontSize: 18),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection('users').snapshots(),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (userSnapshot.hasError) {
                return Center(child: Text('Error: ${userSnapshot.error}'));
              }

              final users = userSnapshot.data?.docs ?? [];

              return ListView.builder(
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final userData = users[index].data() as Map<String, dynamic>;
                  final userId = users[index].id;
                  final username = userData['username'] as String;

                  return ExpansionTile(
                    title: Text(username),
                    children: [
                      StreamBuilder<QuerySnapshot>(
                        stream: _firestore
                            .collection('memes')
                            .where('userId', isEqualTo: userId)
                            .snapshots(),
                        builder: (context, memeSnapshot) {
                          if (memeSnapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }

                          if (memeSnapshot.hasError) {
                            return const Center(child: Text('Resimler yüklenemedi'));
                          }

                          final memes = memeSnapshot.data?.docs ?? [];

                          if (memes.isEmpty) {
                            return const ListTile(title: Text('Resim yok'));
                          }

                          return Column(
                            children: memes.map((meme) {
                              final memeData = meme.data() as Map<String, dynamic>;
                              return ListTile(
                                leading: CachedNetworkImage(
                                  imageUrl: memeData['imageUrl'],
                                  width: 50,
                                  height: 50,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => CircularProgressIndicator(),
                                  errorWidget: (context, url, error) => Icon(Icons.error),
                                ),
                                title: Text('Created: ${(memeData['createdAt'] as Timestamp).toDate().toString()}'),
                                trailing: IconButton(
                                  icon: Icon(Icons.delete),
                                  onPressed: () => _deleteMeme(meme.id),
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _deleteMeme(String memeId) async {
    try {
      // firestoredan meme bilgilerini al
      final memeDoc = await _firestore.collection('memes').doc(memeId).get();
      final memeData = memeDoc.data() as Map<String, dynamic>;
      final imageUrl = memeData['imageUrl'] as String;

      // Storage'dan resmi sil
      final storageRef = FirebaseStorage.instance.refFromURL(imageUrl);
      await storageRef.delete();

      // Firestore'dan memei sil
      await _firestore.collection('memes').doc(memeId).delete();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Meme deleted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting meme: $e')),
      );
    }
  }
} 