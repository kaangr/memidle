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
import 'login_page.dart';

class HomePage extends StatefulWidget {
  final String userId;
  
  const HomePage({super.key, required this.userId});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirebaseService _firebaseService = FirebaseService();
  String? _selectedMemeId;
  bool _hasSelectedMeme = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(widget.userId)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              print('❌ Error loading user data: ${snapshot.error}');
              return const Text('My Meme Studio');
            }

            if (!snapshot.hasData) {
              return const Text('Loading...');
            }

            final userData = snapshot.data?.data() as Map<String, dynamic>?;
            final username = userData?['username'] ?? 'Unknown User';
            
            print('👤 Loaded user data: $username');

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('My Meme Studio'),
                Text(
                  'Welcome, $username!',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
            tooltip: 'Refresh',
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: _buildMemeGrid(),
      bottomNavigationBar: _hasSelectedMeme
          ? BottomAppBar(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Seçili meme\'i paylaş',
                      style: TextStyle(fontSize: 16),
                    ),
                    ElevatedButton.icon(
                      icon: Icon(Icons.public),
                      label: Text('Herkese Açık Paylaş'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.black,
                      ),
                      onPressed: () => _toggleMemeVisibility(_selectedMemeId!, false),
                    ),
                  ],
                ),
              ),
            )
          : null,
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
          const DrawerHeader(
            decoration: BoxDecoration(
              color: Colors.blue,
            ),
            child: Text(
              'Memidle',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                  (route) => false,
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.public),
            title: const Text('Social Feed'),
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
    print('🏠 Building meme grid for user: ${widget.userId}');
    
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('memes')
          .where('userId', isEqualTo: widget.userId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          print('❌ Home Page Error: ${snapshot.error}');
          return Center(
            child: Text('Bir hata oluştu: ${snapshot.error}'),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          print('⏳ Loading memes...');
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
          );
        }

        final memes = snapshot.data?.docs ?? [];
        print('📊 Found ${memes.length} memes for user');

        if (memes.isEmpty) {
          print('📭 No memes found for user');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.image_not_supported, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'Henüz meme oluşturmadınız',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DrawingPage(userId: widget.userId),
                    ),
                  ),
                  icon: Icon(Icons.add),
                  label: Text('Yeni Meme Oluştur'),
                ),
              ],
            ),
          );
        }

        print('🖼️ Rendering meme grid');
        return GridView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
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
    );
  }

  Widget _buildMemeCard(DocumentSnapshot meme) {
    final memeData = meme.data() as Map<String, dynamic>;
    final bool isPublic = memeData['isPublic'] ?? false;
    final bool isSelected = meme.id == _selectedMemeId;
    
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                if (isSelected) {
                  _selectedMemeId = null;
                  _hasSelectedMeme = false;
                } else {
                  _selectedMemeId = meme.id;
                  _hasSelectedMeme = true;
                }
              });
            },
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
                if (isSelected)
                  Container(
                    color: Colors.amber.withOpacity(0.3),
                    child: Center(
                      child: Icon(
                        Icons.check_circle,
                        color: Colors.amber,
                        size: 40,
                      ),
                    ),
                  ),
                Positioned(
                  right: 4,
                  top: 4,
                  child: Row(
                    children: [
                      if (isPublic)
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Public',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
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

  Future<void> _toggleMemeVisibility(String memeId, bool currentVisibility) async {
    try {
      await FirebaseFirestore.instance
          .collection('memes')
          .doc(memeId)
          .update({'isPublic': !currentVisibility});
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            !currentVisibility 
                ? 'Meme is now visible in Social Feed!' 
                : 'Meme is now private'
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating meme visibility: $e')),
      );
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