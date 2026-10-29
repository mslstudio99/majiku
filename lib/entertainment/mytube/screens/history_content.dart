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
  final String? targetChannelId; // [MODE ADMIN]: Akses spesifik ID Channel
  final String? targetChannelName; // [MODE ADMIN]: Nama Channel untuk judul
  final String? targetCreatorEmail; // [MODE ADMIN]: Email kreator target

  const HistoryContentScreen({
    super.key,
    this.initialTabIndex = 0,
    this.targetChannelId,
    this.targetChannelName,
    this.targetCreatorEmail,
  });

  @override
  ConsumerState<HistoryContentScreen> createState() => _HistoryContentScreenState();
}

class _HistoryContentScreenState extends ConsumerState<HistoryContentScreen>
    with SingleTickerProviderStateMixin {
  final FirestoreMytubeService _service = FirestoreMytubeService();
  late final TabController _tabController;
  User? _currentUser;
  String _channelId = ''; // [JANGKAR UTAMA]: ID Channel Resmi Saluran

  // [KATEGORI KONTEN]: 17 Kategori Resmi Diurutkan A-Z (Default English & Bilingual ID)
  static const List<Map<String, String>> _categories = [
    {'en': 'Cartoons & Anime', 'id': 'Kartun & Anime'},
    {'en': 'Comedy & Funny', 'id': 'Lucu'},
    {'en': 'Education & Facts', 'id': 'Edukasi & Fakta'},
    {'en': 'Faith & Religion', 'id': 'Religi'},
    {'en': 'Finance & Investment', 'id': 'Keuangan'},
    {'en': 'Food & Culinary', 'id': 'Kuliner'},
    {'en': 'Health & Wellness', 'id': 'Kesehatan'}, // [BARU]: Kategori Kesehatan
    {'en': 'History', 'id': 'Sejarah'},
    {'en': 'Horror & Mystery', 'id': 'Horor & Misteri'},
    {'en': 'Music & Artists', 'id': 'Musik & Artis'},
    {'en': 'Myths & Legends', 'id': 'Mitos & Legenda'},
    {'en': 'Nature & Animals', 'id': 'Alam, Binatang & Tumbuhan'},
    {'en': 'News & Information', 'id': 'Berita'},
    {'en': 'Places & Travel', 'id': 'Tempat & Perjalanan'},
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
    _loadChannelIdSync();
  }

  Future<void> _loadChannelIdSync() async {
    // [MODE ADMIN OVERRIDE]: Jika targetChannelId diberikan dari Content Management, gunakan langsung
    if (widget.targetChannelId != null && widget.targetChannelId!.trim().isNotEmpty) {
      if (mounted) {
        setState(() {
          _channelId = widget.targetChannelId!.trim();
        });
      }
      return;
    }

    final email = _currentUser?.email ?? '';
    final uid = _currentUser?.uid ?? '';
    if (email.isEmpty && uid.isEmpty) return;

    try {
      final profile = await _service.getCreatorProfile(email, userId: uid);
      if (profile != null && mounted) {
        setState(() {
          _channelId = profile.channelId;
        });
      }
    } catch (_) {}
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
              ? 'Video "${video.title}" akan dihapus permanen dari channel. Tindakan ini tidak dapat dibatalkan.'
              : 'Video "${video.title}" will be permanently removed from this channel. This action cannot be undone.',
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
      // [HIBRIDA]: Utamakan video.channelId, fallback ke targetChannelId, _channelId atau email
      final creatorKey = video.channelId.trim().isNotEmpty
          ? video.channelId.trim()
          : (widget.targetChannelId?.trim().isNotEmpty == true
              ? widget.targetChannelId!.trim()
              : (_channelId.trim().isNotEmpty
                  ? _channelId.trim()
                  : (widget.targetCreatorEmail?.trim().isNotEmpty == true
                      ? widget.targetCreatorEmail!.trim().toLowerCase()
                      : (_currentUser?.email ?? _currentUser?.uid ?? ''))));

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

  // Eksekusi Simpan Edit: Creator Mengajukan Permohonan (Pending), Admin Langsung Terapkan (Sinkron 1-2 Kategori)
  Future<void> _submitEditVideo({
    required VideoMytubeModel video,
    required String newTitle,
    required List<String> newCategories, // [BARU]: Mendukung 1-2 Kategori Sekaligus
    required String newLanguage,
    required List<String> newTargetLocations,
    required bool isIndo,
    required bool isAdmin,
  }) async {
    try {
      final effectiveCategories = newCategories.isNotEmpty
          ? newCategories
          : (video.categories.isNotEmpty ? video.categories : [video.category]);
      final primaryCategory = effectiveCategories.first;

      if (isAdmin) {
        // ADMIN PUSAT: Langsung terapkan perubahan ke database tanpa antrean approval
        final isLong = video.videoType.toUpperCase() == 'LONG';
        final subCol = isLong ? FirestoreMytubeService.subColLongVideo : FirestoreMytubeService.subColShortVideo;

        // [HIBRIDA]: Prioritaskan channelId dokumen video -> targetChannelId -> _channelId -> email
        final creatorKey = video.channelId.trim().isNotEmpty
            ? video.channelId.trim()
            : (widget.targetChannelId?.trim().isNotEmpty == true
                ? widget.targetChannelId!.trim()
                : (_channelId.trim().isNotEmpty
                    ? _channelId.trim()
                    : (widget.targetCreatorEmail?.trim().isNotEmpty == true
                        ? widget.targetCreatorEmail!.trim().toLowerCase()
                        : (video.uploaderEmail.trim().isNotEmpty
                            ? video.uploaderEmail.trim().toLowerCase()
                            : video.uploaderId))));

        await FirebaseFirestore.instance
            .collection(FirestoreMytubeService.colMytube)
            .doc(creatorKey)
            .collection(subCol)
            .doc(video.id)
            .update({
          'title': newTitle,
          'category': primaryCategory, // Kategori primer
          'categories': effectiveCategories, // [SINKRONISASI FIRESTORE]: Array 1-2 kategori
          'language': newLanguage,
          'target_locations': newTargetLocations,
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
          newCategory: primaryCategory,
          newLanguage: newLanguage,
          newTargetLocations: newTargetLocations,
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

    // [DUAL LOGIKA CHANNEL & KREATOR]:
    // Jika dibuka oleh Admin (targetChannelId tersedia), pakai data channel target.
    // Jika dibuka oleh Creator pribadi, pakai data akun yang login.
    final effectiveChannelId = widget.targetChannelId?.trim().isNotEmpty == true
        ? widget.targetChannelId!.trim()
        : _channelId;

    final creatorEmail = widget.targetCreatorEmail?.trim().isNotEmpty == true
        ? widget.targetCreatorEmail!.trim().toLowerCase()
        : (_currentUser?.email ?? '');

    final creatorUid = widget.targetChannelId?.trim().isNotEmpty == true
        ? '' // Mode Admin tidak bergantung pada UID pengguna login
        : (_currentUser?.uid ?? '');

    final appBarTitle = widget.targetChannelName?.trim().isNotEmpty == true
        ? '${t('Content History', 'Riwayat Konten')} • ${widget.targetChannelName}'
        : t('Content History', 'Riwayat Konten');

    return Scaffold(
      backgroundColor: const Color(0xFF121214),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E24),
        elevation: 0,
        title: Text(
          appBarTitle,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          overflow: TextOverflow.ellipsis,
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
          // Tab 1: Shorts History (Sinkron Channel ID & Email Legacy)
          _buildVideoListStream(
            videoType: 'SHORT',
            channelId: effectiveChannelId,
            creatorEmail: creatorEmail,
            creatorUid: creatorUid,
            t: t,
            isIndo: isIndo,
            isAdmin: isAdmin,
          ),

          // Tab 2: Longs History (Sinkron Channel ID & Email Legacy)
          _buildVideoListStream(
            videoType: 'LONG',
            channelId: effectiveChannelId,
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
//VIDEO LIST VIEW BUILDER (STREAMBUILDER DUAL-COMPATIBILITY)                 //
  Widget _buildVideoListStream({
    required String videoType,
    required String channelId,
    required String creatorEmail,
    required String creatorUid,
    required String Function(String, String) t,
    required bool isIndo,
    required bool isAdmin,
  }) {
    return StreamBuilder<List<VideoMytubeModel>>(
      stream: _service.getVideosByTypeStream(
        videoType: videoType,
        channelId: channelId,
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
//VIDEO CARD COMPONENT & METRICS ROW (DILENGKAPI TOMBOL EDIT & SEMUA LOKASI) //
  Widget _buildVideoCard(VideoMytubeModel video, String Function(String, String) t, bool isIndo, bool isAdmin) {
    // Ambil daftar lokasi lengkap (default Global jika kosong)
    final locations = video.targetLocations.isNotEmpty ? video.targetLocations : const ['Global'];

    // [DUKUNGAN 1-2 KATEGORI KONTEN]: Ekstraksi kategori resmi secara aman dari categories array
    final categories = video.categories.isNotEmpty
        ? video.categories
        : (video.category.trim().isNotEmpty ? [video.category.trim()] : const ['Comedy & Funny']);

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

                // Info Video (Judul, Kategori, Bahasa, Lokasi, Status)
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

                      // Badge Kategori (1-2 Kategori Mandiri), Bahasa & SELURUH Lokasi (Ditampilkan Semua)
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          // [KOTAK KATEGORI MANDIRI]: 1 atau 2 Kategori ditampilkan semua
                          ...categories.map((cat) => _buildBadge(cat, Colors.amberAccent)),
                          _buildBadge(video.language, Colors.cyanAccent),
                          // [TAMPILKAN SEMUA LOKASI SATU PER SATU]:
                          ...locations.map((loc) {
                            final isGlob = loc.toLowerCase() == 'global';
                            return _buildBadge(
                              isGlob ? '🌐 Global' : '📍 $loc',
                              Colors.lightGreenAccent,
                            );
                          }),
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

                // Tombol 2: Edit Video (Judul, Kategori 1-2, Bahasa, Lokasi)
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
//EDIT DIALOG, LOCATION PICKER, PREVIEW DIALOG & UTILITY HELPERS             //
  // --- FORMULIR DIALOG EDIT VIDEO (JUDUL, 1-2 KATEGORI, BAHASA, LOKASI) ---
  void _showEditDialog(
    VideoMytubeModel video,
    String Function(String, String) t,
    bool isIndo,
    bool isAdmin,
  ) {
    final titleController = TextEditingController(text: video.title);
    
    // [MULTI-KATEGORI 1-2]: Ambil dari video.categories atau fallback ke video.category
    List<String> selectedCategories = List<String>.from(
      video.categories.isNotEmpty
          ? video.categories
          : (video.category.trim().isNotEmpty ? [video.category.trim()] : ['Comedy & Funny']),
    );

    String selectedLanguage = _languages.contains(video.language)
        ? video.language
        : _languages.first;

    List<String> selectedLocations = List<String>.from(
      video.targetLocations.isNotEmpty ? video.targetLocations : const ['Global'],
    );

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

                  // 2. Pemilih Kategori Video (Pilih 1 - 2 Kategori)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        t('Category (Select 1-2)', 'Kategori (Pilih 1-2)'),
                        style: const TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.bold),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amberAccent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.amberAccent.withOpacity(0.3), width: 0.8),
                        ),
                        child: Text(
                          '${selectedCategories.length}/2',
                          style: const TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 180),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF141418),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _categories.map((cat) {
                          final catKey = cat['en']!;
                          final catLabel = isIndo ? cat['id']! : cat['en']!;
                          final isSelected = selectedCategories.contains(catKey);

                          return ChoiceChip(
                            label: Text(catLabel),
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.black : Colors.white,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 11.5,
                            ),
                            selected: isSelected,
                            selectedColor: Colors.amberAccent,
                            backgroundColor: const Color(0xFF22222A),
                            side: BorderSide(
                              color: isSelected ? Colors.amberAccent : Colors.white24,
                              width: 0.8,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            onSelected: (selected) {
                              setDialogState(() {
                                if (selected) {
                                  if (selectedCategories.length < 2) {
                                    selectedCategories.add(catKey);
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          isIndo
                                              ? 'Maksimal memilih 2 kategori.'
                                              : 'Maximum 2 categories.',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                } else {
                                  if (selectedCategories.length > 1) {
                                    selectedCategories.remove(catKey);
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          isIndo
                                              ? 'Minimal harus memilih 1 kategori.'
                                              : 'At least 1 category must be selected.',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 3. Dropdown Bahasa Video (37 Bahasa Resmi)
                  Text(
                    t('Language', 'Bahasa'),
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
                  const SizedBox(height: 16),

                  // 4. Pemilih Target Lokasi (Mendukung Multi-Lokasi Sekaligus)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        t('Target Locations', 'Target Lokasi'),
                        style: const TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.bold),
                      ),
                      GestureDetector(
                        onTap: () {
                          setDialogState(() {
                            if (!selectedLocations.contains('Global')) {
                              selectedLocations.insert(0, 'Global');
                            }
                          });
                        },
                        child: Text(
                          t('+ Add Global', '+ Tambah Global'),
                          style: const TextStyle(color: Colors.lightGreenAccent, fontSize: 11.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () async {
                      final updated = await _showLocationPickerDialog(
                        context: context,
                        initialLocations: selectedLocations,
                        isIndo: isIndo,
                      );
                      if (updated != null) {
                        setDialogState(() {
                          selectedLocations = updated.isEmpty ? ['Global'] : updated;
                        });
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                      decoration: BoxDecoration(
                        color: const Color(0xFF141418),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.public_rounded, color: Colors.lightGreenAccent, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              selectedLocations.join(', '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.arrow_drop_down, color: Colors.white54),
                        ],
                      ),
                    ),
                  ),

                  // Chip Visual Seluruh Lokasi Terpilih (Bisa Dihapus per Chip)
                  if (selectedLocations.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: selectedLocations.map((loc) {
                        final isGlob = loc.toLowerCase() == 'global';
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.lightGreenAccent.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.lightGreenAccent.withOpacity(0.3), width: 0.8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                isGlob ? '🌐 $loc' : '📍 $loc',
                                style: const TextStyle(color: Colors.lightGreenAccent, fontSize: 10.5, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: () {
                                  setDialogState(() {
                                    if (selectedLocations.length > 1) {
                                      selectedLocations.remove(loc);
                                    } else {
                                      // Minimal menyisakan 1 target lokasi (Global)
                                      selectedLocations = ['Global'];
                                    }
                                  });
                                },
                                child: const Icon(Icons.close_rounded, size: 12, color: Colors.lightGreenAccent),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
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

                        // Cek apakah ada perubahan nyata (termasuk lokasi & kategori ganda)
                        final isLocationUnchanged = setEquals(
                          selectedLocations.toSet(),
                          video.targetLocations.toSet(),
                        );

                        final isCategoriesUnchanged = setEquals(
                          selectedCategories.toSet(),
                          (video.categories.isNotEmpty ? video.categories : [video.category]).toSet(),
                        );

                        if (newTitle == video.title &&
                            isCategoriesUnchanged &&
                            selectedLanguage == video.language &&
                            isLocationUnchanged) {
                          Navigator.of(ctx).pop();
                          return;
                        }

                        setDialogState(() => isSubmitting = true);

                        await _submitEditVideo(
                          video: video,
                          newTitle: newTitle,
                          newCategories: selectedCategories,
                          newLanguage: selectedLanguage,
                          newTargetLocations: selectedLocations,
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

  // --- DIALOG PEMILIH MULTI-LOKASI TARGET (GLOBAL & NEGARA BEBAS BERSAMAAN) ---
  Future<List<String>?> _showLocationPickerDialog({
    required BuildContext context,
    required List<String> initialLocations,
    required bool isIndo,
  }) async {
    final searchController = TextEditingController();
    List<String> tempSelected = List<String>.from(initialLocations);
    final allCountries = MytubeLocationDatabase.allCountries;

    return showDialog<List<String>>(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (context, setDlgState) {
          final query = searchController.text.trim().toLowerCase();
          final filteredCountries = query.isEmpty
              ? allCountries
              : allCountries.where((c) => c.toLowerCase().contains(query)).toList();

          final isGlobal = tempSelected.contains('Global');

          return AlertDialog(
            backgroundColor: const Color(0xFF1E1E24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.public_rounded, color: Colors.lightGreenAccent, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isIndo ? 'Pilih Target Lokasi' : 'Select Target Location',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: Column(
                children: [
                  // Kolom Pencarian Cepat
                  TextField(
                    controller: searchController,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: isIndo ? 'Cari negara...' : 'Search country...',
                      hintStyle: const TextStyle(color: Colors.white38, fontSize: 12.5),
                      prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 18),
                      filled: true,
                      fillColor: const Color(0xFF141418),
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    ),
                    onChanged: (_) => setDlgState(() {}),
                  ),
                  const SizedBox(height: 10),

                  // Opsi Centang 'Global' (Bisa Dipilih Bersamaan dengan Negara Lain)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Checkbox(
                      value: isGlobal,
                      activeColor: Colors.lightGreenAccent,
                      checkColor: Colors.black,
                      onChanged: (val) {
                        setDlgState(() {
                          if (val == true) {
                            if (!tempSelected.contains('Global')) tempSelected.insert(0, 'Global');
                          } else {
                            tempSelected.remove('Global');
                            if (tempSelected.isEmpty) tempSelected = ['Global'];
                          }
                        });
                      },
                    ),
                    title: Text(
                      isIndo ? '🌐 Global (Audiens Seluruh Dunia)' : '🌐 Global (Worldwide Audience)',
                      style: TextStyle(
                        color: isGlobal ? Colors.lightGreenAccent : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const Divider(color: Colors.white12, height: 1),

                  // Daftar 100 Negara (Bisa Dicentang Bersamaan)
                  Expanded(
                    child: ListView.builder(
                      itemCount: filteredCountries.length,
                      itemBuilder: (context, idx) {
                        final country = filteredCountries[idx];
                        final isChecked = tempSelected.contains(country);

                        return CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text('📍 $country', style: const TextStyle(color: Colors.white, fontSize: 13)),
                          value: isChecked,
                          activeColor: Colors.lightGreenAccent,
                          checkColor: Colors.black,
                          onChanged: (bool? val) {
                            setDlgState(() {
                              if (val == true) {
                                tempSelected.add(country);
                              } else {
                                tempSelected.remove(country);
                              }
                              // Jika kosong semua, otomatis set ke Global
                              if (tempSelected.isEmpty) {
                                tempSelected = ['Global'];
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dlgCtx).pop(null),
                child: Text(isIndo ? 'Batal' : 'Cancel', style: const TextStyle(color: Colors.white54)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.lightGreenAccent,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => Navigator.of(dlgCtx).pop(tempSelected),
                child: Text(isIndo ? 'Terapkan' : 'Apply', style: const TextStyle(fontWeight: FontWeight.bold)),
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