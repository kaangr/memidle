import 'dart:io';
import 'package:flutter/material.dart';
import '../services/database_helper.dart';
import 'drawing_page.dart';
import 'saved_memes_page.dart';
import 'package:share_plus/share_plus.dart';
import 'template_selection_page.dart';
import 'social_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/firebase_service.dart';

class HomePage extends StatefulWidget {
  final String userId;
  
  const HomePage({super.key, required this.userId});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirebaseService _firebaseService = FirebaseService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Meme Studio'),
      ),
      drawer: _buildDrawer(),
      body: _buildMemeGrid(),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DrawingPage(userId: widget.userId),
            ),
          );
          if (result == true) {
            setState(() {});
          }
        },
        child: Icon(Icons.add),
        tooltip: 'Create New Meme',
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
            ),
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(widget.userId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  final userData = snapshot.data!.data() as Map<String, dynamic>;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 40,
                        child: Text(
                          userData['username'][0].toUpperCase(),
                          style: TextStyle(fontSize: 24),
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        userData['username'],
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  );
                }
                return CircularProgressIndicator();
              },
            ),
          ),
          ListTile(
            leading: Icon(Icons.settings),
            title: Text('Settings'),
            onTap: () {
              // Navigate to settings
            },
          ),
          ListTile(
            leading: Icon(Icons.exit_to_app),
            title: Text('Logout'),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushReplacementNamed(context, '/');
            },
          ),
          ListTile(
            leading: Icon(Icons.public),
            title: Text('Social Feed'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SocialPage(userId: widget.userId),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMemeGrid() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('memes')
          .where('userId', isEqualTo: widget.userId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Something went wrong'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        final memes = snapshot.data!.docs;

        if (memes.isEmpty) {
          return Center(
            child: SingleChildScrollView(
              physics: AlwaysScrollableScrollPhysics(),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.7,
                child: Center(
                  child: Text('No memes yet. Create your first meme!'),
                ),
              ),
            ),
          );
        }

        return GridView.builder(
          physics: AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(8),
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
    );
  }

  Widget _buildMemeCard(DocumentSnapshot meme) {
    final memeData = meme.data() as Map<String, dynamic>;
    
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          CachedNetworkImage(
            imageUrl: memeData['imageUrl'],
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
            placeholder: (context, url) => Center(child: CircularProgressIndicator()),
            errorWidget: (context, url, error) => Icon(Icons.error),
          ),
          Positioned(
            right: 4,
            top: 4,
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.share, color: Colors.white),
                  onPressed: () => _shareMeme(memeData),
                ),
                IconButton(
                  icon: Icon(Icons.delete, color: Colors.white),
                  onPressed: () => _deleteMeme(meme.id),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _shareMeme(Map<String, dynamic> meme) async {
    await Share.share(meme['imageUrl'], subject: 'Check out my meme!');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Meme shared successfully!')),
    );
  }

  Future<void> _deleteMeme(String memeId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Meme'),
        content: Text('Are you sure you want to delete this meme?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete'),
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

  void _selectTemplate() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TemplateSelectionPage(
          userId: widget.userId,
          onTemplateSelected: (File file) {},
        ),
      ),
    );
    setState(() {});
  }
}

class Achievement {
  final String title;
  final int points;
  final IconData icon;
  final bool isDaily;

  Achievement({
    required this.title,
    required this.points,
    required this.icon,
    required this.isDaily,
  });
} 