//................................................................//
// NAMA FILE: TIMELINE_REVIEW_STORINEMA_SCREEN.DART               //
// PATH: LIB/SCREENS_STORINEMA/TIMELINE_REVIEW_STORINEMA_SCREEN.DART //
// DESKRIPSI: SMART CONTROLLER, NATIVE VIDEO TIMELINE, TEXT/SUBS  //
//................................................................//

//................................................................//
// NAMA FILE: TIMELINE_REVIEW_STORINEMA_SCREEN.DART               //
// PATH: LIB/SCREENS_STORINEMA/TIMELINE_REVIEW_STORINEMA_SCREEN.DART //
// DESKRIPSI: SMART CONTROLLER, NATIVE VIDEO TIMELINE, TEXT/SUBS  //
//................................................................//

//No ke-1.........................................................//
// IMPORTS, CONSTANTS & PROVIDERS                                 //
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart'; 
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart'; 

// --- [SUNTIKAN BARU: LIBRARY UNTUK FORCE DOWNLOAD WEB] ---
import 'package:universal_html/html.dart' as html;

import '../theme/app_theme.dart';
import '../models_storinema/scene_storinema.dart';
import '../services_storinema/firestore_storinema_service.dart';
import '../view_model_storinema/timeline_storinema_view_model.dart';
import '../providers_storinema/visual_settings_storinema_provider.dart';
import '../providers_storinema/firestore_storinema_provider.dart';
import '../providers_storinema/timeline_storinema_providers.dart';

import 'visual_setting_storinema_screen.dart';
import '../providers/user_provider.dart';
import '../providers/config_provider.dart'; // [BARU]: Membaca konfigurasi tarif token Storinema

final selectedSceneStorinemaProvider = StateProvider.autoDispose<SceneStorinema?>((ref) => null);
//................................................................//

//No ke-2.........................................................//
// MAIN CLASS DEFINITION & INITIALIZATION                         //
class TimelineReviewStorinemaScreen extends ConsumerStatefulWidget {
  final String projectId;
  const TimelineReviewStorinemaScreen({super.key, required this.projectId});

  @override
  ConsumerState<TimelineReviewStorinemaScreen> createState() =>
      _TimelineReviewStorinemaScreenState();
}

class _TimelineReviewStorinemaScreenState extends ConsumerState<TimelineReviewStorinemaScreen> {
  // [PERBAIKAN]: _narrationPlayer dikembalikan untuk mendengarkan Google TTS
  late AudioPlayer _bgmPlayer; 
  late AudioPlayer _narrationPlayer; 
  
  VideoPlayerController? _videoController;

  bool _isPlayingIndividual = false;
  String? _currentlyPlayingSceneId;
  bool _isPlayingSequence = false;
  int _currentSequenceIndex = -1;
  List<SceneStorinema> _currentScenes = [];
  List<ProcessedSceneDataStorinema> _currentProcessedScenes = [];
  bool _isPlayingIntroBgm = false;
  double _currentPlaybackTime = 0.0;
  Timer? _playbackTimer;
  
  bool _showTitleOverlay = false;
  bool _showDescriptionOverlay = false;
  bool _showSubtitleOverlay = false;
  String _currentSubtitleText = "";
  int _currentSubtitleMaxLines = 4;
  
  String? _currentMediaUrl; 
  
  bool _isTriggeringRender = false;
  bool _hasAutoTriggeredRender = false; 
  static const int _renderTimeoutDuration = 3600;
  Timer? _uiRefreshTimer;
  bool _hasDismissedRenderPopup = false; 
  
  bool _isSceneTransitioning = false; 

  @override
  void initState() {
    super.initState();
    _bgmPlayer = AudioPlayer();
    _narrationPlayer = AudioPlayer();

    _bgmPlayer.onPlayerComplete.listen((event) {
      if (mounted && _isPlayingSequence && _isPlayingIntroBgm) {
        logger.info("Intro BGM finished. Starting scene 0.");
        
        final timelineData = ref.read(processedTimelineStorinemaProvider(widget.projectId)).asData?.value;
        final introDuration = timelineData?.introDuration ?? 0.0;
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
//................................................................//

//No ke-3.........................................................//
// TIMERS, UTILITIES & TIMEOUT HANDLER                            //
  void _startUiRefreshTimer() {
    if (_uiRefreshTimer != null && _uiRefreshTimer!.isActive) return;
    _uiRefreshTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() {}); else timer.cancel();
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
      final firestore = ref.read(firestoreStorinemaServiceProvider);
      final projectDoc = await firestore.getProject(widget.projectId);
      final currentStatus = projectDoc?['status'];
      if (currentStatus == 'RENDER_START' || currentStatus == 'RENDERING') {
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
      logger.error("Failed to set ERROR_RENDER: $e");
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
    if (time < _currentPlaybackTime && (_currentPlaybackTime - time).abs() > 0.1) {
      if (_playbackTimer?.isActive ?? false) return;
    }
    _currentPlaybackTime = time;
    _updateOverlayVisibility();
  }

  void _updateOverlayVisibility() {
    if (!mounted) return;
    final settings = ref.read(visualSettingsStorinemaProvider(widget.projectId));
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
        final double chunkAbsoluteStartTime = sceneAbsoluteStartTime + (chunk as dynamic).startTime;
        final double chunkAbsoluteEndTime = chunkAbsoluteStartTime + (chunk as dynamic).duration;
        if (_currentPlaybackTime >= chunkAbsoluteStartTime && _currentPlaybackTime < chunkAbsoluteEndTime) {
          shouldShowSubtitle = true;
          subtitleText = chunk.text;
          _currentSubtitleMaxLines = settings.subtitleMaxLines;
          break;
        }
      }
    }
    
    if (!shouldShowSubtitle && _currentSubtitleMaxLines != settings.subtitleMaxLines) {
      _currentSubtitleMaxLines = settings.subtitleMaxLines;
    }
    
    if (_showSubtitleOverlay != shouldShowSubtitle ||
        (_showSubtitleOverlay && _currentSubtitleText != subtitleText)) {
      _showSubtitleOverlay = shouldShowSubtitle;
      _currentSubtitleText = subtitleText;
      needsSetState = true;
    }
    if (needsSetState) setState(() {});
  }

  void _startPlaybackTimer() {
    _playbackTimer?.cancel();
    const tickDuration = Duration(milliseconds: 50);
    _playbackTimer = Timer.periodic(tickDuration, (timer) {
      if (!mounted || !_isPlayingSequence) {
        timer.cancel();
        return;
      }
      final newTime = _currentPlaybackTime + (tickDuration.inMilliseconds / 1000.0);
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
    _uiRefreshTimer?.cancel();
    _videoController?.dispose(); 
    _bgmPlayer.dispose();
    _narrationPlayer.dispose();
    super.dispose();
  }
//................................................................//

//No ke-4.........................................................//
// PLAYBACK & NATIVE VIDEO LOGIC (MP4 LISTENER)                   //

  void _onVideoPlayerComplete() {
    if (_videoController == null || !_videoController!.value.isInitialized) return;
    
    if (_videoController!.value.position >= _videoController!.value.duration) {
      if (_isSceneTransitioning) return; 
      _isSceneTransitioning = true;
      _narrationPlayer.stop(); 
      
      if (_isPlayingIndividual) {
        setState(() { _isPlayingIndividual = false; });
      }

      if (_isPlayingSequence && !_isPlayingIntroBgm) {
        if (_currentSequenceIndex < _currentProcessedScenes.length) {
          final processedScene = _currentProcessedScenes[_currentSequenceIndex];
          _updatePlaybackTime(processedScene.absoluteEndTime);
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
  }

  void _startOrResumeSequencePlayback() async {
    if (_currentSequenceIndex == -1) _updatePlaybackTime(0.0);
    if (_currentScenes.isEmpty && _currentSequenceIndex != -1) return;

    if (_currentSequenceIndex == -1) {
      _stopSequencePlayback(resetIndex: true);
      ref.read(selectedSceneStorinemaProvider.notifier).state = null;
      setState(() {
        _isPlayingSequence = true;
        _isPlayingIntroBgm = false;
        _currentPlaybackTime = 0.0;
      });
      _startPlaybackTimer();
      if (_currentScenes.isNotEmpty) _playSceneAtIndex(0);
      else _stopSequencePlayback();
      
    } else if (!_isPlayingSequence && !_isPlayingIntroBgm && _currentSequenceIndex >= 0) {
      _videoController?.play(); 
      _narrationPlayer.resume(); 
      setState(() => _isPlayingSequence = true);
      _startPlaybackTimer();
      
    } else if (!_isPlayingSequence && _isPlayingIntroBgm && _currentSequenceIndex == -1) {
      _bgmPlayer.resume();
      setState(() => _isPlayingSequence = true);
      _startPlaybackTimer();
    }
  }

  void _pauseSequencePlayback() {
    if (!_isPlayingSequence) return;
    _playbackTimer?.cancel();
    _videoController?.pause(); 
    _narrationPlayer.pause(); 
    
    if (_isPlayingIntroBgm) _bgmPlayer.pause();
    setState(() => _isPlayingSequence = false);
  }

  void _stopSequencePlayback({bool resetIndex = true}) {
    _playbackTimer?.cancel();
    _updatePlaybackTime(0.0);
    _videoController?.pause();
    _bgmPlayer.stop();
    _narrationPlayer.stop(); 
    
    if (mounted) {
      setState(() {
        _isPlayingSequence = false;
        _isPlayingIntroBgm = false;
        _isPlayingIndividual = false;
        _currentlyPlayingSceneId = null;
        if (resetIndex) {
          _currentMediaUrl = null;
          _currentSequenceIndex = -1;
        }
      });
      if (resetIndex) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) ref.read(selectedSceneStorinemaProvider.notifier).state = null;
        });
      }
    }
  }

  void _replaySequence() {
    _stopSequencePlayback(resetIndex: true);
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _startOrResumeSequencePlayback();
    });
  }

  void _playSceneAtIndex(int sceneIndex) {
    if (!_isPlayingSequence || _isPlayingIntroBgm || sceneIndex < 0 || sceneIndex >= _currentScenes.length) {
      _stopSequencePlayback();
      return;
    }
    
    _isSceneTransitioning = false; 
    final scene = _currentScenes[sceneIndex];
    if (!mounted) return;
    
    ref.read(selectedSceneStorinemaProvider.notifier).state = scene;
    
    final String mediaUrl = (scene as dynamic).videoUrl ?? ''; 
    final String audioUrl = (scene as dynamic).ttsAudioUrl ?? ''; 
    
    setState(() {
      _currentSequenceIndex = sceneIndex;
      _currentlyPlayingSceneId = scene.id;
      _isPlayingIndividual = false;
      _currentMediaUrl = mediaUrl;
    });
    
    _videoController?.removeListener(_onVideoPlayerComplete);
    _videoController?.dispose();
    _narrationPlayer.stop(); 
    
    if (mediaUrl.isNotEmpty) {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(mediaUrl))
        ..initialize().then((_) {
          if (mounted) {
            _videoController!.addListener(_onVideoPlayerComplete);
            _videoController!.play();
            if (audioUrl.isNotEmpty && audioUrl != 'EMPTY') {
              _narrationPlayer.play(UrlSource(audioUrl));
            }
            setState(() {}); 
          }
        }).catchError((e) {
          logger.error("Error initializing video player: $e");
          _handlePlaybackErrorOrSkip(sceneIndex);
        });
    } else {
      logger.warn("Scene $sceneIndex has no video URL, skipping after delay.");
      _handlePlaybackErrorOrSkip(sceneIndex);
    }

    _updateOverlayVisibility();
  }

  void _handlePlaybackErrorOrSkip(int currentSceneIndex) {
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted && _isPlayingSequence && !_isPlayingIntroBgm && _currentSequenceIndex == currentSceneIndex) {
        _videoController?.pause();
        _narrationPlayer.stop();
        if (currentSceneIndex < _currentProcessedScenes.length) {
          final processedScene = _currentProcessedScenes[currentSceneIndex];
          _updatePlaybackTime(processedScene.absoluteEndTime);
        }
        final nextIndex = _currentSequenceIndex + 1;
        if (nextIndex < _currentScenes.length) _playSceneAtIndex(nextIndex);
        else _stopSequencePlayback();
      }
    });
  }

  // --- [SISTEM DOWNLOAD: DIALIHKAN KE TAB BARU SECARA PRESISI] ---
  Future<void> _launchURL(String urlString) async {
    if (kIsWeb) {
      try {
        html.window.open(urlString, '_blank');
        return;
      } catch (_) {}
    }
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(
      url, 
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    )) {
      if (mounted) {
        final currentLocale = ref.read(appLanguageProvider);
        final isIndo = currentLocale.languageCode == 'id';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isIndo ? 'Tidak dapat membuka link: $urlString' : 'Could not open link: $urlString'), 
            backgroundColor: Colors.red
          ),
        );
      }
    }
  }

  double _calculateAspectRatio(String? ratioString) {
    if (ratioString == null || ratioString.isEmpty) return 16 / 9;
    final parts = ratioString.split(':');
    if (parts.length == 2) {
      final double? width = double.tryParse(parts[0]);
      final double? height = double.tryParse(parts[1]);
      if (width != null && height != null && height != 0) return width / height;
    }
    return 16 / 9;
  }
//................................................................//

//No ke-5.........................................................//
// BUILD UI, WIDGETS & GATEKEEPER LOGIC                           //
  Widget _buildVideoViewer(String? mediaUrl, {Key? key}) {
    if (mediaUrl == null || mediaUrl.isEmpty) {
      return Tooltip(
        key: key,
        message: 'Video is rendering or missing...',
        child: const Icon(Icons.movie_creation_outlined, color: Colors.white24, size: 80),
      );
    }

    if (_videoController != null && _videoController!.value.isInitialized) {
      return SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover, 
          child: SizedBox(
            width: _videoController!.value.size.width,
            height: _videoController!.value.size.height,
            child: VideoPlayer(_videoController!),
          ),
        ),
      );
    } else {
      return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
    }
  }

  Widget _buildRenderingOverlay(int secondsRemaining, bool hasValidStartTime, bool isWaitingForUrl) {
    final currentLocale = ref.watch(appLanguageProvider);
    final isIndo = currentLocale.languageCode == 'id';
    String t(String en, String id) => isIndo ? id : en;

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
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: Colors.blueAccent), 
                  const SizedBox(height: 16),
                  Text(
                    isWaitingForUrl ? t("Preparing Download Link...", "Menyiapkan Link Download...") : t("Rendering Final Video...", "Rendering Final Video..."), 
                    style: const TextStyle(fontSize: 16, color: Colors.white)
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "${t('Auto Cancel in:', 'Batal Otomatis dalam:')} ${_formatDuration(secondsRemaining)}", 
                    style: const TextStyle(fontSize: 14, color: Colors.white70)
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
    final currentLocale = ref.watch(appLanguageProvider);
    final isIndo = currentLocale.languageCode == 'id';
    String t(String en, String id) => isIndo ? id : en;

    final projectAsyncValue = ref.watch(projectStorinemaStreamProvider(widget.projectId));
    final processedTimelineAsync = ref.watch(processedTimelineStorinemaProvider(widget.projectId));
    final visualSettings = ref.watch(visualSettingsStorinemaProvider(widget.projectId));
    final projectData = projectAsyncValue.asData?.value;
    
    final bool isCalculating = processedTimelineAsync.asData?.value?.isCalculating ?? true;

    final bool areAllScenesValid = processedTimelineAsync.maybeWhen(
      data: (timeline) {
        if (timeline.scenes.isEmpty) return false; 
        return timeline.scenes.every((s) {
          final scene = s.originalScene;
          final String vUrl = (scene as dynamic).videoUrl ?? '';
          final hasValidMedia = vUrl.isNotEmpty; 
          final hasNoErrors = scene.status == null || !scene.status!.startsWith('ERROR');
          final isNotGenerating = scene.status != 'PENDING_REFINEMENT' &&
                                  scene.status != 'QUEUED_FOR_REFINE' &&
                                  scene.status != 'IS_REFINING' &&
                                  scene.status != 'QUEUED_FOR_VIDEO' &&
                                  scene.status != 'GENERATING_VIDEO' &&
                                  scene.status != 'WAITING_AUDIO';
          return hasValidMedia && hasNoErrors && isNotGenerating;
        });
      },
      orElse: () => false,
    );

    final bool isRenderSuccessGlobal = projectData != null &&
        projectData.status == 'RENDER_COMPLETED' &&
        projectData.finalVideoUrl != null &&
        projectData.finalVideoUrl!.isNotEmpty;

    // [PENJAGA ANTI-LOOP AUTO-RENDER]: Render otomatis HANYA di awal saat project baru
    final bool hasAlreadyRendered = projectData != null && 
        projectData.finalVideoUrl != null && 
        projectData.finalVideoUrl!.isNotEmpty;

    if (projectData != null && 
        projectData.status == 'ASSETS_COMPLETE' && 
        !hasAlreadyRendered && 
        areAllScenesValid && 
        !_hasAutoTriggeredRender && 
        !_isTriggeringRender) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        setState(() { _hasAutoTriggeredRender = true; _isTriggeringRender = true; });
        try {
          await prepareAndSaveRenderStorinemaPacket(ref, widget.projectId);
          await ref.read(firestoreStorinemaServiceProvider).updateProject(
            widget.projectId, {'status': 'RENDER_READY', 'renderReadyAt': FieldValue.serverTimestamp()}
          );
        } catch (e) {
          if (mounted) setState(() { _isTriggeringRender = false; _hasAutoTriggeredRender = false; });
        }
      });
    }

    final bool canPlayOrReplay = projectData != null && !isCalculating && areAllScenesValid && !isRenderSuccessGlobal;
    final double aspectRatioValue = _calculateAspectRatio(projectData?.aspectRatio);
    const double previewScaleFactor = 0.2315;

    TextStyle _getTextStyle(double baseFontSize, Color color) {
      final double previewFontSize = baseFontSize * previewScaleFactor;
      return TextStyle(fontSize: previewFontSize, color: color, fontWeight: FontWeight.bold, shadows: const [Shadow(blurRadius: 3.0, color: Colors.black87, offset: Offset(1.5, 1.5))]);
    }

    final double transitionDurationSeconds = visualSettings.transitionDuration;

    return Theme(
      data: AppTheme.darkTheme,
      child: Scaffold(
        appBar: AppBar(
          title: Text(t('Review Project (Storinema)', 'Tinjau Proyek (Storinema)')),
          actions: [
            IconButton(
              icon: const Icon(Icons.tune),
              tooltip: t('Visual Settings', 'Pengaturan Visual'),
              onPressed: () {
                _stopSequencePlayback();
                _cancelUiRefreshTimer();
                Navigator.push(context, MaterialPageRoute(builder: (context) => VisualSettingStorinemaScreen(projectId: widget.projectId)));
              },
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: projectAsyncValue.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(child: Text(t('Error loading project: $error', 'Gagal memuat proyek: $error'))),
          data: (project) {
            if (project == null) return Center(child: Text(t("Error: Failed to load project.", "Error: Proyek gagal dimuat."), style: const TextStyle(color: Colors.red)));

            if (_isTriggeringRender && (
                project.status == 'RENDERING' || 
                project.status == 'RENDER_START' || 
                project.status == 'RENDER_COMPLETED' || 
                project.status == 'ERROR_RENDER'
            )) {
              WidgetsBinding.instance.addPostFrameCallback((_) { 
                if (mounted) setState(() => _isTriggeringRender = false); 
              });
            }
            
            final bool isRenderSuccess = project.status == 'RENDER_COMPLETED' && project.finalVideoUrl != null && project.finalVideoUrl!.isNotEmpty;
            final bool isRenderComplete = isRenderSuccess;
            final String? finalVideoUrl = project.finalVideoUrl;
            
            final bool isWaitingForUrl = project.status == 'RENDER_COMPLETED' && 
                                         (project.finalVideoUrl == null || project.finalVideoUrl!.isEmpty);

            final bool isProjectRendering = (
              project.status == 'RENDER_READY' || 
              project.status == 'RENDER_START' || 
              project.status == 'RENDERING' || 
              isWaitingForUrl || 
              _isTriggeringRender
            );

            bool hasValidStartTime = false;
            int secondsRemainingForOverlay = _renderTimeoutDuration;
            if (isProjectRendering) {
              final Timestamp? startTime = project.renderStartedAt;
              if (startTime != null) {
                hasValidStartTime = true;
                final int elapsedSeconds = Timestamp.now().seconds - startTime.seconds;
                secondsRemainingForOverlay = (_renderTimeoutDuration - elapsedSeconds);
                if (secondsRemainingForOverlay <= 0) {
                  _cancelUiRefreshTimer();
                  WidgetsBinding.instance.addPostFrameCallback((_) => _handleRenderTimeout());
                } else _startUiRefreshTimer();
              } else _cancelUiRefreshTimer();
            } else _cancelUiRefreshTimer();

            // --- [STREAM BUILDER: MEMBACA MAP DATA FIRESTORE SECARA LANGSUNG & REALTIME] ---
            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection('projects_storinema').doc(widget.projectId).snapshots(),
              builder: (context, projectSnap) {
                final Map<String, dynamic>? projectMap = projectSnap.data?.data();
                final bool needsReRender = projectMap?['needsReRender'] ?? false;

                // LOGIKA TOMBOL RENDER (ON saat klip baru selesai & OFF setelah render selesai)
                final bool canRender;
                if (isProjectRendering) {
                  canRender = false;
                } else if (needsReRender) {
                  canRender = areAllScenesValid;
                } else if (project.status == 'ASSETS_COMPLETE' && (project.finalVideoUrl == null || project.finalVideoUrl!.isEmpty)) {
                  canRender = areAllScenesValid;
                } else if (project.status == 'ERROR_RENDER') {
                  canRender = areAllScenesValid;
                } else {
                  canRender = false;
                }

                return Stack(
                  children: [
                    Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                          child: Text(visualSettings.titleSettings.text, style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
                        ),

                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 250),
                              child: AspectRatio(
                                aspectRatio: aspectRatioValue,
                                child: Container(
                                  decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400, width: 2.0), color: Colors.black87),
                                  child: ClipRRect(
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        AnimatedSwitcher(
                                          duration: Duration(milliseconds: (transitionDurationSeconds * 1000).round()),
                                          transitionBuilder: (Widget child, Animation<double> animation) => FadeTransition(opacity: animation, child: child),
                                          child: _buildVideoViewer(_currentMediaUrl, key: ValueKey<String?>(_currentMediaUrl)),
                                        ),
                                        AnimatedOpacity(
                                          key: ValueKey('title_${_showTitleOverlay}'),
                                          opacity: _showTitleOverlay ? 1.0 : 0.0,
                                          duration: const Duration(milliseconds: 300),
                                          child: Visibility(
                                            visible: _showTitleOverlay,
                                            maintainState: false, maintainAnimation: false,
                                            child: Align(
                                              alignment: Alignment(0.0, visualSettings.titleSettings.verticalAlignment),
                                              child: FractionallySizedBox(
                                                widthFactor: visualSettings.titleSettings.textBlockWidthFactor,
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(4)),
                                                  child: Text(visualSettings.titleSettings.text, style: _getTextStyle(visualSettings.titleSettings.baseFontSize, visualSettings.titleSettings.color), textAlign: TextAlign.center, maxLines: visualSettings.titleSettings.maxLines, overflow: TextOverflow.ellipsis),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        AnimatedOpacity(
                                          key: ValueKey('desc_${_showDescriptionOverlay}'),
                                          opacity: _showDescriptionOverlay ? 1.0 : 0.0,
                                          duration: const Duration(milliseconds: 300),
                                          child: Visibility(
                                            visible: _showDescriptionOverlay,
                                            maintainState: false, maintainAnimation: false,
                                            child: Align(
                                              alignment: Alignment(0.0, visualSettings.descriptionSettings.verticalAlignment),
                                              child: FractionallySizedBox(
                                                widthFactor: visualSettings.descriptionSettings.textBlockWidthFactor,
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(4)),
                                                  child: Text(visualSettings.descriptionSettings.text, style: _getTextStyle(visualSettings.descriptionSettings.baseFontSize, visualSettings.descriptionSettings.color), textAlign: TextAlign.center, maxLines: visualSettings.descriptionSettings.maxLines, overflow: TextOverflow.ellipsis),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        Align(
                                          alignment: Alignment(0.0, visualSettings.subtitleVerticalAlignment),
                                          child: AnimatedOpacity(
                                            opacity: _showSubtitleOverlay ? 1.0 : 0.0,
                                            duration: const Duration(milliseconds: 200),
                                            child: Visibility(
                                              visible: _showSubtitleOverlay,
                                              child: FractionallySizedBox(
                                                widthFactor: visualSettings.subtitleBlockWidthFactor,
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(4)),
                                                  child: Text(_currentSubtitleText, style: TextStyle(fontSize: (visualSettings.subtitleBaseFontSize) * previewScaleFactor, color: Colors.white, shadows: const [Shadow(blurRadius: 3.0, color: Colors.black87, offset: Offset(1.5, 1.5))]), textAlign: TextAlign.center, maxLines: visualSettings.subtitleMaxLines, overflow: TextOverflow.ellipsis),
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

                        if (isRenderComplete && finalVideoUrl != null && finalVideoUrl.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                            child: ElevatedButton.icon(
                              onPressed: () => _launchURL(finalVideoUrl), 
                              icon: const Icon(Icons.open_in_new),
                              label: Text(t('DOWNLOAD FINAL VIDEO', 'UNDUH VIDEO FINAL')),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade700, 
                                foregroundColor: Colors.white, 
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                              ),
                            ),
                          ),

                        const Divider(height: 1, thickness: 1),

                        Expanded(
                          child: processedTimelineAsync.when(
                            skipLoadingOnReload: true,
                            loading: () => const Center(child: CircularProgressIndicator()),
                            error: (error, stack) => Center(child: Text(t('Error loading timeline data: $error', 'Gagal memuat data timeline: $error'))),
                            data: (timelineData) {
                              _currentScenes = timelineData.scenes.map((e) => e.originalScene).toList();
                              _currentProcessedScenes = timelineData.scenes;
                              final scenes = _currentScenes;

                              if (_currentMediaUrl == null && scenes.isNotEmpty) {
                                 _currentMediaUrl = (scenes.first as dynamic).videoUrl; 
                                 if (_currentMediaUrl != null && _currentMediaUrl!.isNotEmpty) {
                                   WidgetsBinding.instance.addPostFrameCallback((_) {
                                     if (mounted) _initializeFirstPreview(_currentMediaUrl!);
                                   });
                                 }
                              }

                              if (scenes.isEmpty) return Center(child: Text(t("Generating scenes...", "Membuat adegan...")));

                              // --- [BANNER PERINGATAN SCENE ERROR] ---
                              final bool hasErrorScenes = scenes.any((s) => s.status != null && s.status!.startsWith('ERROR'));
                              final bool showWarningBanner = (project.status == 'ASSETS_NEED_REFINEMENT' || hasErrorScenes) && !_isTriggeringRender && !isProjectRendering;
                              
                              return Column(
                                children: [
                                  if (showWarningBanner)
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                      color: Colors.orange.shade800,
                                      child: Row(
                                        children: [
                                          const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 28),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              t(
                                                "Some scenes failed to process. Please tap the Regenerate button on the affected scene below.",
                                                "Beberapa scene gagal diproses. Silakan tekan tombol Regenerate pada scene yang bermasalah di bawah ini."
                                              ),
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  Expanded(
                                    child: ListView.builder(
                                      itemCount: scenes.length,
                                      itemBuilder: (context, index) {
                                        final sceneIndex = index;
                                        final scene = scenes[sceneIndex];
                                        final isCurrentlyPlaying = _isPlayingSequence && !_isPlayingIntroBgm && _currentSequenceIndex == sceneIndex;
                                        final bool isSelectedManually = ref.watch(selectedSceneStorinemaProvider)?.id == scene.id && !_isPlayingSequence;

                                        final bool isSceneInError = scene.status != null && scene.status!.startsWith('ERROR'); 
                                        final bool showRegenerateButton = isSceneInError;
                                        final bool isProjectBusy = (project.status?.contains('GENERATING') ?? false) || 
                                                                   (project.status == 'RENDER_READY') || 
                                                                   (project.status == 'RENDER_START') || 
                                                                   (project.status == 'RENDERING') ||
                                                                   (scene.status == 'PENDING_REFINEMENT') ||
                                                                   (scene.status == 'GENERATING_VIDEO');
                                        final bool canRegenerate = showRegenerateButton && !isProjectBusy;
                                        
                                        final String cardVideoUrl = (scene as dynamic).videoUrl ?? '';
                                        final String cardAudioUrl = (scene as dynamic).ttsAudioUrl ?? '';
                                                
                                        return Card(
                                          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          color: isCurrentlyPlaying ? Colors.lightBlue[50] : (isSelectedManually ? Colors.grey[200] : null), 
                                          elevation: isCurrentlyPlaying ? 4 : (isSelectedManually ? 2 : 1),
                                          child: InkWell(
                                            onTap: () {
                                              if (_isPlayingSequence) _stopSequencePlayback(resetIndex: false);
                                              ref.read(selectedSceneStorinemaProvider.notifier).state = scene;
                                              setState(() {
                                                _currentSequenceIndex = sceneIndex;
                                                _currentMediaUrl = cardVideoUrl;
                                              });
                                            },
                                            child: Padding(
                                              padding: const EdgeInsets.all(8.0),
                                              child: Row(
                                                children: [
                                                  CircleAvatar(radius: 12, backgroundColor: Colors.grey[400], child: Text('${index + 1}', style: const TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold))),
                                                  const SizedBox(width: 12),
                                                  Container(
                                                    width: 80, height: 60,
                                                    decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(8)),
                                                    child: Center(
                                                      child: cardVideoUrl.isNotEmpty
                                                        ? const Icon(Icons.movie_creation, color: Colors.blueAccent, size: 30)
                                                        : const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3.0)),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  _buildScenePlayButton(scene, sceneIndex, cardVideoUrl, cardAudioUrl),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(scene.segmentText ?? "", style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 14, color: isCurrentlyPlaying ? Colors.black87 : null), maxLines: 2, overflow: TextOverflow.ellipsis),
                                                        const SizedBox(height: 4),
                                                        Text(scene.status ?? "Unknown", style: TextStyle(fontSize: 12, color: _getStatusColor(scene.status), fontWeight: FontWeight.bold)),
                                                      ],
                                                    ),
                                                  ),
                                                  // --- [TOMBOL REGENERATE ORANYE KHUSUS ERROR SCENE] ---
                                                  Visibility(
                                                    visible: showRegenerateButton,
                                                    child: Container(
                                                      decoration: BoxDecoration(
                                                        color: canRegenerate ? Colors.orange.withOpacity(0.2) : Colors.transparent,
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: IconButton(
                                                        tooltip: t('Regenerate AI Video (Error Recovery)', 'Regenerate Video AI (Pemulihan Error)'),
                                                        icon: Icon(
                                                          Icons.refresh, 
                                                          color: canRegenerate ? Colors.deepOrange : Colors.grey[400], 
                                                          size: 26, 
                                                        ), 
                                                        onPressed: !canRegenerate ? null : () { 
                                                          _stopSequencePlayback(); 
                                                          _showRegenerateDialog(scene); 
                                                        }
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  // --- [TOMBOL DOWNLOAD HIJAU NEON MODERN (TAB BARU)] ---
                                                  IconButton(
                                                    padding: EdgeInsets.zero,
                                                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                                    tooltip: t('Download Clip (New Tab)', 'Unduh Klip (Tab Baru)'),
                                                    icon: Icon(
                                                      Icons.download_rounded, 
                                                      color: cardVideoUrl.isNotEmpty ? Colors.greenAccent.shade400 : Colors.grey[700], 
                                                      size: 24
                                                    ),
                                                    onPressed: cardVideoUrl.isNotEmpty
                                                        ? () => _launchURL(cardVideoUrl)
                                                        : null,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  // --- [TOMBOL REGENERATE BIRU ELEGAN (BERBAYAR 1 SEGMEN)] ---
                                                  IconButton(
                                                    padding: EdgeInsets.zero,
                                                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                                    tooltip: t('Regenerate Clip', 'Regenerate Klip'),
                                                    icon: Icon(
                                                      Icons.refresh_rounded, 
                                                      color: isProjectBusy ? Colors.grey[700] : Colors.blueAccent, 
                                                      size: 26
                                                    ),
                                                    onPressed: isProjectBusy ? null : () {
                                                      _stopSequencePlayback();
                                                      _showPaidRegenerateDialog(scene, project, projectMap);
                                                    },
                                                  ),
                                                  const SizedBox(width: 4),
                                                  // --- [TOMBOL LAPOR MERAH (BENDERA)] ---
                                                  IconButton(
                                                    padding: EdgeInsets.zero,
                                                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                                    tooltip: t('Report Scene', 'Lapor Scene'),
                                                    icon: const Icon(Icons.flag_outlined, color: Colors.redAccent, size: 20),
                                                    onPressed: () => _showSceneReportDialog(scene, cardVideoUrl),
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
                                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                      children: [
                                        ElevatedButton.icon(
                                          onPressed: !canPlayOrReplay ? null : () { if (_isPlayingSequence) _pauseSequencePlayback(); else _startOrResumeSequencePlayback(); },
                                          icon: Icon(isCalculating ? Icons.hourglass_top : (_isPlayingSequence ? Icons.pause : Icons.play_arrow)),
                                          label: Text(isCalculating ? t('CALCULATING...', 'MENGHITUNG...') : (_isPlayingSequence ? t('PAUSE', 'JEDA') : t('PLAY ALL', 'PUTAR SEMUA'))),
                                          style: ElevatedButton.styleFrom(backgroundColor: _isPlayingSequence ? Colors.orangeAccent : Theme.of(context).colorScheme.primary, foregroundColor: Colors.white),
                                        ),
                                        IconButton(icon: const Icon(Icons.replay), iconSize: 32, color: canPlayOrReplay ? Theme.of(context).colorScheme.secondary : Colors.grey, onPressed: !canPlayOrReplay ? null : _replaySequence),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red.shade700, 
                                            foregroundColor: Colors.white,
                                            disabledBackgroundColor: Colors.grey[800],
                                            disabledForegroundColor: Colors.grey[600],
                                          ),
                                          onPressed: !canRender ? null : () {
                                            setState(() => _hasDismissedRenderPopup = true);
                                            _stopSequencePlayback();
                                            showDialog(context: context, builder: (ctx) => AlertDialog(
                                              title: Text(t('Start Video Render?', 'Mulai Render Video?')),
                                              content: Text(t("This will assemble all final video assets.", "Ini akan merakit semua aset video final.")),
                                              actions: [
                                                TextButton(
                                                  style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                                                  child: Text(t('Cancel', 'Batal')), 
                                                  onPressed: () => Navigator.pop(ctx)
                                                ),
                                                TextButton(
                                                  child: Text(t('RENDER', 'RENDER'), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)), 
                                                  onPressed: () async {
                                                    Navigator.pop(ctx);
                                                    setState(() => _isTriggeringRender = true);
                                                    await prepareAndSaveRenderStorinemaPacket(ref, widget.projectId);
                                                    await ref.read(firestoreStorinemaServiceProvider).updateProject(widget.projectId, {
                                                      'status': 'RENDER_READY', 
                                                      'needsReRender': false,
                                                      'renderReadyAt': FieldValue.serverTimestamp()
                                                    });
                                                  }
                                                ),
                                              ],
                                            ));
                                          },
                                          child: Text(t('RENDER', 'RENDER')),
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
                    if (isProjectRendering) _buildRenderingOverlay(secondsRemainingForOverlay, hasValidStartTime, isWaitingForUrl),
                  ],
                );
              }
            );
          },
        ),
      ),
    );
  }
//................................................................//

//No ke-6.........................................................//
// HELPERS, RENDER LOGIC (MANUAL) & STYLING                       //
  Color _getStatusColor(String? status) {
    if (status == null) return Colors.grey.shade600;
    
    if (status.startsWith('ERROR')) return Colors.red.shade700;
    
    switch (status) {
      case 'COMPLETED': return Colors.green.shade700;
      case 'RENDER_COMPLETED': return Colors.green.shade700;
      
      case 'QUEUED_FOR_REFINE':
      case 'IS_REFINING': return Colors.orangeAccent;
      
      case 'QUEUED_FOR_VIDEO':
      case 'GENERATING_VIDEO': 
      case 'WAITING_AUDIO': return Colors.purple.shade600;
      
      case 'PENDING_REFINEMENT': return Colors.blueAccent;
      
      default: return Colors.grey.shade600;
    }
  }

  void _initializeFirstPreview(String url) {
    if (_videoController != null) return; 
    
    _videoController = VideoPlayerController.networkUrl(Uri.parse(url))
      ..initialize().then((_) {
        if (mounted) setState(() {});
      }).catchError((e) {
        logger.error("Initial preview failed: $e");
        if (mounted) setState(() {}); 
      });
  }

  // --- [DIALOG REGENERATE KLIP BERBAYAR (1 SEGMEN TOKEN) - BILINGUAL & ANTI-CRASH] ---
  void _showPaidRegenerateDialog(SceneStorinema scene, dynamic project, [Map<String, dynamic>? projectMap]) {
    final currentLocale = ref.read(appLanguageProvider);
    final isIndo = currentLocale.languageCode == 'id';
    String t(String en, String id) => isIndo ? id : en;

    final config = ref.read(appConfigProvider).valueOrNull;
    final user = ref.read(firestoreUserProvider).valueOrNull;
    final int userBalance = user?.tokenBalance ?? 0;

    String costLevel = 'Standard';
    String resolution = '720p';

    if (projectMap != null) {
      costLevel = projectMap['costLevel']?.toString() ?? projectMap['visualQuality']?.toString() ?? 'Standard';
      resolution = projectMap['resolution']?.toString() ?? '720p';
    } else {
      try {
        costLevel = (project as dynamic).costLevel?.toString() ?? (project as dynamic).visualQuality?.toString() ?? 'Standard';
      } catch (_) {
        costLevel = 'Standard';
      }
      try {
        resolution = (project as dynamic).resolution?.toString() ?? '720p';
      } catch (_) {
        resolution = '720p';
      }
    }

    int costPerScene = 0;
    if (config != null) {
      final sCosts = config.costs.storinemaCosts;
      if (costLevel == 'High') {
        costPerScene = resolution == '1080p' ? sCosts.highPerSegment1080p : sCosts.highPerSegment720p;
      } else if (costLevel == 'Good') {
        costPerScene = resolution == '1080p' ? sCosts.goodPerSegment1080p : sCosts.goodPerSegment720p;
      } else {
        costPerScene = resolution == '1080p' ? sCosts.standardPerSegment1080p : sCosts.standardPerSegment720p;
      }
    } else {
      if (costLevel == 'High') {
        costPerScene = resolution == '1080p' ? 4500 : 4400;
      } else if (costLevel == 'Good') {
        costPerScene = resolution == '1080p' ? 2200 : 2000;
      } else {
        costPerScene = resolution == '1080p' ? 1870 : 720;
      }
    }

    final bool hasEnoughTokens = userBalance >= costPerScene;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.refresh_rounded, color: Colors.blueAccent),
            const SizedBox(width: 8),
            Text(t('Regenerate Clip ${scene.segmentIndex + 1}?', 'Regenerate Klip ${scene.segmentIndex + 1}?')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t(
                'Do you want to re-create Video AI for clip ${scene.segmentIndex + 1}?',
                'Apakah Anda ingin membuat ulang Video AI untuk klip ke-${scene.segmentIndex + 1}?'
              ),
              style: const TextStyle(fontSize: 14, color: Colors.white70),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: hasEnoughTokens ? Colors.blue.withOpacity(0.08) : Colors.red.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: hasEnoughTokens ? Colors.blueAccent.withOpacity(0.3) : Colors.redAccent.withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.token, size: 16, color: hasEnoughTokens ? Colors.amber : Colors.redAccent),
                      const SizedBox(width: 6),
                      Text(
                        t('Cost: $costPerScene Tokens (1 Clip)', 'Biaya: $costPerScene Token (1 Klip)'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: hasEnoughTokens ? Colors.white : Colors.redAccent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    t('Your Token Balance: $userBalance Tokens', 'Saldo Token Anda: $userBalance Token'),
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                  if (!hasEnoughTokens) ...[
                    const SizedBox(height: 6),
                    Text(
                      t(
                        'Insufficient token balance to regenerate this clip. Please top up your tokens.',
                        'Saldo token tidak cukup untuk regenerasi klip ini. Silakan top up token terlebih dahulu.'
                      ),
                      style: const TextStyle(fontSize: 11, color: Colors.redAccent, fontWeight: FontWeight.bold),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx),
            child: Text(t('Cancel', 'Batal')),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey[800],
            ),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(t('Regenerate Clip', 'Regenerate Klip')),
            onPressed: !hasEnoughTokens
                ? null
                : () async {
                    Navigator.pop(ctx);
                    _stopSequencePlayback();

                    try {
                      await FirebaseFirestore.instance
                          .collection('projects_storinema')
                          .doc(widget.projectId)
                          .update({
                            'needsReRender': true,
                          });
                    } catch (e) {
                      logger.error("Failed to update needsReRender: $e");
                    }

                    ref.read(firestoreStorinemaServiceProvider).requestVideoRegeneration(
                      widget.projectId,
                      scene.id,
                    );

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(t(
                            'Regenerating Clip ${scene.segmentIndex + 1} started (Cost: $costPerScene tokens)...',
                            'Memulai regenerasi Klip ${scene.segmentIndex + 1} (Biaya: $costPerScene token)...'
                          )),
                          backgroundColor: Colors.blueAccent,
                        ),
                      );
                    }
                  },
          ),
        ],
      ),
    );
  }

  void _showRegenerateDialog(SceneStorinema scene) {
    final currentLocale = ref.read(appLanguageProvider);
    final isIndo = currentLocale.languageCode == 'id';
    String t(String en, String id) => isIndo ? id : en;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('Regenerate AI Video?', 'Regenerate Video AI?')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t('Re-create Video AI for scene ${scene.segmentIndex + 1}?', 'Buat ulang Video AI untuk scene ${scene.segmentIndex + 1}?')),
            const SizedBox(height: 12),
            Text(
              t(
                'Safety Note: Sensitive elements will be automatically converted to implicit representation while preserving physical traits, time, and setting.',
                'Catatan Anti-Gagal: Elemen sensitif otomatis dirubah ke representasi implisit, sambil tetap mempertahankan ciri fisik karakter, waktu, dan tempat.'
              ),
              style: const TextStyle(fontSize: 12, color: Colors.orange, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(child: Text(t('Cancel', 'Batal')), onPressed: () => Navigator.pop(ctx)),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.deepOrange),
            child: Text(t('Regenerate (Pruned)', 'Regenerate (Pruned)')), 
            onPressed: () async {
              Navigator.pop(ctx);
              
              String promptToPrune = scene.refinedPrompt ?? scene.rawPrompt ?? "";
              
              if (promptToPrune.isNotEmpty) {
                try {
                  await FirebaseFirestore.instance
                      .collection('projects_storinema')
                      .doc(widget.projectId)
                      .collection('scenes')
                      .doc(scene.id)
                      .update({
                        'status': 'PENDING_REFINEMENT',
                        'errorDetail': FieldValue.delete(), 
                      });

                  await FirebaseFirestore.instance
                      .collection('projects_storinema')
                      .doc(widget.projectId)
                      .update({
                        'needsReRender': true,
                      });
                } catch (e) {
                  logger.error("Failed to trigger refinement: $e");
                }
              }

              ref.read(firestoreStorinemaServiceProvider).requestVideoRegeneration(widget.projectId, scene.id);
            }
          ),
        ],
      ),
    );
  }

  Widget _buildScenePlayButton(SceneStorinema scene, int sceneIndex, String videoUrl, String audioUrl) {
    final bool isThisSceneCurrentlyPlaying = (_isPlayingIndividual || (_isPlayingSequence && !_isPlayingIntroBgm)) &&
        _currentlyPlayingSceneId == scene.id &&
        _videoController != null && _videoController!.value.isPlaying;
        
    final bool canThisScenePlay = videoUrl.isNotEmpty;

    if (!canThisScenePlay) {
      return IconButton(icon: Icon(Icons.play_disabled, color: Colors.grey[400], size: 36), onPressed: null);
    }

    return IconButton(
      icon: Icon(isThisSceneCurrentlyPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
        color: Theme.of(context).primaryColor, size: 36),
      onPressed: () {
        if (_isPlayingSequence) _stopSequencePlayback(resetIndex: false);
        if (isThisSceneCurrentlyPlaying) {
          _videoController?.pause();
          _narrationPlayer.pause(); 
          setState(() {});
        } else {
          _playbackTimer?.cancel();
          _updatePlaybackTime(0.0);
          
          setState(() {
            _currentlyPlayingSceneId = scene.id;
            _isPlayingIndividual = true;
            _currentSequenceIndex = sceneIndex;
            ref.read(selectedSceneStorinemaProvider.notifier).state = scene;
            _currentMediaUrl = videoUrl;
          });
          
          _videoController?.removeListener(_onVideoPlayerComplete);
          _videoController?.dispose();
          _narrationPlayer.stop(); 
          
          _videoController = VideoPlayerController.networkUrl(Uri.parse(videoUrl))
            ..initialize().then((_) {
              if (mounted) {
                _videoController!.addListener(_onVideoPlayerComplete);
                _videoController!.play();
                if (audioUrl.isNotEmpty && audioUrl != 'EMPTY') {
                  _narrationPlayer.play(UrlSource(audioUrl));
                }
                setState(() {});
              }
            }).catchError((e) {
              logger.error("Error manual play: $e");
              if (mounted) setState(() {});
            });
        }
      },
    );
  }
//................................................................//

//No ke-7.........................................................//
// REPORT SCENE LOGIC (BILINGUAL / ENGLISH)                       //
  void _showSceneReportDialog(SceneStorinema scene, String videoUrl) {
    final currentLocale = ref.read(appLanguageProvider);
    final isIndo = currentLocale.languageCode == 'id';
    String t(String en, String id) => isIndo ? id : en;

    final TextEditingController reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t("Report Scene ${scene.segmentIndex + 1}", "Lapor Scene ${scene.segmentIndex + 1}")),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t("Does this AI video violate safety or content policies?", "Apakah video AI ini melanggar kebijakan keamanan atau konten?"), 
              style: const TextStyle(fontSize: 14)
            ),
            const SizedBox(height: 8),
            TextField(
              controller: reasonController, 
              maxLines: 3,
              decoration: InputDecoration(
                hintText: t("Enter report reason...", "Masukkan alasan pelaporan..."),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t("Cancel", "Batal"))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              final userId = ref.read(firestoreUserProvider).valueOrNull?.uid ?? 'anonymous'; 
              FirebaseFirestore.instance.collection('reports').add({
                'projectId': widget.projectId,
                'sceneId': scene.id,
                'content': videoUrl, 
                'contentType': 'scene_video_ai',
                'reason': reasonController.text,
                'reportedAt': FieldValue.serverTimestamp(),
                'userId': userId,
              }).then((_) { if (mounted) Navigator.pop(ctx); });
            },
            child: Text(t("Report", "Lapor")),
          ),
        ],
      ),
    );
  }
}
//................................................................//

//No ke-8.........................................................//
// DUMMY LOGGER                                                   //
class _DummyLogger {
  void warn(String message, [dynamic error, StackTrace? stackTrace]) => debugPrint('WARN: $message ${error ?? ''}');
  void info(String message, [dynamic error, StackTrace? stackTrace]) => debugPrint('INFO: $message ${error ?? ''}');
  void error(String message, [dynamic error, StackTrace? stackTrace]) => debugPrint('ERROR: $message ${error ?? ''}');
}

final logger = _DummyLogger();
//................................................................//