//LIB/SCREENS_NARAKU/HISTORY_T2IMAGE_SCREEN.DART//
//KATEGORI: SCREEN & LOGIC MERGED//
//HISTORI T2IMAGE//


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
import 'package:url_launcher/url_launcher.dart'; // [BARU] Import url_launcher untuk multiplatform
import 'dart:html' if (dart.library.io) '../utils/html_stub.dart' as html;

import '../providers/config_provider.dart';
import '../models_naraku/image_project_t2image.dart';
import '../services_naraku/firestore_t2image_service.dart';
import '../theme/app_theme.dart';
//.......................................................//

// No ke-2: PROVIDERS & LOGIKA //
//.......................................................//
final firestoreT2ImageServiceProvider = Provider<FirestoreT2ImageService>((ref) {
  return FirestoreT2ImageService();
});

final historyT2ImageStreamProvider = StreamProvider.autoDispose<List<ImageProjectT2Image>>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  
  if (user == null) {
    return Stream.value([]);
  }
  
  return ref.watch(firestoreT2ImageServiceProvider).streamUserProjects(user.uid);
});
//.......................................................//

// No ke-3: STATEFUL WIDGET & HELPER DIALOG //
// No ke-3: STATEFUL WIDGET & HELPER DIALOG //
//.......................................................//
class HistoryT2ImageScreen extends ConsumerStatefulWidget {
  const HistoryT2ImageScreen({super.key});

  @override
  ConsumerState<HistoryT2ImageScreen> createState() => _HistoryT2ImageScreenState();
}

class _HistoryT2ImageScreenState extends ConsumerState<HistoryT2ImageScreen> {
  
  void _showImageDetailDialog(BuildContext context, ImageProjectT2Image project, bool isIndo) {
    String t(String en, String id) => isIndo ? id : en;
    bool isDownloading = false;
    final screenSize = MediaQuery.of(context).size;

    // Helper Rasio
    double getAspectRatio(String ratio) {
      try {
        final parts = ratio.split(':');
        if (parts.length == 2) return double.parse(parts[0]) / double.parse(parts[1]);
      } catch (_) {}
      return 1.0;
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            backgroundColor: Colors.grey[900],
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(t('Image Details', 'Detail Gambar'), style: const TextStyle(color: Colors.white)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    constraints: BoxConstraints(maxHeight: screenSize.height * 0.5),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: AspectRatio(
                        aspectRatio: getAspectRatio(project.aspectRatio),
                        child: Image.network(
                          project.imageUrl,
                          fit: BoxFit.contain,
                          // Mencegah memory leak WebGL dengan membatasi cache
                          cacheWidth: 800,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              color: Colors.black,
                              child: const Center(child: CircularProgressIndicator()),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: Colors.black,
                            child: const Icon(Icons.broken_image, color: Colors.red, size: 48),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text("${t('Prompt', 'Prompt')}:", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  Text(project.prompt, style: const TextStyle(color: Colors.white, fontSize: 14)),
                  const SizedBox(height: 12),
                  Text("${t('Style', 'Gaya')}: ${project.style}", style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  Text("${t('Ratio', 'Rasio')}: ${project.aspectRatio}", style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
            actions: [
              if (isDownloading)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.greenAccent)),
                )
              else
                TextButton.icon(
                  icon: const Icon(Icons.download_rounded, color: Colors.greenAccent),
                  label: Text(t('Download', 'Unduh'), style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    setStateDialog(() => isDownloading = true);
                    try {
                      // [PERBAIKAN] Menggunakan arsitektur Native Delegation (ala Storinema)
                      final Uri url = Uri.parse(project.imageUrl);
                      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Could not open link: ${project.imageUrl}'), backgroundColor: Colors.red),
                          );
                        }
                      }
                      // Jika sukses, tidak perlu SnackBar karena OS Android/Browser 
                      // akan memunculkan notifikasi download bawaan mereka sendiri yang lebih elegan.
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red)
                        );
                      }
                    } finally {
                      if (mounted) {
                        setStateDialog(() => isDownloading = false);
                      }
                    }
                  },
                ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(t('Close', 'Tutup'), style: const TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }
//.......................................................//

// No ke-4: BUILD METHOD UTAMA //
//.......................................................//
  @override
  Widget build(BuildContext context) {
    final projectsAsyncValue = ref.watch(historyT2ImageStreamProvider);
    final currentLocale = ref.watch(appLanguageProvider);
    final isIndo = currentLocale.languageCode == 'id';
    
    String t(String en, String id) => isIndo ? id : en;

    return Theme(
      data: AppTheme.darkTheme,
      child: Scaffold(
        appBar: AppBar(
          title: Text(t('T2Image History', 'Histori T2Image')),
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
      AsyncValue<List<ImageProjectT2Image>> asyncValue, bool isIndo) {
    
    String t(String en, String id) => isIndo ? id : en;

    return asyncValue.when(
      loading: () => const SliverToBoxAdapter(
        child: Center(child: Padding(padding: EdgeInsets.all(32.0), child: CircularProgressIndicator())),
      ),
      error: (error, stack) {
        // --- LOGIKA DETEKSI LINK INDEX FIREBASE ---
        final errorStr = error.toString();
        final hasIndexError = errorStr.contains('https://console.firebase.google.com');
        String? indexUrl;
        
        if (hasIndexError) {
          // Ekstrak URL menggunakan RegEx
          final regExp = RegExp(r'https://console\.firebase\.google\.com/[^\s]+');
          indexUrl = regExp.stringMatch(errorStr);
        }

        return SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                const Icon(Icons.analytics_outlined, color: Colors.redAccent, size: 40),
                const SizedBox(height: 16),
                Text(
                  hasIndexError 
                    ? t('Database Index Required', 'Butuh Index Database')
                    : t('System Error', 'Kesalahan Sistem'),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  hasIndexError
                    ? t('Firebase needs a composite index to show your history.', 'Firebase butuh index khusus untuk menampilkan histori Anda.')
                    : errorStr,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                if (hasIndexError && indexUrl != null) ...[
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: Text(t('BUILD INDEX NOW', 'BUAT INDEX SEKARANG')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    onPressed: () async { 
                      // Salin ke Clipboard sebagai cadangan
                      Clipboard.setData(ClipboardData(text: indexUrl!));
                      
                      // Menggunakan url_launcher yang dijamin aman di Android
                      final Uri url = Uri.parse(indexUrl!);
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url, mode: LaunchMode.externalApplication);
                      } else {
                        debugPrint('Gagal membuka link index Firebase');
                      }
                      
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(t('Link opened & copied to clipboard!', 'Link dibuka & disalin ke clipboard!')))
                        );
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
      data: (projects) {
        if (projects.isEmpty) {
          return SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  children: [
                    const Icon(Icons.image_not_supported_outlined, color: Colors.white24, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      t('No generated images yet.', 'Belum ada gambar yang dihasilkan.'),
                      style: const TextStyle(color: Colors.white38),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final project = projects[index];
              return Card(
                elevation: 2,
                color: Colors.grey[900],
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _showImageDetailDialog(context, project, isIndo),
                  child: ListTile(
                    leading: const Icon(Icons.image_search_rounded, color: Colors.blueAccent),
                    title: Text(project.prompt, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white)),
                    subtitle: Text("${project.style} • ${project.aspectRatio}", style: TextStyle(color: Colors.green.shade400, fontSize: 12)),
                    
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // --- TOMBOL DOWNLOAD LANGSUNG (NATIVE DELEGATION) ---
                        IconButton(
                          icon: const Icon(Icons.download_for_offline, color: Colors.greenAccent),
                          tooltip: t('Download', 'Unduh'),
                          onPressed: () async {
                            try {
                              final Uri url = Uri.parse(project.imageUrl);
                              if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Could not open link: ${project.imageUrl}'), backgroundColor: Colors.red),
                                  );
                                }
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                                );
                              }
                            }
                          },
                        ),
                        // --- TOMBOL HAPUS ---
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          tooltip: t('Delete', 'Hapus'),
                          onPressed: () async {
                            try {
                              await ref.read(firestoreT2ImageServiceProvider).deleteProject(project.id);
                            } catch (e) {
                              debugPrint("Delete error: $e");
                            }
                          },
                        ),
                      ],
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
} // <--- PENUTUP CLASS (PENTING)
//.......................................................//