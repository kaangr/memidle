import 'package:flutter/material.dart';
import 'screens/login_page.dart';
import 'screens/home_page.dart';
import 'screens/admin_page.dart';
import 'app_theme.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Your App Title',
      theme: AppTheme.theme,
      initialRoute: '/',
      routes: {
        '/': (context) => LoginPage(), // Giriş sayfası
        '/home_page': (context) => HomePage(), // Ana sayfa
        '/admin_panel': (context) => AdminPage(), // Admin paneli
      },
    );
  }
}
