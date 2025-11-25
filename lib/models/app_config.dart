// KATEGORI_MODEL_UPDATE NO_URUT_01 (ENABLE PACKAGES)
// NAMA FILE: lib/models/app_config.dart
// TUJUAN:
// - [FITUR] Mengaktifkan parsing data 'packages' agar UI tahu harga & token.
// - [ANTI-REGRESI] Mempertahankan kelas 'Costs' 100% sama dengan kode asli.
// - [KOMPATIBILITAS] Menambahkan default value pada constructor agar Provider aman.

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
  
  // [DIUBAH] Field ini sekarang diaktifkan (sebelumnya diabaikan)
  final Map<String, PackageConfig> packages;

  AppConfig({
    required this.costs,
    // [ANTI-REGRESI] Default ke map kosong agar tidak error jika data belum ada
    this.packages = const {}, 
  });

  factory AppConfig.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    
    // 1. Parsing 'costs' dengan aman (Logika Lama)
    final costsData = data['costs'] as Map<String, dynamic>? ?? {};
    final costs = Costs.fromMap(costsData);

    // 2. [BARU] Parsing 'packages'
    final packagesData = data['packages'] as Map<String, dynamic>? ?? {};
    final packages = packagesData.map(
      (key, value) => MapEntry(
        key,
        PackageConfig.fromMap(value as Map<String, dynamic>),
      ),
    );

    return AppConfig(costs: costs, packages: packages);
  }

  // [BARU] Helper untuk mengambil paket spesifik dengan mudah di UI
  PackageConfig? getPackage(String key) {
    return packages[key];
  }
}

/// [Costs]
/// BAGIAN INI DIPERTAHANKAN 100% SESUAI KODE ASLI ANDA
/// AGAR TIDAK ADA REGRESI PADA FITUR GENERATE KONTEN.
class Costs {
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

  // --- [PATCH BARU] GETTER ALIAS (SnakeCase) ---
  int get motion_per_scene => motionPerScene;
  int get footage_per_scene => footagePerScene;
  // ---------------------------------------------

  /// Helper: Nilai fallback (Jaring Pengaman) jika Firestore gagal
  factory Costs.fallback() {
    return Costs(
      motionPerScene: 100,
      footagePerScene: 800,
      ideKontenPerClick: 10,
      kontenUmumPerClick: 20,
      kontenShortPerClick: 20,
      kisahSejarahPerClick: 20,
      kisahIslamiPerClick: 20,
      kisahLegendaPerClick: 20,
      kisahHororPerClick: 20,
      kisahCustomPerClick: 20,
      createThumbnailPerClick: 100,
    );
  }

  /// Helper: Parsing dari Map (Firestore)
  factory Costs.fromMap(Map<String, dynamic> map) {
    // Menggunakan fallback() untuk jaminan anti-regresi (anti-null)
    final defaults = Costs.fallback();
    return Costs(
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