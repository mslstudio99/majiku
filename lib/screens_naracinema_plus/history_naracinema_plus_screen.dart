//================================================================//
// NAMA FILE: HISTORY_NARACINEMA_PLUS_SCREEN.DART                 //
// DIREKTORI: LIB/SCREENS_NARACINEMA_PLUS/                        //
// DESKRIPSI: LAYAR HISTORI PROYEK NARACINEMA PLUS                //
//================================================================//

// No ke-1: IMPOR DEPENDENSI & LAYAR TERKAIT                      //
//----------------------------------------------------------------//
// Mengimpor library flutter, riverpod, service, dan screen terkait
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services_naracinema_plus/firestore_naracinema_plus_service.dart';
import '../models_naracinema_plus/video_project_naracinema_plus.dart';
import '../theme/app_theme.dart';

import 'project_loading_naracinema_plus_screen.dart';
import 'timeline_review_naracinema_plus_screen.dart';
//----------------------------------------------------------------//

// No ke-2: STATEFUL WIDGET & INISIALISASI SERVICE                //
//----------------------------------------------------------------//
// Mengelola state dan navigasi untuk Histori Naracinema Plus
class HistoryNaracinemaPlusScreen extends ConsumerStatefulWidget {
  const HistoryNaracinemaPlusScreen({super.key});

  @override
  ConsumerState<HistoryNaracinemaPlusScreen> createState() => _HistoryNaracinemaPlusScreenState();
}

class _HistoryNaracinemaPlusScreenState extends ConsumerState<HistoryNaracinemaPlusScreen> {
  final FirestoreNaracinemaPlusService _firestoreService = FirestoreNaracinemaPlusService();

  void _navigateToProjectDetail(VideoProjectNaracinemaPlus project) {
    if (project.id.isEmpty) return;

    // Perbaikan: Null coalescing untuk menghindari TypeError String? ke String
    final String status = project.status ?? 'PENDING';
    
    if (status == 'ASSETS_COMPLETE' || status == 'RENDER_READY' || status == 'RENDER_COMPLETED') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TimelineReviewNaracinemaPlusScreen(projectId: project.id),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProjectLoadingNaracinemaPlusScreen(projectId: project.id),
        ),
      );
    }
  }

  Future<void> _confirmDelete(BuildContext context, String projectId, String title) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Hapus Proyek?', style: TextStyle(color: Colors.white)),
        content: Text('Anda yakin ingin menghapus "$title"?',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await _firestoreService.deleteProject(projectId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Proyek berhasil dihapus.'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal menghapus: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }
//----------------------------------------------------------------//

// No ke-3: BUILD METHOD & UI UTAMA (STREAM BUILDER)              //
//----------------------------------------------------------------//
// Merender layout utama dan mendengarkan stream project user
  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.darkTheme,
      child: Scaffold(
        backgroundColor: const Color(0xFF121212),
        appBar: AppBar(
          title: const Text('Histori Naracinema Plus', style: TextStyle(fontSize: 18)),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: StreamBuilder<List<VideoProjectNaracinemaPlus>>(
          stream: _firestoreService.getProjectsForUser(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Colors.cyan));
            }
            if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text('Belum ada histori proyek.', style: TextStyle(color: Colors.white54)));
            }

            final projects = snapshot.data!;
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: projects.length,
              itemBuilder: (context, index) => _buildProjectCard(projects[index]),
            );
          },
        ),
      ),
    );
  }
//----------------------------------------------------------------//

// No ke-4: KOMPONEN UI CARD HISTORI                              //
//----------------------------------------------------------------//
// Merender satuan card project list beserta formatting UI-nya
  Widget _buildProjectCard(VideoProjectNaracinemaPlus project) {
    // Perbaikan: Konversi objek Timestamp Firestore ke DateTime agar terbaca .day, .month dll
    final DateTime date = project.createdAt.toDate();
    
    final dateString = "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";

    Color statusColor = Colors.grey;
    
    // Perbaikan: Menggunakan ?. dan ?? false untuk pengkondisian String? yang aman (Null-Safe)
    if (project.status?.contains('ERROR') ?? false) {
      statusColor = Colors.redAccent;
    } else if (project.status == 'ASSETS_COMPLETE' || project.status == 'RENDER_READY') {
      statusColor = Colors.amberAccent;
    } else if (project.status == 'RENDER_COMPLETED') {
      statusColor = Colors.greenAccent;
    }

    return Card(
      color: Colors.grey[900]?.withOpacity(0.5),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Colors.white12),
      ),
      child: InkWell(
        onTap: () => _navigateToProjectDetail(project),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: statusColor.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(Icons.movie_creation_outlined, color: statusColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(project.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('Status: ${project.status ?? 'UNKNOWN'}', style: TextStyle(color: statusColor, fontSize: 12)),
                    Text('Dibuat: $dateString', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.white38),
                onPressed: () => _confirmDelete(context, project.id, project.title),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
//----------------------------------------------------------------//