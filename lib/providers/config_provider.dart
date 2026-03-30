// KATEGORI_CONFIG_UPDATE NO_URUT_01
// NAMA FILE: lib/providers/config_provider.dart
// TUJUAN: 
// 1. (Tetap) Memuat config/token_settings dari Firestore.
// 2. (Baru) Menyediakan state bahasa (Inggris/Indo) untuk aplikasi.

import 'package:flutter/material.dart'; // Dibutuhkan untuk Locale
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Impor model
import '../models/app_config.dart';

// Impor provider firestore
import './user_provider.dart';

// =============================================================================
// BAGIAN 1: STATE BAHASA (BARU)
// =============================================================================

/// [appLanguageProvider]
/// Provider sederhana untuk mengatur bahasa aplikasi secara lokal.
/// Default: English ('en').
/// Menggunakan StateProvider agar UI bisa mengubah nilainya secara langsung.
final appLanguageProvider = StateProvider<Locale>((ref) {
  // Default bahasa Inggris. 
  // Nanti bisa dikembangkan untuk membaca dari SharedPreferences jika perlu persistensi.
  return const Locale('en');
});

// =============================================================================
// BAGIAN 2: CONFIG FIRESTORE (EXISTING)
// =============================================================================

/// [appConfigProvider]
/// Provider ini adalah 'FutureProvider' yang memuat dokumen
/// 'config/token_settings' dari Firestore.
final appConfigProvider = FutureProvider.autoDispose<AppConfig>((ref) async {
  // 1. Dapatkan instance Firestore dari provider yang sudah ada
  final db = ref.watch(firestoreProvider);

  // 2. Tentukan path dokumen
  final docRef = db.collection('config').doc('token_settings');

  try {
    // 3. Ambil dokumen
    final doc = await docRef.get();

    if (doc.exists) {
      // 4. SUKSES: Dokumen ada, parse menggunakan model
      return AppConfig.fromFirestore(doc);
    } else {
      // 5. GAGAL (Ringan): Dokumen tidak ditemukan.
      print(
          "[AppConfigProvider] WARNING: Dokumen 'config/token_settings' tidak ditemukan. Menggunakan nilai fallback.");
      return AppConfig(costs: Costs.fallback());
    }
  } catch (e) {
    // 6. GAGAL (Kritis): Error saat mengambil data
    print(
        "[AppConfigProvider] ERROR: Gagal memuat config: $e. Menggunakan nilai fallback.");
    return AppConfig(costs: Costs.fallback());
  }
});