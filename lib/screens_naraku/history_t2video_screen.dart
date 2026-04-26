// [NAMA FILE: HISTORY_T2VIDEO_SCREEN.DART] //
// [DIREKTORI: LIB/SCREENS_NARAKU/HISTORY_T2VIDEO_SCREEN.DART] //
// [KATEGORI: SCREEN & LOGIC MERGED] //

// No ke-1: IMPORTS & DEPENDENCIES //
//.......................................................//
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart'; // [BARU] Import untuk Native Download Delegation
import 'dart:html' if (dart.library.io) '../utils/html_stub.dart' as html;

import '../providers/config_provider.dart';
import '../models_naraku/video_project_t2video.dart';
import '../services_naraku/firestore_t2video_service.dart';
import '../theme/app_theme.dart';

// [PENTING] Mengimpor layar T2Video untuk menggunakan VideoPlayerDialog
import 't2video_screen.dart'; 
//.......................................................//

// No ke-2: PROVIDERS & LOGIKA (PENGGANTI VIEW MODEL) //
//.......................................................//
final firestoreT2VideoServiceProvider = Provider<FirestoreT2VideoService>((ref) {
  return FirestoreT2VideoService();
});

// [PERBAIKAN ERROR INDEX FIRESTORE]
// Stream dirombak agar melakukan sorting secara lokal di Dart, 
// sehingga Anda tidak perlu repot membuat Composite Index di Firebase.
final historyT2VideoStreamProvider = StreamProvider.autoDispose<List<VideoProjectT2Video>>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  
  if (user == null) {
    return Stream.value([]);
  }
  
  return FirebaseFirestore.instance
      .collection('projects_t2video')
      .where('userId', isEqualTo: user.uid)
      .snapshots()
      .map((snapshot) {
    final list = snapshot.docs.map((doc) {
      return VideoProjectT2Video.fromMap(doc.data(), doc.id);
    }).toList();
    
    // Melakukan pengurutan dari yang terbaru ke terlama secara lokal
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  });
});
//.......................................................//

// No ke-3: STATEFUL WIDGET & HELPER DIALOG //
//.......................................................//
class HistoryT2VideoScreen extends ConsumerStatefulWidget {
  const HistoryT2VideoScreen({super.key});

  @override
  ConsumerState<HistoryT2VideoScreen> createState() => _HistoryT2VideoScreenState();
}

class _HistoryT2VideoScreenState extends ConsumerState<HistoryT2VideoScreen> {
  
  // Dialog Kaya (Rich Dialog) dengan Video Player & Download
  void _showVideoDetailDialog(BuildContext context, VideoProjectT2Video project, bool isIndo) {
    String t(String en, String id) => isIndo ? id : en;
    bool isDownloading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            backgroundColor: Colors.grey[900],
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(t('Video Details', 'Detail Video'), style: const TextStyle(color: Colors.white)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- AREA VIDEO THUMBNAIL & PLAY ---
                  Container(
                    height: 180,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.black,
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const ClipRRect(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                          child: GridPaper(color: Colors.white10, divisions: 2, subdivisions: 2),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.blueAccent.withOpacity(0.9),
                            boxShadow: [
                              BoxShadow(color: Colors.blueAccent.withOpacity(0.6), blurRadius: 10, spreadRadius: 2)
                            ]
                          ),
                          child: IconButton(
                            iconSize: 45,
                            icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
                            onPressed: () {
                              // Memanggil Video Player yang ada di t2video_screen.dart
                              showDialog(
                                context: context,
                                builder: (context) => VideoPlayerDialog(videoUrl: project.videoUrl),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // --- DETAIL TEKS ---
                  Text("${t('Prompt', 'Narasi')}:", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  Text(project.prompt, style: const TextStyle(color: Colors.white)),
                  const SizedBox(height: 12),
                  Text("${t('Style', 'Gaya')}: ${project.style}", style: const TextStyle(color: Colors.white70)),
                  Text("${t('Ratio', 'Rasio')}: ${project.aspectRatio} | Res: ${project.resolution}p", style: const TextStyle(color: Colors.white70)),
                ],
              ),
            ),
            actions: [
              // --- TOMBOL DOWNLOAD ---
              if (isDownloading)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.greenAccent)),
                )
              else
                TextButton.icon(
                  icon: const Icon(Icons.download_rounded, color: Colors.greenAccent),
                  label: Text(t('Download', 'Unduh'), style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    setStateDialog(() => isDownloading = true);
                    try {
                      // [PERBAIKAN] Menggunakan arsitektur Native Delegation
                      final Uri url = Uri.parse(project.videoUrl);
                      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Could not open link: ${project.videoUrl}'), backgroundColor: Colors.red),
                          );
                        }
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                        );
                      }
                    } finally {
                      if (mounted) {
                        setStateDialog(() => isDownloading = false);
                      }
                    }
                  },
                ),
              // --- TOMBOL TUTUP ---
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(t('Close', 'Tutup'), style: const TextStyle(color: Colors.white)),
              ),
            ],
          );
        }
      ),
    );
  }
//.......................................................//

// No ke-4: BUILD METHOD UTAMA //
//.......................................................//
  @override
  Widget build(BuildContext context) {
    final projectsAsyncValue = ref.watch(historyT2VideoStreamProvider);
    final currentLocale = ref.watch(appLanguageProvider);
    final isIndo = currentLocale.languageCode == 'id';
    
    String t(String en, String id) => isIndo ? id : en;

    return Theme(
      data: AppTheme.darkTheme,
      child: Scaffold(
        appBar: AppBar(
          title: Text(t('T2Video History', 'Histori T2Video')),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: CustomScrollView(
          slivers: [
            _buildProjectList(context, ref, projectsAsyncValue, isIndo),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
//.......................................................//

// No ke-5: LIST BUILDER HISTORI //
//.......................................................//
  Widget _buildProjectList(BuildContext context, WidgetRef ref,
      AsyncValue<List<VideoProjectT2Video>> asyncValue, bool isIndo) {
    
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
            child: Text('Error: $error', style: const TextStyle(color: Colors.red)),
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
                  t('No generated videos yet.', 'Belum ada video yang dihasilkan.'),
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
              final VideoProjectT2Video project = projects[index];
              return Card(
                elevation: 2,
                color: Colors.grey[900],
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: InkWell(
                  hoverColor: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    _showVideoDetailDialog(context, project, isIndo);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: ListTile(
                      leading: const Icon(Icons.video_library, color: Colors.blueAccent),
                      title: Text(
                        project.prompt,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.white),
                      ),
                      subtitle: Text(
                        "${project.style} • ${project.aspectRatio} • ${t('Completed', 'Selesai')}",
                        style: TextStyle(color: Colors.green.shade400, fontSize: 12),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                        tooltip: t('Delete Record', 'Hapus Riwayat'),
                        onPressed: () async {
                          try {
                            await ref.read(firestoreT2VideoServiceProvider).deleteProject(project.id);
                          } catch (e) {
                            debugPrint("Error deleting project: $e");
                          }
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