//===================================================================//
// NAMA FILE: APP_CONFIG.DART                                        //
// PATH: LIB/MODELS/APP_CONFIG.DART                                  //
//===================================================================//

import 'package:cloud_firestore/cloud_firestore.dart';

// No ke-1 : PACKAGE CONFIG MODEL                                      //
// Model pembantu untuk memetakan detail paket (harga, tier, token)    //
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
//-------------------------------------------------------------------//

// No ke-2 : T2VIDEO DYNAMIC COST CONFIG MODEL                         //
// Model pemetaan harga per-detik T2Video berdasarkan resolusi         //
class T2VideoCostConfig {
  final int res480NoAudio;
  final int res480WithAudio;
  final int res720NoAudio;
  final int res720WithAudio;
  final int res1080NoAudio;
  final int res1080WithAudio;

  T2VideoCostConfig({
    required this.res480NoAudio,
    required this.res480WithAudio,
    required this.res720NoAudio,
    required this.res720WithAudio,
    required this.res1080NoAudio,
    required this.res1080WithAudio,
  });

  factory T2VideoCostConfig.fallback() {
    return T2VideoCostConfig(
      res480NoAudio: 40,
      res480WithAudio: 60,
      res720NoAudio: 70,
      res720WithAudio: 120,
      res1080NoAudio: 120,
      res1080WithAudio: 220,
    );
  }

  factory T2VideoCostConfig.fromMap(Map<String, dynamic>? map) {
    if (map == null) return T2VideoCostConfig.fallback();
    final defaults = T2VideoCostConfig.fallback();
    
    return T2VideoCostConfig(
      res480NoAudio: map['480_no_audio'] as int? ?? defaults.res480NoAudio,
      res480WithAudio: map['480_with_audio'] as int? ?? defaults.res480WithAudio,
      res720NoAudio: map['720_no_audio'] as int? ?? defaults.res720NoAudio,
      res720WithAudio: map['720_with_audio'] as int? ?? defaults.res720WithAudio,
      res1080NoAudio: map['1080_no_audio'] as int? ?? defaults.res1080NoAudio,
      res1080WithAudio: map['1080_with_audio'] as int? ?? defaults.res1080WithAudio,
    );
  }
}
//-------------------------------------------------------------------//

// No ke-3 : IMAGE2VIDEO DYNAMIC COST CONFIG MODEL                     //
// Model pemetaan harga per-detik Image2Video berdasarkan resolusi     //
class Image2VideoCostConfig {
  final int res480NoAudio;
  final int res480WithAudio;
  final int res720NoAudio;
  final int res720WithAudio;
  final int res1080NoAudio;
  final int res1080WithAudio;

  Image2VideoCostConfig({
    required this.res480NoAudio,
    required this.res480WithAudio,
    required this.res720NoAudio,
    required this.res720WithAudio,
    required this.res1080NoAudio,
    required this.res1080WithAudio,
  });

  factory Image2VideoCostConfig.fallback() {
    return Image2VideoCostConfig(
      res480NoAudio: 50,
      res480WithAudio: 70,
      res720NoAudio: 80,
      res720WithAudio: 130,
      res1080NoAudio: 130,
      res1080WithAudio: 230,
    );
  }

  factory Image2VideoCostConfig.fromMap(Map<String, dynamic>? map) {
    if (map == null) return Image2VideoCostConfig.fallback();
    final defaults = Image2VideoCostConfig.fallback();
    
    return Image2VideoCostConfig(
      res480NoAudio: map['480_no_audio'] as int? ?? defaults.res480NoAudio,
      res480WithAudio: map['480_with_audio'] as int? ?? defaults.res480WithAudio,
      res720NoAudio: map['720_no_audio'] as int? ?? defaults.res720NoAudio,
      res720WithAudio: map['720_with_audio'] as int? ?? defaults.res720WithAudio,
      res1080NoAudio: map['1080_no_audio'] as int? ?? defaults.res1080NoAudio,
      res1080WithAudio: map['1080_with_audio'] as int? ?? defaults.res1080WithAudio,
    );
  }
}
//-------------------------------------------------------------------//

// No ke-4 : T2VIDEO-PLUS DYNAMIC COST CONFIG MODEL                    //
// Model pemetaan harga per-detik T2Video-Plus berdasarkan resolusi    //
class T2VideoPlusCostConfig {
  final int res480NoAudio;
  final int res480WithAudio;
  final int res720NoAudio;
  final int res720WithAudio;
  final int res1080NoAudio;
  final int res1080WithAudio;

  T2VideoPlusCostConfig({
    required this.res480NoAudio,
    required this.res480WithAudio,
    required this.res720NoAudio,
    required this.res720WithAudio,
    required this.res1080NoAudio,
    required this.res1080WithAudio,
  });

  factory T2VideoPlusCostConfig.fallback() {
    return T2VideoPlusCostConfig(
      res480NoAudio: 60,
      res480WithAudio: 80,
      res720NoAudio: 90,
      res720WithAudio: 140,
      res1080NoAudio: 140,
      res1080WithAudio: 240,
    );
  }

  factory T2VideoPlusCostConfig.fromMap(Map<String, dynamic>? map) {
    if (map == null) return T2VideoPlusCostConfig.fallback();
    final defaults = T2VideoPlusCostConfig.fallback();
    
    return T2VideoPlusCostConfig(
      res480NoAudio: map['480_no_audio'] as int? ?? defaults.res480NoAudio,
      res480WithAudio: map['480_with_audio'] as int? ?? defaults.res480WithAudio,
      res720NoAudio: map['720_no_audio'] as int? ?? defaults.res720NoAudio,
      res720WithAudio: map['720_with_audio'] as int? ?? defaults.res720WithAudio,
      res1080NoAudio: map['1080_no_audio'] as int? ?? defaults.res1080NoAudio,
      res1080WithAudio: map['1080_with_audio'] as int? ?? defaults.res1080WithAudio,
    );
  }
}
//-------------------------------------------------------------------//

// No ke-5 : STORINEMA DYNAMIC COST CONFIG MODEL                       //
// Model pemetaan harga per-segmen Storinema berdasarkan resolusi      //
class StorinemaCostConfig {
  final int res480;
  final int res720;
  final int res1080;

  StorinemaCostConfig({
    required this.res480,
    required this.res720,
    required this.res1080,
  });

  factory StorinemaCostConfig.fallback() {
    return StorinemaCostConfig(
      res480: 400,
      res720: 640,
      res1080: 1040,
    );
  }

  factory StorinemaCostConfig.fromMap(Map<String, dynamic>? map) {
    if (map == null) return StorinemaCostConfig.fallback();
    final defaults = StorinemaCostConfig.fallback();
    
    return StorinemaCostConfig(
      res480: map['480p_per_segment'] as int? ?? defaults.res480,
      res720: map['720p_per_segment'] as int? ?? defaults.res720,
      res1080: map['1080p_per_segment'] as int? ?? defaults.res1080,
    );
  }
}
//-------------------------------------------------------------------//

// No ke-6 : VEO DYNAMIC COST CONFIG MODEL [BARU]                      //
// Model pemetaan harga per-detik khusus pipeline VEO                  //
class VeoCostConfig {
  final int res720;
  final int res1080;

  VeoCostConfig({
    required this.res720,
    required this.res1080,
  });

  factory VeoCostConfig.fallback() {
    return VeoCostConfig(
      res720: 200,
      res1080: 230,
    );
  }

  factory VeoCostConfig.fromMap(Map<String, dynamic>? map) {
    if (map == null) return VeoCostConfig.fallback();
    final defaults = VeoCostConfig.fallback();
    
    return VeoCostConfig(
      res720: map['res720'] as int? ?? defaults.res720,
      res1080: map['res1080'] as int? ?? defaults.res1080,
    );
  }
}
//-------------------------------------------------------------------//

// No ke-6B : NARACINEMA PLUS DYNAMIC COST CONFIG MODEL [DIPERBAIKI]      //
// Model pemetaan harga per-segmen Naracinema Plus berdasarkan resolusi    //
class NaracinemaPlusCostConfig {
  // [PERBAIKAN]: Nama properti diubah agar lebih jelas dan konsisten
  final int perSegment720p;
  final int perSegment1080p;

  NaracinemaPlusCostConfig({
    required this.perSegment720p,
    required this.perSegment1080p,
  });

  factory NaracinemaPlusCostConfig.fallback() {
    return NaracinemaPlusCostConfig(
      perSegment720p: 640,
      perSegment1080p: 1040,
    );
  }

  factory NaracinemaPlusCostConfig.fromMap(Map<String, dynamic>? map) {
    if (map == null) return NaracinemaPlusCostConfig.fallback();
    final defaults = NaracinemaPlusCostConfig.fallback();
    
    // Parsing dari Firestore dengan kunci yang benar dan fallback yang aman
    return NaracinemaPlusCostConfig(
      perSegment720p: map['720p_per_segment'] as int? ?? defaults.perSegment720p,
      perSegment1080p: map['1080p_per_segment'] as int? ?? defaults.perSegment1080p,
    );
  }
}
//-------------------------------------------------------------------//

// No ke-7 : APP CONFIG MODEL (DENGAN FORCE UPDATE)                    //
// Model data level atas untuk dokumen config/token_settings           //
class AppConfig {
  final Costs costs;
  final Map<String, PackageConfig> packages;
  
  // Variabel kontrol versi
  final String minAppVersion;
  final String playStoreUrl;

  AppConfig({
    required this.costs,
    this.packages = const {}, 
    required this.minAppVersion,
    required this.playStoreUrl,
  });

  factory AppConfig.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    
    final costsData = data['costs'] as Map<String, dynamic>? ?? {};
    final costs = Costs.fromMap(costsData);

    final packagesData = data['packages'] as Map<String, dynamic>? ?? {};
    final packages = packagesData.map(
      (key, value) => MapEntry(
        key,
        PackageConfig.fromMap(value as Map<String, dynamic>),
      ),
    );

    final minVersion = data['minAppVersion'] as String? ?? '1.0.0';
    final storeUrl = data['playStoreUrl'] as String? ?? 'https://play.google.com/store/apps/details?id=com.mslstudio.majiku';

    return AppConfig(
      costs: costs, 
      packages: packages,
      minAppVersion: minVersion,
      playStoreUrl: storeUrl,
    );
  }

  PackageConfig? getPackage(String key) {
    return packages[key];
  }
}
//-------------------------------------------------------------------//

// No ke-8: COSTS MODEL                                                //
// MENGATUR BIAYA TOKEN UNTUK SETIAP AKSI DI APLIKASI MAJIKU           //
class Costs {
  final int freeTokens;
  final int motionPerScene;
  
  final int ideKontenPerClick;
  final int kontenUmumPerClick;
  final int kontenShortPerClick;
  final int kisahSejarahPerClick;
  final int kisahIslamiPerClick;
  final int kisahLegendaPerClick;
  final int kisahHororPerClick;
  final int kisahCustomPerClick;
  final int createThumbnailPerClick;
  final int t2imageCost; 
  
  final T2VideoCostConfig t2videoCosts;
  final Image2VideoCostConfig image2videoCosts; 
  final T2VideoPlusCostConfig t2videoPlusCosts; 
  final StorinemaCostConfig storinemaCosts;
  final VeoCostConfig veoCosts; 
  final NaracinemaPlusCostConfig naracinemaPlusCosts; // [TAMBAHAN BARU]

  Costs({
    required this.freeTokens, 
    required this.motionPerScene,
    required this.ideKontenPerClick,
    required this.kontenUmumPerClick,
    required this.kontenShortPerClick,
    required this.kisahSejarahPerClick,
    required this.kisahIslamiPerClick,
    required this.kisahLegendaPerClick,
    required this.kisahHororPerClick,
    required this.kisahCustomPerClick,
    required this.createThumbnailPerClick,
    required this.t2imageCost,
    required this.t2videoCosts,
    required this.image2videoCosts, 
    required this.t2videoPlusCosts, 
    required this.storinemaCosts,
    required this.veoCosts, 
    required this.naracinemaPlusCosts, // [TAMBAHAN BARU]
  });

  int get motion_per_scene => motionPerScene;

  factory Costs.fallback() {
    return Costs(
      freeTokens: 200, 
      motionPerScene: 100,
      ideKontenPerClick: 10,
      kontenUmumPerClick: 20,
      kontenShortPerClick: 20,
      kisahSejarahPerClick: 20,
      kisahIslamiPerClick: 20,
      kisahLegendaPerClick: 20,
      kisahHororPerClick: 20,
      kisahCustomPerClick: 20,
      createThumbnailPerClick: 100,
      t2imageCost: 50, 
      t2videoCosts: T2VideoCostConfig.fallback(), 
      image2videoCosts: Image2VideoCostConfig.fallback(), 
      t2videoPlusCosts: T2VideoPlusCostConfig.fallback(), 
      storinemaCosts: StorinemaCostConfig.fallback(),
      veoCosts: VeoCostConfig.fallback(), 
      naracinemaPlusCosts: NaracinemaPlusCostConfig.fallback(), // [TAMBAHAN BARU]
    );
  }

  factory Costs.fromMap(Map<String, dynamic> map) {
    final defaults = Costs.fallback();
    return Costs(
      freeTokens: map['free_tokens'] as int? ?? defaults.freeTokens,
      motionPerScene: map['motion_per_scene'] as int? ?? defaults.motionPerScene,
      ideKontenPerClick: map['ide_konten_per_click'] as int? ?? defaults.ideKontenPerClick,
      kontenUmumPerClick: map['konten_umum_per_click'] as int? ?? defaults.kontenUmumPerClick,
      kontenShortPerClick: map['konten_short_per_click'] as int? ?? defaults.kontenShortPerClick,
      kisahSejarahPerClick: map['kisah_sejarah_per_click'] as int? ?? defaults.kisahSejarahPerClick,
      kisahIslamiPerClick: map['kisah_islami_per_click'] as int? ?? defaults.kisahIslamiPerClick,
      kisahLegendaPerClick: map['kisah_legenda_per_click'] as int? ?? defaults.kisahLegendaPerClick,
      kisahHororPerClick: map['kisah_horor_per_click'] as int? ?? defaults.kisahHororPerClick,
      kisahCustomPerClick: map['kisah_custom_per_click'] as int? ?? defaults.kisahCustomPerClick,
      createThumbnailPerClick: map['create_thumbnail_per_click'] as int? ?? defaults.createThumbnailPerClick,
      
      t2imageCost: map['t2image_per_click'] as int? ?? defaults.t2imageCost, 
      
      t2videoCosts: T2VideoCostConfig.fromMap(map['t2video_costs'] as Map<String, dynamic>?),
      image2videoCosts: Image2VideoCostConfig.fromMap(map['image2video_costs'] as Map<String, dynamic>?), 
      t2videoPlusCosts: T2VideoPlusCostConfig.fromMap(map['t2videoPlus_costs'] as Map<String, dynamic>?), 
      storinemaCosts: StorinemaCostConfig.fromMap(map['storinema_costs'] as Map<String, dynamic>?),
      veoCosts: VeoCostConfig.fromMap(map['veo_costs'] as Map<String, dynamic>?), 
      
      // [TAMBAHAN BARU] Parsing Map naracinema_plus_costs dari Firestore
      naracinemaPlusCosts: NaracinemaPlusCostConfig.fromMap(map['naracinema_plus_costs'] as Map<String, dynamic>?), 
    );
  }
}  
//-------------------------------------------------------------------//