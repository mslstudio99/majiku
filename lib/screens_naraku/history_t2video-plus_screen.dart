// HISTORY_T2VIDEO-PLUS_SCREEN.DART //
// LIB/SCREENS_NARAKU/HISTORY_T2VIDEO-PLUS_SCREEN.DART //
// KATEGORI: SCREEN & LOGIC MERGED //

// No ke-1 - IMPORTS & DEPENDENCIES //
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart'; 
import 'dart:html' if (dart.library.io) '../utils/html_stub.dart' as html;

import '../providers/config_provider.dart';
import '../models_naraku/video_project_t2video-plus.dart';
import '../services_naraku/firestore_t2video-plus_service.dart';
import '../theme/app_theme.dart';

// Mengimpor layar T2Video-Plus untuk menggunakan VideoPlayerDialog
import 't2video-plus_screen.dart'; 
// Penutup Blok //

// No ke-2 - PROVIDERS & LOGIKA (PENGGANTI VIEW MODEL) //
final firestoreT2videoPlusServiceProvider = Provider<FirestoreT2videoPlusService>((ref) {
  return FirestoreT2videoPlusService();
});

// Stream dirombak agar melakukan sorting secara lokal di Dart (ANTI-CRASH)
final historyT2videoPlusStreamProvider = StreamProvider.autoDispose<List<VideoProjectT2videoPlus>>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  
  if (user == null) {
    return Stream.value([]);
  }
  
  return FirebaseFirestore.instance
      .collection('projects_t2video_plus')
      .where('userid', isEqualTo: user.uid) // Disesuaikan dengan lowercase keys di backend
      .snapshots()
      .map((snapshot) {
    
    // 1. Parsing & Proteksi Null
    final list = snapshot.docs.map((doc) {
      try {
        return VideoProjectT2videoPlus.fromMap(doc.data(), doc.id);
      } catch (e) {
        // Jika ada 1 dokumen korup, abaikan, jangan hancurkan seluruh stream
        debugPrint("Skipping corrupted doc ${doc.id}: $e");
        return null;
      }
    }).where((item) => item != null).cast<VideoProjectT2videoPlus>().toList();
    
    // 2. Sorting Aman (Mencegah NullPointerException pada compareTo)
    list.sort((a, b) {
      // Pastikan kedua objek memiliki createdat sebelum dibandingkan. 
      // Jika model Anda masih menggunakan DateTime (bukan Timestamp), ini akan melindunginya.
      final dateA = a.createdat; 
      final dateB = b.createdat;
      
      // Menangani kasus jika createdat entah bagaimana bisa lolos sebagai null (meski seharusnya tidak)
      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1; // Taruh di bawah
      if (dateB == null) return -1; // Taruh di bawah
      
      return dateB.compareTo(dateA); 
    });
    
    return list;
  });
});
// Penutup Blok //

// No ke-3 - STATEFUL WIDGET & HELPER DIALOG //
class HistoryT2videoPlusScreen extends ConsumerStatefulWidget {
  const HistoryT2videoPlusScreen({super.key});

  @override
  ConsumerState<HistoryT2videoPlusScreen> createState() => _HistoryT2videoPlusScreenState();
}

class _HistoryT2videoPlusScreenState extends ConsumerState<HistoryT2videoPlusScreen> {
  
  // Dialog Kaya (Rich Dialog) dengan Video Player & Download
  void _showVideoDetailDialog(BuildContext context, VideoProjectT2videoPlus project, bool isIndo) {
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
                              // Memanggil Video Player yang ada di t2video-plus_screen.dart
                              showDialog(
                                context: context,
                                builder: (context) => VideoPlayerDialog(videoUrl: project.videourl),
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
                  Text("${t('Ratio', 'Rasio')}: ${project.aspectratio} | Res: ${project.resolution}p", style: const TextStyle(color: Colors.white70)),
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
                      // Menggunakan arsitektur Native Delegation dengan videourl (lowercase)
                      final Uri url = Uri.parse(project.videourl);
                      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Could not open link: ${project.videourl}'), backgroundColor: Colors.red),
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
// Penutup Blok //

// No ke-4 - BUILD METHOD UTAMA //
  @override
  Widget build(BuildContext context) {
    final projectsAsyncValue = ref.watch(historyT2videoPlusStreamProvider);
    final currentLocale = ref.watch(appLanguageProvider);
    final isIndo = currentLocale.languageCode == 'id';
    
    String t(String en, String id) => isIndo ? id : en;

    return Theme(
      data: AppTheme.darkTheme,
      child: Scaffold(
        appBar: AppBar(
          title: Text(t('T2Video-Plus History', 'Histori T2Video-Plus')),
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
// Penutup Blok //

// No ke-5 - LIST BUILDER HISTORI //
  Widget _buildProjectList(BuildContext context, WidgetRef ref,
      AsyncValue<List<VideoProjectT2videoPlus>> asyncValue, bool isIndo) {
    
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
              final VideoProjectT2videoPlus project = projects[index];
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
                        "${project.style} • ${project.aspectratio} • ${t('Completed', 'Selesai')}",
                        style: TextStyle(color: Colors.green.shade400, fontSize: 12),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                        tooltip: t('Delete Record', 'Hapus Riwayat'),
                        onPressed: () async {
                          try {
                            await ref.read(firestoreT2videoPlusServiceProvider).deleteProject(project.id);
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
// Penutup Blok //