//================================================================//
// NAMA FILE: DASHBOARD_MARKETTING_VIDEO_VIEW_MODEL.DART           //
// DIREKTORI: LIB/VIEW_MODEL_MARKETTING_VIDEO/                      //
// DESKRIPSI: VIEW MODEL MANAJEMEN STATE DASHBOARD MARKETTING VIDEO//
//================================================================//

// No ke-1: IMPORT DEPENDENSI                                     //
//----------------------------------------------------------------//
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models_marketting_video/video_project_marketting_video.dart';
import '../services_marketting_video/firestore_marketting_video_service.dart';
import '../providers_marketting_video/firestore_marketting_video_provider.dart';
//----------------------------------------------------------------//

// No ke-2: DEKLARASI PROVIDER                                    //
//----------------------------------------------------------------//
final projectsMarkettingVideoStreamProvider = StreamProvider<List<VideoProjectMarkettingVideo>>((ref) {
  final firestoreService = ref.watch(firestoreMarkettingVideoServiceProvider);
  return firestoreService.getProjectsForUser();
});

final dashboardMarkettingVideoViewModelProvider = Provider((ref) {
  final firestoreService = ref.watch(firestoreMarkettingVideoServiceProvider);
  return DashboardMarkettingVideoViewModel(firestoreService);
});
//----------------------------------------------------------------//

// No ke-3: CLASS VIEW MODEL                                      //
//----------------------------------------------------------------//
class DashboardMarkettingVideoViewModel {
  final FirestoreMarkettingVideoService _firestoreService;

  DashboardMarkettingVideoViewModel(this._firestoreService);

  Future<void> deleteProject(String projectId) async {
    await _firestoreService.deleteProject(projectId);
  }
}
//----------------------------------------------------------------//