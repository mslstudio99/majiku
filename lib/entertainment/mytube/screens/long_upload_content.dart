//============================================================================//
// DIREKTORI: lib/entertainment/mytube/screens/                              //
// FILE: LONG_UPLOAD_CONTENT.DART                                            //
// LAYAR UPLOAD LONG VIDEO MYTUBE (FILTER 16:9, 10 KATEGORI A-Z, 37 BAHASA)  //
//============================================================================//

//No ke-1....................................................................//
//IMPORTS & UPPERCASE FORMATTER                                              //
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../../../providers/config_provider.dart';
import '../services/firestore_mytube_service.dart';
import '../view_model/mytube_admin_view_model.dart';

// Formatter otomatis mengubah semua teks menjadi HURUF KAPITAL
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
//............................................................................//

//No ke-2....................................................................//
//WIDGET DECLARATION & STATE SETUP                                           //
class LongUploadContentScreen extends ConsumerStatefulWidget {
  const LongUploadContentScreen({super.key});

  @override
  ConsumerState<LongUploadContentScreen> createState() => _LongUploadContentScreenState();
}

class _LongUploadContentScreenState extends ConsumerState<LongUploadContentScreen> {
  late final MytubeAdminViewModel _viewModel;
  final FirestoreMytubeService _service = FirestoreMytubeService();
  final ImagePicker _picker = ImagePicker();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _actionTextController = TextEditingController();
  final TextEditingController _actionRouteController = TextEditingController();

  User? _currentUser;
  String _channelName = 'Majiku Official';
  String _channelAvatarUrl = '';

  // Kategori & Bahasa Default
  String _selectedCategory = 'Comedy & Funny';
  String _selectedLanguage = 'English (US)';

  // [KATEGORI KONTEN]: 16 Kategori Resmi Diurutkan Berdasarkan Abjad A-Z (Default English)
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
    {'en': 'Places & Travel', 'id': 'Tempat & Perjalanan'},
    {'en': 'Popular Figures', 'id': 'Tokoh Populer'},
    {'en': 'Sports & Fitness', 'id': 'Olahraga'},
    {'en': 'Technology & Gadgets', 'id': 'Teknologi'},
  ];

  // [BAHASA KONTEN]: 37 Bahasa Resmi Disinkronkan (#1 English US, #2 Indonesian)
  static const List<String> _languages = [
    'English (US)',
    'Indonesian',
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
    'Hindi',
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
//LIFECYCLE & CREATOR PROFILE SYNC                                           //
  @override
  void initState() {
    super.initState();
    _viewModel = MytubeAdminViewModel();
    _currentUser = FirebaseAuth.instance.currentUser;
    _channelName = _currentUser?.displayName ?? 'Majiku Official';
    _channelAvatarUrl = _currentUser?.photoURL ?? '';

    if (_currentUser != null) {
      _viewModel.verifyAdminAccess(_currentUser!.uid);
      _loadCreatorProfileSync(_currentUser!.email ?? '', _currentUser!.uid);
    }
  }

  Future<void> _loadCreatorProfileSync(String email, String uid) async {
    final profile = await _service.getCreatorProfile(email, userId: uid);
    if (profile != null && mounted) {
      setState(() {
        if (profile.channelName.isNotEmpty) {
          _channelName = profile.channelName;
        }
        if (profile.avatarUrl.isNotEmpty) {
          _channelAvatarUrl = profile.avatarUrl;
        }
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _actionTextController.dispose();
    _actionRouteController.dispose();
    _viewModel.dispose();
    super.dispose();
  }
//............................................................................//

//No ke-4....................................................................//
//MEDIA PICKERS WITH 16:9 RATIO & 30-MINUTE FILTER                           //
  Future<void> _pickVideo(bool isIndo) async {
    try {
      final picked = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 30),
      );

      if (picked == null) return;

      // 1. Ekstraksi otomatis nama file video menjadi judul kapital
      String rawName = picked.name;
      if (rawName.contains('.')) {
        rawName = rawName.substring(0, rawName.lastIndexOf('.'));
      }
      rawName = rawName.replaceAll(RegExp(r'[_-]+'), ' ').trim().toUpperCase();
      if (rawName.length > 50) {
        rawName = rawName.substring(0, 50);
      }
      if (rawName.isNotEmpty) {
        _titleController.text = rawName;
      }

      // 2. Mengukur Durasi & Rasio Aspek Video (Web vs Mobile)
      final VideoPlayerController testController;
      if (kIsWeb) {
        testController = VideoPlayerController.networkUrl(Uri.parse(picked.path));
      } else {
        testController = VideoPlayerController.file(File(picked.path));
      }

      int durationSeconds = 0;
      double aspectRatio = 1.0;

      try {
        await testController.initialize();
        durationSeconds = testController.value.duration.inSeconds;
        final size = testController.value.size;
        if (size.width > 0 && size.height > 0) {
          aspectRatio = size.width / size.height;
        }
      } finally {
        await testController.dispose();
      }

      // [FILTER 1: RASIO LONG CONTENT WAJIB HORIZONTAL/LANDSCAPE (16:9)]
      // Video landscape memiliki lebar >= tinggi (rasio lebar/tinggi >= 1.0)
      if (aspectRatio < 1.0) {
        if (mounted) {
          _showOrientationWarningDialog(isIndo);
        }
        return;
      }

      // [FILTER 2: FILTER DURASI MAKSIMAL 30 MENIT (1800 DETIK)]
      if (durationSeconds > 1800) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isIndo
                    ? 'Durasi video melebihi batas. Maksimal 30 menit ($durationSeconds detik terdeteksi).'
                    : 'Video exceeds limit. Max 30 minutes ($durationSeconds sec detected).',
                style: const TextStyle(fontSize: 14),
              ),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }

      final isValid = _viewModel.setVideoFile(
        file: picked,
        durationInSeconds: durationSeconds,
        maxDurationSeconds: 1800, // Batas 30 Menit untuk Long Content
      );

      if (!isValid && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _viewModel.errorMessage ??
                  (isIndo
                      ? 'Durasi video tidak valid.'
                      : 'Invalid video duration.'),
              style: const TextStyle(fontSize: 14),
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isIndo
                  ? 'Gagal memproses file video: $e'
                  : 'Failed to process video file: $e',
              style: const TextStyle(fontSize: 14),
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showOrientationWarningDialog(bool isIndo) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.tv_rounded, color: Colors.orangeAccent, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isIndo ? 'Wajib Format Landscape (16:9)' : 'Landscape (16:9) Format Required',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          isIndo
              ? 'Video yang Anda pilih berorientasi tegak/portrait. Video Long Content wajib berformat mendatar/lanskap (16:9).\n\nUntuk video portrait, silakan gunakan menu "Create Short Content".'
              : 'The video you selected is in portrait orientation. Long Content videos must be in horizontal/landscape (16:9) format.\n\nFor portrait videos, please use "Create Short Content".',
          style: const TextStyle(color: Colors.white70, fontSize: 13.5, height: 1.4),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orangeAccent,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              isIndo ? 'Mengerti' : 'Got it',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickThumbnail() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (picked != null) {
        _viewModel.setThumbnailFile(picked);
      }
    } catch (_) {}
  }
//............................................................................//

//No ke-5....................................................................//
//UPLOAD SUBMISSION & BILINGUAL FEEDBACK                                     //
  Future<void> _submitUpload(bool isIndo) async {
    if (_currentUser == null) return;

    final success = await _viewModel.uploadAndPublishVideo(
      uploaderId: _currentUser!.uid,
      uploaderEmail: _currentUser!.email ?? '',
      channelName: _channelName.trim().isNotEmpty ? _channelName.trim() : 'Majiku Official',
      channelAvatarUrl: _channelAvatarUrl,
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      isLandscape: true, // Long Video selalu Landscape
      category: _selectedCategory,
      language: _selectedLanguage,
      videoType: 'LONG',
      actionButtonText: _actionTextController.text.trim(),
      actionButtonRoute: _actionRouteController.text.trim(),
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isIndo
                ? 'Video Panjang Mytube berhasil dipublikasikan!'
                : 'Mytube Long video successfully published!',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop();
    } else if (_viewModel.errorMessage != null && mounted) {
      _showErrorDialog(context, _viewModel.errorMessage!, isIndo);
    }
  }

  void _showErrorDialog(BuildContext context, String errorText, bool isIndo) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isIndo ? 'Detail Kegagalan Upload' : 'Upload Failure Details',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Container(
          constraints: const BoxConstraints(maxHeight: 260),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white12),
          ),
          child: SingleChildScrollView(
            child: SelectableText(
              errorText,
              style: const TextStyle(
                color: Colors.redAccent,
                fontSize: 13,
                fontFamily: 'monospace',
                height: 1.4,
              ),
            ),
          ),
        ),
        actions: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amberAccent,
              foregroundColor: Colors.black,
            ),
            icon: const Icon(Icons.copy, size: 17),
            label: Text(
              isIndo ? 'Salin Pesan Error' : 'Copy Error',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: errorText));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    isIndo ? 'Pesan error berhasil disalin ke clipboard!' : 'Error copied to clipboard!',
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
          TextButton(
            child: Text(
              isIndo ? 'Tutup' : 'Close',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
//............................................................................//

//No ke-6....................................................................//
//UI LAYOUT & ENLARGED CONTRAST FORM (PRO & MODERN)                          //
  @override
  Widget build(BuildContext context) {
    final currentLocale = ref.watch(appLanguageProvider);
    final isIndo = currentLocale.languageCode == 'id';
    String t(String en, String id) => isIndo ? id : en;

    return Scaffold(
      backgroundColor: const Color(0xFF121214),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E24),
        title: Text(
          t('Create Long Content', 'Buat Konten Panjang'),
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        elevation: 0,
      ),
      body: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, _) {
          if (_viewModel.isCheckingAuth) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.orangeAccent),
            );
          }

          if (!_viewModel.isAdminVerified) {
            return _buildAccessDenied(t);
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info Banner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orangeAccent.withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.tv_rounded, color: Colors.orangeAccent, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          t(
                            'Long Video Requirement: Horizontal landscape (16:9) video with duration up to 30 minutes.',
                            'Syarat Video Panjang: Video horizontal lanskap (16:9) dengan durasi maksimal 30 menit.',
                          ),
                          style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                // Video Picker Card
                _buildVideoPickerCard(t, isIndo),
                const SizedBox(height: 16),

                // Thumbnail Picker Card
                _buildThumbnailPickerCard(t),
                const SizedBox(height: 22),

                // --- SEKSI 1: 10 KATEGORI KONTEN TERURUT A-Z (HIGH CONTRAST CHIPS) ---
                Text(
                  t('CONTENT CATEGORY (A-Z)', 'KATEGORI KONTEN (A-Z)'),
                  style: const TextStyle(
                    color: Colors.orangeAccent,
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 9,
                  children: _categories.map((cat) {
                    final catKey = cat['en']!;
                    final catLabel = isIndo ? cat['id']! : cat['en']!;
                    final isSelected = _selectedCategory == catKey;

                    return ChoiceChip(
                      label: Text(
                        catLabel,
                        style: TextStyle(
                          color: isSelected ? Colors.black : Colors.white,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: Colors.orangeAccent,
                      backgroundColor: const Color(0xFF22222A),
                      side: BorderSide(
                        color: isSelected ? Colors.orangeAccent : Colors.white24,
                        width: 1,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _selectedCategory = catKey);
                        }
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 22),

                // --- SEKSI 2: PILIHAN 37 BAHASA KONTEN LENGKAP ---
                Text(
                  t('CONTENT LANGUAGE', 'BAHASA KONTEN'),
                  style: const TextStyle(
                    color: Colors.orangeAccent,
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 10),
                InkWell(
                  onTap: () => _showLanguageSelectionModal(t),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E24),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.language, color: Colors.orangeAccent, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _selectedLanguage,
                            style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Text(
                          t('Change', 'Ubah'),
                          style: const TextStyle(color: Colors.orangeAccent, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_drop_down, color: Colors.orangeAccent, size: 24),
                      ],
                    ),
                  ),
                ),
                const Divider(color: Colors.white12, height: 36),

                // Input Judul Video
                _buildTextField(
                  label: t('Long Video Title (Auto-Uppercase, Max 50 Chars)', 'Judul Video Panjang (Otomatis Kapital, Maks 50 Karakter)'),
                  controller: _titleController,
                  hint: t('ENTER VIDEO TITLE...', 'MASUKKAN JUDUL VIDEO...'),
                  maxLength: 50,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(50),
                    UpperCaseTextFormatter(),
                  ],
                ),
                const SizedBox(height: 16),

                // Input Deskripsi
                _buildTextField(
                  label: t('Description / Summary (Optional)', 'Deskripsi / Sinopsis (Opsional)'),
                  controller: _descController,
                  hint: '#cinema #documentary #majiku...',
                  maxLines: 4,
                ),
                const SizedBox(height: 16),

                // Label Tombol Aksi Opsional
                _buildTextField(
                  label: t('Action Button Label (Optional)', 'Label Tombol Aksi (Opsional)'),
                  controller: _actionTextController,
                  hint: t('e.g. Watch Next Episode', 'Misal: Tonton Episode Berikutnya'),
                ),
                const SizedBox(height: 16),

                // Rute Aksi Opsional
                _buildTextField(
                  label: t('Action Route (Optional)', 'Rute Aksi (Opsional)'),
                  controller: _actionRouteController,
                  hint: t('e.g. /storinema', 'Misal: /storinema'),
                ),
                const SizedBox(height: 26),

                // Upload Progress Bar
                if (_viewModel.isUploading) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: _viewModel.uploadProgress,
                      backgroundColor: Colors.white12,
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: Text(
                      '${t('Uploading to Cloud Storage', 'Mengunggah ke Cloud Storage')}: ${(_viewModel.uploadProgress * 100).toInt()}%',
                      style: const TextStyle(color: Color(0xFF60A5FA), fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Tombol Upload Eksekusi Pro & Modern (Royal Blue Studio)
                Container(
                  width: double.infinity,
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      if (!_viewModel.isUploading)
                        BoxShadow(
                          color: const Color(0xFF2563EB).withOpacity(0.4),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFF2A2A38),
                      disabledForegroundColor: Colors.white38,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _viewModel.isUploading ? null : () => _submitUpload(isIndo),
                    icon: _viewModel.isUploading
                        ? const SizedBox.shrink()
                        : const Icon(Icons.cloud_upload_rounded, color: Colors.white, size: 24),
                    label: _viewModel.isUploading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                          )
                        : Text(
                            t('Publish Long Video', 'Publikasikan Video Panjang'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15.5,
                              letterSpacing: 0.5,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showLanguageSelectionModal(String Function(String, String) t) {
    final searchController = TextEditingController();
    List<String> filteredLanguages = List.from(_languages);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.72,
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    t('Select Content Language', 'Pilih Bahasa Konten'),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
                  ),
                  const SizedBox(height: 14),

                  TextField(
                    controller: searchController,
                    style: const TextStyle(color: Colors.white, fontSize: 14.5),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search, color: Colors.white54, size: 22),
                      hintText: t('Search language...', 'Cari bahasa...'),
                      hintStyle: const TextStyle(color: Colors.white24, fontSize: 14),
                      filled: true,
                      fillColor: const Color(0xFF141418),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    onChanged: (query) {
                      setModalState(() {
                        filteredLanguages = _languages
                            .where((lang) => lang.toLowerCase().contains(query.toLowerCase()))
                            .toList();
                      });
                    },
                  ),
                  const SizedBox(height: 12),

                  Expanded(
                    child: ListView.separated(
                      itemCount: filteredLanguages.length,
                      separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
                      itemBuilder: (_, idx) {
                        final lang = filteredLanguages[idx];
                        final isSelected = lang == _selectedLanguage;

                        return ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          title: Text(
                            lang,
                            style: TextStyle(
                              color: isSelected ? Colors.orangeAccent : Colors.white,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 14.5,
                            ),
                          ),
                          trailing: isSelected ? const Icon(Icons.check, color: Colors.orangeAccent, size: 20) : null,
                          onTap: () {
                            setState(() {
                              _selectedLanguage = lang;
                            });
                            Navigator.of(ctx).pop();
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAccessDenied(String Function(String, String) t) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, color: Colors.redAccent, size: 64),
            const SizedBox(height: 16),
            Text(
              t('Access Denied', 'Akses Ditolak'),
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              t(
                'Your account is not registered or approved as a Mytube Admin in Firestore.',
                'Akun Anda belum terdaftar atau disetujui sebagai Admin Mytube di sistem Firestore.',
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 13.5),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(t('Back', 'Kembali')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPickerCard(String Function(String, String) t, bool isIndo) {
    final hasVideo = _viewModel.selectedVideoFile != null;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E24),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: hasVideo ? Colors.green : Colors.white12),
      ),
      child: Row(
        children: [
          Icon(
            hasVideo ? Icons.check_circle : Icons.tv_rounded,
            color: hasVideo ? Colors.green : Colors.orangeAccent,
            size: 34,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasVideo ? t('Selected Long Video', 'Video Panjang Terpilih') : t('Select Long Video (16:9)', 'Pilih Video Panjang (16:9)'),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  hasVideo
                      ? '${t('Duration', 'Durasi')}: ${_formatDuration(_viewModel.videoDurationSeconds)} / 30:00'
                      : t('Landscape orientation, max 30 minutes', 'Orientasi lanskap, maks 30 menit'),
                  style: TextStyle(
                    color: hasVideo ? Colors.greenAccent : Colors.white38,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: _viewModel.isUploading ? null : () => _pickVideo(isIndo),
            child: Text(
              hasVideo ? t('Change', 'Ganti') : t('Select', 'Pilih'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnailPickerCard(String Function(String, String) t) {
    final hasThumb = _viewModel.selectedThumbnailFile != null;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E24),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Icon(Icons.image, color: hasThumb ? Colors.orangeAccent : Colors.white54, size: 34),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasThumb ? t('Selected 16:9 Thumbnail', 'Thumbnail 16:9 Terpilih') : t('Select 16:9 Thumbnail Cover', 'Pilih Sampul Thumbnail 16:9'),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  t('JPG/PNG landscape cover for wide screen', 'Format JPG/PNG lanskap untuk layar lebar'),
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: _viewModel.isUploading ? null : _pickThumbnail,
            child: Text(
              hasThumb ? t('Change', 'Ganti') : t('Select', 'Pilih'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 13.5, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          maxLength: maxLength,
          inputFormatters: inputFormatters,
          style: const TextStyle(color: Colors.white, fontSize: 14.5),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white24, fontSize: 14),
            filled: true,
            fillColor: const Color(0xFF1E1E24),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            counterStyle: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ),
      ],
    );
  }
}
//............................................................................//