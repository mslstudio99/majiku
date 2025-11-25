// [RILIS BERSIH - IMPLEMENTASI TEMA DARK MODERN]
// KATEGORI_TEMA_BARU NO_URUT_05
// NAMA FILE: lib/screens_veo/timeline_review_veo_screen.dart
// TUJUAN:
// - [FITUR] Menerapkan AppTheme.darkTheme ke halaman ini.
// - [REFAKTOR] Menghapus warna hardcode dari AppBar.
// - [ANTI-REGRESI] Mempertahankan semua warna fungsional/status
// - (tombol Play, Render, Download, highlight scene, status error).

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

// --- (Impor Tema BARU) ---
import '../theme/app_theme.dart';

// --- (Impor Proyek) ---
import '../models_veo/scene_veo.dart';
import '../models_veo/video_project_veo.dart';
import '../services_veo/firestore_veo_service.dart';
import '../view_model_veo/timeline_veo_view_model.dart';
import 'visual_setting_veo_screen.dart';
import '../providers_veo/visual_settings_veo_provider.dart';

// --- (Definisi Provider Tidak Berubah) ---
final firestoreVeoServiceProvider =
    Provider<FirestoreVeoService>((ref) => FirestoreVeoService());
final selectedSceneVeoProvider =
    StateProvider.autoDispose<SceneVeo?>((ref) => null);

class TimelineReviewVeoScreen extends ConsumerStatefulWidget {
  final String projectId;
  const TimelineReviewVeoScreen({super.key, required this.projectId});

  @override
  ConsumerState<TimelineReviewVeoScreen> createState() =>
      _TimelineReviewVeoScreenState();
}

class _TimelineReviewVeoScreenState
    extends ConsumerState<TimelineReviewVeoScreen> {
  // (State internal tidak berubah)
  VideoPlayerController? _videoController;
  bool _isPlayingSequence = false;
  int _currentSequenceIndex = -1;
  List<SceneVeo> _currentScenes = [];
  List<ProcessedSceneDataVeo> _currentProcessedScenes = [];
  double _currentPlaybackTime = 0.0;
  Timer? _playbackTimer;
  bool _showTitleOverlay = false;
  bool _showDescriptionOverlay = false;
  bool _isTriggeringRender = false;
  static const int _renderTimeoutDuration = 3600;
  Timer? _uiRefreshTimer;

  @override
  void initState() {
    super.initState();
  }

  // (Fungsi _startUiRefreshTimer Tidak Berubah)
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

  // (Fungsi _cancelUiRefreshTimer Tidak Berubah)
  void _cancelUiRefreshTimer() {
    if (_uiRefreshTimer != null && _uiRefreshTimer!.isActive) {
      _uiRefreshTimer!.cancel();
    }
  }

  // (Fungsi _handleRenderTimeout Tidak Berubah)
  Future<void> _handleRenderTimeout() async {
    _cancelUiRefreshTimer();
    try {
      final firestore = ref.read(firestoreVeoServiceProvider);
      final projectDoc = await firestore.getProject(widget.projectId);
      final currentStatus = projectDoc?['status'];

      if (currentStatus == 'RENDER_START' || currentStatus == 'RENDERING') {
        logger.error(
            "Render timeout! Project ${widget.projectId} stuck in $currentStatus for > 60 minutes (V1.7).");
        await firestore.updateProject(
          widget.projectId,
          {
            'status': 'ERROR_RENDER',
            'errorDetail': 'Render process timed out after 60 minutes (V1.7).',
            'renderStartedAt': FieldValue.delete(),
          },
        );
      } else {
        logger.error(
            "[DEBUG] Timeout check skipped — current status is $currentStatus, not RENDER_START/RENDERING.");
      }
    } catch (e) {
      logger.error("Failed to set ERROR_RENDER status after timeout (V1.7): $e");
    }
  }

  // (Fungsi _formatDuration Tidak Berubah)
  String _formatDuration(int totalSeconds) {
    final secondsClamped = totalSeconds.clamp(0, _renderTimeoutDuration);
    final duration = Duration(seconds: secondsClamped);
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  // (Fungsi _updatePlaybackTime Tidak Berubah)
  void _updatePlaybackTime(double time) {
    if (!mounted) return;
    if (time < _currentPlaybackTime && (_currentPlaybackTime - time).abs() > 0.1) {
      if (_playbackTimer?.isActive ?? false) return;
    }
    _currentPlaybackTime = time;
    _updateOverlayVisibility();
  }

  // (Fungsi _updateOverlayVisibility Tidak Berubah)
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

  // (Fungsi _startPlaybackTimer Tidak Berubah)
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

  // (Fungsi sceneIdFromIndex Tidak Berubah)
  String? sceneIdFromIndex(int sceneIndex) {
    if (sceneIndex >= 0 && sceneIndex < _currentScenes.length) {
      return _currentScenes[sceneIndex].id;
    }
    return null;
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    _uiRefreshTimer?.cancel();
    _videoController?.dispose();
    super.dispose();
  }

  // (Fungsi _startOrResumeSequencePlayback Tidak Berubah)
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

  // (Fungsi _pauseSequencePlayback Tidak Berubah)
  void _pauseSequencePlayback() {
    if (!_isPlayingSequence) return;
    _playbackTimer?.cancel();
    _videoController?.pause();
    logger.info("Pausing sequence at scene $_currentSequenceIndex.");
    setState(() {
      _isPlayingSequence = false;
    });
  }

  // (Fungsi _stopSequencePlayback Tidak Berubah)
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

  // (Fungsi _replaySequence Tidak Berubah)
  void _replaySequence() {
    logger.info("Replaying sequence from beginning.");
    _stopSequencePlayback(resetIndex: true);
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _startOrResumeSequencePlayback();
      }
    });
  }

  // (Fungsi _videoPlaybackListener Tidak Berubah)
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

  // (Fungsi _initializeAndPlayVideo Tidak Berubah)
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

  // (Fungsi _handlePlaybackErrorOrSkip Tidak Berubah)
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

  // (Fungsi _launchURL Tidak Berubah)
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

  // (Fungsi _calculateAspectRatio Tidak Berubah)
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

  // (Fungsi _buildVideoDisplay Tidak Berubah)
  Widget _buildVideoDisplay({Key? key}) {
    if (_isPlayingSequence &&
        _videoController != null &&
        _videoController!.value.isInitialized) {
      return VideoPlayer(_videoController!);
    }
    return Tooltip(
      key: key,
      message: 'Video not playing. No thumbnail available.',
      child: Icon(Icons.video_camera_back_outlined,
          color: Colors.white54, size: 60),
    );
  }

  // (Fungsi _buildRenderingOverlay Tidak Berubah)
  Widget _buildRenderingOverlay(int secondsRemaining, bool hasValidStartTime) {
    return Positioned.fill(
      child: AbsorbPointer(
        child: Container(
          color: Colors.black.withOpacity(0.7),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  )
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  const Text(
                    "Rendering Video Dalam Beberapa Menit...",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (hasValidStartTime)
                    Text(
                      "Batas waktu cancel otomatis: ${_formatDuration(secondsRemaining)}",
                      style: const TextStyle(fontSize: 14, color: Colors.black54),
                    )
                  else
                    const Text(
                      "Menunggu respons backend...",
                      style: TextStyle(fontSize: 14, color: Colors.black54),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ### METODE BUILD UTAMA ###
  @override
  Widget build(BuildContext context) {
    // (Provider watches tidak berubah)
    final projectAsyncValue =
        ref.watch(projectVeoStreamProvider(widget.projectId));
    final processedTimelineAsync =
        ref.watch(processedTimelineVeoProvider(widget.projectId));
    final visualSettings =
        ref.watch(visualSettingsVeoProvider(widget.projectId));

    final projectData = projectAsyncValue.asData?.value;
    final bool isCalculating =
        processedTimelineAsync.asData?.value?.isCalculating ?? true;
    final bool canPlayOrReplay = projectData != null && !isCalculating;
    final double aspectRatioValue =
        _calculateAspectRatio(projectData?.aspectRatio);

    const double previewScaleFactor = 0.2315;

    // (Fungsi _getTextStyle Tidak Berubah)
    TextStyle _getTextStyle(double baseFontSize, Color color) {
      double multiplier = 1.0;
      final double actualRenderFontSize = baseFontSize * multiplier;
      final double previewFontSize = actualRenderFontSize * previewScaleFactor;

      return TextStyle(
        fontSize: previewFontSize,
        color: color,
        fontWeight: FontWeight.bold,
        shadows: const [
          Shadow(
            blurRadius: 3.0,
            color: Colors.black87,
            offset: Offset(1.5, 1.5),
          )
        ],
      );
    }

    // [BARU] Menerapkan tema Dark Modern HANYA ke halaman ini
    return Theme(
      data: AppTheme.darkTheme,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Review Project (Veo)'),
          // [DIHAPUS] Warna AppBar akan diwarisi dari AppTheme
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

            // (Logika status tidak berubah)
            if (_isTriggeringRender &&
                (project.status == 'RENDERING' ||
                    project.status == 'RENDER_START')) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _isTriggeringRender = false);
              });
            }
            final bool scenesAreReadyOrError = processedTimelineAsync.maybeWhen(
              data: (timeline) =>
                  !timeline.scenes.any((s) => s.originalScene.status == 'ERROR'),
              orElse: () => false,
            );
            final bool isRenderSuccess = project.status == 'RENDER_COMPLETED' &&
                project.finalVideoUrl != null &&
                project.finalVideoUrl!.isNotEmpty;
            final bool isRenderComplete = isRenderSuccess;
            final String? finalVideoUrl = project.finalVideoUrl;
            final bool canRender;
            if (isRenderSuccess) {
              canRender = false;
            } else if (project.status == 'ASSETS_COMPLETE' ||
                project.status == 'ERROR_RENDER' ||
                project.status == 'RENDER_READY' ||
                project.status == 'ERROR_TRIGGER' ||
                project.status == 'RENDER_START' ||
                (project.status == 'RENDER_COMPLETED' && !isRenderSuccess)) {
              canRender = scenesAreReadyOrError;
            } else {
              canRender = false;
            }
            final bool isProjectRendering = (project.status == 'RENDER_START' ||
                project.status == 'RENDERING' ||
                _isTriggeringRender);
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
            
            // Tampilan Utama (Column)
            return Stack(
              children: [
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Text(
                        visualSettings.titleSettings.text,
                        // [MODIFIKASI TEMA] Menggunakan style tema
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(
                                // [PERBAIKAN] Memaksa warna putih agar kontras
                                color: Colors.white),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    // --- Viewer Atas DINAMIS ---
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
                                  // [ANTI-REGRESI] Warna border abu-abu dipertahankan
                                  color: Colors.grey.shade400,
                                  width: 2.0,
                                ),
                                // [ANTI-REGRESI] Backdrop hitam video dipertahankan
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
                                    // (Layer 2: Title Overlay - Tidak Berubah)
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
                                              decoration: BoxDecoration(
                                                color: Colors.black
                                                    .withOpacity(0.6),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                visualSettings
                                                    .titleSettings.text,
                                                style: _getTextStyle(
                                                  visualSettings.titleSettings
                                                      .baseFontSize,
                                                  visualSettings
                                                      .titleSettings.color,
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
                                    // (Layer 3: Description Overlay - Tidak Berubah)
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
                                              visualSettings
                                                  .descriptionSettings
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
                                              decoration: BoxDecoration(
                                                color: Colors.black
                                                    .withOpacity(0.6),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
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
                    // --- AKHIR BLOK PREVIEWER ---

                    // (Tombol Download Tidak Berubah)
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

// [PATCH 3 - UI FRONTEND (KATEGORI_EDIT_PROMPT)]
                    // (Timeline List dengan Editor Prompt Manual)
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
                                child: ListView.builder(
                                  itemCount: scenes.length,
                                  itemBuilder: (context, index) {
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
                                        // [PENTING] Status manual tidak ada lagi karena kita pakai PENDING_REFINEMENT
                                        // Tapi status PENDING_MANUAL_REFIX dihapus dari backend, jadi aman.
                                        false;

                                    // Logika Visibilitas Tombol Edit (Hanya jika ERROR)
                                    // Menggunakan (?? '') untuk null safety (Anti-Regresi)
                                    final bool isError = (scene.status ?? '').startsWith('ERROR');

                                    return Card(
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      color: isCurrentlyPlayingInSequence
                                          ? Colors.lightBlue[50]
                                          : (isSelectedManually
                                              ? Colors.grey[200]
                                              : null), // null = pakai tema
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
                                              // [KATEGORI_FITUR_UI] Nomor Urut Scene
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

                                              // THUMBNAIL
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
                                                    : _VideoThumbnailItem(
                                                        videoUrl: scene.videoUrl),
                                              ),
                                              const SizedBox(width: 12),

                                              // TEKS
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

                                              // [PERUBAHAN UTAMA: TOMBOL EDIT PROMPT]
                                              if (isError)
                                                IconButton(
                                                  icon: Icon(Icons.edit, // Ikon Edit
                                                      color: Colors.orange[700]),
                                                  tooltip: 'Edit Prompt & Retry',
                                                  onPressed: () {
                                                    // Persiapkan controller dengan prompt yang gagal (atau raw)
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
                                                             // [INPUT FIELD BARU]
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

                                                              // [PANGGIL METODE SERVICE BARU]
                                                              ref.read(firestoreVeoServiceProvider)
                                                                 .updateScenePromptAndRegenerate(
                                                                    widget.projectId,
                                                                    scene.id,
                                                                    newPrompt // Kirim prompt editan user
                                                                 );
                                                              Navigator.of(ctx).pop();
                                                            },
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                  },
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              // Tombol Kontrol Bawah (Tetap ada di sini)
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
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  Colors.red.shade700,
                                              foregroundColor: Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 20,
                                                      vertical: 12),
                                              textStyle: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold))
                                          .copyWith(
                                        backgroundColor: MaterialStateProperty
                                            .resolveWith<Color?>(
                                                (states) => states.contains(
                                                        MaterialState.disabled)
                                                    ? Colors.red.shade200
                                                    : Colors.red.shade700),
                                        foregroundColor: MaterialStateProperty
                                            .resolveWith<Color?>(
                                                (states) => states.contains(
                                                        MaterialState.disabled)
                                                    ? Colors.white70
                                                    : Colors.white),
                                      ),
                                      onPressed: !canRender
                                          ? null
                                          : () {
                                              _stopSequencePlayback();
                                              showDialog(
                                                context: context,
                                                barrierDismissible: false,
                                                builder:
                                                    (BuildContext context) {
                                                  bool _isSaving = false;
                                                  String _loadingMessage =
                                                      "Saving render packet...";
                                                  return StatefulBuilder(
                                                    builder: (context,
                                                        setDialogState) {
                                                      return AlertDialog(
                                                        title: const Text(
                                                            'Start Video Render?'),
                                                        content: Column(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            const Text(
                                                              "This will assemble all final data (scenes, timing, and styles) and send it to the render queue.\n\n"
                                                              "This action cannot be undone.",
                                                            ),
                                                            if (_isSaving)
                                                              Padding(
                                                                padding:
                                                                    const EdgeInsets
                                                                        .only(
                                                                        top: 16.0),
                                                                child: Row(
                                                                  children: [
                                                                    const SizedBox(
                                                                      width: 20,
                                                                      height:
                                                                          20,
                                                                      child:
                                                                          CircularProgressIndicator(
                                                                              strokeWidth:
                                                                                  3),
                                                                    ),
                                                                    const SizedBox(
                                                                        width:
                                                                            12),
                                                                    Flexible(
                                                                        child: Text(
                                                                            _loadingMessage)),
                                                                  ],
                                                                ),
                                                              ),
                                                          ],
                                                        ),
                                                        actions: <Widget>[
                                                          TextButton(
                                                            child: const Text(
                                                                'Cancel'),
                                                            onPressed: _isSaving
                                                                ? null
                                                                : () =>
                                                                    Navigator.of(
                                                                            context)
                                                                        .pop(),
                                                          ),
                                                          TextButton(
                                                            child: Text(
                                                              _isSaving
                                                                  ? 'SAVING...'
                                                                  : 'RENDER',
                                                              style: TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  color:
                                                                      _isSaving
                                                                          ? Colors
                                                                              .grey
                                                                          : Colors
                                                                              .red),
                                                            ),
                                                            onPressed: _isSaving
                                                                ? null
                                                                : () async {
                                                                    setDialogState(
                                                                        () {
                                                                      _isSaving =
                                                                          true;
                                                                      _loadingMessage =
                                                                          "Saving render packet...";
                                                                    });
                                                                    try {
                                                                      logger.info(
                                                                          "Step 1/2: Preparing and saving full render packet for ${widget.projectId}...");
                                                                      await prepareAndSaveRenderPacketVeo(
                                                                          ref,
                                                                          widget
                                                                              .projectId);
                                                                      setDialogState(
                                                                          () {
                                                                        _loadingMessage =
                                                                            "Triggering backend render...";
                                                                      });
                                                                      await Future
                                                                          .delayed(
                                                                              const Duration(
                                                                                  milliseconds:
                                                                                      200));
                                                                      logger.info(
                                                                          "Step 2/2: Updating status to RENDER_READY for ${widget.projectId}...");
                                                                      await ref
                                                                          .read(
                                                                              firestoreVeoServiceProvider)
                                                                          .updateProject(
                                                                              widget
                                                                                  .projectId,
                                                                              {
                                                                                'status':
                                                                                    'RENDER_READY',
                                                                                'renderStartedAt': FieldValue
                                                                                    .serverTimestamp(),
                                                                                'errorDetail': FieldValue
                                                                                    .delete()
                                                                              });
                                                                      logger.info(
                                                                          "Render trigger successful for ${widget.projectId}");
                                                                      if (mounted) {
                                                                        Navigator.of(
                                                                                context)
                                                                            .pop();
                                                                        setState(
                                                                            () {
                                                                          _isTriggeringRender =
                                                                              true;
                                                                        });
                                                                      }
                                                                    } catch (e) {
                                                                      logger.error(
                                                                          "Failed to prepare or trigger render for ${widget.projectId}",
                                                                          e);
                                                                      if (mounted) {
                                                                        Navigator.of(
                                                                                context)
                                                                            .pop();
                                                                        ScaffoldMessenger.of(
                                                                                context)
                                                                            .showSnackBar(
                                                                          SnackBar(
                                                                              content: Text(
                                                                                  '❌ Failed to send render packet: $e'),
                                                                              backgroundColor:
                                                                                  Colors.red),
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
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
// [AKHIR PATCH]
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

// --- (Widget _VideoThumbnailItem Tidak Berubah) ---
} // Akhir _TimelineReviewScreenState

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
// --- [AKHIR PERBAIKAN] ---

// --- (Dummy Logger Tidak Berubah) ---
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
// --- Akhir Dummy Logger ---