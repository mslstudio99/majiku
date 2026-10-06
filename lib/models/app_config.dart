//......................................................//
// NAMA FILE: APP_CONFIG.DART                           //
// PATH: LIB/MODELS/APP_CONFIG.DART                     //
// DESKRIPSI: DATA MODEL CONFIGURATION & TOKENIZATION   //
//......................................................//

import 'package:cloud_firestore/cloud_firestore.dart';

// No ke-1 - PACKAGE CONFIG MODEL.......................//
// Model pembantu untuk memetakan detail paket..........//
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
//......................................................//

// No ke-2 - T2VIDEO DYNAMIC COST CONFIG MODEL..........//
// Model pemetaan harga per-detik T2Video...............//
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
//......................................................//

// No ke-3 - IMAGE2VIDEO DYNAMIC COST CONFIG MODEL......//
// Model pemetaan harga per-detik Image2Video...........//
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
//......................................................//

// No ke-4 - T2VIDEO-PLUS DYNAMIC COST CONFIG MODEL.....//
// Model pemetaan harga per-detik T2Video-Plus..........//
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
//......................................................//

// No ke-5 - STORINEMA DYNAMIC COST CONFIG MODEL........//
// Model pemetaan harga per-segmen Storinema (Standard, Good, High) //
class StorinemaCostConfig {
  final int standardPerSegment720p;
  final int standardPerSegment1080p;
  final int goodPerSegment720p; 
  final int goodPerSegment1080p; 
  final int highPerSegment720p;
  final int highPerSegment1080p;

  StorinemaCostConfig({
    required this.standardPerSegment720p,
    required this.standardPerSegment1080p,
    required this.goodPerSegment720p,
    required this.goodPerSegment1080p,
    required this.highPerSegment720p,
    required this.highPerSegment1080p,
  });

  // [GETTER ALIAS ANTI-REGRESI]: Menjamin kode eksisting yang memanggil field lama tetap kompatibel
  int get perSegment720p => standardPerSegment720p;
  int get perSegment1080p => standardPerSegment1080p;
  int get res720 => standardPerSegment720p;
  int get res1080 => standardPerSegment1080p;
  int get res480 => standardPerSegment720p;

  factory StorinemaCostConfig.fallback() {
    return StorinemaCostConfig(
      standardPerSegment720p: 720,   // Standard (720p)
      standardPerSegment1080p: 1870, // Standard (1080p)
      goodPerSegment720p: 2000,     // Good (720p)
      goodPerSegment1080p: 2200,    // Good (1080p)
      highPerSegment720p: 4400,     // High (720p)
      highPerSegment1080p: 4500,    // High (1080p)
    );
  }

  factory StorinemaCostConfig.fromMap(Map<String, dynamic>? map) {
    if (map == null) return StorinemaCostConfig.fallback();
    final defaults = StorinemaCostConfig.fallback();
    
    return StorinemaCostConfig(
      standardPerSegment720p: (map['standard_720p_per_segment'] ?? map['720p_per_segment'] ?? map['720p_per_segmen']) as int? ?? defaults.standardPerSegment720p,
      standardPerSegment1080p: (map['standard_1080p_per_segment'] ?? map['1080p_per_segment']) as int? ?? defaults.standardPerSegment1080p,
      goodPerSegment720p: (map['good_720p_per_segment'] ?? map['goodPerSegment720p']) as int? ?? defaults.goodPerSegment720p,
      goodPerSegment1080p: (map['good_1080p_per_segment'] ?? map['goodPerSegment1080p']) as int? ?? defaults.goodPerSegment1080p,
      highPerSegment720p: (map['high_720p_per_segment'] ?? map['highPerSegment720p']) as int? ?? defaults.highPerSegment720p,
      highPerSegment1080p: (map['high_1080p_per_segment'] ?? map['highPerSegment1080p']) as int? ?? defaults.highPerSegment1080p,
    );
  }
}
//......................................................//

// No ke-6 - VEO DYNAMIC COST CONFIG MODEL..............//
// Model pemetaan harga per-detik khusus pipeline VEO...//
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
//......................................................//

// No ke-6B - NARACINEMA PLUS DYNAMIC COST CONFIG MODEL..//
// Model pemetaan harga per-segmen Naracinema Plus (Good, High) //
class NaracinemaPlusCostConfig {
  final int perSegment720p;
  final int perSegment1080p;
  final int goodPerSegment720p; 
  final int goodPerSegment1080p; 
  final int highPerSegment720p;
  final int highPerSegment1080p;

  NaracinemaPlusCostConfig({
    required this.perSegment720p,
    required this.perSegment1080p,
    required this.goodPerSegment720p,
    required this.goodPerSegment1080p,
    required this.highPerSegment720p,
    required this.highPerSegment1080p,
  });

  factory NaracinemaPlusCostConfig.fallback() {
    return NaracinemaPlusCostConfig(
      perSegment720p: 2000,
      perSegment1080p: 2200,
      goodPerSegment720p: 2000, 
      goodPerSegment1080p: 2200,
      highPerSegment720p: 4400,
      highPerSegment1080p: 4500,
    );
  }

  factory NaracinemaPlusCostConfig.fromMap(Map<String, dynamic>? map) {
    if (map == null) return NaracinemaPlusCostConfig.fallback();
    final defaults = NaracinemaPlusCostConfig.fallback();
    
    return NaracinemaPlusCostConfig(
      perSegment720p: (map['720p_per_segment'] ?? map['perSegment720p']) as int? ?? defaults.perSegment720p,
      perSegment1080p: (map['1080p_per_segment'] ?? map['perSegment1080p']) as int? ?? defaults.perSegment1080p,
      goodPerSegment720p: (map['good_720p_per_segment'] ?? map['goodPerSegment720p']) as int? ?? defaults.goodPerSegment720p,
      goodPerSegment1080p: (map['good_1080p_per_segment'] ?? map['goodPerSegment1080p']) as int? ?? defaults.goodPerSegment1080p,
      highPerSegment720p: (map['high_720p_per_segment'] ?? map['highPerSegment720p']) as int? ?? defaults.highPerSegment720p,
      highPerSegment1080p: (map['high_1080p_per_segment'] ?? map['highPerSegment1080p']) as int? ?? defaults.highPerSegment1080p,
    );
  }
}
//......................................................//

//No ke-6C - MARKETTING VIDEO DYNAMIC COST CONFIG MODEL...........//
// Model pemetaan harga per-segmen Marketting Video (Standard/High)//
class MarkettingVideoCostConfig {
  final int standardPerSegment720p;
  final int standardPerSegment1080p;
  final int highPerSegment720p; 
  final int highPerSegment1080p; 

  MarkettingVideoCostConfig({
    required this.standardPerSegment720p,
    required this.standardPerSegment1080p,
    required this.highPerSegment720p,
    required this.highPerSegment1080p,
  });

  // [GETTER ALIAS ANTI-REGRESI]: Menjamin kode eksisting tetap kompatibel
  int get perSegment720p => standardPerSegment720p;
  int get perSegment1080p => standardPerSegment1080p;
  int get goodPerSegment720p => highPerSegment720p;
  int get goodPerSegment1080p => highPerSegment1080p;

  factory MarkettingVideoCostConfig.fallback() {
    return MarkettingVideoCostConfig(
      standardPerSegment720p: 2880, // Veo 3.1 Fast (720p)
      standardPerSegment1080p: 3000, // Veo 3.1 Fast (1080p)
      highPerSegment720p: 4300,     // Veo 3.1 Quality (720p)
      highPerSegment1080p: 4400,    // Veo 3.1 Quality (1080p)
    );
  }

  factory MarkettingVideoCostConfig.fromMap(Map<String, dynamic>? map) {
    if (map == null) return MarkettingVideoCostConfig.fallback();
    final defaults = MarkettingVideoCostConfig.fallback();
    
    return MarkettingVideoCostConfig(
      standardPerSegment720p: (map['standard_720p_per_segment'] ?? map['720p_per_segment']) as int? ?? defaults.standardPerSegment720p,
      standardPerSegment1080p: (map['standard_1080p_per_segment'] ?? map['1080p_per_segment']) as int? ?? defaults.standardPerSegment1080p,
      highPerSegment720p: (map['high_720p_per_segment'] ?? map['good_720p_per_segment']) as int? ?? defaults.highPerSegment720p,
      highPerSegment1080p: (map['high_1080p_per_segment'] ?? map['good_1080p_per_segment']) as int? ?? defaults.highPerSegment1080p,
    );
  }
}
//......................................................//

// No ke-6D - T2SPEECH DYNAMIC COST CONFIG MODEL.........//
// Model pemetaan harga dinamis per-100 karakter T2Speech//
class T2SpeechCostConfig {
  final int costPer100Chars;
  final int minTokens;

  T2SpeechCostConfig({
    required this.costPer100Chars,
    required this.minTokens,
  });

  factory T2SpeechCostConfig.fallback() {
    return T2SpeechCostConfig(
      costPer100Chars: 15,
      minTokens: 15,
    );
  }

  factory T2SpeechCostConfig.fromMap(Map<String, dynamic>? map) {
    if (map == null) return T2SpeechCostConfig.fallback();
    final defaults = T2SpeechCostConfig.fallback();
    
    return T2SpeechCostConfig(
      costPer100Chars: (map['cost_per_100_chars'] ?? map['costPer100Chars']) as int? ?? defaults.costPer100Chars,
      minTokens: (map['min_tokens'] ?? map['minTokens']) as int? ?? defaults.minTokens,
    );
  }
}
//......................................................//

// No ke-7 - APP CONFIG MODEL..........................//
// Model data level atas untuk dokumen config...........//
class AppConfig {
  final Costs costs;
  final Map<String, PackageConfig> packages;
  
  final String minAppVersion;
  final String playStoreUrl;
  final double usdRate; // [BARU] Kurs USD ke IDR dinamis dari Firestore

  AppConfig({
    required this.costs,
    this.packages = const {}, 
    required this.minAppVersion,
    required this.playStoreUrl,
    this.usdRate = 15500.0, // [FALLBACK AMAN] Default 15500 jika belum diisi di DB
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

    // Membaca kurs dinamis dari key 'usd_rate' atau 'usdRate', fallback 15500.0
    final rawUsdRate = data['usd_rate'] ?? data['usdRate'] ?? 15500.0;
    final double parsedUsdRate = (rawUsdRate is num) ? rawUsdRate.toDouble() : 15500.0;

    return AppConfig(
      costs: costs, 
      packages: packages,
      minAppVersion: minVersion,
      playStoreUrl: storeUrl,
      usdRate: parsedUsdRate,
    );
  }

  PackageConfig? getPackage(String key) {
    return packages[key];
  }
}
//......................................................//

//No ke-8 - COSTS MODEL...........................................//
// Mengatur biaya token untuk setiap aksi di aplikasi.............//
class Costs {
  final int freeTokens;
  final int motionPerScene;
  final int motionGoodPerScene; // [BARU] Biaya Motion Tier Good (Gemini 3.1 Flash Image)
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
  final int t2imageCost; 
  
  final T2VideoCostConfig t2videoCosts;
  final Image2VideoCostConfig image2videoCosts; 
  final T2VideoPlusCostConfig t2videoPlusCosts; 
  final StorinemaCostConfig storinemaCosts;
  final VeoCostConfig veoCosts; 
  final NaracinemaPlusCostConfig naracinemaPlusCosts; 
  final MarkettingVideoCostConfig markettingVideoCosts;
  final T2SpeechCostConfig t2speechCosts;

  Costs({
    required this.freeTokens, 
    required this.motionPerScene,
    required this.motionGoodPerScene, // [BARU]
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
    required this.t2imageCost,
    required this.t2videoCosts,
    required this.image2videoCosts, 
    required this.t2videoPlusCosts, 
    required this.storinemaCosts,
    required this.veoCosts, 
    required this.naracinemaPlusCosts, 
    required this.markettingVideoCosts,
    required this.t2speechCosts,
  });

  int get motion_per_scene => motionPerScene;
  int get motion_good_per_scene => motionGoodPerScene; // [BARU] Getter alias
  int get footage_per_scene => footagePerScene; 

  factory Costs.fallback() {
    return Costs(
      freeTokens: 200, 
      motionPerScene: 120,          // [PERBAIKAN] Default 120 (Standard)
      motionGoodPerScene: 180,      // [BARU] Default 180 (Good)
      footagePerScene: 100, 
      ideKontenPerClick: 10,
      kontenUmumPerClick: 20,
      kontenShortPerClick: 20,
      kisahSejarahPerClick: 20,
      kisahIslamiPerClick: 20,
      kisahLegendaPerClick: 20,
      kisahHororPerClick: 20,
      kisahCustomPerClick: 20,
      createThumbnailPerClick: 100,
      t2imageCost: 100, 
      t2videoCosts: T2VideoCostConfig.fallback(), 
      image2videoCosts: Image2VideoCostConfig.fallback(), 
      t2videoPlusCosts: T2VideoPlusCostConfig.fallback(), 
      storinemaCosts: StorinemaCostConfig.fallback(),
      veoCosts: VeoCostConfig.fallback(), 
      naracinemaPlusCosts: NaracinemaPlusCostConfig.fallback(), 
      markettingVideoCosts: MarkettingVideoCostConfig.fallback(),
      t2speechCosts: T2SpeechCostConfig.fallback(),
    );
  }

  factory Costs.fromMap(Map<String, dynamic>? map) {
    if (map == null) return Costs.fallback();
    final defaults = Costs.fallback();
    
    return Costs(
      freeTokens: map['free_tokens'] as int? ?? defaults.freeTokens,
      motionPerScene: (map['motion_per_scene'] ?? map['motionPerScene']) as int? ?? defaults.motionPerScene,
      motionGoodPerScene: (map['motion_good_per_scene'] ?? map['motionGoodPerScene']) as int? ?? defaults.motionGoodPerScene, // [BARU]
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
      t2imageCost: (map['t2image_per_click'] ?? map['t2image_cost']) as int? ?? defaults.t2imageCost,
      t2videoCosts: T2VideoCostConfig.fromMap(map['t2video_costs'] as Map<String, dynamic>?),
      image2videoCosts: Image2VideoCostConfig.fromMap(map['image2video_costs'] as Map<String, dynamic>?),
      t2videoPlusCosts: T2VideoPlusCostConfig.fromMap(map['t2video_plus_costs'] as Map<String, dynamic>?),
      storinemaCosts: StorinemaCostConfig.fromMap(map['storinema_costs'] as Map<String, dynamic>?),
      veoCosts: VeoCostConfig.fromMap(map['veo_costs'] as Map<String, dynamic>?),
      naracinemaPlusCosts: NaracinemaPlusCostConfig.fromMap(map['naracinema_plus_costs'] as Map<String, dynamic>?),
      markettingVideoCosts: MarkettingVideoCostConfig.fromMap((map['marketting_video_costs'] ?? map['marketing_video_costs']) as Map<String, dynamic>?),
      t2speechCosts: T2SpeechCostConfig.fromMap(map['t2speech_costs'] as Map<String, dynamic>?),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'motion_per_scene': motion_per_scene,
      'motion_good_per_scene': motion_good_per_scene,
      'footage_per_scene': footage_per_scene,
    };
  }
}
//......................................................//