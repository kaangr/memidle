import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'drawing_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;

class SavedMemesPage extends StatefulWidget {
  final String userId;
  
  const SavedMemesPage({super.key, required this.userId});

  @override
  State<SavedMemesPage> createState() => _SavedMemesPageState();
}

class _SavedMemesPageState extends State<SavedMemesPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Memes'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('memes')
            .where('userId', isEqualTo: widget.userId)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          
          final memes = snapshot.data?.docs ?? [];
          
          if (memes.isEmpty) {
            return const Center(child: Text('No saved memes'));
          }
          
          return GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: memes.length,
            itemBuilder: (context, index) {
              final meme = memes[index];
              return _buildMemeCard(meme);
            },
          );
        },
      ),
    );
  }

  Widget _buildMemeCard(DocumentSnapshot meme) {
    final memeData = meme.data() as Map<String, dynamic>;
    final createdAt = (memeData['createdAt'] as Timestamp).toDate();
    
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          GestureDetector(
            onTap: () => _showMemePopup(memeData['imageUrl']),
            child: CachedNetworkImage(
              imageUrl: memeData['imageUrl'],
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
              placeholder: (context, url) => Center(child: CircularProgressIndicator()),
              errorWidget: (context, url, error) => Icon(Icons.error),
            ),
          ),
          Positioned(
            right: 4,
            top: 4,
            child: IconButton(
              icon: const Icon(Icons.delete, color: Colors.white),
              onPressed: () => _deleteMeme(meme.id),
            ),
          ),
          Positioned(
            left: 4,
            bottom: 4,
            child: Text(
              _formatDate(createdAt),
              style: const TextStyle(
                color: Colors.white,
                backgroundColor: Colors.black54,
                fontSize: 12,
              ),
            ),
          ),
          Positioned(
            right: 40,
            top: 4,
            child: IconButton(
              icon: const Icon(Icons.share, color: Colors.white),
              onPressed: () => _shareMeme(memeData['imageUrl']),
            ),
          ),
        ],
      ),
    );
  }

  void _showMemePopup(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Stack(
                alignment: Alignment.topRight,
                children: [
                  InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.contain,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      icon: Icon(Icons.edit),
                      label: Text('Edit'),
                      onPressed: () {
                        Navigator.of(context).pop();
                        _editMeme(imageUrl);
                      },
                    ),
                    ElevatedButton.icon(
                      icon: Icon(Icons.share),
                      label: Text('Share'),
                      onPressed: () {
                        Navigator.of(context).pop();
                        _shareMeme(imageUrl);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _editMeme(String imageUrl) async {
    try {
      // URL'den resmi indir
      final response = await http.get(Uri.parse(imageUrl));
      final bytes = response.bodyBytes;
      
      // Geçici dosya oluştur
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/temp_meme.png');
      await tempFile.writeAsBytes(bytes);

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DrawingPage(
              userId: widget.userId,
              selectedImage: tempFile,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading meme: $e')),
        );
      }
    }
  }

  Future<void> _shareMeme(String imageUrl) async {
    try {
      await Share.share(imageUrl, subject: 'Check out my meme!');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sharing meme: $e')),
      );
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _deleteMeme(String memeId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Meme'),
        content: const Text('Are you sure you want to delete this meme?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('memes')
          .doc(memeId)
          .delete();
      setState(() {});
    }
  }
}
