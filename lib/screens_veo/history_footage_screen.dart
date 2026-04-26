// lib/screens_veo //
// history_footage_screen.dart //
// Menampilkan daftar histori proyek VFootage (Veo) secara terpisah //

// No ke-1 //
// IMPORTS & DEPENDENCIES //
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/config_provider.dart';
import '../models_veo/video_project_veo.dart';
import '../view_model_veo/dashboard_veo_view_model.dart';
import 'timeline_review_veo_screen.dart';
import 'project_loading_veo_screen.dart';
import '../theme/app_theme.dart';
//.......................................................//

// No ke-2 //
// STATEFUL WIDGET & HELPER //
class HistoryFootageScreen extends ConsumerStatefulWidget {
  const HistoryFootageScreen({super.key});

  @override
  ConsumerState<HistoryFootageScreen> createState() => _HistoryFootageScreenState();
}

class _HistoryFootageScreenState extends ConsumerState<HistoryFootageScreen> {
  
  Widget _buildStatusVeo(BuildContext context, VideoProjectVeo project, bool isIndo) {
    final String status = project.status ?? 'UNKNOWN';
    String t(String en, String id) => isIndo ? id : en;

    if (status == 'ASSETS_COMPLETE') {
      return Text(
        t('Assets Ready', 'Aset Siap'),
        style: TextStyle(
          color: Colors.green.shade700,
          fontWeight: FontWeight.bold,
        ),
      );
    }
    if (status == 'RENDER_READY') {
      return Text(
        t('Ready to Render', 'Siap Render'),
        style: const TextStyle(
          color: Colors.blueAccent,
          fontWeight: FontWeight.bold,
        ),
      );
    }
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
    if (status.startsWith('ERROR_')) {
      return Text(
        '${t('Error', 'Eror')}: $status',
        style: const TextStyle(
          color: Colors.redAccent,
          fontWeight: FontWeight.bold,
        ),
        overflow: TextOverflow.ellipsis,
      );
    }
    return Text('Status: $status');
  }
//.......................................................//

// No ke-3 //
// BUILD METHOD UTAMA //
  @override
  Widget build(BuildContext context) {
    final projectsVeoAsyncValue = ref.watch(projectsVeoStreamProvider);
    final currentLocale = ref.watch(appLanguageProvider);
    final isIndo = currentLocale.languageCode == 'id';
    
    String t(String en, String id) => isIndo ? id : en;

    return Theme(
      data: AppTheme.darkTheme,
      child: Scaffold(
        appBar: AppBar(
          title: Text(t('History VFootage', 'Histori VFootage')),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: CustomScrollView(
          slivers: [
            _buildVeoProjectList(context, ref, projectsVeoAsyncValue, isIndo),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
//.......................................................//

// No ke-4 //
// LIST BUILDER HISTORI //
  Widget _buildVeoProjectList(BuildContext context, WidgetRef ref,
      AsyncValue<List<VideoProjectVeo>> asyncValue, bool isIndo) {
    
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
            child: Text('Error loading Footage projects: $error'),
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
                  t('No (Footage) projects yet.', 'Belum ada proyek (Footage).'),
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
              final VideoProjectVeo project = projects[index];
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
                        status == 'RENDER_READY' ||
                        status == 'RENDER_START' ||
                        status == 'RENDERING' ||
                        status == 'RENDER_COMPLETED' ||
                        status.startsWith('ERROR_')) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) =>
                              TimelineReviewVeoScreen(projectId: project.id),
                        ),
                      );
                    } else {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) =>
                              ProjectLoadingVeoScreen(projectId: project.id),
                        ),
                      );
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: ListTile(
                      leading: const Icon(Icons.movie_filter, color: Colors.deepPurpleAccent),
                      title: Text(
                        project.title,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: _buildStatusVeo(context, project, isIndo),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                        tooltip: t('Delete Project', 'Hapus Proyek'),
                        onPressed: () {
                          ref
                              .read(dashboardVeoViewModelProvider)
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