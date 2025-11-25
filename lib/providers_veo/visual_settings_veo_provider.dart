// NAMA FILE: lib/providers_veo/visual_settings_veo_provider.dart
// TUJUAN: Versi "Isolasi Total" (Veo) - Pengaturan Motion/Transisi/Subtitle DIHAPUS.

import 'dart:async';
// --- KATEGORI_PENYESUAIAN_VEO (NO_URUT_01): Hapus import Random (tidak perlu intro music) ---
// import 'dart:math'; // <-- DIHAPUS
// --- AKHIR PENYESUAIAN VEO ---
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Digunakan di FirestoreService

// --- KATEGORI_ISOLASI_VEO (Aturan #1 & #2): Path Impor Disesuaikan ---
import '../view_model_veo/timeline_veo_view_model.dart'; // Mengandung projectVeoStreamProvider
import '../services_veo/firestore_veo_service.dart';
import '../models_veo/video_project_veo.dart'; // Model VideoProjectVeo (meski tidak eksplisit digunakan, path harus benar)
// --- AKHIR ISOLASI VEO ---

// =======================================================================
// === FIREBASE SERVICE PROVIDER (Harus didefinisikan) ===
// =======================================================================

// --- KATEGORI_ISOLASI_VEO (Aturan #3): Definisi Provider Disesuaikan ---
// Provider untuk FirestoreVeoService
final firestoreVeoServiceProvider = Provider<FirestoreVeoService>((ref) {
  return FirestoreVeoService();
});
// --- AKHIR ISOLASI VEO ---

// =======================================================================
// === KONSTANTA FFMPEG (Logika Motion) ===
// =======================================================================
// --- KATEGORI_PENYESUAIAN_VEO (NO_URUT_02): Hapus Semua Konstanta Motion & Transisi ---
// (Semua konstanta _kPi, _kProgressVar, _kEasing, kSceneMotionRecipes, 
// kRandomMotionRecipes, kDefaultSceneMotionNames, kRandomSceneMotionNames DIHAPUS)
// --- AKHIR PENYESUAIAN VEO ---

// =======================================================================
// === ENUM & HELPER KONVERSI ===
// =======================================================================

enum TextEffect { fadeInOut, slideUp, zoomIn, drop }

String textEffectToString(TextEffect effect) {
  switch (effect) {
    case TextEffect.fadeInOut:
      return 'Fade In/Out';
    case TextEffect.slideUp:
      return 'Slide Up';
    case TextEffect.zoomIn:
      return 'Zoom In';
    case TextEffect.drop:
      return 'Drop';
  }
}

TextEffect _textEffectFromString(String? value) {
  value = value?.replaceAll(RegExp(r'[ /]'), '').toLowerCase();
  for (var effect in TextEffect.values) {
    if (effect.name.toLowerCase() == value ||
        textEffectToString(effect)
                .replaceAll(RegExp(r'[ /]'), '')
                .toLowerCase() ==
            value) {
      return effect;
    }
  }
  return TextEffect.fadeInOut; // Default
}

// --- KATEGORI_PERBAIKAN_SKALA: Ganti default fallback ---
double _baseSizeFromLegacyNumeric(double? fontSize) {
  // --- KATEGORI_MODIFIKASI_KONSTANTA NO_URUT_02 (Fallback) ---
  if (fontSize == null) return 45.0; // Fallback ke default Judul baru
  // --- AKHIR MODIFIKASI ---
  // Ini adalah logika mapping dari nilai font lama ke 3 nilai dasar (32, 24, 16)
  if (fontSize > 25.0 || (fontSize > 19.0 && fontSize < 19.5)) {
    return 32.0; // (legacy)
  }
  if (fontSize > 17.0 || (fontSize > 14.0 && fontSize < 14.5)) {
    return 24.0; // (legacy)
  }
  return 16.0; // (legacy)
}

double _baseSizeFromLegacyEnum(String? value) {
  value = value?.toLowerCase();
  if (value == 'large') return 32.0; // (legacy)
  if (value == 'small') return 16.0; // (legacy)
  // --- KATEGORI_MODIFIKASI_KONSTANTA NO_URUT_02 (Fallback) ---
  return 45.0; // Fallback ke default Judul baru
  // --- AKHIR MODIFIKASI ---
}
// --- AKHIR PERBAIKAN ---

// =======================================================================
// === CLASS TextOverlaySettingsVeo ===
// =======================================================================

// --- KATEGORI_ISOLASI_VEO (Aturan #3): Nama Class Disesuaikan ---
@immutable
class TextOverlaySettingsVeo {
// --- AKHIR ISOLASI VEO ---
  final String text;
  final TextEffect effect;
  final double baseFontSize;
  final Color color;
  final double startTime;
  final double duration;
  final double textBlockWidthFactor; // (0.1 - 1.0)
  final int maxLines;
  final double verticalAlignment; // (Flutter: -1.0 s/d 1.0)

  // --- KATEGORI_ISOLASI_VEO (Aturan #3): Nama Class Disesuaikan ---
  const TextOverlaySettingsVeo({
  // --- AKHIR ISOLASI VEO ---
    required this.text,
    required this.effect,
    required this.baseFontSize,
    required this.color,
    required this.startTime,
    required this.duration,
    required this.textBlockWidthFactor,
    required this.maxLines,
    required this.verticalAlignment,
  });

  // --- KATEGORI_ISOLASI_VEO (Aturan #3): Nama Class Disesuaikan ---
  TextOverlaySettingsVeo copyWith({
  // --- AKHIR ISOLASI VEO ---
    String? text,
    TextEffect? effect,
    double? baseFontSize,
    Color? color,
    double? startTime,
    double? duration,
    double? textBlockWidthFactor,
    int? maxLines,
    double? verticalAlignment,
  }) {
    // --- KATEGORI_ISOLASI_VEO (Aturan #3): Nama Class Disesuaikan ---
    return TextOverlaySettingsVeo(
    // --- AKHIR ISOLASI VEO ---
      text: text ?? this.text,
      effect: effect ?? this.effect,
      baseFontSize: baseFontSize ?? this.baseFontSize,
      color: color ?? this.color,
      startTime: startTime ?? this.startTime,
      duration: duration ?? this.duration,
      textBlockWidthFactor: textBlockWidthFactor ?? this.textBlockWidthFactor,
      maxLines: maxLines ?? this.maxLines,
      verticalAlignment: verticalAlignment ?? this.verticalAlignment,
    );
  }

  Map<String, dynamic> toJson(double aspectRatioValue) {
    String colorToHex(Color c) {
      // Hilangkan 'ff' di depan (alpha) untuk hex FFmpeg (misal: FFFFFF)
      return '#${c.value.toRadixString(16).padLeft(8, '0').substring(2)}';
    }

    // --- KATEGORI_PERBAIKAN_SKALA: Hapus penskalaan 60% ---
    double multiplier = 1.0;
    final double responsiveFontSize = baseFontSize * multiplier;
    // --- AKHIR PERBAIKAN ---

    // Hitung boxWidth absolut agar FFmpeg tidak error
    final double baseVideoDimension =
        aspectRatioValue > 1.6 ? 1920 : 1080;
    final double boxWidthPixels = baseVideoDimension * textBlockWidthFactor;

    debugPrint(
        "🧩 [TextOverlaySettingsVeo.toJson] aspect=$aspectRatioValue, boxWidth=${boxWidthPixels.round()}, factor=$textBlockWidthFactor");

    return {
      'text': text,
      'effect': textEffectToString(effect),
      'baseFontSize': baseFontSize,
      'fontSize': responsiveFontSize, // <-- Sekarang selalu 100% dari baseFontSize
      'colorHex': colorToHex(color),
      'startTime': startTime,
      'duration': duration,
      'boxWidth': boxWidthPixels.round(), // Nilai absolut untuk FFmpeg
      'textBlockWidthFactor': textBlockWidthFactor,
      'maxLines': maxLines,
      'verticalAlignment': verticalAlignment,
    };
  }

  // --- KATEGORI_ISOLASI_VEO (Aturan #3): Nama Class Disesuaikan ---
  factory TextOverlaySettingsVeo.fromJson(Map<String, dynamic>? json) {
  // --- AKHIR ISOLASI VEO ---
    Color hexToColor(String? hexCode) {
      if (hexCode == null || !hexCode.startsWith('#')) return Colors.white;
      String hex = hexCode.substring(1);
      if (hex.length == 6) hex = 'FF$hex'; // Tambahkan alpha FF jika 6 digit
      try {
        if (hex.length == 8) {
          return Color(int.parse('0x$hex'));
        }
      } catch (e) {
        debugPrint("Error parsing colorHex: $hexCode, defaulting to white. Error: $e");
      }
      return Colors.white;
    }

    if (json == null) {
      // --- KATEGORI_PERBAIKAN_SKALA: Ganti default fallback ---
      // --- KATEGORI_MODIFIKASI_KONSTANTA NO_URUT_02 (Target 4) ---
      // --- KATEGORI_ISOLASI_VEO (Aturan #3): Nama Class Disesuaikan ---
      return TextOverlaySettingsVeo(
      // --- AKHIR ISOLASI VEO ---
        text: "",
        effect: TextEffect.fadeInOut,
        baseFontSize: 45.0, // <-- Ganti fallback ke default Judul baru
        color: Colors.white,
        startTime: 0.0,
        duration: 5.0,
        textBlockWidthFactor: 0.9,
        maxLines: 3,
        verticalAlignment: -0.8,
      );
      // --- AKHIR MODIFIKASI ---
      // --- AKHIR PERBAIKAN ---
    }

    // --- KATEGORI_PERBAIKAN_SKALA: Ganti default fallback ---
    final double loadedBaseFontSize;
    if (json.containsKey('baseFontSize')) {
      // --- KATEGORI_MODIFIKASI_KONSTANTA NO_URUT_02 (Target 5) ---
      loadedBaseFontSize = (json['baseFontSize'] as num?)?.toDouble() ?? 45.0; // <-- Ganti fallback
      // --- AKHIR MODIFIKASI ---
    } else if (json.containsKey('fontSize')) {
      loadedBaseFontSize =
          _baseSizeFromLegacyNumeric((json['fontSize'] as num?)?.toDouble());
    } else if (json.containsKey('size')) {
      loadedBaseFontSize = _baseSizeFromLegacyEnum(json['size'] as String?);
    } else {
      // --- KATEGORI_MODIFIKASI_KONSTANTA NO_URUT_02 (Target 6) ---
      loadedBaseFontSize = 45.0; // <-- Ganti fallback
      // --- AKHIR MODIFIKASI ---
    }
    // --- AKHIR PERBAIKAN ---

    final double loadedWidthFactor =
        (json['textBlockWidthFactor'] as num?)?.toDouble() ?? 0.9;
    final int loadedMaxLines = (json['maxLines'] as int?) ?? 3;
    final double loadedVAlign =
        (json['verticalAlignment'] as num?)?.toDouble() ?? -0.8;

    // --- KATEGORI_ISOLASI_VEO (Aturan #3): Nama Class Disesuaikan ---
    return TextOverlaySettingsVeo(
    // --- AKHIR ISOLASI VEO ---
      text: json['text'] as String? ?? "", // <-- Ini sudah benar, default ke ""
      effect: _textEffectFromString(json['effect'] as String?),
      baseFontSize: loadedBaseFontSize,
      color: hexToColor(json['colorHex'] as String?),
      startTime: (json['startTime'] as num?)?.toDouble() ?? 0.0,
      duration: (json['duration'] as num?)?.toDouble() ?? 5.0,
      textBlockWidthFactor: loadedWidthFactor,
      maxLines: loadedMaxLines,
      verticalAlignment: loadedVAlign,
    );
  }
}

// =======================================================================
// === CLASS VisualSettingsVeo ===
// =======================================================================

// --- KATEGORI_ISOLASI_VEO (Aturan #3): Nama Class Disesuaikan ---
@immutable
class VisualSettingsVeo {
// --- AKHIR ISOLASI VEO ---

  // --- KATEGORI_ISOLASI_VEO (Aturan #3): Tipe Data Disesuaikan ---
  final TextOverlaySettingsVeo titleSettings;
  final TextOverlaySettingsVeo descriptionSettings;
  // --- AKHIR ISOLASI VEO ---

  // --- KATEGORI_PENYESUAIAN_VEO (NO_URUT_03): Hapus Subtitle, Transisi, Motion, Musik ---
  // (Semua properti subtitle... DIHAPUS)
  // (Semua properti transition... DIHAPUS)
  // (Semua properti introMotion... DIHAPUS)
  // (Semua properti sceneMotion... DIHAPUS)
  // (Properti introMusicUrl DIHAPUS)
  // --- AKHIR PENYESUAIAN VEO ---


  // --- KATEGORI_ISOLASI_VEO (Aturan #3): Nama Class Disesuaikan ---
  const VisualSettingsVeo({
  // --- AKHIR ISOLASI VEO ---
    required this.titleSettings,
    required this.descriptionSettings,
    // --- KATEGORI_PENYESUAIAN_VEO (NO_URUT_04): Hapus dari Konstruktor ---
    // (Semua properti subtitle... DIHAPUS)
    // (Semua properti transition... DIHAPUS)
    // (Semua properti introMotion... DIHAPUS)
    // (Semua properti sceneMotion... DIHAPUS)
    // (Properti introMusicUrl DIHAPUS)
    // --- AKHIR PENYESUAIAN VEO ---
  });

  // --- KATEGORI_ISOLASI_VEO (Aturan #3): Nama Class Disesuaikan ---
  VisualSettingsVeo copyWith({
  // --- AKHIR ISOLASI VEO ---
    TextOverlaySettingsVeo? titleSettings,
    TextOverlaySettingsVeo? descriptionSettings,
    // --- KATEGORI_PENYESUAIAN_VEO (NO_URUT_05): Hapus dari copyWith ---
    // (Semua properti subtitle... DIHAPUS)
    // (Semua properti transition... DIHAPUS)
    // (Semua properti introMotion... DIHAPUS)
    // (Semua properti sceneMotion... DIHAPUS)
    // (Properti introMusicUrl DIHAPUS)
    // --- AKHIR PENYESUAIAN VEO ---
  }) {
    // --- KATEGORI_ISOLASI_VEO (Aturan #3): Nama Class Disesuaikan ---
    return VisualSettingsVeo(
    // --- AKHIR ISOLASI VEO ---
      titleSettings: titleSettings ?? this.titleSettings,
      descriptionSettings: descriptionSettings ?? this.descriptionSettings,
      // --- KATEGORI_PENYESUAIAN_VEO (NO_URUT_06): Hapus dari return copyWith ---
      // (Semua properti subtitle... DIHAPUS)
      // (Semua properti transition... DIHAPUS)
      // (Semua properti introMotion... DIHAPUS)
      // (Semua properti sceneMotion... DIHAPUS)
      // (Properti introMusicUrl DIHAPUS)
      // --- AKHIR PENYESUAIAN VEO ---
    );
  }

  /// Mengembalikan pengaturan default baru dengan judul proyek yang diberikan.
  // --- KATEGORI_ISOLASI_VEO (Aturan #3): Nama Class Disesuaikan ---
  static VisualSettingsVeo defaultSettingsWithTitle(String projectTitle) {
  // --- AKHIR ISOLASI VEO ---
    
    // --- KATEGORI_PENYESUAIAN_VEO (NO_URUT_07): Hapus Logika Musik Intro Acak ---
    // (Logika Random() dan defaultIntroMusicUrl DIHAPUS)
    // --- AKHIR PENYESUAIAN VEO ---

    // --- KATEGORI_PERBAIKAN_SKALA: Ganti default ---
    // --- KATEGORI_MODIFIKASI_KONSTANTA NO_URUT_01 ---
    // --- KATEGORI_ISOLASI_VEO (Aturan #3): Nama Class Disesuaikan ---
    return VisualSettingsVeo(
      titleSettings: TextOverlaySettingsVeo(
      // --- AKHIR ISOLASI VEO ---
        text: projectTitle, // <-- Perbaikan dari "UNTITLED"
        effect: TextEffect.fadeInOut,
        baseFontSize: 45.0, // <-- [TARGET 1] DIUBAH
        color: Colors.white,
        startTime: 3.0,
        duration: 7.0,
        textBlockWidthFactor: 0.9,
        maxLines: 3,
        verticalAlignment: -0.8, // 10% dari atas
      ),
      // --- KATEGORI_ISOLASI_VEO (Aturan #3): Nama Class Disesuaikan ---
      descriptionSettings: TextOverlaySettingsVeo(
      // --- AKHIR ISOLASI VEO ---
        text: "",
        effect: TextEffect.fadeInOut,
        baseFontSize: 40.0, // <-- [TARGET 2] DIUBAH
        color: Colors.white,
        startTime: 11.0,
        duration: 5.0,
        textBlockWidthFactor: 0.9,
        maxLines: 3,
        verticalAlignment: -0.7, // 15% dari atas
      ),
      
      // --- KATEGORI_PENYESUAIAN_VEO (NO_URUT_08): Hapus properti sisa ---
      // (Semua properti subtitle... DIHAPUS)
      // (Semua properti transition... DIHAPUS)
      // (Semua properti introMotion... DIHAPUS)
      // (Semua properti sceneMotion... DIHAPUS)
      // (Properti introMusicUrl DIHAPUS)
      // --- AKHIR PENYESUAIAN VEO ---
    );
    // --- AKHIR MODIFIKASI ---
    // --- AKHIR PERBAIKAN ---
  }

  // --- KATEGORI_PENYESUAIAN_VEO (NO_URUT_09): Hapus helper motion ---
  // (Fungsi _buildSceneMotionJson() DIHAPUS)
  // (Fungsi _buildIntroMotionJson() DIHAPUS)
  // --- AKHIR PENYESUAIAN VEO ---

  Map<String, dynamic> toJson(double aspectRatioValue) {
    // --- KATEGORI_PENYESUAIAN_VEO (NO_URUT_10): Hapus logika subtitle/motion dari toJson ---
    // (Logika subtitle... DIHAPUS)
    // --- AKHIR PENYESUAIAN VEO ---

    return {
      'titleOverlay': titleSettings.toJson(aspectRatioValue),
      'descriptionOverlay': descriptionSettings.toJson(aspectRatioValue),
      
      // --- KATEGORI_PENYESUAIAN_VEO (NO_URUT_11): Hapus properti sisa dari toJson ---
      // 'subtitles': { ... } // <-- DIHAPUS
      // 'transition': { ... } // <-- DIHAPUS
      // 'introMotion': _buildIntroMotionJson(), // <-- DIHAPUS
      // 'sceneMotion': _buildSceneMotionJson(), // <-- DIHAPUS
      // 'introMusicUrl': introMusicUrl, // <-- DIHAPUS
      // --- AKHIR PENYESUAIAN VEO ---
    };
  }

  // --- KATEGORI_PENYESUAIAN_VEO (NO_URUT_12): Hapus parser motion ---
  // (Fungsi _parseSceneMotionBehavior() DIHAPUS)
  // --- AKHIR PENYESUAIAN VEO ---

  // --- KATEGORI_ISOLASI_VEO (Aturan #3): Nama Class Disesuaikan ---
  factory VisualSettingsVeo.fromJson(Map<String, dynamic>? json) {
  // --- AKHIR ISOLASI VEO ---
    if (json == null) {
      // --- KATEGORI_ISOLASI_VEO (Aturan #3): Nama Class Disesuaikan ---
      return VisualSettingsVeo.defaultSettingsWithTitle("");
      // --- AKHIR ISOLASI VEO ---
    }

    // --- KATEGORI_PENYESUAIAN_VEO (NO_URUT_13): Hapus parser sisa ---
    // (Logika parsing subtitleMap DIHAPUS)
    // (Logika parsing introMotionMap DIHAPUS)
    // (Logika parsing loadedSubtitle... DIHAPUS)
    // (Logika parsing loadedIntroMusicUrl DIHAPUS)
    // --- AKHIR PENYESUAIAN VEO ---
    
    // --- KATEGORI_ISOLASI_VEO (Aturan #3): Nama Class Disesuaikan ---
    return VisualSettingsVeo(
      titleSettings: TextOverlaySettingsVeo.fromJson(
          json['titleOverlay'] as Map<String, dynamic>?),
      descriptionSettings: TextOverlaySettingsVeo.fromJson(
          json['descriptionOverlay'] as Map<String, dynamic>?),
    // --- AKHIR ISOLASI VEO ---

      // --- KATEGORI_PENYESUAIAN_VEO (NO_URUT_14): Hapus properti sisa dari fromJson ---
      // (Semua properti subtitle... DIHAPUS)
      // (Semua properti transition... DIHAPUS)
      // (Semua properti introMotion... DIHAPUS)
      // (Semua properti sceneMotion... DIHAPUS)
      // (Properti introMusicUrl DIHAPUS)
      // --- AKHIR PENYESUAIAN VEO ---
    );
  }
}

// =======================================================================
// === HELPER ASPEK RASIO ===
// =======================================================================

double _calculateAspectRatio(String? ratioString) {
  if (ratioString == null || ratioString.isEmpty) {
    return 16 / 9;
  }
  final parts = ratioString.split(':');
  if (parts.length == 2) {
    final double? width = double.tryParse(parts[0]);
    final double? height = double.tryParse(parts[1]);
    if (width != null && height != null && height != 0) {
      return width / height;
    }
  }
  return 16 / 9;
}

// =======================================================================
// === STATE NOTIFIER & PROVIDER ===
// =======================================================================

// --- KATEGORI_ARSITEKTUR: Refaktor Notifier (Perbaikan Bug "Mental") ---
// --- KATEGORI_ISOLASI_VEO (Aturan #3): Nama Class Disesuaikan ---
class VisualSettingsVeoNotifier extends StateNotifier<VisualSettingsVeo> {
// --- AKHIR ISOLASI VEO ---
  final String projectId;
  // --- KATEGORI_ISOLASI_VEO (Aturan #3): Tipe Service Disesuaikan ---
  final FirestoreVeoService _firestoreService;
  // --- AKHIR ISOLASI VEO ---
  final AutoDisposeStateNotifierProviderRef _ref;
  
  // --- KATEGORI_ARSITEKTUR: Tambahan untuk state-safe initialization ---
  StreamSubscription? _projectSubscription;
  bool _isInitialized = false; // Flag untuk mencegah overwrite state
  // --- AKHIR TAMBAHAN ---

  // --- KATEGORI_ISOLASI_VEO (Aturan #3): Nama Class Disesuaikan ---
  VisualSettingsVeoNotifier(
    VisualSettingsVeo initialState, // Ini akan menjadi state 'loading' palsu
  // --- AKHIR ISOLASI VEO ---
    this.projectId,
    this._firestoreService,
    this._ref,
  ) : super(initialState) {
    // --- KATEGORI_ARSITEKTUR: Panggil listener untuk inisialisasi state ---
    _listenToProjectStream();
    // --- AKHIR PERBAIKAN ---
  }

  // --- KATEGORI_ARSITEKTUR: Fungsi baru untuk inisialisasi state ---
  void _listenToProjectStream() {
    _projectSubscription?.cancel();
    // Kita 'watch' stream di sini, di dalam notifier
    // --- KATEGORI_PERBAIKAN_ISOLASI (VEO): Perbaiki typo nama provider (4 LOKASI) ---
    _projectSubscription = _ref.watch(projectVeoStreamProvider(projectId).stream)
        .listen((projectData) {
    // --- AKHIR PERBAIKAN ---

      // HANYA set state dari stream JIKA kita belum diinisialisasi.
      if (!_isInitialized) {
        debugPrint("[$projectId] Notifier (Veo) received first project data. Initializing state...");
        
        final projectTitle = (projectData as dynamic).title ?? "";
        Map<String, dynamic>? settingsMap;
        final data = projectData as dynamic;

        // Logika Pemuatan Prioritas (sama seperti sebelumnya)
        try {
          if (data != null &&
              data.renderPacket is Map<String, dynamic> &&
              data.renderPacket['styleSettings'] is Map<String, dynamic>) {
            settingsMap =
                data.renderPacket['styleSettings'] as Map<String, dynamic>;
            debugPrint(
                '[$projectId] (Veo) Initializing state from renderPacket.styleSettings.');
          } else if (data != null && data.visualSettings is Map<String, dynamic>) {
            settingsMap = data.visualSettings as Map<String, dynamic>;
            debugPrint(
                '[$projectId] (Veo) Initializing state from legacy visualSettings.');
          }
        } catch (e) {
          debugPrint('[$projectId] (Veo) Error accessing dynamic properties: $e');
        }

        // Logika Pengecekan (sama seperti sebelumnya)
        if (settingsMap != null) {
          try {
            // --- KATEGORI_ISOLASI_VEO (Aturan #3): Nama Class Disesuaikan ---
            final parsedSettings = VisualSettingsVeo.fromJson(settingsMap);
            // --- AKHIR ISOLASI VEO ---
            
            // --- KATEGORI_PERBAIKAN_BUG: Logika Injeksi yang Salah DIHAPUS ---
            state = parsedSettings;
            debugPrint(
                '[$projectId] (Veo) Successfully parsed visual settings.');
          } catch (e) {
            debugPrint(
                '[$projectId] (Veo) Error parsing settings map, using default with title. Error: $e');
            // --- KATEGORI_ISOLASI_VEO (Aturan #3): Nama Class Disesuaikan ---
            state = VisualSettingsVeo.defaultSettingsWithTitle(projectTitle);
            // --- AKHIR ISOLASI VEO ---
          }
        } else {
          // Tidak ada setting tersimpan, gunakan default (dengan judul proyek)
          debugPrint(
              '[$projectId] (Veo) visualSettings/renderPacket field missing, using default with title.');
          // --- KATEGORI_ISOLASI_VEO (Aturan #3): Nama Class Disesuaikan ---
          state = VisualSettingsVeo.defaultSettingsWithTitle(projectTitle);
          // --- AKHIR ISOLASI VEO ---
        }

        _isInitialized = true; // Tandai sebagai sudah diinisialisasi
      }
    },
    onError: (e) {
      // Tangani jika stream error saat load
      if (!_isInitialized) {
        debugPrint('[$projectId] (Veo) Error loading project stream ($e), using default settings.');
        // --- KATEGORI_ISOLASI_VEO (Aturan #3): Nama Class Disesuaikan ---
        state = VisualSettingsVeo.defaultSettingsWithTitle(""); // Error state
        // --- AKHIR ISOLASI VEO ---
        _isInitialized = true; // Tetap tandai agar tidak mencoba lagi
      }
    });
  }

  // --- KATEGORI_ARSITEKTUR: Wajib override dispose ---
  @override
  void dispose() {
    _projectSubscription?.cancel(); // Hentikan listener
    super.dispose();
  }
  // --- AKHIR PERBAIKAN ---

  // --- Helper Pembatas (Clamp) ---
  // --- KATEGORI_PERBAIKAN_SKALA: Perbarui Clamp ---
  double _clampFontSize(double size) => size.clamp(6.0, 100.0); // <-- DIUBAH DARI 30.0
  // --- AKHIR PERBAIKAN ---
  double _clampWidthFactor(double factor) => factor.clamp(0.1, 1.0);
  int _clampMaxLines(int count) => count.clamp(1, 10);
  double _clampVerticalAlignment(double align) => align.clamp(-1.0, 1.0);

  // --- Metode Update State (Judul) ---
  void updateTitleText(String text) =>
      state = state.copyWith(titleSettings: state.titleSettings.copyWith(text: text));
  void updateTitleEffect(TextEffect effect) =>
      state = state.copyWith(titleSettings: state.titleSettings.copyWith(effect: effect));
  void updateTitleBaseFontSize(double size) => state = state.copyWith(
      titleSettings:
          state.titleSettings.copyWith(baseFontSize: _clampFontSize(size)));
  void updateTitleColor(Color color) =>
      state = state.copyWith(titleSettings: state.titleSettings.copyWith(color: color));
  void updateTitleStartTime(double time) =>
      state = state.copyWith(titleSettings: state.titleSettings.copyWith(startTime: time));
  void updateTitleDuration(double duration) =>
      state = state.copyWith(titleSettings: state.titleSettings.copyWith(duration: duration));
  void updateTitleBlockWidthFactor(double factor) => state = state.copyWith(
      titleSettings: state.titleSettings
          .copyWith(textBlockWidthFactor: _clampWidthFactor(factor)));
  void updateTitleMaxLines(int lines) => state = state.copyWith(
      titleSettings:
          state.titleSettings.copyWith(maxLines: _clampMaxLines(lines)));
  void updateTitleVerticalAlignment(double align) => state = state.copyWith(
      titleSettings: state.titleSettings
          .copyWith(verticalAlignment: _clampVerticalAlignment(align)));

  // --- Metode Update State (Deskripsi) ---
  void updateDescriptionText(String text) => state =
      state.copyWith(descriptionSettings: state.descriptionSettings.copyWith(text: text));
  void updateDescriptionEffect(TextEffect effect) => state = state.copyWith(
      descriptionSettings: state.descriptionSettings.copyWith(effect: effect));
  void updateDescriptionBaseFontSize(double size) => state = state.copyWith(
      descriptionSettings: state.descriptionSettings
          .copyWith(baseFontSize: _clampFontSize(size)));
  void updateDescriptionColor(Color color) => state =
      state.copyWith(descriptionSettings: state.descriptionSettings.copyWith(color: color));
  void updateDescriptionStartTime(double time) => state = state.copyWith(
      descriptionSettings: state.descriptionSettings.copyWith(startTime: time));
  void updateDescriptionDuration(double duration) => state = state.copyWith(
      descriptionSettings: state.descriptionSettings.copyWith(duration: duration));
  void updateDescriptionBlockWidthFactor(double factor) => state = state.copyWith(
      descriptionSettings: state.descriptionSettings
          .copyWith(textBlockWidthFactor: _clampWidthFactor(factor)));
  void updateDescriptionMaxLines(int lines) => state = state.copyWith(
      descriptionSettings: state.descriptionSettings
          .copyWith(maxLines: _clampMaxLines(lines)));
  void updateDescriptionVerticalAlignment(double align) => state = state.copyWith(
      descriptionSettings: state.descriptionSettings
          .copyWith(verticalAlignment: _clampVerticalAlignment(align)));

  // --- KATEGORI_PENYESUAIAN_VEO (NO_URUT_15): Hapus Notifier Subtitle, Motion, Transisi, Musik ---
  // (Semua method updateSubtitle... DIHAPUS)
  // (Semua method updateTransition... DIHAPUS)
  // (Semua method updateIntroMotion... DIHAPUS)
  // (Semua method updateSceneMotion... DIHAPUS)
  // (Semua method updateIntroMusicUrl... DIHAPUS)
  // --- AKHIR PENYESUAIAN VEO ---

  // --- Fungsi Save ke Firestore ---
Future<void> saveSettingsToFirestore() async {
  try {
    // --- KATEGORI_PERBAIKAN_ARSITEKTUR (Mencegah Overwrite Data) ---
    // 1. Dapatkan data 'renderPacket' yang ADA SAAT INI dari Firestore
    debugPrint(
        "saveSettings (Veo): Reading current project data first to prevent overwrite...");
    final docSnapshot = await _firestoreService.getProject(projectId);
    final data = docSnapshot.data();

    Map<String, dynamic> currentRenderPacket = {};

    // Ambil renderPacket yang ada, atau buat map kosong jika tidak ada
    if (data != null &&
        data.containsKey('renderPacket') &&
        data['renderPacket'] is Map<String, dynamic>) {
      debugPrint("saveSettings (Veo): Found existing renderPacket.");
      currentRenderPacket =
          Map<String, dynamic>.from(data['renderPacket']);
    } else {
      debugPrint(
          "saveSettings (Veo): No existing renderPacket found, will create new one.");
    }
    // --- AKHIR LANGKAH 1 ---

    // 2. Dapatkan data state UI saat ini dan konversikan ke JSON
    
    // --- KATEGORI_PERBAIKAN_ISOLASI (VEO): Perbaiki typo nama provider (4 LOKASI) ---
    final projectData =
        _ref.read(projectVeoStreamProvider(projectId)).asData?.value;
    // --- AKHIR PERBAIKAN ---

    final ratioString =
        (projectData as dynamic)?.aspectRatio; // Cast untuk akses properti
    final double aspectRatioValue = _calculateAspectRatio(ratioString);
    final newStyleSettingsMap = state.toJson(aspectRatioValue);
    // --- AKHIR LANGKAH 2 ---

    // 3. GABUNGKAN data: Timpa HANYA 'styleSettings'
    currentRenderPacket['styleSettings'] = newStyleSettingsMap;
    // --- AKHIR LANGKAH 3 ---

    // 4. Simpan KEMBALI KESELURUHAN renderPacket yang sudah digabungkan
    await _firestoreService.updateProject(
      projectId,
      {'renderPacket': currentRenderPacket}, // <-- Kirim map LENGKAP
    );
    // --- AKHIR PERBAIKAN ---

    debugPrint(
        '✅ (Veo) Visual settings safely merged into renderPacket.styleSettings for project $projectId (Ratio: $aspectRatioValue)');

    // --- KATEGORI_PERBAIKAN_ISOLASI (VEO): Perbaiki typo nama provider (4 LOKASI) ---
    _ref.invalidate(projectVeoStreamProvider(projectId));
    // --- AKHIR PERBAIKAN ---

  } catch (e) {
    debugPrint('❌ (Veo) Error saving visual settings for project $projectId: $e');
    throw Exception('Failed to save settings: $e');
  }
}

  // --- Fungsi Load dari Firestore ---
  Future<void> loadSettingsFromFirestore() async {
    debugPrint('Attempting to manually load settings for $projectId (Veo)...');
    try {
      final docSnapshot = await _firestoreService.getProject(projectId);
      final data = docSnapshot.data();

      Map<String, dynamic>? settingsMap;
      final currentTitle = data?['title'] as String? ?? "";

      if (data != null &&
          data.containsKey('renderPacket') &&
          data['renderPacket'] is Map &&
          (data['renderPacket'] as Map).containsKey('styleSettings') &&
          data['renderPacket']['styleSettings'] is Map) {
        debugPrint(
            'Found new renderPacket.styleSettings map in Firestore for $projectId (Veo).');
        settingsMap =
            data['renderPacket']['styleSettings'] as Map<String, dynamic>;
      } else if (data != null &&
          data.containsKey('visualSettings') &&
          data['visualSettings'] is Map) {
        debugPrint(
            'Found legacy visualSettings map in Firestore for $projectId (Veo).');
        settingsMap = data['visualSettings'] as Map<String, dynamic>;
      }

      if (settingsMap != null) {
        // --- KATEGORI_ISOLASI_VEO (Aturan #3): Nama Class Disesuaikan ---
        final loadedSettings = VisualSettingsVeo.fromJson(settingsMap);
        // --- AKHIR ISOLASI VEO ---
        final titleOverlayMap =
            settingsMap['titleOverlay'] as Map<String, dynamic>?;
        final savedTitleText = titleOverlayMap?['text'] as String?;

        if ((savedTitleText == null || savedTitleText.isEmpty) && currentTitle.isNotEmpty) {
          // --- KATEGORI_PERBAIKAN_BUG: Logika Injeksi yang Salah DIHAPUS ---
          state = loadedSettings;
          debugPrint('Injected project title into loaded settings. (THIS SHOULD NOT HAPPEN)');
        } else {
          state = loadedSettings;
        }

        debugPrint('✅ (Veo) Visual settings loaded and state updated for project $projectId');
      } else {
        // --- KATEGORI_ISOLASI_VEO (Aturan #3): Nama Class Disesuaikan ---
        state = VisualSettingsVeo.defaultSettingsWithTitle(currentTitle);
        // --- AKHIR ISOLASI VEO ---
        debugPrint(
            '⚙️ (Veo) No valid visualSettings or renderPacket map found for $projectId, state reset to default.');
      }
    } catch (e) {
      debugPrint('❌ (Veo) Error loading visual settings for project $projectId: $e');
    }
  }

  /// Mengatur ulang semua pengaturan visual ke nilai default pabrik.
  void resetToDefaults() {
    // --- KATEGORI_PERBAIKAN_ISOLASI (VEO): Perbaiki typo nama provider (4 LOKASI) ---
    final projectData =
        _ref.read(projectVeoStreamProvider(projectId)).asData?.value;
    // --- AKHIR PERBAIKAN ---
    final String currentTitle = (projectData as dynamic)?.title ?? "";

    // --- KATEGORI_ISOLASI_VEO (Aturan #3): Nama Class Disesuaikan ---
    state = VisualSettingsVeo.defaultSettingsWithTitle(currentTitle);
    // --- AKHIR ISOLASI VEO ---

    debugPrint('Visual settings for project $projectId (Veo) reset to default.');
  }
}

// --- Provider (Family dengan projectId) ---
// --- KATEGORI_ARSITEKTUR: Definisi Provider Dirombak ---
// --- KATEGORI_ISOLASI_VEO (Aturan #3): Nama Provider Disesuaikan ---
final visualSettingsVeoProvider =
    StateNotifierProvider.autoDispose.family<VisualSettingsVeoNotifier, VisualSettingsVeo, String>(
  (ref, projectId) {
// --- AKHIR ISOLASI VEO ---
    // 1. Dapatkan dependensi yang diperlukan
    // --- KATEGORI_ISOLASI_VEO (Aturan #3): Ref Provider Disesuaikan ---
    final firestoreService = ref.watch(firestoreVeoServiceProvider);
    // --- AKHIR ISOLASI VEO ---

    // 2. Buat Notifier dengan state 'loading' palsu.
    // --- KATEGORI_ISOLASI_VEO (Aturan #3): Nama Class Disesuaikan ---
    return VisualSettingsVeoNotifier(
      VisualSettingsVeo.defaultSettingsWithTitle(""), // State 'loading' sementara
    // --- AKHIR ISOLASI VEO ---
      projectId,
      firestoreService,
      ref
    );
  },
);
// --- AKHIR REFAKTOR ---