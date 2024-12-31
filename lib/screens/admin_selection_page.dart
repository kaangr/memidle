import 'dart:io';  // File için
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';  // getTemporaryDirectory için
import 'package:http/http.dart' as http;  // http.get için
import 'drawing_page.dart';

class AdminSelectionPage extends StatefulWidget {
  final String userId;  // int yerine String
  
  const AdminSelectionPage({super.key, required this.userId});

  @override
  State<AdminSelectionPage> createState() => _AdminSelectionPageState();
}

class _AdminSelectionPageState extends State<AdminSelectionPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Selection'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('memes')
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
            return const Center(child: Text('No memes available'));
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
              final memeData = meme.data() as Map<String, dynamic>;
              return _buildMemeCard(meme.id, memeData);
            },
          );
        },
      ),
    );
  }

  Widget _buildMemeCard(String memeId, Map<String, dynamic> memeData) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          CachedNetworkImage(
            imageUrl: memeData['imageUrl'],
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
            placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
            errorWidget: (context, url, error) => const Icon(Icons.error),
          ),
          Positioned(
            right: 4,
            top: 4,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.white),
                  onPressed: () => _editMeme(memeData['imageUrl']),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.white),
                  onPressed: () => _deleteMeme(memeId, memeData['imageUrl']),
                ),
              ],
            ),
          ),
          Positioned(
            left: 4,
            bottom: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Created by: ${memeData['userId']}',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editMeme(String imageUrl) async {
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

  Future<void> _deleteMeme(String memeId, String imageUrl) async {
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
      try {
        // Storage'dan resmi sil
        final storageRef = FirebaseStorage.instance.refFromURL(imageUrl);
        await storageRef.delete();

        // Firestore'dan meme dokümanını sil
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
} 