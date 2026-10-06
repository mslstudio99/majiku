
//====================================================================================================//
// NAMA FILE: LIB/SCREENS/TIMELINE_REVIEW_SCREEN.DART                                                 //
// DESKRIPSI: SMART CONTROLLER, TIMELINE UI, AUTO-RENDER WORKFLOW & MANUAL FALLBACK                   //
//====================================================================================================//

//No ke-1: IMPORTS, CONSTANTS & PROVIDERS //
//Deklarasi pustaka, tema, model, dan konfigurasi state global. //
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
import '../providers/user_provider.dart';
import '../providers/config_provider.dart'; // [BARU]: Akses appLanguageProvider & config

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
//----------------------------------------------------------------------------------------------------//

//No ke-2: MAIN CLASS DEFINITION & INITIALIZATION //
//Deklarasi class utama, inisialisasi state, dan setup player. //
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
  
  // [STATE KONTROL RENDER]
  bool _isTriggeringRender = false;
  bool _hasAutoTriggeredRender = false; // Kunci untuk cegah infinite loop Auto-Render
  static const int _renderTimeoutDuration = 3600;
  Timer? _uiRefreshTimer;
  
  // Status pop-up panduan render
  bool _hasDismissedRenderPopup = false; 

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
          // [PERBAIKAN PAUSE INDIVIDUAL]: Tidak mereset _isPlayingIndividual jika hanya dalam kondisi pause
          if (!isPlaying && state != PlayerState.paused) {
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
//----------------------------------------------------------------------------------------------------//

//No ke-3: TIMERS, UTILITIES & TIMEOUT HANDLER //
//Fungsi utilitas untuk waktu, timer UI terisolasi (Anti-Getar), dan timeout render. //
  // [ANTI-GETAR]: ValueNotifier terisolasi agar countdown detik render tidak me-rebuild seluruh layar
  final ValueNotifier<int> _renderSecondsNotifier = ValueNotifier<int>(3600);

  void _startUiRefreshTimer(int initialSeconds) {
    _renderSecondsNotifier.value = initialSeconds;
    if (_uiRefreshTimer != null && _uiRefreshTimer!.isActive) {
      return;
    }
    _uiRefreshTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_renderSecondsNotifier.value > 0) {
        _renderSecondsNotifier.value--;
      } else {
        timer.cancel();
        _handleRenderTimeout();
      }
    });
  }

  void _cancelUiRefreshTimer() {
    if (_uiRefreshTimer != null && _uiRefreshTimer!.isActive) {
      _uiRefreshTimer!.cancel();
      _uiRefreshTimer = null;
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
            "Render timeout! Project ${widget.projectId} stuck in RENDER_START for > 60 minutes.");
        await firestore.updateProject(
          widget.projectId,
          {
            'status': 'ERROR_RENDER',
            'errorDetail': 'Render process timed out after 60 minutes.',
            'renderStartedAt': FieldValue.delete(),
          },
        );
      }
    } catch (e) {
      logger.error("Failed to set ERROR_RENDER status after timeout: $e");
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
    _cancelUiRefreshTimer();
    _renderSecondsNotifier.dispose();
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
//----------------------------------------------------------------------------------------------------//

//No ke-4: PLAYBACK & ANIMATION LOGIC //
//Logika pemutaran audio, animasi gambar, dan navigasi antar scene. //
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
          _currentImageUrl = null;
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
//----------------------------------------------------------------------------------------------------//

//No ke-5: BUILD UI, WIDGETS & GATEKEEPER LOGIC //
//Fungsi rendering antarmuka pengguna, validasi aset (Gatekeeper), auto-render pemicu, dan layout utama. //
  Widget _buildAnimatedImage(String? imageUrl, {Key? key}) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return Tooltip(
        key: key,
        message: 'Image URL is missing',
        child: const Icon(Icons.video_camera_back_outlined,
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

  // [ISOLASI RENDERING OVERLAY]: Menggunakan ValueListenableBuilder agar hitungan detik tidak menggetarkan seluruh halaman
  Widget _buildRenderingOverlay(bool hasValidStartTime, bool isIndo) {
    String t(String en, String id) => isIndo ? id : en;

    return Positioned.fill(
      child: AbsorbPointer(
        child: Container(
          color: Colors.black.withOpacity(0.75),
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              decoration: BoxDecoration(
                color: const Color(0xFF1E222A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 16,
                    offset: Offset(0, 6),
                  )
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: Colors.blueAccent, strokeWidth: 3),
                  const SizedBox(height: 20),
                  Text(
                    t("Rendering in progress...", "Proses render sedang berjalan..."),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    t("You may safely leave this page.", "Anda dapat meninggalkan halaman ini dengan aman."),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  if (hasValidStartTime)
                    ValueListenableBuilder<int>(
                      valueListenable: _renderSecondsNotifier,
                      builder: (context, remainingSecs, _) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "${t('Auto Cancel in:', 'Batal Otomatis dalam:')} ${_formatDuration(remainingSecs)}",
                            style: const TextStyle(fontSize: 13, color: Colors.amberAccent, fontWeight: FontWeight.bold),
                          ),
                        );
                      },
                    )
                  else
                    Text(
                      t("Waiting for backend response...", "Menunggu respons backend..."),
                      style: const TextStyle(fontSize: 13, color: Colors.white70),
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
    // KONEKSI BILINGUAL KE APP_LANGUAGE_PROVIDER
    final currentLocale = ref.watch(appLanguageProvider);
    final isIndo = currentLocale.languageCode == 'id';
    String t(String en, String id) => isIndo ? id : en;

    final projectAsyncValue = ref.watch(projectStreamProvider(widget.projectId));
    final processedTimelineAsync =
        ref.watch(processedTimelineProvider(widget.projectId));
    final visualSettings = ref.watch(visualSettingsProvider(widget.projectId));
    final projectData = projectAsyncValue.asData?.value;
    
    final bool isCalculating =
        processedTimelineAsync.asData?.value?.isCalculating ?? true;

    // GATEKEEPER VALIDASI MUTLAK
    final bool areAllScenesValid = processedTimelineAsync.maybeWhen(
      data: (timeline) {
        if (timeline.scenes.isEmpty) return false; 
        
        return timeline.scenes.every((s) {
          final scene = s.originalScene;
          final hasValidImage = scene.imageUrl.isNotEmpty;
          final hasValidAudio = scene.ttsAudioUrl.isNotEmpty;
          final hasNoErrors = scene.status == null || !scene.status!.startsWith('ERROR');
          final isNotGenerating = scene.status != 'PENDING_REGENERATION' &&
                                  scene.status != 'GENERATING_VISUALS' &&
                                  scene.status != 'GENERATING_AUDIO' &&
                                  scene.status != 'PENDING_VISUALS' &&
                                  scene.status != 'PENDING_AUDIO';
          return hasValidImage && hasValidAudio && hasNoErrors && isNotGenerating;
        });
      },
      orElse: () => false,
    );

    final bool isRenderSuccessGlobal = projectData != null &&
        projectData.status == 'RENDER_COMPLETED' &&
        projectData.finalVideoUrl != null &&
        projectData.finalVideoUrl!.isNotEmpty;

    // AUTO-RENDER SMART CONTROLLER
    if (projectData != null &&
        projectData.status == 'CREATE_RENDER_PACKET' &&
        areAllScenesValid &&
        !_hasAutoTriggeredRender &&
        !_isTriggeringRender) {
      
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        setState(() {
          _hasAutoTriggeredRender = true;
          _isTriggeringRender = true;
        });
        
        try {
          logger.info("[AUTO-RENDER] Preparing and saving render packet...");
          await prepareAndSaveRenderPacket(ref, widget.projectId);
          
          logger.info("[AUTO-RENDER] Updating status to RENDER_START...");
          await ref.read(firestoreServiceProvider).updateProject(
            widget.projectId,
            {
              'status': 'RENDER_START',
              'renderStartedAt': FieldValue.serverTimestamp(),
              'errorDetail': FieldValue.delete()
            }
          );
          logger.info("[AUTO-RENDER] Trigger successful for ${widget.projectId}");
        } catch (e) {
          logger.error("[AUTO-RENDER] Failed to auto-trigger render", e);
          if (mounted) {
            setState(() {
              _isTriggeringRender = false;
              _hasAutoTriggeredRender = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(t('Auto-Render failed: $e', 'Auto-Render gagal: $e')),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      });
    }

    final bool canPlayOrReplay = projectData != null && !isCalculating && areAllScenesValid && !isRenderSuccessGlobal;

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

    final double transitionDurationSeconds = visualSettings.transitionDuration;

    return Theme(
      data: AppTheme.darkTheme,
      child: Scaffold(
        appBar: AppBar(
          title: Text(t('Review Project', 'Tinjau Proyek')),
          actions: [
            IconButton(
              icon: const Icon(Icons.tune),
              tooltip: t('Visual Settings', 'Pengaturan Visual'),
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
              Center(child: Text(t('Error loading project: $error', 'Gagal memuat proyek: $error'))),
          data: (project) {
            if (project == null) {
              return Center(
                child: Text(
                  t("Error: Project not found or failed to load.", "Error: Proyek tidak ditemukan atau gagal dimuat."),
                  style: const TextStyle(color: Colors.red),
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
            
            final bool isRenderSuccess = project.status == 'RENDER_COMPLETED' &&
                project.finalVideoUrl != null &&
                project.finalVideoUrl!.isNotEmpty;
            final bool isRenderComplete = isRenderSuccess;
            final String? finalVideoUrl = project.finalVideoUrl;
            
            final bool canRender;
            if (isRenderSuccess) {
              canRender = false;
            } else if (project.status == 'ASSETS_COMPLETE' ||
                project.status == 'CREATE_RENDER_PACKET' ||
                project.status == 'ASSETS_NEED_REFINEMENT' || 
                project.status == 'ERROR_RENDER' ||
                project.status == 'RENDER_QUEUED' ||
                project.status == 'ERROR_TRIGGER' ||
                project.status == 'RENDER_START' ||
                (project.status == 'RENDER_COMPLETED' && !isRenderSuccess)) {
              
              canRender = areAllScenesValid; 
              
            } else {
              canRender = false;
            }
            
            final bool isProjectRendering = (project.status == 'RENDER_START' ||
                project.status == 'RENDERING' ||
                _isTriggeringRender);

            bool hasValidStartTime = false;
            if (isProjectRendering) {
              final Timestamp? startTime = project.renderStartedAt;
              if (startTime != null) {
                hasValidStartTime = true;
                final int nowSeconds = Timestamp.now().seconds;
                final int startSeconds = startTime.seconds;
                final int elapsedSeconds = nowSeconds - startSeconds;
                final int remaining = _renderTimeoutDuration - elapsedSeconds;
                if (remaining <= 0) {
                  _cancelUiRefreshTimer();
                  WidgetsBinding.instance
                      .addPostFrameCallback((_) => _handleRenderTimeout());
                } else {
                  _startUiRefreshTimer(remaining);
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

                    if (isRenderComplete &&
                        finalVideoUrl != null &&
                        finalVideoUrl.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 12.0, horizontal: 16.0),
                        child: ElevatedButton.icon(
                          onPressed: () => _launchURL(finalVideoUrl),
                          icon: const Icon(Icons.download_for_offline),
                          label: Text(t('DOWNLOAD FINAL VIDEO', 'UNDUH VIDEO FINAL')),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
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
                        loading: () => Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(),
                              const SizedBox(height: 12),
                              Text(t("Calculating audio durations...", "Menghitung durasi audio...")),
                            ],
                          ),
                        ),
                        error: (error, stack) => Center(
                            child:
                                Text(t('Error loading timeline data: $error', 'Gagal memuat data timeline: $error'))),
                        data: (timelineData) {
                          _currentScenes = timelineData.scenes
                              .map((e) => e.originalScene)
                              .toList();
                          _currentProcessedScenes = timelineData.scenes;
                          final scenes = _currentScenes;

                          if (_currentImageUrl == null && scenes.isNotEmpty) {
                             _currentImageUrl = scenes.first.imageUrl;
                          }

                          if (scenes.isEmpty &&
                              project.status != 'PROCESSING_GENERATION' &&
                              project.status != 'PENDING_REFINEMENT') {
                            return Center(
                                child: Text(t("No scenes generated yet.", "Belum ada adegan yang dibuat.")));
                          } else if (scenes.isEmpty) {
                            return Center(
                                child: Text(t("Generating scenes...", "Membuat adegan...")));
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
                                                'ERROR_VISUALS' ||
                                            scene.status == 'ERROR_VISUALS_FINAL'; 
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
                                          ? Colors.blue.withOpacity(0.15)
                                          : (isSelectedManually
                                              ? Colors.white.withOpacity(0.08)
                                              : Colors.white.withOpacity(0.03)), 
                                      elevation:
                                          isCurrentlyPlayingInSequence
                                              ? 3
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
                                              CircleAvatar(
                                                radius: 12,
                                                backgroundColor: Colors.blueAccent.withOpacity(0.3),
                                                child: Text(
                                                  '${index + 1}',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Container(
                                                width: 80,
                                                height: 60,
                                                decoration: BoxDecoration(
                                                  color: Colors.black26,
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  border:
                                                      isCurrentlyPlayingInSequence
                                                          ? Border.all(
                                                              color: Colors.blueAccent,
                                                              width: 2)
                                                          : Border.all(
                                                              color: Colors.white12,
                                                              width: 1),
                                                ),
                                                child: (scene.imageUrl.isNotEmpty)
                                                    ? ClipRRect(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(8),
                                                        child: Image.network(
                                                          scene.imageUrl,
                                                          headers: const {},
                                                          fit: BoxFit.cover,
                                                          errorBuilder:
                                                              (c, e, s) {
                                                            debugPrint("Scene ${sceneIndex + 1} Image Error: $e");
                                                            return const Icon(
                                                                Icons.error_outline,
                                                                color: Colors.redAccent);
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
                                                                        strokeWidth: 3.0),
                                                              )
                                                            : const Icon(Icons.image_outlined, color: Colors.grey),
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
                                                        color: Colors.white,
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
                                                            style: const TextStyle(
                                                                fontSize: 10,
                                                                color: Colors.redAccent),
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
                                                          : Colors.grey[600]),
                                                  tooltip: t('Regenerate Asset', 'Regenerasi Aset'),
                                                  onPressed: !canRegenerate
                                                      ? null
                                                      : () {
                                                          _stopSequencePlayback();
                                                          _showRegenerateDialog(
                                                              scene);
                                                        },
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              // Tombol Download Gambar Scene (Hijau Terang)
                                              IconButton(
                                                icon: Icon(
                                                  Icons.download_for_offline_outlined,
                                                  color: scene.imageUrl.isNotEmpty
                                                      ? Colors.greenAccent.shade400
                                                      : Colors.grey[700],
                                                  size: 24,
                                                ),
                                                tooltip: scene.imageUrl.isNotEmpty
                                                    ? t('Download Image Scene ${index + 1}', 'Unduh Gambar Adegan ${index + 1}')
                                                    : t('Image not available', 'Gambar belum tersedia'),
                                                onPressed: scene.imageUrl.isNotEmpty
                                                    ? () => _launchURL(scene.imageUrl)
                                                    : null,
                                              ),
                                              const SizedBox(width: 4),
                                              // Tombol Bendera Lapor (Merah Tegas)
                                              IconButton(
                                                icon: const Icon(Icons.flag_outlined, 
                                                  color: Colors.redAccent, 
                                                  size: 20
                                                ),
                                                tooltip: t('Report Scene ${index + 1}', 'Lapor Adegan ${index + 1}'),
                                                onPressed: () => _showSceneReportDialog(scene),
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
                                          ? t('CALCULATING...', 'MENGHITUNG...')
                                          : (_isPlayingSequence
                                              ? t('PAUSE', 'JEDA')
                                              : t('PLAY ALL', 'PUTAR SEMUA'))),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _isPlayingSequence
                                            ? Colors.orangeAccent
                                            : Colors.blueAccent,
                                        foregroundColor: Colors.white,
                                        disabledBackgroundColor: Colors.grey.shade800,
                                        disabledForegroundColor: Colors.grey.shade500,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 12),
                                        textStyle: const TextStyle(
                                            fontSize: 15, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.replay),
                                      iconSize: 32,
                                      tooltip: t('Replay from Beginning', 'Putar Ulang dari Awal'),
                                      color: canPlayOrReplay
                                          ? Colors.cyanAccent
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
                                            backgroundColor: Colors.redAccent.shade700,
                                            foregroundColor: Colors.white,
                                            disabledBackgroundColor: Colors.grey.shade800,
                                            disabledForegroundColor: Colors.grey.shade600,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 20, vertical: 12),
                                            textStyle: const TextStyle(
                                                fontSize: 16, fontWeight: FontWeight.bold),
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
                                                    builder:
                                                        (BuildContext context) {
                                                      bool _isSaving = false;
                                                      String _loadingMessage = t("Saving render packet...", "Menyimpan paket render...");
                                                      return StatefulBuilder(
                                                        builder: (context,
                                                            setDialogState) {
                                                          return AlertDialog(
                                                            backgroundColor: const Color(0xFF1E222A),
                                                            shape: RoundedRectangleBorder(
                                                              borderRadius: BorderRadius.circular(16),
                                                              side: const BorderSide(color: Colors.white12),
                                                            ),
                                                            title: Text(
                                                              t('Start Video Render?', 'Mulai Render Video?'),
                                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                                            ),
                                                            content: Column(
                                                              mainAxisSize:
                                                                  MainAxisSize.min,
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children: [
                                                                Text(
                                                                  t(
                                                                    "This will assemble all final data (scenes, timing, and styles) and send it to the render queue.\n\nThis action cannot be undone.",
                                                                    "Ini akan merakit semua data akhir (adegan, waktu, dan gaya) lalu mengirimkannya ke antrean render.\n\nTindakan ini tidak dapat dibatalkan."
                                                                  ),
                                                                  style: const TextStyle(color: Colors.white70, fontSize: 14),
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
                                                                          height: 20,
                                                                          child:
                                                                              CircularProgressIndicator(
                                                                            strokeWidth: 3,
                                                                            color: Colors.blueAccent,
                                                                          ),
                                                                        ),
                                                                        const SizedBox(width: 12),
                                                                        Flexible(
                                                                          child: Text(
                                                                            _loadingMessage,
                                                                            style: const TextStyle(color: Colors.white70),
                                                                          ),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  ),
                                                              ],
                                                            ),
                                                            actions: <Widget>[
                                                              // [WARNA KONTRAS]: Tombol Cancel Oranye Terang Jelas di Atas Background Gelap
                                                              TextButton(
                                                                style: TextButton.styleFrom(
                                                                  foregroundColor: Colors.orangeAccent,
                                                                  textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                                                ),
                                                                child: Text(t('Cancel', 'Batal')),
                                                                onPressed: _isSaving
                                                                    ? null
                                                                    : () =>
                                                                        Navigator.of(context).pop(),
                                                              ),
                                                              ElevatedButton(
                                                                style: ElevatedButton.styleFrom(
                                                                  backgroundColor: Colors.redAccent.shade700,
                                                                  foregroundColor: Colors.white,
                                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                                ),
                                                                child: Text(
                                                                  _isSaving
                                                                      ? t('SAVING...', 'MENYIMPAN...')
                                                                      : t('RENDER', 'RENDER'),
                                                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                                                ),
                                                                onPressed: _isSaving
                                                                    ? null
                                                                    : () async {
                                                                        setDialogState(
                                                                          () {
                                                                            _isSaving = true;
                                                                            _loadingMessage = t("Saving render packet...", "Menyimpan paket render...");
                                                                          },
                                                                        );
                                                                        try {
                                                                          logger.info("Step 1/2: Preparing and saving full render packet for ${widget.projectId}...");
                                                                          await prepareAndSaveRenderPacket(ref, widget.projectId);
                                                                          setDialogState(
                                                                            () {
                                                                              _loadingMessage = t("Triggering backend render...", "Memicu backend render...");
                                                                            },
                                                                          );
                                                                          await Future.delayed(const Duration(milliseconds: 200));
                                                                          logger.info("Step 2/2: Updating status to RENDER_START for ${widget.projectId}...");
                                                                          await ref
                                                                              .read(firestoreServiceProvider)
                                                                              .updateProject(
                                                                                  widget.projectId,
                                                                                  {
                                                                                'status': 'RENDER_START',
                                                                                'renderStartedAt': FieldValue.serverTimestamp(),
                                                                                'errorDetail': FieldValue.delete()
                                                                              });
                                                                          logger.info("Render trigger successful for ${widget.projectId}");
                                                                          if (mounted) {
                                                                            Navigator.of(context).pop();
                                                                            setState(() {
                                                                              _isTriggeringRender = true;
                                                                            });
                                                                          }
                                                                        } catch (e) {
                                                                          logger.error("Failed to prepare or trigger render for ${widget.projectId}", e);
                                                                          if (mounted) {
                                                                            Navigator.of(context).pop();
                                                                            ScaffoldMessenger.of(context).showSnackBar(
                                                                              SnackBar(
                                                                                content: Text(t('Failed to send render packet: $e', 'Gagal mengirim paket render: $e')),
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
                                                    },
                                                  );
                                                },
                                          child: Text(t('RENDER', 'RENDER')),
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
                                                      child: Text(
                                                        t("✨ Finish & Export to MP4", "✨ Siap Render & Ekspor Video"),
                                                        style: const TextStyle(
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
                  _buildRenderingOverlay(hasValidStartTime, isIndo),
              ],
            );
          },
        ),
      ),
    );
  }
//----------------------------------------------------------------------------------------------------//

//No ke-6: HELPERS, RENDER LOGIC (MANUAL) & STYLING //
//Warna status, dialog regenerasi aset, dan logika kontrol Play/Pause/Resume audio tiap adegan. //
  Color _getStatusColor(String? status) {
    switch (status) {
      case 'COMPLETED':
        return Colors.green.shade400;
      case 'ERROR':
      case 'ERROR_AUDIO':
      case 'ERROR_VISUALS':
      case 'ERROR_REFINEMENT':
      case 'ERROR_RENDER':
        return Colors.redAccent;
      case 'PENDING_REGENERATION':
        return Colors.blueAccent;
      case 'GENERATING_VISUALS':
      case 'GENERATING_AUDIO':
      case 'PROCESSING_REFINEMENT':
      case 'PROCESSING_AUTO_RETRY':
      case 'GENERATING_THUMBNULL':
      case 'GENERATING_THUMBNAIL':
        return Colors.purpleAccent;
      case 'ASSETS_COMPLETE':
        return Colors.blueAccent;
      case 'RENDER_COMPLETED':
        return Colors.greenAccent;
      default:
        return Colors.grey.shade400;
    }
  }

  void _showRegenerateDialog(Scene scene) {
    final currentLocale = ref.read(appLanguageProvider);
    final isIndo = currentLocale.languageCode == 'id';
    String t(String en, String id) => isIndo ? id : en;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E222A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Colors.white12),
          ),
          title: Text(
            t('Regenerate Asset?', 'Regenerasi Aset?'),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Text(
            t(
              'This will re-create the image AND audio for scene ${scene.segmentIndex + 1}. Are you sure?',
              'Ini akan membuat ulang gambar DAN audio untuk adegan ${scene.segmentIndex + 1}. Apakah Anda yakin?'
            ),
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          actions: <Widget>[
            // [WARNA KONTRAS]: Tombol Cancel Oranye Terang
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.orangeAccent,
                textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              child: Text(t('Cancel', 'Batal')),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                t('Regenerate', 'Regenerasi'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
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
    final currentLocale = ref.read(appLanguageProvider);
    final isIndo = currentLocale.languageCode == 'id';
    String t(String en, String id) => isIndo ? id : en;

    final timelineDataAsync =
        ref.read(processedTimelineProvider(widget.projectId));
    final timelineData = timelineDataAsync.asData?.value;
    final double aspectRatioValue = _calculateAspectRatio(aspectRatioString);
    final styleData = ref
        .read(visualSettingsProvider(widget.projectId))
        .toJson(aspectRatioValue);
    if (timelineData == null || timelineData.isCalculating) {
      logger.error("Render failed: Timeline data is not ready or still calculating.");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('Error: Timeline data is not ready. Please wait and try again.', 'Error: Data timeline belum siap. Silakan tunggu sebentar.')),
          backgroundColor: Colors.red
        ),
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
          backgroundColor: const Color(0xFF1E222A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Colors.white12),
          ),
          title: Text(
            t('Start Video Render?', 'Mulai Render Video?'),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Text(
            t(
              'This will send the complete render packet to the backend to start final video generation.',
              'Ini akan mengirimkan seluruh paket render ke backend untuk memulai perakitan video final.'
            ),
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          actions: <Widget>[
            // [WARNA KONTRAS]: Tombol Cancel Oranye Terang
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.orangeAccent,
                textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              child: Text(t('Cancel', 'Batal')),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                t('RENDER', 'RENDER'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                try {
                  logger.info("Attempting update to RENDER_START for ${widget.projectId} with full render packet.");
                  ref
                      .read(firestoreServiceProvider)
                      .updateProject(widget.projectId,
                          {'renderPacket': renderPacket, 'status': 'RENDER_START'});
                  logger.info("Firestore update call finished for ${widget.projectId}");
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(t('Render request sent!', 'Permintaan render berhasil dikirim!')),
                        backgroundColor: Colors.green
                      ),
                    );
                  }
                } catch (e) {
                  logger.error("Failed to trigger render for ${widget.projectId}", e);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(t('Failed to send render request: $e', 'Gagal mengirim permintaan render: $e')),
                        backgroundColor: Colors.red
                      ),
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

  // [RESPONS INSTAN PLAY / PAUSE / RESUME 1X KLIK & WARNA TERANG KONTRAS]
  Widget _buildAudioControlButton(Scene scene, int sceneIndex) {
    final bool isThisSceneIndividualTarget = _isPlayingIndividual && _currentlyPlayingSceneId == scene.id;
    final bool isThisSceneSequenceTarget = _isPlayingSequence && !_isPlayingIntroBgm && _currentlyPlayingSceneId == scene.id;

    final bool isThisScenePlaying = isThisSceneSequenceTarget ||
        (isThisSceneIndividualTarget && _narrationPlayer.state != PlayerState.paused);

    final bool isThisScenePaused = isThisSceneIndividualTarget && _narrationPlayer.state == PlayerState.paused;

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
        icon: const Icon(Icons.volume_off, color: Colors.redAccent, size: 36),
        onPressed: null,
        tooltip: 'Audio failed to generate. Please regenerate.',
      );
    } else if (!canThisScenePlay) {
      return IconButton(
        icon: Icon(Icons.volume_off, color: Colors.grey[600], size: 36),
        onPressed: null,
        tooltip: 'No audio available or still pending',
      );
    }

    return IconButton(
      icon: Icon(
        isThisScenePlaying
            ? Icons.pause_circle_filled
            : Icons.play_circle_fill,
        color: isThisScenePaused
            ? Colors.orangeAccent
            : Colors.blueAccent,
        size: 36,
      ),
      tooltip: isThisScenePlaying
          ? 'Pause Scene ${sceneIndex + 1}'
          : (isThisScenePaused
              ? 'Resume Scene ${sceneIndex + 1}'
              : 'Play Scene ${sceneIndex + 1}'),
      onPressed: () {
        if (_isPlayingSequence) {
          _stopSequencePlayback(resetIndex: false);
        }

        if (isThisScenePlaying) {
          _narrationPlayer.pause();
          setState(() {});
        } else if (isThisScenePaused) {
          _narrationPlayer.resume();
          setState(() {});
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
            logger.error("Error playing individual audio for scene $sceneIndex: $e");
            if (mounted) {
              setState(() {
                _currentlyPlayingSceneId = null;
                _isPlayingIndividual = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to play audio for scene ${sceneIndex + 1}.'),
                  backgroundColor: Colors.red
                ),
              );
            }
          });
        }
      },
    );
  }
//----------------------------------------------------------------------------------------------------//

//No ke-7: REPORT SCENE LOGIC //
//Logika pelaporan konten pada scene dengan tombol kontras & bilingual. //
  void _showSceneReportDialog(Scene scene) {
    final currentLocale = ref.read(appLanguageProvider);
    final isIndo = currentLocale.languageCode == 'id';
    String t(String en, String id) => isIndo ? id : en;

    final TextEditingController reasonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E222A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.white12),
        ),
        title: Text(
          t("Report Scene ${scene.segmentIndex + 1}", "Lapor Adegan ${scene.segmentIndex + 1}"),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t(
                "Does the visual or narration violate policy?",
                "Apakah gambar atau narasi adegan ini melanggar kebijakan?"
              ),
              style: const TextStyle(fontSize: 14, color: Colors.white70),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                hintText: t("Reason (Violence, Sensitive content, etc)...", "Alasan (SARA, Kekerasan, dll)..."),
                border: const OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          // [WARNA KONTRAS]: Tombol Cancel Oranye Terang
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Colors.orangeAccent,
              textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: Text(t("Cancel", "Batal")),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              final user = ref.read(firestoreUserProvider).valueOrNull;
              final userId = user?.uid ?? 'anonymous'; 

              FirebaseFirestore.instance.collection('reports').add({
                'projectId': widget.projectId,
                'sceneId': scene.id,
                'content': scene.imageUrl, 
                'contentType': 'scene_image',
                'reason': reasonController.text.isEmpty ? 'No reason provided' : reasonController.text,
                'reportedAt': FieldValue.serverTimestamp(),
                'userId': userId,
                'feature': 'Timeline Review', 
              }).then((_) {
                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(t("Report submitted. Thank you.", "Laporan dikirim. Terima kasih.")),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              });
            },
            child: Text(t("Report", "Lapor"), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
//----------------------------------------------------------------------------------------------------//

//No ke-8: DUMMY LOGGER //
//Utilitas logger sementara untuk output debug. //
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
//----------------------------------------------------------------------------------------------------//
