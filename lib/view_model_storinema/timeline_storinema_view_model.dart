//................................................................//
// NAMA FILE: TIMELINE_STORINEMA_VIEW_MODEL.DART                  //
// PATH: LIB/VIEW_MODEL_STORINEMA/TIMELINE_STORINEMA_VIEW_MODEL.DART //
// DESKRIPSI: VIEW MODEL PEMROSESAN TIMELINE & RENDER PACKET      //
//................................................................//

//No ke-1: IMPORT DEPENDENSI & KONSTANTA .........................//
//................................................................//
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models_storinema/scene_storinema.dart';
import '../models_storinema/video_project_storinema.dart';
import '../services_storinema/firestore_storinema_service.dart';
import '../providers_storinema/visual_settings_storinema_provider.dart';
import '../providers_storinema/firestore_storinema_provider.dart';

// [PERBAIKAN]: Mengimpor Stream Provider dari sumber utama
import '../providers_storinema/timeline_storinema_providers.dart';

const double kDefaultSceneDuration = 8.0;
//................................................................//

//No ke-2: MODEL DATA MATANG STORINEMA (ANTI-CRASH UI) ............//
//................................................................//
@immutable
class ProcessedSceneDataStorinema {
  final SceneStorinema originalScene;
  final double actualVideoDuration; 
  final double absoluteStartTime;
  final double absoluteEndTime;
  
  final List<dynamic> subtitleChunks;
  double get actualAudioDuration => actualVideoDuration; 

  const ProcessedSceneDataStorinema({
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
class ProcessedTimelineDataStorinema {
  final List<ProcessedSceneDataStorinema> scenes;
  final double totalTimelineDuration;
  final bool isCalculating; 
  final double introDuration; 

  const ProcessedTimelineDataStorinema({
    required this.scenes,
    required this.totalTimelineDuration,
    required this.isCalculating,
    this.introDuration = 0.0,
  });

  factory ProcessedTimelineDataStorinema.loading() {
    return const ProcessedTimelineDataStorinema(
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
//................................................................//

//No ke-3: PROVIDER PEMROSESAN TIMELINE STORINEMA ................//
//................................................................//
final processedTimelineStorinemaProvider = StreamProvider.family<ProcessedTimelineDataStorinema, String>((ref, projectId) async* {
  ref.watch(visualSettingsStorinemaProvider(projectId)); 
  
  // Menggunakan provider yang diimpor dari timeline_storinema_providers.dart
  final scenesAsync = ref.watch(scenesStorinemaStreamProvider(projectId));
  final projectAsync = ref.watch(projectStorinemaStreamProvider(projectId));

  final scenes = scenesAsync.asData?.value; 
  final project = projectAsync.asData?.value; 

  if (scenes == null || project == null) {
    yield ProcessedTimelineDataStorinema.loading();
    return;
  }

  final List<ProcessedSceneDataStorinema> processedScenes = [];
  double currentPlaybackTime = 0.0; 
  double totalDuration = 0.0; 

  for (int i = 0; i < scenes.length; i++) {
    final scene = scenes[i]; 
    
    final double sceneDuration = (scene as dynamic).duration ?? kDefaultSceneDuration;

    final processedScene = ProcessedSceneDataStorinema(
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

  yield ProcessedTimelineDataStorinema(
    scenes: processedScenes,
    totalTimelineDuration: totalDuration,
    isCalculating: false, 
    introDuration: 0.0, 
  );
});
//................................................................//

//No ke-4: FUNGSI PERAKITAN RENDER PACKET STORINEMA ..............//
//................................................................//
Future<void> prepareAndSaveRenderStorinemaPacket(WidgetRef ref, String projectId) async {
  debugPrint("prepareAndSaveRenderStorinemaPacket: Memulai perakitan renderPacket untuk $projectId...");
  
  try {
    final firestoreService = ref.read(firestoreStorinemaServiceProvider);
    final visualSettings = ref.read(visualSettingsStorinemaProvider(projectId));
    final processedTimeline = await ref.read(processedTimelineStorinemaProvider(projectId).future);
    final project = await ref.read(projectStorinemaStreamProvider(projectId).future);

    if (project == null) {
      debugPrint("❌ CRITICAL: Gagal menyimpan renderPacket (STORINEMA) karena project null.");
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
      debugPrint("⚠️ ABORT: prepareAndSaveRenderStorinemaPacket dihentikan karena status proyek sudah '${project.status}'. Mencegah Loop Render.");
      return; // Berhenti di sini, jangan lakukan update ke Firestore
    }

    if (processedTimeline.scenes.isEmpty) {
      debugPrint("⚠️ prepareAndSaveRenderStorinemaPacket: Timeline data is empty. Aborting.");
      throw Exception("Timeline data is empty.");
    }
    
    final double aspectRatioValue = _calculateAspectRatioFromString(project.aspectRatio);

    final Map<String, dynamic> renderPacket = {
      'styleSettings': visualSettings.toJson(aspectRatioValue),
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
    
    debugPrint("✅ prepareAndSaveRenderStorinemaPacket: renderPacket lengkap berhasil disimpan ke Firestore untuk $projectId");

  } catch (e) {
    debugPrint("❌ CRITICAL: Gagal menyimpan renderPacket (STORINEMA) ke Firestore: $e");
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
  debugPrint("Invalid aspectRatio string '$ratioString' in timeline_storinema_view_model, falling back to 16/9.");
  return 16 / 9;
}
//................................................................//