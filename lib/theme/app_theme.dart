// KATEGORI_TEMA_BARU NO_URUT_01
// NAMA FILE: lib/theme/app_theme.dart
// TUJUAN: Mendefinisikan tema "Dark Modern" terpusat
// untuk semua halaman non-Naraku.

import 'package:flutter/material.dart';

class AppTheme {
  // Palet "Dark Modern" (Versi Hitam/Ungu/Emas)
  static const Color primaryColor = Colors.deepPurple; // <-- GANTI JADI UNGU
  static const Color accentColor = Colors.amber; // <-- GANTI JADI EMAS
  static const Color background = Colors.black; // <-- GANTI JADI HITAM
  static const Color appBarBg = Color(0xFF1A1A1A); // <-- Abu-abu sangat gelap
  static const Color cardBg = Color(0xFF2C2C2C); // <-- Abu-abu gelap (untuk Card)
  static const Color inputFill = Color(0xFF1A1A1A); // <-- Abu-abu sangat gelap (untuk TextField)
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFBDBDBD); // Tetap abu-abu
  static const Color textHint = Color(0xFF9E9E9E); // Tetap abu-abu

  // Definisi Tema Utama
  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,

    // 1. Warna Inti
    primaryColor: primaryColor,
    scaffoldBackgroundColor: background,
    
    // 2. Skema Warna (Penting untuk Material 3)
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.dark,
      primary: primaryColor,
      onPrimary: textPrimary,
      secondary: accentColor,
      onSecondary: Colors.black, // Teks hitam di atas aksen teal
      background: background,
      onBackground: textPrimary,
      surface: cardBg, // Warna untuk Card
      onSurface: textPrimary, // Teks di atas Card
      error: Colors.redAccent,
      onError: Colors.white,
    ),

    // 3. Tema AppBar (Kekinian & Keren)
    appBarTheme: const AppBarTheme(
      backgroundColor: appBarBg,
      foregroundColor: textPrimary, // Warna judul dan ikon
      elevation: 0,
      centerTitle: false,
    ),

    // 4. Tema Card (Konsisten dengan Naraku)
    cardTheme: CardThemeData(
      color: cardBg,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias, // Memastikan sudut melengkung rapi
    ),

    // 5. Tema Tombol (CTA Utama)
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: textPrimary,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
        textStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    ),

    // 6. Tema Input/TextField (Sangat Penting)
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: inputFill,
      hintStyle: TextStyle(color: textHint),
      labelStyle: TextStyle(color: textSecondary),
      // Border saat normal
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      // Border saat di-klik (fokus)
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: accentColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
    ),

    // 7. Tema Teks (Kontras Tinggi)
    textTheme: Typography.whiteMountainView.apply(
      bodyColor: textPrimary,
      displayColor: textPrimary,
    ).copyWith(
      // Judul besar (seperti di AppBar atau judul Kartu)
      headlineSmall: Typography.whiteMountainView.headlineSmall?.copyWith(
        color: textPrimary,
        fontWeight: FontWeight.bold,
      ),
      // Teks default di dalam body
      bodyMedium: Typography.whiteMountainView.bodyMedium?.copyWith(
        color: textSecondary, // Abu-abu sedikit untuk teks body
        height: 1.5, // Jarak antar baris
      ),
      // Teks di dalam TextFields
      titleMedium: Typography.whiteMountainView.titleMedium?.copyWith(
        color: textPrimary,
      ),
      // Label kecil (seperti di atas textfield)
      labelMedium: Typography.whiteMountainView.labelMedium?.copyWith(
        color: textSecondary,
      ),
    ),
  );
}