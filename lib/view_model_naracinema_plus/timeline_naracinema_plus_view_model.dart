//================================================================//
// NAMA FILE: TIMELINE_NARACINEMA_PLUS_VIEW_MODEL.DART            //
// DIREKTORI: LIB/VIEW_MODEL_NARACINEMA_PLUS/                     //
// DESKRIPSI: VIEW MODEL PEMROSESAN TIMELINE & RENDER PACKET      //
//================================================================//

// No ke-1: IMPORT DEPENDENSI & KONSTANTA                         //
//----------------------------------------------------------------//
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models_naracinema_plus/scene_naracinema_plus.dart';
import '../models_naracinema_plus/video_project_naracinema_plus.dart';
import '../services_naracinema_plus/firestore_naracinema_plus_service.dart';
import '../providers_naracinema_plus/visual_settings_naracinema_plus_provider.dart';
import '../providers_naracinema_plus/firestore_naracinema_plus_provider.dart';

// [PERBAIKAN]: Mengimpor Stream Provider dari sumber utama
import '../providers_naracinema_plus/timeline_naracinema_plus_providers.dart';

const double kDefaultSceneDuration = 8.0;
//----------------------------------------------------------------//

// No ke-2: MODEL DATA MATANG NARACINEMA PLUS (ANTI-CRASH UI)     //
//----------------------------------------------------------------//
@immutable
class ProcessedSceneDataNaracinemaPlus {
  final SceneNaracinemaPlus originalScene;
  final double actualVideoDuration; 
  final double absoluteStartTime;
  final double absoluteEndTime;
  
  final List<dynamic> subtitleChunks;
  double get actualAudioDuration => actualVideoDuration; 

  const ProcessedSceneDataNaracinemaPlus({
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
class ProcessedTimelineDataNaracinemaPlus {
  final List<ProcessedSceneDataNaracinemaPlus> scenes;
  final double totalTimelineDuration;
  final bool isCalculating; 
  final double introDuration; 

  const ProcessedTimelineDataNaracinemaPlus({
    required this.scenes,
    required this.totalTimelineDuration,
    required this.isCalculating,
    this.introDuration = 0.0,
  });

  factory ProcessedTimelineDataNaracinemaPlus.loading() {
    return const ProcessedTimelineDataNaracinemaPlus(
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

// No ke-3: PROVIDER PEMROSESAN TIMELINE NARACINEMA PLUS          //
//----------------------------------------------------------------//
final processedTimelineNaracinemaPlusProvider = StreamProvider.family<ProcessedTimelineDataNaracinemaPlus, String>((ref, projectId) async* {
  ref.watch(visualSettingsNaracinemaPlusProvider(projectId)); 
  
  // Menggunakan provider yang diimpor dari timeline_naracinema_plus_providers.dart
  final scenesAsync = ref.watch(scenesNaracinemaPlusStreamProvider(projectId));
  final projectAsync = ref.watch(projectNaracinemaPlusStreamProvider(projectId));

  final scenes = scenesAsync.asData?.value; 
  final project = projectAsync.asData?.value; 

  if (scenes == null || project == null) {
    yield ProcessedTimelineDataNaracinemaPlus.loading();
    return;
  }

  final List<ProcessedSceneDataNaracinemaPlus> processedScenes = [];
  double currentPlaybackTime = 0.0; 
  double totalDuration = 0.0; 

  for (int i = 0; i < scenes.length; i++) {
    final scene = scenes[i]; 
    
    final double sceneDuration = (scene as dynamic).duration ?? kDefaultSceneDuration;

    final processedScene = ProcessedSceneDataNaracinemaPlus(
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

  yield ProcessedTimelineDataNaracinemaPlus(
    scenes: processedScenes,
    totalTimelineDuration: totalDuration,
    isCalculating: false, 
    introDuration: 0.0, 
  );
});
//----------------------------------------------------------------//

// No ke-4: FUNGSI PERAKITAN RENDER PACKET NARACINEMA PLUS        //
//----------------------------------------------------------------//
Future<void> prepareAndSaveRenderNaracinemaPlusPacket(WidgetRef ref, String projectId) async {
  debugPrint("prepareAndSaveRenderNaracinemaPlusPacket: Memulai perakitan renderPacket untuk $projectId...");
  
  try {
    final firestoreService = ref.read(firestoreNaracinemaPlusServiceProvider);
    final visualSettings = ref.read(visualSettingsNaracinemaPlusProvider(projectId));
    final processedTimeline = await ref.read(processedTimelineNaracinemaPlusProvider(projectId).future);
    final project = await ref.read(projectNaracinemaPlusStreamProvider(projectId).future);

    if (project == null) {
      debugPrint("❌ CRITICAL: Gagal menyimpan renderPacket (NARACINEMA PLUS) karena project null.");
      throw Exception("Project data is null. Cannot prepare render packet.");
    }

    // [ANTI-REGRESI]: Safety Gatekeeper - Jangan tindih data jika sedang/sudah render
    final List<String> immuneStatuses = [
      'RENDER_READY', 
      'RENDER_START', 
      'RENDERING', 
      'RENDER_COMPLETED'
    ];

    if (immuneStatuses.contains(project.status)) {
      debugPrint("⚠️ ABORT: prepareAndSaveRenderNaracinemaPlusPacket dihentikan karena status proyek sudah '${project.status}'. Mencegah Loop Render.");
      return; // Berhenti di sini, jangan lakukan update ke Firestore
    }

    if (processedTimeline.scenes.isEmpty) {
      debugPrint("⚠️ prepareAndSaveRenderNaracinemaPlusPacket: Timeline data is empty. Aborting.");
      throw Exception("Timeline data is empty.");
    }
    
    final double aspectRatioValue = _calculateAspectRatioFromString(project.aspectRatio);

    final Map<String, dynamic> renderPacket = {
      'styleSettings': visualSettings.toJson(aspectRatioValue, projectId),
      'timingData': {
        'scenes': processedTimeline.toJson()['scenes'],
        'totalTimelineDuration': processedTimeline.totalTimelineDuration,
      },
    };

    // Simpan paket tanpa mengubah status secara langsung di sini 
    // (Status diubah oleh UI setelah fungsi ini sukses dipanggil)
    await firestoreService.updateProject(
      projectId,
      {'renderPacket': renderPacket},
    );
    
    debugPrint("✅ prepareAndSaveRenderNaracinemaPlusPacket: renderPacket lengkap berhasil disimpan ke Firestore untuk $projectId");

  } catch (e) {
    debugPrint("❌ CRITICAL: Gagal menyimpan renderPacket (NARACINEMA PLUS) ke Firestore: $e");
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
  debugPrint("Invalid aspectRatio string '$ratioString' in timeline_naracinema_plus_view_model, falling back to 16/9.");
  return 16 / 9;
}
//----------------------------------------------------------------//