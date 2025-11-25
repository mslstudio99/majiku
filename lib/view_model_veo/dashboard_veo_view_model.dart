// --- KATEGORI_ISOLASI_VEO: Path file: view_model_veo/dashboard_veo_view_model.dart ---

import 'package:flutter_riverpod/flutter_riverpod.dart';
// --- KATEGORI_ISOLASI_VEO: Impor diubah ke _veo ---
import '../models_veo/video_project_veo.dart';
import '../services_veo/firestore_veo_service.dart';

// Mengimpor provider dari satu-satunya sumber kebenaran (VEO)
import '../providers_veo/visual_settings_veo_provider.dart';
// --- AKHIR MODIFIKASI ---


// (Provider 'firestoreVeoServiceProvider' sekarang diimpor dari visual_settings_veo_provider.dart)

// Provider 2: StreamProvider yang menyediakan daftar proyek VEO.
// --- KATEGORI_ISOLASI_VEO: Provider diubah namanya dan tipe datanya ---
final projectsVeoStreamProvider = StreamProvider<List<VideoProjectVeo>>((ref) {
  // Ini sekarang me-watch provider VEO
  final firestoreService = ref.watch(firestoreVeoServiceProvider);
  // --- AKHIR MODIFIKASI ---
  return firestoreService.getProjectsForUser();
});

// Provider 3: Provider untuk view model VEO.
// --- KATEGORI_ISOLASI_VEO: Provider diubah namanya ---
final dashboardVeoViewModelProvider = Provider((ref) {
  // Ini sekarang me-watch provider VEO
  final firestoreService = ref.watch(firestoreVeoServiceProvider);
  // --- AKHIR MODIFIKASI ---
  return DashboardVeoViewModel(firestoreService);
});

// --- KATEGORI_ISOLASI_VEO: Class diubah namanya ---
class DashboardVeoViewModel {
  // --- KATEGORI_ISOLASI_VEO: Tipe service diubah ---
  final FirestoreVeoService _firestoreService;
  // --- AKHIR MODIFIKASI ---
  
  // --- KATEGORI_ISOLASI_VEO: Konstruktor diubah ---
  DashboardVeoViewModel(this._firestoreService);
  // --- AKHIR MODIFIKASI ---

  // Method to delete a project (Logika ini tetap valid, _firestoreService adalah instance Veo)
  Future<void> deleteProject(String projectId) async {
    await _firestoreService.deleteProject(projectId);
  }

  // We can add other methods like 'createNewProject' here later.
}