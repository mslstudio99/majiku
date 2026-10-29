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
import 'package:http/http.dart' as http; // [BARU]: Pembaca File Teks Terjemahan Judul

import '../../../providers/config_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../services/firestore_service.dart';
import '../models/video_mytube_model.dart';
import '../services/firestore_mytube_service.dart';
import '../services/mytube_ad_service.dart'; // [TERPADU]: Orkestrator Iklan MyTube Terpusat
import '../services/user_device_service.dart';
import '../view_model/mytube_feed_view_model.dart';
import 'mytube_comment_sheet.dart';
import 'mytube_home_screen.dart'; // [JANGKAR TERPUSAT]: Akses titleMemoryCache & countryToLanguageCodeMap
//............................................................................//

//No ke-2....................................................................//
//WIDGET DECLARATION & STATE SETUP                                           //
class MytubeFeedScreen extends ConsumerStatefulWidget {
  final String? initialVideoId;
  final String initialVideoType; // Mendukung 'SHORT' atau 'LONG'

  const MytubeFeedScreen({
    super.key,
    this.initialVideoId,
    this.initialVideoType = 'SHORT',
  });

  @override
  ConsumerState<MytubeFeedScreen> createState() => _MytubeFeedScreenState();
}

class _MytubeFeedScreenState extends ConsumerState<MytubeFeedScreen> with WidgetsBindingObserver {
  late final MytubeFeedViewModel _viewModel;
  final FirestoreMytubeService _service = FirestoreMytubeService();
  late final PageController _pageController;
  final TextEditingController _searchController = TextEditingController();

  User? _currentUser;
  bool _isSearchOpen = false;
  bool _isManualFullscreen = false;
  bool _hasJumpedToInitialVideo = false;

  // [SINKRONISASI LAYAR & JUMP TO TOP]: Menyimpan kunci filter terakhir
  String _lastFilterKey = '';

  // [SMART LAZY CACHE RAM]: Menyimpan foto profil saluran di memori
  static final Map<String, String> _channelAvatarCache = {};

  // Daftar 17 Kategori Resmi Terurut A-Z
  static const List<Map<String, String>> _categories = [
    {'en': 'Cartoons & Anime', 'id': 'Kartun & Anime'},
    {'en': 'Comedy & Funny', 'id': 'Lucu'},
    {'en': 'Education & Facts', 'id': 'Edukasi & Fakta'},
    {'en': 'Faith & Religion', 'id': 'Religi'},
    {'en': 'Finance & Investment', 'id': 'Keuangan'},
    {'en': 'Food & Culinary', 'id': 'Kuliner'},
    {'en': 'Health & Wellness', 'id': 'Kesehatan'},
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

  static List<String> get _languages => MytubeFeedViewModel.supportedLanguages;
//............................................................................//

//No ke-3....................................................................//
//LIFECYCLE, ORIENTATION CONTROL, INITIAL VIDEO JUMP & FULLSCREEN TOGGLE     //
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    _pageController = PageController();
    _viewModel = MytubeFeedViewModel(service: _service);
    _viewModel.addListener(_syncWakeLockWithPlayer); 
    _viewModel.addListener(_checkAndJumpToInitialVideo);

    _currentUser = FirebaseAuth.instance.currentUser;
    final uid = _currentUser?.uid ?? '';

    // [INTEGRASI DOMISILI]: Baca lokasi domisili negara dari userProvider saat inisialisasi awal
    final userCountry = ref.read(firestoreUserProvider).value?.country;

    _lastFilterKey = _viewModel.filterKey;

    // [KUNCI INITIAL VIDEO TARGET & TYPE]: Teruskan mode video (SHORT/LONG) dan videoId ke ViewModel
    _viewModel.initFeed(
      uid,
      videoType: widget.initialVideoType.toUpperCase(),
      userCountry: userCountry,
      initialVideoId: widget.initialVideoId,
    );
    _recordFeedVisit();

    // [ORKESTRASI IKLAN TERPUSAT]: Mulai stopwatch 1 menit sesi MyTube jika belum berjalan
    MytubeAdService.instance.startSessionTimerIfNeeded();
  }

  // [HELPER JUMP INITIAL VIDEO]: Presisi melompat ke video sasaran tanpa pernah terlempar balik ke index 0
  void _checkAndJumpToInitialVideo() {
    if (_hasJumpedToInitialVideo || widget.initialVideoId == null) return;
    final list = _viewModel.filteredVideos;
    if (list.isEmpty) return;

    final targetIndex = list.indexWhere((v) => v.id == widget.initialVideoId);
    if (targetIndex != -1) {
      _hasJumpedToInitialVideo = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pageController.hasClients) {
          if (_pageController.page?.round() != targetIndex) {
            _pageController.jumpToPage(targetIndex);
          }
          if (_viewModel.currentIndex != targetIndex) {
            _viewModel.onPageChanged(targetIndex);
          }
        }
      });
    }
  }

  void _syncWakeLockWithPlayer() {
    UserDeviceService.instance.attachPlayer(_viewModel.currentController);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    UserDeviceService.instance.handleAppLifecycle(state);
  }

  void _recordFeedVisit() {
    FirestoreService().logFeatureActivity(
      featureKey: 'mytube',
      subFeatureKey: 'feed',
      eventType: 'visit',
    );
  }

  void _toggleManualFullscreen(bool isLandscapeVideo) {
    if (!isLandscapeVideo) return;

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
    WidgetsBinding.instance.removeObserver(this);
    _viewModel.removeListener(_syncWakeLockWithPlayer);
    _viewModel.removeListener(_checkAndJumpToInitialVideo);
    UserDeviceService.instance.detachPlayer();

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
//MAIN CANVAS & LISTENABLE BUILDER (FONDASI POPSCOPE, AD ORCHESTRATION & PAGE)//
  /// [ADMOB INTERSTITIAL ORCHESTRATOR]: Terintegrasi MytubeAdService
  /// Memeriksa syarat: Kumulatif >= 1 menit + Minimal 1 video sudah disetel
  void _handleVideoPageChangeWithAd(int index, List<VideoMytubeModel> displayList) {
    // 1. Tandai bahwa pengguna sudah menyetel/menonton setidaknya 1 video
    MytubeAdService.instance.recordVideoPlayed();

    // 2. Jalankan evaluasi iklan interstitial saat jeda alami ganti video
    MytubeAdService.instance.showAdIfEligible(
      onBeforeAd: () {
        // [HARD STOP & MUTE SEBELUM IKLAN]: Matikan volume video lama ke 0.0 & pause seketika
        _viewModel.setAdActiveStatus(true);
      },
      onActionProceed: () {
        // [LANJUTKAN VIDEO BARU]: Setelah iklan ditutup (atau jika belum eligible)
        if (mounted) {
          _viewModel.setAdActiveStatus(false);
          _viewModel.onPageChanged(index);
          final videoId = displayList[index].id;
          _viewModel.checkInitialInteractionStatus(videoId);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentLocale = ref.watch(appLanguageProvider);
    final isIndo = currentLocale.languageCode == 'id';
    String t(String en, String id) => isIndo ? id : en;

    // [POPSCOPE HARD STOP LEAK-PROOF]: Memotong seketika seluruh suara video & dubbing saat pengguna menekan tombol kembali
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          _viewModel.hardStopAllPlayback();
        }
      },
      child: Scaffold(
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
            
            // [PROTEKSI SINKRONISASI FILTER PRESISI]:
            // Hanya lompat ke page 0 jika pengguna secara manual mengganti filter di dalam layar,
            // DAN BUKAN saat sesi pembukaan awal video pilihan dari Home (initialVideoId)
            if (_lastFilterKey != _viewModel.filterKey) {
              _lastFilterKey = _viewModel.filterKey;
              if (widget.initialVideoId == null && _hasJumpedToInitialVideo) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && _pageController.hasClients && _pageController.page != 0) {
                    _pageController.jumpToPage(0);
                  }
                });
              }
            }

            // [CADANGAN SINKRONISASI INITIAL JUMP]: Pastikan lompat ke target saat data pertama kali siap
            if (!_hasJumpedToInitialVideo && widget.initialVideoId != null && displayList.isNotEmpty) {
              final targetIdx = displayList.indexWhere((v) => v.id == widget.initialVideoId);
              if (targetIdx != -1) {
                _hasJumpedToInitialVideo = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && _pageController.hasClients) {
                    if (_pageController.page?.round() != targetIdx) {
                      _pageController.jumpToPage(targetIdx);
                    }
                    if (_viewModel.currentIndex != targetIdx) {
                      _viewModel.onPageChanged(targetIdx);
                    }
                  }
                });
              }
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
                            // [MLA DUBBING]: Overlay notifikasi real-time loading dubbing audio
                            if (_viewModel.isDubbingLoading) _buildDubbingLoadingOverlay(t),
                            // [DUAL READY GATE]: Indikator menunggu audio dubbing siap di detik 0
                            if (_viewModel.isWaitingForDubbingAudio) _buildWaitingDubbingOverlay(t),
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
            fontSize: 20.0,               // <-- FONT 18.0 PAS & LEBIH BESAR SESUAI PERMINTAAN
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
//TOP BAR, BOTTOM NAVIGATION & HELPER COMPONENTS (MINIMALIST CLEAN PLAYER)   //
  Widget _buildTopBar(String Function(String, String) t, bool isIndo) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
              onPressed: () {
                _viewModel.hardStopAllPlayback();
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                } else {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => const MytubeHomeScreen(),
                    ),
                  );
                }
              },
            ),
            const SizedBox(width: 2),

            // Sakelar Kapsul Mode Konten SHORT / LONG
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
            // 1. KATALOG BERANDA MYTUBE (LABEL 'SV' & IKON DAFTAR ISI GRID) -> Menuju ke Beranda MyTube
            InkWell(
              onTap: () {
                _viewModel.hardStopAllPlayback();
                // Beralih ke Beranda MyTube (MytubeHomeScreen) tanpa keluar dari MyTube
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) => const MytubeHomeScreen(),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(12),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.grid_view_rounded, color: Colors.white70, size: 24),
                    SizedBox(height: 2),
                    Text(
                      'SV',
                      style: TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),

            // 2. SUBTITLE (CC)
            InkWell(
              onTap: () => _showSubtitleModalSheet(t, isIndo),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _viewModel.isSubtitleActive ? Icons.closed_caption_rounded : Icons.closed_caption_off_rounded,
                      color: _viewModel.isSubtitleActive ? Colors.amberAccent : Colors.white70,
                      size: 24,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _viewModel.isSubtitleActive ? 'CC (${_viewModel.activeSubtitleLangCode!.toUpperCase()})' : 'Subtitle',
                      style: TextStyle(
                        color: _viewModel.isSubtitleActive ? Colors.amberAccent : Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 3. AUDIO DUBBING (DUB)
            InkWell(
              onTap: () => _showAudioModalSheet(t, isIndo),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _viewModel.isDubbingActive ? Icons.record_voice_over_rounded : Icons.voice_over_off_rounded,
                      color: _viewModel.isDubbingActive ? Colors.amberAccent : Colors.white70,
                      size: 24,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _viewModel.isDubbingActive ? 'DUB (${_viewModel.activeAudioLangCode!.toUpperCase()})' : 'DUB',
                      style: TextStyle(
                        color: _viewModel.isDubbingActive ? Colors.amberAccent : Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 4. KOLEKSI (LIBRARY)
            InkWell(
              onTap: () => _showLibraryModalSheet(t, isIndo),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bookmarks_rounded, color: Colors.white70, size: 22),
                    const SizedBox(height: 2),
                    Text(
                      t('Library', 'Koleksi'),
                      style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
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
  Widget _buildSubtitleBox(
    VideoPlayerController controller, {
    required bool isCinema,
    AlignmentGeometry? alignment,
    double fontSize = 20.0,
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
              Flexible(
                child: Text(
                  _viewModel.subtitleLoadingMessage ?? t('Translating...', 'Menerjemahkan...'),
                  style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDubbingLoadingOverlay(String Function(String, String) t) {
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
              Flexible(
                child: Text(
                  _viewModel.dubbingLoadingMessage ?? t('Preparing audio dubbing, wait a minute...', 'Menyiapkan dubbing audio, tunggu sebentar...'),
                  style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWaitingDubbingOverlay(String Function(String, String) t) {
    return Positioned(
      top: 95,
      left: 24,
      right: 24,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E24).withOpacity(0.92),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.amberAccent.withOpacity(0.8), width: 1),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10, spreadRadius: 1),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 15,
                height: 15,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amberAccent),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  t('Waiting audio dubbing...', 'Menyiapkan audio dubbing...'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
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
                Text(
                  t('Tap to unmute', 'Ketuk aktifkan suara'),
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
//............................................................................//

//No ke-5....................................................................//
//MODAL BOTTOM SHEETS (SUBTITLE CC 37 BAHASA, DUBBING MLA & MYTUBE LIBRARY)  //
  // --- A. MODAL PILIH SUBTITLE (CC) 37 BAHASA DUNIA ---
  void _showSubtitleModalSheet(String Function(String, String) t, bool isIndo) {
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
                    final code = MytubeFeedViewModel.getLanguageCode(langName);
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

  // --- B. MODAL PILIH AUDIO DUBBING 37 BAHASA DUNIA ---
  void _showAudioModalSheet(String Function(String, String) t, bool isIndo) {
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
          height: MediaQuery.of(context).size.height * 0.75,
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
                      const Icon(Icons.record_voice_over_rounded, color: Colors.amberAccent, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        t('Audio Language (Dubbing)', 'Bahasa Audio (Dubbing)'),
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  if (_viewModel.isDubbingActive)
                    TextButton(
                      onPressed: () {
                        _viewModel.resetAudioToOriginal();
                        Navigator.of(ctx).pop();
                      },
                      child: Text(
                        t('Original Audio', 'Audio Asli'),
                        style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
              const Divider(color: Colors.white12, height: 18),

              // OPSI 1: AUDIO ASLI BAWAAN VIDEO (ORIGINAL)
              ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                leading: Icon(
                  Icons.audiotrack_rounded,
                  color: !_viewModel.isDubbingActive ? Colors.amberAccent : Colors.white54,
                  size: 20,
                ),
                title: Text(
                  t('Original Video Audio', 'Audio Asli Bawaan Video'),
                  style: TextStyle(
                    color: !_viewModel.isDubbingActive ? Colors.amberAccent : Colors.white,
                    fontWeight: !_viewModel.isDubbingActive ? FontWeight.bold : FontWeight.normal,
                    fontSize: 14,
                  ),
                ),
                trailing: !_viewModel.isDubbingActive
                    ? const Icon(Icons.check_circle_rounded, color: Colors.amberAccent, size: 20)
                    : null,
                onTap: () {
                  Navigator.of(ctx).pop();
                  _viewModel.resetAudioToOriginal();
                },
              ),
              const Divider(color: Colors.white12, height: 8),

              // DAFTAR 37 BAHASA DUBBING DUNIA
              Expanded(
                child: ListView.separated(
                  itemCount: _languages.length,
                  separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
                  itemBuilder: (context, idx) {
                    final langName = _languages[idx];
                    final code = MytubeFeedViewModel.getLanguageCode(langName);
                    final isCurrentActive = _viewModel.activeAudioLangCode == code;

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
                        _viewModel.selectAudioLanguage(langCode: code, langName: langName);
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

    // [JANGKAR HIBRIDA]: Utamakan channelId resmi saluran, fallback ke email/uid untuk 8 video lama
    final String creatorKey = video.channelId.trim().isNotEmpty
        ? video.channelId.trim()
        : (video.uploaderEmail.trim().isNotEmpty
            ? video.uploaderEmail.trim().toLowerCase()
            : video.uploaderId.trim());

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
        // [TOMBOL FOLLOW RESMI]: Menggunakan FutureBuilder (Anti-Assertion Desync ca9/b815 pada Web)
        if (!isSelf && _currentUser != null && creatorKey.isNotEmpty) ...[
          FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('users')
                .doc(_currentUser!.uid)
                .collection('mytube_following')
                .doc(creatorKey)
                .get(),
            builder: (context, snapshot) {
              final initialFollowing = snapshot.hasData && snapshot.data != null && snapshot.data!.exists;

              return StatefulBuilder(
                builder: (context, setBtnState) {
                  bool isFollowing = initialFollowing;
                  bool isProcessing = false;

                  return MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () async {
                        if (isProcessing) return;
                        setBtnState(() => isProcessing = true);

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
                          setBtnState(() {
                            if (success) {
                              isFollowing = !isFollowing;
                            }
                            isProcessing = false;
                          });
                        }

                        if (isFollowing && success) {
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
    // Ambil daftar lokasi lengkap (default Global jika kosong)
    final locations = video.targetLocations.isNotEmpty ? video.targetLocations : const ['Global'];

    // [DUKUNGAN 1-2 KATEGORI KONTEN]: Ekstraksi kategori resmi secara aman dari categories array
    final categories = video.categories.isNotEmpty
        ? video.categories
        : (video.category.trim().isNotEmpty ? [video.category.trim()] : const ['Comedy & Funny']);

    // [RESOLVER BAHASA SASARAN]: Membaca preferensi aktif (DUB -> CC -> Domisili -> UI Locale)
    final currentLocale = ref.watch(appLanguageProvider);
    final isIndo = currentLocale.languageCode == 'id';
    final userCountry = ref.watch(firestoreUserProvider).value?.country;
    final activeLangCode = MytubeHomeScreen.resolveLanguageCode(
      userCountry: userCountry,
      isAppIndo: isIndo,
      preferredDubbing: _viewModel.activeAudioLangCode,
      preferredSubtitle: _viewModel.activeSubtitleLangCode,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            // [FOTO PROFIL CHANNEL CERDAS]: Lazy In-Memory Cache Fallback (0 Polling / Hemat Kuota)
            _buildChannelAvatar(video),
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

        // [JUDUL DINAMIS TERJEMAHAN - MANUT BERANDA]: Mengalir instan 0 ms dari titleMemoryCache
        _buildFeedDynamicTitle(video, activeLangCode),

        const SizedBox(height: 5),
        // [FLEXIBLE WRAP]: Masing-masing Kategori Kotak Mandiri, Bahasa & SELURUH Lokasi Berdampingan
        Wrap(
          spacing: 6,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // 1. KOTAK KATEGORI KONTEN INDIVIDUAL (KOTAK KHUSUS RESMI PER KATEGORI)
            ...categories.map((cat) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  cat,
                  style: const TextStyle(
                    color: Colors.amberAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            }),

            // 2. Bahasa Konten
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

            // 3. SELURUH TARGET LOKASI (Ditampilkan Semua di Samping Bahasa)
            ...locations.map((loc) {
              final isGlob = loc.toLowerCase() == 'global';
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: Colors.lightGreenAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: Colors.lightGreenAccent.withOpacity(0.35),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  isGlob ? '🌐 Global' : '📍 $loc',
                  style: const TextStyle(
                    color: Colors.lightGreenAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            }),
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

  // --- BUILDER JUDUL FEED (MANUT HOME: BEBAS RACE CONDITION / HANYA BACA CACHE & STORAGE) ---
  Widget _buildFeedDynamicTitle(VideoMytubeModel video, String? targetLangCode) {
    if (targetLangCode != null && targetLangCode.isNotEmpty) {
      final memoryKey = '${video.id}_$targetLangCode';

      // 1. Prioritas Utama: Baca RAM Cache Terpusat MytubeHomeScreen (0 ms instan dari Beranda)
      if (MytubeHomeScreen.titleMemoryCache.containsKey(memoryKey)) {
        return Text(
          MytubeHomeScreen.titleMemoryCache[memoryKey]!.toUpperCase(),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            height: 1.25,
          ),
        );
      }

      // 2. Prioritas Kedua: Baca dari URL Storage titles/{langCode}.txt yang sudah tercatat di dokumen video
      final sharedTitleUrl = video.titles?[targetLangCode];
      if (sharedTitleUrl != null && sharedTitleUrl.isNotEmpty) {
        if (MytubeHomeScreen.titleMemoryCache.containsKey(sharedTitleUrl)) {
          return Text(
            MytubeHomeScreen.titleMemoryCache[sharedTitleUrl]!.toUpperCase(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              height: 1.25,
            ),
          );
        }

        // Ambil isi teks satu kali dan simpan ke RAM Cache Terpusat (Tanpa memicu Cloud Function)
        return FutureBuilder<String>(
          future: http.get(Uri.parse(sharedTitleUrl)).then((res) {
            if (res.statusCode == 200 && res.body.trim().isNotEmpty) {
              final upper = res.body.trim().toUpperCase();
              MytubeHomeScreen.titleMemoryCache[memoryKey] = upper;
              MytubeHomeScreen.titleMemoryCache[sharedTitleUrl] = upper;
              return upper;
            }
            return video.title.toUpperCase();
          }).catchError((_) => video.title.toUpperCase()),
          builder: (context, snap) {
            final titleText = (snap.data ?? video.title).toUpperCase();
            return Text(
              titleText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                height: 1.25,
              ),
            );
          },
        );
      }
    }

    // Fallback: Tampilkan judul asli bawaan video dalam huruf kapital (Tanpa memicu Cloud Function)
    return Text(
      video.title.toUpperCase(),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 13,
        fontWeight: FontWeight.bold,
        height: 1.25,
      ),
    );
  }

  // --- HELPER RENDERING FOTO PROFIL SALURAN CERDAS (HEMAT KUOTA & MEMORI) ---
  Widget _buildChannelAvatar(VideoMytubeModel video) {
    // 1. Prioritas Utama: Jika video sudah membawa channelAvatarUrl, gunakan langsung (0 Read Firestore)
    if (video.channelAvatarUrl.trim().isNotEmpty) {
      return _buildAvatarImage(video.channelAvatarUrl.trim());
    }

    final channelKey = video.channelId.trim().isNotEmpty
        ? video.channelId.trim()
        : (video.uploaderEmail.trim().isNotEmpty
            ? video.uploaderEmail.trim().toLowerCase()
            : video.uploaderId.trim());

    if (channelKey.isEmpty) {
      return _buildDefaultAvatarPlaceholder();
    }

    // 2. Prioritas Kedua: Cek apakah foto saluran sudah tersimpan di RAM aplikasi (0 Read Firestore)
    if (_channelAvatarCache.containsKey(channelKey)) {
      final cachedUrl = _channelAvatarCache[channelKey]!;
      if (cachedUrl.isNotEmpty) {
        return _buildAvatarImage(cachedUrl);
      }
      return _buildDefaultAvatarPlaceholder();
    }

    // 3. Fallback Hemat (1x Read saja): Ambil dari dokumen saluran, simpan ke RAM untuk selamanya
    return FutureBuilder(
      future: _service.getCreatorProfile(
        video.uploaderEmail,
        channelId: video.channelId,
        userId: video.uploaderId,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
          final dynamic profile = snapshot.data;
          final String avatarUrl = (profile?.avatarUrl ?? '').toString().trim();
          _channelAvatarCache[channelKey] = avatarUrl;
          if (avatarUrl.isNotEmpty) {
            return _buildAvatarImage(avatarUrl);
          }
        }
        return _buildDefaultAvatarPlaceholder();
      },
    );
  }

  Widget _buildAvatarImage(String url) {
    return ClipOval(
      child: Image.network(
        url,
        width: 26,
        height: 26,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildDefaultAvatarPlaceholder(),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: 26,
            height: 26,
            decoration: const BoxDecoration(
              color: Colors.white12,
              shape: BoxShape.circle,
            ),
          );
        },
      ),
    );
  }

  Widget _buildDefaultAvatarPlaceholder() {
    return Container(
      width: 26,
      height: 26,
      decoration: const BoxDecoration(
        color: Colors.white24,
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.person, color: Colors.white70, size: 15),
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