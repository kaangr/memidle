import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/firebase_service.dart';
import 'login_page.dart';

class ProfilePage extends StatelessWidget {
  final String userId;
  final FirebaseService _firebaseService = FirebaseService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  ProfilePage({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showSettingsDialog(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildUserInfo(),
            _buildUserStats(),
            _buildUserMemes(),
          ],
        ),
      ),
    );
  }

  Widget _buildUserInfo() {
    return FutureBuilder<DocumentSnapshot>(
      future: _firestore.collection('users').doc(userId).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return const Center(child: CircularProgressIndicator());
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>?;
        if (userData == null) return const SizedBox.shrink();

        return ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person)),
          title: Text(userData['username'] ?? 'User'),
          subtitle: Text(userData['email'] ?? ''),
        );
      },
    );
  }

  Widget _buildUserStats() {
    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('users').doc(userId).snapshots(),
      builder: (context, userSnapshot) {
        return StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('memes')
              .where('userId', isEqualTo: userId)
              .snapshots(),
          builder: (context, memesSnapshot) {
            if (!userSnapshot.hasData || !memesSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
            final memes = memesSnapshot.data!.docs;
            
            double totalRating = 0;
            int totalRatings = 0;

            for (var meme in memes) {
              final memeData = meme.data() as Map<String, dynamic>?;
              if (memeData == null) continue;

              final double avgRating = (memeData['averageRating'] as num?)?.toDouble() ?? 0.0;
              final int numRatings = (memeData['totalRatings'] as num?)?.toInt() ?? 0;
              
              totalRating += avgRating * numRatings;
              totalRatings += numRatings;
            }

            final averageRating = totalRatings > 0 ? totalRating / totalRatings : 0.0;
            final points = userData?['points'] ?? 0;

            return Card(
              margin: const EdgeInsets.all(8),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem('Memes', memes.length.toString()),
                    _buildStatItem('Points', points.toString()),
                    _buildStatItem('Avg Rating', averageRating.toStringAsFixed(1)),
                    _buildStatItem('Total Ratings', totalRatings.toString()),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(label),
      ],
    );
  }

  Widget _buildUserMemes() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('memes')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final memes = snapshot.data!.docs;
        if (memes.isEmpty) {
          return const Center(
            child: Text('Henüz meme paylaşmadınız'),
          );
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
          ),
          itemCount: memes.length,
          itemBuilder: (context, index) {
            final memeData = memes[index].data() as Map<String, dynamic>?;
            if (memeData == null) return const SizedBox.shrink();
            
            final String? imageUrl = memeData['imageUrl'] as String?;
            if (imageUrl == null || imageUrl.isEmpty) {
              return const SizedBox.shrink();
            }
            
            return CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              memCacheHeight: 300,
              placeholder: (context, url) => const Center(
                child: CircularProgressIndicator(),
              ),
              errorWidget: (context, url, error) => const Center(
                child: Icon(Icons.error, color: Colors.red),
              ),
            );
          },
        );
      },
    );
  }

  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('Delete Account'),
              onTap: () => _showDeleteAccountDialog(context),
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () async {
                await FirebaseAuth.instance.signOut();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                  (route) => false,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'Are you sure you want to delete your account? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await _firebaseService.deleteAccount(userId);
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                  (route) => false,
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error deleting account: $e')),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
} 