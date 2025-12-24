import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // LIGHT THEME TOKENS
  static const Color _lightBg = Color(0xFFF8FAFC); // Slate 50
  static const Color _lightSurface = Colors.white; 
  static const Color _lightCard = Colors.white;
  static const Color _lightBorder = Color(0xFFE2E8F0); // Slate 200
  static const Color _lightPrimary = Color(0xFF1E3A8A); // Blue 900
  static const Color _lightSecondary = Color(0xFF3B82F6); // Blue 500
  static const Color _lightTextPrimary = Color(0xFF0F172A); // Slate 900
  static const Color _lightTextSecondary = Color(0xFF64748B); // Slate 500
  static const Color _lightError = Color(0xFFEF4444); // Red 500

  // DARK THEME TOKENS (Slate Palette)
  static const Color _darkBg = Color(0xFF020617); // Slate 950
  static const Color _darkSurface = Color(0xFF0F172A); // Slate 900
  static const Color _darkCard = Color(0xFF1E293B); // Slate 800
  static const Color _darkOverlay = Color(0xFF1E293B); // Slate 800 (Modal BG)
  static const Color _darkBorder = Color(0xFF334155); // Slate 700
  static const Color _darkPrimary = Color(0xFF3B82F6); // Blue 500
  static const Color _darkSecondary = Color(0xFF60A5FA); // Blue 400
  static const Color _darkTextPrimary = Color(0xFFF1F5F9); // Slate 100
  static const Color _darkTextSecondary = Color(0xFF94A3B8); // Slate 400
  static const Color _darkError = Color(0xFFF87171); // Red 400
  static const Color _darkSuccess = Color(0xFF22C55E); // Green 500 (Adjusted for dark)


  // LIGHT THEME
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: _lightPrimary,
    scaffoldBackgroundColor: _lightBg,
    
    colorScheme: const ColorScheme.light(
      primary: _lightPrimary,
      secondary: _lightSecondary,
      surface: _lightSurface,
      surfaceTint: Colors.white,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: _lightTextPrimary,
      error: _lightError,
      outline: _lightBorder,
    ),
    
    appBarTheme: const AppBarTheme(
      backgroundColor: _lightSurface,
      foregroundColor: _lightTextPrimary,
      elevation: 0,
      centerTitle: true,
      surfaceTintColor: Colors.transparent,
      iconTheme: IconThemeData(color: _lightTextSecondary),
      titleTextStyle: TextStyle(color: _lightTextPrimary, fontSize: 18, fontWeight: FontWeight.bold),
    ),

    cardTheme: CardThemeData(
      color: _lightCard,
      elevation: 0,
       shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: _lightBorder),
      ),
      margin: EdgeInsets.zero,
    ),

    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      minVerticalPadding: 16,
      iconColor: _lightTextSecondary,
      textColor: _lightTextPrimary,
      titleTextStyle: TextStyle(fontWeight: FontWeight.w500, fontSize: 16, color: _lightTextPrimary),
      subtitleTextStyle: TextStyle(fontSize: 14, color: _lightTextSecondary),
    ),
    
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
       backgroundColor: _lightSurface,
       selectedItemColor: _lightPrimary,
       unselectedItemColor: _lightTextSecondary,
       type: BottomNavigationBarType.fixed,
       elevation: 8,
       showSelectedLabels: true,
       showUnselectedLabels: true,
    ),
    
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _lightSurface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _lightBorder)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _lightBorder)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _lightPrimary, width: 2)),
      labelStyle: const TextStyle(color: _lightTextSecondary),
      hintStyle: const TextStyle(color: _lightTextSecondary),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: _lightBg,
      side: const BorderSide(color: _lightBorder),
      labelStyle: const TextStyle(color: _lightTextPrimary, fontSize: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
    ),
    
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: _lightSurface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    ),

    dividerTheme: const DividerThemeData(
       color: _lightBorder,
       thickness: 1,
    ),

    textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme).apply(
      bodyColor: _lightTextPrimary,
      displayColor: _lightTextPrimary,
    ),
  );

  // DARK THEME
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: _darkPrimary,
    scaffoldBackgroundColor: _darkBg,
    
    colorScheme: const ColorScheme.dark(
      primary: _darkPrimary,
      secondary: _darkSecondary,
      surface: _darkSurface, // Used for AppBars etc
      surfaceTint: _darkSurface,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: _darkTextPrimary,
      error: _darkError,
      outline: _darkBorder,
      background: _darkBg,
    ),
    
    appBarTheme: const AppBarTheme(
      backgroundColor: _darkSurface,
      foregroundColor: _darkTextPrimary,
      elevation: 0,
      centerTitle: true,
      surfaceTintColor: Colors.transparent, // Disable Material 3 tint
      iconTheme: IconThemeData(color: _darkTextSecondary),
      titleTextStyle: TextStyle(color: _darkTextPrimary, fontSize: 18, fontWeight: FontWeight.bold),
    ),

    // Koyu temada beyaz kart yok! Slate 800 kullanıyoruz.
    cardTheme: CardThemeData(
      color: _darkCard,
      elevation: 0,
       shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: _darkBorder),
      ),
      margin: EdgeInsets.zero,
    ),

    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      minVerticalPadding: 16,
      iconColor: _darkTextSecondary,
      textColor: _darkTextPrimary,
      titleTextStyle: TextStyle(fontWeight: FontWeight.w500, fontSize: 16, color: _darkTextPrimary),
      subtitleTextStyle: TextStyle(fontSize: 14, color: _darkTextSecondary),
      tileColor: Colors.transparent, // Kartın rengini alsın
    ),
    
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
       backgroundColor: _darkSurface, // Slate 900
       selectedItemColor: _darkSecondary,
       unselectedItemColor: _darkTextSecondary,
       type: BottomNavigationBarType.fixed,
       elevation: 0, // Düz görünüm, border eklenebilir
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _darkCard, // Input içi kart rengi olsun
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _darkBorder)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _darkBorder)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _darkPrimary, width: 2)),
      labelStyle: const TextStyle(color: _darkTextSecondary),
      hintStyle: const TextStyle(color: _darkTextSecondary),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: _darkSurface,
      side: const BorderSide(color: _darkBorder),
      labelStyle: const TextStyle(color: _darkTextSecondary, fontSize: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
    ),
    
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: _darkOverlay, // Slate 800 (Card ile aynı veya bir tık açık)
      modalBackgroundColor: _darkOverlay,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    ),
    
    dialogTheme: DialogThemeData(
      backgroundColor: _darkCard,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: _darkBorder)),
      titleTextStyle: const TextStyle(color: _darkTextPrimary, fontSize: 20, fontWeight: FontWeight.bold),
      contentTextStyle: const TextStyle(color: _darkTextSecondary, fontSize: 16),
    ),

    iconTheme: const IconThemeData(color: _darkTextSecondary),
    
    dividerTheme: const DividerThemeData(
       color: _darkBorder,
       thickness: 1,
    ),
    
    textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).apply(
      bodyColor: _darkTextPrimary,
      displayColor: _darkTextPrimary,
    ),
  );
}
