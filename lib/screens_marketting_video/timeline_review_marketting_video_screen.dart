

//================================================================//
// NAMA FILE: TIMELINE_REVIEW_MARKETTING_VIDEO_SCREEN.DART         //
// DIREKTORI: LIB/SCREENS_MARKETTING_VIDEO/                        //
// DESKRIPSI: SMART CONTROLLER, NATIVE VIDEO TIMELINE, TEXT/SUBS  //
//================================================================//

// No ke-1: IMPORTS, CONSTANTS & PROVIDERS                        //
//----------------------------------------------------------------//
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
import '../models_marketting_video/scene_marketting_video.dart';
import '../services_marketting_video/firestore_marketting_video_service.dart';
import '../view_model_marketting_video/timeline_marketting_video_view_model.dart';
import '../providers_marketting_video/visual_settings_marketting_video_provider.dart';
import '../providers_marketting_video/firestore_marketting_video_provider.dart';
import '../providers_marketting_video/timeline_marketting_video_providers.dart';

import 'visual_setting_marketting_video_screen.dart';
import '../providers/user_provider.dart';
import '../providers/config_provider.dart';

final selectedSceneMarkettingVideoProvider = StateProvider.autoDispose<SceneMarkettingVideo?>((ref) => null);
//----------------------------------------------------------------//

// No ke-2: MAIN CLASS DEFINITION & INITIALIZATION                //
//----------------------------------------------------------------//
class TimelineReviewMarkettingVideoScreen extends ConsumerStatefulWidget {
  final String projectId;
  const TimelineReviewMarkettingVideoScreen({super.key, required this.projectId});

  @override
  ConsumerState<TimelineReviewMarkettingVideoScreen> createState() =>
      _TimelineReviewMarkettingVideoScreenState();
}

class _TimelineReviewMarkettingVideoScreenState extends ConsumerState<TimelineReviewMarkettingVideoScreen> {
  // [PERBAIKAN]: _narrationPlayer dikembalikan untuk mendengarkan Google TTS
  late AudioPlayer _bgmPlayer; 
  late AudioPlayer _narrationPlayer; 
  
  VideoPlayerController? _videoController;

  bool _isPlayingIndividual = false;
  String? _currentlyPlayingSceneId;
  bool _isPlayingSequence = false;
  int _currentSequenceIndex = -1;
  List<SceneMarkettingVideo> _currentScenes = [];
  List<ProcessedSceneDataMarkettingVideo> _currentProcessedScenes = [];
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
        
        final timelineData = ref.read(processedTimelineMarkettingVideoProvider(widget.projectId)).asData?.value;
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
//----------------------------------------------------------------//

// No ke-3: TIMERS, UTILITIES & TIMEOUT HANDLER                   //
//----------------------------------------------------------------//
  // [ISOLASI TIMER HITUNG MUNDUR]: Mencegah rebuild seluruh layar setiap 1 detik
  final ValueNotifier<int> _renderCountdownNotifier = ValueNotifier<int>(3600);

  void _startUiRefreshTimer(int initialSeconds) {
    _renderCountdownNotifier.value = initialSeconds;
    if (_uiRefreshTimer != null && _uiRefreshTimer!.isActive) return;
    
    _uiRefreshTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_renderCountdownNotifier.value > 0) {
        _renderCountdownNotifier.value--;
      } else {
        timer.cancel();
        _handleRenderTimeout();
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
      final firestore = ref.read(firestoreMarkettingVideoServiceProvider);
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
    final settings = ref.read(visualSettingsMarkettingVideoProvider(widget.projectId));
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
    _renderCountdownNotifier.dispose();
    _videoController?.dispose(); 
    _bgmPlayer.dispose();
    _narrationPlayer.dispose();
    super.dispose();
  }
//----------------------------------------------------------------//

// No ke-4: PLAYBACK & NATIVE VIDEO LOGIC (MP4 LISTENER)          //
//----------------------------------------------------------------//
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
      ref.read(selectedSceneMarkettingVideoProvider.notifier).state = null;
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
          if (mounted) ref.read(selectedSceneMarkettingVideoProvider.notifier).state = null;
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
    
    ref.read(selectedSceneMarkettingVideoProvider.notifier).state = scene;
    
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

  // --- [SISTEM DOWNLOAD VMOTION: RINGAN & NATIVE] ---
  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open link: $urlString'), backgroundColor: Colors.red),
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
//----------------------------------------------------------------//

// No ke-5: BUILD UI, WIDGETS & GATEKEEPER LOGIC                  //
//----------------------------------------------------------------//
  
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

  Widget _buildRenderingOverlay(bool hasValidStartTime, bool isWaitingForUrl) {
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
                    isWaitingForUrl ? "Preparing Download Link..." : "Rendering Final Video...", 
                    style: const TextStyle(fontSize: 16, color: Colors.white)
                  ),
                  const SizedBox(height: 10),
                  ValueListenableBuilder<int>(
                    valueListenable: _renderCountdownNotifier,
                    builder: (context, secondsRemaining, _) {
                      return Text(
                        "Auto Cancel in: ${_formatDuration(secondsRemaining)}", 
                        style: const TextStyle(fontSize: 14, color: Colors.white70)
                      );
                    },
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
    final projectAsyncValue = ref.watch(projectMarkettingVideoStreamProvider(widget.projectId));
    final processedTimelineAsync = ref.watch(processedTimelineMarkettingVideoProvider(widget.projectId));
    final visualSettings = ref.watch(visualSettingsMarkettingVideoProvider(widget.projectId));
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

    // Render otomatis HANYA di awal saat project baru (belum pernah ada finalVideoUrl)
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
          await prepareAndSaveRenderMarkettingVideoPacket(ref, widget.projectId);
          await ref.read(firestoreMarkettingVideoServiceProvider).updateProject(
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
          title: const Text('Review Project (Marketting Video)'),
          actions: [
            IconButton(
              icon: const Icon(Icons.tune),
              tooltip: 'Visual Settings',
              onPressed: () {
                _stopSequencePlayback();
                _cancelUiRefreshTimer();
                Navigator.push(context, MaterialPageRoute(builder: (context) => VisualSettingMarkettingVideoScreen(projectId: widget.projectId)));
              },
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: projectAsyncValue.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(child: Text('Error loading project: $error')),
          data: (project) {
            if (project == null) return const Center(child: Text("Error: Failed to load project.", style: TextStyle(color: Colors.red)));

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
            if (isProjectRendering) {
              final Timestamp? startTime = project.renderStartedAt;
              if (startTime != null) {
                hasValidStartTime = true;
                final int elapsedSeconds = Timestamp.now().seconds - startTime.seconds;
                final int secondsRemaining = (_renderTimeoutDuration - elapsedSeconds);
                if (secondsRemaining <= 0) {
                  _cancelUiRefreshTimer();
                  WidgetsBinding.instance.addPostFrameCallback((_) => _handleRenderTimeout());
                } else {
                  _startUiRefreshTimer(secondsRemaining);
                }
              } else {
                _cancelUiRefreshTimer();
              }
            } else {
              _cancelUiRefreshTimer();
            }

            // --- [STREAM BUILDER: MEMBACA PENANDA needsReRender DARI FIRESTORE SECARA REALTIME] ---
            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection('projects_marketting_video').doc(widget.projectId).snapshots(),
              builder: (context, projectSnap) {
                final bool needsReRender = projectSnap.data?.data()?['needsReRender'] ?? false;

                // LOGIKA TOMBOL RENDER: 
                // ON jika ada klip yang baru diregenerasi (needsReRender == true) dan semua adegan siap
                // OFF setelah proses render selesai
                final bool canRender;
                if (isProjectRendering) {
                  canRender = false;
                } else if (needsReRender) {
                  canRender = areAllScenesValid; // MENYALA ON saat klip hasil regenerasi selesai!
                } else if (project.status == 'ASSETS_COMPLETE' && (project.finalVideoUrl == null || project.finalVideoUrl!.isEmpty)) {
                  canRender = areAllScenesValid;
                } else if (project.status == 'ERROR_RENDER') {
                  canRender = areAllScenesValid;
                } else {
                  canRender = false; // OFF saat render selesai dan tidak ada klip yang diregenerasi
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
                                child: RepaintBoundary(
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
                        ),

                        if (isRenderComplete && finalVideoUrl != null && finalVideoUrl.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                            child: ElevatedButton.icon(
                              onPressed: () => _launchURL(finalVideoUrl), 
                              icon: const Icon(Icons.download_for_offline),
                              label: const Text('DOWNLOAD FINAL VIDEO'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade600, 
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
                            error: (error, stack) => Center(child: Text('Error loading timeline data: $error')),
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

                              if (scenes.isEmpty) return const Center(child: Text("Generating scenes..."));
                              
                              return Column(
                                children: [
                                  Expanded(
                                    child: ListView.builder(
                                      itemCount: scenes.length,
                                      itemBuilder: (context, index) {
                                        final sceneIndex = index;
                                        final scene = scenes[sceneIndex];
                                        final isCurrentlyPlaying = _isPlayingSequence && !_isPlayingIntroBgm && _currentSequenceIndex == sceneIndex;
                                        final bool isSelectedManually = ref.watch(selectedSceneMarkettingVideoProvider)?.id == scene.id && !_isPlayingSequence;

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
                                              ref.read(selectedSceneMarkettingVideoProvider.notifier).state = scene;
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
                                                  Visibility(
                                                    visible: showRegenerateButton,
                                                    child: Container(
                                                      decoration: BoxDecoration(
                                                        color: canRegenerate ? Colors.orange.withOpacity(0.2) : Colors.transparent,
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: IconButton(
                                                        tooltip: 'Regenerate AI Video',
                                                        icon: Icon(
                                                          Icons.refresh, 
                                                          color: canRegenerate ? Colors.deepOrange : Colors.grey[400], 
                                                          size: 26, 
                                                        ), 
                                                        onPressed: !canRegenerate ? null : () { 
                                                          _stopSequencePlayback(); 
                                                          _showRegenerateDialog(scene, project); 
                                                        }
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  // --- [GREEN DOWNLOAD BUTTON] ---
                                                  IconButton(
                                                    padding: EdgeInsets.zero,
                                                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                                    tooltip: 'Download Clip',
                                                    icon: Icon(
                                                      Icons.download_rounded, 
                                                      color: cardVideoUrl.isNotEmpty ? Colors.greenAccent.shade400 : Colors.grey[700], 
                                                      size: 24
                                                    ),
                                                    onPressed: cardVideoUrl.isNotEmpty
                                                        ? () {
                                                            if (kIsWeb) {
                                                              try {
                                                                html.AnchorElement(href: cardVideoUrl)
                                                                  ..setAttribute("download", "scene_${index + 1}.mp4")
                                                                  ..click();
                                                                return;
                                                              } catch (_) {}
                                                            }
                                                            _launchURL(cardVideoUrl);
                                                          }
                                                        : null,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  // --- [BLUE REGENERATE BUTTON] ---
                                                  IconButton(
                                                    padding: EdgeInsets.zero,
                                                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                                    tooltip: 'Regenerate Clip',
                                                    icon: const Icon(Icons.refresh, color: Colors.blueAccent, size: 26),
                                                    onPressed: isProjectBusy ? null : () {
                                                      _stopSequencePlayback();
                                                      _showEditPromptDialog(scene, project);
                                                    },
                                                  ),
                                                  const SizedBox(width: 4),
                                                  // --- [RED REPORT BUTTON] ---
                                                  IconButton(
                                                    padding: EdgeInsets.zero,
                                                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
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
                                          label: Text(isCalculating ? 'CALCULATING...' : (_isPlayingSequence ? 'PAUSE' : 'PLAY ALL')),
                                          style: ElevatedButton.styleFrom(backgroundColor: _isPlayingSequence ? Colors.orangeAccent : Theme.of(context).colorScheme.primary, foregroundColor: Colors.white),
                                        ),
                                        IconButton(icon: const Icon(Icons.replay), iconSize: 32, color: canPlayOrReplay ? Colors.cyanAccent : Colors.grey, onPressed: !canPlayOrReplay ? null : _replaySequence),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.redAccent.shade700, 
                                            foregroundColor: Colors.white,
                                            disabledBackgroundColor: Colors.grey.shade800,
                                            disabledForegroundColor: Colors.grey.shade600,
                                          ),
                                          onPressed: !canRender ? null : () {
                                            setState(() => _hasDismissedRenderPopup = true);
                                            _stopSequencePlayback();
                                            showDialog(context: context, builder: (ctx) => AlertDialog(
                                              backgroundColor: const Color(0xFF1E222A),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(16),
                                                side: const BorderSide(color: Colors.white12),
                                              ),
                                              title: const Text('Start Video Render?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                              content: const Text("This will assemble all final video assets.", style: TextStyle(color: Colors.white70)),
                                              actions: [
                                                // [WARNA KONTRAS]: Tombol Cancel Oranye Terang Jelas di Atas Background Gelap
                                                TextButton(
                                                  style: TextButton.styleFrom(
                                                    foregroundColor: Colors.orangeAccent,
                                                    textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                                  ),
                                                  child: const Text('Cancel'), 
                                                  onPressed: () => Navigator.pop(ctx)
                                                ),
                                                ElevatedButton(
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.redAccent.shade700,
                                                    foregroundColor: Colors.white,
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                  ),
                                                  onPressed: () async {
                                                    Navigator.pop(ctx);
                                                    setState(() => _isTriggeringRender = true);
                                                    await prepareAndSaveRenderMarkettingVideoPacket(ref, widget.projectId);
                                                    // Pemicu render: reset needsReRender ke false dan set status ke RENDER_READY
                                                    await ref.read(firestoreMarkettingVideoServiceProvider).updateProject(widget.projectId, {
                                                      'status': 'RENDER_READY', 
                                                      'needsReRender': false,
                                                      'renderReadyAt': FieldValue.serverTimestamp()
                                                    });
                                                  },
                                                  child: const Text('RENDER', style: TextStyle(fontWeight: FontWeight.bold)),
                                                ),
                                              ],
                                            ));
                                          },
                                          child: const Text('RENDER', style: TextStyle(fontWeight: FontWeight.bold)),
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
                    if (isProjectRendering) _buildRenderingOverlay(hasValidStartTime, isWaitingForUrl),
                  ],
                );
              }
            );
          },
        ),
      ),
    );
  }
//----------------------------------------------------------------//

// No ke-6: HELPERS, RENDER LOGIC (MANUAL) & STYLING              //
//----------------------------------------------------------------//
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

  // --- [DIALOG REGENERATE KLIP DENGAN PENANDA needsReRender] ---
  void _showEditPromptDialog(SceneMarkettingVideo scene, dynamic project) {
    final config = ref.read(appConfigProvider).valueOrNull;
    final user = ref.read(firestoreUserProvider).valueOrNull;
    final int userBalance = user?.tokenBalance ?? 0;

    final String costLevel = (project as dynamic).costLevel ?? 'Standard';
    final String resolution = (project as dynamic).resolution ?? '720p';

    int costPerScene = 0;
    if (config != null) {
      final mCosts = config.costs.markettingVideoCosts;
      if (costLevel == 'High') {
        costPerScene = resolution == '1080p' ? mCosts.highPerSegment1080p : mCosts.highPerSegment720p;
      } else {
        costPerScene = resolution == '1080p' ? mCosts.standardPerSegment1080p : mCosts.standardPerSegment720p;
      }
    }

    final bool hasEnoughTokens = userBalance >= costPerScene;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E222A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.white12),
        ),
        title: Row(
          children: [
            const Icon(Icons.refresh, color: Colors.blueAccent),
            const SizedBox(width: 8),
            Text('Regenerate Clip ${scene.segmentIndex + 1}?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Do you want to re-create Video AI for clip ${scene.segmentIndex + 1}?',
              style: const TextStyle(fontSize: 14, color: Colors.white70),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: hasEnoughTokens ? Colors.blue.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
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
                        'Cost: $costPerScene Tokens (1 Clip)',
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
                    'Your Token Balance: $userBalance Tokens',
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                  if (!hasEnoughTokens) ...[
                    const SizedBox(height: 6),
                    const Text(
                      'Insufficient token balance to regenerate this clip. Please top up your tokens.',
                      style: TextStyle(fontSize: 11, color: Colors.redAccent, fontWeight: FontWeight.bold),
                    ),
                  ],
                ],
              ),
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
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey[800],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Regenerate Clip', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: !hasEnoughTokens
                ? null
                : () async {
                    Navigator.pop(ctx);
                    _stopSequencePlayback();

                    try {
                      // [PRESISI]: Catat penanda needsReRender = true tanpa merusak status utama project
                      await FirebaseFirestore.instance
                          .collection('projects_marketting_video')
                          .doc(widget.projectId)
                          .update({
                            'needsReRender': true,
                          });
                    } catch (e) {
                      logger.error("Failed to update needsReRender: $e");
                    }

                    // Trigger worker backend untuk regenerasi klip (potong 1 segmen token)
                    ref.read(firestoreMarkettingVideoServiceProvider).requestVideoRegeneration(
                      widget.projectId,
                      scene.id,
                    );

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Regenerating Clip ${scene.segmentIndex + 1} started (Cost: $costPerScene tokens)...'),
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

  void _showRegenerateDialog(SceneMarkettingVideo scene, dynamic project) {
    final config = ref.read(appConfigProvider).valueOrNull;
    final user = ref.read(firestoreUserProvider).valueOrNull;
    final int userBalance = user?.tokenBalance ?? 0;

    final String costLevel = (project as dynamic).costLevel ?? 'Standard';
    final String resolution = (project as dynamic).resolution ?? '720p';

    int costPerScene = 0;
    if (config != null) {
      final mCosts = config.costs.markettingVideoCosts;
      if (costLevel == 'High') {
        costPerScene = resolution == '1080p' ? mCosts.highPerSegment1080p : mCosts.highPerSegment720p;
      } else {
        costPerScene = resolution == '1080p' ? mCosts.standardPerSegment1080p : mCosts.standardPerSegment720p;
      }
    }

    final bool hasEnoughTokens = userBalance >= costPerScene;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E222A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.white12),
        ),
        title: const Text('Regenerate AI Video?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Re-create Video AI for scene ${scene.segmentIndex + 1}?', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 10),
            Text(
              'Cost: $costPerScene Tokens (Balance: $userBalance Tokens)',
              style: TextStyle(
                fontSize: 12, 
                fontWeight: FontWeight.bold, 
                color: hasEnoughTokens ? Colors.white70 : Colors.redAccent
              ),
            ),
            if (!hasEnoughTokens) ...[
              const SizedBox(height: 4),
              const Text(
                'Insufficient token balance. Please top up your tokens.',
                style: TextStyle(fontSize: 11, color: Colors.redAccent),
              ),
            ],
            const SizedBox(height: 12),
            const Text(
              'Safety Pruning Note: The prompt will be automatically simplified to scene setting and lighting to ensure AI moderation compliance, while preserving your product.',
              style: TextStyle(fontSize: 12, color: Colors.orange, fontStyle: FontStyle.italic),
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
            child: const Text('Cancel'), 
            onPressed: () => Navigator.pop(ctx)
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: !hasEnoughTokens ? null : () async {
              Navigator.pop(ctx);
              
              String promptToPrune = scene.refinedPrompt ?? scene.rawPrompt ?? "";
              
              if (promptToPrune.isNotEmpty) {
                bool hasProductTag = false;
                if (promptToPrune.toUpperCase().contains('[USE_PRODUCT_IMAGE]')) {
                  hasProductTag = true;
                  promptToPrune = promptToPrune.replaceAll(RegExp(r'\[USE_PRODUCT_IMAGE\]', caseSensitive: false), '').trim();
                }

                String cleaned = promptToPrune.replaceAll(RegExp(r'^Create a video of\s*', caseSensitive: false), '').trim();
                List<String> sentences = cleaned.split('.');
                String lastSentence = "";
                
                for (int i = sentences.length - 1; i >= 0; i--) {
                  if (sentences[i].trim().isNotEmpty) {
                    lastSentence = sentences[i].trim();
                    break;
                  }
                }
                
                if (lastSentence.isNotEmpty) {
                  String finalPrunedPrompt = "Create a video of $lastSentence.";
                  
                  if (hasProductTag) {
                    finalPrunedPrompt = "[USE_PRODUCT_IMAGE] " + finalPrunedPrompt;
                  }
                  
                  try {
                    await FirebaseFirestore.instance
                        .collection('projects_marketting_video')
                        .doc(widget.projectId)
                        .collection('scenes')
                        .doc(scene.id)
                        .update({
                          'refinedPrompt': finalPrunedPrompt,
                          'errorDetail': FieldValue.delete(), 
                        });

                    await FirebaseFirestore.instance
                        .collection('projects_marketting_video')
                        .doc(widget.projectId)
                        .update({
                          'needsReRender': true,
                        });
                  } catch (e) {
                    logger.error("Failed to update pruned prompt to Firestore: $e");
                  }
                }
              }

              ref.read(firestoreMarkettingVideoServiceProvider).requestVideoRegeneration(widget.projectId, scene.id);
            },
            child: const Text('Regenerate (Pruned)', style: TextStyle(fontWeight: FontWeight.bold)), 
          ),
        ],
      ),
    );
  }

  Widget _buildScenePlayButton(SceneMarkettingVideo scene, int sceneIndex, String videoUrl, String audioUrl) {
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
            ref.read(selectedSceneMarkettingVideoProvider.notifier).state = scene;
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
//----------------------------------------------------------------//

// No ke-7: REPORT SCENE LOGIC (100% ENGLISH)                     //
//----------------------------------------------------------------//
  void _showSceneReportDialog(SceneMarkettingVideo scene, String videoUrl) {
    final TextEditingController reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E222A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.white12),
        ),
        title: Text("Report Scene ${scene.segmentIndex + 1}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Does this AI video violate safety or content policies?", style: TextStyle(fontSize: 14, color: Colors.white70)),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController, 
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: "Enter report reason...",
                border: OutlineInputBorder(),
              ),
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
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
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
            child: const Text("Report", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
  }
//----------------------------------------------------------------//

// No ke-8: DUMMY LOGGER                                          //
//----------------------------------------------------------------//
class _DummyLogger {
  void warn(String message, [dynamic error, StackTrace? stackTrace]) => debugPrint('WARN: $message ${error ?? ''}');
  void info(String message, [dynamic error, StackTrace? stackTrace]) => debugPrint('INFO: $message ${error ?? ''}');
  void error(String message, [dynamic error, StackTrace? stackTrace]) => debugPrint('ERROR: $message ${error ?? ''}');
}

final logger = _DummyLogger();
//----------------------------------------------------------------//