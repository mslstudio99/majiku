//================================================================//
// NAMA FILE: TIMELINE_MARKETTING_VIDEO_VIEW_MODEL.DART            //
// DIREKTORI: LIB/VIEW_MODEL_MARKETTING_VIDEO/                      //
// DESKRIPSI: VIEW MODEL PEMROSESAN TIMELINE & RENDER PACKET      //
//================================================================//

// No ke-1: IMPORT DEPENDENSI & KONSTANTA                         //
//----------------------------------------------------------------//
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models_marketting_video/scene_marketting_video.dart';
import '../models_marketting_video/video_project_marketting_video.dart';
import '../services_marketting_video/firestore_marketting_video_service.dart';
import '../providers_marketting_video/visual_settings_marketting_video_provider.dart';
import '../providers_marketting_video/firestore_marketting_video_provider.dart';

// [PERBAIKAN]: Mengimpor Stream Provider dari sumber utama
import '../providers_marketting_video/timeline_marketting_video_providers.dart';

const double kDefaultSceneDuration = 8.0;
//----------------------------------------------------------------//

// No ke-2: MODEL DATA MATANG MARKETTING VIDEO (ANTI-CRASH UI)     //
//----------------------------------------------------------------//
@immutable
class ProcessedSceneDataMarkettingVideo {
  final SceneMarkettingVideo originalScene;
  final double actualVideoDuration; 
  final double absoluteStartTime;
  final double absoluteEndTime;
  
  final List<dynamic> subtitleChunks;
  double get actualAudioDuration => actualVideoDuration; 

  const ProcessedSceneDataMarkettingVideo({
    required this.originalScene,
    required this.actualVideoDuration,
    required this.absoluteStartTime,
    required this.absoluteEndTime,
    this.subtitleChunks = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'sceneId': originalScene.id,
      'segmentText': originalScene.segmentText,
      'videoUrl': (originalScene as dynamic).videoUrl ?? '', 
      // [PERBAIKAN]: Menyuntikkan URL Audio TTS agar Cloud Run tidak merender video bisu
      'ttsAudioUrl': (originalScene as dynamic).ttsAudioUrl ?? '',
      'absoluteStartTime': absoluteStartTime,
      'absoluteEndTime': absoluteEndTime,
    };
  }
}

@immutable
class ProcessedTimelineDataMarkettingVideo {
  final List<ProcessedSceneDataMarkettingVideo> scenes;
  final double totalTimelineDuration;
  final bool isCalculating; 
  final double introDuration; 

  const ProcessedTimelineDataMarkettingVideo({
    required this.scenes,
    required this.totalTimelineDuration,
    required this.isCalculating,
    this.introDuration = 0.0,
  });

  factory ProcessedTimelineDataMarkettingVideo.loading() {
    return const ProcessedTimelineDataMarkettingVideo(
      scenes: [],
      totalTimelineDuration: 0.0,
      isCalculating: true,
      introDuration: 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalTimelineDuration': totalTimelineDuration,
      'introDuration': introDuration,
      'scenes': scenes.map((scene) => scene.toJson()).toList(),
    };
  }
}
//----------------------------------------------------------------//

// No ke-3: PROVIDER PEMROSESAN TIMELINE MARKETTING VIDEO          //
//----------------------------------------------------------------//
final processedTimelineMarkettingVideoProvider = StreamProvider.family<ProcessedTimelineDataMarkettingVideo, String>((ref, projectId) async* {
  ref.watch(visualSettingsMarkettingVideoProvider(projectId)); 
  
  // Menggunakan provider yang diimpor dari timeline_marketting_video_providers.dart
  final scenesAsync = ref.watch(scenesMarkettingVideoStreamProvider(projectId));
  final projectAsync = ref.watch(projectMarkettingVideoStreamProvider(projectId));

  final scenes = scenesAsync.asData?.value; 
  final project = projectAsync.asData?.value; 

  if (scenes == null || project == null) {
    yield ProcessedTimelineDataMarkettingVideo.loading();
    return;
  }

  final List<ProcessedSceneDataMarkettingVideo> processedScenes = [];
  double currentPlaybackTime = 0.0; 
  double totalDuration = 0.0; 

  for (int i = 0; i < scenes.length; i++) {
    final scene = scenes[i]; 
    
    final double sceneDuration = (scene as dynamic).duration ?? kDefaultSceneDuration;

    final processedScene = ProcessedSceneDataMarkettingVideo(
      originalScene: scene,
      actualVideoDuration: sceneDuration, 
      absoluteStartTime: currentPlaybackTime,
      absoluteEndTime: currentPlaybackTime + sceneDuration,
      subtitleChunks: (scene as dynamic).subtitleChunks ?? [],
    );

    processedScenes.add(processedScene);
    currentPlaybackTime += sceneDuration;
    totalDuration += sceneDuration;
  }

  yield ProcessedTimelineDataMarkettingVideo(
    scenes: processedScenes,
    totalTimelineDuration: totalDuration,
    isCalculating: false, 
    introDuration: 0.0, 
  );
});
//----------------------------------------------------------------//

// No ke-4: FUNGSI PERAKITAN RENDER PACKET MARKETTING VIDEO        //
//----------------------------------------------------------------//
Future<void> prepareAndSaveRenderMarkettingVideoPacket(WidgetRef ref, String projectId) async {
  debugPrint("prepareAndSaveRenderMarkettingVideoPacket: Memulai perakitan renderPacket untuk $projectId...");
  
  try {
    final firestoreService = ref.read(firestoreMarkettingVideoServiceProvider);
    final visualSettings = ref.read(visualSettingsMarkettingVideoProvider(projectId));
    
    // Invalidate provider agar data timeline mengambil klip terbaru dari Firestore
    ref.invalidate(processedTimelineMarkettingVideoProvider(projectId));
    final processedTimeline = await ref.read(processedTimelineMarkettingVideoProvider(projectId).future);
    final project = await ref.read(projectMarkettingVideoStreamProvider(projectId).future);

    if (project == null) {
      debugPrint("❌ CRITICAL: Gagal menyimpan renderPacket (MARKETTING VIDEO) karena project null.");
      throw Exception("Project data is null. Cannot prepare render packet.");
    }

    // [PERBAIKAN MUTLAK]: Status kebal HANYA saat render sedang aktif berjalan di Cloud Run.
    // RENDER_COMPLETED dicabut agar render ulang diizinkan mengupdate renderPacket terbaru.
    final List<String> immuneStatuses = [
      'RENDER_READY', 
      'RENDER_START', 
      'RENDERING', 
    ];

    if (immuneStatuses.contains(project.status)) {
      debugPrint("⚠️ ABORT: prepareAndSaveRenderMarkettingVideoPacket dihentikan karena status proyek sedang render: '${project.status}'.");
      return; 
    }

    if (processedTimeline.scenes.isEmpty) {
      debugPrint("⚠️ prepareAndSaveRenderMarkettingVideoPacket: Timeline data is empty. Aborting.");
      throw Exception("Timeline data is empty.");
    }
    
    final double aspectRatioValue = _calculateAspectRatioFromString(project.aspectRatio);

    final Map<String, dynamic> styleSettingsMap = visualSettings.toJson(aspectRatioValue, projectId);

    if (project.visualSettings != null &&
        project.visualSettings!['descriptionOverlay'] != null &&
        project.visualSettings!['descriptionOverlay']['position'] != null) {
      if (styleSettingsMap['descriptionOverlay'] != null) {
        styleSettingsMap['descriptionOverlay']['position'] = project.visualSettings!['descriptionOverlay']['position'];
      }
    }

    final Map<String, dynamic> renderPacket = {
      'styleSettings': styleSettingsMap,
      'timingData': {
        'scenes': processedTimeline.toJson()['scenes'],
        'totalTimelineDuration': processedTimeline.totalTimelineDuration,
      },
    };

    // Simpan paket render terbaru yang memuat URL klip hasil regenerasi ke Firestore
    await firestoreService.updateProject(
      projectId,
      {'renderPacket': renderPacket},
    );
    
    debugPrint("✅ prepareAndSaveRenderMarkettingVideoPacket: renderPacket BARU berhasil disimpan ke Firestore untuk $projectId");

  } catch (e) {
    debugPrint("❌ CRITICAL: Gagal menyimpan renderPacket (MARKETTING VIDEO) ke Firestore: $e");
    rethrow;
  }
}

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
  debugPrint("Invalid aspectRatio string '$ratioString' in timeline_marketting_video_view_model, falling back to 16/9.");
  return 16 / 9;
}
//----------------------------------------------------------------//