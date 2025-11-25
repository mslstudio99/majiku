// --- KATEGORI_ISOLASI_VEO: Path file: view_model_veo/timeline_veo_view_model.dart ---
// --- KATEGORI_PEMBERSIHAN: Karakter non-ASCII (U+00A0) telah dihapus ---

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart'; // Diperlukan untuk @immutable

// --- KATEGORI_PENGHAPUSAN_VEO (Audio/TTS): Hapus impor yang tidak relevan ---
// import 'package:audioplayers/audioplayers.dart'; // <-- DIHAPUS
// import 'dart:math'; // <-- DIHAPUS (Tidak diperlukan untuk .ceil() atau Random())
// --- AKHIR PENGHAPUSAN ---

// --- KATEGORI_ISOLASI_VEO: Impor diubah ke _veo ---
import '../models_veo/scene_veo.dart';
import '../models_veo/video_project_veo.dart';
import '../services_veo/firestore_veo_service.dart';
import '../providers_veo/visual_settings_veo_provider.dart';
// --- AKHIR MODIFIKASI ---

// --- KATEGORI_KONSTANTA_VEO: Durasi Tetap Scene (Berdasarkan Prompt 8s) ---
const double kDefaultSceneDuration = 8.0;
// --- AKHIR KONSTANTA VEO ---


// =========================================================================
// === BAGIAN 1: PROVIDER BAHAN MENTAH (ISOLASI VEO) ===
// =========================================================================

// (Provider 'firestoreVeoServiceProvider' sekarang diimpor dari visual_settings_veo_provider.dart)

// --- KATEGORI_ISOLASI_VEO: Provider diubah namanya dan tipe datanya ---
final projectVeoStreamProvider = StreamProvider.family<VideoProjectVeo?, String>((ref, projectId) {
  final firestoreService = ref.watch(firestoreVeoServiceProvider);
  return firestoreService.getProjectStream(projectId).handleError((error, stackTrace) {
    debugPrint("[projectVeoStreamProvider] Error fetching project $projectId: $error");
    return null;
  });
});

final scenesVeoStreamProvider = StreamProvider.family<List<SceneVeo>, String>((ref, projectId) {
  final firestoreService = ref.watch(firestoreVeoServiceProvider);
  return firestoreService.getScenesStream(projectId).handleError((error, stackTrace) {
    debugPrint("[scenesVeoStreamProvider] Error fetching scenes for $projectId: $error");
    return [];
  });
});
// --- AKHIR MODIFIKASI ---


// =========================================================================
// === BAGIAN 2: MODEL DATA "MATANG" (ISOLASI VEO) ===
// =========================================================================

// --- KATEGORI_PENGHAPUSAN_VEO: Hapus SubtitleChunkVeo class dan logicnya ---
// (Class SubtitleChunkVeo DIHAPUS)
// --- AKHIR PENGHAPUSAN ---

/// Model data matang untuk SATU scene VEO.
@immutable
// --- KATEGORI_ISOLASI_VEO: Nama Class diubah ---
class ProcessedSceneDataVeo {
// --- AKHIR MODIFIKASI ---
  // --- KATEGORI_ISOLASI_VEO: Tipe data diubah ---
  final SceneVeo originalScene;
  // --- AKHIR MODIFIKASI ---
  // --- KATEGORI_PENGHAPUSAN_VEO: Durasi Audio DIHAPUS (Gunakan Video Duration) ---
  // final double actualAudioDuration; // <-- DIHAPUS
  final double actualVideoDuration; // <-- DIGUNAKAN UNTUK DURASI SCENE
  // --- AKHIR PENGHAPUSAN ---
  final double absoluteStartTime;
  final double absoluteEndTime;

  // --- KATEGORI_PENGHAPUSAN_VEO: Hapus Subtitle Chunks ---
  // final List<SubtitleChunkVeo> subtitleChunks; // <-- DIHAPUS
  // --- AKHIR PENGHAPUSAN ---

  // --- KATEGORI_ISOLASI_VEO: Konstruktor diubah ---
  const ProcessedSceneDataVeo({
  // --- AKHIR MODIFIKASI ---
    required this.originalScene,
    required this.actualVideoDuration,
    required this.absoluteStartTime,
    required this.absoluteEndTime,
    // required this.subtitleChunks, // <-- DIHAPUS
  });

  /// Mengubah data matang ini menjadi JSON untuk "Paket Tugas Render".
  Map<String, dynamic> toJson() {
    return {
      'sceneId': originalScene.id,
      'segmentText': originalScene.segmentText,
      // --- KATEGORI_ISOLASI_VEO: Perubahan Semantik (videoUrl) ---
      'videoUrl': originalScene.videoUrl, // <-- Menggantikan imageUrl
      // --- KATEGORI_PENGHAPUSAN_VEO: Hapus TTS dan Durasi Audio/Subtitle ---
      // 'ttsAudioUrl': originalScene.ttsAudioUrl, // <-- DIHAPUS
      // 'actualAudioDuration': actualAudioDuration, // <-- DIHAPUS
      // 'subtitleChunks': subtitleChunks.map((c) => c.toJson()).toList(), // <-- DIHAPUS
      // --- AKHIR PENGHAPUSAN ---
      'absoluteStartTime': absoluteStartTime,
      'absoluteEndTime': absoluteEndTime,
    };
  }
}

@immutable
// --- KATEGORI_ISOLASI_VEO: Nama Class diubah ---
class ProcessedTimelineDataVeo {
// --- AKHIR MODIFIKASI ---
  // --- KATEGORI_PENGHAPUSAN_VEO: Hapus Durasi Intro ---
  // final double introDuration; // <-- DIHAPUS
  // --- AKHIR PENGHAPUSAN ---
  // --- KATEGORI_ISOLASI_VEO: Tipe data diubah ---
  final List<ProcessedSceneDataVeo> scenes;
  // --- AKHIR MODIFIKASI ---
  final double totalTimelineDuration;
  // --- KATEGORI_PENGHAPUSAN_VEO: Hapus isCalculating (Tidak ada TTS measurement) ---
  final bool isCalculating; // <-- Tetap true hanya saat scenesAsync loading
  // --- AKHIR PENGHAPUSAN ---

  // --- KATEGORI_ISOLASI_VEO: Konstruktor diubah ---
  const ProcessedTimelineDataVeo({
  // --- AKHIR MODIFIKASI ---
    // required this.introDuration, // <-- DIHAPUS
    required this.scenes,
    required this.totalTimelineDuration,
    required this.isCalculating,
  });

  // --- KATEGORI_ISOLASI_VEO: Factory diubah ---
  factory ProcessedTimelineDataVeo.loading() {
    return const ProcessedTimelineDataVeo(
    // --- AKHIR MODIFIKASI ---
      // introDuration: 0.0, // <-- DIHAPUS
      scenes: [],
      totalTimelineDuration: 0.0,
      isCalculating: true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      // 'introDuration': introDuration, // <-- DIHAPUS
      'totalTimelineDuration': totalTimelineDuration,
      'scenes': scenes.map((scene) => scene.toJson()).toList(),
    };
  }
}

// =========================================================================
// === BAGIAN 3: HELPER (LOGIKA DIHAPUS/DIROMBAK) ===
// =========================================================================

// --- KATEGORI_PENGHAPUSAN_VEO: Hapus _measureAudioDuration ---
// (Fungsi _measureAudioDuration DIHAPUS)
// --- AKHIR PENGHAPUSAN ---

// --- KATEGORI_PENGHAPUSAN_VEO: Hapus _injectNewlines ---
// (Fungsi _injectNewlines DIHAPUS)
// --- AKHIR PENGHAPUSAN ---


// =========================================================================
// === BAGIAN 4: "PABRIK PROVIDER" TERPUSAT (ISOLASI VEO) ===
// =========================================================================

// --- KATEGORI_ISOLASI_VEO: Provider diubah namanya ---
final processedTimelineVeoProvider = StreamProvider.family<ProcessedTimelineDataVeo, String>((ref, projectId) async* {
// --- AKHIR MODIFIKASI ---
  
  // 1. Tonton (watch) semua "Bahan Mentah" VEO
  // --- KATEGORI_PENGHAPUSAN_VEO: Hapus semua referensi VisualSettings (karena sudah dihapus) ---
  ref.watch(visualSettingsVeoProvider(projectId)); 
  // --- AKHIR PENGHAPUSAN ---
  
  final scenesAsync = ref.watch(scenesVeoStreamProvider(projectId));
  final projectAsync = ref.watch(projectVeoStreamProvider(projectId));

  // 2. Handle State Loading
  final scenes = scenesAsync.asData?.value; // Tipe: List<SceneVeo>
  final project = projectAsync.asData?.value; // Tipe: VideoProjectVeo

  if (scenes == null || project == null) {
    // --- KATEGORI_ISOLASI_VEO: Tipe data diubah ---
    yield ProcessedTimelineDataVeo.loading();
    // --- AKHIR MODIFIKASI ---
    return;
  }

// --- "PABRIK" VEO DIMULAI (Logika Penyederhanaan) ---
  
// --- KATEGORI_PENGHAPUSAN_VEO: Hapus isAnyAudioMissing ---
// final bool isAnyAudioMissing = scenes.any((s) => s.ttsAudioUrl.isEmpty); // <-- DIHAPUS

// 3. Eksekusi Pengukuran Durasi (Sederhana)
  
  // --- KATEGORI_PENGHAPUSAN_VEO: Hapus Logic Intro/TTS Measurement ---
  // final double finalIntroDuration = 0.0; // <-- DIHAPUS
  // (Semua measurement futures DIHAPUS)
  // --- AKHIR PENGHAPUSAN ---


  // 4. "Memasak" Data (SINKRON)
  
  // --- KATEGORI_ISOLASI_VEO: Tipe data diubah ---
  final List<ProcessedSceneDataVeo> processedScenes = [];
  // --- AKHIR MODIFIKASI ---
  double currentPlaybackTime = 0.0; // Mulai dari 0.0
  double totalDuration = 0.0; // Mulai dari 0.0

  for (int i = 0; i < scenes.length; i++) {
    final scene = scenes[i]; // Tipe: SceneVeo
    
    // --- KATEGORI_REFAKTOR_LOGIC: Durasi Scene Selalu Default ---
    // Kita mengasumsikan durasi video VEO 3.1 adalah 8.0 detik per prompt.
    // Jika Veo API mengirim durasi (scene.duration), kita akan menggunakannya, 
    // jika tidak, kita gunakan fallback 8.0s.
    final double sceneDuration = scene.duration ?? kDefaultSceneDuration;

    // --- KATEGORI_PENGHAPUSAN_VEO: Hapus Logic Subtitle Chunking ---
    // (Semua logika subtitle chunking DIHAPUS)
    // --- AKHIR PENGHAPUSAN ---

    // --- KATEGORI_ISOLASI_VEO: Tipe data diubah ---
    final processedScene = ProcessedSceneDataVeo(
    // --- AKHIR MODIFIKASI ---
      originalScene: scene,
      actualVideoDuration: sceneDuration, // <-- Menggunakan durasi scene
      absoluteStartTime: currentPlaybackTime,
      absoluteEndTime: currentPlaybackTime + sceneDuration,
      // subtitleChunks: [], // <-- DIHAPUS
    );

    processedScenes.add(processedScene);
    currentPlaybackTime += sceneDuration;
    totalDuration += sceneDuration;
  }

  // 5. "Yield" Data Matang
  // --- KATEGORI_ISOLASI_VEO: Tipe data diubah ---
  yield ProcessedTimelineDataVeo(
  // --- AKHIR MODIFIKASI ---
    // introDuration: 0.0, // <-- DIHAPUS
    scenes: processedScenes,
    totalTimelineDuration: totalDuration,
    isCalculating: false, // <-- Selalu false karena tidak ada measurement
  );

});

// =========================================================================
// === BAGIAN 5: FUNGSI "PERAKITAN" UTAMA (ISOLASI VEO) ===
// =========================================================================

// --- KATEGORI_ISOLASI_VEO: Fungsi diubah namanya ---
Future<void> prepareAndSaveRenderPacketVeo(WidgetRef ref, String projectId) async {
// --- AKHIR MODIFIKASI ---
  debugPrint("prepareAndSaveRenderPacket (VEO): Memulai perakitan renderPacket untuk $projectId...");
  
  try {
    // --- KATEGORI_ISOLASI_VEO: Dependensi diubah ---
    final firestoreService = ref.read(firestoreVeoServiceProvider);
    final visualSettings = ref.read(visualSettingsVeoProvider(projectId));
    final processedTimeline = await ref.read(processedTimelineVeoProvider(projectId).future);
    final project = await ref.read(projectVeoStreamProvider(projectId).future);
    // --- AKHIR MODIFIKASI ---

    // --- KATEGORI_PERBAIKAN_ARSITEKTUR (NULL_SAFETY): Perbaiki error null ---
    if (project == null) {
      debugPrint("❌ CRITICAL: Gagal menyimpan renderPacket (VEO) karena project null.");
      throw Exception("Project data is null. Cannot prepare render packet.");
    }
    // --- AKHIR PERBAIKAN ---

    // --- KATEGORI_PENGHAPUSAN_VEO: Hapus isCalculating check ---
    if (processedTimeline.scenes.isEmpty) {
      debugPrint("⚠️ prepareAndSaveRenderPacket (VEO): Timeline data is empty. Aborting.");
      throw Exception("Timeline data is empty.");
    }
    // --- AKHIR PENGHAPUSAN ---
    
    final double aspectRatioValue = _calculateAspectRatioFromString(project.aspectRatio);

    final Map<String, dynamic> renderPacket = {
      'styleSettings': visualSettings.toJson(aspectRatioValue),
      'timingData': {
        'scenes': processedTimeline.toJson()['scenes'],
        // --- KATEGORI_PENGHAPUSAN_VEO: Hapus Intro Duration ---
        // 'introDuration': processedTimeline.introDuration, // <-- DIHAPUS
        // --- AKHIR PENGHAPUSAN ---
        'totalTimelineDuration': processedTimeline.totalTimelineDuration,
      },
    };

    // (Logika updateProject sudah benar, karena firestoreService adalah instance VEO)
    await firestoreService.updateProject(
      projectId,
      {'renderPacket': renderPacket},
    );
    
    debugPrint("✅ prepareAndSaveRenderPacket (VEO): renderPacket lengkap berhasil disimpan ke Firestore untuk $projectId");

  } catch (e) {
    debugPrint("❌ CRITICAL: Gagal menyimpan renderPacket (VEO) ke Firestore: $e");
    rethrow;
  }
}

/// Helper (Dipertahankan)
double _calculateAspectRatioFromString(String? ratioString) {
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
  debugPrint("Invalid aspectRatio string '$ratioString' in timeline_veo_view_model, falling back to 16/9.");
  return 16 / 9;
}