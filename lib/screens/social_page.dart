import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Social Feed'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firebaseService.getMemesFeed(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Something went wrong'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {});
            },
            child: ListView.builder(
              controller: _scrollController,
              itemCount: snapshot.data!.docs.length,
              itemBuilder: (context, index) {
                var meme = snapshot.data!.docs[index];
                return _buildMemeCard(meme);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildMemeCard(DocumentSnapshot meme) {
    return Card(
      margin: EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CachedNetworkImage(
            imageUrl: meme['imageUrl'],
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
                      'Rating: ${(meme['averageRating'] as num).toStringAsFixed(1)}/10',
                      style: TextStyle(fontSize: 16),
                    ),
                    Text(
                      'Total Ratings: ${meme['totalRatings']}',
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
                          icon: Icon(Icons.emoji_events,
                              color: canUse ? Colors.amber : Colors.grey),
                          onPressed: canUse
                              ? () => _useMemidle(meme.id)
                              : () => ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('You can use Memidle once per day!'))),
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
            onPressed: () {
              _firebaseService.rateMeme(memeId, widget.userId, rating);
              Navigator.pop(context);
            },
            child: Text('Rate'),
          ),
        ],
      ),
    );
  }

  Future<void> _useMemidle(String memeId) async {
    await _firebaseService.useMemidle(memeId, widget.userId);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Memidle used! +50 points')),
    );
  }
} 