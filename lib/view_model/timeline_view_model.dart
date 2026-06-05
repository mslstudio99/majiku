//====================================================================================================//
// NAMA FILE: LIB/VIEW_MODEL/TIMELINE_VIEW_MODEL.DART                                                 //
// DESKRIPSI: TIMELINE VIEW MODEL SMART ENGINE (PENGELOLA DURASI, TEKS, DAN RENDER PACKET)            //
//====================================================================================================//

//No ke-1: IMPORTS & DEPENDENCIES //
//Deklarasi pustaka inti, Riverpod, dan model data. //
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'dart:math'; 

import '../models/scene.dart';
import '../models/video_project.dart';
import '../services/firestore_service.dart';
import '../providers/visual_settings_provider.dart';
//----------------------------------------------------------------------------------------------------//

//No ke-2: PROVIDER BAHAN MENTAH //
//Mengambil stream data proyek dan scene dari Firestore. //
final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService();
});

final projectStreamProvider = StreamProvider.family<VideoProject, String>((ref, projectId) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.getProjectStream(projectId);
});

final scenesStreamProvider = StreamProvider.family<List<Scene>, String>((ref, projectId) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.getScenesStream(projectId);
});
//----------------------------------------------------------------------------------------------------//

//No ke-3: MODEL DATA MATANG (PROCESSED) //
//Model untuk menampung data timeline yang sudah diukur dan dibagi chunk. //
@immutable
class SubtitleChunk {
  final String text; // Untuk Pratinjau (mengerti '\n')
  final List<String> lines; // Untuk Render FFmpeg
  final double startTime;
  final double duration;

  const SubtitleChunk({
    required this.text,
    required this.lines, 
    required this.startTime,
    required this.duration,
  });

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'lines': lines, 
      'startTime': startTime,
      'duration': duration,
    };
  }
}

@immutable
class ProcessedSceneData {
  final Scene originalScene;
  final double actualAudioDuration;
  final double absoluteStartTime;
  final double absoluteEndTime;
  final List<SubtitleChunk> subtitleChunks;

  const ProcessedSceneData({
    required this.originalScene,
    required this.actualAudioDuration,
    required this.absoluteStartTime,
    required this.absoluteEndTime,
    required this.subtitleChunks,
  });

  Map<String, dynamic> toJson() {
    return {
      'sceneId': originalScene.id,
      'segmentText': originalScene.segmentText,
      'imageUrl': originalScene.imageUrl,
      'ttsAudioUrl': originalScene.ttsAudioUrl,
      'actualAudioDuration': actualAudioDuration,
      'absoluteStartTime': absoluteStartTime,
      'absoluteEndTime': absoluteEndTime,
      'subtitleChunks': subtitleChunks.map((c) => c.toJson()).toList(),
    };
  }
}

@immutable
class ProcessedTimelineData {
  final double introDuration;
  final List<ProcessedSceneData> scenes;
  final double totalTimelineDuration;
  final bool isCalculating;

  const ProcessedTimelineData({
    required this.introDuration,
    required this.scenes,
    required this.totalTimelineDuration,
    required this.isCalculating,
  });

  factory ProcessedTimelineData.loading() {
    return const ProcessedTimelineData(
      introDuration: 10.0,
      scenes: [],
      totalTimelineDuration: 10.0,
      isCalculating: true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'introDuration': introDuration,
      'totalTimelineDuration': totalTimelineDuration,
      'scenes': scenes.map((scene) => scene.toJson()).toList(),
    };
  }
}
//----------------------------------------------------------------------------------------------------//

//No ke-4: HELPER PENGUKURAN AUDIO & FORMAT TEKS //
//Mengukur durasi asli audio dan memotong teks untuk preview UI. //
Future<double> _measureAudioDuration(String url, {bool isAsset = false}) async {
  final double fallbackDuration = 5.0;
  if (url.isEmpty) {
      debugPrint("MeasureAudio: URL is empty, using fallback ${fallbackDuration}s");
    return fallbackDuration;
  }

  AudioPlayer? tempPlayer;
  try {
    tempPlayer = AudioPlayer();
    if (isAsset) {
      await tempPlayer.setSource(AssetSource(url));
    } else {
      await tempPlayer.setSource(UrlSource(url));
    }
    Duration? duration;
    int retries = 0;
    while (retries < 5) {
      duration = await tempPlayer.getDuration();
      if (duration != null && duration.inMilliseconds > 100) break; 
      await Future.delayed(const Duration(milliseconds: 200));
      retries++;
    }
    if (duration != null && duration.inMilliseconds > 100) {
      return duration.inMilliseconds / 1000.0;
    } else {
      debugPrint("MeasureAudio: Failed to get duration for '$url', using fallback ${fallbackDuration}s");
      return fallbackDuration;
    }
  } catch (e) {
    debugPrint("MeasureAudio: Error loading '$url' ($e), using fallback ${fallbackDuration}s");
    return fallbackDuration;
  } finally {
    await tempPlayer?.release();
    await tempPlayer?.dispose();
  }
}

String _injectNewlines(String text, {required int maxLines}) {
  if (maxLines <= 1) return text;
  final List<String> words = text.split(' ').where((s) => s.isNotEmpty).toList();
  if (words.isEmpty) return text;

  final int linesToCreate = maxLines;
  int wordsPerLine = (words.length / linesToCreate).ceil();
  if (wordsPerLine == 0) return words.join(' ');

  final List<String> lines = [];
  int wordCursor = 0; 

  for (int i = 0; i < linesToCreate; i++) {
    if (wordCursor >= words.length) break;
    int end = wordCursor + wordsPerLine;
    if (i == linesToCreate - 1) {
        end = words.length;
    } else {
        end = (wordCursor + wordsPerLine > words.length) ? words.length : (wordCursor + wordsPerLine);
    }
    final line = words.sublist(wordCursor, end).join(' ');
    lines.add(line);
    wordCursor = end;
  }
  return lines.join('\n');
}
//----------------------------------------------------------------------------------------------------//

//No ke-5: PABRIK PROVIDER (SMART ENGINE) //
//Memproses data mentah menjadi timeline siap render. //
final processedTimelineProvider = StreamProvider.family<ProcessedTimelineData, String>((ref, projectId) async* {
  
  final (
    double estimatedIntroDuration,
    int subtitleChunkCount,
    int subtitleMaxLines,
    String introMusicUrl 
  ) = ref.watch(visualSettingsProvider(projectId).select((vs) => (
        vs.titleSettings.startTime + vs.titleSettings.duration,
        vs.subtitleChunkCount,
        vs.subtitleMaxLines,
        vs.introMusicUrl 
      )));
  
  final scenesAsync = ref.watch(scenesStreamProvider(projectId));
  final projectAsync = ref.watch(projectStreamProvider(projectId));

  final scenes = scenesAsync.asData?.value;
  final project = projectAsync.asData?.value;

  if (scenes == null || project == null) {
    yield ProcessedTimelineData.loading();
    return;
  }

  final bool isAnyAudioMissing = scenes.any((s) => s.ttsAudioUrl.isEmpty);

  final double finalIntroDuration = 0.0;

  final List<Future<double>> measurementFutures = [];
  for (final scene in scenes) {
    if (scene.duration != null && scene.duration! > 0.1) {
      measurementFutures.add(Future.value(scene.duration!));
      debugPrint("[$projectId] Scene ${scene.segmentIndex}: Using pre-calculated duration: ${scene.duration!}s");
    } else {
      debugPrint("[$projectId] Scene ${scene.segmentIndex}: No duration. Measuring manually...");
      measurementFutures.add(_measureAudioDuration(scene.ttsAudioUrl, isAsset: false));
    }
  }
  final List<double> actualSceneDurations = await Future.wait(measurementFutures);
  debugPrint("[$projectId] All audio durations calculated.");


  final List<ProcessedSceneData> processedScenes = [];
  double currentPlaybackTime = finalIntroDuration;
  double totalDuration = finalIntroDuration;

  final String aspectRatio = project.aspectRatio ?? "16:9";

  for (int i = 0; i < scenes.length; i++) {
    final scene = scenes[i];
    final double measuredDuration = actualSceneDurations[i];
    final String fullText = scene.segmentText ?? "";
    
    final int chunksToMake;
    final int linesPerChunk;

    if (aspectRatio == "16:9") {
      chunksToMake = 2;
      linesPerChunk = 3;
    } else {
      chunksToMake = 5;
      linesPerChunk = 4;
    }
    
    final List<SubtitleChunk> subtitleChunks = [];
    final List<String> words = fullText.split(' ').where((s) => s.isNotEmpty).toList();
    final int totalWords = words.length;

    if (totalWords == 0 || measuredDuration == 0) {
      subtitleChunks.add(const SubtitleChunk(text: "", lines: [], startTime: 0, duration: 0));
    } else {
      final double durationPerChunk = measuredDuration / chunksToMake;
      final int wordsPerChunk = (totalWords / chunksToMake).floor();
      int wordCursor = 0;

      for (int j = 0; j < chunksToMake; j++) {
        final double chunkStartTime = j * durationPerChunk;
        
        String chunkText;
        double chunkDuration;

        if (j == chunksToMake - 1) {
          chunkText = words.sublist(wordCursor).join(' ');
          chunkDuration = measuredDuration - chunkStartTime;
        } else {
          final int endWordIndex = (wordCursor + wordsPerChunk > totalWords) ? totalWords : (wordCursor + wordsPerChunk);
          chunkText = words.sublist(wordCursor, endWordIndex).join(' ');
          chunkDuration = durationPerChunk;
          wordCursor = endWordIndex;
        }
        
        final String formattedTextForPreview = _injectNewlines(chunkText, maxLines: linesPerChunk);
        final List<String> rawLinesForBackend = [chunkText];

        subtitleChunks.add(SubtitleChunk(
          text: formattedTextForPreview, 
          lines: rawLinesForBackend,     
          startTime: chunkStartTime,
          duration: chunkDuration > 0.1 ? chunkDuration : 0.1,
        ));
      }
    }

    final processedScene = ProcessedSceneData(
      originalScene: scene,
      actualAudioDuration: measuredDuration,
      absoluteStartTime: currentPlaybackTime,
      absoluteEndTime: currentPlaybackTime + measuredDuration,
      subtitleChunks: subtitleChunks,
    );

    processedScenes.add(processedScene);
    
    currentPlaybackTime += measuredDuration;
    totalDuration += measuredDuration;
  }

  yield ProcessedTimelineData(
    introDuration: finalIntroDuration,
    scenes: processedScenes,
    totalTimelineDuration: totalDuration,
    isCalculating: isAnyAudioMissing,
  );

});
//----------------------------------------------------------------------------------------------------//

//No ke-6: FUNGSI PERAKITAN RENDER PACKET //
//Menyiapkan seluruh data timing dan style, lalu mengirimnya ke backend via Firestore. //
Future<void> prepareAndSaveRenderPacket(WidgetRef ref, String projectId) async {
  debugPrint("prepareAndSaveRenderPacket: Memulai perakitan renderPacket untuk $projectId...");
  
  try {
    final firestoreService = ref.read(firestoreServiceProvider);
    final visualSettings = ref.read(visualSettingsProvider(projectId));
    final processedTimeline = await ref.read(processedTimelineProvider(projectId).future);
    final project = await ref.read(projectStreamProvider(projectId).future);

    if (processedTimeline.isCalculating || processedTimeline.scenes.isEmpty) {
      debugPrint("⚠️ prepareAndSaveRenderPacket: Timeline data not ready. Aborting.");
      throw Exception("Timeline data is not ready.");
    }
    
    final double aspectRatioValue = _calculateAspectRatioFromString(project.aspectRatio);

    // [PERBAIKAN ERROR]: Kita ambil flag dari visualSettings, BUKAN dari project.
    final bool enableOverlay = visualSettings.useAssetOverlayEffects; 

    final Map<String, dynamic> renderPacket = {
      'styleSettings': {
          ...visualSettings.toJson(aspectRatioValue),
          'useAssetOverlayEffects': enableOverlay, 
      },
      'timingData': {
        'scenes': processedTimeline.toJson()['scenes'],
        'introDuration': processedTimeline.introDuration,
        'totalTimelineDuration': processedTimeline.totalTimelineDuration,
      },
    };

    await firestoreService.updateProject(
      projectId,
      {'renderPacket': renderPacket},
    );
    
    debugPrint("✅ prepareAndSaveRenderPacket: renderPacket lengkap berhasil disimpan.");

  } catch (e) {
    debugPrint("❌ CRITICAL: Gagal menyimpan renderPacket: $e");
    rethrow;
  }
}

// [PERBAIKAN ERROR]: Fungsi ini dikembalikan agar tidak Error: Method not found
double _calculateAspectRatioFromString(String? ratioString) {
  if (ratioString == null || ratioString.isEmpty) return 16 / 9;
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
//----------------------------------------------------------------------------------------------------//
