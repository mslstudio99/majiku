// KATEGORI_MODEL_UPDATE NO_URUT_01 (ENABLE PACKAGES & REMOTE FREE TOKENS - FIXED)
// NAMA FILE: lib/models/app_config.dart
// TUJUAN:
// - [FITUR] Mengaktifkan parsing data 'packages' agar UI tahu harga & token.
// - [FITUR] Menambahkan 'freeTokens' yang bisa diatur remote via Firestore.
// - [FIX] Menghapus parameter tak terdaftar yang menyebabkan gagal compile.
// - [ANTI-REGRESI] Mempertahankan variabel asli 100% sesuai constructor.

import 'package:cloud_firestore/cloud_firestore.dart';

/// [PackageConfig]
/// Model pembantu untuk memetakan detail paket (harga, tier, token) dari Firestore.
class PackageConfig {
  final int amount;
  final int tokens;
  final String tier;

  PackageConfig({
    required this.amount,
    required this.tokens,
    required this.tier,
  });

  factory PackageConfig.fromMap(Map<String, dynamic> map) {
    return PackageConfig(
      amount: (map['amount'] ?? 0).toInt(),
      tokens: (map['tokens'] ?? 0).toInt(),
      tier: map['tier'] ?? '',
    );
  }
}

/// [AppConfig]
/// Model data level atas untuk dokumen 'config/token_settings'.
class AppConfig {
  final Costs costs;
  
  // Field ini diaktifkan untuk mendukung sistem pembelian paket
  final Map<String, PackageConfig> packages;

  AppConfig({
    required this.costs,
    // Default ke map kosong agar tidak error jika data belum ada di Firestore
    this.packages = const {}, 
  });

  factory AppConfig.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    
    // 1. Parsing 'costs' dengan aman
    final costsData = data['costs'] as Map<String, dynamic>? ?? {};
    final costs = Costs.fromMap(costsData);

    // 2. Parsing 'packages'
    final packagesData = data['packages'] as Map<String, dynamic>? ?? {};
    final packages = packagesData.map(
      (key, value) => MapEntry(
        key,
        PackageConfig.fromMap(value as Map<String, dynamic>),
      ),
    );

    return AppConfig(costs: costs, packages: packages);
  }

  // Helper untuk mengambil paket spesifik (misal: 'basic_monthly')
  PackageConfig? getPackage(String key) {
    return packages[key];
  }
}

/// [Costs]
/// Mengatur biaya token untuk setiap aksi di aplikasi Majiku.
class Costs {
  // --- BARU: REMOTE INITIAL TOKENS ---
  final int freeTokens;

  // --- VARIABEL ASLI (CamelCase) ---
  final int motionPerScene;
  final int footagePerScene;
  final int ideKontenPerClick;
  final int kontenUmumPerClick;
  final int kontenShortPerClick;
  final int kisahSejarahPerClick;
  final int kisahIslamiPerClick;
  final int kisahLegendaPerClick;
  final int kisahHororPerClick;
  final int kisahCustomPerClick;
  final int createThumbnailPerClick;

  Costs({
    required this.freeTokens, 
    required this.motionPerScene,
    required this.footagePerScene,
    required this.ideKontenPerClick,
    required this.kontenUmumPerClick,
    required this.kontenShortPerClick,
    required this.kisahSejarahPerClick,
    required this.kisahIslamiPerClick,
    required this.kisahLegendaPerClick,
    required this.kisahHororPerClick,
    required this.kisahCustomPerClick,
    required this.createThumbnailPerClick,
  });

  // --- [PATCH] GETTER ALIAS (SnakeCase) ---
  int get motion_per_scene => motionPerScene;
  int get footage_per_scene => footagePerScene;

  /// Helper: Nilai fallback (Jaring Pengaman) jika Firestore gagal diakses
  factory Costs.fallback() {
    return Costs(
      freeTokens: 200, 
      motionPerScene: 100,
      footagePerScene: 800,
      ideKontenPerClick: 10,
      kontenUmumPerClick: 20,
      // FIXED: Menghapus parameter 'contentTypeShortPerClick' yang tidak ada di constructor
      kontenShortPerClick: 20,
      kisahSejarahPerClick: 20,
      kisahIslamiPerClick: 20,
      kisahLegendaPerClick: 20,
      kisahHororPerClick: 20,
      kisahCustomPerClick: 20,
      createThumbnailPerClick: 100,
    );
  }

  /// Helper: Parsing dari Map Firestore ke Objek Dart
  factory Costs.fromMap(Map<String, dynamic> map) {
    final defaults = Costs.fallback();
    return Costs(
      // Parsing field baru 'free_tokens'
      freeTokens: map['free_tokens'] as int? ?? defaults.freeTokens,
      
      // Parsing field lama sesuai key Firestore
      motionPerScene: map['motion_per_scene'] as int? ?? defaults.motionPerScene,
      footagePerScene: map['footage_per_scene'] as int? ?? defaults.footagePerScene,
      ideKontenPerClick: map['ide_konten_per_click'] as int? ?? defaults.ideKontenPerClick,
      kontenUmumPerClick: map['konten_umum_per_click'] as int? ?? defaults.kontenUmumPerClick,
      kontenShortPerClick: map['konten_short_per_click'] as int? ?? defaults.kontenShortPerClick,
      kisahSejarahPerClick: map['kisah_sejarah_per_click'] as int? ?? defaults.kisahSejarahPerClick,
      kisahIslamiPerClick: map['kisah_islami_per_click'] as int? ?? defaults.kisahIslamiPerClick,
      kisahLegendaPerClick: map['kisah_legenda_per_click'] as int? ?? defaults.kisahLegendaPerClick,
      kisahHororPerClick: map['kisah_horor_per_click'] as int? ?? defaults.kisahHororPerClick,
      kisahCustomPerClick: map['kisah_custom_per_click'] as int? ?? defaults.kisahCustomPerClick,
      createThumbnailPerClick: map['create_thumbnail_per_click'] as int? ?? defaults.createThumbnailPerClick,
    );
  }
}