// [RILIS BERSIH - TIMELINE UI UPDATE]
// KATEGORI_UI_TIMELINE_UPDATE
// Lokasi: lib/screens/timeline_review_screen.dart
// TUJUAN:
// - [UI] Menghapus baris "Intro Image" di timeline.
// - [UI] Menjadikan Scene 1 sebagai baris pertama.
// - [UI] Menampilkan gambar Scene 1 secara default di preview utama saat muat.
// - [UI] Menambahkan nomor urut scene di sebelah kiri thumbnail.
// - [ANTI-REGRESI] Fitur playback, render, dan editing tetap berjalan normal.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math' show cos, pi;

// --- (Impor Tema) ---
import '../theme/app_theme.dart';

// --- (Impor Proyek) ---
import '../models/scene.dart';
import '../models/video_project.dart';
import '../services/firestore_service.dart';
import '../view_model/timeline_view_model.dart';
import 'visual_setting_screen.dart';
import '../providers/visual_settings_provider.dart';

const List<String> kDefaultSceneMotionNames = [
  'rand_zoom_in_center',
  'rand_zoom_out_center',
  'pan_right',
  'zoom_in_top',
  'pan_left',
  'zoom_in_bottom',
];
const List<String> kRandomSceneMotionNames = [
  'rand_zoom_in_center',
  'rand_pan_right_out',
  'rand_pan_left_in',
  'rand_pan_top_right_out',
  'rand_pan_bottom_left_in',
  'rand_zoom_out_center',
];

class MotionStopCurve extends Curve {
  final double stopPoint;
  const MotionStopCurve({this.stopPoint = 0.8});
  @override
  double transformInternal(double t) {
    final double p = (t / stopPoint).clamp(0.0, 1.0);
    return (1 - cos(pi * p)) / 2;
  }
}

final firestoreServiceProvider =
    Provider<FirestoreService>((ref) => FirestoreService());
final selectedSceneProvider = StateProvider.autoDispose<Scene?>((ref) => null);

class TimelineReviewScreen extends ConsumerStatefulWidget {
  final String projectId;
  const TimelineReviewScreen({super.key, required this.projectId});

  @override
  ConsumerState<TimelineReviewScreen> createState() =>
      _TimelineReviewScreenState();
}

class _TimelineReviewScreenState extends ConsumerState<TimelineReviewScreen>
    with TickerProviderStateMixin {
  late AudioPlayer _narrationPlayer;
  late AudioPlayer _bgmPlayer;
  bool _isPlayingIndividual = false;
  String? _currentlyPlayingSceneId;
  bool _isPlayingSequence = false;
  int _currentSequenceIndex = -1;
  List<Scene> _currentScenes = [];
  List<ProcessedSceneData> _currentProcessedScenes = [];
  bool _isPlayingIntroBgm = false;
  double _currentPlaybackTime = 0.0;
  Timer? _playbackTimer;
  bool _showTitleOverlay = false;
  bool _showDescriptionOverlay = false;
  bool _showSubtitleOverlay = false;
  String _currentSubtitleText = "";
  int _currentSubtitleMaxLines = 4;
  late AnimationController _motionController;
  Animation<double>? _scaleAnimation;
  Animation<Offset>? _translateAnimation;
  String? _currentImageUrl;
  bool _isTriggeringRender = false;
  static const int _renderTimeoutDuration = 3600;
  Timer? _uiRefreshTimer;

  @override
  void initState() {
    super.initState();
    _narrationPlayer = AudioPlayer();
    _bgmPlayer = AudioPlayer();
    _motionController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );
    _narrationPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        final bool isPlaying = state == PlayerState.playing;
        if (!_isPlayingSequence ||
            (_isPlayingSequence &&
                !_isPlayingIntroBgm &&
                _currentlyPlayingSceneId ==
                    sceneIdFromIndex(_currentSequenceIndex))) {
          if (_isPlayingIndividual != isPlaying) {
            setState(() {
              _isPlayingIndividual = isPlaying;
            });
          }
        } else if (_isPlayingIndividual) {
          if (!isPlaying) {
            setState(() {
              _isPlayingIndividual = false;
            });
          }
        }
      }
    });
    _narrationPlayer.onPlayerComplete.listen((event) {
      if (mounted) {
        final completedSceneId = _currentlyPlayingSceneId;
        _currentlyPlayingSceneId = null;
        if (_isPlayingIndividual) {
          _isPlayingIndividual = false;
          setState(() {});
        }
        if (_isPlayingSequence &&
            !_isPlayingIntroBgm &&
            _currentSequenceIndex >= 0 &&
            _currentSequenceIndex < _currentScenes.length &&
            sceneIdFromIndex(_currentSequenceIndex) == completedSceneId) {
          _motionController.stop();
          if (_currentSequenceIndex < _currentProcessedScenes.length) {
            final processedScene =
                _currentProcessedScenes[_currentSequenceIndex];
            _updatePlaybackTime(processedScene.absoluteEndTime);
          } else {
            logger.warn(
                "onPlayerComplete: Index out of bounds, cannot sync end time.");
            _updatePlaybackTime(_currentPlaybackTime + 0.1);
          }
          final nextIndex = _currentSequenceIndex + 1;
          if (nextIndex < _currentScenes.length) {
            _playSceneAtIndex(nextIndex);
          } else {
            logger.info("Sequence finished playing all scenes.");
            _stopSequencePlayback();
          }
        }
      }
    });
    _bgmPlayer.onPlayerComplete.listen((event) {
      if (mounted && _isPlayingSequence && _isPlayingIntroBgm) {
        logger.info("Intro BGM finished. Starting scene 0.");
        _motionController.stop();
        final timelineData = ref
            .read(processedTimelineProvider(widget.projectId))
            .asData
            ?.value;
        final introDuration = timelineData?.introDuration ?? 10.0;
        _updatePlaybackTime(introDuration);
        setState(() {
          _isPlayingIntroBgm = false;
        });
        if (_currentScenes.isNotEmpty) {
          _playSceneAtIndex(0);
        } else {
          logger.warn("No scenes available after intro BGM. Stopping.");
          _stopSequencePlayback();
        }
      }
    });
    _bgmPlayer.onPlayerStateChanged.listen((state) {
      if (mounted &&
          (state == PlayerState.stopped || state == PlayerState.completed)) {
        if (_isPlayingIntroBgm) {
          logger.warn(
              "BGM Player stopped unexpectedly. Attempting to start scene 0.");
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _isPlayingIntroBgm) {
              final timelineData = ref
                  .read(processedTimelineProvider(widget.projectId))
                  .asData
                  ?.value;
              final introDuration = timelineData?.introDuration ?? 10.0;
              _motionController.stop();
              _updatePlaybackTime(introDuration);
              setState(() {
                _isPlayingIntroBgm = false;
              });
              if (_currentScenes.isNotEmpty) {
                _playSceneAtIndex(0);
              } else {
                _stopSequencePlayback();
              }
            }
          });
        }
      }
    });
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
      final firestore = ref.read(firestoreServiceProvider);
      final projectDoc = await firestore.getProject(widget.projectId);
      final currentStatus = projectDoc?['status'];
      if (currentStatus == 'RENDER_START' || currentStatus == 'RENDERING') {
        logger.error(
            "Render timeout! Project ${widget.projectId} stuck in RENDER_START for > 60 minutes (V6).");
        await firestore.updateProject(
          widget.projectId,
          {
            'status': 'ERROR_RENDER',
            'errorDetail': 'Render process timed out after 60 minutes (V6).',
            'renderStartedAt': FieldValue.delete(),
          },
        );
      } else {
        logger.error(
            "[DEBUG] Timeout check skipped — current status is $currentStatus, not RENDER_START.");
      }
    } catch (e) {
      logger.error("Failed to set ERROR_RENDER status after timeout (V6): $e");
    }
  }

  String _formatDuration(int totalSeconds) {
    final secondsClamped = totalSeconds.clamp(0, _renderTimeoutDuration);
    final duration = Duration(seconds: secondsClamped);
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  void _updatePlaybackTime(double time) {
    if (!mounted) return;
    if (time < _currentPlaybackTime &&
        (_currentPlaybackTime - time).abs() > 0.1) {
      if (_playbackTimer?.isActive ?? false) return;
    }
    _currentPlaybackTime = time;
    _updateOverlayVisibility();
  }

  void _updateOverlayVisibility() {
    if (!mounted) return;
    final settings = ref.read(visualSettingsProvider(widget.projectId));
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
    bool shouldShowSubtitle = false;
    String subtitleText = "";
    if (settings.showSubtitles &&
        _isPlayingSequence &&
        !_isPlayingIntroBgm &&
        _currentSequenceIndex >= 0 &&
        _currentSequenceIndex < _currentProcessedScenes.length) {
      final processedScene = _currentProcessedScenes[_currentSequenceIndex];
      final double sceneAbsoluteStartTime = processedScene.absoluteStartTime;
      for (final chunk in processedScene.subtitleChunks) {
        final double chunkAbsoluteStartTime =
            sceneAbsoluteStartTime + chunk.startTime;
        final double chunkAbsoluteEndTime =
            chunkAbsoluteStartTime + chunk.duration;
        if (_currentPlaybackTime >= chunkAbsoluteStartTime &&
            _currentPlaybackTime < chunkAbsoluteEndTime) {
          shouldShowSubtitle = true;
          subtitleText = chunk.text;
          _currentSubtitleMaxLines = settings.subtitleMaxLines;
          break;
        }
      }
    }
    if (!shouldShowSubtitle &&
        _currentSubtitleMaxLines != settings.subtitleMaxLines) {
      _currentSubtitleMaxLines = settings.subtitleMaxLines;
    }
    if (_showSubtitleOverlay != shouldShowSubtitle ||
        (_showSubtitleOverlay && _currentSubtitleText != subtitleText)) {
      _showSubtitleOverlay = shouldShowSubtitle;
      _currentSubtitleText = subtitleText;
      needsSetState = true;
    }
    if (needsSetState) {
      setState(() {});
    }
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

  String? sceneIdFromIndex(int sceneIndex) {
    if (sceneIndex >= 0 && sceneIndex < _currentScenes.length) {
      return _currentScenes[sceneIndex].id;
    }
    return null;
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    _motionController.dispose();
    _uiRefreshTimer?.cancel();
    if (_narrationPlayer.state != PlayerState.stopped &&
        _narrationPlayer.state != PlayerState.disposed) {
      _narrationPlayer.stop();
    }
    if (_bgmPlayer.state != PlayerState.stopped &&
        _bgmPlayer.state != PlayerState.disposed) {
      _bgmPlayer.stop();
    }
    _narrationPlayer.dispose();
    _bgmPlayer.dispose();
    super.dispose();
  }

  void _startOrResumeSequencePlayback() async {
    if (_currentSequenceIndex == -1) {
      _updatePlaybackTime(0.0);
    }
    if (_currentScenes.isEmpty && _currentSequenceIndex != -1) {
      logger.warn("Cannot start sequence: No scenes loaded.");
      return;
    }
    if (_currentSequenceIndex == -1) {
      logger.info("Sequence start: Skipping intro, starting scene 0.");
      _stopSequencePlayback(resetIndex: true);
      ref.read(selectedSceneProvider.notifier).state = null;
      setState(() {
        _isPlayingSequence = true;
        _isPlayingIntroBgm = false;
        _currentPlaybackTime = 0.0;
      });
      _startPlaybackTimer();
      if (_currentScenes.isNotEmpty) {
        _playSceneAtIndex(0);
      } else {
        logger.warn("No scenes available to play. Stopping.");
        _stopSequencePlayback();
      }
    } else if (!_isPlayingSequence &&
        !_isPlayingIntroBgm &&
        _currentSequenceIndex >= 0 &&
        _currentSequenceIndex < _currentScenes.length &&
        _narrationPlayer.state == PlayerState.paused) {
      _narrationPlayer.resume();
      _motionController.forward();
      setState(() {
        _isPlayingSequence = true;
      });
      _startPlaybackTimer();
      logger.info("Resuming sequence at scene $_currentSequenceIndex.");
    } else if (!_isPlayingSequence &&
        _isPlayingIntroBgm &&
        _currentSequenceIndex == -1 &&
        _bgmPlayer.state == PlayerState.paused) {
      _bgmPlayer.resume();
      _motionController.forward();
      setState(() {
        _isPlayingSequence = true;
      });
      _startPlaybackTimer();
      logger.info("Resuming sequence during intro BGM.");
    }
  }

  void _pauseSequencePlayback() {
    if (!_isPlayingSequence) return;
    _playbackTimer?.cancel();
    _motionController.stop();
    if (_isPlayingIntroBgm) {
      _bgmPlayer.pause();
      logger.info("Pausing sequence during intro BGM.");
    } else {
      _narrationPlayer.pause();
      logger.info("Pausing sequence at scene $_currentSequenceIndex.");
    }
    setState(() {
      _isPlayingSequence = false;
    });
  }

  void _stopSequencePlayback({bool resetIndex = true}) {
    _playbackTimer?.cancel();
    _updatePlaybackTime(0.0);
    _motionController.stop();
    _motionController.reset();
    if (_narrationPlayer.state != PlayerState.stopped &&
        _narrationPlayer.state != PlayerState.disposed) {
      _narrationPlayer.stop();
    }
    if (_bgmPlayer.state != PlayerState.stopped &&
        _bgmPlayer.state != PlayerState.disposed) {
      _bgmPlayer.stop();
    }
    if (mounted) {
      setState(() {
        _isPlayingSequence = false;
        _isPlayingIntroBgm = false;
        _isPlayingIndividual = false;
        _currentlyPlayingSceneId = null;
        if (resetIndex) {
          _currentImageUrl = null; // Will reset to default in build
          _currentSequenceIndex = -1;
        }
      });
      if (resetIndex) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ref.read(selectedSceneProvider.notifier).state = null;
          }
        });
      }
    } else {
      _isPlayingSequence = false;
      _isPlayingIntroBgm = false;
      _isPlayingIndividual = false;
      _currentlyPlayingSceneId = null;
      if (resetIndex) {
        _currentImageUrl = null;
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

  void _playSceneAtIndex(int sceneIndex) {
    if (!_isPlayingSequence ||
        _isPlayingIntroBgm ||
        sceneIndex < 0 ||
        sceneIndex >= _currentScenes.length) {
      logger.warn("Invalid state for playSceneAtIndex.");
      _stopSequencePlayback();
      return;
    }
    if (_bgmPlayer.state == PlayerState.playing ||
        _bgmPlayer.state == PlayerState.paused) {
      _bgmPlayer.stop();
    }
    final scene = _currentScenes[sceneIndex];
    final processedScene = _currentProcessedScenes[sceneIndex];
    if (!mounted) return;
    ref.read(selectedSceneProvider.notifier).state = scene;
    final settings = ref.read(visualSettingsProvider(widget.projectId));
    final sceneMotionBehavior = settings.sceneMotionBehavior;
    final double sceneDuration = processedScene.actualAudioDuration;
    String motionName = 'none';
    double intensity = 0.3;
    bool isMotionIn = true;
    Curve simulationCurve;
    if (sceneMotionBehavior == 'default') {
      intensity = 0.3;
      motionName =
          kDefaultSceneMotionNames[sceneIndex % kDefaultSceneMotionNames.length];
      isMotionIn =
          (motionName != 'zoom_out_center' && !motionName.contains('_out'));
      if (motionName.startsWith('rand_')) {
        simulationCurve = const Interval(0.0, 0.7, curve: Curves.linear);
      } else {
        simulationCurve = const MotionStopCurve(stopPoint: 0.7);
      }
    } else if (sceneMotionBehavior == 'random') {
      intensity = 0.3;
      motionName =
          kRandomSceneMotionNames[sceneIndex % kRandomSceneMotionNames.length];
      isMotionIn = !motionName.contains('_out');
      simulationCurve = const Interval(0.0, 0.7, curve: Curves.linear);
    } else {
      motionName = 'none';
      intensity = 0.0;
      isMotionIn = true;
      simulationCurve = Curves.linear;
    }
    final double scaleStart = isMotionIn ? 1.0 : (1.0 + intensity);
    final double scaleEnd = isMotionIn ? (1.0 + intensity) : 1.0;
    _scaleAnimation = Tween<double>(begin: scaleStart, end: scaleEnd)
        .animate(CurvedAnimation(
            parent: _motionController, curve: simulationCurve));
    Offset translateStart = Offset.zero;
    Offset translateEnd = Offset.zero;
    final double panFactor = intensity * 0.5;
    switch (motionName) {
      case 'pan_right':
      case 'rand_pan_right_in':
      case 'rand_pan_right_out':
        translateEnd = Offset(panFactor, 0.0);
        break;
      case 'pan_left':
      case 'rand_pan_left_in':
      case 'rand_pan_left_out':
        translateEnd = Offset(-panFactor, 0.0);
        break;
      case 'zoom_in_top':
        translateEnd = Offset(0.0, -panFactor);
        break;
      case 'zoom_in_bottom':
        translateEnd = Offset(0.0, panFactor);
        break;
      case 'rand_pan_top_right_out':
        translateEnd = Offset(panFactor, -panFactor);
        break;
      case 'rand_pan_bottom_left_in':
        translateEnd = Offset(-panFactor, panFactor);
        break;
      default:
        translateEnd = Offset.zero;
        break;
    }
    if (isMotionIn) {
      translateStart = Offset.zero;
    } else {
      translateStart = translateEnd;
      translateEnd = Offset.zero;
    }
    _translateAnimation = Tween<Offset>(begin: translateStart, end: translateEnd)
        .animate(CurvedAnimation(
            parent: _motionController, curve: simulationCurve));
    setState(() {
      _currentSequenceIndex = sceneIndex;
      _currentlyPlayingSceneId = scene.id;
      _isPlayingIndividual = false;
      _currentImageUrl = scene.imageUrl;
    });
    if (sceneMotionBehavior != 'none') {
      _motionController.duration =
          Duration(milliseconds: (sceneDuration * 1000).round());
      _motionController.forward(from: 0.0);
    }
    logger.info("Playing sequence at scene index $sceneIndex (ID: ${scene.id})");
    if (scene.ttsAudioUrl.isNotEmpty) {
      _narrationPlayer.play(UrlSource(scene.ttsAudioUrl)).catchError((e) {
        logger.error("Error playing narration for scene $sceneIndex: $e");
        _handlePlaybackErrorOrSkip(sceneIndex);
      });
    } else {
      logger.warn("Scene $sceneIndex has no audio URL, skipping after delay.");
      _handlePlaybackErrorOrSkip(sceneIndex);
    }
    _updateOverlayVisibility();
  }

  void _handlePlaybackErrorOrSkip(int currentSceneIndex) {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted &&
          _isPlayingSequence &&
          !_isPlayingIntroBgm &&
          _currentSequenceIndex == currentSceneIndex) {
        _motionController.stop();
        if (currentSceneIndex < _currentProcessedScenes.length) {
          final processedScene = _currentProcessedScenes[currentSceneIndex];
          _updatePlaybackTime(processedScene.absoluteEndTime);
        }
        final nextIndex = _currentSequenceIndex + 1;
        if (nextIndex < _currentScenes.length) {
          _playSceneAtIndex(nextIndex);
        } else {
          logger.info("Sequence finished after skipping/error on last scene.");
          _stopSequencePlayback();
        }
      }
    });
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

  Widget _buildAnimatedImage(String? imageUrl, {Key? key}) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return Tooltip(
        key: key,
        message: 'Image URL is missing',
        child: Icon(Icons.video_camera_back_outlined,
            color: Colors.white54, size: 60),
      );
    }
    final imageWidget = Image.network(
      imageUrl,
      headers: const {}, 
      fit: BoxFit.contain,
      loadingBuilder: (c, ch, lp) => lp == null
          ? ch
          : const Center(child: CircularProgressIndicator(color: Colors.white70)),
      errorBuilder: (c, e, s) {
          debugPrint("[IMAGE ERROR] Main Viewer: $e");
          return Tooltip(
              message: 'Error loading image: $e',
              child: const Icon(Icons.broken_image, color: Colors.redAccent, size: 60));
      },
    );
    return AnimatedBuilder(
      key: key,
      animation: _motionController,
      builder: (context, child) {
        final double scale = _scaleAnimation?.value ?? 1.0;
        final Offset translate = _translateAnimation?.value ?? Offset.zero;
        return LayoutBuilder(builder: (context, constraints) {
          final double panDimension = constraints.maxWidth < constraints.maxHeight
              ? constraints.maxWidth
              : constraints.maxHeight;
          final double translateX = translate.dx * panDimension;
          final double translateY = translate.dy * panDimension;
          return Transform.scale(
            scale: scale,
            child: Transform.translate(
              offset: Offset(translateX, translateY),
              child: child,
            ),
          );
        });
      },
      child: imageWidget,
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

  @override
  Widget build(BuildContext context) {
    final projectAsyncValue = ref.watch(projectStreamProvider(widget.projectId));
    final processedTimelineAsync =
        ref.watch(processedTimelineProvider(widget.projectId));
    final visualSettings = ref.watch(visualSettingsProvider(widget.projectId));
    final projectData = projectAsyncValue.asData?.value;
    final bool isCalculating =
        processedTimelineAsync.asData?.value?.isCalculating ?? true;
    final bool canPlayOrReplay = projectData != null && !isCalculating;
    final double aspectRatioValue =
        _calculateAspectRatio(projectData?.aspectRatio);

    const double previewScaleFactor = 0.2315;

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

    // [FIX] DEFAULT IMAGE LOGIC: Jika belum ada image, ambil dari SCENE 1
    // bukan dari thumbnail project.
    // Ini dilakukan di dalam processedTimelineAsync.when data block
    final double transitionDurationSeconds = visualSettings.transitionDuration;

    return Theme(
      data: AppTheme.darkTheme,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Review Project'),
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
                        VisualSettingScreen(projectId: widget.projectId),
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
                project.status == 'RENDER_QUEUED' ||
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
                            ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
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
                                  color: Colors.grey.shade400,
                                  width: 2.0,
                                ),
                                color: Colors.black87,
                              ),
                              child: ClipRRect(
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    AnimatedSwitcher(
                                      duration: Duration(
                                          milliseconds:
                                              (transitionDurationSeconds * 1000)
                                                  .round()),
                                      transitionBuilder: (Widget child,
                                          Animation<double> animation) {
                                        return FadeTransition(
                                            opacity: animation, child: child);
                                      },
                                      child: _buildAnimatedImage(
                                        _currentImageUrl,
                                        key: ValueKey<String?>(_currentImageUrl),
                                      ),
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
                                    Align(
                                      alignment: Alignment(
                                          0.0,
                                          visualSettings
                                              .subtitleVerticalAlignment),
                                      child: AnimatedOpacity(
                                        opacity:
                                            _showSubtitleOverlay ? 1.0 : 0.0,
                                        duration:
                                            const Duration(milliseconds: 200),
                                        child: Visibility(
                                          visible: _showSubtitleOverlay,
                                          child: FractionallySizedBox(
                                            widthFactor: visualSettings
                                                .subtitleBlockWidthFactor,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 5),
                                              decoration: BoxDecoration(
                                                color: Colors.black
                                                    .withOpacity(0.7),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                _currentSubtitleText,
                                                style: TextStyle(
                                                  fontSize: (visualSettings
                                                              .subtitleBaseFontSize *
                                                          (aspectRatioValue < 1.1
                                                              ? 1.0
                                                              : 1.0)) *
                                                      previewScaleFactor,
                                                  color: Colors.white,
                                                  shadows: const [
                                                    Shadow(
                                                      blurRadius: 3.0,
                                                      color: Colors.black87,
                                                      offset: Offset(1.5, 1.5),
                                                    )
                                                  ],
                                                ),
                                                textAlign: TextAlign.center,
                                                maxLines: visualSettings
                                                    .subtitleMaxLines,
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
                              Text("Calculating audio durations..."),
                            ],
                          ),
                        ),
                        error: (error, stack) => Center(
                            child:
                                Text('Error loading timeline data: $error')),
                        data: (timelineData) {
                          _currentScenes = timelineData.scenes
                              .map((e) => e.originalScene)
                              .toList();
                          _currentProcessedScenes = timelineData.scenes;
                          final scenes = _currentScenes;

                          // [FIX] Set Default Image to Scene 1 if not set
                          if (_currentImageUrl == null && scenes.isNotEmpty) {
                             _currentImageUrl = scenes.first.imageUrl;
                          }

                          if (scenes.isEmpty &&
                              project.status != 'PROCESSING_GENERATION' &&
                              project.status != 'PENDING_REFINEMENT') {
                            return const Center(
                                child: Text("No scenes generated yet."));
                          } else if (scenes.isEmpty) {
                            return const Center(
                                child: Text("Generating scenes..."));
                          }
                          return Column(
                            children: [
                              Expanded(
                                child: ListView.builder(
                                  itemCount: scenes.length, // [REMOVED INTRO] Count hanya scenes
                                  itemBuilder: (context, index) {
                                    // [REMOVED INTRO] Logic index 0 dihapus
                                    // Sekarang index 0 adalah Scene 1 langsung
                                    final sceneIndex = index;
                                    final scene = scenes[sceneIndex];
                                    final isCurrentlyPlayingInSequence =
                                        _isPlayingSequence &&
                                            !_isPlayingIntroBgm &&
                                            _currentSequenceIndex ==
                                                sceneIndex;
                                    final bool isSelectedManually = ref
                                            .watch(selectedSceneProvider)
                                            ?.id ==
                                        scene.id &&
                                        !_isPlayingSequence;

                                    final bool isSceneInError =
                                        scene.status == 'ERROR' ||
                                            scene.status == 'ERROR_AUDIO' ||
                                            scene.status ==
                                                'ERROR_REFINEMENT' ||
                                            scene.status ==
                                                'ERROR_VISUALS';
                                    final bool isSceneStuck =
                                        scene.status == 'PENDING_AUDIO' ||
                                            scene.status ==
                                                'PENDING_VISUALS';
                                    final bool showRegenerateButton =
                                        isSceneInError || isSceneStuck;
                                    final bool isProjectBusy =
                                        (project.status?.contains('GENERATING') ??
                                                false) ||
                                            (project.status
                                                    ?.contains('PROCESSING') ??
                                                false) ||
                                            (project.status ==
                                                'RENDER_START') ||
                                            (project.status == 'RENDERING');
                                    final bool isSceneBusy = scene.status ==
                                            'PENDING_REGENERATION' ||
                                        scene.status ==
                                            'GENERATING_VISUALS' ||
                                        scene.status == 'GENERATING_AUDIO';
                                    final bool canRegenerate =
                                        showRegenerateButton &&
                                            !isProjectBusy &&
                                            !isSceneBusy;
                                            
                                    return Card(
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      color: isCurrentlyPlayingInSequence
                                          ? Colors.lightBlue[50]
                                          : (isSelectedManually
                                              ? Colors.grey[200]
                                              : null), 
                                      elevation:
                                          isCurrentlyPlayingInSequence
                                              ? 4
                                              : (isSelectedManually ? 2 : 1),
                                      child: InkWell(
                                        onTap: () {
                                          if (_isPlayingSequence) {
                                            _stopSequencePlayback(
                                                resetIndex: false);
                                          }
                                          ref
                                              .read(selectedSceneProvider
                                                  .notifier)
                                              .state = scene;
                                          setState(() {
                                            _currentSequenceIndex =
                                                sceneIndex;
                                            _currentImageUrl =
                                                scene.imageUrl;
                                          });
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Row(
                                            children: [
                                              // [BARU] Nomor Urut Scene di Kiri
                                              CircleAvatar(
                                                radius: 12,
                                                backgroundColor: Colors.grey[400],
                                                child: Text(
                                                  '${index + 1}',
                                                  style: const TextStyle(
                                                    color: Colors.black,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              // Thumbnail Container
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
                                                child: (scene.imageUrl
                                                        .isNotEmpty)
                                                    ? ClipRRect(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(8),
                                                        child: Image.network(
                                                          scene.imageUrl,
                                                          // [PATCH CORS] Headers
                                                          headers: const {},
                                                          fit: BoxFit.cover,
                                                          errorBuilder:
                                                              (c, e, s) {
                                                                  debugPrint("Scene ${sceneIndex + 1} Image Error: $e");
                                                                  return const Icon(
                                                                  Icons
                                                                      .error_outline,
                                                                  color: Colors
                                                                      .red);
                                                              },
                                                        ),
                                                      )
                                                    : Center(
                                                        child: (scene.status ==
                                                                    'PENDING_REGENERATION' ||
                                                                scene.status ==
                                                                    'GENERATING_VISUALS')
                                                            ? const SizedBox(
                                                                width: 24,
                                                                height: 24,
                                                                child:
                                                                    CircularProgressIndicator(
                                                                        strokeWidth:
                                                                            3.0),
                                                              )
                                                            : const Icon(Icons.image, color: Colors.grey),
                                                      ),
                                              ),
                                              const SizedBox(width: 12),
                                              _buildAudioControlButton(
                                                  scene, sceneIndex),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      scene.segmentText ?? "",
                                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.w500,
                                                        color: isCurrentlyPlayingInSequence || isSelectedManually
                                                            ? Colors.black87
                                                            : Theme.of(context).textTheme.bodyMedium?.color,
                                                      ),
                                                      maxLines: 2,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      scene.status ?? "Unknown",
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: _getStatusColor(
                                                            scene.status),
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                    if (scene.errorDetail !=
                                                            null &&
                                                        scene.errorDetail!
                                                            .isNotEmpty)
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets
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
                                              Visibility(
                                                visible: showRegenerateButton,
                                                maintainSize: true,
                                                maintainAnimation: true,
                                                maintainState: true,
                                                child: IconButton(
                                                  icon: Icon(Icons.refresh,
                                                      color: canRegenerate
                                                          ? Colors.blueAccent
                                                          : Colors.grey[400]),
                                                  tooltip:
                                                      'Regenerate Asset (Image & Audio)',
                                                  onPressed: !canRegenerate
                                                      ? null
                                                      : () {
                                                          _stopSequencePlayback();
                                                          _showRegenerateDialog(
                                                              scene);
                                                        },
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
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
                                                                      },
                                                                    );
                                                                    try {
                                                                      logger.info(
                                                                          "Step 1/2: Preparing and saving full render packet for ${widget.projectId}...");
                                                                      await prepareAndSaveRenderPacket(
                                                                          ref,
                                                                          widget
                                                                              .projectId);
                                                                      setDialogState(
                                                                        () {
                                                                          _loadingMessage =
                                                                              "Triggering backend render...";
                                                                        },
                                                                      );
                                                                      await Future
                                                                          .delayed(
                                                                        const Duration(
                                                                            milliseconds:
                                                                                200),
                                                                      );
                                                                      logger.info(
                                                                          "Step 2/2: Updating status to RENDER_START for ${widget.projectId}...");
                                                                      await ref
                                                                          .read(
                                                                              firestoreServiceProvider)
                                                                          .updateProject(
                                                                              widget
                                                                                  .projectId,
                                                                              {
                                                                                'status':
                                                                                    'RENDER_START',
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
                                                                          },
                                                                        );
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

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'COMPLETED':
        return Colors.green.shade700;
      case 'ERROR':
      case 'ERROR_AUDIO':
      case 'ERROR_VISUALS':
      case 'ERROR_REFINEMENT':
      case 'ERROR_RENDER':
        return Colors.red.shade700;
      case 'PENDING_REGENERATION':
        return Colors.blueAccent;
      case 'GENERATING_VISUALS':
      case 'GENERATING_AUDIO':
      case 'PROCESSING_REFINEMENT':
      case 'PROCESSING_AUTO_RETRY':
      case 'GENERATING_THUMBNULL':
      case 'GENERATING_THUMBNAIL':
        return Colors.purple.shade600;
      case 'ASSETS_COMPLETE':
        return Colors.blue.shade600;
      case 'RENDER_COMPLETED':
        return Colors.green.shade700;
      default:
        return Colors.grey.shade600;
    }
  }

  void _showRegenerateDialog(Scene scene) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Regenerate Asset?'),
          content: Text(
              'This will re-create the image AND audio for scene ${scene.segmentIndex + 1}. Are you sure?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Regenerate'),
              onPressed: () {
                Navigator.of(context).pop();
                ref
                    .read(firestoreServiceProvider)
                    .requestImageRegeneration(widget.projectId, scene.id);
              },
            ),
          ],
        );
      },
    );
  }

  void _triggerRender(String? aspectRatioString) {
    final timelineDataAsync =
        ref.read(processedTimelineProvider(widget.projectId));
    final timelineData = timelineDataAsync.asData?.value;
    final double aspectRatioValue = _calculateAspectRatio(aspectRatioString);
    final styleData = ref
        .read(visualSettingsProvider(widget.projectId))
        .toJson(aspectRatioValue);
    if (timelineData == null || timelineData.isCalculating) {
      logger.error(
          "Render failed: Timeline data is not ready or still calculating.");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Error: Timeline data is not ready. Please wait and try again.'),
            backgroundColor: Colors.red),
      );
      return;
    }
    final timingData = timelineData.toJson();
    final Map<String, dynamic> renderPacket = {
      'styleSettings': styleData,
      'timingData': timingData,
    };
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Start Video Render?'),
          content: const Text(
              'This will send the complete render packet to the backend to start the final video generation.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('RENDER',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop();
                try {
                  logger.info(
                      "Attempting update to RENDER_START for ${widget.projectId} with full render packet.");
                  ref
                      .read(firestoreServiceProvider)
                      .updateProject(widget.projectId,
                          {'renderPacket': renderPacket, 'status': 'RENDER_START'});
                  logger.info(
                      "Firestore update call finished for ${widget.projectId}");
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Render request sent!'),
                          backgroundColor: Colors.green),
                    );
                  }
                } catch (e) {
                  logger.error(
                      "Failed to trigger render for ${widget.projectId}", e);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content:
                              Text('Failed to send render request: $e'),
                          backgroundColor: Colors.red),
                    );
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildAudioControlButton(Scene scene, int sceneIndex) {
    final bool isThisSceneCurrentlyPlaying = (_isPlayingIndividual ||
            (_isPlayingSequence && !_isPlayingIntroBgm)) &&
        _currentlyPlayingSceneId == scene.id &&
        _narrationPlayer.state == PlayerState.playing;
    final bool canThisScenePlay = scene.ttsAudioUrl.isNotEmpty;

    if (!canThisScenePlay &&
        (_isPlayingSequence && _currentSequenceIndex == sceneIndex)) {
      return const SizedBox(
        width: 48,
        height: 48,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
                strokeWidth: 2.5, color: Colors.blueAccent),
          ),
        ),
      );
    } else if (!canThisScenePlay &&
        (scene.status == 'ERROR_AUDIO' || scene.status == 'ERROR')) {
      return IconButton(
        icon: Icon(Icons.volume_off, color: Colors.red[400], size: 36),
        onPressed: null,
        tooltip: 'Audio failed to generate. Please regenerate.',
      );
    } else if (!canThisScenePlay) {
      return IconButton(
        icon: Icon(Icons.volume_off, color: Colors.grey[400], size: 36),
        onPressed: null,
        tooltip: 'No audio available or still pending',
      );
    }

    return IconButton(
      icon: Icon(
        isThisSceneCurrentlyPlaying
            ? Icons.pause_circle_filled
            : Icons.play_circle_fill,
        color: Theme.of(context).primaryColor,
        size: 36,
      ),
      tooltip: isThisSceneCurrentlyPlaying
          ? 'Pause Scene ${sceneIndex + 1}'
          : 'Play Scene ${sceneIndex + 1}',
      onPressed: () {
        if (_isPlayingSequence) {
          _stopSequencePlayback(resetIndex: false);
        }
        if (isThisSceneCurrentlyPlaying) {
          _narrationPlayer.pause();
        } else {
          _playbackTimer?.cancel();
          _updatePlaybackTime(0.0);
          _narrationPlayer.stop();
          _bgmPlayer.stop();
          setState(() {
            _currentlyPlayingSceneId = scene.id;
            _isPlayingIndividual = true;
            _currentSequenceIndex = sceneIndex;
            ref.read(selectedSceneProvider.notifier).state = scene;
            _currentImageUrl = scene.imageUrl;
          });
          _narrationPlayer.play(UrlSource(scene.ttsAudioUrl)).catchError((e) {
            logger.error(
                "Error playing individual audio for scene $sceneIndex: $e");
            if (mounted) {
              setState(() {
                _currentlyPlayingSceneId = null;
                _isPlayingIndividual = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(
                        'Failed to play audio for scene ${sceneIndex + 1}.'),
                    backgroundColor: Colors.red),
              );
            }
          });
        }
      },
    );
  }
} 

class _DummyLogger {
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

final logger = _DummyLogger();