//................................................................//
// NAMA FILE: TIMELINE_STORINEMA_PROVIDERS.DART                   //
// PATH: LIB/PROVIDERS_STORINEMA/TIMELINE_STORINEMA_PROVIDERS.DART//
// DESKRIPSI: PROVIDER STREAM UNTUK DATA PROYEK & SCENE STORINEMA //
//................................................................//

//No ke-1: IMPORT DEPENDENSI & SETUP .............................//
//................................................................//
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models_storinema/scene_storinema.dart';
import '../models_storinema/video_project_storinema.dart';
import '../providers_storinema/firestore_storinema_provider.dart';
//................................................................//

//No ke-2: PROJECT STORINEMA STREAM PROVIDER .....................//
//................................................................//
// MENYEDIAKAN STREAM UNTUK SATU DOKUMEN PROYEK STORINEMA SPESIFIK
final projectStorinemaStreamProvider = StreamProvider.family<VideoProjectStorinema?, String>((ref, projectId) {
  final firestoreStorinemaService = ref.watch(firestoreStorinemaServiceProvider); 
  
  return firestoreStorinemaService.getProjectStream(projectId).handleError((error, stackTrace) {
      debugPrint("[projectStorinemaStreamProvider] Error fetching project $projectId: $error");
      return null;
  });
});
//................................................................//

//No ke-3: SCENES STORINEMA STREAM PROVIDER ......................//
//................................................................//
// MENYEDIAKAN STREAM UNTUK DAFTAR SCENES DARI SEBUAH PROYEK STORINEMA
final scenesStorinemaStreamProvider = StreamProvider.family<List<SceneStorinema>, String>((ref, projectId) {
  final firestoreStorinemaService = ref.watch(firestoreStorinemaServiceProvider); 
  
  return firestoreStorinemaService.getScenesStream(projectId).handleError((error, stackTrace) {
      debugPrint("[scenesStorinemaStreamProvider] Error fetching scenes for $projectId: $error");
      return <SceneStorinema>[];
  });
});
//................................................................//