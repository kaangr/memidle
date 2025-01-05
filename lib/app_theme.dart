import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';


  // Thanks GPT!

class AppTheme {
  // Light mode renkleri
  static const Color primaryColorLight = Color(0xFF6C63FF);
  static const Color secondaryColorLight = Color(0xFF32D74B);
  static const Color accentColorLight = Color(0xFFFF6B6B);
  static const Color backgroundColorLight = Color(0xFFF8F9FA);
  static const Color surfaceColorLight = Colors.white;
  static const Color textPrimaryColorLight = Color(0xFF2D3436);
  static const Color textSecondaryColorLight = Color(0xFF636E72);

  // Dark mode renkleri
  static const Color primaryColorDark = Color(0xFF8B80FF);
  static const Color secondaryColorDark = Color(0xFF40E35B);
  static const Color accentColorDark = Color(0xFFFF8080);
  static const Color backgroundColorDark = Color(0xFF121212);
  static const Color surfaceColorDark = Color(0xFF1E1E1E);
  static const Color textPrimaryColorDark = Colors.white;
  static const Color textSecondaryColorDark = Color(0xFFB0B0B0);

  static ThemeData getTheme(bool isDarkMode) {
    return ThemeData(
      useMaterial3: true,
      brightness: isDarkMode ? Brightness.dark : Brightness.light,
      colorScheme: ColorScheme(
        brightness: isDarkMode ? Brightness.dark : Brightness.light,
        primary: isDarkMode ? primaryColorDark : primaryColorLight,
        secondary: isDarkMode ? secondaryColorDark : secondaryColorLight,
        surface: isDarkMode ? surfaceColorDark : surfaceColorLight,
        background: isDarkMode ? backgroundColorDark : backgroundColorLight,
        error: isDarkMode ? accentColorDark : accentColorLight,
        onPrimary: isDarkMode ? Colors.white : Colors.white,
        onSecondary: isDarkMode ? Colors.white : Colors.black,
        onSurface: isDarkMode ? textPrimaryColorDark : textPrimaryColorLight,
        onBackground: isDarkMode ? textPrimaryColorDark : textPrimaryColorLight,
        onError: Colors.white,
        onSurfaceVariant: isDarkMode ? textSecondaryColorDark : textSecondaryColorLight,
      ),
      
      scaffoldBackgroundColor: isDarkMode ? backgroundColorDark : backgroundColorLight,
      
      // App Bar teması
      appBarTheme: AppBarTheme(
        backgroundColor: isDarkMode ? surfaceColorDark : surfaceColorLight,
        foregroundColor: isDarkMode ? textPrimaryColorDark : textPrimaryColorLight,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.poppins(
          color: isDarkMode ? textPrimaryColorDark : textPrimaryColorLight,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(
          color: isDarkMode ? textPrimaryColorDark : textPrimaryColorLight,
        ),
      ),

      // Card teması
      cardTheme: CardTheme(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        color: surfaceColorLight,
      ),

      // Buton teması
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColorLight,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      // Text buton teması
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColorLight,
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      // Floating Action Button teması
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColorLight,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      // Input Decoration teması
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: backgroundColorLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: backgroundColorLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryColorLight),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        labelStyle: TextStyle(color: textSecondaryColorLight),
      ),

      // Genel metin teması
      textTheme: TextTheme(
        displayLarge: GoogleFonts.poppins(
          color: textPrimaryColorLight,
          fontSize: 32,
          fontWeight: FontWeight.bold,
        ),
        displayMedium: GoogleFonts.poppins(
          color: textPrimaryColorLight,
          fontSize: 28,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: GoogleFonts.poppins(
          color: textPrimaryColorLight,
          fontSize: 16,
        ),
        bodyMedium: GoogleFonts.poppins(
          color: textSecondaryColorLight,
          fontSize: 14,
        ),
      ),

      // Bottom Navigation Bar teması
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surfaceColorLight,
        selectedItemColor: primaryColorLight,
        unselectedItemColor: textSecondaryColorLight,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),

      // Drawer teması
      drawerTheme: DrawerThemeData(
        backgroundColor: isDarkMode ? surfaceColorDark : surfaceColorLight,
        scrimColor: isDarkMode ? Colors.black54 : Colors.black12,
      ),
    );
  }
} 