import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/firebase_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

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
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('memes')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Something went wrong'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          final memes = snapshot.data?.docs ?? [];

          if (memes.isEmpty) {
            return Center(child: Text('No memes yet'));
          }

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {});
            },
            child: ListView.builder(
              controller: _scrollController,
              itemCount: memes.length,
              itemBuilder: (context, index) {
                var meme = memes[index];
                return _buildMemeCard(meme);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildMemeCard(DocumentSnapshot meme) {
    final memeData = meme.data() as Map<String, dynamic>;
    
    return Card(
      margin: EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FutureBuilder<DocumentSnapshot>(
            future: _firestore.collection('users').doc(memeData['userId']).get(),
            builder: (context, userSnapshot) {
              final username = userSnapshot.hasData 
                  ? (userSnapshot.data!.data() as Map<String, dynamic>)['username'] 
                  : 'User';
              return Padding(
                padding: EdgeInsets.all(8),
                child: Text(
                  'Created by: $username',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              );
            },
          ),
          CachedNetworkImage(
            imageUrl: memeData['imageUrl'],
            placeholder: (context, url) => Center(child: CircularProgressIndicator()),
            errorWidget: (context, url, error) => Icon(Icons.error),
          ),
          Padding(
            padding: EdgeInsets.all(8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rating: ${(memeData['averageRating'] as num).toStringAsFixed(1)}/10',
                      style: TextStyle(fontSize: 16),
                    ),
                    Text(
                      'Total Ratings: ${memeData['totalRatings']}',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.star_border),
                      onPressed: () => _showRatingDialog(meme.id),
                    ),
                    FutureBuilder<bool>(
                      future: _firebaseService.canUseMemidle(widget.userId),
                      builder: (context, snapshot) {
                        bool canUse = snapshot.data ?? false;
                        return IconButton(
                          icon: Icon(
                            Icons.emoji_events,
                            color: canUse ? Colors.amber : Colors.grey,
                          ),
                          onPressed: canUse
                              ? () => _useMemidle(meme.id)
                              : () => _showMemidleUsedMessage(),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showRatingDialog(String memeId) {
    double rating = 5.0;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Rate this meme'),
        content: StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${rating.toStringAsFixed(1)}/10'),
              Slider(
                value: rating,
                min: 0,
                max: 10,
                divisions: 20,
                onChanged: (value) {
                  setState(() => rating = value);
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await _firebaseService.rateMeme(memeId, widget.userId, rating);
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Rating submitted successfully!')),
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
            child: Text('Rate'),
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