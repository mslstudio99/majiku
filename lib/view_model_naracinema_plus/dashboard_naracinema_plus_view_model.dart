//================================================================//
// NAMA FILE: DASHBOARD_NARACINEMA_PLUS_VIEW_MODEL.DART           //
// DIREKTORI: LIB/VIEW_MODEL_NARACINEMA_PLUS/                     //
// DESKRIPSI: VIEW MODEL MANAJEMEN STATE DASHBOARD NARACINEMA PLUS//
//================================================================//

// No ke-1: IMPORT DEPENDENSI                                     //
//----------------------------------------------------------------//
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models_naracinema_plus/video_project_naracinema_plus.dart';
import '../services_naracinema_plus/firestore_naracinema_plus_service.dart';
import '../providers_naracinema_plus/visual_settings_naracinema_plus_provider.dart';
//----------------------------------------------------------------//

// No ke-2: DEKLARASI PROVIDER                                    //
//----------------------------------------------------------------//
final projectsNaracinemaPlusStreamProvider = StreamProvider<List<VideoProjectNaracinemaPlus>>((ref) {
  final firestoreService = ref.watch(firestoreNaracinemaPlusServiceProvider);
  return firestoreService.getProjectsForUser();
});

final dashboardNaracinemaPlusViewModelProvider = Provider((ref) {
  final firestoreService = ref.watch(firestoreNaracinemaPlusServiceProvider);
  return DashboardNaracinemaPlusViewModel(firestoreService);
});
//----------------------------------------------------------------//

// No ke-3: CLASS VIEW MODEL                                      //
//----------------------------------------------------------------//
class DashboardNaracinemaPlusViewModel {
  final FirestoreNaracinemaPlusService _firestoreService;

  DashboardNaracinemaPlusViewModel(this._firestoreService);

  Future<void> deleteProject(String projectId) async {
    await _firestoreService.deleteProject(projectId);
  }
}
//----------------------------------------------------------------//