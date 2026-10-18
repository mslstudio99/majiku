//============================================================================//
// DIREKTORI: LIB/ENTERTAINMENT/MYTUBE/SCREENS/                               //
// FILE: HISTORY_CONTENT.DART                                                //
// LAYAR RIWAYAT KONTEN MYTUBE (SHORTS, LONGS, STATISTIK, PREVIEW & EDIT)    //
//============================================================================//

//No ke-1....................................................................//
//IMPORTS & DEPENDENCIES                                                     //
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:video_player/video_player.dart';

import '../../../providers/config_provider.dart';
import '../../../providers/user_provider.dart';
import '../models/video_mytube_model.dart';
import '../services/firestore_mytube_service.dart';
import 'short_upload_content.dart';
import 'long_upload_content.dart';
//............................................................................//

//No ke-2....................................................................//
//WIDGET DECLARATION & STATE SETUP                                           //
class HistoryContentScreen extends ConsumerStatefulWidget {
  final int initialTabIndex; // 0 untuk Shorts, 1 untuk Longs

  const HistoryContentScreen({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  ConsumerState<HistoryContentScreen> createState() => _HistoryContentScreenState();
}

class _HistoryContentScreenState extends ConsumerState<HistoryContentScreen>
    with SingleTickerProviderStateMixin {
  final FirestoreMytubeService _service = FirestoreMytubeService();
  late final TabController _tabController;
  User? _currentUser;

  // Daftar 15 Kategori Resmi Terurut A-Z (Default English)
  static const List<Map<String, String>> _categories = [
    {'en': 'Cartoons & Anime', 'id': 'Kartun & Anime'},
    {'en': 'Comedy & Funny', 'id': 'Lucu'},
    {'en': 'Education & Facts', 'id': 'Edukasi & Fakta'},
    {'en': 'Faith & Religion', 'id': 'Religi'},
    {'en': 'Finance & Investment', 'id': 'Keuangan'},
    {'en': 'Food & Culinary', 'id': 'Kuliner'},
    {'en': 'History', 'id': 'Sejarah'},
    {'en': 'Horror & Mystery', 'id': 'Horor & Misteri'},
    {'en': 'Music & Artists', 'id': 'Musik & Artis'},
    {'en': 'Myths & Legends', 'id': 'Mitos & Legenda'},
    {'en': 'Nature & Animals', 'id': 'Alam, Binatang & Tumbuhan'},
    {'en': 'News & Information', 'id': 'Berita'},
    {'en': 'Popular Figures', 'id': 'Tokoh Populer'},
    {'en': 'Sports & Fitness', 'id': 'Olahraga'},
    {'en': 'Technology & Gadgets', 'id': 'Teknologi'},
  ];

  // Daftar 37 Bahasa & Negara Resmi (#1 English US, #2 Indonesian)
  static const List<String> _languages = [
    'English (US)',
    'Indonesian',
    'Hindi',
    'English (UK)',
    'English (Australia)',
    'English (India)',
    'Arabic',
    'Bengali (India)',
    'Danish',
    'Dutch (Netherlands)',
    'Dutch (Belgium)',
    'Finnish',
    'French (France)',
    'French (Canada)',
    'German',
    'Gujarati',
    'Italian',
    'Japanese',
    'Kannada',
    'Korean',
    'Malayalam',
    'Mandarin Chinese',
    'Marathi',
    'Norwegian',
    'Polish',
    'Portuguese (Brazil)',
    'Russian',
    'Spanish (Spain)',
    'Spanish (US)',
    'Swedish',
    'Tamil',
    'Telugu',
    'Thai',
    'Turkish',
    'Ukrainian',
    'Urdu',
    'Vietnamese',
  ];
//............................................................................//

//No ke-3....................................................................//
//LIFECYCLE, DELETE & EDIT ACTION HANDLERS                                   //
  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 1),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _deleteVideo(VideoMytubeModel video, bool isIndo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.delete_forever_rounded, color: Colors.redAccent, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isIndo ? 'Hapus Video Ini?' : 'Delete This Video?',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          isIndo
              ? 'Video "${video.title}" akan dihapus permanen dari channel Anda. Tindakan ini tidak dapat dibatalkan.'
              : 'Video "${video.title}" will be permanently removed from your channel. This action cannot be undone.',
          style: const TextStyle(color: Colors.white70, fontSize: 13.5, height: 1.4),
        ),
        actions: [
          TextButton(
            child: Text(isIndo ? 'Batal' : 'Cancel', style: const TextStyle(color: Colors.white54, fontSize: 14)),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: Text(isIndo ? 'Ya, Hapus' : 'Yes, Delete', style: const TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final creatorKey = _currentUser?.email ?? _currentUser?.uid ?? '';
      await _service.deleteVideoPost(
        videoId: video.id,
        creatorKey: creatorKey,
        videoType: video.videoType,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isIndo ? 'Video berhasil dihapus.' : 'Video successfully deleted.',
              style: const TextStyle(fontSize: 14),
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  // Eksekusi Simpan Edit: Creator Mengajukan Permohonan (Pending), Admin Langsung Terapkan
  Future<void> _submitEditVideo({
    required VideoMytubeModel video,
    required String newTitle,
    required String newCategory,
    required String newLanguage,
    required bool isIndo,
    required bool isAdmin,
  }) async {
    try {
      if (isAdmin) {
        // ADMIN PUSAT: Langsung terapkan perubahan ke database tanpa antrean approval
        final isLong = video.videoType.toUpperCase() == 'LONG';
        final subCol = isLong ? FirestoreMytubeService.subColLongVideo : FirestoreMytubeService.subColShortVideo;
        final creatorKey = video.uploaderEmail.trim().toLowerCase().isNotEmpty
            ? video.uploaderEmail.trim().toLowerCase()
            : video.uploaderId;

        await FirebaseFirestore.instance
            .collection(FirestoreMytubeService.colMytube)
            .doc(creatorKey)
            .collection(subCol)
            .doc(video.id)
            .update({
          'title': newTitle,
          'category': newCategory,
          'language': newLanguage,
          'updated_at': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isIndo ? 'Perubahan video berhasil disimpan langsung.' : 'Video changes saved successfully.',
                style: const TextStyle(fontSize: 14),
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // CREATOR: Kirimkan permohonan resmi ke koleksi mytube_requests (Status PENDING)
        await _service.submitEditRequest(
          currentVideo: video,
          newTitle: newTitle,
          newCategory: newCategory,
          newLanguage: newLanguage,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isIndo
                    ? 'Permohonan edit terkirim! Menunggu persetujuan Admin Pusat.'
                    : 'Edit request submitted! Waiting for Admin review.',
                style: const TextStyle(fontSize: 14),
              ),
              backgroundColor: Colors.blueAccent,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isIndo ? 'Gagal menyimpan perubahan: $e' : 'Failed to save changes: $e',
              style: const TextStyle(fontSize: 14),
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }
//............................................................................//

//No ke-4....................................................................//
//MAIN BUILD, APPBAR & TABBAR HEADER                                         //
  @override
  Widget build(BuildContext context) {
    final currentLocale = ref.watch(appLanguageProvider);
    final isIndo = currentLocale.languageCode == 'id';
    String t(String en, String id) => isIndo ? id : en;

    // [STANDAR RESMI APPUSER]: Pengecekan hak akses admin melalui userTier
    final userAsync = ref.watch(firestoreUserProvider);
    final userTier = userAsync.value?.userTier.toLowerCase() ?? '';
    final isAdmin = userTier == 'admin';

    final creatorEmail = _currentUser?.email ?? '';
    final creatorUid = _currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFF121214),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E24),
        elevation: 0,
        title: Text(
          t('Content History', 'Riwayat Konten'),
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amberAccent,
          indicatorWeight: 3,
          labelColor: Colors.amberAccent,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
          tabs: [
            Tab(
              icon: const Icon(Icons.bolt, size: 20),
              text: t('Shorts (9:16)', 'Shorts (9:16)'),
            ),
            Tab(
              icon: const Icon(Icons.tv_rounded, size: 20),
              text: t('Long Videos (16:9)', 'Video Panjang (16:9)'),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Shorts History
          _buildVideoListStream(
            videoType: 'SHORT',
            creatorEmail: creatorEmail,
            creatorUid: creatorUid,
            t: t,
            isIndo: isIndo,
            isAdmin: isAdmin,
          ),

          // Tab 2: Longs History
          _buildVideoListStream(
            videoType: 'LONG',
            creatorEmail: creatorEmail,
            creatorUid: creatorUid,
            t: t,
            isIndo: isIndo,
            isAdmin: isAdmin,
          ),
        ],
      ),
    );
  }
//............................................................................//

//No ke-5....................................................................//
//VIDEO LIST VIEW BUILDER (STREAMBUILDER)                                    //
  Widget _buildVideoListStream({
    required String videoType,
    required String creatorEmail,
    required String creatorUid,
    required String Function(String, String) t,
    required bool isIndo,
    required bool isAdmin,
  }) {
    return StreamBuilder<List<VideoMytubeModel>>(
      stream: _service.getVideosByTypeStream(
        videoType: videoType,
        uploaderEmail: creatorEmail,
        uploaderId: creatorUid,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.amberAccent));
        }

        final videos = snapshot.data ?? [];

        if (videos.isEmpty) {
          return _buildEmptyState(videoType, t, isIndo);
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: videos.length,
          separatorBuilder: (_, __) => const SizedBox(height: 14),
          itemBuilder: (context, index) {
            final video = videos[index];
            return _buildVideoCard(video, t, isIndo, isAdmin);
          },
        );
      },
    );
  }

  Widget _buildEmptyState(String videoType, String Function(String, String) t, bool isIndo) {
    final isShort = videoType == 'SHORT';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isShort ? Icons.bolt : Icons.tv_rounded,
              color: Colors.white24,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              isShort
                  ? t('No Short Videos Yet', 'Belum Ada Video Short')
                  : t('No Long Videos Yet', 'Belum Ada Video Panjang'),
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              isShort
                  ? t(
                      'Published shorts will be displayed here along with live views and engagement stats.',
                      'Video short yang sudah diterbitkan akan muncul di sini beserta statistik penayangan langsung.',
                    )
                  : t(
                      'Published landscape videos will appear here with complete playback metrics.',
                      'Video lanskap yang sudah diterbitkan akan muncul di sini lengkap dengan metrik pemutaran.',
                    ),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 22),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: isShort ? Colors.amberAccent : Colors.orangeAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.add_rounded, size: 20),
              label: Text(
                isShort
                    ? t('Create First Short', 'Buat Short Pertama')
                    : t('Create First Long Video', 'Buat Video Panjang Pertama'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => isShort
                        ? const ShortUploadContentScreen()
                        : const LongUploadContentScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
//............................................................................//

//No ke-6....................................................................//
//VIDEO CARD COMPONENT & METRICS ROW (DILENGKAPI TOMBOL EDIT)                //
  Widget _buildVideoCard(VideoMytubeModel video, String Function(String, String) t, bool isIndo, bool isAdmin) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E24),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Baris Atas: Thumbnail, Info Utama & Tombol Preview
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail dengan Durasi
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: video.isLandscape ? 110 : 75,
                        height: video.isLandscape ? 62 : 110,
                        color: Colors.black38,
                        child: video.thumbnailUrl.isNotEmpty
                            ? Image.network(video.thumbnailUrl, fit: BoxFit.cover)
                            : const Icon(Icons.video_library, color: Colors.white24, size: 30),
                      ),
                    ),
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _formatDuration(video.durationSeconds),
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),

                // Info Video (Judul, Kategori, Bahasa, Status)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        video.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14.5,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Badge Kategori & Bahasa
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _buildBadge(video.category, Colors.amberAccent),
                          _buildBadge(video.language, Colors.cyanAccent),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Badge Status Transcoding
                      _buildStatusIndicator(video.hlsUrl != null && video.hlsUrl!.isNotEmpty, t),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white10, height: 1),

          // Baris Bawah: Barisan 5 Metrik Lengkap & 3 Tombol Aksi (Preview, Edit, Hapus)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                // 1. Views
                _buildMetricIcon(Icons.remove_red_eye_rounded, video.viewsCount, Colors.white70),
                const SizedBox(width: 14),

                // 2. Likes
                _buildMetricIcon(Icons.favorite, video.likesCount, Colors.redAccent),
                const SizedBox(width: 14),

                // 3. Comments
                _buildMetricIcon(Icons.chat_bubble_rounded, video.commentsCount, Colors.white70),
                const SizedBox(width: 14),

                // 4. Saves
                _buildMetricIcon(Icons.bookmark_rounded, video.savesCount, Colors.amberAccent),
                const SizedBox(width: 14),

                // 5. Shares
                _buildMetricIcon(Icons.share_rounded, video.sharesCount, Colors.white70),
                const Spacer(),

                // Tombol 1: Preview Video
                IconButton(
                  icon: const Icon(Icons.play_circle_fill_rounded, color: Colors.blueAccent, size: 26),
                  tooltip: t('Preview Video', 'Pratinjau Video'),
                  onPressed: () => _showPreviewDialog(video),
                ),

                // Tombol 2: Edit Video (Judul, Kategori, Bahasa)
                IconButton(
                  icon: const Icon(Icons.edit_note_rounded, color: Colors.orangeAccent, size: 26),
                  tooltip: t('Edit Video Info', 'Edit Info Video'),
                  onPressed: () => _showEditDialog(video, t, isIndo, isAdmin),
                ),

                // Tombol 3: Hapus Video
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 22),
                  tooltip: t('Delete Video', 'Hapus Video'),
                  onPressed: () => _deleteVideo(video, isIndo),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3), width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildStatusIndicator(bool isReady, String Function(String, String) t) {
    final color = isReady ? Colors.green : Colors.orangeAccent;
    final text = isReady ? t('READY', 'SIAP TAYANG') : t('TRANSCODING', 'DIPROSES');

    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildMetricIcon(IconData icon, int count, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 4),
        Text(
          _formatCompact(count),
          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
//............................................................................//

//No ke-7....................................................................//
//EDIT DIALOG, PREVIEW DIALOG & UTILITY HELPERS                               //
  // --- FORMULIR DIALOG EDIT VIDEO (JUDUL, KATEGORI, BAHASA) ---
  void _showEditDialog(
    VideoMytubeModel video,
    String Function(String, String) t,
    bool isIndo,
    bool isAdmin,
  ) {
    final titleController = TextEditingController(text: video.title);
    
    // Validasi nilai awal agar ada dalam daftar master
    String selectedCategory = _categories.any((c) => c['en'] == video.category)
        ? video.category
        : _categories.first['en']!;

    String selectedLanguage = _languages.contains(video.language)
        ? video.language
        : _languages.first;

    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E1E24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.edit_note_rounded, color: Colors.orangeAccent, size: 28),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    t('Edit Video Info', 'Edit Info Video'),
                    style: const TextStyle(color: Colors.white, fontSize: 16.5, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Banner Notifikasi Alur Persetujuan
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isAdmin ? Colors.green.withOpacity(0.15) : Colors.amber.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isAdmin ? Colors.greenAccent.withOpacity(0.4) : Colors.amberAccent.withOpacity(0.4),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          isAdmin ? Icons.admin_panel_settings_rounded : Icons.info_outline_rounded,
                          color: isAdmin ? Colors.greenAccent : Colors.amberAccent,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isAdmin
                                ? t('Direct Mode: Changes will be applied immediately.', 'Mode Admin: Perubahan akan langsung disimpan.')
                                : t('Creator Mode: Changes require Admin approval before live.', 'Mode Kreator: Perubahan membutuhkan persetujuan Admin Pusat.'),
                            style: TextStyle(
                              color: isAdmin ? Colors.greenAccent : Colors.amberAccent,
                              fontSize: 11.5,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 1. Input Judul Video
                  Text(
                    t('Video Title', 'Judul Video'),
                    style: const TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: titleController,
                    maxLines: 2,
                    maxLength: 120,
                    style: const TextStyle(color: Colors.white, fontSize: 13.5),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF141418),
                      counterStyle: const TextStyle(color: Colors.white30, fontSize: 11),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.white24),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.orangeAccent),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 2. Dropdown Kategori Video (15 Kategori)
                  Text(
                    t('Category', 'Kategori'),
                    style: const TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    dropdownColor: const Color(0xFF1E1E24),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF141418),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.white24),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: _categories.map((cat) {
                      final label = isIndo ? cat['id']! : cat['en']!;
                      return DropdownMenuItem<String>(
                        value: cat['en']!,
                        child: Text(label),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedCategory = val);
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // 3. Dropdown Bahasa Video (37 Bahasa)
                  Text(
                    t('Language & Region', 'Bahasa & Negara'),
                    style: const TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedLanguage,
                    dropdownColor: const Color(0xFF1E1E24),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF141418),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.white24),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: _languages.map((lang) {
                      return DropdownMenuItem<String>(
                        value: lang,
                        child: Text(lang),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedLanguage = val);
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.of(ctx).pop(),
                child: Text(t('Cancel', 'Batal'), style: const TextStyle(color: Colors.white54)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orangeAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final newTitle = titleController.text.trim();
                        if (newTitle.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(t('Title cannot be empty.', 'Judul tidak boleh kosong.')),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                          return;
                        }

                        // Cek apakah ada perubahan nyata
                        if (newTitle == video.title &&
                            selectedCategory == video.category &&
                            selectedLanguage == video.language) {
                          Navigator.of(ctx).pop();
                          return;
                        }

                        setDialogState(() => isSubmitting = true);

                        await _submitEditVideo(
                          video: video,
                          newTitle: newTitle,
                          newCategory: selectedCategory,
                          newLanguage: selectedLanguage,
                          isIndo: isIndo,
                          isAdmin: isAdmin,
                        );

                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop();
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      )
                    : Text(
                        isAdmin ? t('Save Now', 'Simpan Langsung') : t('Submit Request', 'Ajukan Permohonan'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  // --- DIALOG PREVIEW VIDEO & UTILITY FORMATTERS ---
  void _showPreviewDialog(VideoMytubeModel video) {
    showDialog(
      context: context,
      builder: (ctx) => _VideoPreviewDialog(video: video),
    );
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _formatCompact(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return '$count';
  }
}

// Widget Dialog Pemutar Preview Video Interaktif (Dual-Engine Adaptif Web & HP)
class _VideoPreviewDialog extends StatefulWidget {
  final VideoMytubeModel video;
  const _VideoPreviewDialog({required this.video});

  @override
  State<_VideoPreviewDialog> createState() => _VideoPreviewDialogState();
}

class _VideoPreviewDialogState extends State<_VideoPreviewDialog> {
  VideoPlayerController? _controller;
  bool _isInit = false;
  bool _hasError = false;
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    final chosenUrl = kIsWeb
        ? (widget.video.videoUrl.isNotEmpty ? widget.video.videoUrl : widget.video.streamingUrl)
        : (widget.video.streamingUrl.isNotEmpty ? widget.video.streamingUrl : widget.video.videoUrl);

    if (chosenUrl.isEmpty) {
      if (mounted) setState(() => _hasError = true);
      return;
    }

    try {
      _controller = VideoPlayerController.networkUrl(Uri.parse(chosenUrl));
      await _controller!.initialize();

      if (!mounted) return;

      _controller!.setLooping(true);

      try {
        await _controller!.setVolume(1.0);
        await _controller!.play();
      } catch (_) {
        if (kIsWeb) {
          _isMuted = true;
          await _controller!.setVolume(0.0);
          await _controller!.play();
        }
      }

      if (mounted) {
        setState(() {
          _isInit = true;
          _hasError = false;
        });
      }
    } catch (e) {
      debugPrint('[MYTUBE PREVIEW ERROR]: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _isInit = false;
        });
      }
    }
  }

  void _toggleMute() {
    if (_controller == null || !_isInit) return;
    setState(() {
      _isMuted = !_isMuted;
      _controller!.setVolume(_isMuted ? 0.0 : 1.0);
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Dialog
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF1E1E24),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.video.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14.5),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70, size: 22),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          // Video Canvas
          Container(
            color: Colors.black,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.65,
            ),
            child: _hasError
                ? Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 40),
                        const SizedBox(height: 10),
                        const Text(
                          'Gagal memuat video preview.',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white12,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('Coba Lagi', style: TextStyle(fontSize: 12)),
                          onPressed: () {
                            setState(() {
                              _hasError = false;
                              _isInit = false;
                            });
                            _initPlayer();
                          },
                        ),
                      ],
                    ),
                  )
                : (_controller != null && _isInit)
                    ? Stack(
                        alignment: Alignment.center,
                        children: [
                          AspectRatio(
                            aspectRatio: _controller!.value.aspectRatio,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _controller!.value.isPlaying ? _controller!.pause() : _controller!.play();
                                });
                              },
                              child: VideoPlayer(_controller!),
                            ),
                          ),

                          // Tombol Pause Overlay saat video dijeda
                          if (!_controller!.value.isPlaying)
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _controller!.play();
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.6),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 36),
                              ),
                            ),

                          // Tombol Mute / Unmute Pojok Kanan Atas
                          Positioned(
                            top: 10,
                            right: 10,
                            child: GestureDetector(
                              onTap: _toggleMute,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.65),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : const Padding(
                        padding: EdgeInsets.all(48),
                        child: Center(
                          child: CircularProgressIndicator(color: Colors.amberAccent),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
//............................................................................//