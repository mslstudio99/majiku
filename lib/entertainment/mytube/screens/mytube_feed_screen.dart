//============================================================================//
// DIREKTORI: lib/entertainment/mytube/screens/                              //
// FILE: MYTUBE_FEED_SCREEN.DART                                             //
// LAYAR FEED MYTUBE (BOTTOM: HOME, CC, KOLEKSI; TOP: MINIMAL ICON; SUBTITLE)//
//============================================================================//

//No ke-1....................................................................//
//IMPORTS & DEPENDENCIES                                                     //
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:video_player/video_player.dart';

import '../../../providers/config_provider.dart';
import '../../../services/ad_service.dart'; // [BARU]: Pengelola Iklan AdMob
import '../../../services/firestore_service.dart';
import '../models/video_mytube_model.dart';
import '../services/firestore_mytube_service.dart';
import '../view_model/mytube_feed_view_model.dart';
import 'mytube_comment_sheet.dart';
//............................................................................//

//No ke-2....................................................................//
//WIDGET DECLARATION & STATE SETUP                                           //
class MytubeFeedScreen extends ConsumerStatefulWidget {
  const MytubeFeedScreen({super.key});

  @override
  ConsumerState<MytubeFeedScreen> createState() => _MytubeFeedScreenState();
}

class _MytubeFeedScreenState extends ConsumerState<MytubeFeedScreen> {
  late final MytubeFeedViewModel _viewModel;
  final FirestoreMytubeService _service = FirestoreMytubeService();
  final PageController _pageController = PageController();
  final TextEditingController _searchController = TextEditingController();

  User? _currentUser;
  bool _isSearchOpen = false;
  bool _isManualFullscreen = false;

  // [SINKRONISASI LAYAR & JUMP TO TOP]: Menyimpan kunci filter terakhir agar layar otomatis lompat ke urutan 0
  String _lastFilterKey = '';

  // [ADMOB TIMING & NATURAL BREAK]: Penjadwal Iklan 1 Menit Awal & 7 Menit Berkala
  DateTime? _nextAdEligibleTime;
  bool _isAdShowing = false;

  // Daftar 16 Kategori Resmi Terurut A-Z (Default English)
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
//LIFECYCLE, ORIENTATION CONTROL & FULLSCREEN TOGGLE                         //
  @override
  void initState() {
    super.initState();
    _viewModel = MytubeFeedViewModel(service: _service);
    _currentUser = FirebaseAuth.instance.currentUser;
    final uid = _currentUser?.uid ?? '';
    _viewModel.initFeed(uid, videoType: 'SHORT');
    _recordFeedVisit();

    // [ADMOB]: 1. Preload Iklan Interstitial di latar belakang sejak awal layar dibuka
    AdService().loadInterstitial();

    // [ADMOB]: 2. Jadwalkan iklan pertama berhak tayang setelah 1 Menit (60 detik)
    _nextAdEligibleTime = DateTime.now().add(const Duration(minutes: 1));
  }

  void _recordFeedVisit() {
    FirestoreService().logFeatureActivity(
      featureKey: 'mytube',
      subFeatureKey: 'feed',
      eventType: 'visit',
    );
  }

  // Toggle Manual Fullscreen (Bisa dipanggil dari tombol Fullscreen di PC atau HP)
  void _toggleManualFullscreen(bool isLandscapeVideo) {
    if (!isLandscapeVideo) return; // PROTEKSI: Video Shorts tidak boleh UI-less

    setState(() {
      _isManualFullscreen = !_isManualFullscreen;
    });

    if (!kIsWeb) {
      if (_isManualFullscreen) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      } else {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      }
    }
  }

  @override
  void dispose() {
    // Kembalikan orientasi dan status bar HP ke kondisi normal saat keluar
    if (!kIsWeb) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
    _pageController.dispose();
    _searchController.dispose();
    _viewModel.dispose();
    super.dispose();
  }
//............................................................................//

//No ke-4....................................................................//
//MAIN CANVAS & LISTENABLE BUILDER (Fondasi Scaffold dan PageView)           //
  /// [ADMOB INTERSTITIAL ORCHESTRATOR]: Hard Stop & Mute Sebelum Iklan Muncul
  void _handleVideoPageChangeWithAd(int index, List<VideoMytubeModel> displayList) {
    final now = DateTime.now();
    final bool isEligible = !kIsWeb &&
        _nextAdEligibleTime != null &&
        now.isAfter(_nextAdEligibleTime!) &&
        AdService().isAdReady &&
        !_isAdShowing;

    if (isEligible) {
      _isAdShowing = true;
      
      // 1. [HARD STOP & MUTE SEBELUM IKLAN MUNCUL]:
      // Mematikan volume video lama ke 0.0 & pause seketika agar tidak bocor suara ke iklan
      _viewModel.setAdActiveStatus(true);

      // 2. Tayangkan Iklan Interstitial
      AdService().showInterstitial(
        onAdClicked: () {
          FirestoreService().logFeatureActivity(featureKey: 'mytube', subFeatureKey: 'interstitial_ad', eventType: 'conversion');
        },
        onAdDismissed: () {
          _isAdShowing = false;
          _nextAdEligibleTime = DateTime.now().add(const Duration(minutes: 7));

          // 3. Iklan selesai & ditutup: Baru beralih ke video baru dan nyalakan suaranya
          if (mounted) {
            _viewModel.setAdActiveStatus(false);
            _viewModel.onPageChanged(index);
            final videoId = displayList[index].id;
            _viewModel.checkInitialInteractionStatus(videoId);
          }
        },
      );
    } else {
      _viewModel.onPageChanged(index);
      final videoId = displayList[index].id;
      _viewModel.checkInitialInteractionStatus(videoId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentLocale = ref.watch(appLanguageProvider);
    final isIndo = currentLocale.languageCode == 'id';
    String t(String en, String id) => isIndo ? id : en;

    return Scaffold(
      backgroundColor: Colors.black,
      body: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, _) {
          if (_viewModel.isLoading) {
            return const Center(child: CircularProgressIndicator(color: Colors.white70));
          }

          if (_viewModel.errorMessage != null) {
            return _buildErrorState(_viewModel.errorMessage!, t);
          }

          final displayList = _viewModel.filteredVideos;
          
          if (_lastFilterKey != _viewModel.filterKey) {
            _lastFilterKey = _viewModel.filterKey;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _pageController.hasClients && _pageController.page != 0) {
                _pageController.jumpToPage(0);
              }
            });
          }
          
          bool isCurrentVideoLandscape = false;
          if (displayList.isNotEmpty && _viewModel.currentIndex < displayList.length) {
            final curVid = displayList[_viewModel.currentIndex];
            final curCtrl = _viewModel.currentController;
            isCurrentVideoLandscape = curVid.isLandscape || 
                                      !_viewModel.isShortMode || 
                                      (curCtrl != null && curCtrl.value.isInitialized && curCtrl.value.aspectRatio > 1.2);
          }

          final isDeviceLandscape = !kIsWeb && MediaQuery.of(context).orientation == Orientation.landscape;
          final isFullscreen = isCurrentVideoLandscape && (isDeviceLandscape || _isManualFullscreen);

          final double bottomSafePadding = MediaQuery.of(context).padding.bottom > 0
              ? MediaQuery.of(context).padding.bottom
              : 8.0;

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (!kIsWeb) {
              if (isFullscreen) {
                SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
              } else {
                SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
              }
            }
          });

          return Stack(
            children: [
              if (displayList.isEmpty)
                _buildEmptyState(t)
              else
                GestureDetector(
                  onHorizontalDragEnd: (details) {
                    final velocity = details.primaryVelocity ?? 0.0;
                    if (velocity < -300) { 
                      if (_viewModel.isShortMode) _viewModel.switchVideoType('LONG');
                    } else if (velocity > 300) { 
                      if (!_viewModel.isShortMode) _viewModel.switchVideoType('SHORT');
                    }
                  },
                  child: PageView.builder(
                    controller: _pageController,
                    scrollDirection: Axis.vertical,
                    itemCount: displayList.length,
                    physics: isFullscreen
                        ? const NeverScrollableScrollPhysics()
                        : const PageScrollPhysics(parent: ClampingScrollPhysics()),
                    onPageChanged: (index) {
                      _handleVideoPageChangeWithAd(index, displayList);
                    },
                    itemBuilder: (context, index) {
                      final video = displayList[index];
                      final controller = _viewModel.currentIndex == index
                          ? _viewModel.currentController
                          : null;

                      final bool isVideoLandscape = controller != null && controller.value.isInitialized
                          ? controller.value.aspectRatio > 1.2 || video.isLandscape || !_viewModel.isShortMode
                          : video.isLandscape || !_viewModel.isShortMode;

                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          _buildBaseVideoPlayer(controller, isVideoLandscape, isFullscreen, isDeviceLandscape, video, t),

                          if (_viewModel.isSubtitleLoading) _buildSubtitleLoadingOverlay(t),
                          if (_viewModel.isAutoplaySoundBlocked) _buildUnmutePromptOverlay(t),

                          if (!isVideoLandscape)
                            ..._buildShortVideoOutFrameOverlays(video, bottomSafePadding, t),

                          if (isVideoLandscape)
                            ..._buildLongVideoOutFrameOverlays(video, controller, bottomSafePadding, isFullscreen, isDeviceLandscape, t),
                        ],
                      );
                    },
                  ),
                ),

              if (isFullscreen) _buildFullscreenExitButton(t),
              if (!isFullscreen) _buildTopBar(t, isIndo),
              if (!isFullscreen) _buildBottomNavigationBar(t, isIndo),
            ],
          );
        },
      ),
    );
  }
//............................................................................//

//No ke-4.1..................................................................//
//BASE PLAYER & SHORTS OVERLAY (UI Khusus Shorts, aman dari regresi)         //
  Widget _buildBaseVideoPlayer(
    VideoPlayerController? controller,
    bool isVideoLandscape,
    bool isFullscreen,
    bool isDeviceLandscape,
    VideoMytubeModel video,
    String Function(String, String) t,
  ) {
    final double bottomNavHeight = isFullscreen
        ? 0.0
        : (60.0 + (MediaQuery.of(context).padding.bottom > 0 ? MediaQuery.of(context).padding.bottom : 6.0));

    final bool isBeingOptimized = video.hlsStatus == 'PENDING' || video.hlsStatus == 'PROCESSING';

    // [KUNCI GEOMETRI VIDEO]: Hitung rasio aspek yang pas (Short = 9/16, Long = 16/9)
    final double targetAspectRatio = (controller != null && controller.value.isInitialized && controller.value.aspectRatio > 0)
        ? controller.value.aspectRatio
        : (isVideoLandscape ? (16 / 9) : (9 / 16));

    // [THUMBNAIL DI LAPISAN DEPAN + FADE OUT OTOMATIS]:
    Widget posterLayer = _buildPosterPlaceholder(video, isVideoLandscape);
    if (controller != null) {
      posterLayer = ValueListenableBuilder<VideoPlayerValue>(
        valueListenable: controller,
        builder: (context, value, child) {
          final bool isPlaying = value.isInitialized && (value.isPlaying || value.position > Duration.zero);
          return IgnorePointer(
            child: AnimatedOpacity(
              opacity: isPlaying ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 300),
              child: child,
            ),
          );
        },
        child: posterLayer,
      );
    } else {
      posterLayer = IgnorePointer(child: posterLayer);
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _viewModel.togglePlayPause(),
      child: Container(
        color: Colors.black, // Kanvas dasar hitam murni di seluruh layar HP
        padding: EdgeInsets.only(bottom: isVideoLandscape ? bottomNavHeight : 0.0),
        child: Center(
          // [KUNCI PRESISI]: Mengunci ukuran video DAN thumbnail dalam bingkai rasio yang sama persis
          child: AspectRatio(
            aspectRatio: targetAspectRatio,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final videoWidth = constraints.maxWidth;
                final videoHeight = constraints.maxHeight;
                final bool isCinemaLandscape = isVideoLandscape && (isDeviceLandscape || _isManualFullscreen || kIsWeb);

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    // 1. LAPISAN BELAKANG: Video Player Asli
                    if (controller != null && controller.value.isInitialized)
                      IgnorePointer(child: VideoPlayer(controller))
                    else
                      Container(color: Colors.black),

                    // 2. LAPISAN DEPAN: Poster Thumbnail (Ukurannya pas 1:1 dengan frame video)
                    posterLayer,

                    // 3. Indikator Buffering & User Pause
                    if (controller != null && controller.value.isInitialized)
                      _buildPlayPauseBufferingIndicator(controller)
                    else if (isBeingOptimized)
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.75),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.amberAccent, width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amberAccent)),
                              const SizedBox(width: 8),
                              Text(t('Optimizing Quality...', 'Mengoptimasi Kualitas...'), style: const TextStyle(color: Colors.amberAccent, fontSize: 11.5, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      )
                    else
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.black.withOpacity(0.35), shape: BoxShape.circle),
                          child: const SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.amberAccent)),
                        ),
                      ),

                    // 4. SUBTITLE KHUSUS SHORTS (Di dalam video frame, posisi 25%)
                    if (!isVideoLandscape && _viewModel.isSubtitleActive && controller != null)
                      Positioned(
                        bottom: videoHeight * 0.25,
                        left: 16.0,
                        right: 75.0,
                        child: _buildSubtitleBox(controller, isCinema: false),
                      ),

                    // 5. SUBTITLE KHUSUS LONG LANSKAP BIOSKOP (Di dalam video frame, posisi 10%)
                    if (isVideoLandscape && isCinemaLandscape && _viewModel.isSubtitleActive && controller != null)
                      Positioned(
                        bottom: (videoHeight * 0.10).clamp(10.0, 42.0),
                        left: videoWidth * 0.08,
                        right: videoWidth * 0.08,
                        child: _buildSubtitleBox(controller, isCinema: true),
                      ),

                    // 6. [TOMBOL MASUK FULLSCREEN]: Pojok Kanan Atas Video Lanskap
                    if (isVideoLandscape && !isFullscreen)
                      Positioned(
                        top: 12,
                        right: 12,
                        child: GestureDetector(
                          onTap: () => _toggleManualFullscreen(true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.70),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white30, width: 0.8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.fullscreen_rounded, color: Colors.white, size: 20),
                                const SizedBox(width: 4),
                                Text(
                                  t('Fullscreen', 'Layar Penuh'),
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// [HELPER POSTER INSTAN]: Ukuran terkunci rapi di dalam bingkai video (Cover 100% pas frame)
  Widget _buildPosterPlaceholder(VideoMytubeModel video, bool isVideoLandscape) {
    if (video.thumbnailUrl.isNotEmpty) {
      return Image.network(
        video.thumbnailUrl,
        fit: BoxFit.cover, // Di dalam kotak AspectRatio video, cover mengisi 100% bingkai tanpa keluar garis
        width: double.infinity,
        height: double.infinity,
        alignment: Alignment.center,
        errorBuilder: (_, __, ___) => _buildFallbackDarkGradient(),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildFallbackDarkGradient();
        },
      );
    }
    return _buildFallbackDarkGradient();
  }

  Widget _buildFallbackDarkGradient() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1E1E24),
            Color(0xFF141418),
            Color(0xFF0A0A0D),
          ],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.play_circle_fill_rounded,
          color: Colors.white12,
          size: 64,
        ),
      ),
    );
  }

  List<Widget> _buildShortVideoOutFrameOverlays(VideoMytubeModel video, double bottomSafePadding, String Function(String, String) t) {
    return [
      Positioned(
        right: 12,
        bottom: 85.0 + bottomSafePadding,
        child: _buildActionColumn(video),
      ),
      Positioned(
        left: 16,
        bottom: 75.0 + bottomSafePadding,
        right: 80,
        child: _buildBottomMetadata(video, t),
      ),
    ];
  }
//............................................................................//

//No ke-4.2..................................................................//
//LONG VIDEO / LANSKAP OVERLAY (Bioskop 10%, Portrait Khusus, Fullscreen)    //
  List<Widget> _buildLongVideoOutFrameOverlays(
    VideoMytubeModel video,
    VideoPlayerController? controller,
    double bottomSafePadding,
    bool isFullscreen,
    bool isDeviceLandscape,
    String Function(String, String) t,
  ) {
    final bool isCinemaLandscape = isDeviceLandscape || _isManualFullscreen || kIsWeb;
    List<Widget> overlays = [];

    // [SUBTITLE KHUSUS LONG VIDEO SAAT HP TEGAK/PORTRAIT]:
    // Puncak atap dikunci persis sejajar puncak tombol Like (215 dp di atas dasar kolom aksi)
    // Rata Atas (Alignment.topLeft) & Ukuran Font 16.0 agar pas dan sedikit lebih besar
    if (_viewModel.isSubtitleActive && !isCinemaLandscape && controller != null) {
      final double likeButtonTop = 85.0 + bottomSafePadding + 215.0;
      const double boxHeight = 140.0;

      overlays.add(
        Positioned(
          bottom: likeButtonTop - boxHeight,
          height: boxHeight,
          left: 16.0,
          right: 75.0,
          child: _buildSubtitleBox(
            controller,
            isCinema: false,
            alignment: Alignment.topLeft, // <-- KUNCI RATA ATAS SEJAJAR TOMBOL LIKE!
            fontSize: 18.0,               // <-- FONT 18.0 PAS & LEBIH BESAR SESUAI PERMINTAAN
          ),
        ),
      );
    }

    // Aksi Kanan & Metadata Bawah hanya muncul jika layar TIDAK Fullscreen
    if (!isFullscreen) {
      overlays.add(
        Positioned(
          right: 12,
          bottom: 85.0 + bottomSafePadding,
          child: _buildActionColumn(video),
        ),
      );
      overlays.add(
        Positioned(
          left: 16,
          bottom: 75.0 + bottomSafePadding,
          right: 80,
          child: _buildBottomMetadata(video, t),
        ),
      );
    }

    return overlays;
  }

  Widget _buildFullscreenExitButton(String Function(String, String) t) {
    return Positioned(
      top: MediaQuery.of(context).padding.top > 0 ? MediaQuery.of(context).padding.top + 8 : 16,
      right: 16,
      child: SafeArea(
        child: GestureDetector(
          onTap: () => _toggleManualFullscreen(true),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.75),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.amberAccent.withOpacity(0.8), width: 1),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 8)],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.fullscreen_exit_rounded, color: Colors.amberAccent, size: 20),
                const SizedBox(width: 5),
                Text(
                  t('Exit Fullscreen', 'Keluar Layar Penuh'),
                  style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
//............................................................................//

//No ke-4.3..................................................................//
//TOP BAR, BOTTOM NAVIGATION & HELPER COMPONENTS                             //
  Widget _buildTopBar(String Function(String, String) t, bool isIndo) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 2),

                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E24).withOpacity(0.85),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24, width: 0.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          if (!_viewModel.isShortMode) _viewModel.switchVideoType('SHORT');
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: _viewModel.isShortMode ? Colors.amberAccent : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(Icons.bolt, color: _viewModel.isShortMode ? Colors.black : Colors.white60, size: 16),
                        ),
                      ),
                      const SizedBox(width: 3),
                      InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          if (_viewModel.isShortMode) _viewModel.switchVideoType('LONG');
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: !_viewModel.isShortMode ? Colors.orangeAccent : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(Icons.tv_rounded, color: !_viewModel.isShortMode ? Colors.black : Colors.white60, size: 16),
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                IconButton(
                  icon: Icon(
                    _isSearchOpen ? Icons.search_off : Icons.search,
                    color: _viewModel.searchQuery.isNotEmpty ? Colors.amberAccent : Colors.white,
                    size: 22,
                  ),
                  tooltip: t('Search Video Title', 'Cari Judul Video'),
                  onPressed: () {
                    setState(() {
                      _isSearchOpen = !_isSearchOpen;
                      if (_isSearchOpen) {
                        _viewModel.pauseCurrentVideoForSearch(); // [AUTO-PAUSE ANTI HANTU]
                      } else if (_viewModel.searchQuery.isNotEmpty) {
                        _searchController.clear();
                        _viewModel.clearSearchQuery();
                      }
                    });
                  },
                ),

                Stack(
                  alignment: Alignment.topRight,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.tune_rounded,
                        color: (_viewModel.selectedCategory != null || _viewModel.selectedLanguage != null) ? Colors.amberAccent : Colors.white,
                        size: 22,
                      ),
                      tooltip: t('Filter Content', 'Filter Konten'),
                      onPressed: () => _showFilterModalSheet(t, isIndo),
                    ),
                    if (_viewModel.selectedCategory != null || _viewModel.selectedLanguage != null)
                      Positioned(
                        top: 8, right: 8,
                        child: Container(width: 7, height: 7, decoration: const BoxDecoration(color: Colors.amberAccent, shape: BoxShape.circle)),
                      ),
                  ],
                ),
              ],
            ),

            if (_isSearchOpen)
              Container(
                margin: const EdgeInsets.only(top: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E24).withOpacity(0.95),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amberAccent.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: Colors.amberAccent, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        autofocus: true,
                        style: const TextStyle(color: Colors.white, fontSize: 13.5),
                        decoration: InputDecoration(
                          hintText: t('Search title or channel...', 'Cari judul video atau kreator...'),
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onChanged: (val) => _viewModel.setSearchQuery(val),
                      ),
                    ),
                    if (_searchController.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _viewModel.clearSearchQuery();
                        },
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavigationBar(String Function(String, String) t, bool isIndo) {
    return Positioned(
      left: 0, right: 0, bottom: 0,
      child: Container(
        padding: EdgeInsets.only(
          top: 6,
          bottom: MediaQuery.of(context).padding.bottom > 0 ? MediaQuery.of(context).padding.bottom : 6,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF0F0F12).withOpacity(0.92),
          border: const Border(top: BorderSide(color: Colors.white12, width: 0.8)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            InkWell(
              onTap: () {
                _viewModel.resetToHomeDefault();
                if (_pageController.hasClients) _pageController.jumpToPage(0);
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.home_rounded, color: (_viewModel.isShortMode && !_viewModel.isFilterActive) ? Colors.amberAccent : Colors.white70, size: 24),
                    const SizedBox(height: 2),
                    Text(t('Home', 'Beranda'), style: TextStyle(color: (_viewModel.isShortMode && !_viewModel.isFilterActive) ? Colors.amberAccent : Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),

            InkWell(
              onTap: () => _showSubtitleModalSheet(t, isIndo),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_viewModel.isSubtitleActive ? Icons.closed_caption_rounded : Icons.closed_caption_off_rounded, color: _viewModel.isSubtitleActive ? Colors.amberAccent : Colors.white70, size: 24),
                    const SizedBox(height: 2),
                    Text(_viewModel.isSubtitleActive ? 'CC (${_viewModel.activeSubtitleLangCode!.toUpperCase()})' : 'Subtitle', style: TextStyle(color: _viewModel.isSubtitleActive ? Colors.amberAccent : Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),

            InkWell(
              onTap: () => _showLibraryModalSheet(t, isIndo),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bookmarks_rounded, color: Colors.white70, size: 22),
                    const SizedBox(height: 2),
                    Text(t('Library', 'Koleksi'), style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- KUMPULAN HELPER WIDGETS ---
  // [HELPER SUBTITLE MANDIRI]: Mendukung Alignment Kustom (Rata Atas) dan Pengaturan Font Terpisah
  Widget _buildSubtitleBox(
    VideoPlayerController controller, {
    required bool isCinema,
    AlignmentGeometry? alignment,
    double fontSize = 18.0,
  }) {
    final effectiveAlignment = alignment ?? (isCinema ? Alignment.bottomCenter : Alignment.bottomLeft);

    return IgnorePointer(
      child: ValueListenableBuilder<VideoPlayerValue>(
        valueListenable: controller,
        builder: (context, value, _) {
          final currentPosition = value.position;
          String activeText = '';

          for (final cue in _viewModel.currentCues) {
            if (currentPosition >= cue.start && currentPosition <= cue.end) {
              activeText = cue.text;
              break;
            }
          }

          if (activeText.isEmpty) return const SizedBox.shrink();

          return Align(
            alignment: effectiveAlignment,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.78),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white24, width: 0.6),
              ),
              child: Text(
                activeText,
                textAlign: isCinema ? TextAlign.center : TextAlign.left,
                softWrap: true,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                  height: 1.25,
                  shadows: const [
                    Shadow(offset: Offset(1, 1), blurRadius: 3, color: Colors.black),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlayPauseBufferingIndicator(VideoPlayerController controller) {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        if (!value.isInitialized) return const SizedBox.shrink();

        if (value.isBuffering) {
          return Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.black.withOpacity(0.45), shape: BoxShape.circle),
              child: const SizedBox(width: 38, height: 38, child: CircularProgressIndicator(strokeWidth: 2.8, color: Colors.amberAccent)),
            ),
          );
        }

        if (_viewModel.isUserPaused && !value.isPlaying) {
          return Center(
            child: IgnorePointer(
              child: Container(
                width: 70, height: 70,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white38, width: 1.5),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 10, spreadRadius: 2)],
                ),
                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 46),
              ),
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildSubtitleLoadingOverlay(String Function(String, String) t) {
    return Positioned(
      top: 95, left: 24, right: 24,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E24).withOpacity(0.92),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.amberAccent.withOpacity(0.6), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amberAccent)),
              const SizedBox(width: 10),
              Flexible(child: Text(_viewModel.subtitleLoadingMessage ?? t('Translating...', 'Menerjemahkan...'), style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUnmutePromptOverlay(String Function(String, String) t) {
    return Positioned(
      top: 95, left: 0, right: 0,
      child: Center(
        child: GestureDetector(
          onTap: () => _viewModel.unmuteByGesture(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.75),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white38, width: 0.8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.volume_off_rounded, color: Colors.amberAccent, size: 18),
                const SizedBox(width: 8),
                Text(t('Tap to unmute', 'Ketuk aktifkan suara'), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),
      ),
    );
  }
//............................................................................//

//No ke-5....................................................................//
//MODAL BOTTOM SHEETS (FILTER, SUBTITLE CC 37 BAHASA & LIBRARY)              //
  // --- A. MODAL FILTER KONTEN (DILENGKAPI PENGANGKAT TOMBOL SAFEAREA HP) ---
  void _showFilterModalSheet(String Function(String, String) t, bool isIndo) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true, // [PROTEKSI HP]: Memastikan sheet berada di area aman layar HP
      backgroundColor: const Color(0xFF1E1E24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final activeCat = _viewModel.selectedCategory;
            final activeLang = _viewModel.selectedLanguage;

            // Perhitungan batas aman navigasi bawah HP (gestur / 3 tombol)
            final double bottomInset = MediaQuery.of(context).padding.bottom;

            return Container(
              height: MediaQuery.of(context).size.height * 0.80, // Ketinggian 80% proporsional
              padding: EdgeInsets.fromLTRB(20, 16, 20, 14.0 + bottomInset),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        t('MyTube Content Filter', 'Filter Konten MyTube'),
                        style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      if (activeCat != null || activeLang != null)
                        TextButton(
                          onPressed: () {
                            _viewModel.clearAllFilters();
                            setModalState(() {});
                            Navigator.of(ctx).pop();
                          },
                          child: Text(
                            t('Reset', 'Reset'),
                            style: const TextStyle(color: Colors.amberAccent, fontSize: 13),
                          ),
                        ),
                    ],
                  ),
                  const Divider(color: Colors.white12, height: 20),

                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t('CONTENT CATEGORY (A-Z)', 'KATEGORI KONTEN (A-Z)'),
                            style: const TextStyle(color: Colors.amberAccent, fontSize: 12.5, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _categories.map((cat) {
                              final catEn = cat['en']!;
                              final catLabel = isIndo ? cat['id']! : cat['en']!;
                              final isSelected = activeCat == catEn;

                              return ChoiceChip(
                                label: Text(
                                  catLabel,
                                  style: TextStyle(
                                    color: isSelected ? Colors.black : Colors.white,
                                    fontSize: 12.5,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  ),
                                ),
                                selected: isSelected,
                                selectedColor: Colors.amberAccent,
                                backgroundColor: const Color(0xFF2B2B36),
                                side: BorderSide(color: isSelected ? Colors.amberAccent : Colors.white12),
                                onSelected: (selected) {
                                  _viewModel.setCategoryFilter(selected ? catEn : null);
                                  setModalState(() {});
                                },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 24),

                          Text(
                            t('LANGUAGE & REGION', 'BAHASA & NEGARA'),
                            style: const TextStyle(color: Colors.amberAccent, fontSize: 12.5, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _languages.map((lang) {
                              final isSelected = activeLang == lang;

                              return ChoiceChip(
                                label: Text(
                                  lang,
                                  style: TextStyle(
                                    color: isSelected ? Colors.black : Colors.white,
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  ),
                                ),
                                selected: isSelected,
                                selectedColor: Colors.orangeAccent,
                                backgroundColor: const Color(0xFF2B2B36),
                                side: BorderSide(color: isSelected ? Colors.orangeAccent : Colors.white12),
                                onSelected: (selected) {
                                  _viewModel.setLanguageFilter(selected ? lang : null);
                                  setModalState(() {});
                                },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),

                  // [TOMBOL TERAPKAN FILTER TERANGKAT LEGA DI ATAS BILAH NAVIGASI HP]
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amberAccent,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 2,
                      ),
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: Text(t('Apply Filter', 'Terapkan Filter'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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

  // --- B. MODAL PILIH SUBTITLE (CC) 37 BAHASA DUNIA ---
  void _showSubtitleModalSheet(String Function(String, String) t, bool isIndo) {
    const Map<String, String> langCodeMap = {
      'English (US)': 'en',
      'Indonesian': 'id',
      'Hindi': 'hi',
      'English (UK)': 'en-gb',
      'English (Australia)': 'en-au',
      'English (India)': 'en-in',
      'Arabic': 'ar',
      'Bengali (India)': 'bn',
      'Danish': 'da',
      'Dutch (Netherlands)': 'nl',
      'Dutch (Belgium)': 'nl-be',
      'Finnish': 'fi',
      'French (France)': 'fr',
      'French (Canada)': 'fr-ca',
      'German': 'de',
      'Gujarati': 'gu',
      'Italian': 'it',
      'Japanese': 'ja',
      'Kannada': 'kn',
      'Korean': 'ko',
      'Malayalam': 'ml',
      'Mandarin Chinese': 'zh',
      'Marathi': 'mr',
      'Norwegian': 'no',
      'Polish': 'pl',
      'Portuguese (Brazil)': 'pt',
      'Russian': 'ru',
      'Spanish (Spain)': 'es',
      'Spanish (US)': 'es-us',
      'Swedish': 'sv',
      'Tamil': 'ta',
      'Telugu': 'te',
      'Thai': 'th',
      'Turkish': 'tr',
      'Ukrainian': 'uk',
      'Urdu': 'ur',
      'Vietnamese': 'vi',
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFF1E1E24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.72,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Column(
            children: [
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.closed_caption_rounded, color: Colors.amberAccent, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        t('Video Subtitles (CC)', 'Subtitle Video (CC)'),
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  if (_viewModel.isSubtitleActive)
                    TextButton(
                      onPressed: () {
                        _viewModel.disableSubtitles();
                        Navigator.of(ctx).pop();
                      },
                      child: Text(
                        t('Turn Off', 'Matikan'),
                        style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
              const Divider(color: Colors.white12, height: 18),

              Expanded(
                child: ListView.separated(
                  itemCount: _languages.length,
                  separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
                  itemBuilder: (context, idx) {
                    final langName = _languages[idx];
                    final code = langCodeMap[langName] ?? 'en';
                    final isCurrentActive = _viewModel.activeSubtitleLangCode == code;

                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      title: Text(
                        langName,
                        style: TextStyle(
                          color: isCurrentActive ? Colors.amberAccent : Colors.white,
                          fontWeight: isCurrentActive ? FontWeight.bold : FontWeight.normal,
                          fontSize: 14,
                        ),
                      ),
                      trailing: isCurrentActive
                          ? const Icon(Icons.check_circle_rounded, color: Colors.amberAccent, size: 20)
                          : null,
                      onTap: () {
                        Navigator.of(ctx).pop();
                        _viewModel.selectSubtitleLanguage(langCode: code, langName: langName);
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
  }

  // --- C. MODAL LEMBAR KOLEKSI SAYA (MYTUBE LIBRARY) ---
  void _showLibraryModalSheet(String Function(String, String) t, bool isIndo) {
    final uid = _currentUser?.uid ?? '';
    if (uid.isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFF16161A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DefaultTabController(
          length: 2,
          child: Container(
            height: MediaQuery.of(context).size.height * 0.78,
            padding: const EdgeInsets.only(top: 14),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 12),
                TabBar(
                  indicatorColor: Colors.amberAccent,
                  labelColor: Colors.amberAccent,
                  unselectedLabelColor: Colors.white60,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                  tabs: [
                    Tab(
                      icon: const Icon(Icons.bookmark_outline, size: 20),
                      text: t('Saved Videos', 'Video Tersimpan'),
                    ),
                    Tab(
                      icon: const Icon(Icons.people_outline, size: 20),
                      text: t('Following', 'Diikuti'),
                    ),
                  ],
                ),
                const Divider(color: Colors.white12, height: 1),

                Expanded(
                  child: TabBarView(
                    children: [
                      // TAB 1: DAFTAR VIDEO TERSIMPAN
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .doc(uid)
                            .collection('mytube_saves')
                            .orderBy('saved_at', descending: true)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator(color: Colors.amberAccent));
                          }

                          final docs = snapshot.data?.docs ?? [];
                          if (docs.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.bookmark_border_rounded, color: Colors.white24, size: 54),
                                  const SizedBox(height: 12),
                                  Text(
                                    t('No saved videos yet.', 'Belum ada video yang disimpan.'),
                                    style: const TextStyle(color: Colors.white54, fontSize: 13.5),
                                  ),
                                ],
                              ),
                            );
                          }

                          return ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: docs.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, idx) {
                              final data = docs[idx].data() as Map<String, dynamic>;
                              final videoId = data['video_id'] ?? docs[idx].id;
                              final videoType = data['video_type'] ?? 'SHORT';

                              return Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E1E24),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: Colors.white12,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        videoType == 'LONG' ? Icons.tv_rounded : Icons.bolt,
                                        color: videoType == 'LONG' ? Colors.orangeAccent : Colors.amberAccent,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            videoId,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            'Type: $videoType',
                                            style: const TextStyle(color: Colors.white54, fontSize: 11),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                      onPressed: () async {
                                        await docs[idx].reference.delete();
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),

                      // TAB 2: DAFTAR CHANNEL YANG DIIKUTI
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .doc(uid)
                            .collection('mytube_following')
                            .orderBy('followed_at', descending: true)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator(color: Colors.amberAccent));
                          }

                          final docs = snapshot.data?.docs ?? [];
                          if (docs.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.people_outline_rounded, color: Colors.white24, size: 54),
                                  const SizedBox(height: 12),
                                  Text(
                                    t('Not following any channels yet.', 'Belum mengikuti channel mana pun.'),
                                    style: const TextStyle(color: Colors.white54, fontSize: 13.5),
                                  ),
                                ],
                              ),
                            );
                          }

                          return ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: docs.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, idx) {
                              final data = docs[idx].data() as Map<String, dynamic>;
                              final channelName = data['channel_name'] ?? 'Creator';
                              final avatarUrl = data['avatar_url'] ?? '';

                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E1E24),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor: Colors.white12,
                                      backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                                      child: avatarUrl.isEmpty ? const Icon(Icons.person, color: Colors.white54) : null,
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Text(
                                        '@$channelName',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
                                      ),
                                    ),
                                    TextButton(
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.white60,
                                        backgroundColor: Colors.white10,
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                      ),
                                      onPressed: () async {
                                        await docs[idx].reference.delete();
                                      },
                                      child: Text(
                                        t('Unfollow', 'Berhenti'),
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
//............................................................................//

//No ke-6....................................................................//
//RIGHT ACTION COLUMN & HELPER FORMATTERS (DILENGKAPI AKSI SHARE UNIVERSAL)  //
  Widget _buildActionColumn(VideoMytubeModel video) {
    final isLiked = _viewModel.isVideoLiked(video.id);
    final isSaved = _viewModel.isVideoSaved(video.id);
    final currentLocale = ref.watch(appLanguageProvider);
    final isIndo = currentLocale.languageCode == 'id';
    String t(String en, String id) => isIndo ? id : en;

    final creatorKey = video.uploaderEmail.trim().isNotEmpty
        ? video.uploaderEmail.trim().toLowerCase()
        : video.uploaderId.trim();

    final isSelf = _currentUser != null && (
      (_currentUser!.uid.isNotEmpty && _currentUser!.uid == video.uploaderId) ||
      (_currentUser!.email != null &&
          _currentUser!.email!.isNotEmpty &&
          video.uploaderEmail.isNotEmpty &&
          _currentUser!.email!.toLowerCase() == video.uploaderEmail.toLowerCase())
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // [TOMBOL FOLLOW RESMI]: Bertengger di puncak kolom aksi
        if (!isSelf && _currentUser != null && creatorKey.isNotEmpty) ...[
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(_currentUser!.uid)
                .collection('mytube_following')
                .doc(creatorKey)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                debugPrint('🚨 [MYTUBE FOLLOW STREAM ERROR]: ${snapshot.error}');
              }

              final isFollowing = snapshot.hasData && snapshot.data != null && snapshot.data!.exists;

              return StatefulBuilder(
                builder: (context, setBtnState) {
                  bool isProcessing = false;

                  return MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () async {
                        if (isProcessing) return;
                        setBtnState(() => isProcessing = true);

                        // [PIPA DATA LENGKAP]: Mengirim Nama, Avatar, & Email resmi penonton
                        final success = await _service.toggleFollowCreator(
                          userId: _currentUser!.uid,
                          creatorKey: creatorKey,
                          channelName: video.channelName,
                          avatarUrl: video.channelAvatarUrl,
                          dominantCategory: video.category,
                          preferredLanguage: video.language,
                          followerName: _currentUser?.displayName ?? 'Pengikut MyTube',
                          followerAvatar: _currentUser?.photoURL ?? '',
                          followerEmail: _currentUser?.email ?? '',
                        );

                        if (context.mounted) {
                          setBtnState(() => isProcessing = false);
                        }

                        if (!isFollowing && success) {
                          FirestoreService().logFeatureActivity(
                            featureKey: 'mytube',
                            subFeatureKey: 'follow_creator',
                            eventType: 'conversion',
                          );
                        }
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: isFollowing ? const Color(0xFF1E1E24) : Colors.amberAccent,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isFollowing ? Colors.white30 : Colors.amberAccent,
                                width: 1.5,
                              ),
                              boxShadow: [
                                if (!isFollowing)
                                  BoxShadow(
                                    color: Colors.amberAccent.withOpacity(0.4),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                              ],
                            ),
                            child: isProcessing
                                ? const Center(
                                    child: SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.black,
                                      ),
                                    ),
                                  )
                                : Icon(
                                    isFollowing ? Icons.how_to_reg_rounded : Icons.person_add_alt_1_rounded,
                                    color: isFollowing ? Colors.amberAccent : Colors.black,
                                    size: 22,
                                  ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isFollowing ? t('Following', 'Mengikuti') : t('Follow', 'Ikuti'),
                            style: TextStyle(
                              color: isFollowing ? Colors.amberAccent : Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 14),
        ],

        // 1. Tayangan (Views)
        _buildActionButton(
          icon: Icons.remove_red_eye_rounded,
          iconColor: Colors.white70,
          countText: _formatCompactCount(video.viewsCount),
          onTap: () {},
        ),
        const SizedBox(height: 14),

        // 2. Like
        _buildActionButton(
          icon: isLiked ? Icons.favorite : Icons.favorite_border,
          iconColor: isLiked ? Colors.redAccent : Colors.white,
          countText: _formatCompactCount(video.likesCount),
          onTap: () => _viewModel.toggleLikeCurrentVideo(),
        ),
        const SizedBox(height: 14),

        // 3. Komentar
        _buildActionButton(
          icon: Icons.chat_bubble_outline_rounded,
          iconColor: Colors.white,
          countText: _formatCompactCount(video.commentsCount),
          onTap: () {
            MytubeCommentSheet.show(
              context,
              videoId: video.id,
              currentUserId: _currentUser?.uid ?? '',
              currentUserName: _currentUser?.displayName ?? 'User',
              currentUserAvatar: _currentUser?.photoURL ?? '',
              isCurrentUserAdmin: false,
            );
          },
        ),
        const SizedBox(height: 14),

        // 4. Koleksi / Bookmark
        _buildActionButton(
          icon: isSaved ? Icons.bookmark : Icons.bookmark_border,
          iconColor: isSaved ? Colors.amberAccent : Colors.white,
          countText: _formatCompactCount(video.savesCount),
          onTap: () => _viewModel.toggleSaveCurrentVideo(),
        ),
        const SizedBox(height: 14),

        // 5. Bagikan / Share
        _buildActionButton(
          icon: Icons.share_rounded,
          iconColor: Colors.white,
          countText: _formatCompactCount(video.sharesCount),
          onTap: () async {
            _viewModel.recordShareCurrentVideo();

            final String shareMessage = isIndo
                ? '🎬 Tonton video ini di Majiku!\n${video.title}\n\n🔗 Tonton di sini:\nhttps://app.majiku.net/?v=${video.id}\n(Daftar/masuk akun untuk menonton)'
                : '🎬 Watch this video on Majiku!\n${video.title}\n\n🔗 Watch here:\nhttps://app.majiku.net/?v=${video.id}\n(Sign in/register to watch)';

            await Clipboard.setData(ClipboardData(text: shareMessage));

            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          isIndo
                              ? 'Tautan video berhasil disalin! Silakan bagikan.'
                              : 'Video link copied! Ready to share.',
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: const Color(0xFF2563EB),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          },
        ),
      ],
    );
  }

  String _formatCompactCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return '$count';
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color iconColor,
    required String countText,
    required VoidCallback onTap,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          children: [
            Icon(icon, color: iconColor, size: 26),
            const SizedBox(height: 3),
            Text(
              countText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
//............................................................................//

//No ke-7....................................................................//
//BOTTOM METADATA OVERLAY, FOLLOW ATOMIC & EMPTY/ERROR STATES BILINGUAL       //
  Widget _buildBottomMetadata(VideoMytubeModel video, String Function(String, String) t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            // [FOTO PROFIL CHANNEL]: Pindah rapi ke sebelah kiri nama channel
            CircleAvatar(
              radius: 13,
              backgroundColor: Colors.white24,
              backgroundImage: video.channelAvatarUrl.isNotEmpty
                  ? NetworkImage(video.channelAvatarUrl)
                  : null,
              child: video.channelAvatarUrl.isEmpty
                  ? const Icon(Icons.person, color: Colors.white70, size: 15)
                  : null,
            ),
            const SizedBox(width: 8),

            Flexible(
              child: Text(
                '@${video.channelName}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (video.isVerifiedAdmin) ...[
              const SizedBox(width: 4),
              const Icon(Icons.verified, color: Colors.blueAccent, size: 14),
            ],
          ],
        ),
        const SizedBox(height: 6),

        Text(
          video.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            height: 1.25,
          ),
        ),

        const SizedBox(height: 5),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                video.category,
                style: const TextStyle(color: Colors.amberAccent, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                video.language,
                style: const TextStyle(color: Colors.white70, fontSize: 10),
              ),
            ),
          ],
        ),

        if (video.actionButtonText != null && video.actionButtonText!.isNotEmpty) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              if (video.actionButtonRoute != null) {
                Navigator.of(context).pushNamed(video.actionButtonRoute!);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withOpacity(0.85),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.link, color: Colors.white, size: 13),
                  const SizedBox(width: 5),
                  Text(
                    video.actionButtonText!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEmptyState(String Function(String, String) t) {
    final isFiltered = _viewModel.isFilterActive;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isFiltered ? Icons.filter_alt_off_rounded : Icons.play_circle_outline,
            color: Colors.white38,
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            isFiltered
                ? t('No videos match your filter or search.', 'Tidak ada video yang cocok dengan filter atau pencarian Anda.')
                : (_viewModel.isShortMode
                    ? t('No MyTube Shorts available yet.', 'Belum ada video Short MyTube tersedia.')
                    : t('No MyTube Long videos available yet.', 'Belum ada video Panjang MyTube tersedia.')),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 16),
          if (isFiltered)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amberAccent,
                foregroundColor: Colors.black,
              ),
              icon: const Icon(Icons.refresh),
              label: Text(t('Reset Filter & Search', 'Reset Filter & Pencarian')),
              onPressed: () {
                _searchController.clear();
                _viewModel.clearAllFilters();
              },
            ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String errorText, String Function(String, String) t) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, color: Colors.redAccent, size: 64),
            const SizedBox(height: 16),
            Text(
              t('Failed to Load MyTube Feed', 'Gagal Memuat Feed MyTube'),
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 140),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E24),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white12),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  errorText,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontFamily: 'monospace'),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amberAccent,
                foregroundColor: Colors.black,
              ),
              icon: const Icon(Icons.refresh),
              label: Text(t('Try Again', 'Coba Lagi')),
              onPressed: () => _viewModel.retryFeed(),
            ),
          ],
        ),
      ),
    );
  }
} // <--- PENUTUP RESMI CLASS _MytubeFeedScreenState
//............................................................................//