//................................................................//
// NAMA FILE: VISUAL_SETTINGS_PROVIDER.DART                       //
// PATH: LIB/PROVIDERS/VISUAL_SETTINGS_PROVIDER.DART              //
//................................................................//

//No ke-1.........................................................//
// IMPORT DEPENDENSI & KONSTANTA FFMPEG                           //
import 'dart:async';
import 'dart:math'; // <-- KATEGORI_ARSITEKTUR_INTRO_MUSIK: Diperlukan untuk Random()
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Digunakan di FirestoreService

// Import model, view model, dan service yang diperlukan
import '../view_model/timeline_view_model.dart'; // Asumsikan ini berisi projectStreamProvider
import '../services/firestore_service.dart'; // Pastikan path ini benar
import '../models/video_project.dart'; // Model VideoProject

// =======================================================================
// === FIREBASE SERVICE PROVIDER (Harus didefinisikan) ===
// =======================================================================

// Provider untuk FirestoreService
final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService();
});

// =======================================================================
// === KONSTANTA FFMPEG (Logika Motion) ===
// =======================================================================

const String _kPi = '3.1415926535';
const String _kIntensityDefault = '0.3'; // Intensitas Zoom/Pan

// --- A. Variabel Asli (80/20) untuk INTRO ---
// (Tetap 80/20 sesuai permintaan Anda)
const String _kProgressVar = 'min(on/(d*0.8),1)';
const String _kEasing = '(1-cos(${_kPi}*${_kProgressVar}))/2';
const String _kBaseZoomIn = '(1+${_kEasing}*${_kIntensityDefault})';
const String _kBaseZoomOut =
    '(1+${_kIntensityDefault}-${_kEasing}*${_kIntensityDefault})';
const String _kPanYCenterIn = 'ih/2-ih/(2*${_kBaseZoomIn})';
const String _kPanYCenterOut = 'ih/2-ih/(2*${_kBaseZoomOut})';
const String _kPanXCenterIn = 'iw/2-iw/(2*${_kBaseZoomIn})';
const String _kPanXCenterOut = 'iw/2-iw/(2*${_kBaseZoomOut})';

// --- B. Variabel (70/30) Easing (Cos) untuk SCENES ---
// --- KATEGORI_RESEP_FFMPEG (NO_URUT_01) ---
// (Waktu diam 30% untuk mengurangi getar/goyang)
const String _kProgressVar_Scene = 'min(on/(d*0.7),1)'; // <-- DIUBAH KE 0.7 (Permintaan 70/30)
// --- AKHIR PERUBAHAN ---
const String _kEasing_Scene = '(1-cos(${_kPi}*${_kProgressVar_Scene}))/2';
const String _kBaseZoomIn_Scene = '(1+${_kEasing_Scene}*${_kIntensityDefault})';
const String _kBaseZoomOut_Scene =
    '(1+${_kIntensityDefault}-${_kEasing_Scene}*${_kIntensityDefault})';
const String _kPanYCenterIn_Scene = 'ih/2-ih/(2*${_kBaseZoomIn_Scene})';
const String _kPanYCenterOut_Scene = 'ih/2-ih/(2*${_kBaseZoomOut_Scene})';
const String _kPanXCenterIn_Scene = 'iw/2-iw/(2*${_kBaseZoomIn_Scene})';
const String _kPanXCenterOut_Scene = 'ih/2-iw/(2*${_kBaseZoomOut_Scene})';

// --- C. Variabel BARU (70/30) LINEAR untuk RANDOM ---
// (Menggunakan progress 70/30 tapi TANPA easing 'cos')
const String _kBaseZoomIn_Scene_Linear =
    '(1+${_kProgressVar_Scene}*${_kIntensityDefault})';
const String _kBaseZoomOut_Scene_Linear =
    '(1+${_kIntensityDefault}-${_kProgressVar_Scene}*${_kIntensityDefault})';
const String _kPanYCenterIn_Scene_Linear =
    'ih/2-ih/(2*${_kBaseZoomIn_Scene_Linear})';
const String _kPanYCenterOut_Scene_Linear =
    'ih/2-ih/(2*${_kBaseZoomOut_Scene_Linear})';
const String _kPanXCenterIn_Scene_Linear =
    'iw/2-iw/(2*${_kBaseZoomIn_Scene_Linear})';
const String _kPanXCenterOut_Scene_Linear =
    'iw/2-iw/(2*${_kBaseZoomOut_Scene_Linear})';

// --- KATEGORI_MODIFIKASI: Hapus "Option 3" (NO_URUT_01) ---
// --- Variabel D (Option 3) DIHAPUS ---
// --- AKHIR MODIFIKASI ---

/// Resep Motion Scene Standar (Intensitas 0.3)
/// --- KATEGORI_PERBAIKAN_BUG (Getar/Goyang) ---
/// Resep ini sekarang menggunakan variabel _Scene (70/30) - [INI MENGGUNAKAN COS]
final Map<String, String> kSceneMotionRecipes = {
  // 1. Zoom Tengah
  'zoom_in_center':
      "z=${_kBaseZoomIn_Scene}:x=${_kPanXCenterIn_Scene}:y=${_kPanYCenterIn_Scene}",
  // 2. Zoom Out Tengah
  'zoom_out_center':
      "z=${_kBaseZoomOut_Scene}:x=${_kPanXCenterOut_Scene}:y=${_kPanYCenterOut_Scene}",
  // 3. Pan Kanan (Zoom In ke Kanan)
  'pan_right':
      "z=${_kBaseZoomIn_Scene}:x=iw-iw/${_kBaseZoomIn_Scene}:y=${_kPanYCenterIn_Scene}",
  // 4. Zoom In Atas
  'zoom_in_top': "z=${_kBaseZoomIn_Scene}:x=${_kPanXCenterIn_Scene}:y=0",
  // 5. Pan Kiri (Zoom In ke Kiri)
  'pan_left': "z=${_kBaseZoomIn_Scene}:x=0:y=${_kPanYCenterIn_Scene}",
  // 6. Zoom In Bawah
  'zoom_in_bottom':
      "z=${_kBaseZoomIn_Scene}:x=${_kPanXCenterIn_Scene}:y=ih-ih/${_kBaseZoomIn_Scene}",
  // 7. Resep 'None'
  'none': "z=1:x=0:y=0",
};
// --- AKHIR PERBAIKAN ---

// --- KATEGORI_MODIFIKASI: Ganti Resep Default (NO_URUT_01) ---
/// Urutan Default untuk Scene
const List<String> kDefaultSceneMotionNames = [
  'rand_zoom_in_center', // <-- MODIFIKASI: Menggunakan resep Linear 70/30
  'rand_zoom_out_center', // <-- MODIFIKASI: Menggunakan resep Linear 70/30
  'pan_right', // <-- Tetap: Menggunakan resep Cosine 70/30
  'zoom_in_top', // <-- Tetap: Menggunakan resep Cosine 70/30
  'pan_left', // <-- Tetap: Menggunakan resep Cosine 70/30
  'zoom_in_bottom', // <-- Tetap: Menggunakan resep Cosine 70/30
];
// --- AKHIR MODIFIKASI ---

/// Resep Motion "Mengalun" Acak (Intensitas 0.3)
/// --- KATEGORI_MODIFIKASI: Menggunakan Gerakan LINEAR (Tanpa Easing/Cos) ---
/// Resep ini sekarang menggunakan variabel _Scene_Linear (70/30)
final Map<String, String> kRandomMotionRecipes = {
  // --- IN (1.0 -> 1.3) ---
  'rand_zoom_in_center':
      'z=${_kBaseZoomIn_Scene_Linear}:x=${_kPanXCenterIn_Scene_Linear}:y=${_kPanYCenterIn_Scene_Linear}',
  'rand_pan_left_in':
      'z=${_kBaseZoomIn_Scene_Linear}:x=0:y=${_kPanYCenterIn_Scene_Linear}',
  'rand_pan_right_in':
      'z=${_kBaseZoomIn_Scene_Linear}:x=iw-iw/${_kBaseZoomIn_Scene_Linear}:y=${_kPanYCenterIn_Scene_Linear}',

  // --- OUT (1.3 -> 1.0) ---
  'rand_zoom_out_center':
      'z=${_kBaseZoomOut_Scene_Linear}:x=${_kPanXCenterOut_Scene_Linear}:y=${_kPanYCenterOut_Scene_Linear}',
  'rand_pan_left_out':
      'z=${_kBaseZoomOut_Scene_Linear}:x=0:y=${_kPanYCenterOut_Scene_Linear}',
  'rand_pan_right_out':
      'z=${_kBaseZoomOut_Scene_Linear}:x=iw-iw/${_kBaseZoomOut_Scene_Linear}:y=${_kPanYCenterOut_Scene_Linear}',

  // --- NONE (Tidak ada pergerakan) ---
  'none': "z=1:x=0:y=0",
}; // <--- PENUTUP MAP YANG HILANG DITAMBAHKAN DI SINI

// --- KATEGORI_MODIFIKASI: Hapus "Option 3" (NO_URUT_02) ---
// Resep Motion "Option 3" DIHAPUS
// --- AKHIR MODIFIKASI ---

/// Urutan Default untuk Random Motion
const List<String> kRandomSceneMotionNames = [
  // <--- DEFENISI BARU DITAMBAHKAN
  'rand_zoom_in_center',
  'rand_zoom_out_center',
  'rand_pan_right_in',
  'rand_pan_left_out',
]; // <--- Tambahkan daftar nama ini untuk digunakan di _buildSceneMotionJson()

// --- KATEGORI_MODIFIKASI: Hapus "Option 3" (NO_URUT_03) ---
// Urutan Default untuk "Option 3" DIHAPUS
// --- AKHIR MODIFIKASI ---
//................................................................//

//No ke-2.........................................................//
// ENUM & HELPER KONVERSI                                         //
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
  if (fontSize == null) return 43.0; // Fallback ke default Judul baru
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
  return 43.0; // Fallback ke default Judul baru
  // --- AKHIR MODIFIKASI ---
}
// --- AKHIR PERBAIKAN ---
//................................................................//

//No ke-3.........................................................//
// CLASS TEXT OVERLAY SETTINGS                                    //
@immutable
class TextOverlaySettings {
  final String text;
  final TextEffect effect;
  final double baseFontSize;
  final Color color;
  final double startTime;
  final double duration;
  final double textBlockWidthFactor; // (0.1 - 1.0)
  final int maxLines;
  final double verticalAlignment; // (Flutter: -1.0 s/d 1.0)

  const TextOverlaySettings({
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

  TextOverlaySettings copyWith({
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
    return TextOverlaySettings(
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
    // Multiplier sekarang SELALU 1.0, sesuai permintaan Anda
    double multiplier = 1.0;
    // if (aspectRatioValue < 1.1) { // <-- DIHAPUS
    //    multiplier = 0.6; // (LAMA)
    // } // <-- DIHAPUS
    final double responsiveFontSize = baseFontSize * multiplier;
    // --- AKHIR PERBAIKAN ---

    // Hitung boxWidth absolut agar FFmpeg tidak error
    // Asumsi: 16:9 = 1920px, 9:16 = 1080px (sisi terkecil video dasar)
    final double baseVideoDimension =
        aspectRatioValue > 1.6 ? 1920 : 1080;
    final double boxWidthPixels = baseVideoDimension * textBlockWidthFactor;

    debugPrint(
        "🧩 [TextOverlaySettings.toJson] aspect=$aspectRatioValue, boxWidth=${boxWidthPixels.round()}, factor=$textBlockWidthFactor");

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

  factory TextOverlaySettings.fromJson(Map<String, dynamic>? json) {
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
      return TextOverlaySettings(
        text: "",
        effect: TextEffect.fadeInOut,
        baseFontSize: 43.0, // <-- Ganti fallback ke default Judul baru
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
      loadedBaseFontSize = (json['baseFontSize'] as num?)?.toDouble() ?? 43.0; // <-- Ganti fallback
      // --- AKHIR MODIFIKASI ---
    } else if (json.containsKey('fontSize')) {
      loadedBaseFontSize =
          _baseSizeFromLegacyNumeric((json['fontSize'] as num?)?.toDouble());
    } else if (json.containsKey('size')) {
      loadedBaseFontSize = _baseSizeFromLegacyEnum(json['size'] as String?);
    } else {
      // --- KATEGORI_MODIFIKASI_KONSTANTA NO_URUT_02 (Target 6) ---
      loadedBaseFontSize = 43.0; // <-- Ganti fallback
      // --- AKHIR MODIFIKASI ---
    }
    // --- AKHIR PERBAIKAN ---

    final double loadedWidthFactor =
        (json['textBlockWidthFactor'] as num?)?.toDouble() ?? 0.9;
    final int loadedMaxLines = (json['maxLines'] as int?) ?? 3;
    final double loadedVAlign =
        (json['verticalAlignment'] as num?)?.toDouble() ?? -0.8;

    return TextOverlaySettings(
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
//................................................................//

//No ke-4.........................................................//
// CLASS VISUAL SETTINGS (MODEL UTAMA)                            //
@immutable
class VisualSettings {
  final TextOverlaySettings titleSettings;
  final TextOverlaySettings descriptionSettings;

  // Pengaturan Subtitle
  final bool showSubtitles;
  final double subtitleBaseFontSize;
  final double subtitleBlockWidthFactor;
  final int subtitleChunkCount;
  final double subtitleDurationMultiplier;
  final int subtitleMaxLines;
  final double subtitleVerticalAlignment; // (Flutter: -1.0 s/d 1.0)

  // Lainnya
  final String transitionType;
  final double transitionDuration;
  final String introMotionType;
  final String sceneMotionBehavior;
  
  // --- KATEGORI_ARSITEKTUR_INTRO_MUSIK (NO_URUT_01) ---
  final String introMusicUrl; 
  // --- AKHIR PERUBAHAN ---

  // --- KATEGORI_FITUR_BARU (OVERLAY_EFFECTS) ---
  final bool useAssetOverlayEffects;
  // --- AKHIR TAMBAHAN ---

  const VisualSettings({
    required this.titleSettings,
    required this.descriptionSettings,
    // Subtitle
    required this.showSubtitles,
    required this.subtitleBaseFontSize,
    required this.subtitleBlockWidthFactor,
    required this.subtitleChunkCount,
    required this.subtitleDurationMultiplier,
    required this.subtitleMaxLines,
    required this.subtitleVerticalAlignment,
    // Lainnya
    required this.transitionType,
    required this.transitionDuration,
    required this.introMotionType,
    required this.sceneMotionBehavior,
    // --- KATEGORI_ARSITEKTUR_INTRO_MUSIK (NO_URUT_02) ---
    required this.introMusicUrl, 
    // --- AKHIR PERUBAHAN ---
    // --- KATEGORI_FITUR_BARU (OVERLAY_EFFECTS) ---
    required this.useAssetOverlayEffects,
    // --- AKHIR TAMBAHAN ---
  });

  VisualSettings copyWith({
    TextOverlaySettings? titleSettings,
    TextOverlaySettings? descriptionSettings,
    // Subtitle
    bool? showSubtitles,
    double? subtitleBaseFontSize,
    double? subtitleBlockWidthFactor,
    int? subtitleChunkCount,
    double? subtitleDurationMultiplier,
    int? subtitleMaxLines,
    double? subtitleVerticalAlignment,
    // Lainnya
    String? transitionType,
    double? transitionDuration,
    String? introMotionType,
    String? sceneMotionBehavior,
    // --- KATEGORI_ARSITEKTUR_INTRO_MUSIK (NO_URUT_03) ---
    String? introMusicUrl, 
    // --- AKHIR PERUBAHAN ---
    // --- KATEGORI_FITUR_BARU (OVERLAY_EFFECTS) ---
    bool? useAssetOverlayEffects,
    // --- AKHIR TAMBAHAN ---
  }) {
    return VisualSettings(
      titleSettings: titleSettings ?? this.titleSettings,
      descriptionSettings: descriptionSettings ?? this.descriptionSettings,
      // Subtitle
      showSubtitles: showSubtitles ?? this.showSubtitles,
      subtitleBaseFontSize: subtitleBaseFontSize ?? this.subtitleBaseFontSize,
      subtitleBlockWidthFactor:
          subtitleBlockWidthFactor ?? this.subtitleBlockWidthFactor,
      subtitleChunkCount: subtitleChunkCount ?? this.subtitleChunkCount,
      subtitleDurationMultiplier:
          subtitleDurationMultiplier ?? this.subtitleDurationMultiplier,
      subtitleMaxLines: subtitleMaxLines ?? this.subtitleMaxLines,
      subtitleVerticalAlignment:
          subtitleVerticalAlignment ?? this.subtitleVerticalAlignment,
      // Lainnya
      transitionType: transitionType ?? this.transitionType,
      transitionDuration: transitionDuration ?? this.transitionDuration,
      introMotionType: introMotionType ?? this.introMotionType,
      sceneMotionBehavior: sceneMotionBehavior ?? this.sceneMotionBehavior,
      // --- KATEGORI_ARSITEKTUR_INTRO_MUSIK (NO_URUT_04) ---
      introMusicUrl: introMusicUrl ?? this.introMusicUrl, 
      // --- AKHIR PERUBAHAN ---
      // --- KATEGORI_FITUR_BARU (OVERLAY_EFFECTS) ---
      useAssetOverlayEffects: useAssetOverlayEffects ?? this.useAssetOverlayEffects,
      // --- AKHIR TAMBAHAN ---
    );
  }

  /// Mengembalikan pengaturan default baru dengan judul proyek yang diberikan.
  static VisualSettings defaultSettingsWithTitle(String projectTitle) {
    // --- KATEGORI_ARSITEKTUR_INTRO_MUSIK (NO_URUT_05) ---
    // Logika acak untuk memilih 1 dari 20 lagu
    final trackNumber = Random().nextInt(20) + 1; // Menghasilkan 1-20
    // Bangun URL bebas-token berdasarkan path file Anda yang benar
    final defaultIntroMusicUrl =
        'https://firebasestorage.googleapis.com/v0/b/majiku-5b07e.firebasestorage.app/o/assets%2Fmusic%2Fintro_music%20$trackNumber.mp3?alt=media';
    // --- AKHIR PERUBAHAN ---

    // --- KATEGORI_PERBAIKAN_SKALA: Ganti default ---
    // --- KATEGORI_MODIFIKASI_KONSTANTA NO_URUT_01 ---
    return VisualSettings(
      titleSettings: TextOverlaySettings(
        text: projectTitle, // <-- Perbaikan dari "UNTITLED"
        effect: TextEffect.fadeInOut,
        baseFontSize: 55.0, // <-- [TARGET 1] DIUBAH
        color: Colors.white,
        startTime: 3.0,
        duration: 7.0,
        textBlockWidthFactor: 0.9,
        maxLines: 3,
        verticalAlignment: -0.8, // 10% dari atas
      ),
      descriptionSettings: TextOverlaySettings(
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
      // Subtitle
      showSubtitles: false,
      subtitleBaseFontSize: 50.0, // <-- [TARGET 3] DIUBAH
      subtitleBlockWidthFactor: 0.9,
      subtitleChunkCount: 5,
      subtitleDurationMultiplier: 0.8,
      subtitleMaxLines: 4,
      // --- KATEGORI_MODIFIKASI_KONSTANTA NO_URUT_01 (10% dari Bawah) ---
      subtitleVerticalAlignment: 0.8, // 10% dari bawah (DIUBAH DARI 0.9)
      // --- AKHIR MODIFIKASI ---

      // Lainnya
      transitionType: 'fade',
      transitionDuration: 1.0,
      introMotionType: 'zoom_in_center',
      sceneMotionBehavior: 'default',
      // --- KATEGORI_ARSITEKTUR_INTRO_MUSIK (NO_URUT_05) ---
      introMusicUrl: defaultIntroMusicUrl, // <-- Gunakan URL acak yang baru
      // --- AKHIR PERUBAHAN ---
      // --- KATEGORI_FITUR_BARU (OVERLAY_EFFECTS) ---
      useAssetOverlayEffects: false, // Default false untuk optimasi render
      // --- AKHIR TAMBAHAN ---
    );
    // --- AKHIR MODIFIKASI ---
    // --- AKHIR PERBAIKAN ---
  }

  Map<String, dynamic> _buildSceneMotionJson() {
    // --- KATEGORI_MODIFIKASI: Ganti Resep Default (NO_URUT_02) ---
    if (sceneMotionBehavior == 'default') {
      return {
        'behavior': 'default_sequence',
        'list': kDefaultSceneMotionNames.map((nama) {
          // --- LOGIKA BARU UNTUK MENDUKUNG 2 MAP ---
          if (nama.startsWith('rand_')) {
            // Resep 1 & 2 (Linear 70/30)
            return kRandomMotionRecipes[nama] ?? kRandomMotionRecipes['none']!;
          } else {
            // Resep 3-6 (Cosine 70/30)
            return kSceneMotionRecipes[nama] ?? kSceneMotionRecipes['none']!;
          }
          // --- AKHIR LOGIKA BARU ---
        }).toList(),
      };
    }
    // --- AKHIR MODIFIKASI ---
    if (sceneMotionBehavior == 'random') {
      return {
        'behavior': 'random_sequence',
        'list': kRandomSceneMotionNames.map((nama) {
          // Gunakan resep 70/30 untuk adegan
          return kRandomMotionRecipes[nama] ??
              kRandomMotionRecipes['rand_zoom_in_center']!;
        }).toList(),
      };
    }
    // --- KATEGORI_MODIFIKASI: Hapus "Option 3" (NO_URUT_04) ---
    // Blok "if (sceneMotionBehavior == 'option_3')" DIHAPUS
    // --- AKHIR MODIFIKASI ---
    return {
      'behavior': 'none',
      'list': [kSceneMotionRecipes['none']]
    };
  }

  Map<String, dynamic> _buildIntroMotionJson() {
    // --- KATEGORI_PERBAIKAN_BUG (Getar/Goyang) ---
    // Logika ini harus menggunakan resep 80/20 yang ASLI
    // untuk menjaga intro tetap sama.
    
    // 1. Buat Peta 80/20 khusus untuk Intro
    final Map<String, String> kIntroMotionRecipes = {
      'zoom_in_center':
          "z=${_kBaseZoomIn}:x=${_kPanXCenterIn}:y=${_kPanYCenterIn}",
      'zoom_out_center':
          "z=${_kBaseZoomOut}:x=${_kPanXCenterOut}:y=${_kPanYCenterOut}",
      'pan_right':
          "z=${_kBaseZoomIn}:x=iw-iw/${_kBaseZoomIn}:y=${_kPanYCenterIn}",
      'zoom_in_top': "z=${_kBaseZoomIn}:x=${_kPanXCenterIn}:y=0",
      'pan_left': "z=${_kBaseZoomIn}:x=0:y=${_kPanYCenterIn}",
      'zoom_in_bottom':
          "z=${_kBaseZoomIn}:x=${_kPanXCenterIn}:y=ih-ih/${_kBaseZoomIn}",
      'none': "z=1:x=0:y=0",
    };

    // 2. Ambil resep dari Peta 80/20 tersebut
    final String recipe =
        kIntroMotionRecipes[introMotionType] ?? kIntroMotionRecipes['zoom_in_center']!;
    // --- AKHIR PERBAIKAN ---

    return {
      'type': introMotionType,
      'recipe': recipe,
    };
  }

  Map<String, dynamic> toJson(double aspectRatioValue) {
    // --- KATEGORI_PERBAIKAN_SKALA: Hapus penskalaan 60% ---
    double subBaseFontSize = this.subtitleBaseFontSize;
    double subMultiplier = 1.0;
    // if (aspectRatioValue < 1.1) { // <-- DIHAPUS
    //    subMultiplier = 0.6; // (LAMA)
    // } // <-- DIHAPUS
    final double subResponsiveFontSize = subBaseFontSize * subMultiplier;
    // --- AKHIR PERBAIKAN ---

    // Hitung boxWidth absolut untuk subtitles
    final double baseVideoDimension =
        aspectRatioValue > 1.6 ? 1920 : 1080;
    final double subBoxWidthPixels = baseVideoDimension * this.subtitleBlockWidthFactor;
    // --- AKHIR PERBAIKAN ---

    return {
      'titleOverlay': titleSettings.toJson(aspectRatioValue),
      'descriptionOverlay': descriptionSettings.toJson(aspectRatioValue),
      'subtitles': {
        'show': showSubtitles,
        'durationMultiplier': subtitleDurationMultiplier,
        'baseFontSize': subBaseFontSize,
        'fontSize': subResponsiveFontSize, // <-- Sekarang selalu 100%
        'textBlockWidthFactor': subtitleBlockWidthFactor,
        
        // --- KATEGORI_PERBAIKAN_BUG (Konsistensi boxWidth) ---
        // Kirim nilai 'boxWidth' yang sudah matang
        'boxWidth': subBoxWidthPixels.round(),
        // --- AKHIR PERBAIKAN ---
        
        'subtitleChunkCount': subtitleChunkCount,
        'subtitleMaxLines': subtitleMaxLines,
        'subtitleVerticalAlignment': subtitleVerticalAlignment,
      },
      'transition': {'type': transitionType, 'duration': transitionDuration},
      'introMotion': _buildIntroMotionJson(),
      'sceneMotion': _buildSceneMotionJson(),
      // --- KATEGORI_ARSITEKTUR_INTRO_MUSIK (NO_URUT_06) ---
      'introMusicUrl': introMusicUrl, // <-- SIMPAN URL KE JSON
      // --- AKHIR PERUBAHAN ---
      // --- KATEGORI_FITUR_BARU (OVERLAY_EFFECTS) ---
      'useAssetOverlayEffects': useAssetOverlayEffects,
      // --- AKHIR TAMBAHAN ---
    };
  }

  static String _parseSceneMotionBehavior(Map<String, dynamic>? json) {
    final sceneMotionMap = json?['sceneMotion'] as Map<String, dynamic>?;
    final behavior =
        sceneMotionMap?['behavior'] as String? ?? 'default_sequence';

    switch (behavior) {
      case 'random_sequence':
      case 'random':
        return 'random';
      // --- KATEGORI_MODIFIKASI: Hapus "Option 3" (NO_URUT_05) ---
      // case 'option_3' DIHAPUS
      // --- AKHIR MODIFIKASI ---
      case 'none':
        return 'none';
      case 'default_sequence':
      case 'sequence':
      case 'default':
      default:
        return 'default';
    }
  }

  factory VisualSettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return VisualSettings.defaultSettingsWithTitle("");
    }

    final introMotionMap = json['introMotion'] as Map<String, dynamic>?;
    final subtitleMap = json['subtitles'] as Map<String, dynamic>?;

    // --- KATEGORI_PERBAIKAN_SKALA: Ganti default fallback ---
    final double loadedSubtitleBaseFontSize;
    if (subtitleMap != null && subtitleMap.containsKey('baseFontSize')) {
      // --- KATEGORI_MODIFIKASI_KONSTANTA NO_URUT_03 (Target 7) ---
      loadedSubtitleBaseFontSize =
          (subtitleMap['baseFontSize'] as num?)?.toDouble() ?? 35.0; // <-- Ganti fallback
      // --- AKHIR MODIFIKASI ---
    } else if (subtitleMap != null && subtitleMap.containsKey('fontSize')) {
      loadedSubtitleBaseFontSize = _baseSizeFromLegacyNumeric(
          (subtitleMap['fontSize'] as num?)?.toDouble());
    } else if (subtitleMap != null && subtitleMap.containsKey('size')) {
      loadedSubtitleBaseFontSize =
          _baseSizeFromLegacyEnum(subtitleMap['size'] as String?);
    } else {
      // --- KATEGGORI_MODIFIKASI_KONSTANTA NO_URUT_03 (Target 8) ---
      loadedSubtitleBaseFontSize = 28.0; // <-- Ganti fallback
      // --- AKHIR MODIFIKASI ---
    }
    // --- AKHIR PERBAIKAN ---

    // --- KATEGORI_PERBAIKAN_BUG (Konsistensi boxWidth) ---
    // Sekarang kita juga memuat 'textBlockWidthFactor' (seperti sebelumnya)
    final double loadedSubtitleWidthFactor =
        (subtitleMap?['textBlockWidthFactor'] as num?)?.toDouble() ?? 0.9;
    // (Kita tidak perlu memuat 'boxWidth', karena 'toJson' akan selalu membuatnya)
    // --- AKHIR PERBAIKAN ---
        
    final int loadedSubtitleChunkCount =
        (subtitleMap?['subtitleChunkCount'] as int?) ?? 5;
    final int loadedSubtitleMaxLines =
        (subtitleMap?['subtitleMaxLines'] as int?) ?? 4;
    // --- KATEGORI_MODIFIKASI_KONSTANTA NO_URUT_01 (10% dari Bawah) ---
    final double loadedSubtitleVAlign =
        (subtitleMap?['subtitleVerticalAlignment'] as num?)?.toDouble() ?? 0.8; // <-- DIUBAH DARI 0.9
    // --- AKHIR MODIFIKASI ---

    // --- KATEGORI_ARSITEKTUR_INTRO_MUSIK (NO_URUT_07) ---
    // Ambil URL yang tersimpan.
    // Jika tidak ada (proyek lama), fallback ke URL acak BARU.
    final String loadedIntroMusicUrl;
    if (json['introMusicUrl'] != null &&
        (json['introMusicUrl'] as String).isNotEmpty) {
      loadedIntroMusicUrl = json['introMusicUrl'] as String;
    } else {
      // Proyek lama tidak memiliki URL, beri mereka satu URL acak
      final trackNumber = Random().nextInt(20) + 1; // 1-20
      loadedIntroMusicUrl =
          'https://firebasestorage.googleapis.com/v0/b/majiku-5b07e.firebasestorage.app/o/assets%2Fmusic%2Fintro_music%20$trackNumber.mp3?alt=media';
    }
    // --- AKHIR PERUBAHAN ---

    return VisualSettings(
      titleSettings: TextOverlaySettings.fromJson(
          json['titleOverlay'] as Map<String, dynamic>?),
      descriptionSettings: TextOverlaySettings.fromJson(
          json['descriptionOverlay'] as Map<String, dynamic>?),

      // Data Subtitle
      showSubtitles: subtitleMap?['show'] as bool? ?? false,
      subtitleDurationMultiplier:
          (subtitleMap?['durationMultiplier'] as num?)?.toDouble() ?? 0.8,
      subtitleBaseFontSize: loadedSubtitleBaseFontSize,
      subtitleBlockWidthFactor: loadedSubtitleWidthFactor, // <-- Tetap dimuat
      subtitleChunkCount: loadedSubtitleChunkCount,
      subtitleMaxLines: loadedSubtitleMaxLines,
      subtitleVerticalAlignment: loadedSubtitleVAlign,

      // Lainnya
      transitionType:
          (json['transition'] as Map<String, dynamic>?)?['type'] as String? ??
              'fade',
      transitionDuration:
          ((json['transition'] as Map<String, dynamic>?)?['duration'] as num?)
                  ?.toDouble() ??
              1.0,

      introMotionType:
          introMotionMap?['type'] as String? ?? 'zoom_in_center',

      sceneMotionBehavior: _parseSceneMotionBehavior(json),
      
      // --- KATEGORI_ARSITEKTUR_INTRO_MUSIK (NO_URUT_08) ---
      introMusicUrl: loadedIntroMusicUrl, // <-- Gunakan URL yang dimuat
      // --- AKHIR PERUBAHAN ---
      
      // --- KATEGORI_FITUR_BARU (OVERLAY_EFFECTS) ---
      useAssetOverlayEffects: json['useAssetOverlayEffects'] as bool? ?? false,
      // --- AKHIR TAMBAHAN ---
    );
  }
}
//................................................................//

//No ke-5.........................................................//
// HELPER ASPEK RASIO & STATE NOTIFIER / PROVIDER                 //
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

// --- KATEGORI_ARSITEKTUR: Refaktor Notifier (Perbaikan Bug "Mental") ---
class VisualSettingsNotifier extends StateNotifier<VisualSettings> {
  final String projectId;
  final FirestoreService _firestoreService;
  final AutoDisposeStateNotifierProviderRef _ref;
  
  // --- KATEGORI_ARSITEKTUR: Tambahan untuk state-safe initialization ---
  StreamSubscription? _projectSubscription;
  bool _isInitialized = false; // Flag untuk mencegah overwrite state
  // --- AKHIR TAMBAHAN ---

  VisualSettingsNotifier(
    VisualSettings initialState, // Ini akan menjadi state 'loading' palsu
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
    _projectSubscription = _ref.watch(projectStreamProvider(projectId).stream)
        .listen((projectData) {

      // HANYA set state dari stream JIKA kita belum diinisialisasi.
      // Ini mencegah stream menimpa (overwrite) editan pengguna (misal switch).
      if (!_isInitialized) {
        debugPrint("[$projectId] Notifier received first project data. Initializing state...");
        
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
                '[$projectId] Initializing state from renderPacket.styleSettings.');
          } else if (data != null && data.visualSettings is Map<String, dynamic>) {
            settingsMap = data.visualSettings as Map<String, dynamic>;
            debugPrint(
                '[$projectId] Initializing state from legacy visualSettings.');
          }
        } catch (e) {
          debugPrint('[$projectId] Error accessing dynamic properties: $e');
        }

        // Logika Pengecekan (sama seperti sebelumnya)
        if (settingsMap != null) {
          try {
            // Kita panggil fromJson, yang sudah benar menangani text: ""
            final parsedSettings = VisualSettings.fromJson(settingsMap);
            
            // --- KATEGORI_PERBAIKAN_BUG: Logika Injeksi yang Salah DIHAPUS ---
            // Logika 'if (savedTitleText.isEmpty && projectTitle.isNotEmpty)'
            // dihapus karena menimpa 'save'-an yang sengaja dikosongkan.
            // --- AKHIR PERBAIKAN ---

            state = parsedSettings;
            debugPrint(
                '[$projectId] Successfully parsed visual settings.');
          } catch (e) {
            debugPrint(
                '[$projectId] Error parsing settings map, using default with title. Error: $e');
            state = VisualSettings.defaultSettingsWithTitle(projectTitle);
          }
        } else {
          // Tidak ada setting tersimpan, gunakan default (dengan judul proyek)
          debugPrint(
              '[$projectId] visualSettings/renderPacket field missing, using default with title.');
          state = VisualSettings.defaultSettingsWithTitle(projectTitle);
        }

        _isInitialized = true; // Tandai sebagai sudah diinisialisasi
      }
    },
    onError: (e) {
      // Tangani jika stream error saat load
      if (!_isInitialized) {
        debugPrint('[$projectId] Error loading project stream ($e), using default settings.');
        state = VisualSettings.defaultSettingsWithTitle(""); // Error state
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
  int _clampChunkCount(int count) => count.clamp(1, 10);
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

  // --- Metode Update State (Subtitle) ---
  void updateShowSubtitles(bool show) =>
      state = state.copyWith(showSubtitles: show);
  void updateSubtitleDurationMultiplier(double multiplier) =>
      state = state.copyWith(subtitleDurationMultiplier: multiplier);
  void updateSubtitleBaseFontSize(double size) =>
      state = state.copyWith(subtitleBaseFontSize: _clampFontSize(size));
  void updateSubtitleBlockWidthFactor(double factor) =>
      state = state.copyWith(subtitleBlockWidthFactor: _clampWidthFactor(factor));
  void updateSubtitleChunkCount(int count) =>
      state = state.copyWith(subtitleChunkCount: _clampChunkCount(count));
  void updateSubtitleMaxLines(int lines) =>
      state = state.copyWith(subtitleMaxLines: _clampMaxLines(lines));
  void updateSubtitleVerticalAlignment(double align) =>
      state = state.copyWith(
          subtitleVerticalAlignment: _clampVerticalAlignment(align));

  // --- Metode Update State (Transisi & Motion) ---
  void updateTransitionType(String type) =>
      state = state.copyWith(transitionType: type);
  void updateTransitionDuration(double duration) =>
      state = state.copyWith(transitionDuration: duration);
  void updateIntroMotionType(String type) =>
      state = state.copyWith(introMotionType: type);
  void updateSceneMotionBehavior(String behavior) =>
      state = state.copyWith(sceneMotionBehavior: behavior);
      
  // --- KATEGORI_ARSITEKTUR_INTRO_MUSIK (NO_URUT_09) ---
  void updateIntroMusicUrl(String url) =>
      state = state.copyWith(introMusicUrl: url);
  // --- AKHIR PERUBAHAN ---

  // --- KATEGORI_FITUR_BARU (OVERLAY_EFFECTS) ---
  void updateUseAssetOverlayEffects(bool use) =>
      state = state.copyWith(useAssetOverlayEffects: use);
  // --- AKHIR TAMBAHAN ---

  // --- Fungsi Save ke Firestore ---
Future<void> saveSettingsToFirestore() async {
  try {
    // --- KATEGORI_PERBAIKAN_ARSITEKTUR (Mencegah Overwrite Data) ---
    // 1. Dapatkan data 'renderPacket' yang ADA SAAT INI dari Firestore
    //    Ini PENTING untuk mengambil 'scenes' dan 'timing' yang sudah ada.
    debugPrint(
        "saveSettings: Reading current project data first to prevent overwrite...");
    final docSnapshot = await _firestoreService.getProject(projectId);
    final data = docSnapshot.data();

    Map<String, dynamic> currentRenderPacket = {};

    // Ambil renderPacket yang ada, atau buat map kosong jika tidak ada
    if (data != null &&
        data.containsKey('renderPacket') &&
        data['renderPacket'] is Map<String, dynamic>) {
      debugPrint("saveSettings: Found existing renderPacket.");
      currentRenderPacket =
          Map<String, dynamic>.from(data['renderPacket']);
    } else {
      debugPrint(
          "saveSettings: No existing renderPacket found, will create new one.");
    }
    // --- AKHIR LANGKAH 1 ---

    // 2. Dapatkan data state UI saat ini dan konversikan ke JSON

    // --- KATEGORI_PERBAIKAN_BUG (State-Loss on Re-entry) ---
    // Gunakan 'ref.read' di sini untuk mendapatkan snapshot, BUKAN 'ref.watch'
    // Ini PENTING agar fungsi save tidak memicu rebuild provider.
    final projectData =
        _ref.read(projectStreamProvider(projectId)).asData?.value;
    // --- AKHIR PERBAIKAN ---

    final ratioString =
        (projectData as dynamic)?.aspectRatio; // Cast untuk akses properti
    final double aspectRatioValue = _calculateAspectRatio(ratioString);
    final newStyleSettingsMap = state.toJson(aspectRatioValue);
    // --- AKHIR LANGKAH 2 ---

    // 3. GABUNGKAN data: Timpa HANYA 'styleSettings'
    //    Ini adalah perbaikan inti (Anti-Regresi).
    currentRenderPacket['styleSettings'] = newStyleSettingsMap;
    // --- AKHIR LANGKAH 3 ---

    // 4. Simpan KEMBALI KESELURUHAN renderPacket yang sudah digabungkan
    //    Karena service menggunakan .set(merge: true), kita kirim field teratas.
    await _firestoreService.updateProject(
      projectId,
      {'renderPacket': currentRenderPacket}, // <-- Kirim map LENGKAP
    );
    // --- AKHIR PERBAIKAN ---

    debugPrint(
        '✅ Visual settings safely merged into renderPacket.styleSettings for project $projectId (Ratio: $aspectRatioValue)');

    // --- KATEGORI_PERBAIKAN_BUG (Perbaikan Bug 2: State-Loss on Re-entry) ---
    // Paksa 'projectStreamProvider' untuk me-refresh datanya dari Firestore.
    // Ini memastikan saat kita kembali ke Timeline, atau membuka ulang
    // layar ini, kita akan melihat data yang BARU saja disimpan.
    _ref.invalidate(projectStreamProvider(projectId));
    // --- AKHIR PERBAIKAN ---

  } catch (e) {
    debugPrint('❌ Error saving visual settings for project $projectId: $e');
    throw Exception('Failed to save settings: $e');
  }
}

  // --- Fungsi Load dari Firestore ---
  Future<void> loadSettingsFromFirestore() async {
    debugPrint('Attempting to manually load settings for $projectId...');
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
            'Found new renderPacket.styleSettings map in Firestore for $projectId.');
        settingsMap =
            data['renderPacket']['styleSettings'] as Map<String, dynamic>;
      } else if (data != null &&
          data.containsKey('visualSettings') &&
          data['visualSettings'] is Map) {
        debugPrint(
            'Found legacy visualSettings map in Firestore for $projectId.');
        settingsMap = data['visualSettings'] as Map<String, dynamic>;
      }

      if (settingsMap != null) {
        final loadedSettings = VisualSettings.fromJson(settingsMap);
        // Pastikan judul terisi jika hilang (anti-regresi)
        final titleOverlayMap =
            settingsMap['titleOverlay'] as Map<String, dynamic>?;
        final savedTitleText = titleOverlayMap?['text'] as String?;

        if ((savedTitleText == null || savedTitleText.isEmpty) && currentTitle.isNotEmpty) {
          // --- KATEGORI_PERBAIKAN_BUG: Logika Injeksi yang Salah DIHAPUS ---
          // Ini seharusnya tidak pernah terjadi karena 'fromJson'
          // dan inisialisasi awal sudah menangani ini.
          // Jika kita sampai di sini, 'state' harusnya sudah benar.
          // state = loadedSettings.copyWith(...); // <-- DIHAPUS
          // --- AKHIR PERBAIKAN ---
          state = loadedSettings;
          debugPrint('Injected project title into loaded settings. (THIS SHOULD NOT HAPPEN)');
        } else {
          state = loadedSettings;
        }

        debugPrint('✅ Visual settings loaded and state updated for project $projectId');
      } else {
        state = VisualSettings.defaultSettingsWithTitle(currentTitle);
        debugPrint(
            '⚙️ No valid visualSettings or renderPacket map found for $projectId, state reset to default.');
      }
    } catch (e) {
      debugPrint('❌ Error loading visual settings for project $projectId: $e');
    }
  }

  /// Mengatur ulang semua pengaturan visual ke nilai default pabrik.
  void resetToDefaults() {
    // --- KATEGORI_PERBAIKAN_BUG (State-Loss on Re-entry) ---
    // Gunakan 'ref.read' di sini, BUKAN 'ref.watch'
    final projectData =
        _ref.read(projectStreamProvider(projectId)).asData?.value;
    // --- AKHIR PERBAIKAN ---
    final String currentTitle = (projectData as dynamic)?.title ?? "";

    state = VisualSettings.defaultSettingsWithTitle(currentTitle);

    debugPrint('Visual settings for project $projectId reset to default.');
  }
}

// --- Provider (Family dengan projectId) ---
// --- KATEGORI_ARSITEKTUR: Definisi Provider Dirombak ---
final visualSettingsProvider =
    StateNotifierProvider.autoDispose.family<VisualSettingsNotifier, VisualSettings, String>(
  (ref, projectId) {
    // 1. Dapatkan dependensi yang diperlukan
    final firestoreService = ref.watch(firestoreServiceProvider);

    // 2. Buat Notifier dengan state 'loading' palsu.
    // Notifier akan memuat statenya sendiri di dalam konstruktornya.
    // Ini MEMUTUS siklus rebuild yang menyebabkan bug "mental".
    return VisualSettingsNotifier(
      VisualSettings.defaultSettingsWithTitle(""), // State 'loading' sementara
      projectId,
      firestoreService,
      ref
    );
  },
);
// --- AKHIR REFAKTOR ---
//................................................................//