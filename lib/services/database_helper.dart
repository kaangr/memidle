





  //  databaselhelper daha öncesinde sqlite kullanılan versiyondan kalma bir dosya.Şuand kullanılmıyor.


import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'dart:convert';

class DatabaseMemeText {
  final String text;
  final Offset position;
  final double fontSize;
  final Color color;
  final double strokeWidth;
  final Color strokeColor;

  DatabaseMemeText({
    required this.text,
    required this.position,
    required this.fontSize,
    required this.color,
    this.strokeWidth = 0.0,
    this.strokeColor = Colors.black,
  });
}

class DatabaseHelper {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'user.db');

    print(path);
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users(
        userid INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE memes(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER,
        image_path TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        texts TEXT,
        FOREIGN KEY (user_id) REFERENCES users (userid)
      )
    ''');
  }

  Future<bool> registerUser(String username, String password) async {
    try {
      final db = await database;
      await db.insert('users', {
        'username': username,
        'password': password,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> loginUser(
      String username, String password) async {
    final db = await database;
    print('Attempting login with Username: $username, Password: $password');

    final List<Map<String, dynamic>> result = await db.query(
      'users',
      where: 'username = ? AND password = ?',
      whereArgs: [username, password],
    );

    print('Query result: $result');

    if (result.isNotEmpty) {
      return result.first;
    }
    return null;
  }

  Future<void> saveMeme(
      int userId, String imagePath, List<DatabaseMemeText> memeTexts) async {
    final db = await database;

    String textsJson = jsonEncode(memeTexts
        .map((text) => {
              'content': text.text,
              'position_x': text.position.dx,
              'position_y': text.position.dy,
              'font_size': text.fontSize,
              'color': text.color.value,
            })
        .toList());

    print('MemeTexts: $textsJson');

    await db.insert('memes', {
      'user_id': userId,
      'image_path': imagePath,
      'created_at': DateTime.now().toIso8601String(),
      'texts': textsJson,
    });
  }

  Future<List<Map<String, dynamic>>> getUserMemes(int userId) async {
    final db = await database;
    return await db.query(
      'memes',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );
  }

  Future<void> deleteMeme(int memeId) async {
    final db = await database;

    // meme
    final meme = await db.query(
      'memes',
      where: 'id = ?',
      whereArgs: [memeId],
    );

    if (meme.isNotEmpty) {
      // deleting
      final file = File(meme.first['image_path'] as String);
      if (await file.exists()) {
        await file.delete();
      }

      // database delete
      await db.delete(
        'memes',
        where: 'id = ?',
        whereArgs: [memeId],
      );
    }
  }

  Future<List<Map<String, dynamic>>> getAllUsers() async {
    final db = await database;
    return await db.query('users');
  }

  Future<int> getUserCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM users');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<List<Map<String, dynamic>>> getAllImagesByUsername(String username) async {
    final db = await database;
    return await db.query(
      'memes',
      where: 'user_id = (SELECT userid FROM users WHERE username = ?)',
      whereArgs: [username],
    );
  }

  Future<Map<String, dynamic>> getUserData(int userId) async {
    final db = await database;
    final result = await db.query(
      'users',
      where: 'userid = ?',
      whereArgs: [userId],
    );
    return result.first;
  }

  Future<Map<String, dynamic>> getUserInfo(int userId) async {
    final db = await database;
    final result = await db.query(
      'users',
      where: 'userid = ?',
      whereArgs: [userId],
    );
    return result.first;
  }

}
