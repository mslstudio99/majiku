//================================================================//
// NAMA FILE: VIDEO_PROJECT_MARKETTING_VIDEO.DART                  //
// DIREKTORI: LIB/MODELS_MARKETTING_VIDEO/                         //
// DESKRIPSI: KELAS MODEL VIDEO PROJECT MARKETTING_VIDEO           //
//================================================================//

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';

class VideoProjectMarkettingVideo {
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
  final String? voice; 
  final String? costLevel;
  final String? description;
  final String? productImageUrl; // [INJEKSI FITUR BARU]: URL Gambar Produk
  final List<Map<String, dynamic>> identifiedCharacters;
  final String? status;
  final Timestamp createdAt;
  final Timestamp updatedAt;
  final String? errorDetail;
  final String? finalVideoUrl;
  final Map<String, dynamic>? visualSettings;
  final Timestamp? renderStartedAt;

  VideoProjectMarkettingVideo({
    required this.id,
    required this.userId,
    required this.title,
    required this.rawScript,
    required this.imageStyle,
    required this.aspectRatio,
    required this.language,
    this.resolution,
    this.voice,     
    this.costLevel, 
    this.description,
    this.productImageUrl, // [INJEKSI FITUR BARU]
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
  factory VideoProjectMarkettingVideo.fromFirestore(DocumentSnapshot doc) {
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

    return VideoProjectMarkettingVideo(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      title: data['title'] as String? ?? 'Untitled Marketting Video Project',
      rawScript: data['rawScript'] as String? ?? '',
      imageStyle: data['imageStyle'] as String? ?? 'marketting_video_default', 
      aspectRatio: data['aspectRatio'] as String? ?? '16:9',
      language: data['language'] as String? ?? 'Indonesian',
      resolution: data['resolution'] as String?, 
      voice: data['voice'] as String?,
      costLevel: data['costLevel'] as String?,
      description: data['description'] as String?,
      productImageUrl: data['productImageUrl'] as String?, // [INJEKSI FITUR BARU]
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
      if (voice != null) 'voice': voice,
      if (costLevel != null) 'costLevel': costLevel,
      if (description != null) 'description': description,
      if (productImageUrl != null) 'productImageUrl': productImageUrl, // [INJEKSI FITUR BARU]
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
  VideoProjectMarkettingVideo copyWith({
    String? id,
    String? userId,
    String? title,
    String? rawScript,
    String? imageStyle,
    String? aspectRatio,
    String? language,
    String? resolution,
    String? voice,
    String? costLevel,
    String? description,
    String? productImageUrl, // [INJEKSI FITUR BARU]
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
    return VideoProjectMarkettingVideo(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      rawScript: rawScript ?? this.rawScript,
      imageStyle: imageStyle ?? this.imageStyle,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      language: language ?? this.language,
      resolution: resolution ?? this.resolution,
      voice: voice ?? this.voice,             
      costLevel: costLevel ?? this.costLevel, 
      description: description ?? this.description, 
      productImageUrl: productImageUrl ?? this.productImageUrl, // [INJEKSI FITUR BARU]
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

    return other is VideoProjectMarkettingVideo &&
        other.id == id &&
        other.userId == userId &&
        other.title == title &&
        other.rawScript == rawScript &&
        other.imageStyle == imageStyle &&
        other.aspectRatio == aspectRatio &&
        other.language == language &&
        other.resolution == resolution &&
        other.voice == voice &&         
        other.costLevel == costLevel && 
        other.description == description &&
        other.productImageUrl == productImageUrl && // [INJEKSI FITUR BARU]
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
        (voice?.hashCode ?? 0) ^         
        (costLevel?.hashCode ?? 0) ^     
        (description?.hashCode ?? 0) ^   
        (productImageUrl?.hashCode ?? 0) ^ // [INJEKSI FITUR BARU]
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