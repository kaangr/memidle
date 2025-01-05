import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:memidle_test/screens/profile_page.dart';
import '../services/firebase_service.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

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
              .where('isPublic', isEqualTo: true)
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
    
    print(' Getting user data for ID: ${memeData['userId']}');
    
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
        .collection('users')
        .doc(memeData['userId'])
        .snapshots(),
      builder: (context, userSnapshot) {
        if (userSnapshot.hasError) {
          print(' User data error: ${userSnapshot.error}');
          return const SizedBox.shrink();
        }

        if (!userSnapshot.hasData) {
          print('Loading user data...');
          return const Center(child: CircularProgressIndicator());
        }

        final userData = userSnapshot.data?.data() as Map<String, dynamic>?;
        if (userData == null) {
          print('User data is null');
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
          color: Theme.of(context).colorScheme.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                leading: CircleAvatar(
                  child: Text(username[0].toUpperCase()),
                ),
                title: Text(
                  username,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  timeAgo,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Normal rating yıldızları
                  Row(
                    children: List.generate(5, (index) {
                      final isDark = Theme.of(context).brightness == Brightness.dark;
                      return IconButton(
                        icon: Icon(
                          index < (memeData['averageRating'] ?? 0).floor()
                              ? Icons.star
                              : Icons.star_border,
                          color: index < (memeData['averageRating'] ?? 0).floor()
                              ? Colors.amber
                              : isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                        onPressed: () => _firebaseService.rateMeme(meme.id, index + 1, widget.userId),
                      );
                    }),
                  ),
                  // Memidle butonu
                  FutureBuilder<bool>(
                    future: _firebaseService.canGiveMemidle(widget.userId, meme.id),
                    builder: (context, snapshot) {
                      final canGive = snapshot.data ?? false;
                      final isDark = Theme.of(context).brightness == Brightness.dark;
                      return Container(
                        decoration: BoxDecoration(
                          color: canGive 
                              ? Colors.amber.withOpacity(0.2)
                              : isDark ? Colors.grey[800] : Colors.grey[300],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: canGive
                                ? () => _giveMemidle(meme.id)
                                : () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('You can give one Memidle per day'),
                                      ),
                                    );
                                  },
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: Text(
                                'Memidle.',
                                style: GoogleFonts.abrilFatface(
                                  color: canGive 
                                      ? Colors.amber
                                      : isDark ? Colors.grey[400] : Colors.grey[700],
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
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

  void _showRatingDialog(String memeId) async {
    // Önce oy verip veremeyeceğini kontrol et
    final canRate = await _firebaseService.canRateMeme(memeId, widget.userId);
    
    if (!canRate) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You cannot rate this meme again or it\'s your own meme'),
          ),
        );
      }
      return;
    }

    int rating = 5;
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          'Rate this meme',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        content: StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$rating/10',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              ),
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
                          color: rating >= i 
                              ? Colors.amber 
                              : Theme.of(context).brightness == Brightness.dark
                                  ? Colors.grey[800]
                                  : Colors.grey[300],
                        ),
                        child: Text(
                          '$i',
                          style: TextStyle(
                            color: rating >= i 
                                ? Colors.white 
                                : Theme.of(context).colorScheme.onSurface,
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
                await _firebaseService.rateMeme(memeId, rating, widget.userId);
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
                    SnackBar(content: Text('Error: $e')),
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

  Future<void> _giveMemidle(String memeId) async {
    try {
      await _firebaseService.giveMemidle(widget.userId, memeId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Memidle points given! +50 points')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error giving Memidle: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
} 