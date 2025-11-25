// NAMA FILE: lib/providers_veo/timeline_veo_providers.dart
// TUJUAN: Versi "Isolasi Total" (Veo) dari Timeline Providers.

import 'package:flutter/foundation.dart'; // Untuk debugPrint
import 'package:flutter_riverpod/flutter_riverpod.dart';
// --- KATEGORI_ISOLASI_VEO: Path diubah ke _veo ---
import '../models_veo/scene_veo.dart';
import '../models_veo/video_project_veo.dart';
// Impor Provider Veo
import '../providers_veo/visual_settings_veo_provider.dart';
// --- AKHIR MODIFIKASI ---

// --- KATEGORI_ISOLASI_VEO: Nama Provider diubah dan tipe disesuaikan ---
// Provider 1: Menyediakan stream untuk SATU dokumen proyek VEO spesifik.
final projectVeoStreamProvider = StreamProvider.family<VideoProjectVeo?, String>((ref, projectId) {
  // Ambil instance FirestoreVeoService
  final firestoreVeoService = ref.watch(firestoreVeoServiceProvider); 
  return firestoreVeoService.getProjectStream(projectId).handleError((error, stackTrace) {
      debugPrint("[projectVeoStreamProvider] Error fetching project $projectId: $error");
      return null;
  });
});
// --- AKHIR MODIFIKASI ---

// --- KATEGORI_ISOLASI_VEO: Nama Provider diubah dan tipe disesuaikan ---
// Provider 2: Menyediakan stream untuk DAFTAR scenes dari sebuah proyek VEO.
final scenesVeoStreamProvider = StreamProvider.family<List<SceneVeo>, String>((ref, projectId) {
  // Ambil instance FirestoreVeoService
  final firestoreVeoService = ref.watch(firestoreVeoServiceProvider); 
  return firestoreVeoService.getScenesStream(projectId).handleError((error, stackTrace) {
      debugPrint("[scenesVeoStreamProvider] Error fetching scenes for $projectId: $error");
      return [];
  });
});
// --- AKHIR MODIFIKASI ---