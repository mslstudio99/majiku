//============================================================================//
// DIREKTORI: lib/entertainment/mytube/view_model/                           //
// FILE: MYTUBE_FEED_VIEW_MODEL.DART                                         //
// VIEW MODEL FEED MYTUBE (SHORTS, LONGS, CC SUBTITLE & MLA DUBBING SYNC)    //
//============================================================================//

//No ke-1....................................................................//
//IMPORTS & DEPENDENCIES                                                     //
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:audioplayers/audioplayers.dart';

import '../models/video_mytube_model.dart';
import '../services/firestore_mytube_service.dart';
//............................................................................//

//No ke-2....................................................................//
//STATE PROPERTIES, CONTROLLER MAPS, SUBTITLE & DUBBING STATE                //

class MytubeLanguageDatabase {
  static const List<String> languageList = [
    'English (US)', 'Indonesian', 'Hindi', 'English (UK)', 'English (Australia)',
    'English (India)', 'Arabic', 'Bengali (India)', 'Danish', 'Dutch (Netherlands)',
    'Dutch (Belgium)', 'Finnish', 'French (France)', 'French (Canada)', 'German',
    'Gujarati', 'Italian', 'Japanese', 'Kannada', 'Korean', 'Malayalam',
    'Mandarin Chinese', 'Marathi', 'Norwegian', 'Polish', 'Portuguese (Brazil)',
    'Russian', 'Spanish (Spain)', 'Spanish (US)', 'Swedish', 'Tamil', 'Telugu',
    'Thai', 'Turkish', 'Ukrainian', 'Urdu', 'Vietnamese',
  ];

  static const Map<String, String> languageToCodeMap = {
    'English (US)': 'en', 'Indonesian': 'id', 'Hindi': 'hi', 'English (UK)': 'en-gb',
    'English (Australia)': 'en-au', 'English (India)': 'en-in', 'Arabic': 'ar',
    'Bengali (India)': 'bn', 'Danish': 'da', 'Dutch (Netherlands)': 'nl',
    'Dutch (Belgium)': 'nl-be', 'Finnish': 'fi', 'French (France)': 'fr',
    'French (Canada)': 'fr-ca', 'German': 'de', 'Gujarati': 'gu', 'Italian': 'it',
    'Japanese': 'ja', 'Kannada': 'kn', 'Korean': 'ko', 'Malayalam': 'ml',
    'Mandarin Chinese': 'zh', 'Marathi': 'mr', 'Norwegian': 'no', 'Polish': 'pl',
    'Portuguese (Brazil)': 'pt', 'Russian': 'ru', 'Spanish (Spain)': 'es',
    'Spanish (US)': 'es-us', 'Swedish': 'sv', 'Tamil': 'ta', 'Telugu': 'te',
    'Thai': 'th', 'Turkish': 'tr', 'Ukrainian': 'uk', 'Urdu': 'ur', 'Vietnamese': 'vi',
  };

  static String getCode(String languageName) => languageToCodeMap[languageName] ?? 'en';
  static String getName(String code) {
    for (final entry in languageToCodeMap.entries) {
      if (entry.value == code) return entry.key;
    }
    return 'English (US)';
  }
}

class MytubeFeedViewModel extends ChangeNotifier {
  final FirestoreMytubeService _service;

  MytubeFeedViewModel({FirestoreMytubeService? service})
      : _service = service ?? FirestoreMytubeService();

  List<VideoMytubeModel> _videos = [];
  List<VideoMytubeModel> get videos => _videos;

  int _currentIndex = 0;
  int get currentIndex => _currentIndex;

  final Map<int, VideoPlayerController> _controllers = {};
  VideoPlayerController? get currentController => _controllers[_currentIndex];

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool _isMuted = false;
  bool get isMuted => _isMuted;

  bool _isAutoplaySoundBlocked = false;
  bool get isAutoplaySoundBlocked => _isAutoplaySoundBlocked;

  bool _isUserPaused = false;
  bool get isUserPaused => _isUserPaused;

  bool _isAdActive = false;
  bool get isAdActive => _isAdActive;

  bool _isLiteModeLocked = false;
  bool get isLiteModeLocked => _isLiteModeLocked;
  DateTime? _bufferingStartTime;
  static const String _prefLiteModeExpiryKey = 'mytube_lite_mode_expiry';

  final Set<String> _likedVideoIds = {};
  final Set<String> _savedVideoIds = {};

  StreamSubscription<List<VideoMytubeModel>>? _feedSubscription;
  String? _currentUserId;

  String _currentVideoType = 'SHORT';
  String get currentVideoType => _currentVideoType;
  bool get isShortMode => _currentVideoType == 'SHORT';

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  String _appliedSearchQuery = '';
  Timer? _searchDebounceTimer;

  String? _selectedCategory;
  String? get selectedCategory => _selectedCategory;

  String? _selectedLanguage;
  String? get selectedLanguage => _selectedLanguage;

  String? _selectedLocation;
  String? get selectedLocation => _selectedLocation;

  bool get isFilterActive =>
      _appliedSearchQuery.trim().isNotEmpty ||
      _selectedCategory != null ||
      _selectedLanguage != null ||
      _selectedLocation != null;

  String get filterKey => '${_currentVideoType}_${_appliedSearchQuery}_${_selectedCategory}_${_selectedLanguage}_${_selectedLocation}';

  // --- SUBTITLE PROPERTIES ---
  static const String _prefSubCodeKey = 'mytube_pref_sub_lang_code';
  static const String _prefSubNameKey = 'mytube_pref_sub_lang_name';

  String? _activeSubtitleLangCode;
  String? get activeSubtitleLangCode => _activeSubtitleLangCode;
  bool get isSubtitleActive => _activeSubtitleLangCode != null;

  String? _activeSubtitleLangName;
  String? get activeSubtitleLangName => _activeSubtitleLangName;

  bool _isSubtitleLoading = false;
  bool get isSubtitleLoading => _isSubtitleLoading;

  String? _subtitleLoadingMessage;
  String? get subtitleLoadingMessage => _subtitleLoadingMessage;

  Timer? _onDemandSubtitleTimer;
  final Map<String, String> _vttContentCache = {};

  List<SubtitleCue> _currentCues = [];
  List<SubtitleCue> get currentCues => _currentCues;

  // --- [SMART & PERSISTENT MLA DUBBING & H+1 PRECACHE PROPERTIES] ---
  static const String _prefAudioCodeKey = 'mytube_pref_audio_lang_code';
  static const String _prefAudioNameKey = 'mytube_pref_audio_lang_name';

  String? _activeAudioLangCode; 
  String? get activeAudioLangCode => _activeAudioLangCode;
  bool get isDubbingActive => _activeAudioLangCode != null;

  String? _activeAudioLangName;
  String? get activeAudioLangName => _activeAudioLangName;

  bool _isDubbingLoading = false;
  bool get isDubbingLoading => _isDubbingLoading;

  String? _dubbingLoadingMessage;
  String? get dubbingLoadingMessage => _dubbingLoadingMessage;

  // Pemutar Utama (Video H)
  AudioPlayer? _dubbingAudioPlayer;
  Duration _lastSyncedVideoPosition = Duration.zero;
  DateTime? _lastDriftCheckTime; 
  bool _isDubbingSyncing = false; 

  // [BARU - SMART PRECACHE AUDIO DUBBING H+1]:
  AudioPlayer? _nextDubbingAudioPlayer;      // Pemutar cadangan yang di-buffer di latar belakang untuk video H+1
  String? _nextDubbingAudioUrl;             // URL audio H+1 yang sudah standby di memori
  int? _nextDubbingPrecachedIndex;          // Indeks video yang berhasil di-precache

  // [KUNCI ANTI-BOCOR & GERBANG TUNGGU FALLBACK GATE]:
  int _dubbingSessionId = 0;
  String? _currentDubbingAudioUrl;
  bool _isWaitingForDubbingAudio = false;    // Status menahan video di frame 0 sampai audio siap
  bool get isWaitingForDubbingAudio => _isWaitingForDubbingAudio;
  Timer? _dubbingTimeoutTimer;              // Batas waktu darurat 5 detik agar video tidak membeku selamanya

  static List<String> get supportedLanguages => MytubeLanguageDatabase.languageList;
  static String getLanguageCode(String name) => MytubeLanguageDatabase.getCode(name);
  static String getLanguageName(String code) => MytubeLanguageDatabase.getName(code);

  bool isVideoLanguageMatchingTarget(VideoMytubeModel video, String? targetCode, String? targetName) {
    if (targetCode == null || targetName == null) return false;
    final vLang = video.language.trim().toLowerCase();
    final tCode = targetCode.trim().toLowerCase();
    final tName = targetName.trim().toLowerCase();

    if (vLang == tCode || vLang == tName) return true;
    if ((vLang.contains('indonesia') || vLang == 'id') && (tCode == 'id' || tName.contains('indonesia'))) return true;
    if ((vLang.contains('english') || vLang.startsWith('en')) && (tCode.startsWith('en') || tName.contains('english'))) return true;
    if ((vLang.contains('hindi') || vLang == 'hi') && (tCode == 'hi' || tName.contains('hindi'))) return true;

    return false;
  }

  bool isCurrentVideoAudioBypassed(VideoMytubeModel video) {
    if (!isDubbingActive) return false;
    return isVideoLanguageMatchingTarget(video, _activeAudioLangCode, _activeAudioLangName);
  }

  List<VideoMytubeModel> get filteredVideos {
    return _videos.where((video) {
      if (_appliedSearchQuery.trim().isNotEmpty) {
        final query = _appliedSearchQuery.trim().toLowerCase();
        final matchTitle = video.title.toLowerCase().contains(query);
        final matchChannel = video.channelName.toLowerCase().contains(query);
        final matchDesc = video.description.toLowerCase().contains(query);
        if (!matchTitle && !matchChannel && !matchDesc) return false;
      }
      if (_selectedCategory != null && _selectedCategory!.isNotEmpty) {
        if (video.category.toLowerCase() != _selectedCategory!.toLowerCase()) return false;
      }
      if (_selectedLanguage != null && _selectedLanguage!.isNotEmpty) {
        if (video.language.toLowerCase() != _selectedLanguage!.toLowerCase()) return false;
      }
      if (_selectedLocation != null && _selectedLocation!.isNotEmpty) {
        final locQuery = _selectedLocation!.trim().toLowerCase();
        final matchesGlobal = video.targetLocations.any((l) => l.trim().toLowerCase() == 'global');
        final matchesSpecific = video.targetLocations.any((l) => l.trim().toLowerCase() == locQuery);
        if (!matchesGlobal && !matchesSpecific) return false;
      }
      return true;
    }).toList();
  }

  void setAdActiveStatus(bool isActive) {
    _isAdActive = isActive;
    if (isActive) {
      for (final controller in _controllers.values) {
        try {
          controller.setVolume(0.0);
          controller.pause();
        } catch (_) {}
      }
      _dubbingAudioPlayer?.pause();
      _nextDubbingAudioPlayer?.pause();
    } else {
      final active = currentController;
      if (active != null && active.value.isInitialized) {
        _safePlay(active);
      }
    }
    notifyListeners();
  }
//............................................................................//

//No ke-3....................................................................//
//LIFECYCLE, FEED SWITCHER & STREAM INITIALIZATION                           //
  Future<void> initFeed(String userId, {String videoType = 'SHORT'}) async {
    _currentUserId = userId;
    _currentVideoType = videoType.toUpperCase();
    _isUserPaused = false;
    await _loadSubtitlePreferences();
    await _loadAudioPreferences();
    await _loadNetworkPreferences();
    _startFeedStream();
  }

  Future<void> _loadNetworkPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final expiryIso = prefs.getString(_prefLiteModeExpiryKey);
      
      if (expiryIso != null && expiryIso.isNotEmpty) {
        final expiryTime = DateTime.parse(expiryIso);
        if (DateTime.now().isBefore(expiryTime)) {
          _isLiteModeLocked = true;
        } else {
          _isLiteModeLocked = false;
          await prefs.remove(_prefLiteModeExpiryKey);
        }
      }
    } catch (_) {}
  }

  Future<void> _loadSubtitlePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCode = prefs.getString(_prefSubCodeKey);
      final savedName = prefs.getString(_prefSubNameKey);

      if (savedCode == 'off') {
        _activeSubtitleLangCode = null;
        _activeSubtitleLangName = null;
      } else if (savedCode != null && savedCode.isNotEmpty) {
        _activeSubtitleLangCode = savedCode;
        _activeSubtitleLangName = savedName ?? 'English (US)';
      } else {
        _activeSubtitleLangCode = 'en';
        _activeSubtitleLangName = 'English (US)';
        await prefs.setString(_prefSubCodeKey, 'en');
        await prefs.setString(_prefSubNameKey, 'English (US)');
      }
    } catch (e) {
      _activeSubtitleLangCode = 'en';
      _activeSubtitleLangName = 'English (US)';
    }
  }

  Future<void> _loadAudioPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCode = prefs.getString(_prefAudioCodeKey);
      final savedName = prefs.getString(_prefAudioNameKey);

      if (savedCode == null || savedCode.isEmpty || savedCode == 'off') {
        _activeAudioLangCode = null;
        _activeAudioLangName = null;
      } else {
        _activeAudioLangCode = savedCode;
        _activeAudioLangName = savedName ?? MytubeLanguageDatabase.getName(savedCode);
      }
    } catch (e) {
      _activeAudioLangCode = null;
      _activeAudioLangName = null;
    }
  }

  void switchVideoType(String newType) {
    final cleanType = newType.toUpperCase();
    if (_currentVideoType == cleanType && !_isLoading) return;

    _cancelOnDemandSubtitleTimer();
    _stopDubbingAudio();
    _currentVideoType = cleanType;
    _isUserPaused = false;
    _searchQuery = '';
    _selectedCategory = null;
    _selectedLanguage = null;

    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    _currentIndex = 0;
    _currentCues = [];

    _startFeedStream();
  }

  void _startFeedStream() {
    _isLoading = true;
    _errorMessage = null;
    _isUserPaused = false;
    notifyListeners();

    _feedSubscription?.cancel();
    _feedSubscription = _service
        .getVideosByTypeStream(videoType: _currentVideoType)
        .listen((videoList) {
      _videos = videoList;
      _isLoading = false;
      _errorMessage = null;

      final currentFiltered = filteredVideos;
      if (currentFiltered.isNotEmpty && !_controllers.containsKey(0)) {
        _initControllerAtIndex(0).then((_) {
          _safePlay(currentController);
          _recordView(0);
          _precacheAdjacentVideos(0);
          _syncActiveSubtitleForCurrentVideo(0);
          _syncDubbingAudioForCurrentVideo(0);
        });
      }
      notifyListeners();
    }, onError: (dynamic error) {
      _isLoading = false;
      _errorMessage = error.toString();
      notifyListeners();
    });
  }

  void retryFeed() {
    if (_currentUserId != null) {
      _startFeedStream();
    }
  }
//............................................................................//

//No ke-4....................................................................//
//VIDEO & DUBBING PLAYER MANAGEMENT & AUDIO SYNCHRONIZATION (H+1 PRECACHE)   //
  AudioPlayer _getOrCreateAudioPlayer() {
    if (_dubbingAudioPlayer == null) {
      _dubbingAudioPlayer = AudioPlayer();
      _dubbingAudioPlayer!.setReleaseMode(ReleaseMode.stop);

      if (!kIsWeb) {
        _dubbingAudioPlayer!.setAudioContext(
          AudioContext(
            android: const AudioContextAndroid(
              isSpeakerphoneOn: true,
              stayAwake: true,
              contentType: AndroidContentType.music,
              usageType: AndroidUsageType.media,
              audioFocus: AndroidAudioFocus.none, 
            ),
            iOS: AudioContextIOS(
              category: AVAudioSessionCategory.playback,
              options: {
                AVAudioSessionOptions.mixWithOthers,
              },
            ),
          ),
        );
      }
    }
    return _dubbingAudioPlayer!;
  }

  AudioPlayer _getOrCreateNextAudioPlayer() {
    if (_nextDubbingAudioPlayer == null) {
      _nextDubbingAudioPlayer = AudioPlayer();
      _nextDubbingAudioPlayer!.setReleaseMode(ReleaseMode.stop);

      if (!kIsWeb) {
        _nextDubbingAudioPlayer!.setAudioContext(
          AudioContext(
            android: const AudioContextAndroid(
              isSpeakerphoneOn: true,
              stayAwake: true,
              contentType: AndroidContentType.music,
              usageType: AndroidUsageType.media,
              audioFocus: AndroidAudioFocus.none, 
            ),
            iOS: AudioContextIOS(
              category: AVAudioSessionCategory.playback,
              options: {
                AVAudioSessionOptions.mixWithOthers,
              },
            ),
          ),
        );
      }
    }
    return _nextDubbingAudioPlayer!;
  }

  void _startDubbingTimeout(VideoPlayerController controller) {
    _dubbingTimeoutTimer?.cancel();
    _dubbingTimeoutTimer = Timer(const Duration(seconds: 5), () {
      if (_isWaitingForDubbingAudio) {
        debugPrint('[MYTUBE TIMEOUT] Dubbing timeout 5s tercapai. Melepas gerbang video agar tidak beku.');
        _isWaitingForDubbingAudio = false;
        controller.play();
        notifyListeners();
      }
    });
  }

  void _cancelDubbingTimeout() {
    _dubbingTimeoutTimer?.cancel();
    _dubbingTimeoutTimer = null;
  }

  Future<void> _stopDubbingAudio() async {
    _dubbingSessionId++; 
    _currentDubbingAudioUrl = null; 
    _isWaitingForDubbingAudio = false;
    _cancelDubbingTimeout();

    if (_dubbingAudioPlayer != null) {
      try {
        await _dubbingAudioPlayer!.setVolume(0.0);
        await _dubbingAudioPlayer!.stop();
      } catch (_) {}
    }
  }

  Future<void> _initControllerAtIndex(int index) async {
    final list = filteredVideos;
    if (index < 0 || index >= list.length) return;
    if (_controllers.containsKey(index)) return;

    final video = list[index];

    if (!kIsWeb && (video.hlsStatus == 'PENDING' || video.hlsStatus == 'PROCESSING')) {
      return; 
    }

    String hlsUrl = video.streamingUrl.isNotEmpty ? video.streamingUrl : video.videoUrl;
    String mp4Url = video.videoUrl.isNotEmpty ? video.videoUrl : video.streamingUrl;

    if (hlsUrl.isEmpty && mp4Url.isEmpty) return;

    if (_isLiteModeLocked && !kIsWeb) {
      if (hlsUrl.contains('master.m3u8')) {
        hlsUrl = hlsUrl.replaceAll('master.m3u8', '360p/index.m3u8');
      }
      if (mp4Url.contains('master.m3u8')) {
        mp4Url = mp4Url.replaceAll('master.m3u8', '360p/index.m3u8');
      }
    }

    final bool preferMp4 = kIsWeb;
    final String primaryUrl = preferMp4 ? mp4Url : hlsUrl;
    final String fallbackUrl = preferMp4 ? hlsUrl : mp4Url;

    VideoPlayerController? controller;

    try {
      controller = VideoPlayerController.networkUrl(
        Uri.parse(primaryUrl),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      _controllers[index] = controller;
      await controller.initialize();
    } catch (e) {
      if (_controllers[index] != controller) {
        await controller?.dispose();
        return;
      }
      await controller?.dispose();
      _controllers.remove(index);

      if (fallbackUrl.isNotEmpty && fallbackUrl != primaryUrl) {
        try {
          controller = VideoPlayerController.networkUrl(
            Uri.parse(fallbackUrl),
            videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
          );
          _controllers[index] = controller;
          await controller.initialize();
        } catch (_) { return; }
      } else { return; }
    }

    if (_controllers[index] != controller) {
      controller?.dispose();
      return;
    }

    controller!.setLooping(true);

    final bool isActiveVideo = index == _currentIndex;
    final bool isBypassed = isCurrentVideoAudioBypassed(video);
    final bool hasValidDubbingData = isDubbingActive && !isBypassed && video.dubbing?[_activeAudioLangCode] != null;
    
    // Video tetangga / precache WAJIB 0.0 agar tidak ada kebocoran suara
    final double initialVolume = (isActiveVideo && (!hasValidDubbingData || isBypassed))
        ? ((_isMuted || _isAdActive) ? 0.0 : 1.0)
        : 0.0;
        
    controller.setVolume(initialVolume);

    controller.addListener(() {
      if (!_controllers.containsKey(index) || controller == null) return;
      final activeCtrl = controller;
      if (activeCtrl == null || !activeCtrl.value.isInitialized) return;

      // [KUNCI MATI VIDEO LAMA]: Jika bukan video aktif di layar, wajib pause dan bisu 0.0
      if (index != _currentIndex) {
        if (activeCtrl.value.isPlaying) {
          activeCtrl.pause();
        }
        if (activeCtrl.value.volume > 0.0) {
          activeCtrl.setVolume(0.0);
        }
        return;
      }
      
      if (activeCtrl.value.isBuffering) {
        _bufferingStartTime ??= DateTime.now();
        if (!_isLiteModeLocked && DateTime.now().difference(_bufferingStartTime!).inMilliseconds > 1000) {
          _isLiteModeLocked = true;
          SharedPreferences.getInstance().then((prefs) {
            final expiry = DateTime.now().add(const Duration(hours: 1));
            prefs.setString(_prefLiteModeExpiryKey, expiry.toIso8601String());
          });
        }
        if (isDubbingActive && _dubbingAudioPlayer != null) {
          if (_dubbingAudioPlayer!.state == PlayerState.playing && !_isDubbingSyncing) {
            _dubbingAudioPlayer!.pause();
          }
        }
      } else {
        _bufferingStartTime = null; 
      }

      final currentList = filteredVideos;
      final currentVideo = (index >= 0 && index < currentList.length) ? currentList[index] : null;
      final bool currentBypassed = currentVideo != null && isCurrentVideoAudioBypassed(currentVideo);
      
      final bool currentHasValidDubbingData = isDubbingActive && !currentBypassed && currentVideo?.dubbing?[_activeAudioLangCode] != null;
      final bool isDubbingReady = currentHasValidDubbingData && _currentDubbingAudioUrl == currentVideo!.dubbing![_activeAudioLangCode];

      if (index == _currentIndex && isDubbingReady) {
        if (activeCtrl.value.volume > 0.0) {
          activeCtrl.setVolume(0.0);
        }

        final currentPos = activeCtrl.value.position;
        final bool isRealLoop = _lastSyncedVideoPosition.inMilliseconds > 1500 && currentPos.inMilliseconds < 500;

        if (isRealLoop) {
          _lastSyncedVideoPosition = Duration.zero;
          _dubbingAudioPlayer!.seek(Duration.zero);
          if (activeCtrl.value.isPlaying && !_isUserPaused && !_isAdActive) {
            _dubbingAudioPlayer!.resume();
          }
        } else {
          if ((currentPos.inMilliseconds - _lastSyncedVideoPosition.inMilliseconds).abs() < 1000 || 
              currentPos.inMilliseconds > _lastSyncedVideoPosition.inMilliseconds) {
            _lastSyncedVideoPosition = currentPos;
          }
        }

        // [SMART DRIFT CORRECTOR: SINKRONISASI JEDA JARINGAN]:
        final now = DateTime.now();
        if (_lastDriftCheckTime == null || now.difference(_lastDriftCheckTime!).inMilliseconds > 500) {
          _lastDriftCheckTime = now;
          _dubbingAudioPlayer!.getCurrentPosition().then((audioPos) {
            if (audioPos != null && activeCtrl.value.isInitialized && activeCtrl.value.isPlaying && !activeCtrl.value.isBuffering) {
              final videoPos = activeCtrl.value.position;
              final diff = (videoPos.inMilliseconds - audioPos.inMilliseconds).abs();
              if (diff > 400 && audioPos.inMilliseconds > 0) {
                _dubbingAudioPlayer!.seek(videoPos);
              }
            }
          }).catchError((_) {});
        }

        if (activeCtrl.value.isPlaying && !activeCtrl.value.isBuffering && !_isUserPaused && !_isAdActive) {
          if (_dubbingAudioPlayer!.state != PlayerState.playing && !_isDubbingSyncing) {
            _isDubbingSyncing = true;
            _dubbingAudioPlayer!.resume().then((_) {
              _isDubbingSyncing = false;
            }).catchError((_) {
              _isDubbingSyncing = false;
            });
          }
        } else if (!activeCtrl.value.isPlaying || activeCtrl.value.isBuffering) {
          if (_dubbingAudioPlayer!.state == PlayerState.playing && !_isDubbingSyncing) {
            _isDubbingSyncing = true;
            _dubbingAudioPlayer!.pause().then((_) {
              _isDubbingSyncing = false;
            }).catchError((_) {
              _isDubbingSyncing = false;
            });
          }
        }
      } else if (index == _currentIndex && (!isDubbingActive || currentBypassed) && _dubbingAudioPlayer != null) {
        if (!activeCtrl.value.isBuffering && activeCtrl.value.volume == 0.0 && !_isMuted && !_isAdActive) {
          activeCtrl.setVolume(1.0);
        }
        if (_dubbingAudioPlayer!.state == PlayerState.playing) {
          _dubbingAudioPlayer!.setVolume(0.0);
          _dubbingAudioPlayer!.stop();
        }
      }

      // Pemutaran normal hanya diizinkan jika TIDAK sedang dalam gerbang tunggu dubbing
      if (index == _currentIndex &&
          !_isWaitingForDubbingAudio &&
          !activeCtrl.value.isPlaying &&
          !activeCtrl.value.isBuffering &&
          !_isUserPaused &&
          !_isAdActive &&
          activeCtrl.value.position < activeCtrl.value.duration) {
        activeCtrl.play();
      }
    });

    if (index == _currentIndex &&
        _activeSubtitleLangCode != null &&
        video.subtitles?[_activeSubtitleLangCode!] != null) {
      _applySubtitleToController(video, _activeSubtitleLangCode!);
    }

    notifyListeners();
  }

  Future<void> _safePlay(VideoPlayerController? controller) async {
    if (controller == null || !controller.value.isInitialized) return;
    if (_isAdActive) return; 

    try {
      _isUserPaused = false;
      
      final list = filteredVideos;
      final currentVideo = (list.isNotEmpty && _currentIndex < list.length) ? list[_currentIndex] : null;
      final bool currentBypassed = currentVideo != null && isCurrentVideoAudioBypassed(currentVideo);
      
      final bool hasValidDubbingData = isDubbingActive && !currentBypassed && currentVideo?.dubbing?[_activeAudioLangCode] != null;
      final bool isDubbingReady = hasValidDubbingData && _currentDubbingAudioUrl == currentVideo!.dubbing![_activeAudioLangCode];

      if (hasValidDubbingData) {
        await controller.setVolume(0.0);

        if (isDubbingReady && _dubbingAudioPlayer != null) {
          // [KASUS 1 - PRECACHE H+1 SUKSES]: Audio sudah matang di memori -> Langsung main serentak 0 detik!
          _isWaitingForDubbingAudio = false;
          _cancelDubbingTimeout();
          await _dubbingAudioPlayer!.setVolume((_isMuted || _isAdActive) ? 0.0 : 1.0);
          await _dubbingAudioPlayer!.resume();
          await controller.play();
        } else {
          // [KASUS 2 - GERBANG TUNGGU FALLBACK GATE]: Audio belum selesai di-download -> Tahan video di frame 0!
          _isWaitingForDubbingAudio = true;
          controller.pause();
          _startDubbingTimeout(controller);
          notifyListeners();
        }
      } else {
        // Video bermain dengan audio asli
        _isWaitingForDubbingAudio = false;
        _cancelDubbingTimeout();
        await controller.setVolume(_isMuted ? 0.0 : 1.0);
        if (_dubbingAudioPlayer != null) {
          await _dubbingAudioPlayer!.setVolume(0.0);
          await _dubbingAudioPlayer!.stop();
        }
        await controller.play();
      }
    } catch (e) {
      if (kIsWeb && !_isMuted) {
        try {
          _isAutoplaySoundBlocked = true;
          await controller.setVolume(0.0);
          await controller.play();
          notifyListeners();
        } catch (_) {}
      }
    }
  }

  void onPageChanged(int newIndex) {
    final list = filteredVideos;
    if (newIndex == _currentIndex || newIndex < 0 || newIndex >= list.length) return;

    _cancelOnDemandSubtitleTimer();
    _isSubtitleLoading = false;
    _subtitleLoadingMessage = null;
    _isDubbingSyncing = false;
    
    // [SMART TRANSISI PRECACHE H+1]:
    // Jika audio dubbing video baru sudah di-precache di _nextDubbingAudioPlayer, transfer instan!
    if (_nextDubbingPrecachedIndex == newIndex &&
        _nextDubbingAudioPlayer != null &&
        _nextDubbingAudioUrl != null) {
      _dubbingAudioPlayer?.dispose();
      _dubbingAudioPlayer = _nextDubbingAudioPlayer;
      _currentDubbingAudioUrl = _nextDubbingAudioUrl;
      _nextDubbingAudioPlayer = null;
      _nextDubbingAudioUrl = null;
      _nextDubbingPrecachedIndex = null;
      _dubbingSessionId++;
    } else {
      _stopDubbingAudio();
    }

    // Pause dan bisukan volume 0.0 seluruh controller video lama serentak
    for (final entry in _controllers.entries) {
      if (entry.key != newIndex) {
        try {
          entry.value.pause();
          entry.value.setVolume(0.0);
        } catch (_) {}
      }
    }

    _isUserPaused = false;
    _currentCues = [];
    _lastSyncedVideoPosition = Duration.zero;
    _lastDriftCheckTime = null; 

    _currentIndex = newIndex;

    if (_isAutoplaySoundBlocked) {
      _isAutoplaySoundBlocked = false;
      _isMuted = false;
    }

    final newController = _controllers[_currentIndex];
    if (newController != null && newController.value.isInitialized) {
      _safePlay(newController);
      _recordView(_currentIndex);
      _syncActiveSubtitleForCurrentVideo(_currentIndex);
      _syncDubbingAudioForCurrentVideo(_currentIndex);
      _precacheAdjacentVideos(_currentIndex);
    } else {
      _initControllerAtIndex(_currentIndex).then((_) {
        _safePlay(_controllers[_currentIndex]);
        _recordView(_currentIndex);
        _syncActiveSubtitleForCurrentVideo(_currentIndex);
        _syncDubbingAudioForCurrentVideo(_currentIndex);
        _precacheAdjacentVideos(_currentIndex);
      });
    }

    _cleanupDistantControllers(_currentIndex);
    notifyListeners();
  }

  void _precacheAdjacentVideos(int index) {
    final list = filteredVideos;
    if (index + 1 < list.length) {
      // 1. Precache Video H+1 (ExoPlayer)
      if (!_controllers.containsKey(index + 1)) {
        _initControllerAtIndex(index + 1);
      }
      // 2. [SMART PRECACHE DUBBING H+1]: Ikutkan audio dubbing dalam irama precache!
      _precacheDubbingForIndex(index + 1);
    }
  }

  void _cleanupDistantControllers(int activeIndex) {
    final keysToRemove = <int>[];
    _controllers.forEach((index, controller) {
      if ((index - activeIndex).abs() > 1) {
        try {
          controller.pause();
          controller.setVolume(0.0);
          controller.dispose();
        } catch (_) {}
        keysToRemove.add(index);
      }
    });
    for (final key in keysToRemove) {
      _controllers.remove(key);
    }

    // Bersihkan juga player precache jika jaraknya sudah jauh
    if (_nextDubbingPrecachedIndex != null && (_nextDubbingPrecachedIndex! - activeIndex).abs() > 1) {
      try {
        _nextDubbingAudioPlayer?.dispose();
      } catch (_) {}
      _nextDubbingAudioPlayer = null;
      _nextDubbingAudioUrl = null;
      _nextDubbingPrecachedIndex = null;
    }
  }

  void togglePlayPause() {
    final controller = currentController;
    if (controller != null && controller.value.isInitialized) {
      if (_isAutoplaySoundBlocked) {
        _isAutoplaySoundBlocked = false;
        _isMuted = false;
      }

      final list = filteredVideos;
      final currentVideo = (list.isNotEmpty && _currentIndex < list.length) ? list[_currentIndex] : null;
      final bool currentBypassed = currentVideo != null && isCurrentVideoAudioBypassed(currentVideo);
      
      final bool hasValidDubbingData = isDubbingActive && !currentBypassed && currentVideo?.dubbing?[_activeAudioLangCode] != null;
      final bool isDubbingReady = hasValidDubbingData && _currentDubbingAudioUrl == currentVideo!.dubbing![_activeAudioLangCode];

      if (controller.value.isPlaying) {
        _isUserPaused = true;
        controller.pause();
        _dubbingAudioPlayer?.pause();
      } else {
        _isUserPaused = false;
        if (hasValidDubbingData) {
          controller.setVolume(0.0);
          if (isDubbingReady) {
            controller.play();
            _dubbingAudioPlayer?.setVolume((_isMuted || _isAdActive) ? 0.0 : 1.0);
            _dubbingAudioPlayer?.resume();
          } else {
            // Jika belum ready saat user unpause, aktifkan gerbang tunggu
            _isWaitingForDubbingAudio = true;
            controller.pause();
            _startDubbingTimeout(controller);
          }
        } else {
          controller.setVolume((_isMuted || _isAdActive) ? 0.0 : 1.0);
          controller.play();
          _dubbingAudioPlayer?.setVolume(0.0);
          _dubbingAudioPlayer?.stop();
        }
      }
      notifyListeners();
    }
  }

  void pauseCurrentVideoForSearch() {
    if (currentController != null && currentController!.value.isInitialized && currentController!.value.isPlaying) {
      _isUserPaused = true;
      currentController!.pause();
      _dubbingAudioPlayer?.pause();
      notifyListeners();
    }
  }

  void unmuteByGesture() {
    _isAutoplaySoundBlocked = false;
    _isMuted = false;
    _isUserPaused = false;

    final list = filteredVideos;
    final currentVideo = (list.isNotEmpty && _currentIndex < list.length) ? list[_currentIndex] : null;
    final bool currentBypassed = currentVideo != null && isCurrentVideoAudioBypassed(currentVideo);
    
    final bool hasValidDubbingData = isDubbingActive && !currentBypassed && currentVideo?.dubbing?[_activeAudioLangCode] != null;
    final bool isDubbingReady = hasValidDubbingData && _currentDubbingAudioUrl == currentVideo!.dubbing![_activeAudioLangCode];

    if (hasValidDubbingData) {
      currentController?.setVolume(0.0);
      if (isDubbingReady) {
        _dubbingAudioPlayer?.setVolume(1.0);
        _dubbingAudioPlayer?.resume();
      }
    } else {
      currentController?.setVolume(1.0);
      _dubbingAudioPlayer?.setVolume(0.0);
      _dubbingAudioPlayer?.stop();
    }
    notifyListeners();
  }

  void toggleMute() {
    _isMuted = !_isMuted;
    _isAutoplaySoundBlocked = false;

    final list = filteredVideos;
    final currentVideo = (list.isNotEmpty && _currentIndex < list.length) ? list[_currentIndex] : null;
    final bool currentBypassed = currentVideo != null && isCurrentVideoAudioBypassed(currentVideo);
    
    final bool hasValidDubbingData = isDubbingActive && !currentBypassed && currentVideo?.dubbing?[_activeAudioLangCode] != null;
    final bool isDubbingReady = hasValidDubbingData && _currentDubbingAudioUrl == currentVideo!.dubbing![_activeAudioLangCode];

    _controllers.forEach((_, controller) {
      controller.setVolume((hasValidDubbingData || _isMuted) ? 0.0 : 1.0);
    });

    if (hasValidDubbingData) {
      if (isDubbingReady) {
        _dubbingAudioPlayer?.setVolume(_isMuted ? 0.0 : 1.0);
      }
    } else {
      _dubbingAudioPlayer?.setVolume(0.0);
      _dubbingAudioPlayer?.stop();
    }
    notifyListeners();
  }
//............................................................................//

//No ke-5....................................................................//
//FILTER, SEARCH, HOME RESET & SUBTITLE / DUBBING ACTION HANDLERS            //
  void setSearchQuery(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;
    notifyListeners(); 

    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(const Duration(milliseconds: 600), () {
      if (_appliedSearchQuery != _searchQuery) {
        _appliedSearchQuery = _searchQuery;
        _resetControllersForFilteredList();
        notifyListeners();
      }
    });
  }

  void clearSearchQuery() {
    _searchQuery = '';
    _searchDebounceTimer?.cancel();
    if (_appliedSearchQuery != '') {
      _appliedSearchQuery = '';
      _resetControllersForFilteredList();
    }
    notifyListeners();
  }

  void setCategoryFilter(String? category) {
    _selectedCategory = category;
    _resetControllersForFilteredList();
    notifyListeners();
  }

  void setLanguageFilter(String? language) {
    _selectedLanguage = language;
    _resetControllersForFilteredList();
    notifyListeners();
  }

  void setLocationFilter(String? location) {
    _selectedLocation = location;
    _resetControllersForFilteredList();
    notifyListeners();
  }

  void clearAllFilters() {
    _searchQuery = '';
    _appliedSearchQuery = '';
    _selectedCategory = null;
    _selectedLanguage = null;
    _selectedLocation = null;
    _resetControllersForFilteredList();
    notifyListeners();
  }

  void resetToHomeDefault() {
    _searchQuery = '';
    _appliedSearchQuery = '';
    _selectedCategory = null;
    _selectedLanguage = null;
    _selectedLocation = null;

    if (_currentVideoType != 'SHORT') {
      switchVideoType('SHORT');
    } else {
      _resetControllersForFilteredList();
      notifyListeners();
    }
  }

  void _resetControllersForFilteredList() {
    _cancelOnDemandSubtitleTimer();
    _stopDubbingAudio();
    _currentIndex = 0;
    _currentCues = [];
    
    for (final controller in _controllers.values) {
      controller.pause(); 
      controller.dispose();
    }
    _controllers.clear();

    final list = filteredVideos;
    if (list.isNotEmpty) {
      _initControllerAtIndex(0).then((_) {
        _safePlay(currentController);
        _recordView(0);
        _precacheAdjacentVideos(0);
        _syncActiveSubtitleForCurrentVideo(0);
        _syncDubbingAudioForCurrentVideo(0);
      });
    }
  }

  void _cancelOnDemandSubtitleTimer() {
    _onDemandSubtitleTimer?.cancel();
    _onDemandSubtitleTimer = null;
  }

  Future<void> disableSubtitles() async {
    _cancelOnDemandSubtitleTimer();
    _activeSubtitleLangCode = null;
    _activeSubtitleLangName = null;
    _isSubtitleLoading = false;
    _subtitleLoadingMessage = null;
    _currentCues = [];
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefSubCodeKey, 'off');
    } catch (e) {}
  }

  Future<void> selectSubtitleLanguage({
    required String langCode,
    required String langName,
  }) async {
    final list = filteredVideos;
    if (_currentIndex < 0 || _currentIndex >= list.length) return;

    if (_activeSubtitleLangCode == langCode) {
      await disableSubtitles();
      return;
    }

    _cancelOnDemandSubtitleTimer();
    _activeSubtitleLangCode = langCode;
    _activeSubtitleLangName = langName;
    _currentCues = [];
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefSubCodeKey, langCode);
      await prefs.setString(_prefSubNameKey, langName);
    } catch (e) {}

    await _syncActiveSubtitleForCurrentVideo(_currentIndex, immediate: true);
  }

  Future<void> _syncActiveSubtitleForCurrentVideo(
    int targetIndex, {
    bool immediate = false,
  }) async {
    _cancelOnDemandSubtitleTimer();

    if (_activeSubtitleLangCode == null || _activeSubtitleLangName == null) return;

    final list = filteredVideos;
    if (targetIndex < 0 || targetIndex >= list.length) return;

    if (targetIndex != _currentIndex) return;

    final video = list[targetIndex];
    final langCode = _activeSubtitleLangCode!;
    final langName = _activeSubtitleLangName!;
    final existingUrl = video.subtitles?[langCode];

    if (existingUrl != null && existingUrl.isNotEmpty) {
      await _applySubtitleToController(video, langCode);
      return;
    }

    Future<void> executeAiTranslation() async {
      if (_currentIndex != targetIndex || _activeSubtitleLangCode != langCode) return;

      if (_currentIndex == targetIndex) {
        _isSubtitleLoading = true;
        _subtitleLoadingMessage = 'AI sedang menyiapkan subtitle $langName...';
        notifyListeners();
      }

      try {
        final newUrl = await _service.requestOnDemandSubtitle(
          videoId: video.id,
          creatorEmail: video.uploaderEmail,
          channelId: video.channelId,
          videoType: video.videoType,
          targetLanguageCode: langCode,
          targetLanguageName: langName,
        );

        if (newUrl != null && newUrl.isNotEmpty) {
          final updatedSubtitles = Map<String, String>.from(video.subtitles ?? {});
          updatedSubtitles[langCode] = newUrl;

          final rawIndex = _videos.indexWhere((v) => v.id == video.id);
          if (rawIndex != -1) {
            _videos[rawIndex] = _videos[rawIndex].copyWith(subtitles: updatedSubtitles);
          }

          if (_currentIndex == targetIndex && _activeSubtitleLangCode == langCode) {
            await _applySubtitleToController(
              _videos[rawIndex != -1 ? rawIndex : targetIndex],
              langCode,
            );
          }
        }
      } catch (e) {
      } finally {
        if (_currentIndex == targetIndex) {
          _isSubtitleLoading = false;
          _subtitleLoadingMessage = null;
          notifyListeners();
        }
      }
    }

    if (immediate) {
      await executeAiTranslation();
      return;
    }

    _onDemandSubtitleTimer = Timer(const Duration(seconds: 3), () async {
      await executeAiTranslation();
    });
  }

  Future<void> _applySubtitleToController(VideoMytubeModel video, String langCode) async {
    final list = filteredVideos;
    if (_currentIndex < 0 || _currentIndex >= list.length || list[_currentIndex].id != video.id) {
      return;
    }

    final vttUrl = video.subtitles?[langCode];
    if (vttUrl == null || vttUrl.isEmpty) {
      if (_currentIndex >= 0 && _currentIndex < list.length && list[_currentIndex].id == video.id) {
        _currentCues = [];
        notifyListeners();
      }
      return;
    }

    try {
      String vttContent;
      if (_vttContentCache.containsKey(vttUrl)) {
        vttContent = _vttContentCache[vttUrl]!;
      } else {
        final res = await http.get(Uri.parse(vttUrl));
        if (res.statusCode == 200) {
          vttContent = res.body;
          _vttContentCache[vttUrl] = vttContent;
        } else {
          return;
        }
      }

      if (_currentIndex < 0 || _currentIndex >= list.length || list[_currentIndex].id != video.id) {
        return;
      }

      _currentCues = _parseVttContent(vttContent);
      notifyListeners();
    } catch (e) {}
  }

  List<SubtitleCue> _parseVttContent(String content) {
    final cues = <SubtitleCue>[];
    final lines = content.replaceAll('\r\n', '\n').split('\n');
    final timePattern = RegExp(r'(\d{2}:)?\d{2}:\d{2}\.\d{3}\s*-->\s*(\d{2}:)?\d{2}:\d{2}\.\d{3}');

    Duration? currentStart;
    Duration? currentEnd;
    StringBuffer currentText = StringBuffer();

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();

      if (line == 'WEBVTT' || line.isEmpty) {
        if (currentStart != null && currentEnd != null && currentText.isNotEmpty) {
          cues.add(SubtitleCue(start: currentStart, end: currentEnd, text: currentText.toString().trim()));
          currentStart = null;
          currentEnd = null;
          currentText.clear();
        }
        continue;
      }

      if (timePattern.hasMatch(line)) {
        final parts = line.split(RegExp(r'\s*-->\s*'));
        if (parts.length == 2) {
          currentStart = _parseDuration(parts[0]);
          currentEnd = _parseDuration(parts[1]);
        }
      } else if (currentStart != null && currentEnd != null) {
        if (currentText.isNotEmpty) currentText.write('\n');
        currentText.write(line);
      }
    }

    if (currentStart != null && currentEnd != null && currentText.isNotEmpty) {
      cues.add(SubtitleCue(start: currentStart, end: currentEnd, text: currentText.toString().trim()));
    }
    return cues;
  }

  Duration _parseDuration(String timeString) {
    final parts = timeString.trim().split(':');
    int hours = 0, minutes = 0, seconds = 0, milliseconds = 0;
    if (parts.length == 3) {
      hours = int.parse(parts[0]);
      minutes = int.parse(parts[1]);
      final secParts = parts[2].split('.');
      seconds = int.parse(secParts[0]);
      milliseconds = int.parse(secParts[1]);
    } else if (parts.length == 2) {
      minutes = int.parse(parts[0]);
      final secParts = parts[1].split('.');
      seconds = int.parse(secParts[0]);
      milliseconds = int.parse(secParts[1]);
    }
    return Duration(hours: hours, minutes: minutes, seconds: seconds, milliseconds: milliseconds);
  }

  Future<void> selectAudioLanguage({
    required String langCode,
    required String langName,
  }) async {
    final list = filteredVideos;
    if (_currentIndex < 0 || _currentIndex >= list.length) return;

    if (_activeAudioLangCode == langCode) {
      return; 
    }

    _activeAudioLangCode = langCode;
    _activeAudioLangName = langName;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefAudioCodeKey, langCode);
      await prefs.setString(_prefAudioNameKey, langName);
    } catch (e) {}

    await _syncDubbingAudioForCurrentVideo(_currentIndex, immediate: true);
    // Segera mulai precache video tetangga H+1 dengan bahasa baru ini!
    _precacheDubbingForIndex(_currentIndex + 1);
  }

  Future<void> resetAudioToOriginal() async {
    _activeAudioLangCode = null;
    _activeAudioLangName = null;
    _isDubbingLoading = false;
    _dubbingLoadingMessage = null;
    _isDubbingSyncing = false;
    _isWaitingForDubbingAudio = false;
    _cancelDubbingTimeout();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefAudioCodeKey, 'off');
      await prefs.remove(_prefAudioNameKey);
    } catch (e) {}

    await _stopDubbingAudio();

    final active = currentController;
    if (active != null && active.value.isInitialized) {
      await active.setVolume((_isMuted || _isAdActive) ? 0.0 : 1.0);
      if (!active.value.isPlaying && !_isUserPaused && !_isAdActive) {
        await active.play();
      }
    }
    notifyListeners();
  }

  // --- [BARU - SMART PRECACHE DUBBING H+1 DI LATAR BELAKANG] ---
  Future<void> _precacheDubbingForIndex(int targetIndex) async {
    if (!isDubbingActive || _activeAudioLangCode == null) return;
    final list = filteredVideos;
    if (targetIndex < 0 || targetIndex >= list.length) return;

    final video = list[targetIndex];
    if (isCurrentVideoAudioBypassed(video)) return;

    final langCode = _activeAudioLangCode!;
    String? audioUrl = video.dubbing?[langCode];

    // Jika video H+1 belum memiliki file dubbing, panggil Cloud Function secara diam-diam di background!
    if (audioUrl == null || audioUrl.isEmpty) {
      try {
        final result = await _service.requestOnDemandDubbing(
          videoId: video.id,
          creatorEmail: video.uploaderEmail,
          channelId: video.channelId,
          videoType: video.videoType,
          targetLanguageCode: langCode,
          targetLanguageName: _activeAudioLangName ?? '',
        );

        if (result != null && result['url'] != null) {
          audioUrl = result['url'] as String?;
          final updatedDubbing = Map<String, String>.from(video.dubbing ?? {});
          updatedDubbing[langCode] = audioUrl!;

          final rawIdx = _videos.indexWhere((v) => v.id == video.id);
          if (rawIdx != -1) {
            _videos[rawIdx] = _videos[rawIdx].copyWith(dubbing: updatedDubbing);
          }
        }
      } catch (_) {}
    }

    // Jika URL sudah siap, siapkan AudioPlayer cadangan di memori HP!
    if (audioUrl != null && audioUrl.isNotEmpty) {
      try {
        final player = _getOrCreateNextAudioPlayer();
        await player.setVolume(0.0);
        await player.setSource(UrlSource(audioUrl));
        _nextDubbingAudioUrl = audioUrl;
        _nextDubbingPrecachedIndex = targetIndex;
      } catch (_) {}
    }
  }

  Future<void> _syncDubbingAudioForCurrentVideo(
    int targetIndex, {
    bool immediate = false,
  }) async {
    if (_activeAudioLangCode == null || _activeAudioLangName == null) {
      await _stopDubbingAudio();
      final active = currentController;
      if (active != null && active.value.isInitialized) {
        await active.setVolume((_isMuted || _isAdActive) ? 0.0 : 1.0);
      }
      return;
    }

    final list = filteredVideos;
    if (targetIndex < 0 || targetIndex >= list.length) return;
    if (targetIndex != _currentIndex) return;

    final video = list[targetIndex];
    final langCode = _activeAudioLangCode!;
    final langName = _activeAudioLangName!;

    if (isVideoLanguageMatchingTarget(video, langCode, langName)) {
      await _stopDubbingAudio();
      final active = currentController;
      if (active != null && active.value.isInitialized) {
        await active.setVolume((_isMuted || _isAdActive) ? 0.0 : 1.0);
      }
      notifyListeners();
      return;
    }

    final existingUrl = video.dubbing?[langCode];
    if (existingUrl != null && existingUrl.isNotEmpty) {
      await _applyDubbingAudioToController(existingUrl);
      return;
    }

    if (_currentIndex == targetIndex) {
      _isDubbingLoading = true;
      _dubbingLoadingMessage = 'Preparing audio dubbing, wait a minute...';
      notifyListeners();
    }

    try {
      final result = await _service.requestOnDemandDubbing(
        videoId: video.id,
        creatorEmail: video.uploaderEmail,
        channelId: video.channelId,
        videoType: video.videoType,
        targetLanguageCode: langCode,
        targetLanguageName: langName,
      );

      if (_currentIndex != targetIndex) return;

      if (result != null) {
        if (result['isOriginal'] == true) {
          await _stopDubbingAudio();
          final active = currentController;
          if (active != null && active.value.isInitialized) {
            await active.setVolume((_isMuted || _isAdActive) ? 0.0 : 1.0);
          }
          return;
        }

        final newUrl = result['url'] as String?;
        if (newUrl != null && newUrl.isNotEmpty) {
          final updatedDubbing = Map<String, String>.from(video.dubbing ?? {});
          updatedDubbing[langCode] = newUrl;

          final rawIndex = _videos.indexWhere((v) => v.id == video.id);
          if (rawIndex != -1) {
            _videos[rawIndex] = _videos[rawIndex].copyWith(dubbing: updatedDubbing);
          }

          if (_currentIndex == targetIndex && _activeAudioLangCode == langCode) {
            await _applyDubbingAudioToController(newUrl);
          }
        }
      }
    } catch (e) {
    } finally {
      if (_currentIndex == targetIndex) {
        _isDubbingLoading = false;
        _dubbingLoadingMessage = null;
        notifyListeners();
      }
    }
  }

  Future<void> _applyDubbingAudioToController(String audioUrl) async {
    final controller = currentController;
    if (controller == null || !controller.value.isInitialized) return;

    final list = filteredVideos;
    final currentVideo = (_currentIndex >= 0 && _currentIndex < list.length) ? list[_currentIndex] : null;

    if (!isDubbingActive || (currentVideo != null && isCurrentVideoAudioBypassed(currentVideo))) {
      await _stopDubbingAudio();
      await controller.setVolume((_isMuted || _isAdActive) ? 0.0 : 1.0);
      return;
    }

    _dubbingSessionId++;
    final int currentSession = _dubbingSessionId;

    final player = _getOrCreateAudioPlayer();
    await controller.setVolume(0.0);

    try {
      final currentPos = controller.value.position;
      final double volume = (_isMuted || _isAdActive) ? 0.0 : 1.0;

      await player.setVolume(volume);
      await player.play(
        UrlSource(audioUrl),
        position: currentPos,
        volume: volume,
      );

      // Jika user sudah geser selama proses buffering MP3:
      if (currentSession != _dubbingSessionId) {
        await player.stop();
        return;
      }

      _currentDubbingAudioUrl = audioUrl;

      // [PELEPASAN GERBANG TUNGGU]: Audio dubbing sudah 100% siap memutar!
      _isWaitingForDubbingAudio = false;
      _cancelDubbingTimeout();

      // Lepas pemutaran video dan dubbing serentak dari detik awal!
      if (!controller.value.isPlaying && !_isUserPaused && !_isAdActive) {
        await controller.play();
      }

      if (!controller.value.isPlaying || _isUserPaused || _isAdActive) {
        await player.pause();
      }
    } catch (e) {
      debugPrint('[MYTUBE AUDIO ERROR] Gagal apply audio dubbing: $e');
    }
    notifyListeners();
  }
//............................................................................//

//No ke-6....................................................................//
//USER SOCIAL INTERACTIONS WITH TASTE PROFILE SIGNAL INTEGRATION             //
  Future<void> checkInitialInteractionStatus(String videoId) async {
    if (_currentUserId == null || _currentUserId!.isEmpty) return;

    String? channelId;
    String? uploaderEmail;
    String? uploaderId;
    String videoType = 'SHORT';
    try {
      final vid = _videos.firstWhere((v) => v.id == videoId);
      channelId = vid.channelId;
      uploaderEmail = vid.uploaderEmail;
      uploaderId = vid.uploaderId;
      videoType = vid.videoType;
    } catch (_) {}

    final isLiked = await _service.checkIsVideoLiked(
      videoId: videoId,
      userId: _currentUserId!,
      channelId: channelId,
      uploaderEmail: uploaderEmail,
      uploaderId: uploaderId,
      videoType: videoType,
    );
    if (isLiked) {
      _likedVideoIds.add(videoId);
    }

    final isSaved = await _service.checkIsVideoSaved(
      videoId: videoId,
      userId: _currentUserId!,
    );
    if (isSaved) {
      _savedVideoIds.add(videoId);
    }
    notifyListeners();
  }

  bool isVideoLiked(String videoId) => _likedVideoIds.contains(videoId);
  bool isVideoSaved(String videoId) => _savedVideoIds.contains(videoId);

  Future<void> toggleLikeCurrentVideo() async {
    final list = filteredVideos;
    if (_currentUserId == null || list.isEmpty) return;
    final currentVideo = list[_currentIndex];
    final videoId = currentVideo.id;

    final wasLiked = _likedVideoIds.contains(videoId);
    if (wasLiked) {
      _likedVideoIds.remove(videoId);
    } else {
      _likedVideoIds.add(videoId);
    }

    final rawIndex = _videos.indexWhere((v) => v.id == videoId);
    if (rawIndex != -1) {
      final newLikes = wasLiked
          ? (_videos[rawIndex].likesCount - 1).clamp(0, 999999999)
          : _videos[rawIndex].likesCount + 1;
      _videos[rawIndex] = _videos[rawIndex].copyWith(likesCount: newLikes);
    }
    notifyListeners();

    final success = await _service.toggleLikeVideo(
      videoId: videoId,
      userId: _currentUserId!,
      channelId: currentVideo.channelId,
      uploaderEmail: currentVideo.uploaderEmail,
      uploaderId: currentVideo.uploaderId,
      videoType: currentVideo.videoType,
      category: currentVideo.category,
      language: currentVideo.language,
      channelName: currentVideo.channelName,
      topicLocations: currentVideo.targetLocations, 
    );

    if (success != !wasLiked) {
      if (success) {
        _likedVideoIds.add(videoId);
      } else {
        _likedVideoIds.remove(videoId);
      }
      notifyListeners();
    }
  }

  Future<void> toggleSaveCurrentVideo() async {
    final list = filteredVideos;
    if (_currentUserId == null || list.isEmpty) return;
    final currentVideo = list[_currentIndex];
    final videoId = currentVideo.id;

    final wasSaved = _savedVideoIds.contains(videoId);
    if (wasSaved) {
      _savedVideoIds.remove(videoId);
    } else {
      _savedVideoIds.add(videoId);
    }

    final rawIndex = _videos.indexWhere((v) => v.id == videoId);
    if (rawIndex != -1) {
      final newSaves = wasSaved
          ? (_videos[rawIndex].savesCount - 1).clamp(0, 999999999)
          : _videos[rawIndex].savesCount + 1;
      _videos[rawIndex] = _videos[rawIndex].copyWith(savesCount: newSaves);
    }
    notifyListeners();

    final success = await _service.toggleSaveVideo(
      videoId: videoId,
      userId: _currentUserId!,
      channelId: currentVideo.channelId,
      uploaderEmail: currentVideo.uploaderEmail,
      uploaderId: currentVideo.uploaderId,
      videoType: currentVideo.videoType,
      category: currentVideo.category,
      language: currentVideo.language,
      channelName: currentVideo.channelName,
      topicLocations: currentVideo.targetLocations, 
    );

    if (success != !wasSaved) {
      if (success) {
        _savedVideoIds.add(videoId);
      } else {
        _savedVideoIds.remove(videoId);
      }
      notifyListeners();
    }
  }

  Future<void> recordShareCurrentVideo() async {
    final list = filteredVideos;
    if (list.isEmpty) return;
    final currentVideo = list[_currentIndex];

    final rawIndex = _videos.indexWhere((v) => v.id == currentVideo.id);
    if (rawIndex != -1) {
      _videos[rawIndex] = _videos[rawIndex].copyWith(
        sharesCount: _videos[rawIndex].sharesCount + 1,
      );
    }
    notifyListeners();

    await _service.incrementShareCount(
      currentVideo.id,
      channelId: currentVideo.channelId,
      uploaderEmail: currentVideo.uploaderEmail,
      uploaderId: currentVideo.uploaderId,
      videoType: currentVideo.videoType,
      userId: _currentUserId,
      category: currentVideo.category,
      language: currentVideo.language,
      channelName: currentVideo.channelName,
      topicLocations: currentVideo.targetLocations, 
    );
  }

  void _recordView(int index) {
    final list = filteredVideos;
    if (index >= 0 && index < list.length) {
      final video = list[index];
      _service.incrementViewCount(
        video.id,
        channelId: video.channelId,
        uploaderEmail: video.uploaderEmail,
        uploaderId: video.uploaderId,
        videoType: video.videoType,
        userId: _currentUserId,
        category: video.category,
        language: video.language,
        channelName: video.channelName,
        topicLocations: video.targetLocations, 
      );
    }
  }
//............................................................................//

//No ke-7....................................................................//
//DISPOSAL & RESOURCE CLEANUP                                                //
  @override
  void dispose() {
    _cancelOnDemandSubtitleTimer();
    _stopDubbingAudio();
    _dubbingAudioPlayer?.dispose();
    _dubbingAudioPlayer = null;

    _feedSubscription?.cancel();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    super.dispose();
  }
} // <--- PENUTUP RESMI KELAS MytubeFeedViewModel

class SubtitleCue {
  final Duration start;
  final Duration end;
  final String text;

  SubtitleCue({
    required this.start,
    required this.end,
    required this.text,
  });
}
//............................................................................//