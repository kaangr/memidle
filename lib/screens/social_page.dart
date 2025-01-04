import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:memidle_test/screens/profile_page.dart';
import '../services/firebase_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SocialPage extends StatefulWidget {
  final String userId;

  const SocialPage({Key? key, required this.userId}) : super(key: key);

  @override
  State<SocialPage> createState() => _SocialPageState();
}

class _SocialPageState extends State<SocialPage> {
  final FirebaseService _firebaseService = FirebaseService();
  final ScrollController _scrollController = ScrollController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Social Feed'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProfilePage(userId: widget.userId),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // Basit bir yenileme için kısa bir bekleme
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) {
            setState(() {});
          }
        },
        child: StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('memes')
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text('Bir şeyler yanlış gitti: ${snapshot.error}'),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final memes = snapshot.data?.docs ?? [];
            
            if (memes.isEmpty) {
              return const Center(
                child: Text('Henüz hiç meme paylaşılmamış'),
              );
            }

            return ListView.builder(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(), // RefreshIndicator için gerekli
              itemCount: memes.length,
              itemBuilder: (context, index) => _buildMemeCard(memes[index]),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMemeCard(DocumentSnapshot meme) {
    print('🎨 Building meme card');
    
    final memeData = meme.data() as Map<String, dynamic>?;
    if (memeData == null) {
      print('❌ Meme data is null');
      return const SizedBox.shrink();
    }
    
    print('👤 Getting user data for ID: ${memeData['userId']}');
    
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
        .collection('users')
        .doc(memeData['userId'])
        .snapshots(),
      builder: (context, userSnapshot) {
        if (userSnapshot.hasError) {
          print('❌ User data error: ${userSnapshot.error}');
          return const SizedBox.shrink();
        }

        if (!userSnapshot.hasData) {
          print('⏳ Loading user data...');
          return const Center(child: CircularProgressIndicator());
        }

        final userData = userSnapshot.data?.data() as Map<String, dynamic>?;
        if (userData == null) {
          print('⚠️ User data is null');
          return const SizedBox.shrink();
        }

        print('✅ User data loaded: ${userData['username']}');
        
        final isOwnMeme = memeData['userId'] == widget.userId;
        final String? imageUrl = memeData['imageUrl'] as String?;
        if (imageUrl == null) return const SizedBox.shrink();
        
        final Timestamp? createdAt = memeData['createdAt'] as Timestamp?;
        
        final username = userData?['username'] ?? 'Unknown User';
        final timeAgo = createdAt != null ? _formatTimestamp(createdAt) : '';
        
        return Card(
          margin: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                leading: CircleAvatar(
                  child: Text(username[0].toUpperCase()),
                ),
                title: Text(username),
                subtitle: Text(timeAgo),
              ),
              if (imageUrl.isNotEmpty)
                Container(
                  constraints: const BoxConstraints(
                    maxHeight: 400,
                  ),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.contain,
                    memCacheHeight: 800,
                    placeholder: (context, url) => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    errorWidget: (context, url, error) => const Center(
                      child: Icon(Icons.error, size: 48, color: Colors.red),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Rating: ${((memeData['averageRating'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(1)}/10',
                          style: const TextStyle(fontSize: 16),
                        ),
                        Text(
                          'Total Ratings: ${(memeData['totalRatings'] as num?)?.toInt() ?? 0}',
                          style: const TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                    if (memeData['userId'] != widget.userId) ...[  // Kendi meme'ini oylayamaz
                      IconButton(
                        icon: const Icon(Icons.star),
                        onPressed: () => _showRatingDialog(meme.id),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    final now = DateTime.now();
    final date = timestamp.toDate();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  void _showRatingDialog(String memeId) {
    int rating = 5;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rate this meme'),
        content: StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$rating/10'),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (int i = 1; i <= 10; i++)
                    InkWell(
                      onTap: () => setState(() => rating = i),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: rating >= i ? Colors.amber : Colors.grey[300],
                        ),
                        child: Text(
                          '$i',
                          style: TextStyle(
                            color: rating >= i ? Colors.white : Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await _firebaseService.rateMeme(memeId, widget.userId, rating.toDouble());
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Rating submitted successfully!')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error submitting rating: $e')),
                  );
                }
              }
            },
            child: const Text('Rate'),
          ),
        ],
      ),
    );
  }

  Future<void> _useMemidle(String memeId) async {
    try {
      await _firebaseService.useMemidle(memeId, widget.userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Memidle used! +50 points')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error using Memidle: $e')),
        );
      }
    }
  }

  void _showMemidleUsedMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('You can use Memidle once per day!')),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
} 