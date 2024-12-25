import 'package:flutter/material.dart';
import '../services/database_helper.dart';
import 'dart:io';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Map<String, dynamic>> _users = [];
  int _userCount = 0;
  Map<String, List<Map<String, dynamic>>> _userImages = {}; // Kullanıcı resimlerini saklamak için

  @override
  void initState() {
    super.initState();
    _fetchUsers();
    _fetchUserCount();
  }

  Future<void> _fetchUsers() async {
    final users = await _dbHelper.getAllUsers();
    setState(() {
      _users = users;
    });
  }

  Future<void> _fetchUserCount() async {
    final count = await _dbHelper.getUserCount();
    setState(() {
      _userCount = count;
    });
  }

  Future<void> _fetchImagesByUsername(String username) async {
    final images = await _dbHelper.getAllImagesByUsername(username);
    setState(() {
      _userImages[username] = images; // Kullanıcı resimlerini sakla
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
      ),
      body: _buildAdminPanel(),
    );
  }

  Widget _buildAdminPanel() {
    return Column(
      children: [
        const Text(
          'Admin Paneli',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        Text(
          'Toplam Kullanıcı Sayısı: $_userCount',
          style: const TextStyle(fontSize: 18),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: ListView.builder(
            itemCount: _users.length,
            itemBuilder: (context, index) {
              final username = _users[index]['username'];
              return ExpansionTile(
                title: Text(username),
                children: [
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: _dbHelper.getAllImagesByUsername(username),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      } else if (snapshot.hasError) {
                        return const Center(child: Text('Resimler yüklenemedi'));
                      } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const ListTile(title: Text('Resim yok'));
                      } else {
                        return Column(
                          children: snapshot.data!.map((imageData) {
                            return ListTile(
                              leading: Image.file(
                                File(imageData['image_path']),
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                              ),
                              title: Text('Resim: ${imageData['image_path']}'),
                            );
                          }).toList(),
                        );
                      }
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
} 