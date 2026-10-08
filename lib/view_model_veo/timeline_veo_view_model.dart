//================================================================//
// NAMA FILE: TIMELINE_VEO_VIEW_MODEL.DART                        //
// DIREKTORI: LIB/VIEW_MODEL_VEO/                                 //
// DESKRIPSI: VIEW MODEL PENGELOLA TIMELINE & RENDER PACKET VEO   //
//================================================================//

//No ke-1.........................................................//
// IMPORT DEPENDENSI & KONSTANTA GLOBAL                           //
//................................................................//
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models_veo/scene_veo.dart';
import '../models_veo/video_project_veo.dart';
import '../services_veo/firestore_veo_service.dart';
import '../providers_veo/visual_settings_veo_provider.dart';

// Durasi Tetap Scene VEO 3.1 (Default 8 Detik per Prompt Adegan)
const double kDefaultSceneDuration = 8.0;
//................................................................//

//No ke-2.........................................................//
// PROVIDER BAHAN MENTAH (STREAM PROVIDER)                        //
//................................................................//
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
//................................................................//

//No ke-3.........................................................//
// MODEL DATA MATANG (PROCESSED TIMELINE DATA)                    //
//................................................................//
/// Model data matang untuk SATU scene VEO.
@immutable
class ProcessedSceneDataVeo {
  final SceneVeo originalScene;
  final double actualVideoDuration;
  final double absoluteStartTime;
  final double absoluteEndTime;

  const ProcessedSceneDataVeo({
    required this.originalScene,
    required this.actualVideoDuration,
    required this.absoluteStartTime,
    required this.absoluteEndTime,
  });

  /// Mengubah data adegan matang menjadi Map untuk Paket Render.
  Map<String, dynamic> toJson() {
    return {
      'sceneId': originalScene.id,
      'segmentText': originalScene.segmentText,
      'videoUrl': originalScene.videoUrl,
      'absoluteStartTime': absoluteStartTime,
      'absoluteEndTime': absoluteEndTime,
    };
  }
}

/// Model data matang untuk keseluruhan garis waktu (Timeline) VEO.
@immutable
class ProcessedTimelineDataVeo {
  final List<ProcessedSceneDataVeo> scenes;
  final double totalTimelineDuration;
  final bool isCalculating;

  const ProcessedTimelineDataVeo({
    required this.scenes,
    required this.totalTimelineDuration,
    required this.isCalculating,
  });

  factory ProcessedTimelineDataVeo.loading() {
    return const ProcessedTimelineDataVeo(
      scenes: [],
      totalTimelineDuration: 0.0,
      isCalculating: true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalTimelineDuration': totalTimelineDuration,
      'scenes': scenes.map((scene) => scene.toJson()).toList(),
    };
  }
}
//................................................................//

//No ke-4.........................................................//
// PABRIK PROVIDER TERPUSAT (TIMELINE STREAM PROVIDER)            //
//................................................................//
final processedTimelineVeoProvider = StreamProvider.family<ProcessedTimelineDataVeo, String>((ref, projectId) async* {
  // 1. Monitor pengaturan visual & bahan mentah
  ref.watch(visualSettingsVeoProvider(projectId)); 
  
  final scenesAsync = ref.watch(scenesVeoStreamProvider(projectId));
  final projectAsync = ref.watch(projectVeoStreamProvider(projectId));

  // 2. Tangani status pemuatan data
  final scenes = scenesAsync.asData?.value;
  final project = projectAsync.asData?.value;

  if (scenes == null || project == null) {
    yield ProcessedTimelineDataVeo.loading();
    return;
  }

  // 3. Susun data adegan secara berurutan dan hitung garis waktu
  final List<ProcessedSceneDataVeo> processedScenes = [];
  double currentPlaybackTime = 0.0;
  double totalDuration = 0.0;

  for (int i = 0; i < scenes.length; i++) {
    final scene = scenes[i];
    final double sceneDuration = scene.duration ?? kDefaultSceneDuration;

    final processedScene = ProcessedSceneDataVeo(
      originalScene: scene,
      actualVideoDuration: sceneDuration,
      absoluteStartTime: currentPlaybackTime,
      absoluteEndTime: currentPlaybackTime + sceneDuration,
    );

    processedScenes.add(processedScene);
    currentPlaybackTime += sceneDuration;
    totalDuration += sceneDuration;
  }

  // 4. Salurkan hasil kalkulasi garis waktu ke UI
  yield ProcessedTimelineDataVeo(
    scenes: processedScenes,
    totalTimelineDuration: totalDuration,
    isCalculating: false,
  );
});
//................................................................//

//No ke-5.........................................................//
// FUNGSI PERAKITAN UTAMA RENDER PACKET & HELPER                  //
//................................................................//
Future<void> prepareAndSaveRenderPacketVeo(WidgetRef ref, String projectId) async {
  debugPrint("prepareAndSaveRenderPacket (VEO): Memulai perakitan renderPacket untuk $projectId...");
  
  try {
    final firestoreService = ref.read(firestoreVeoServiceProvider);
    final visualSettings = ref.read(visualSettingsVeoProvider(projectId));
    final processedTimeline = await ref.read(processedTimelineVeoProvider(projectId).future);
    final project = await ref.read(projectVeoStreamProvider(projectId).future);

    if (project == null) {
      debugPrint("❌ CRITICAL: Gagal menyimpan renderPacket (VEO) karena project null.");
      throw Exception("Project data is null. Cannot prepare render packet.");
    }

    if (processedTimeline.scenes.isEmpty) {
      debugPrint("⚠️ prepareAndSaveRenderPacket (VEO): Timeline data is empty. Aborting.");
      throw Exception("Timeline data is empty.");
    }
    
    final double aspectRatioValue = _calculateAspectRatioFromString(project.aspectRatio);

    // Ambil dokumen Firestore untuk membaca konfigurasi showTitle secara akurat
    final projectDoc = await firestoreService.getProject(projectId);
    final Map<String, dynamic> projectData = projectDoc.data() ?? {};
    final bool shouldShowTitle = projectData['showTitle'] ?? true;

    final Map<String, dynamic> styleSettingsMap = visualSettings.toJson(aspectRatioValue);

    // [SINKRONISASI STATUS ON/OFF JUDUL OVERLAY]
    styleSettingsMap['showTitle'] = shouldShowTitle;
    if (shouldShowTitle) {
      final String projectTitle = project.title.isNotEmpty ? project.title : (projectData['title'] ?? '');
      if (styleSettingsMap['title'] == null || styleSettingsMap['title'].toString().trim().isEmpty) {
        styleSettingsMap['title'] = projectTitle;
      }
      if (styleSettingsMap['titleSettings'] is Map) {
        final titleMap = styleSettingsMap['titleSettings'] as Map<String, dynamic>;
        titleMap['show'] = true;
        if (titleMap['text'] == null || titleMap['text'].toString().trim().isEmpty) {
          titleMap['text'] = projectTitle;
        }
      }
    } else {
      styleSettingsMap['title'] = '';
      if (styleSettingsMap['titleSettings'] is Map) {
        final titleMap = styleSettingsMap['titleSettings'] as Map<String, dynamic>;
        titleMap['show'] = false;
        titleMap['text'] = '';
      }
    }

    // Rakit paket akhir render
    final Map<String, dynamic> renderPacket = {
      'styleSettings': styleSettingsMap,
      'timingData': {
        'scenes': processedTimeline.toJson()['scenes'],
        'totalTimelineDuration': processedTimeline.totalTimelineDuration,
      },
    };

    // Simpan paket ke Firestore proyek VEO
    await firestoreService.updateProject(
      projectId,
      {'renderPacket': renderPacket},
    );
    
    debugPrint("✅ prepareAndSaveRenderPacket (VEO): renderPacket lengkap berhasil disimpan ke Firestore untuk $projectId (showTitle: $shouldShowTitle)");

  } catch (e) {
    debugPrint("❌ CRITICAL: Gagal menyimpan renderPacket (VEO) ke Firestore: $e");
    rethrow;
  }
}

/// Helper untuk mengonversi string format '16:9' ke nilai double
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
//................................................................//