// lib/screens //
// history_motion_screen.dart //
// Menampilkan daftar histori proyek VMotion (Imagen) secara terpisah //

// No ke-1 //
// IMPORTS & DEPENDENCIES //
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/config_provider.dart';
import '../models/video_project.dart';
import '../view_model/dashboard_view_model.dart';
import 'timeline_review_screen.dart';
import 'project_loading_screen.dart';
import '../theme/app_theme.dart';
//.......................................................//

// No ke-2 //
// STATEFUL WIDGET & HELPER //
class HistoryMotionScreen extends ConsumerStatefulWidget {
  const HistoryMotionScreen({super.key});

  @override
  ConsumerState<HistoryMotionScreen> createState() => _HistoryMotionScreenState();
}

class _HistoryMotionScreenState extends ConsumerState<HistoryMotionScreen> {
  
  Widget _buildStatus(BuildContext context, VideoProject project, bool isIndo) {
    final String status = project.status ?? 'UNKNOWN';
    String t(String en, String id) => isIndo ? id : en;

    if (status == 'RENDER_COMPLETED' &&
        project.finalVideoUrl != null &&
        project.finalVideoUrl!.isNotEmpty) {
      return Text(
        t('Render Success', 'Render Berhasil'),
        style: TextStyle(
          color: Colors.green.shade700,
          fontWeight: FontWeight.bold,
        ),
      );
    }
    return Text('Status: $status');
  }
//.......................................................//

// No ke-3 //
// BUILD METHOD UTAMA //
  @override
  Widget build(BuildContext context) {
    final projectsAsyncValue = ref.watch(projectsStreamProvider);
    final currentLocale = ref.watch(appLanguageProvider);
    final isIndo = currentLocale.languageCode == 'id';
    
    String t(String en, String id) => isIndo ? id : en;

    return Theme(
      data: AppTheme.darkTheme,
      child: Scaffold(
        appBar: AppBar(
          title: Text(t('History VMotion', 'Histori VMotion')),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: CustomScrollView(
          slivers: [
            _buildImagenProjectList(context, ref, projectsAsyncValue, isIndo),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
//.......................................................//

// No ke-4 //
// LIST BUILDER HISTORI //
  Widget _buildImagenProjectList(BuildContext context, WidgetRef ref,
      AsyncValue<List<VideoProject>> asyncValue, bool isIndo) {
    
    String t(String en, String id) => isIndo ? id : en;

    return asyncValue.when(
      loading: () => const SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: CircularProgressIndicator(),
          ),
        ),
      ),
      error: (error, stack) => SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('Error loading Motion projects: $error'),
          ),
        ),
      ),
      data: (projects) {
        if (projects.isEmpty) {
          return SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  t('No (Motion) projects yet.', 'Belum ada proyek (Motion).'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            ),
          );
        }
        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final VideoProject project = projects[index];
              return Card(
                elevation: 2,
                color: Colors.grey[900],
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: InkWell(
                  hoverColor: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    final String status = project.status ?? '';
                    if (status == 'ASSETS_COMPLETE' ||
                        status == 'RENDER_START' ||
                        status == 'RENDERING' ||
                        status == 'RENDER_COMPLETED' ||
                        status.startsWith('ERROR_')) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) =>
                              TimelineReviewScreen(projectId: project.id),
                        ),
                      );
                    } else {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) =>
                              ProjectLoadingScreen(projectId: project.id),
                        ),
                      );
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: ListTile(
                      leading: const Icon(Icons.image_search, color: Colors.blueAccent),
                      title: Text(
                        project.title,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: _buildStatus(context, project, isIndo),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                        tooltip: t('Delete Project', 'Hapus Proyek'),
                        onPressed: () {
                          ref
                              .read(dashboardViewModelProvider)
                              .deleteProject(project.id);
                        },
                      ),
                    ),
                  ),
                ),
              );
            },
            childCount: projects.length,
          ),
        );
      },
    );
  }
}
//.......................................................//