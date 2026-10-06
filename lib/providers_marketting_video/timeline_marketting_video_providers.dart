//================================================================//
// NAMA FILE: TIMELINE_MARKETTING_VIDEO_PROVIDERS.DART             //
// DIREKTORI: LIB/PROVIDERS_MARKETTING_VIDEO/                      //
// DESKRIPSI: PROVIDER STREAM UNTUK DATA PROYEK & SCENE MARKETTING//
//================================================================//

// No ke-1: IMPORT DEPENDENSI & SETUP                             //
//----------------------------------------------------------------//
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models_marketting_video/scene_marketting_video.dart';
import '../models_marketting_video/video_project_marketting_video.dart';
import '../providers_marketting_video/firestore_marketting_video_provider.dart';
//----------------------------------------------------------------//

// No ke-2: PROJECT MARKETTING VIDEO STREAM PROVIDER               //
//----------------------------------------------------------------//
// MENYEDIAKAN STREAM UNTUK SATU DOKUMEN PROYEK MARKETTING VIDEO SPESIFIK
final projectMarkettingVideoStreamProvider = StreamProvider.family<VideoProjectMarkettingVideo?, String>((ref, projectId) {
  final firestoreMarkettingVideoService = ref.watch(firestoreMarkettingVideoServiceProvider); 
  
  return firestoreMarkettingVideoService.getProjectStream(projectId).handleError((error, stackTrace) {
      debugPrint("[projectMarkettingVideoStreamProvider] Error fetching project $projectId: $error");
      return null;
  });
});
//----------------------------------------------------------------//

// No ke-3: SCENES MARKETTING VIDEO STREAM PROVIDER                //
//----------------------------------------------------------------//
// MENYEDIAKAN STREAM UNTUK DAFTAR SCENES DARI SEBUAH PROYEK MARKETTING VIDEO
final scenesMarkettingVideoStreamProvider = StreamProvider.family<List<SceneMarkettingVideo>, String>((ref, projectId) {
  final firestoreMarkettingVideoService = ref.watch(firestoreMarkettingVideoServiceProvider); 
  
  return firestoreMarkettingVideoService.getScenesStream(projectId).handleError((error, stackTrace) {
      debugPrint("[scenesMarkettingVideoStreamProvider] Error fetching scenes for $projectId: $error");
      return <SceneMarkettingVideo>[];
  });
});
//----------------------------------------------------------------//