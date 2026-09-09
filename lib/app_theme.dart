// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class VelzaTheme {
  // Brand Colors
  static const Color primaryViolet = Color(0xFF6A1B9A); // Deep Violet
  static const Color secondaryGold = Color(0xFFD4AF37); // Premium Gold
  
  static const Color darkBackground = Color(0xFF0E0B16); // Near Black
  static const Color darkCard = Color(0xFF1E162B); // Deep purple-gray
  
  static const Color lightBackground = Color(0xFFFAF6FE); // Soft Lavender-White
  static const Color lightCard = Color(0xFFFFFFFF);

  // Light Theme
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryViolet,
      colorScheme: const ColorScheme.light(
        primary: primaryViolet,
        secondary: secondaryGold,
        surface: lightCard,
        onPrimary: Colors.white,
        onSecondary: Colors.black,
        onSurface: Color(0xFF211330),
        outline: Color(0xFFD1C4E9),
      ),
      scaffoldBackgroundColor: lightBackground,
      textTheme: GoogleFonts.outfitTextTheme(ThemeData.light().textTheme).copyWith(
        titleLarge: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: const Color(0xFF211330)),
        bodyLarge: GoogleFonts.outfit(color: const Color(0xFF3E2723)),
      ),
      cardTheme: const CardThemeData(
        color: lightCard,
        elevation: 2,
        margin: EdgeInsets.all(8),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: lightBackground,
        foregroundColor: primaryViolet,
        elevation: 0,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryViolet,
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  // Dark Theme
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primaryViolet,
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFFBB86FC), // Lighter violet for dark mode
        secondary: secondaryGold,
        surface: darkCard,
        onPrimary: Colors.black,
        onSecondary: Colors.black,
        onSurface: Colors.white70,
        outline: Color(0xFF4A3E56),
      ),
      scaffoldBackgroundColor: darkBackground,
      textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme).copyWith(
        titleLarge: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
        bodyLarge: GoogleFonts.outfit(color: const Color(0xE6FFFFFF)),
      ),
      cardTheme: const CardThemeData(
        color: darkCard,
        elevation: 2,
        margin: EdgeInsets.all(8),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBackground,
        foregroundColor: Color(0xFFBB86FC),
        elevation: 0,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFBB86FC),
          foregroundColor: Colors.black,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}
