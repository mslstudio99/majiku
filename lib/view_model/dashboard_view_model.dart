import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/video_project.dart';
import '../services/firestore_service.dart';

// --- KATEGORI_REFAKTORISASI_STRUKTUR (Anti-Regresi) ---
// Mengimpor provider dari satu-satunya sumber kebenaran (Single Source of Truth)
// untuk mencegah ProviderConflictException.
import '../providers/visual_settings_provider.dart';
// --- AKHIR REFAKTORISASI ---

// --- KATEGORI_REFAKTORISASI_STRUKTUR (Anti-Regresi) ---
// Definisi 'firestoreServiceProvider' yang duplikat di sini telah dihapus.
// Provider tersebut sekarang diimpor dari 'visual_settings_provider.dart'
// (yang diimpor di atas) sebagai Single Source of Truth.
//
// final firestoreServiceProvider = ... (DIHAPUS)
// --- AKHIR REFAKTORISASI ---

// Provider 2: A StreamProvider that provides a real-time list of user projects.
// The UI will watch this provider to automatically update when data changes.
final projectsStreamProvider = StreamProvider<List<VideoProject>>((ref) {
  // Ini sekarang akan secara otomatis me-watch 'firestoreServiceProvider' yang diimpor
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.getProjectsForUser();
});

// Provider 3 (Optional but good practice): A provider for view model actions.
// This helps keep action logic separate from the UI.
final dashboardViewModelProvider = Provider((ref) {
  // Ini sekarang akan secara otomatis me-watch 'firestoreServiceProvider' yang diimpor
  final firestoreService = ref.watch(firestoreServiceProvider);
  return DashboardViewModel(firestoreService);
});

class DashboardViewModel {
  final FirestoreService _firestoreService;
  DashboardViewModel(this._firestoreService);

  // Method to delete a project
  Future<void> deleteProject(String projectId) async {
    await _firestoreService.deleteProject(projectId);
  }

  // We can add other methods like 'createNewProject' here later.
}