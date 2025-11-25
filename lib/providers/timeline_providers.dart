// lib/providers/timeline_providers.dart
import 'package:flutter/foundation.dart'; // Untuk debugPrint
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/scene.dart';
import '../models/video_project.dart';

// --- KATEGORI_PERBAIKAN_ERROR NO_URUT_01: Mengimpor Provider yang Hilang ---
// Definisi 'firestoreServiceProvider' (dan Provider lainnya)
// berada di visual_settings_provider.dart, BUKAN di firestore_service.dart.
// File timeline_providers.dart SANGAT membutuhkan ini.
import '../providers/visual_settings_provider.dart';
// --- AKHIR PERBAIKAN ---

// Provider 1: Menyediakan stream untuk SATU dokumen proyek spesifik.
final projectStreamProvider = StreamProvider.family<VideoProject?, String>((ref, projectId) {
  // Ambil instance FirestoreService dari provider yang benar
  final firestoreService = ref.watch(firestoreServiceProvider); 
  // ... (Logika Error Handling Asli)
  return firestoreService.getProjectStream(projectId).handleError((error, stackTrace) {
      debugPrint("[projectStreamProvider] Error fetching project $projectId: $error");
      return null;
  });
});

// Provider 2: Menyediakan stream untuk DAFTAR scenes dari sebuah proyek.
final scenesStreamProvider = StreamProvider.family<List<Scene>, String>((ref, projectId) {
  // Ambil instance FirestoreService dari provider yang benar
  final firestoreService = ref.watch(firestoreServiceProvider); 
  // ... (Logika Error Handling Asli)
  return firestoreService.getScenesStream(projectId).handleError((error, stackTrace) {
      debugPrint("[scenesStreamProvider] Error fetching scenes for $projectId: $error");
      return [];
  });
});