//============================================================================//
// DIREKTORI: lib/entertainment/mytube/view_model/                           //
// FILE: MYTUBE_FEED_VIEW_MODEL.DART                                         //
// VIEW MODEL FEED MYTUBE (SHORTS, LONGS, SEARCH, FILTER, POSITION-AWARE CC) //
//============================================================================//

//No ke-1....................................................................//
//IMPORTS & DEPENDENCIES                                                     //
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

import '../models/video_mytube_model.dart';
import '../services/firestore_mytube_service.dart';
//............................................................................//

//No ke-2....................................................................//
//STATE PROPERTIES, CONTROLLER MAPS & SUBTITLE STATE                         //
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

  // [SMART LITE-MODE (QoS)]: Pengawas & Pengunci Resolusi 360p (Durasi 1 Jam)
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

  bool get isFilterActive =>
      _appliedSearchQuery.trim().isNotEmpty ||
      _selectedCategory != null ||
      _selectedLanguage != null;

  String get filterKey => '${_currentVideoType}_${_appliedSearchQuery}_${_selectedCategory}_${_selectedLanguage}';

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
    } else {
      final active = currentController;
      if (active != null && active.value.isInitialized) {
        active.setVolume(_isMuted ? 0.0 : 1.0);
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
    await _loadNetworkPreferences(); // [BARU]: Periksa status sinyal sebelumnya
    _startFeedStream();
  }

  // [PENGINGAT KONEKSI]: Memeriksa apakah user sedang dalam masa penalti 1 jam Lite Mode
  Future<void> _loadNetworkPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final expiryIso = prefs.getString(_prefLiteModeExpiryKey);
      
      if (expiryIso != null && expiryIso.isNotEmpty) {
        final expiryTime = DateTime.parse(expiryIso);
        if (DateTime.now().isBefore(expiryTime)) {
          _isLiteModeLocked = true;
          debugPrint('[MYTUBE QoS] Sinyal terdeteksi buruk sebelumnya. Lite Mode (360p) dikunci sampai $expiryTime');
        } else {
          // Jika waktu 1 jam sudah lewat, kembalikan ke mode kualitas tinggi (Adaptif)
          _isLiteModeLocked = false;
          await prefs.remove(_prefLiteModeExpiryKey);
          debugPrint('[MYTUBE QoS] Batas 1 jam selesai. Kembali ke Mode Adaptif Resolusi Tinggi.');
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

  void switchVideoType(String newType) {
    final cleanType = newType.toUpperCase();
    if (_currentVideoType == cleanType && !_isLoading) return;

    _cancelOnDemandSubtitleTimer();
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
//VIDEO PLAYER MANAGEMENT, SMART ROUTING & HYBRID FALLBACK                   //
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

    // [PEMBAJAKAN URL (URL HIJACKING) UNTUK LITE MODE]:
    // Jika Lite Mode aktif (karena sinyal buruk), jangan berikan master.m3u8
    // Tembak langsung ke playlist 360p agar HP tidak pernah mencoba melompat ke 480p/720p!
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
      controller = VideoPlayerController.networkUrl(Uri.parse(primaryUrl));
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
          controller = VideoPlayerController.networkUrl(Uri.parse(fallbackUrl));
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
    controller.setVolume((_isMuted || _isAdActive) ? 0.0 : 1.0);

    controller.addListener(() {
      if (!_controllers.containsKey(index)) return;
      
      // [PENGAWAS SINYAL 1 DETIK (THE WATCHDOG)]:
      // Memantau kestabilan koneksi saat memutar video
      if (controller!.value.isBuffering) {
        _bufferingStartTime ??= DateTime.now();
        
        // Jika buffering lebih dari 1000 milidetik (1 detik penuh) & Lite Mode belum aktif:
        if (!_isLiteModeLocked && DateTime.now().difference(_bufferingStartTime!).inMilliseconds > 1000) {
          _isLiteModeLocked = true;
          debugPrint('⚠️ [MYTUBE QoS] Video macet > 1 detik! Sinyal buruk terdeteksi.');
          
          SharedPreferences.getInstance().then((prefs) {
            final expiry = DateTime.now().add(const Duration(hours: 1)); // Kunci selama 1 Jam
            prefs.setString(_prefLiteModeExpiryKey, expiry.toIso8601String());
            debugPrint('[MYTUBE QoS] Lite Mode (360p murni) dikunci selama 1 jam ke depan.');
          });
        }
      } else {
        // Reset stopwatch jika video lancar kembali
        _bufferingStartTime = null; 
      }

      // Perintah Pemutaran Normal
      if (index == _currentIndex &&
          !_isUserPaused &&
          !_isAdActive && 
          controller.value.isInitialized &&
          !controller.value.isPlaying &&
          !controller.value.isBuffering &&
          controller.value.position < controller.value.duration) {
        controller.play();
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
      await controller.setVolume(_isMuted ? 0.0 : 1.0);
      await controller.play();
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

    _isUserPaused = false;
    _currentCues = [];

    _controllers[_currentIndex]?.pause();
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
      _precacheAdjacentVideos(_currentIndex);
    } else {
      _initControllerAtIndex(_currentIndex).then((_) {
        _safePlay(_controllers[_currentIndex]);
        _recordView(_currentIndex);
        _syncActiveSubtitleForCurrentVideo(_currentIndex);
        _precacheAdjacentVideos(_currentIndex);
      });
    }

    _cleanupDistantControllers(_currentIndex);
    notifyListeners();
  }

  void _precacheAdjacentVideos(int index) {
    final list = filteredVideos;
    if (index + 1 < list.length && !_controllers.containsKey(index + 1)) {
      _initControllerAtIndex(index + 1);
    }
  }

  void _cleanupDistantControllers(int activeIndex) {
    final keysToRemove = <int>[];
    _controllers.forEach((index, controller) {
      if ((index - activeIndex).abs() > 1) {
        controller.dispose();
        keysToRemove.add(index);
      }
    });
    for (final key in keysToRemove) {
      _controllers.remove(key);
    }
  }

  void togglePlayPause() {
    final controller = currentController;
    if (controller != null && controller.value.isInitialized) {
      if (_isAutoplaySoundBlocked) {
        _isAutoplaySoundBlocked = false;
        _isMuted = false;
        controller.setVolume(1.0);
      }
      if (controller.value.isPlaying) {
        _isUserPaused = true;
        controller.pause();
      } else {
        _isUserPaused = false;
        controller.play();
      }
      notifyListeners();
    }
  }

  void pauseCurrentVideoForSearch() {
    if (currentController != null && currentController!.value.isInitialized && currentController!.value.isPlaying) {
      _isUserPaused = true;
      currentController!.pause();
      notifyListeners();
    }
  }

  void unmuteByGesture() {
    _isAutoplaySoundBlocked = false;
    _isMuted = false;
    _isUserPaused = false;
    currentController?.setVolume(1.0);
    notifyListeners();
  }

  void toggleMute() {
    _isMuted = !_isMuted;
    _isAutoplaySoundBlocked = false;
    _controllers.forEach((_, controller) {
      controller.setVolume(_isMuted ? 0.0 : 1.0);
    });
    notifyListeners();
  }
//............................................................................//

//No ke-5....................................................................//
//FILTER, SEARCH, HOME RESET & PERSISTENT WEBVTT SUBTITLE PARSER             //
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

  void clearAllFilters() {
    _searchQuery = '';
    _appliedSearchQuery = '';
    _selectedCategory = null;
    _selectedLanguage = null;
    _resetControllersForFilteredList();
    notifyListeners();
  }

  void resetToHomeDefault() {
    _searchQuery = '';
    _appliedSearchQuery = '';
    _selectedCategory = null;
    _selectedLanguage = null;

    if (_currentVideoType != 'SHORT') {
      switchVideoType('SHORT');
    } else {
      _resetControllersForFilteredList();
      notifyListeners();
    }
  }

  void _resetControllersForFilteredList() {
    _cancelOnDemandSubtitleTimer();
    _currentIndex = 0;
    _currentCues = [];
    
    // [HARD STOP WEB AUDIO]: Wajib dipause paksa agar browser melepas pipeline suara
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
    } catch (e) {
      debugPrint('[MYTUBE PREF] Gagal menyimpan status off subtitle: $e');
    }
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
//............................................................................//
//No ke-6....................................................................//
//USER SOCIAL INTERACTIONS WITH TASTE PROFILE SIGNAL INTEGRATION             //
  Future<void> checkInitialInteractionStatus(String videoId) async {
    if (_currentUserId == null || _currentUserId!.isEmpty) return;

    String? uploaderEmail;
    String? uploaderId;
    String videoType = 'SHORT';
    try {
      final vid = _videos.firstWhere((v) => v.id == videoId);
      uploaderEmail = vid.uploaderEmail;
      uploaderId = vid.uploaderId;
      videoType = vid.videoType;
    } catch (_) {}

    final isLiked = await _service.checkIsVideoLiked(
      videoId: videoId,
      userId: _currentUserId!,
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
      uploaderEmail: currentVideo.uploaderEmail,
      uploaderId: currentVideo.uploaderId,
      videoType: currentVideo.videoType,
      category: currentVideo.category,
      language: currentVideo.language,
      channelName: currentVideo.channelName,
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
      uploaderEmail: currentVideo.uploaderEmail,
      uploaderId: currentVideo.uploaderId,
      videoType: currentVideo.videoType,
      category: currentVideo.category,
      language: currentVideo.language,
      channelName: currentVideo.channelName,
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
      uploaderEmail: currentVideo.uploaderEmail,
      uploaderId: currentVideo.uploaderId,
      videoType: currentVideo.videoType,
      userId: _currentUserId,
      category: currentVideo.category,
      language: currentVideo.language,
      channelName: currentVideo.channelName,
    );
  }

  void _recordView(int index) {
    final list = filteredVideos;
    if (index >= 0 && index < list.length) {
      final video = list[index];
      _service.incrementViewCount(
        video.id,
        uploaderEmail: video.uploaderEmail,
        uploaderId: video.uploaderId,
        videoType: video.videoType,
        userId: _currentUserId,
        category: video.category,
        language: video.language,
        channelName: video.channelName,
      );
    }
  }
//............................................................................//

//No ke-7....................................................................//
//DISPOSAL & RESOURCE CLEANUP                                                //
  @override
  void dispose() {
    _cancelOnDemandSubtitleTimer();
    _feedSubscription?.cancel();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    super.dispose();
  }
} // <--- PENUTUP RESMI KELAS MytubeFeedViewModel

// MODEL DATA SUBTITLE CUE INDEPENDEN (DI LUAR CLASS)
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