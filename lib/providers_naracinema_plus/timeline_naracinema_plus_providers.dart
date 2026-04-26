//================================================================//
// NAMA FILE: TIMELINE_NARACINEMA_PLUS_PROVIDERS.DART             //
// DIREKTORI: LIB/PROVIDERS_NARACINEMA_PLUS/                      //
// DESKRIPSI: PROVIDER STREAM UNTUK DATA PROYEK & SCENE NARACINEMA//
//================================================================//

// No ke-1: IMPORT DEPENDENSI & SETUP                             //
//----------------------------------------------------------------//
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models_naracinema_plus/scene_naracinema_plus.dart';
import '../models_naracinema_plus/video_project_naracinema_plus.dart';
import '../providers_naracinema_plus/firestore_naracinema_plus_provider.dart';
//----------------------------------------------------------------//

// No ke-2: PROJECT NARACINEMA PLUS STREAM PROVIDER               //
//----------------------------------------------------------------//
// MENYEDIAKAN STREAM UNTUK SATU DOKUMEN PROYEK NARACINEMA SPESIFIK
final projectNaracinemaPlusStreamProvider = StreamProvider.family<VideoProjectNaracinemaPlus?, String>((ref, projectId) {
  final firestoreNaracinemaPlusService = ref.watch(firestoreNaracinemaPlusServiceProvider); 
  
  return firestoreNaracinemaPlusService.getProjectStream(projectId).handleError((error, stackTrace) {
      debugPrint("[projectNaracinemaPlusStreamProvider] Error fetching project $projectId: $error");
      return null;
  });
});
//----------------------------------------------------------------//

// No ke-3: SCENES NARACINEMA PLUS STREAM PROVIDER                //
//----------------------------------------------------------------//
// MENYEDIAKAN STREAM UNTUK DAFTAR SCENES DARI SEBUAH PROYEK NARACINEMA
final scenesNaracinemaPlusStreamProvider = StreamProvider.family<List<SceneNaracinemaPlus>, String>((ref, projectId) {
  final firestoreNaracinemaPlusService = ref.watch(firestoreNaracinemaPlusServiceProvider); 
  
  return firestoreNaracinemaPlusService.getScenesStream(projectId).handleError((error, stackTrace) {
      debugPrint("[scenesNaracinemaPlusStreamProvider] Error fetching scenes for $projectId: $error");
      return <SceneNaracinemaPlus>[];
  });
});
//----------------------------------------------------------------//