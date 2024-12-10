import 'dart:io';
import 'package:flutter/material.dart';
import '../services/database_helper.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_cropper/image_cropper.dart';
import 'home_page.dart';

class SavedMemesPage extends StatefulWidget {
  final int userId;
  
  const SavedMemesPage({super.key, required this.userId});

  @override
  State<SavedMemesPage> createState() => _SavedMemesPageState();
}

class _SavedMemesPageState extends State<SavedMemesPage> {
  final _dbHelper = DatabaseHelper();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Memes'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>( 
        future: _dbHelper.getUserMemes(widget.userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          
          final memes = snapshot.data ?? [];
          
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

  Widget _buildMemeCard(Map<String, dynamic> meme) {
    final file = File(meme['image_path']);
    final createdAt = DateTime.parse(meme['created_at']);
    
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          GestureDetector(
            onTap: () => _showMemePopup(file),
            child: Image.file(
              file,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            right: 4,
            top: 4,
            child: IconButton(
              icon: const Icon(Icons.delete, color: Colors.white),
              onPressed: () => _deleteMeme(meme['id']),
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
              onPressed: () => _shareMeme(file),
            ),
          ),
        ],
      ),
    );
  }

  void _showMemePopup(File memeFile) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.file(memeFile),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _editMeme(memeFile);
                },
                child: const Text('Edit Meme'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _editMeme(File memeFile) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HomePage(userId: widget.userId, selectedImage: memeFile),
      ),
    );
  }

  Future<void> _shareMeme(File memeFile) async {
    try {
      await Share.shareXFiles([XFile(memeFile.path)], text: 'Check out my meme!');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sharing meme: $e')),
      );
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _deleteMeme(int memeId) async {
    // Show confirmation dialog
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
      await _dbHelper.deleteMeme(memeId);
      setState(() {}); // Refresh the list
    }
  }
}
