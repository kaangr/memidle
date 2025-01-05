import 'package:flutter/material.dart';
import '../services/database_helper.dart';
import 'home_page.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'dart:math';
import 'admin_page.dart';
import '../app_theme.dart' as MyTheme;
import 'register_page.dart';
import 'drawing_page.dart';
import '../services/firebase_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

final List<String> imagePaths = [
  'data/assets/images/memes/meme_1.jpeg',
  'data/assets/images/memes/meme_2.png',
  'data/assets/images/memes/meme_3.png',
  'data/assets/images/memes/meme_4.png',
  'data/assets/images/memes/meme_5.png',
  'data/assets/images/memes/meme_6.png',
  'data/assets/images/memes/meme_7.png',
  'data/assets/images/memes/meme_8.jpeg',
  'data/assets/images/memes/meme_9.jpg',
];

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameOrEmailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _dbHelper = DatabaseHelper();
  late AnimationController _controller;
  int _currentImageIndex = 0;
  final FirebaseService _firebaseService = FirebaseService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Debug için otomatik email ve şifre
    _usernameOrEmailController.text = "kaan.osmanoglou@gmail.com";
    _passwordController.text = "Kaan123";
    
    _controller = AnimationController(
      duration: const Duration(seconds: 5),
      vsync: this,
    )..repeat();

    // Her 5 saniyede bir resmi değiştir
    Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        setState(() {
          _currentImageIndex = (_currentImageIndex + 1) % imagePaths.length;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final cardSize = Size(300, 300); // Sabit card boyutu

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Memidle.',
          style: GoogleFonts.abrilFatface(
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Stack(
        children: [
        
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 32),
                  ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.secondary,
                        Theme.of(context).colorScheme.tertiary,
                      ],
                    ).createShader(bounds),
                    child: Text(
                      'Turn your imagination into a Meme.',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 60),
                  Text(
                    'Memidle.',
                    style: GoogleFonts.abrilFatface(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 48),
                  TextFormField(
                    controller: _usernameOrEmailController,
                    decoration: InputDecoration(
                      labelText: 'Username or Email',
                      filled: true,
                      fillColor: Theme.of(context).brightness == Brightness.dark 
                          ? Colors.grey[800] // Dark mode için koyu gri
                          : Colors.grey[100], // Light mode için açık gri
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      labelStyle: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter username or email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      filled: true,
                      fillColor: Theme.of(context).brightness == Brightness.dark 
                          ? Colors.grey[800] 
                          : Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      labelStyle: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter password';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _login,
                    child: const Text('Login'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const RegisterPage(),
                        ),
                      );
                    },
                    child: const Text('Create Account'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _login() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isLoading = true;
      });

      try {
        final userCredential = await _firebaseService.signInWithEmailAndPassword(
          _usernameOrEmailController.text.trim(),
          _passwordController.text,
        );

        if (!mounted) return;

        final user = userCredential.user;
        if (user != null) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => HomePage(userId: user.uid, isDarkMode: false, onThemeToggle: () {}),
            ),
          );
        } else {
          throw Exception('Login failed: User is null');
        }
      } catch (e) {
        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }


// sqlite tan kalma şuanda kullanılmıyor.
  Future<void> _register() async {
    if (_formKey.currentState!.validate()) {
      final success = await _dbHelper.registerUser(
        _usernameOrEmailController.text,
        _passwordController.text,
      );
      
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Registration successful')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Username already exists')),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _usernameOrEmailController.dispose();
    _passwordController.dispose();
    _controller.dispose();
    super.dispose();
  }
} 