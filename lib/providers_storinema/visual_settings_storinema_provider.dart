//PROVIDERS_STORINEMA//
//VISUAL_SETTINGS_STORINEMA_PROVIDER.DART//
//PENGATURAN VISUAL DAN STATE PROVIDER UNTUK STORINEMA (PURE VIDEO)//

//................................................................//
// NAMA FILE: VISUAL_SETTINGS_STORINEMA_PROVIDER.DART             //
// PATH: LIB/PROVIDERS_STORINEMA/VISUAL_SETTINGS_STORINEMA_PROVIDER.DART //
//................................................................//

//No ke-1.........................................................//
// IMPORTS & DEPENDENCIES                                         //
import 'dart:async';
import 'dart:math'; 
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 

import '../view_model_storinema/timeline_storinema_view_model.dart'; 
import '../services_storinema/firestore_storinema_service.dart'; 
import '../models_storinema/video_project_storinema.dart'; 
import 'firestore_storinema_provider.dart'; 

// [TAMBAHAN]: Alamat baru untuk projectStorinemaStreamProvider
import 'timeline_storinema_providers.dart'; 

// =======================================================================
// === FIREBASE SERVICE & LANGUAGE PROVIDER (STORINEMA) ===
// =======================================================================

final appLanguageStorinemaProvider = StateProvider<Locale>((ref) => const Locale('id', 'ID'));
//................................................................//
//................................................................//
//No ke-2.........................................................//
// ENUM & HELPER KONVERSI                                         //
enum TextEffect { fadeInOut, slideUp, zoomIn, drop }

String textEffectToString(TextEffect effect) {
  switch (effect) {
    case TextEffect.fadeInOut: return 'Fade In/Out';
    case TextEffect.slideUp: return 'Slide Up';
    case TextEffect.zoomIn: return 'Zoom In';
    case TextEffect.drop: return 'Drop';
  }
}

TextEffect _textEffectFromString(String? value) {
  value = value?.replaceAll(RegExp(r'[ /]'), '').toLowerCase();
  for (var effect in TextEffect.values) {
    if (effect.name.toLowerCase() == value ||
        textEffectToString(effect).replaceAll(RegExp(r'[ /]'), '').toLowerCase() == value) {
      return effect;
    }
  }
  return TextEffect.fadeInOut; 
}

double _baseSizeFromLegacyNumeric(double? fontSize) {
  if (fontSize == null) return 43.0; 
  if (fontSize > 25.0 || (fontSize > 19.0 && fontSize < 19.5)) return 32.0; 
  if (fontSize > 17.0 || (fontSize > 14.0 && fontSize < 14.5)) return 24.0; 
  return 16.0; 
}

double _baseSizeFromLegacyEnum(String? value) {
  value = value?.toLowerCase();
  if (value == 'large') return 32.0; 
  if (value == 'small') return 16.0; 
  return 43.0; 
}
//................................................................//

//No ke-3.........................................................//
// CLASS TEXT OVERLAY & VISUAL SETTINGS                           //
@immutable
class TextOverlayStorinemaSettings {
  final String text;
  final TextEffect effect;
  final double baseFontSize;
  final Color color;
  final double startTime;
  final double duration;
  final double textBlockWidthFactor; 
  final int maxLines;
  final double verticalAlignment; 

  const TextOverlayStorinemaSettings({
    required this.text,
    required this.effect,
    required this.baseFontSize,
    required this.color,
    required this.startTime,
    required this.duration,
    required this.textBlockWidthFactor,
    required this.maxLines,
    required this.verticalAlignment,
  });

  TextOverlayStorinemaSettings copyWith({
    String? text,
    TextEffect? effect,
    double? baseFontSize,
    Color? color,
    double? startTime,
    double? duration,
    double? textBlockWidthFactor,
    int? maxLines,
    double? verticalAlignment,
  }) {
    return TextOverlayStorinemaSettings(
      text: text ?? this.text,
      effect: effect ?? this.effect,
      baseFontSize: baseFontSize ?? this.baseFontSize,
      color: color ?? this.color,
      startTime: startTime ?? this.startTime,
      duration: duration ?? this.duration,
      textBlockWidthFactor: textBlockWidthFactor ?? this.textBlockWidthFactor,
      maxLines: maxLines ?? this.maxLines,
      verticalAlignment: verticalAlignment ?? this.verticalAlignment,
    );
  }

  Map<String, dynamic> toJson(double aspectRatioValue) {
    String colorToHex(Color c) {
      return '#${c.value.toRadixString(16).padLeft(8, '0').substring(2)}';
    }

    double multiplier = 1.0;
    final double responsiveFontSize = baseFontSize * multiplier;

    final double baseVideoDimension = aspectRatioValue > 1.6 ? 1920 : 1080;
    final double boxWidthPixels = baseVideoDimension * textBlockWidthFactor;

    return {
      'text': text,
      'effect': textEffectToString(effect),
      'baseFontSize': baseFontSize,
      'fontSize': responsiveFontSize, 
      'colorHex': colorToHex(color),
      'startTime': startTime,
      'duration': duration,
      'boxWidth': boxWidthPixels.round(), 
      'textBlockWidthFactor': textBlockWidthFactor,
      'maxLines': maxLines,
      'verticalAlignment': verticalAlignment,
    };
  }

  factory TextOverlayStorinemaSettings.fromJson(Map<String, dynamic>? json) {
    Color hexToColor(String? hexCode) {
      if (hexCode == null || !hexCode.startsWith('#')) return Colors.white;
      String hex = hexCode.substring(1);
      if (hex.length == 6) hex = 'FF$hex'; 
      try {
        if (hex.length == 8) {
          return Color(int.parse('0x$hex'));
        }
      } catch (e) {
        debugPrint("Error parsing colorHex: $hexCode. Error: $e");
      }
      return Colors.white;
    }

    if (json == null) {
      return const TextOverlayStorinemaSettings(
        text: "",
        effect: TextEffect.fadeInOut,
        baseFontSize: 43.0, 
        color: Colors.white,
        startTime: 0.0,
        duration: 5.0,
        textBlockWidthFactor: 0.9,
        maxLines: 3,
        verticalAlignment: -0.8,
      );
    }

    final double loadedBaseFontSize;
    if (json.containsKey('baseFontSize')) {
      loadedBaseFontSize = (json['baseFontSize'] as num?)?.toDouble() ?? 43.0; 
    } else if (json.containsKey('fontSize')) {
      loadedBaseFontSize = _baseSizeFromLegacyNumeric((json['fontSize'] as num?)?.toDouble());
    } else if (json.containsKey('size')) {
      loadedBaseFontSize = _baseSizeFromLegacyEnum(json['size'] as String?);
    } else {
      loadedBaseFontSize = 43.0; 
    }

    final double loadedWidthFactor = (json['textBlockWidthFactor'] as num?)?.toDouble() ?? 0.9;
    final int loadedMaxLines = (json['maxLines'] as int?) ?? 3;
    final double loadedVAlign = (json['verticalAlignment'] as num?)?.toDouble() ?? -0.8;

    return TextOverlayStorinemaSettings(
      text: json['text'] as String? ?? "", 
      effect: _textEffectFromString(json['effect'] as String?),
      baseFontSize: loadedBaseFontSize,
      color: hexToColor(json['colorHex'] as String?),
      startTime: (json['startTime'] as num?)?.toDouble() ?? 0.0,
      duration: (json['duration'] as num?)?.toDouble() ?? 5.0,
      textBlockWidthFactor: loadedWidthFactor,
      maxLines: loadedMaxLines,
      verticalAlignment: loadedVAlign,
    );
  }
}

@immutable
class VisualSettingsStorinema {
  final TextOverlayStorinemaSettings titleSettings;
  final TextOverlayStorinemaSettings descriptionSettings;

  // Pengaturan Subtitle
  final bool showSubtitles;
  final double subtitleBaseFontSize;
  final double subtitleBlockWidthFactor;
  final int subtitleChunkCount;
  final double subtitleDurationMultiplier;
  final int subtitleMaxLines;
  final double subtitleVerticalAlignment; 

  // Lainnya (Motion dihapus)
  final String transitionType;
  final double transitionDuration;
  final String introMusicUrl; 

  const VisualSettingsStorinema({
    required this.titleSettings,
    required this.descriptionSettings,
    required this.showSubtitles,
    required this.subtitleBaseFontSize,
    required this.subtitleBlockWidthFactor,
    required this.subtitleChunkCount,
    required this.subtitleDurationMultiplier,
    required this.subtitleMaxLines,
    required this.subtitleVerticalAlignment,
    required this.transitionType,
    required this.transitionDuration,
    required this.introMusicUrl, 
  });

  VisualSettingsStorinema copyWith({
    TextOverlayStorinemaSettings? titleSettings,
    TextOverlayStorinemaSettings? descriptionSettings,
    bool? showSubtitles,
    double? subtitleBaseFontSize,
    double? subtitleBlockWidthFactor,
    int? subtitleChunkCount,
    double? subtitleDurationMultiplier,
    int? subtitleMaxLines,
    double? subtitleVerticalAlignment,
    String? transitionType,
    double? transitionDuration,
    String? introMusicUrl, 
  }) {
    return VisualSettingsStorinema(
      titleSettings: titleSettings ?? this.titleSettings,
      descriptionSettings: descriptionSettings ?? this.descriptionSettings,
      showSubtitles: showSubtitles ?? this.showSubtitles,
      subtitleBaseFontSize: subtitleBaseFontSize ?? this.subtitleBaseFontSize,
      subtitleBlockWidthFactor: subtitleBlockWidthFactor ?? this.subtitleBlockWidthFactor,
      subtitleChunkCount: subtitleChunkCount ?? this.subtitleChunkCount,
      subtitleDurationMultiplier: subtitleDurationMultiplier ?? this.subtitleDurationMultiplier,
      subtitleMaxLines: subtitleMaxLines ?? this.subtitleMaxLines,
      subtitleVerticalAlignment: subtitleVerticalAlignment ?? this.subtitleVerticalAlignment,
      transitionType: transitionType ?? this.transitionType,
      transitionDuration: transitionDuration ?? this.transitionDuration,
      introMusicUrl: introMusicUrl ?? this.introMusicUrl, 
    );
  }

  static VisualSettingsStorinema defaultSettingsWithTitle(String projectTitle) {
    final trackNumber = Random().nextInt(20) + 1; 
    final defaultIntroMusicUrl =
        'https://firebasestorage.googleapis.com/v0/b/majiku-5b07e.firebasestorage.app/o/assets%2Fmusic%2Fintro_music%20$trackNumber.mp3?alt=media';

    return VisualSettingsStorinema(
      titleSettings: TextOverlayStorinemaSettings(
        text: projectTitle, 
        effect: TextEffect.fadeInOut,
        baseFontSize: 55.0, 
        color: Colors.white,
        startTime: 3.0,
        duration: 7.0,
        textBlockWidthFactor: 0.9,
        maxLines: 3,
        verticalAlignment: -0.8, 
      ),
      descriptionSettings: TextOverlayStorinemaSettings(
        text: "",
        effect: TextEffect.fadeInOut,
        baseFontSize: 40.0, 
        color: Colors.white,
        startTime: 11.0,
        duration: 5.0,
        textBlockWidthFactor: 0.9,
        maxLines: 3,
        verticalAlignment: -0.7, 
      ),
      showSubtitles: false,
      subtitleBaseFontSize: 50.0, 
      subtitleBlockWidthFactor: 0.9,
      subtitleChunkCount: 5,
      subtitleDurationMultiplier: 0.8,
      subtitleMaxLines: 4,
      subtitleVerticalAlignment: 0.8, 
      transitionType: 'fade',
      transitionDuration: 1.0,
      introMusicUrl: defaultIntroMusicUrl, 
    );
  }

  Map<String, dynamic> toJson(double aspectRatioValue) {
    double subBaseFontSize = this.subtitleBaseFontSize;
    double subMultiplier = 1.0;
    final double subResponsiveFontSize = subBaseFontSize * subMultiplier;

    final double baseVideoDimension = aspectRatioValue > 1.6 ? 1920 : 1080;
    final double subBoxWidthPixels = baseVideoDimension * this.subtitleBlockWidthFactor;

    return {
      'titleOverlay': titleSettings.toJson(aspectRatioValue),
      'descriptionOverlay': descriptionSettings.toJson(aspectRatioValue),
      'subtitles': {
        'show': showSubtitles,
        'durationMultiplier': subtitleDurationMultiplier,
        'baseFontSize': subBaseFontSize,
        'fontSize': subResponsiveFontSize, 
        'textBlockWidthFactor': subtitleBlockWidthFactor,
        'boxWidth': subBoxWidthPixels.round(),
        'subtitleChunkCount': subtitleChunkCount,
        'subtitleMaxLines': subtitleMaxLines,
        'subtitleVerticalAlignment': subtitleVerticalAlignment,
      },
      'transition': {'type': transitionType, 'duration': transitionDuration},
      'introMusicUrl': introMusicUrl, 
    };
  }

  factory VisualSettingsStorinema.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return VisualSettingsStorinema.defaultSettingsWithTitle("");
    }

    final subtitleMap = json['subtitles'] as Map<String, dynamic>?;

    final double loadedSubtitleBaseFontSize;
    if (subtitleMap != null && subtitleMap.containsKey('baseFontSize')) {
      loadedSubtitleBaseFontSize = (subtitleMap['baseFontSize'] as num?)?.toDouble() ?? 35.0; 
    } else if (subtitleMap != null && subtitleMap.containsKey('fontSize')) {
      loadedSubtitleBaseFontSize = _baseSizeFromLegacyNumeric((subtitleMap['fontSize'] as num?)?.toDouble());
    } else if (subtitleMap != null && subtitleMap.containsKey('size')) {
      loadedSubtitleBaseFontSize = _baseSizeFromLegacyEnum(subtitleMap['size'] as String?);
    } else {
      loadedSubtitleBaseFontSize = 28.0; 
    }

    final double loadedSubtitleWidthFactor = (subtitleMap?['textBlockWidthFactor'] as num?)?.toDouble() ?? 0.9;
    final int loadedSubtitleChunkCount = (subtitleMap?['subtitleChunkCount'] as int?) ?? 5;
    final int loadedSubtitleMaxLines = (subtitleMap?['subtitleMaxLines'] as int?) ?? 4;
    final double loadedSubtitleVAlign = (subtitleMap?['subtitleVerticalAlignment'] as num?)?.toDouble() ?? 0.8; 

    final String loadedIntroMusicUrl;
    if (json['introMusicUrl'] != null && (json['introMusicUrl'] as String).isNotEmpty) {
      loadedIntroMusicUrl = json['introMusicUrl'] as String;
    } else {
      final trackNumber = Random().nextInt(20) + 1; 
      loadedIntroMusicUrl =
          'https://firebasestorage.googleapis.com/v0/b/majiku-5b07e.firebasestorage.app/o/assets%2Fmusic%2Fintro_music%20$trackNumber.mp3?alt=media';
    }

    return VisualSettingsStorinema(
      titleSettings: TextOverlayStorinemaSettings.fromJson(json['titleOverlay'] as Map<String, dynamic>?),
      descriptionSettings: TextOverlayStorinemaSettings.fromJson(json['descriptionOverlay'] as Map<String, dynamic>?),
      showSubtitles: subtitleMap?['show'] as bool? ?? false,
      subtitleDurationMultiplier: (subtitleMap?['durationMultiplier'] as num?)?.toDouble() ?? 0.8,
      subtitleBaseFontSize: loadedSubtitleBaseFontSize,
      subtitleBlockWidthFactor: loadedSubtitleWidthFactor, 
      subtitleChunkCount: loadedSubtitleChunkCount,
      subtitleMaxLines: loadedSubtitleMaxLines,
      subtitleVerticalAlignment: loadedSubtitleVAlign,
      transitionType: (json['transition'] as Map<String, dynamic>?)?['type'] as String? ?? 'fade',
      transitionDuration: ((json['transition'] as Map<String, dynamic>?)?['duration'] as num?)?.toDouble() ?? 1.0,
      introMusicUrl: loadedIntroMusicUrl, 
    );
  }
}
//................................................................//

//No ke-4.........................................................//
// HELPER ASPEK RASIO & STATE NOTIFIER                            //
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
  return 16 / 9;
}

class VisualSettingsStorinemaNotifier extends StateNotifier<VisualSettingsStorinema> {
  final String projectId;
  final FirestoreStorinemaService _firestoreService;
  final AutoDisposeStateNotifierProviderRef _ref;
  
  StreamSubscription? _projectSubscription;
  bool _isInitialized = false; 

  VisualSettingsStorinemaNotifier(
    VisualSettingsStorinema initialState, 
    this.projectId,
    this._firestoreService,
    this._ref,
  ) : super(initialState) {
    _listenToProjectStream();
  }

  void _listenToProjectStream() {
    _projectSubscription?.cancel();
    _projectSubscription = _ref.watch(projectStorinemaStreamProvider(projectId).stream)
        .listen((projectData) {

      if (!_isInitialized) {
        debugPrint("[$projectId] Notifier received first project data. Initializing state...");
        
        final projectTitle = (projectData as dynamic).title ?? "";
        Map<String, dynamic>? settingsMap;
        final data = projectData as dynamic;

        try {
          if (data != null &&
              data.renderPacket is Map<String, dynamic> &&
              data.renderPacket['styleSettings'] is Map<String, dynamic>) {
            settingsMap = data.renderPacket['styleSettings'] as Map<String, dynamic>;
          } else if (data != null && data.visualSettings is Map<String, dynamic>) {
            settingsMap = data.visualSettings as Map<String, dynamic>;
          }
        } catch (e) {
          debugPrint('[$projectId] Error accessing dynamic properties: $e');
        }

        if (settingsMap != null) {
          try {
            final parsedSettings = VisualSettingsStorinema.fromJson(settingsMap);
            state = parsedSettings;
          } catch (e) {
            state = VisualSettingsStorinema.defaultSettingsWithTitle(projectTitle);
          }
        } else {
          state = VisualSettingsStorinema.defaultSettingsWithTitle(projectTitle);
        }

        _isInitialized = true; 
      }
    },
    onError: (e) {
      if (!_isInitialized) {
        state = VisualSettingsStorinema.defaultSettingsWithTitle(""); 
        _isInitialized = true; 
      }
    });
  }

  @override
  void dispose() {
    _projectSubscription?.cancel(); 
    super.dispose();
  }

  double _clampFontSize(double size) => size.clamp(6.0, 100.0); 
  double _clampWidthFactor(double factor) => factor.clamp(0.1, 1.0);
  int _clampChunkCount(int count) => count.clamp(1, 10);
  int _clampMaxLines(int count) => count.clamp(1, 10);
  double _clampVerticalAlignment(double align) => align.clamp(-1.0, 1.0);

  // --- Metode Update State (Judul) ---
  void updateTitleText(String text) => state = state.copyWith(titleSettings: state.titleSettings.copyWith(text: text));
  void updateTitleEffect(TextEffect effect) => state = state.copyWith(titleSettings: state.titleSettings.copyWith(effect: effect));
  void updateTitleBaseFontSize(double size) => state = state.copyWith(titleSettings: state.titleSettings.copyWith(baseFontSize: _clampFontSize(size)));
  void updateTitleColor(Color color) => state = state.copyWith(titleSettings: state.titleSettings.copyWith(color: color));
  void updateTitleStartTime(double time) => state = state.copyWith(titleSettings: state.titleSettings.copyWith(startTime: time));
  void updateTitleDuration(double duration) => state = state.copyWith(titleSettings: state.titleSettings.copyWith(duration: duration));
  void updateTitleBlockWidthFactor(double factor) => state = state.copyWith(titleSettings: state.titleSettings.copyWith(textBlockWidthFactor: _clampWidthFactor(factor)));
  void updateTitleMaxLines(int lines) => state = state.copyWith(titleSettings: state.titleSettings.copyWith(maxLines: _clampMaxLines(lines)));
  void updateTitleVerticalAlignment(double align) => state = state.copyWith(titleSettings: state.titleSettings.copyWith(verticalAlignment: _clampVerticalAlignment(align)));

  // --- Metode Update State (Deskripsi) ---
  void updateDescriptionText(String text) => state = state.copyWith(descriptionSettings: state.descriptionSettings.copyWith(text: text));
  void updateDescriptionEffect(TextEffect effect) => state = state.copyWith(descriptionSettings: state.descriptionSettings.copyWith(effect: effect));
  void updateDescriptionBaseFontSize(double size) => state = state.copyWith(descriptionSettings: state.descriptionSettings.copyWith(baseFontSize: _clampFontSize(size)));
  void updateDescriptionColor(Color color) => state = state.copyWith(descriptionSettings: state.descriptionSettings.copyWith(color: color));
  void updateDescriptionStartTime(double time) => state = state.copyWith(descriptionSettings: state.descriptionSettings.copyWith(startTime: time));
  void updateDescriptionDuration(double duration) => state = state.copyWith(descriptionSettings: state.descriptionSettings.copyWith(duration: duration));
  void updateDescriptionBlockWidthFactor(double factor) => state = state.copyWith(descriptionSettings: state.descriptionSettings.copyWith(textBlockWidthFactor: _clampWidthFactor(factor)));
  void updateDescriptionMaxLines(int lines) => state = state.copyWith(descriptionSettings: state.descriptionSettings.copyWith(maxLines: _clampMaxLines(lines)));
  void updateDescriptionVerticalAlignment(double align) => state = state.copyWith(descriptionSettings: state.descriptionSettings.copyWith(verticalAlignment: _clampVerticalAlignment(align)));

  // --- Metode Update State (Subtitle & Lainnya) ---
  void updateShowSubtitles(bool show) => state = state.copyWith(showSubtitles: show);
  void updateSubtitleDurationMultiplier(double multiplier) => state = state.copyWith(subtitleDurationMultiplier: multiplier);
  void updateSubtitleBaseFontSize(double size) => state = state.copyWith(subtitleBaseFontSize: _clampFontSize(size));
  void updateSubtitleBlockWidthFactor(double factor) => state = state.copyWith(subtitleBlockWidthFactor: _clampWidthFactor(factor));
  void updateSubtitleChunkCount(int count) => state = state.copyWith(subtitleChunkCount: _clampChunkCount(count));
  void updateSubtitleMaxLines(int lines) => state = state.copyWith(subtitleMaxLines: _clampMaxLines(lines));
  void updateSubtitleVerticalAlignment(double align) => state = state.copyWith(subtitleVerticalAlignment: _clampVerticalAlignment(align));

  void updateTransitionType(String type) => state = state.copyWith(transitionType: type);
  void updateTransitionDuration(double duration) => state = state.copyWith(transitionDuration: duration);
  void updateIntroMusicUrl(String url) => state = state.copyWith(introMusicUrl: url);

  // --- Fungsi Save ke Firestore ---
  Future<void> saveSettingsToFirestore() async {
    try {
      final docSnapshot = await _firestoreService.getProject(projectId);
      final data = docSnapshot.data();

      Map<String, dynamic> currentRenderPacket = {};

      if (data != null &&
          data.containsKey('renderPacket') &&
          data['renderPacket'] is Map<String, dynamic>) {
        currentRenderPacket = Map<String, dynamic>.from(data['renderPacket']);
      } 

      final projectData = _ref.read(projectStorinemaStreamProvider(projectId)).asData?.value;
      final ratioString = (projectData as dynamic)?.aspectRatio; 
      final double aspectRatioValue = _calculateAspectRatio(ratioString);
      final newStyleSettingsMap = state.toJson(aspectRatioValue);

      currentRenderPacket['styleSettings'] = newStyleSettingsMap;

      await _firestoreService.updateProject(
        projectId,
        {'renderPacket': currentRenderPacket}, 
      );

      _ref.invalidate(projectStorinemaStreamProvider(projectId));

    } catch (e) {
      debugPrint('❌ Error saving visual settings for project $projectId: $e');
      throw Exception('Failed to save settings: $e');
    }
  }

  // --- Fungsi Load dari Firestore ---
  Future<void> loadSettingsFromFirestore() async {
    try {
      final docSnapshot = await _firestoreService.getProject(projectId);
      final data = docSnapshot.data();

      Map<String, dynamic>? settingsMap;
      final currentTitle = data?['title'] as String? ?? "";

      if (data != null &&
          data.containsKey('renderPacket') &&
          data['renderPacket'] is Map &&
          (data['renderPacket'] as Map).containsKey('styleSettings') &&
          data['renderPacket']['styleSettings'] is Map) {
        settingsMap = data['renderPacket']['styleSettings'] as Map<String, dynamic>;
      } else if (data != null &&
          data.containsKey('visualSettings') &&
          data['visualSettings'] is Map) {
        settingsMap = data['visualSettings'] as Map<String, dynamic>;
      }

      if (settingsMap != null) {
        final loadedSettings = VisualSettingsStorinema.fromJson(settingsMap);
        state = loadedSettings;
      } else {
        state = VisualSettingsStorinema.defaultSettingsWithTitle(currentTitle);
      }
    } catch (e) {
      debugPrint('❌ Error loading visual settings for project $projectId: $e');
    }
  }

  void resetToDefaults() {
    final projectData = _ref.read(projectStorinemaStreamProvider(projectId)).asData?.value;
    final String currentTitle = (projectData as dynamic)?.title ?? "";
    state = VisualSettingsStorinema.defaultSettingsWithTitle(currentTitle);
  }
}
//................................................................//

//No ke-5.........................................................//
// FAMILY PROVIDER EXPORT                                         //
final visualSettingsStorinemaProvider =
    StateNotifierProvider.autoDispose.family<VisualSettingsStorinemaNotifier, VisualSettingsStorinema, String>(
  (ref, projectId) {
    final firestoreService = ref.watch(firestoreStorinemaServiceProvider);

    return VisualSettingsStorinemaNotifier(
      VisualSettingsStorinema.defaultSettingsWithTitle(""), 
      projectId,
      firestoreService,
      ref
    );
  },
);
//................................................................//