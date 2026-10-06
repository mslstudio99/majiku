//====================================================================================================//
// NAMA FILE: TIMELINE_REVIEW_VEO_SCREEN.DART                                                         //
// DIREKTORI: lib/screens_veo/timeline_review_veo_screen.dart                                         //
//====================================================================================================//

//No ke-1: IMPOR & PROVIDER GLOBAL....................................................................//
//Sub-judul: Memuat dependensi, tema, model, dan Riverpod Provider....................................//
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';
import '../models_veo/scene_veo.dart';
import '../models_veo/video_project_veo.dart';
import '../services_veo/firestore_veo_service.dart';
import '../view_model_veo/timeline_veo_view_model.dart';
import 'visual_setting_veo_screen.dart';
import '../providers_veo/visual_settings_veo_provider.dart';
import '../providers/user_provider.dart';

final firestoreVeoServiceProvider =
    Provider<FirestoreVeoService>((ref) => FirestoreVeoService());
final selectedSceneVeoProvider =
    StateProvider.autoDispose<SceneVeo?>((ref) => null);
//Akhir Blok 1........................................................................................//


//No ke-2: DEKLARASI KELAS & STATE UTAMA..............................................................//
//Sub-judul: Inisialisasi ConsumerStatefulWidget, variabel kontrol render, dan flag navigasi..........//
class TimelineReviewVeoScreen extends ConsumerStatefulWidget {
  final String projectId;
  const TimelineReviewVeoScreen({super.key, required this.projectId});

  @override
  ConsumerState<TimelineReviewVeoScreen> createState() =>
      _TimelineReviewVeoScreenState();
}

class _TimelineReviewVeoScreenState extends ConsumerState<TimelineReviewVeoScreen> {
  
  VideoPlayerController? _videoController;
  bool _isPlayingSequence = false;
  int _currentSequenceIndex = -1;
  List<SceneVeo> _currentScenes = [];
  List<ProcessedSceneDataVeo> _currentProcessedScenes = [];
  double _currentPlaybackTime = 0.0;
  Timer? _playbackTimer;
  bool _showTitleOverlay = false;
  bool _showDescriptionOverlay = false;
  
  // [STATE KONTROL RENDER]
  bool _isTriggeringRender = false;
  bool _hasAutoTriggeredRender = false; 
  static const int _renderTimeoutDuration = 3600;
  Timer? _uiRefreshTimer;
  
  // Status pop-up panduan render
  bool _hasDismissedRenderPopup = false; 
//Akhir Blok 2........................................................................................//


//No ke-3: FUNGSI LIFECYCLE & TIMER...................................................................//
//Sub-judul: Pengaturan siklus hidup widget dan penanganan timeout render backend.....................//
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    _uiRefreshTimer?.cancel();
    _videoController?.dispose();
    super.dispose();
  }

  void _startUiRefreshTimer() {
    if (_uiRefreshTimer != null && _uiRefreshTimer!.isActive) {
      return;
    }
    _uiRefreshTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {});
      } else {
        timer.cancel();
      }
    });
  }

  void _cancelUiRefreshTimer() {
    if (_uiRefreshTimer != null && _uiRefreshTimer!.isActive) {
      _uiRefreshTimer!.cancel();
    }
  }

  Future<void> _handleRenderTimeout() async {
    _cancelUiRefreshTimer();
    try {
      final firestore = ref.read(firestoreVeoServiceProvider);
      final projectDoc = await firestore.getProject(widget.projectId);
      final currentStatus = projectDoc?['status'];

      if (currentStatus == 'RENDER_START' || currentStatus == 'RENDERING') {
        logger.error(
            "Render timeout! Project ${widget.projectId} stuck in $currentStatus for > 60 minutes.");
        await firestore.updateProject(
          widget.projectId,
          {
            'status': 'ERROR_RENDER',
            'errorDetail': 'Render process timed out after 60 minutes.',
            'renderStartedAt': FieldValue.delete(),
          },
        );
      } else {
        logger.error(
            "[DEBUG] Timeout check skipped — current status is $currentStatus.");
      }
    } catch (e) {
      logger.error("Failed to set ERROR_RENDER status after timeout: $e");
    }
  }
//Akhir Blok 3........................................................................................//


//No ke-4: FUNGSI PLAYER VIDEO & TIMELINE CONTROL.....................................................//
//Sub-judul: Logika pemutaran, jeda, dan navigasi otomatis perpindahan video scene Veo................//
  void _updatePlaybackTime(double time) {
    if (!mounted) return;
    if (time < _currentPlaybackTime && (_currentPlaybackTime - time).abs() > 0.1) {
      if (_playbackTimer?.isActive ?? false) return;
    }
    _currentPlaybackTime = time;
    _updateOverlayVisibility();
  }

  void _startPlaybackTimer() {
    _playbackTimer?.cancel();
    const tickDuration = Duration(milliseconds: 50);

    _playbackTimer = Timer.periodic(tickDuration, (timer) {
      if (!mounted || !_isPlayingSequence) {
        timer.cancel();
        return;
      }
      final newTime =
          _currentPlaybackTime + (tickDuration.inMilliseconds / 1000.0);
      _updatePlaybackTime(newTime);
    });
  }

  void _startOrResumeSequencePlayback() async {
    if (_currentSequenceIndex == -1) {
      _updatePlaybackTime(0.0);
    }
    if (_currentScenes.isEmpty) {
      logger.warn("Cannot start sequence: No scenes loaded.");
      return;
    }
    final timelineDataAsync =
        ref.read(processedTimelineVeoProvider(widget.projectId));
    final timelineData = timelineDataAsync.asData?.value;
    if (timelineData == null || timelineData.isCalculating) {
      logger.warn(
          "Sequence start requested, but timeline data is not ready or is calculating.");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(timelineData == null
              ? 'Timeline data not loaded yet.'
              : 'Calculating... Please wait.'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }
    if (!mounted) return;
    if (_currentSequenceIndex == -1) {
      _stopSequencePlayback(resetIndex: true);
      ref.read(selectedSceneVeoProvider.notifier).state = null;
      setState(() {
        _isPlayingSequence = true;
      });
      _startPlaybackTimer();
      if (_currentScenes.isNotEmpty) {
        _initializeAndPlayVideo(0);
      } else {
        logger.warn("No scenes available. Stopping.");
        _stopSequencePlayback();
      }
    } else if (!_isPlayingSequence && _videoController != null) {
      _videoController!.play();
      setState(() {
        _isPlayingSequence = true;
      });
      _startPlaybackTimer();
      logger.info("Resuming sequence at scene $_currentSequenceIndex.");
    }
  }

  void _pauseSequencePlayback() {
    if (!_isPlayingSequence) return;
    _playbackTimer?.cancel();
    _videoController?.pause();
    logger.info("Pausing sequence at scene $_currentSequenceIndex.");
    setState(() {
      _isPlayingSequence = false;
    });
  }

  void _stopSequencePlayback({bool resetIndex = true}) {
    _playbackTimer?.cancel();
    _updatePlaybackTime(0.0);
    _videoController?.pause();
    _videoController?.dispose();
    _videoController = null;
    if (mounted) {
      setState(() {
        _isPlayingSequence = false;
        if (resetIndex) {
          _currentSequenceIndex = -1;
        }
      });
      if (resetIndex) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ref.read(selectedSceneVeoProvider.notifier).state = null;
          }
        });
      }
    } else {
      _isPlayingSequence = false;
      if (resetIndex) {
        _currentSequenceIndex = -1;
      }
    }
  }

  void _replaySequence() {
    logger.info("Replaying sequence from beginning.");
    _stopSequencePlayback(resetIndex: true);
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _startOrResumeSequencePlayback();
      }
    });
  }

  void _videoPlaybackListener() {
    if (!mounted ||
        _videoController == null ||
        !_videoController!.value.isInitialized) {
      return;
    }
    final value = _videoController!.value;
    if (value.position >= value.duration &&
        !value.isPlaying &&
        value.isCompleted &&
        !value.hasError) {
      if (!_isPlayingSequence) return;
      final completedSceneId = sceneIdFromIndex(_currentSequenceIndex);
      logger.info("Video for scene $completedSceneId finished.");
      _videoController?.removeListener(_videoPlaybackListener);
      if (_currentSequenceIndex < _currentProcessedScenes.length) {
        final processedScene = _currentProcessedScenes[_currentSequenceIndex];
        _updatePlaybackTime(processedScene.absoluteEndTime);
      }
      final nextIndex = _currentSequenceIndex + 1;
      if (nextIndex < _currentScenes.length) {
        _initializeAndPlayVideo(nextIndex);
      } else {
        logger.info("Sequence finished playing all videos.");
        _stopSequencePlayback();
      }
    }
  }

  Future<void> _initializeAndPlayVideo(int sceneIndex) async {
    if (!_isPlayingSequence ||
        sceneIndex < 0 ||
        sceneIndex >= _currentScenes.length) {
      logger.warn("Invalid state for _initializeAndPlayVideo.");
      _stopSequencePlayback();
      return;
    }
    await _videoController?.dispose();
    _videoController = null;
    final scene = _currentScenes[sceneIndex];
    final processedScene = _currentProcessedScenes[sceneIndex];
    final videoUrl = scene.videoUrl;
    if (!mounted) return;
    ref.read(selectedSceneVeoProvider.notifier).state = scene;
    if (videoUrl.isEmpty) {
      logger.warn("Scene $sceneIndex has no video URL, skipping after delay.");
      _handlePlaybackErrorOrSkip(sceneIndex);
      return;
    }
    logger.info("Playing sequence at scene index $sceneIndex (ID: ${scene.id})");
    try {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      await _videoController!.initialize();
      if (!mounted) {
        _videoController?.dispose();
        return;
      }
      _videoController!.addListener(_videoPlaybackListener);
      _updatePlaybackTime(processedScene.absoluteStartTime);
      _videoController!.play();
      setState(() {
        _currentSequenceIndex = sceneIndex;
      });
      _updateOverlayVisibility();
    } catch (e) {
      logger.error(
          "Error initializing video for scene $sceneIndex (URL: $videoUrl): $e");
      if (mounted) {
        _handlePlaybackErrorOrSkip(sceneIndex);
      }
    }
  }

  void _handlePlaybackErrorOrSkip(int currentSceneIndex) {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted &&
          _isPlayingSequence &&
          _currentSequenceIndex == currentSceneIndex) {
        if (currentSceneIndex < _currentProcessedScenes.length) {
          final processedScene = _currentProcessedScenes[currentSceneIndex];
          _updatePlaybackTime(processedScene.absoluteEndTime);
        }
        final nextIndex = _currentSequenceIndex + 1;
        if (nextIndex < _currentScenes.length) {
          _initializeAndPlayVideo(nextIndex);
        } else {
          logger.info("Sequence finished after skipping/error on last scene.");
          _stopSequencePlayback();
        }
      }
    });
  }

  // --- [SUNTIKAN FITUR PLAY/PAUSE INDIVIDUAL FOOTAGE] ---
  void _togglePlaySingleVideo(int sceneIndex) {
    if (_currentSequenceIndex == sceneIndex &&
        _videoController != null &&
        _videoController!.value.isInitialized) {
      if (_videoController!.value.isPlaying) {
        _videoController!.pause();
        _playbackTimer?.cancel();
        setState(() {
          _isPlayingSequence = false;
        });
      } else {
        _videoController!.play();
        setState(() {
          _isPlayingSequence = false;
        });
      }
      return;
    }
    _playSingleVideo(sceneIndex);
  }

  Future<void> _playSingleVideo(int sceneIndex) async {
    _stopSequencePlayback(resetIndex: false);
    
    setState(() {
      _isPlayingSequence = false;
      _currentSequenceIndex = sceneIndex;
    });
    
    await _videoController?.dispose();
    _videoController = null;
    
    if (!mounted) return;
    final scene = _currentScenes[sceneIndex];
    ref.read(selectedSceneVeoProvider.notifier).state = scene;
    
    final videoUrl = scene.videoUrl;
    if (videoUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Video belum tersedia untuk diputar.')),
      );
      return;
    }
    
    try {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      await _videoController!.initialize();
      if (!mounted) {
        _videoController?.dispose();
        return;
      }
      _videoController!.setLooping(true); // Looping per-segmen jika di play individual
      _videoController!.play();
      setState(() {});
    } catch (e) {
      logger.error("Error playing single video for scene $sceneIndex: $e");
    }
  }
//Akhir Blok 4........................................................................................//


//No ke-5: WIDGET BANTUAN & UTILITAS..................................................................//
//Sub-judul: Overlay Rendering Elegan Vmotion, Formatting Waktu, dan Kalkulasi Layout.................//
  String _formatDuration(int totalSeconds) {
    final secondsClamped = totalSeconds.clamp(0, _renderTimeoutDuration);
    final duration = Duration(seconds: secondsClamped);
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  void _updateOverlayVisibility() {
    if (!mounted) return;
    final settings = ref.read(visualSettingsVeoProvider(widget.projectId));
    bool needsSetState = false;

    final titleStartTime = settings.titleSettings.startTime;
    final titleEndTime = titleStartTime + settings.titleSettings.duration;
    final bool shouldShowTitle = _isPlayingSequence &&
        settings.titleSettings.text.isNotEmpty &&
        _currentPlaybackTime >= titleStartTime &&
        _currentPlaybackTime < titleEndTime;

    if (_showTitleOverlay != shouldShowTitle) {
      _showTitleOverlay = shouldShowTitle;
      needsSetState = true;
    }

    final descStartTime = settings.descriptionSettings.startTime;
    final descEndTime = descStartTime + settings.descriptionSettings.duration;
    final bool shouldShowDescription = _isPlayingSequence &&
        settings.descriptionSettings.text.isNotEmpty &&
        _currentPlaybackTime >= descStartTime &&
        _currentPlaybackTime < descEndTime;

    if (_showDescriptionOverlay != shouldShowDescription) {
      _showDescriptionOverlay = shouldShowDescription;
      needsSetState = true;
    }

    if (needsSetState) {
      setState(() {});
    }
  }

  String? sceneIdFromIndex(int sceneIndex) {
    if (sceneIndex >= 0 && sceneIndex < _currentScenes.length) {
      return _currentScenes[sceneIndex].id;
    }
    return null;
  }

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      logger.error('Could not launch $urlString');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open download link: $urlString'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  double _calculateAspectRatio(String? ratioString) {
    if (ratioString == null || ratioString.isEmpty) {
      return 16 / 9;
    }
    final parts = ratioString.split(':');
    if (parts.length == 2) {
      final double? width = double.tryParse(parts[0]);
      final double? height = double.tryParse(parts[1]);
      if (width != null && height != null && height != 0) {
        return width / height;
      }
    }
    logger.warn(
        "Invalid aspectRatio string '$ratioString', falling back to 16:9.");
    return 16 / 9;
  }

  Widget _buildVideoDisplay({Key? key}) {
    // [MODIFIKASI] Agar video player tetap tampil meski play secara individual (_isPlayingSequence false)
    if (_videoController != null && _videoController!.value.isInitialized) {
      return VideoPlayer(_videoController!);
    }
    return Tooltip(
      key: key,
      message: 'Video not playing. No thumbnail available.',
      child: const Icon(Icons.video_camera_back_outlined,
          color: Colors.white54, size: 60),
    );
  }

  Widget _buildRenderingOverlay(int secondsRemaining, bool hasValidStartTime) {
    return Positioned.fill(
      child: AbsorbPointer(
        child: Container(
          color: Colors.black.withOpacity(0.7),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.grey[900], 
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black54, 
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  )
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: Colors.blueAccent), 
                  const SizedBox(height: 16),
                  const Text(
                    "Rendering in minutes... You may safely leave this page",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white, 
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (hasValidStartTime)
                    Text(
                      "Auto Cancel in: ${_formatDuration(secondsRemaining)}",
                      style: const TextStyle(fontSize: 14, color: Colors.white70), 
                    )
                  else
                    const Text(
                      "Menunggu respons backend...",
                      style: TextStyle(fontSize: 14, color: Colors.white70), 
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
//Akhir Blok 5........................................................................................//


//====================================================================================================//
// NAMA FILE: TIMELINE_REVIEW_VEO_SCREEN.DART                                                         //
// DIREKTORI: lib/screens_veo/timeline_review_veo_screen.dart                                         //
//====================================================================================================//

//No ke-6: WIDGET UTAMA (METHOD BUILD)................................................................//
//Sub-judul: Membangun struktur UI, Smart Controller Auto-Render, dan List Scene Timeline.............//
  @override
  Widget build(BuildContext context) {
    final projectAsyncValue =
        ref.watch(projectVeoStreamProvider(widget.projectId));
    final processedTimelineAsync =
        ref.watch(processedTimelineVeoProvider(widget.projectId));
    final visualSettings =
        ref.watch(visualSettingsVeoProvider(widget.projectId));

    final projectData = projectAsyncValue.asData?.value;
    final bool isCalculating =
        processedTimelineAsync.asData?.value?.isCalculating ?? true;
        
    // [GATEKEEPER VALIDASI MUTLAK] - Hanya mengecek Video URL untuk VEO
    final bool areAllScenesValid = processedTimelineAsync.maybeWhen(
      data: (timeline) {
        if (timeline.scenes.isEmpty) return false; 
        
        return timeline.scenes.every((s) {
          final scene = s.originalScene;
          final hasValidVideo = scene.videoUrl.isNotEmpty;
          final hasNoErrors = scene.status == null || !scene.status!.startsWith('ERROR');
          final isNotGenerating = scene.status != 'PENDING_REFINEMENT' &&
                                  scene.status != 'QUEUED_FOR_REFINE' &&
                                  scene.status != 'IS_REFINING' &&
                                  scene.status != 'QUEUED_FOR_VIDEO' &&
                                  scene.status != 'GENERATING_VIDEO';
          return hasValidVideo && hasNoErrors && isNotGenerating;
        });
      },
      orElse: () => false,
    );

    // [DETEKSI RENDER SUKSES UNTUK MEMBLOKIR TOMBOL PLAY/RENDER]
    final bool isRenderSuccessGlobal = projectData != null &&
        projectData.status == 'RENDER_COMPLETED' &&
        projectData.finalVideoUrl != null &&
        projectData.finalVideoUrl!.isNotEmpty;

    // Jika render sudah sukses, matikan Play/Replay agar fokus pada Download
    final bool canPlayOrReplay = projectData != null && !isCalculating && areAllScenesValid && !isRenderSuccessGlobal;
    final double aspectRatioValue = _calculateAspectRatio(projectData?.aspectRatio);
    const double previewScaleFactor = 0.2315;

    // [MODIFIKASI OUTLINE EFFECT & FONT WEIGHT]
    TextStyle _getTextStyle(double baseFontSize, Color color, {FontWeight weight = FontWeight.normal}) {
      double multiplier = 1.0;
      final double actualRenderFontSize = baseFontSize * multiplier;
      final double previewFontSize = actualRenderFontSize * previewScaleFactor;

      return TextStyle(
        fontSize: previewFontSize,
        color: color,
        fontWeight: weight,
        shadows: const [
          Shadow(blurRadius: 1.5, color: Colors.black, offset: Offset( 1.5,  1.5)),
          Shadow(blurRadius: 1.5, color: Colors.black, offset: Offset(-1.5, -1.5)),
          Shadow(blurRadius: 1.5, color: Colors.black, offset: Offset( 1.5, -1.5)),
          Shadow(blurRadius: 1.5, color: Colors.black, offset: Offset(-1.5,  1.5)),
        ],
      );
    }

    return Theme(
      data: AppTheme.darkTheme,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Review Project (Veo)'),
          actions: [
            IconButton(
              icon: const Icon(Icons.tune),
              tooltip: 'Visual Settings',
              onPressed: () {
                _stopSequencePlayback();
                _cancelUiRefreshTimer();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        VisualSettingVeoScreen(projectId: widget.projectId),
                  ),
                );
              },
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: projectAsyncValue.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) =>
              Center(child: Text('Error loading project: $error')),
          data: (project) {
            if (project == null) {
              return const Center(
                child: Text(
                  "Error: Proyek tidak ditemukan atau gagal dimuat.",
                  style: TextStyle(color: Colors.red),
                ),
              );
            }

            final bool isRenderComplete = isRenderSuccessGlobal;
            final String? finalVideoUrl = project.finalVideoUrl;
            
            // [SINKRONISASI UI]: Menampilkan Overlay MURNI membaca status dari Backend
            final bool isProjectRendering = !isRenderComplete && (
                project.status == 'RENDER_READY' || 
                project.status == 'RENDER_START' ||
                project.status == 'RENDERING');

            final bool canRender = areAllScenesValid && !isRenderComplete && !isProjectRendering;
            
            bool hasValidStartTime = false;
            int secondsRemainingForOverlay = _renderTimeoutDuration;
            
            if (isProjectRendering) {
              final Timestamp? startTime = project.renderStartedAt;
              if (startTime != null) {
                hasValidStartTime = true;
                final int nowSeconds = Timestamp.now().seconds;
                final int startSeconds = startTime.seconds;
                final int elapsedSeconds = nowSeconds - startSeconds;
                secondsRemainingForOverlay =
                    (_renderTimeoutDuration - elapsedSeconds);
                if (secondsRemainingForOverlay <= 0) {
                  _cancelUiRefreshTimer();
                  WidgetsBinding.instance
                      .addPostFrameCallback((_) => _handleRenderTimeout());
                } else {
                  _startUiRefreshTimer();
                }
              } else {
                _cancelUiRefreshTimer();
              }
            } else {
              _cancelUiRefreshTimer();
            }
            
            return Stack(
              children: [
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Text(
                        visualSettings.titleSettings.text,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(color: Colors.white),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8.0, horizontal: 16.0),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 250),
                          child: AspectRatio(
                            aspectRatio: aspectRatioValue,
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.grey.shade400,
                                  width: 2.0,
                                ),
                                color: Colors.black87,
                              ),
                              child: ClipRRect(
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    _buildVideoDisplay(
                                      key: ValueKey<String?>(_videoController
                                              ?.dataSource ??
                                          'no_video'),
                                    ),
                                    AnimatedOpacity(
                                      key: ValueKey(
                                          'title_${_showTitleOverlay}_${visualSettings.titleSettings.text.hashCode}'),
                                      opacity: _showTitleOverlay ? 1.0 : 0.0,
                                      duration:
                                          const Duration(milliseconds: 300),
                                      child: Visibility(
                                        visible: _showTitleOverlay,
                                        maintainState: false,
                                        maintainAnimation: false,
                                        child: Align(
                                          alignment: Alignment(
                                              0.0,
                                              visualSettings.titleSettings
                                                  .verticalAlignment),
                                          child: FractionallySizedBox(
                                            widthFactor: visualSettings
                                                .titleSettings
                                                .textBlockWidthFactor,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 6),
                                              child: Text(
                                                visualSettings
                                                    .titleSettings.text,
                                                style: _getTextStyle(
                                                  visualSettings.titleSettings
                                                      .baseFontSize,
                                                  visualSettings
                                                      .titleSettings.color,
                                                  weight: FontWeight.bold,
                                                ),
                                                textAlign: TextAlign.center,
                                                maxLines: visualSettings
                                                    .titleSettings.maxLines,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    AnimatedOpacity(
                                      key: ValueKey(
                                          'desc_${_showDescriptionOverlay}_${visualSettings.descriptionSettings.text.hashCode}'),
                                      opacity:
                                          _showDescriptionOverlay ? 1.0 : 0.0,
                                      duration:
                                          const Duration(milliseconds: 300),
                                      child: Visibility(
                                        visible: _showDescriptionOverlay,
                                        maintainState: false,
                                        maintainAnimation: false,
                                        child: Align(
                                          alignment: Alignment(
                                              0.0,
                                              visualSettings.descriptionSettings
                                                  .verticalAlignment),
                                          child: FractionallySizedBox(
                                            widthFactor: visualSettings
                                                .descriptionSettings
                                                .textBlockWidthFactor,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 6),
                                              child: Text(
                                                visualSettings
                                                    .descriptionSettings.text,
                                                style: _getTextStyle(
                                                  visualSettings
                                                      .descriptionSettings
                                                      .baseFontSize,
                                                  visualSettings
                                                      .descriptionSettings
                                                      .color,
                                                  weight: FontWeight.normal,
                                                ),
                                                textAlign: TextAlign.center,
                                                maxLines: visualSettings
                                                    .descriptionSettings
                                                    .maxLines,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    if (isRenderComplete &&
                        finalVideoUrl != null &&
                        finalVideoUrl.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 12.0, horizontal: 16.0),
                        child: ElevatedButton.icon(
                          onPressed: () => _launchURL(finalVideoUrl),
                          icon: const Icon(Icons.download_for_offline),
                          label: const Text('DOWNLOAD FINAL VIDEO'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            textStyle: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),

                    const Divider(height: 1, thickness: 1),

                    Expanded(
                      child: processedTimelineAsync.when(
                        loading: () => const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 12),
                              Text("Loading Timeline..."),
                            ],
                          ),
                        ),
                        error: (error, stack) => Center(
                            child: Text('Error loading timeline data: $error')),
                        data: (timelineData) {
                          _currentScenes = timelineData.scenes
                              .map((e) => e.originalScene)
                              .toList();
                          _currentProcessedScenes = timelineData.scenes;
                          final scenes = _currentScenes;

                          if (scenes.isEmpty) {
                            if (processedTimelineAsync.isLoading) {
                              return const Center(
                                  child: Text("Loading Timeline..."));
                            }
                            if (project.status == 'PROCESSING_SCENE' ||
                                project.status == 'PROCESSING_REFINEMENT') {
                              return const Center(
                                  child: Text("Generating scenes..."));
                            }
                            return const Center(
                                child: Text("No scenes found for this project."));
                          }
                          
                          return Column(
                            children: [
                              Expanded(
                                child: CustomScrollView(
                                  slivers: [
                                    SliverList(
                                      delegate: SliverChildBuilderDelegate(
                                        (context, index) {
                                          final sceneIndex = index;
                                          final scene = scenes[sceneIndex];
                                          final isCurrentlyPlayingInSequence =
                                              _isPlayingSequence &&
                                                  _currentSequenceIndex == sceneIndex;
                                          final bool isSelectedManually = ref
                                                  .watch(selectedSceneVeoProvider)
                                                  ?.id ==
                                              scene.id &&
                                              !_isPlayingSequence;

                                          final bool isSceneProcessing =
                                              scene.status == 'QUEUED_FOR_REFINE' ||
                                                  scene.status == 'IS_REFINING' ||
                                                  scene.status == 'QUEUED_FOR_VIDEO' ||
                                                  scene.status == 'GENERATING_VIDEO' ||
                                                  scene.status == 'PENDING_REFINEMENT' ||
                                                  false;

                                          final bool isError = (scene.status ?? '').startsWith('ERROR');
                                          final bool isThisScenePlaying = _currentSequenceIndex == sceneIndex &&
                                              _videoController != null &&
                                              _videoController!.value.isInitialized &&
                                              _videoController!.value.isPlaying;

                                          return Card(
                                            margin: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 4),
                                            color: isCurrentlyPlayingInSequence
                                                ? Colors.lightBlue[50]
                                                : (isSelectedManually
                                                    ? Colors.grey[200]
                                                    : null),
                                            elevation: isCurrentlyPlayingInSequence
                                                ? 4
                                                : (isSelectedManually ? 2 : 1),
                                            child: InkWell(
                                              onTap: () {
                                                if (_isPlayingSequence) {
                                                  _stopSequencePlayback(
                                                      resetIndex: false);
                                                }
                                                ref
                                                    .read(selectedSceneVeoProvider
                                                        .notifier)
                                                    .state = scene;
                                              },
                                              child: Padding(
                                                padding: const EdgeInsets.all(8.0),
                                                child: Row(
                                                  children: [
                                                    Container(
                                                      width: 32,
                                                      alignment: Alignment.centerLeft,
                                                      child: Text(
                                                        "${index + 1}.",
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .titleSmall
                                                            ?.copyWith(
                                                              color: Theme.of(context)
                                                                  .colorScheme
                                                                  .onSurface
                                                                  .withOpacity(0.6),
                                                              fontWeight: FontWeight.bold,
                                                            ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 4),

                                                    Container(
                                                      width: 80,
                                                      height: 60,
                                                      decoration: BoxDecoration(
                                                        color: Colors.grey[300],
                                                        borderRadius:
                                                            BorderRadius.circular(8),
                                                        border:
                                                            isCurrentlyPlayingInSequence
                                                                ? Border.all(
                                                                    color: Colors
                                                                        .blueAccent,
                                                                    width: 2)
                                                                : (isSelectedManually
                                                                    ? Border.all(
                                                                        color: Colors
                                                                            .grey,
                                                                        width: 1)
                                                                    : null),
                                                      ),
                                                      child: isSceneProcessing
                                                          ? const Center(
                                                              child: SizedBox(
                                                                width: 24,
                                                                height: 24,
                                                                child:
                                                                    CircularProgressIndicator(
                                                                        strokeWidth:
                                                                            3.0),
                                                              ),
                                                            )
                                                          : Stack(
                                                              alignment: Alignment.center,
                                                              children: [
                                                                Positioned.fill(
                                                                  child: _VideoThumbnailItem(
                                                                      videoUrl: scene.videoUrl),
                                                                ),
                                                                if (scene.videoUrl.isNotEmpty)
                                                                  Material(
                                                                    color: Colors.transparent,
                                                                    child: InkWell(
                                                                      borderRadius: BorderRadius.circular(20),
                                                                      onTap: () => _togglePlaySingleVideo(sceneIndex),
                                                                      child: Container(
                                                                        padding: const EdgeInsets.all(4),
                                                                        decoration: const BoxDecoration(
                                                                          color: Colors.black54,
                                                                          shape: BoxShape.circle,
                                                                        ),
                                                                        child: Icon(
                                                                          isThisScenePlaying
                                                                              ? Icons.pause
                                                                              : Icons.play_arrow,
                                                                          color: Colors.white,
                                                                          size: 22,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ),
                                                              ],
                                                            ),
                                                    ),
                                                    const SizedBox(width: 12),

                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment.start,
                                                        children: [
                                                          Text(
                                                            scene.segmentText ?? "",
                                                            style: const TextStyle(
                                                                fontSize: 14,
                                                                fontWeight:
                                                                    FontWeight.w500),
                                                            maxLines: 2,
                                                            overflow:
                                                                TextOverflow.ellipsis,
                                                          ),
                                                          const SizedBox(height: 4),
                                                          if (scene.errorDetail !=
                                                                  null &&
                                                              scene.errorDetail!
                                                                  .isNotEmpty)
                                                            Padding(
                                                              padding: const EdgeInsets
                                                                  .only(top: 2.0),
                                                              child: Tooltip(
                                                                message:
                                                                    scene.errorDetail!,
                                                                child: Text(
                                                                  scene.errorDetail!,
                                                                  style: TextStyle(
                                                                      fontSize: 10,
                                                                      color: Colors
                                                                          .red[700]),
                                                                  maxLines: 1,
                                                                  overflow: TextOverflow
                                                                      .ellipsis,
                                                                ),
                                                              ),
                                                            ),
                                                        ],
                                                      ),
                                                    ),

                                                    if (isError)
                                                      IconButton(
                                                        icon: Icon(Icons.edit, 
                                                            color: Colors.orange[700]),
                                                        tooltip: 'Edit Prompt & Retry',
                                                        onPressed: () {
                                                          final TextEditingController _promptController = TextEditingController(
                                                            text: scene.refinedPrompt ?? scene.rawPrompt ?? ""
                                                          );

                                                          showDialog(
                                                            context: context,
                                                            builder: (ctx) => AlertDialog(
                                                              backgroundColor: Theme.of(context).cardColor,
                                                              title: Text('Edit Prompt (Scene ${index + 1})'),
                                                              content: Column(
                                                                mainAxisSize: MainAxisSize.min,
                                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                                children: [
                                                                   Text(
                                                                    'Generation failed. You can manually edit the prompt below to fix policy issues or improve quality.\n',
                                                                    style: Theme.of(context).textTheme.bodyMedium
                                                                   ),
                                                                   TextField(
                                                                     controller: _promptController,
                                                                     maxLines: 5,
                                                                     decoration: const InputDecoration(
                                                                       border: OutlineInputBorder(),
                                                                       hintText: "Enter revised prompt here...",
                                                                       labelText: "Video Prompt",
                                                                     ),
                                                                   ),
                                                                   const SizedBox(height: 8),
                                                                   Text(
                                                                    'Last Error: ${scene.errorDetail ?? "Unknown"}',
                                                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.red),
                                                                   ),
                                                                ],
                                                              ),
                                                              actions: [
                                                                TextButton(
                                                                  child: const Text('Cancel'),
                                                                  onPressed: () => Navigator.of(ctx).pop(),
                                                                ),
                                                                FilledButton(
                                                                  style: FilledButton.styleFrom(
                                                                    backgroundColor: Colors.blue.shade700,
                                                                  ),
                                                                  child: const Text('Save & Regenerate'),
                                                                  onPressed: () {
                                                                    final newPrompt = _promptController.text;
                                                                    if (newPrompt.trim().isEmpty) {
                                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                                        const SnackBar(content: Text("Prompt cannot be empty!"))
                                                                      );
                                                                      return;
                                                                    }

                                                                    ref.read(firestoreVeoServiceProvider)
                                                                       .updateScenePromptAndRegenerate(
                                                                          widget.projectId,
                                                                          scene.id,
                                                                          newPrompt 
                                                                       );
                                                                    Navigator.of(ctx).pop();
                                                                  },
                                                                ),
                                                              ],
                                                            ),
                                                          );
                                                        },
                                                      ),
                                                    
                                                    const SizedBox(width: 4),
                                                    IconButton(
                                                      icon: const Icon(Icons.download, 
                                                          color: Colors.blueAccent, size: 20),
                                                      tooltip: 'Download Video Scene ${index + 1}',
                                                      onPressed: () {
                                                        if (scene.videoUrl.isNotEmpty) {
                                                          _launchURL(scene.videoUrl);
                                                        } else {
                                                          ScaffoldMessenger.of(context).showSnackBar(
                                                            const SnackBar(content: Text('Video belum tersedia'))
                                                          );
                                                        }
                                                      },
                                                    ),
                                                    IconButton(
                                                      icon: const Icon(Icons.flag_outlined, 
                                                        color: Colors.redAccent, 
                                                        size: 20
                                                      ),
                                                      tooltip: 'Lapor Konten Scene ${index + 1}',
                                                      onPressed: () => _showSceneReportDialog(scene, index),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                        childCount: scenes.length,
                                      ),
                                    ),

                                    if (project.identifiedCharacters.isNotEmpty) ...[
                                      SliverToBoxAdapter(
                                        child: Padding(
                                          padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 24.0, bottom: 8.0),
                                          child: Text(
                                            "Image character:",
                                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),

                                      SliverList(
                                        delegate: SliverChildBuilderDelegate(
                                          (context, index) {
                                            final charMap = project.identifiedCharacters[index];
                                            final String charName = charMap['name'] as String? ?? "Character ${index + 1}";
                                            final String? imageUrl = (charMap['imageUri'] as String?) ??
                                                (charMap['imageUrl'] as String?) ??
                                                (charMap['gcsUri'] as String?);

                                            if (imageUrl == null || imageUrl.isEmpty) {
                                              return const SizedBox.shrink();
                                            }

                                            return Card(
                                              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              elevation: 1,
                                              child: Padding(
                                                padding: const EdgeInsets.all(8.0),
                                                child: Row(
                                                  children: [
                                                    Container(
                                                      width: 32,
                                                      alignment: Alignment.centerLeft,
                                                      child: Text(
                                                        "${index + 1}.",
                                                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Container(
                                                      width: 80,
                                                      height: 60,
                                                      decoration: BoxDecoration(
                                                        color: Colors.grey[300],
                                                        borderRadius: BorderRadius.circular(8),
                                                        image: DecorationImage(
                                                          image: NetworkImage(imageUrl),
                                                          fit: BoxFit.cover,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: Text(
                                                        charName,
                                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                                        maxLines: 2,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                    IconButton(
                                                      icon: const Icon(Icons.download, color: Colors.blueAccent, size: 20),
                                                      tooltip: 'Download Image $charName',
                                                      onPressed: () => _launchURL(imageUrl),
                                                    ),
                                                    IconButton(
                                                      icon: const Icon(Icons.flag_outlined, color: Colors.redAccent, size: 20),
                                                      tooltip: 'Lapor Image $charName',
                                                      onPressed: () => _showCharacterReportDialog(charName, imageUrl, index),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                          childCount: project.identifiedCharacters.length,
                                        ),
                                      ),
                                    ],
                                    const SliverToBoxAdapter(
                                      child: SizedBox(height: 16),
                                    ),
                                  ],
                                ),
                              ),

                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8.0, vertical: 12.0),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: !canPlayOrReplay
                                          ? null
                                          : () {
                                              if (_isPlayingSequence) {
                                                _pauseSequencePlayback();
                                              } else {
                                                _startOrResumeSequencePlayback();
                                              }
                                            },
                                      icon: Icon(isCalculating
                                          ? Icons.hourglass_top
                                          : (_isPlayingSequence
                                              ? Icons.pause
                                              : Icons.play_arrow)),
                                      label: Text(isCalculating
                                          ? 'CALCULATING...'
                                          : (_isPlayingSequence
                                              ? 'PAUSE'
                                              : 'PLAY ALL')),
                                      style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  _isPlayingSequence
                                                      ? Colors.orangeAccent
                                                      : Theme.of(context)
                                                          .colorScheme
                                                          .primary,
                                              foregroundColor: Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 12),
                                              textStyle: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold))
                                          .copyWith(
                                        backgroundColor: MaterialStateProperty
                                            .resolveWith<Color?>(
                                                (states) => states.contains(
                                                        MaterialState.disabled)
                                                    ? Colors.grey.shade400
                                                    : (_isPlayingSequence
                                                        ? Colors.orangeAccent
                                                        : Theme.of(context)
                                                            .colorScheme
                                                            .primary)),
                                        foregroundColor: MaterialStateProperty
                                            .resolveWith<Color?>(
                                                (states) => states.contains(
                                                        MaterialState.disabled)
                                                    ? Colors.grey.shade700
                                                    : Colors.white),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.replay),
                                      iconSize: 32,
                                      tooltip: 'Replay from Beginning',
                                      color: canPlayOrReplay
                                          ? Theme.of(context)
                                              .colorScheme
                                              .secondary
                                          : Colors.grey,
                                      onPressed: !canPlayOrReplay
                                          ? null
                                          : _replaySequence,
                                    ),
                                    
                                    Stack(
                                      clipBehavior: Clip.none,
                                      alignment: Alignment.center,
                                      children: [
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.red.shade700,
                                                  foregroundColor: Colors.white,
                                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))
                                              .copyWith(
                                            backgroundColor: MaterialStateProperty.resolveWith<Color?>(
                                                    (states) => states.contains(MaterialState.disabled) ? Colors.red.shade200 : Colors.red.shade700),
                                            foregroundColor: MaterialStateProperty.resolveWith<Color?>(
                                                    (states) => states.contains(MaterialState.disabled) ? Colors.white70 : Colors.white),
                                          ),
                                          onPressed: !canRender
                                              ? null
                                              : () {
                                                  setState(() {
                                                    _hasDismissedRenderPopup = true; 
                                                  });
                                                  _stopSequencePlayback();
                                                  showDialog(
                                                    context: context,
                                                    barrierDismissible: false,
                                                    builder: (BuildContext context) {
                                                      bool _isSaving = false;
                                                      String _loadingMessage = "Memulai Render...";
                                                      return StatefulBuilder(
                                                        builder: (context, setDialogState) {
                                                          return AlertDialog(
                                                            title: const Text('Mulai Render Video?'),
                                                            content: Column(
                                                              mainAxisSize: MainAxisSize.min,
                                                              crossAxisAlignment: CrossAxisAlignment.start,
                                                              children: [
                                                                const Text("Data akan dikirim ke server untuk digabungkan menjadi video utuh."),
                                                                if (_isSaving)
                                                                  Padding(
                                                                    padding: const EdgeInsets.only(top: 16.0),
                                                                    child: Row(
                                                                      children: [
                                                                        const SizedBox(
                                                                          width: 20, height: 20,
                                                                          child: CircularProgressIndicator(strokeWidth: 3)),
                                                                        const SizedBox(width: 12),
                                                                        Flexible(child: Text(_loadingMessage)),
                                                                      ],
                                                                    ),
                                                                  ),
                                                              ],
                                                            ),
                                                            actions: <Widget>[
                                                              TextButton(
                                                                child: const Text('Batal'),
                                                                onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                                                              ),
                                                              TextButton(
                                                                child: Text(
                                                                  _isSaving ? 'MEMPROSES...' : 'RENDER SEKARANG',
                                                                  style: TextStyle(fontWeight: FontWeight.bold, color: _isSaving ? Colors.grey : Colors.red),
                                                                ),
                                                                onPressed: _isSaving
                                                                    ? null
                                                                    : () async {
                                                                        setDialogState(() { _isSaving = true; });
                                                                        try {
                                                                          // [HANYA MENGUBAH STATUS KE ASSETS_COMPLETE]
                                                                          // Membiarkan Backend yang bekerja merakit paket
                                                                          await ref.read(firestoreVeoServiceProvider).updateProject(
                                                                              widget.projectId,
                                                                              {
                                                                                'status': 'ASSETS_COMPLETE',
                                                                                'errorDetail': FieldValue.delete()
                                                                              }
                                                                          );
                                                                          if (mounted) Navigator.of(context).pop();
                                                                        } catch (e) {
                                                                          if (mounted) {
                                                                            Navigator.of(context).pop();
                                                                            ScaffoldMessenger.of(context).showSnackBar(
                                                                              SnackBar(content: Text('❌ Gagal: $e'), backgroundColor: Colors.red),
                                                                            );
                                                                          }
                                                                        }
                                                                      },
                                                              ),
                                                            ],
                                                          );
                                                        },
                                                      );
                                                    },
                                                  );
                                                },
                                          child: const Text('RENDER'),
                                        ),
                                        if (canRender && !_hasDismissedRenderPopup)
                                          Positioned(
                                            bottom: 50,
                                            child: TweenAnimationBuilder<double>(
                                              tween: Tween(begin: 0.0, end: 1.0),
                                              duration: const Duration(milliseconds: 600),
                                              curve: Curves.elasticOut,
                                              builder: (context, value, child) {
                                                return Transform.scale(
                                                  scale: value,
                                                  alignment: Alignment.bottomCenter,
                                                  child: child,
                                                );
                                              },
                                              child: IgnorePointer(
                                                child: Column(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                                      decoration: BoxDecoration(
                                                        color: Colors.green.shade600,
                                                        borderRadius: BorderRadius.circular(8),
                                                        boxShadow: const [
                                                          BoxShadow(
                                                            color: Colors.black26,
                                                            blurRadius: 4,
                                                            offset: Offset(0, 3),
                                                          )
                                                        ],
                                                      ),
                                                      child: const Text(
                                                        "✨ Finish & Export to MP4",
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                    Transform.translate(
                                                      offset: const Offset(0, -6),
                                                      child: Icon(
                                                        Icons.arrow_drop_down,
                                                        color: Colors.green.shade600,
                                                        size: 32,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
                if (isProjectRendering)
                  _buildRenderingOverlay(
                      secondsRemainingForOverlay, hasValidStartTime),
              ],
            );
          },
        ),
      ),
    );
  }
//Akhir Blok 6........................................................................................//


//No ke-7: FITUR LAPOR / FLAG SCENE & CHARACTER.......................................................//
//Sub-judul: Memunculkan dialog pelaporan pelanggaran ke database.....................................//
  void _showSceneReportDialog(SceneVeo scene, int index) {
    final TextEditingController reasonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Lapor Scene ${index + 1} (Veo)"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Apakah video atau narasi scene ini melanggar kebijakan?",
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: "Alasan (SARA, Kekerasan, dll)...",
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              final user = ref.read(firestoreUserProvider).valueOrNull;
              final userId = user?.uid ?? 'anonymous'; 

              FirebaseFirestore.instance.collection('reports').add({
                'projectId': widget.projectId,
                'sceneId': scene.id,
                'content': scene.videoUrl,
                'contentType': 'veo_video',
                'reason': reasonController.text.isEmpty ? 'No reason provided' : reasonController.text,
                'reportedAt': FieldValue.serverTimestamp(),
                'userId': userId,
                'feature': 'Timeline Review Veo', 
              }).then((_) {
                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Laporan dikirim. Terima kasih."),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              });
            },
            child: const Text("Lapor", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showCharacterReportDialog(String charName, String imageUrl, int index) {
    final TextEditingController reasonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Lapor Karakter $charName"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Apakah gambar karakter ini melanggar kebijakan?",
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: "Alasan (SARA, Kekerasan, dll)...",
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              final user = ref.read(firestoreUserProvider).valueOrNull;
              final userId = user?.uid ?? 'anonymous'; 

              FirebaseFirestore.instance.collection('reports').add({
                'projectId': widget.projectId,
                'characterName': charName,
                'content': imageUrl,
                'contentType': 'veo_character_image',
                'reason': reasonController.text.isEmpty ? 'No reason provided' : reasonController.text,
                'reportedAt': FieldValue.serverTimestamp(),
                'userId': userId,
                'feature': 'Timeline Review Veo', 
              }).then((_) {
                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Laporan karakter dikirim. Terima kasih."),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              });
            },
            child: const Text("Lapor", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
} 
//Akhir Blok 7........................................................................................//


//No ke-8: CLASS PELENGKAP............................................................................//
//Sub-judul: Thumbnail Item State & Dummy Logger......................................................//
class _VideoThumbnailItem extends StatefulWidget {
  final String videoUrl;
  const _VideoThumbnailItem({required this.videoUrl});

  @override
  State<_VideoThumbnailItem> createState() => _VideoThumbnailItemState();
}

class _VideoThumbnailItemState extends State<_VideoThumbnailItem> {
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    if (widget.videoUrl.isNotEmpty) {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));

      _controller!.initialize().then((_) {
        if (mounted) {
          setState(() {});
        }
      }).catchError((e) {
        logger.error(
            "Error initializing thumbnail controller for ${widget.videoUrl}: $e");
        if (mounted) {
          setState(() {});
        }
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller != null && _controller!.value.isInitialized) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8.0),
        child: VideoPlayer(_controller!),
      );
    }
    if (_controller != null && _controller!.value.hasError) {
      return Icon(Icons.error_outline, color: Colors.red[700], size: 30);
    }
    if (widget.videoUrl.isEmpty) {
      return Icon(Icons.videocam_off, color: Colors.grey[600], size: 30);
    }
    return const SizedBox(
      width: 24,
      height: 24,
      child: CircularProgressIndicator(strokeWidth: 2.0, color: Colors.grey),
    );
  }
}

class _DummyLoggerVeo {
  void warn(String message, [dynamic error, StackTrace? stackTrace]) {
    debugPrint('WARN: $message ${error ?? ''}');
  }

  void info(String message, [dynamic error, StackTrace? stackTrace]) {
    debugPrint('INFO: $message ${error ?? ''}');
  }

  void error(String message, [dynamic error, StackTrace? stackTrace]) {
    debugPrint('ERROR: $message ${error ?? ''}');
  }
}

final logger = _DummyLoggerVeo();
//Akhir Blok 8........................................................................................//

