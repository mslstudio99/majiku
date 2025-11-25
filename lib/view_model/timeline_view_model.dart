// [RILIS BERSIH - TIMELINE VIEW MODEL SMART ENGINE]
// KATEGORI_SMART_ENGINE NO_URUT_01
// Lokasi: lib/view_model/timeline_view_model.dart
// TUJUAN:
// - Mengirim teks RAW ke backend agar Libass bisa melakukan Auto-Wrap.
// - Tetap memotong baris untuk Preview di UI Flutter agar rapi.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'dart:math'; 

import '../models/scene.dart';
import '../models/video_project.dart';
import '../services/firestore_service.dart';
import '../providers/visual_settings_provider.dart';

// =========================================================================
// === BAGIAN 1: PROVIDER BAHAN MENTAH ===
// =========================================================================

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


// =========================================================================
// === BAGIAN 2: MODEL DATA "MATANG" ===
// =========================================================================

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

// =========================================================================
// === BAGIAN 3: HELPER PENGUKURAN AUDIO & TEXT ===
// =========================================================================
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

// Helper untuk Preview UI (Flutter) agar teks tidak melebar
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


// =========================================================================
// === BAGIAN 4: "PABRIK PROVIDER" TERPUSAT (SMART ENGINE READY) ===
// =========================================================================

final processedTimelineProvider = StreamProvider.family<ProcessedTimelineData, String>((ref, projectId) async* {
  
  // 1. Tonton Bahan Mentah
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

  // --- "PABRIK" DIMULAI ---
  final bool isAnyAudioMissing = scenes.any((s) => s.ttsAudioUrl.isEmpty);

  // 3. Eksekusi Pengukuran Durasi Audio
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


  // 4. "Memasak" Data
  final List<ProcessedSceneData> processedScenes = [];
  double currentPlaybackTime = finalIntroDuration;
  double totalDuration = finalIntroDuration;

  final String aspectRatio = project.aspectRatio ?? "16:9";

  for (int i = 0; i < scenes.length; i++) {
    final scene = scenes[i];
    final double measuredDuration = actualSceneDurations[i];
    final String fullText = scene.segmentText ?? "";
    
    // --- ATURAN RASIO ---
    final int chunksToMake;
    final int linesPerChunk;

    if (aspectRatio == "16:9") {
      // 16:9: Lebih lebar, sedikit chunk, sedikit baris
      chunksToMake = 2;
      linesPerChunk = 3;
    } else {
      // 9:16 / 1:1: Lebih sempit, lebih banyak chunk, lebih banyak baris
      chunksToMake = 5;
      linesPerChunk = 4;
    }
    
    final List<SubtitleChunk> subtitleChunks = [];
    final List<String> words = fullText.split(' ').where((s) => s.isNotEmpty).toList();
    final int totalWords = words.length;

    if (totalWords == 0 || measuredDuration == 0) {
      subtitleChunks.add(const SubtitleChunk(text: "", lines: [], startTime: 0, duration: 0));
    } else {
      // 4d. Eksekusi Algoritma Chunking
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
        
        // --- KATEGORI_SMART_ENGINE (Frontend Adjustment) ---
        // 1. Untuk PREVIEW (Flutter): Gunakan _injectNewlines agar rapi di HP
        final String formattedTextForPreview = _injectNewlines(chunkText, maxLines: linesPerChunk);

        // 2. Untuk RENDER (Backend): Kirim RAW TEXT dalam list.
        // Libass di backend akan mengurus wrapping secara otomatis & rapi.
        final List<String> rawLinesForBackend = [chunkText];
        // --- AKHIR PENYESUAIAN ---

        subtitleChunks.add(SubtitleChunk(
          text: formattedTextForPreview, // Pratinjau (Ada \n)
          lines: rawLinesForBackend,     // Render (Raw String)
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

  // 5. Yield Data
  yield ProcessedTimelineData(
    introDuration: finalIntroDuration,
    scenes: processedScenes,
    totalTimelineDuration: totalDuration,
    isCalculating: isAnyAudioMissing,
  );

});

// =========================================================================
// === BAGIAN 5: FUNGSI "PERAKITAN" UTAMA ===
// =========================================================================

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

    final Map<String, dynamic> renderPacket = {
      'styleSettings': visualSettings.toJson(aspectRatioValue),
      'timingData': {
        'scenes': processedTimeline.toJson()['scenes'],
        'introDuration': processedTimeline.introDuration,
        'totalTimelineDuration': processedTimeline.totalTimelineDuration,
      },
    };

    // Simpan
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