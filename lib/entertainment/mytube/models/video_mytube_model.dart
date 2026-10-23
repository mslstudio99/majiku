//============================================================================//
// DIREKTORI: lib/entertainment/mytube/models/                                //
// FILE: VIDEO_MYTUBE_MODEL.DART                                              //
// MODEL DATA VIDEO MYTUBE (DUKUNGAN CHANNEL ID, EMAIL, CATEGORY, LANGUAGE)   //
//============================================================================//

//No ke-1....................................................................//
//IMPORTS & DEPENDENCIES                                                     //
import 'package:cloud_firestore/cloud_firestore.dart';
//............................................................................//

//No ke-2....................................................................//
//MODEL PROPERTIES & CONSTRUCTOR                                             //
class VideoMytubeModel {
  final String id; // Document ID (titleSlug-uniqueSuffix)
  final String channelId; // [JANGKAR UTAMA]: ID Channel Resmi (Auto-ID Firestore)
  final String title;
  final String description;
  final String videoUrl;
  final String? hlsUrl;
  final String thumbnailUrl;
  final int durationSeconds;
  final bool isLandscape;
  final String uploaderId; // UID Firebase Auth
  final String uploaderEmail; // Email Resmi Creator (Fallback untuk 8 video lama)
  final String channelName;
  final String channelAvatarUrl;
  final bool isVerifiedAdmin;
  final int likesCount;
  final int commentsCount;
  final int savesCount;
  final int sharesCount;
  final int viewsCount;
  final DateTime createdAt;
  final String? actionButtonText;
  final String? actionButtonRoute;

  final String category;
  final String language;
  final String videoType; // 'SHORT' atau 'LONG'
  final Map<String, String>? subtitles; // Peta URL WebVTT {"en": "url...", "id": "url...", "hi": "url..."}

  // [BARU - MLA DUBBING]: Peta URL Audio MP3 Dubbing {"en": "url...", "id": "url...", "ja": "url..."}
  final Map<String, String>? dubbing;

  // [BARU - TOPIC LOCATION]: Target Geografis Konten (Default: ['Global'])
  final List<String> targetLocations;

  // Metadata Transcoding HLS Multi-Bitrate (360p, 480p, 720p)
  final int hlsVersion; // 1 = Format Legacy Tunggal, 2 = Format Multi-Bitrate Baru
  final String hlsStatus; // 'PENDING', 'PROCESSING', 'READY', 'ERROR_TRANSCODING'
  final List<String> availableResolutions; // ['360p', '480p', '720p']

  const VideoMytubeModel({
    required this.id,
    this.channelId = '', // Default kosong: Menjamin 8 video lama tetap terbaca tanpa crash
    required this.title,
    required this.description,
    required this.videoUrl,
    this.hlsUrl,
    required this.thumbnailUrl,
    required this.durationSeconds,
    this.isLandscape = false,
    required this.uploaderId,
    this.uploaderEmail = '',
    required this.channelName,
    required this.channelAvatarUrl,
    this.isVerifiedAdmin = true,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.savesCount = 0,
    this.sharesCount = 0,
    this.viewsCount = 0,
    required this.createdAt,
    this.actionButtonText,
    this.actionButtonRoute,
    this.category = 'Comedy & Funny',
    this.language = 'English (US)',
    this.videoType = 'SHORT',
    this.subtitles,
    this.dubbing,
    this.targetLocations = const ['Global'], // [BARU]: Default selalu mencakup audiens Global
    this.hlsVersion = 1,
    this.hlsStatus = 'READY',
    this.availableResolutions = const [],
  });
//............................................................................//

//No ke-3....................................................................//
//FACTORY DESERIALIZATION (fromFirestore & fromMap)                          //
  factory VideoMytubeModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return VideoMytubeModel.fromMap(data, doc.id);
  }

  factory VideoMytubeModel.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parsedDate;
    if (map['created_at'] is Timestamp) {
      parsedDate = (map['created_at'] as Timestamp).toDate();
    } else if (map['created_at'] is String) {
      parsedDate = DateTime.tryParse(map['created_at']) ?? DateTime.now();
    } else if (map['created_at'] is int) {
      parsedDate = DateTime.fromMillisecondsSinceEpoch(map['created_at']);
    } else {
      parsedDate = DateTime.now();
    }

    final rawType = map['video_type']?.toString().toUpperCase();
    final determinedType = (rawType != null && rawType.isNotEmpty)
        ? rawType
        : (map['is_landscape'] == true ? 'LONG' : 'SHORT');

    // Deserialisasi Peta Subtitle (Aman dari null pointer)
    Map<String, String>? parsedSubtitles;
    if (map['subtitles'] != null && map['subtitles'] is Map) {
      parsedSubtitles = Map<String, String>.from(
        (map['subtitles'] as Map).map(
          (key, value) => MapEntry(key.toString(), value.toString()),
        ),
      );
    }

    // Deserialisasi Peta Audio MP3 Dubbing (Aman dari null pointer)
    Map<String, String>? parsedDubbing;
    if (map['dubbing'] != null && map['dubbing'] is Map) {
      parsedDubbing = Map<String, String>.from(
        (map['dubbing'] as Map).map(
          (key, value) => MapEntry(key.toString(), value.toString()),
        ),
      );
    }

    // [BARU]: Deserialisasi Target Lokasi Konten (Default: ['Global'])
    List<String> parsedLocations = const ['Global'];
    if (map['target_locations'] != null && map['target_locations'] is List) {
      parsedLocations = List<String>.from(
        (map['target_locations'] as List).map((e) => e.toString()),
      );
      if (parsedLocations.isEmpty) parsedLocations = const ['Global'];
    } else if (map['targetLocations'] != null && map['targetLocations'] is List) {
      parsedLocations = List<String>.from(
        (map['targetLocations'] as List).map((e) => e.toString()),
      );
      if (parsedLocations.isEmpty) parsedLocations = const ['Global'];
    }

    // Deserialisasi Resolusi HLS yang Tersedia (Multi-Bitrate 360p, 480p, 720p)
    List<String> parsedResolutions = [];
    if (map['available_resolutions'] != null && map['available_resolutions'] is List) {
      parsedResolutions = List<String>.from(
        (map['available_resolutions'] as List).map((e) => e.toString()),
      );
    }

    return VideoMytubeModel(
      id: docId,
      channelId: map['channel_id']?.toString() ?? map['channelId']?.toString() ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      videoUrl: map['video_url'] ?? '',
      hlsUrl: map['hls_url'],
      thumbnailUrl: map['thumbnail_url'] ?? '',
      durationSeconds: (map['duration_seconds'] as num?)?.toInt() ?? 0,
      isLandscape: map['is_landscape'] ?? false,
      uploaderId: map['uploader_id'] ?? '',
      uploaderEmail: map['uploader_email'] ?? '',
      channelName: map['channel_name'] ?? 'Majiku Official',
      channelAvatarUrl: map['channel_avatar_url'] ?? '',
      isVerifiedAdmin: map['is_verified_admin'] ?? true,
      likesCount: (map['likes_count'] as num?)?.toInt() ?? 0,
      commentsCount: (map['comments_count'] as num?)?.toInt() ?? 0,
      savesCount: (map['saves_count'] as num?)?.toInt() ?? 0,
      sharesCount: (map['shares_count'] as num?)?.toInt() ?? 0,
      viewsCount: (map['views_count'] as num?)?.toInt() ?? 0,
      createdAt: parsedDate,
      actionButtonText: map['action_button_text'],
      actionButtonRoute: map['action_button_route'],
      category: map['category'] as String? ?? 'Comedy & Funny',
      language: map['language'] as String? ?? 'English (US)',
      videoType: determinedType,
      subtitles: parsedSubtitles,
      dubbing: parsedDubbing,
      targetLocations: parsedLocations, // [BARU]
      hlsVersion: (map['hls_version'] as num?)?.toInt() ?? 1,
      hlsStatus: map['hls_status']?.toString() ?? 'READY',
      availableResolutions: parsedResolutions,
    );
  }
//............................................................................//

//No ke-4....................................................................//
//SERIALIZATION (toMap)                                                      //
  Map<String, dynamic> toMap() {
    return {
      'channel_id': channelId,
      'title': title,
      'description': description,
      'video_url': videoUrl,
      'hls_url': hlsUrl,
      'thumbnail_url': thumbnailUrl,
      'duration_seconds': durationSeconds,
      'is_landscape': isLandscape,
      'uploader_id': uploaderId,
      'uploader_email': uploaderEmail,
      'channel_name': channelName,
      'channel_avatar_url': channelAvatarUrl,
      'is_verified_admin': isVerifiedAdmin,
      'likes_count': likesCount,
      'comments_count': commentsCount,
      'saves_count': savesCount,
      'shares_count': sharesCount,
      'views_count': viewsCount,
      'created_at': Timestamp.fromDate(createdAt),
      'action_button_text': actionButtonText,
      'action_button_route': actionButtonRoute,
      'category': category,
      'language': language,
      'video_type': videoType,
      'subtitles': subtitles,
      'dubbing': dubbing,
      'target_locations': targetLocations, // [BARU]: Target Geografis Disimpan ke Firestore
      'hls_version': hlsVersion,
      'hls_status': hlsStatus,
      'available_resolutions': availableResolutions,
    };
  }
//............................................................................//

//No ke-5....................................................................//
//UTILITY METHODS, COPYWITH & LOCATION DATABASE (6 BENUA, 100 NEGARA & GLOBAL)//
  VideoMytubeModel copyWith({
    String? id,
    String? channelId,
    String? title,
    String? description,
    String? videoUrl,
    String? hlsUrl,
    String? thumbnailUrl,
    int? durationSeconds,
    bool? isLandscape,
    String? uploaderId,
    String? uploaderEmail,
    String? channelName,
    String? channelAvatarUrl,
    bool? isVerifiedAdmin,
    int? likesCount,
    int? commentsCount,
    int? savesCount,
    int? sharesCount,
    int? viewsCount,
    DateTime? createdAt,
    String? actionButtonText,
    String? actionButtonRoute,
    String? category,
    String? language,
    String? videoType,
    Map<String, String>? subtitles,
    Map<String, String>? dubbing,
    List<String>? targetLocations, // [BARU]
    int? hlsVersion,
    String? hlsStatus,
    List<String>? availableResolutions,
  }) {
    return VideoMytubeModel(
      id: id ?? this.id,
      channelId: channelId ?? this.channelId,
      title: title ?? this.title,
      description: description ?? this.description,
      videoUrl: videoUrl ?? this.videoUrl,
      hlsUrl: hlsUrl ?? this.hlsUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      isLandscape: isLandscape ?? this.isLandscape,
      uploaderId: uploaderId ?? this.uploaderId,
      uploaderEmail: uploaderEmail ?? this.uploaderEmail,
      channelName: channelName ?? this.channelName,
      channelAvatarUrl: channelAvatarUrl ?? this.channelAvatarUrl,
      isVerifiedAdmin: isVerifiedAdmin ?? this.isVerifiedAdmin,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      savesCount: savesCount ?? this.savesCount,
      sharesCount: sharesCount ?? this.sharesCount,
      viewsCount: viewsCount ?? this.viewsCount,
      createdAt: createdAt ?? this.createdAt,
      actionButtonText: actionButtonText ?? this.actionButtonText,
      actionButtonRoute: actionButtonRoute ?? this.actionButtonRoute,
      category: category ?? this.category,
      language: language ?? this.language,
      videoType: videoType ?? this.videoType,
      subtitles: subtitles ?? this.subtitles,
      dubbing: dubbing ?? this.dubbing,
      targetLocations: targetLocations ?? this.targetLocations, // [BARU]
      hlsVersion: hlsVersion ?? this.hlsVersion,
      hlsStatus: hlsStatus ?? this.hlsStatus,
      availableResolutions: availableResolutions ?? this.availableResolutions,
    );
  }

  String get streamingUrl => (hlsUrl != null && hlsUrl!.isNotEmpty) ? hlsUrl! : videoUrl;

  bool get isDurationValid => durationSeconds > 0 && durationSeconds <= 180;
} // <--- PENUTUP RESMI KELAS VideoMytubeModel

/// [DATABASE LOKASI RESMI MYTUBE]: Memetakan 6 Benua & 100 Negara untuk Target Konten
class MytubeLocationDatabase {
  static const String globalLocation = 'Global';

  // 6 Benua Resmi
  static const List<String> continents = [
    'Asia',
    'Europe',
    'North America',
    'South America',
    'Africa',
    'Australia & Oceania',
  ];

  // Pemetaan 100 Negara Berdasarkan 6 Benua
  static const Map<String, List<String>> continentCountries = {
    'Asia': [
      'Indonesia', 'Malaysia', 'Singapore', 'Philippines', 'Thailand',
      'Vietnam', 'Cambodia', 'Laos', 'India', 'Pakistan',
      'Bangladesh', 'Sri Lanka', 'Nepal', 'Japan', 'South Korea',
      'Taiwan', 'Kazakhstan', 'Azerbaijan', 'Georgia', 'Saudi Arabia',
      'United Arab Emirates', 'Qatar', 'Bahrain', 'Kuwait', 'Oman',
      'Jordan', 'Lebanon', 'Iraq', 'Yemen',
    ],
    'Europe': [
      'United Kingdom', 'Germany', 'France', 'Netherlands', 'Belgium',
      'Switzerland', 'Austria', 'Ireland', 'Luxembourg', 'Liechtenstein',
      'Sweden', 'Norway', 'Denmark', 'Finland', 'Iceland',
      'Italy', 'Spain', 'Portugal', 'Greece', 'Cyprus',
      'Malta', 'Poland', 'Czechia', 'Slovakia', 'Hungary',
      'Romania', 'Bulgaria', 'Croatia', 'Serbia', 'Slovenia',
      'Bosnia and Herzegovina', 'North Macedonia', 'Montenegro', 'Estonia', 'Latvia',
      'Lithuania', 'Ukraine', 'Belarus', 'Turkey',
    ],
    'North America': [
      'United States', 'Canada', 'Mexico', 'Costa Rica', 'Guatemala',
      'Honduras', 'Nicaragua', 'Panama', 'El Salvador', 'Dominican Republic',
      'Jamaica',
    ],
    'South America': [
      'Brazil', 'Argentina', 'Colombia', 'Chile', 'Peru',
      'Ecuador', 'Bolivia', 'Paraguay', 'Uruguay', 'Venezuela',
    ],
    'Africa': [
      'Egypt', 'Morocco', 'Algeria', 'Tunisia', 'Libya',
      'South Africa', 'Nigeria', 'Kenya',
    ],
    'Australia & Oceania': [
      'Australia', 'New Zealand', 'Papua New Guinea',
    ],
  };

  /// Mengambil daftar seluruh 100 negara secara terurut A-Z
  static List<String> get allCountries {
    final list = <String>[];
    for (final countries in continentCountries.values) {
      list.addAll(countries);
    }
    list.sort((a, b) => a.compareTo(b));
    return list;
  }
}
//............................................................................//