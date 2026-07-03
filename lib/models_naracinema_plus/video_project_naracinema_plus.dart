//================================================================//
// NAMA FILE: VIDEO_PROJECT_NARACINEMA_PLUS.DART                  //
// DIREKTORI: LIB/MODELS_NARACINEMA_PLUS/                         //
// DESKRIPSI: KELAS MODEL VIDEO PROJECT NARACINEMA PLUS           //
//================================================================//

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';

class VideoProjectNaracinemaPlus {
// No ke-1: PROPERTI DAN KONSTRUKTOR                              //
//----------------------------------------------------------------//
  final String id;
  final String userId;
  final String title;
  final String rawScript;
  final String imageStyle;
  final String aspectRatio;
  final String language;
  final String? resolution; 
  final String? voice;     // [PERBAIKAN]: Menambah properti voice
  final String? costLevel; // [PERBAIKAN]: Menambah properti costLevel
  final String? description; // [SUNTIKAN BARU] Menampung data deskripsi overlay dari root dokumen
  final List<Map<String, dynamic>> identifiedCharacters;
  final String? status;
  final Timestamp createdAt;
  final Timestamp updatedAt;
  final String? errorDetail;
  final String? finalVideoUrl;
  final Map<String, dynamic>? visualSettings;
  final Timestamp? renderStartedAt;

  VideoProjectNaracinemaPlus({
    required this.id,
    required this.userId,
    required this.title,
    required this.rawScript,
    required this.imageStyle,
    required this.aspectRatio,
    required this.language,
    this.resolution,
    this.voice,     // [PERBAIKAN]
    this.costLevel, // [PERBAIKAN]
    this.description, // [SUNTIKAN BARU]
    required this.identifiedCharacters,
    this.status,
    required this.createdAt,
    required this.updatedAt,
    this.errorDetail,
    this.finalVideoUrl,
    this.visualSettings,
    this.renderStartedAt,
  });
//----------------------------------------------------------------//

// No ke-2: SERIALISASI FIRESTORE                                 //
//----------------------------------------------------------------//
  factory VideoProjectNaracinemaPlus.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    Timestamp _getTimestamp(dynamic value) {
      if (value is Timestamp) return value;
      if (value is Map && value.containsKey('_seconds')) {
        try {
          return Timestamp(value['_seconds'], value['_nanoseconds'] ?? 0);
        } catch (_) {}
      }
      return Timestamp.now();
    }

    Timestamp? _getNullableTimestamp(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value;
      if (value is Map && value.containsKey('_seconds')) {
        try {
          return Timestamp(value['_seconds'], value['_nanoseconds'] ?? 0);
        } catch (_) {}
      }
      return null;
    }

    return VideoProjectNaracinemaPlus(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      title: data['title'] as String? ?? 'Untitled Naracinema Plus Project',
      rawScript: data['rawScript'] as String? ?? '',
      imageStyle: data['imageStyle'] as String? ?? 'naracinema_plus_default', 
      aspectRatio: data['aspectRatio'] as String? ?? '16:9',
      language: data['language'] as String? ?? 'Indonesian',
      resolution: data['resolution'] as String?, 
      voice: data['voice'] as String?,         // [PERBAIKAN]
      costLevel: data['costLevel'] as String?, // [PERBAIKAN]
      description: data['description'] as String?, // [SUNTIKAN BARU] Membaca data deskripsi overlay dari Firestore
      identifiedCharacters: (data['identifiedCharacters'] is List)
          ? List<Map<String, dynamic>>.from(
              (data['identifiedCharacters'] as List).map((item) =>
                  item is Map ? Map<String, dynamic>.from(item) : {}))
          : [],
      status: data['status'] as String?,
      createdAt: _getTimestamp(data['createdAt']),
      updatedAt: _getTimestamp(data['updatedAt']),
      errorDetail: data['errorDetail'] as String?,
      finalVideoUrl: data['finalVideoUrl'] as String?,
      visualSettings: data['visualSettings'] is Map
          ? Map<String, dynamic>.from(data['visualSettings'])
          : null,
      renderStartedAt: _getNullableTimestamp(data['renderStartedAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'title': title,
      'rawScript': rawScript,
      'imageStyle': imageStyle,
      'aspectRatio': aspectRatio,
      'language': language,
      if (resolution != null) 'resolution': resolution,
      if (voice != null) 'voice': voice,         // [PERBAIKAN]
      if (costLevel != null) 'costLevel': costLevel, // [PERBAIKAN]
      if (description != null) 'description': description, // [SUNTIKAN BARU] Menyimpan deskripsi overlay ke root db
      'identifiedCharacters': identifiedCharacters,
      if (status != null) 'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
      if (errorDetail != null) 'errorDetail': errorDetail,
      if (finalVideoUrl != null) 'finalVideoUrl': finalVideoUrl,
      if (visualSettings != null) 'visualSettings': visualSettings,
      if (renderStartedAt != null) 'renderStartedAt': renderStartedAt,
    };
  }
//----------------------------------------------------------------//

// No ke-3: COPYWITH DAN EQUALITY                                 //
//----------------------------------------------------------------//
  VideoProjectNaracinemaPlus copyWith({
    String? id,
    String? userId,
    String? title,
    String? rawScript,
    String? imageStyle,
    String? aspectRatio,
    String? language,
    String? resolution,
    String? voice,     // [PERBAIKAN]
    String? costLevel, // [PERBAIKAN]
    String? description, // [SUNTIKAN BARU]
    List<Map<String, dynamic>>? identifiedCharacters,
    String? status,
    Timestamp? createdAt,
    Timestamp? updatedAt,
    String? errorDetail,
    String? finalVideoUrl,
    Map<String, dynamic>? visualSettings,
    bool clearVisualSettings = false,
    Timestamp? renderStartedAt,
    bool clearRenderStartedAt = false,
  }) {
    return VideoProjectNaracinemaPlus(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      rawScript: rawScript ?? this.rawScript,
      imageStyle: imageStyle ?? this.imageStyle,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      language: language ?? this.language,
      resolution: resolution ?? this.resolution,
      voice: voice ?? this.voice,             // [PERBAIKAN]
      costLevel: costLevel ?? this.costLevel, // [PERBAIKAN]
      description: description ?? this.description, // [SUNTIKAN BARU]
      identifiedCharacters: identifiedCharacters ?? this.identifiedCharacters,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      errorDetail: errorDetail ?? this.errorDetail,
      finalVideoUrl: finalVideoUrl ?? this.finalVideoUrl,
      visualSettings: clearVisualSettings ? null : (visualSettings ?? this.visualSettings),
      renderStartedAt: clearRenderStartedAt ? null : (renderStartedAt ?? this.renderStartedAt),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    final listEquals = const DeepCollectionEquality().equals;
    final mapEquals = const DeepCollectionEquality().equals;

    return other is VideoProjectNaracinemaPlus &&
        other.id == id &&
        other.userId == userId &&
        other.title == title &&
        other.rawScript == rawScript &&
        other.imageStyle == imageStyle &&
        other.aspectRatio == aspectRatio &&
        other.language == language &&
        other.resolution == resolution &&
        other.voice == voice &&         // [PERBAIKAN]
        other.costLevel == costLevel && // [PERBAIKAN]
        other.description == description && // [SUNTIKAN BARU]
        listEquals(other.identifiedCharacters, identifiedCharacters) &&
        other.status == status &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.errorDetail == errorDetail &&
        other.finalVideoUrl == finalVideoUrl &&
        mapEquals(other.visualSettings, visualSettings) &&
        other.renderStartedAt == renderStartedAt;
  }

  @override
  int get hashCode {
    final listHash = const DeepCollectionEquality().hash;
    final mapHash = const DeepCollectionEquality().hash;

    return id.hashCode ^
        userId.hashCode ^
        title.hashCode ^
        rawScript.hashCode ^
        imageStyle.hashCode ^
        aspectRatio.hashCode ^
        language.hashCode ^
        (resolution?.hashCode ?? 0) ^
        (voice?.hashCode ?? 0) ^         // [PERBAIKAN]
        (costLevel?.hashCode ?? 0) ^     // [PERBAIKAN]
        (description?.hashCode ?? 0) ^   // [SUNTIKAN BARU]
        listHash(identifiedCharacters).hashCode ^
        status.hashCode ^
        createdAt.hashCode ^
        updatedAt.hashCode ^
        errorDetail.hashCode ^
        finalVideoUrl.hashCode ^
        mapHash(visualSettings).hashCode ^
        renderStartedAt.hashCode;
  }
//----------------------------------------------------------------//
}