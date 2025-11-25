// KATEGORI_CONFIG_BARU NO_URUT_02
// NAMA FILE: lib/providers/config_provider.dart
// TUJUAN: Provider Riverpod untuk memuat config/token_settings SATU KALI
// dan menyediakannya (cache) ke seluruh UI.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Impor model yang baru kita buat
import '../models/app_config.dart';

// Impor provider firestore dari user_provider (efisiensi)
import './user_provider.dart';

/// [appConfigProvider]
/// Provider ini adalah 'FutureProvider' yang memuat dokumen
/// 'config/token_settings' dari Firestore.
///
/// UI dapat me-'watch' provider ini dan akan menerima:
/// 1. state Loading (saat data diambil)
/// 2. state Error (jika gagal)
/// 3. state Data (berisi objek AppConfig)
///
/// '.autoDispose' digunakan agar provider di-cache selama masih ada
/// yang me-'watch', dan akan membersihkan diri jika tidak lagi digunakan,
/// lalu memuat ulang jika diakses kembali.
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
      // Kembalikan 'fallback' dari model Costs agar UI tidak crash.
      // Ini adalah Jaring Pengaman Anti-Regresi.
      print(
          "[AppConfigProvider] WARNING: Dokumen 'config/token_settings' tidak ditemukan. Menggunakan nilai fallback.");
      return AppConfig(costs: Costs.fallback());
    }
  } catch (e) {
    // 6. GAGAL (Kritis): Error saat mengambil data (misal: permissions)
    // Kembalikan 'fallback' agar UI tidak crash.
    print(
        "[AppConfigProvider] ERROR: Gagal memuat config: $e. Menggunakan nilai fallback.");
    return AppConfig(costs: Costs.fallback());
  }
});