// [NAMA FILE: lib/providers/config_provider.dart] //
// [KATEGORI: PROVIDER / STATE MANAGEMENT] //
// [TUJUAN: Memuat config/token_settings dari Firestore dan mengatur State Bahasa] //

// No ke-1: IMPORT & SETUP //
import 'package:flutter/material.dart'; // Dibutuhkan untuk Locale
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Impor model
import '../models/app_config.dart';

// [PERBAIKAN KRITIS ANTI-REGRESI]: 
// Import './user_provider.dart' DIHAPUS TOTAL dari sini.
// Tujuannya untuk memutus "Circular Dependency" yang menyebabkan error
// "Bad state: Could not find summary for library" pada Flutter Web.
//.......................................................//

// No ke-2: STATE BAHASA (APP LANGUAGE PROVIDER) //
/// [appLanguageProvider]
/// Provider sederhana untuk mengatur bahasa aplikasi secara lokal.
/// Default: English ('en').
/// Menggunakan StateProvider agar UI bisa mengubah nilainya secara langsung.
final appLanguageProvider = StateProvider<Locale>((ref) {
  // Default bahasa Inggris. 
  // Nanti bisa dikembangkan untuk membaca dari SharedPreferences jika perlu persistensi.
  return const Locale('en');
});
//.......................................................//

// No ke-3: CONFIG FIRESTORE (APP CONFIG PROVIDER) //
/// [appConfigProvider]
/// Provider ini adalah 'FutureProvider' yang memuat dokumen
/// 'config/token_settings' dari Firestore.
final appConfigProvider = FutureProvider.autoDispose<AppConfig>((ref) async {
  // [PERBAIKAN KRITIS]: Langsung memanggil instance Firestore bawaan Firebase.
  // Ini menghindari ketergantungan pada firestoreProvider di user_provider.dart.
  final db = FirebaseFirestore.instance;

  // Tentukan path dokumen
  final docRef = db.collection('config').doc('token_settings');

  try {
    // Ambil dokumen
    final doc = await docRef.get();

    if (doc.exists) {
      // SUKSES: Dokumen ada, parse menggunakan model
      return AppConfig.fromFirestore(doc);
    } else {
      // GAGAL (Ringan): Dokumen tidak ditemukan.
      debugPrint("[AppConfigProvider] WARNING: Dokumen 'config/token_settings' tidak ditemukan. Menggunakan nilai fallback.");
      // [MODIFIKASI] Menambahkan parameter minAppVersion & playStoreUrl pada fallback
      return AppConfig(
        costs: Costs.fallback(), 
        packages: const {},
        minAppVersion: '1.0.0',
        playStoreUrl: 'https://play.google.com/store/apps/details?id=com.mslstudio.majiku',
      );
    }
  } catch (e) {
    // GAGAL (Kritis): Error saat mengambil data
    debugPrint("[AppConfigProvider] ERROR: Gagal memuat config: $e. Menggunakan nilai fallback.");
    // [MODIFIKASI] Menambahkan parameter minAppVersion & playStoreUrl pada fallback
    return AppConfig(
      costs: Costs.fallback(), 
      packages: const {},
      minAppVersion: '1.0.0',
      playStoreUrl: 'https://play.google.com/store/apps/details?id=com.mslstudio.majiku',
    );
  }
});
//.......................................................//