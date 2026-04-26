//VIEW_MODEL_STORINEMA//
//DASHBOARD_STORINEMA_VIEW_MODEL.DART//
//VIEW MODEL UNTUK MANAJEMEN STATE DASHBOARD STORINEMA//

//No ke-1 IMPORT DEPENDENSI//
//IMPORT PACKAGE DAN REFERENSI STORINEMA//
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models_storinema/video_project_storinema.dart';
import '../services_storinema/firestore_storinema_service.dart';
import '../providers_storinema/visual_settings_storinema_provider.dart';
//........//

//No ke-2 DEKLARASI PROVIDER//
//STREAM PROVIDER DAN VIEW MODEL PROVIDER STORINEMA//
final projectsStorinemaStreamProvider = StreamProvider<List<VideoProjectStorinema>>((ref) {
  final firestoreService = ref.watch(firestoreStorinemaServiceProvider);
  return firestoreService.getProjectsForUser();
});

final dashboardStorinemaViewModelProvider = Provider((ref) {
  final firestoreService = ref.watch(firestoreStorinemaServiceProvider);
  return DashboardStorinemaViewModel(firestoreService);
});
//........//

//No ke-3 CLASS VIEW MODEL//
//LOGIKA MANAJEMEN STATE DASHBOARD STORINEMA//
class DashboardStorinemaViewModel {
  final FirestoreStorinemaService _firestoreService;

  DashboardStorinemaViewModel(this._firestoreService);

  Future<void> deleteProject(String projectId) async {
    await _firestoreService.deleteProject(projectId);
  }
}
//........//