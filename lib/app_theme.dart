import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF16325B);
  static const Color secondaryColor = Color(0xFF227B94);
  static const Color accentColor = Color(0xFF78B7D0);
  static const Color backgroundColor = Color(0xFFFFDC7F);

  static ThemeData get theme {
    return ThemeData(
      primaryColor: primaryColor, 
      colorScheme: ColorScheme.light(
        primary: primaryColor,
        secondary: accentColor,
      ),
      scaffoldBackgroundColor: backgroundColor,
      appBarTheme: AppBarTheme(
        backgroundColor: primaryColor,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: secondaryColor),
        bodyMedium: TextStyle(color: secondaryColor),
      ),
      buttonTheme: ButtonThemeData(
        buttonColor: accentColor,
        textTheme: ButtonTextTheme.primary,
      ),
    );
  }
} 