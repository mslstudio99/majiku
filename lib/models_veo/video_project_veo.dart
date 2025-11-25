// --- KATEGORI_ISOLASI_VEO: Path file: models_veo/video_project_veo.dart ---

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart'; // Import for DeepCollectionEquality

// --- KATEGORI_ISOLASI_VEO: Nama Class diubah ---
class VideoProjectVeo {
// --- AKHIR MODIFIKASI ---
  final String id;
  final String userId;
  final String title;
  final String rawScript;
  final String imageStyle; // Akan berisi style 'veo'
  final String aspectRatio;
  final String language;
  // --- [REFAKTOR v1.7] Hapus 'voice' (Sinkronisasi dengan firestore_veo_service) ---
  // final String voice; 
  final List<Map<String, dynamic>> identifiedCharacters;
  final String? status;
  final Timestamp createdAt;
  final Timestamp updatedAt;
  // --- [REFAKTOR v1.7] Hapus 'thumbnailImageUrl' & 'thumbnailPrompt' (Tidak dipakai di alur VEO) ---
  // final String? thumbnailImageUrl;
  final String? errorDetail;
  // final String? thumbnailPrompt;
  final String? finalVideoUrl;
  final Map<String, dynamic>? visualSettings; // Tipe Map, bisa null

  // --- KATEGORI_FITUR_TIMEOUT (Dipertahankan) ---
  final Timestamp? renderStartedAt;
  // --- AKHIR FITUR ---

  // --- KATEGORI_ISOLASI_VEO: Konstruktor diubah ---
  VideoProjectVeo({
  // --- AKHIR MODIFIKASI ---
    required this.id,
    required this.userId,
    required this.title,
    required this.rawScript,
    required this.imageStyle,
    required this.aspectRatio,
    required this.language,
    // --- [REFAKTOR v1.7] Hapus 'voice' ---
    // required this.voice,
    required this.identifiedCharacters,
    this.status,
    required this.createdAt,
    required this.updatedAt,
    // --- [REFAKTOR v1.7] Hapus 'thumbnailImageUrl' & 'thumbnailPrompt' ---
    // this.thumbnailImageUrl,
    this.errorDetail,
    // this.thumbnailPrompt,
    this.finalVideoUrl,
    this.visualSettings, // Parameter opsional

    // --- KATEGORI_FITUR_TIMEOUT (Dipertahankan) ---
    this.renderStartedAt, // Parameter opsional
    // --- AKHIR FITUR ---
  });

  // Factory constructor
  // --- KATEGORI_ISOLASI_VEO: Factory diubah ---
  factory VideoProjectVeo.fromFirestore(DocumentSnapshot doc) {
  // --- AKHIR MODIFIKASI ---
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    // Helper untuk timestamp (Dipertahankan)
    Timestamp _getTimestamp(dynamic value) {
        if (value is Timestamp) return value;
        if (value is Map && value.containsKey('_seconds')) {
            try { return Timestamp(value['_seconds'], value['_nanoseconds'] ?? 0); } catch (_) {}
        }
        return Timestamp.now(); // Fallback
    }
    
    // Helper Timestamp Nullable (Dipertahankan)
    Timestamp? _getNullableTimestamp(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value;
      if (value is Map && value.containsKey('_seconds')) {
            try { return Timestamp(value['_seconds'], value['_nanoseconds'] ?? 0); } catch (_) {}
      }
      return null; // Fallback ke null jika tipe data tidak dikenal
    }

    // --- KATEGORI_ISOLASI_VEO: Return type diubah ---
    return VideoProjectVeo(
    // --- AKHIR MODIFIKASI ---
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      title: data['title'] as String? ?? 'Untitled Veo Project', // Judul default diubah
      rawScript: data['rawScript'] as String? ?? '',
      imageStyle: data['imageStyle'] as String? ?? 'Veo-Default', // Style default diubah
      aspectRatio: data['aspectRatio'] as String? ?? '16:9',
      language: data['language'] as String? ?? 'Indonesian',
      // --- [REFAKTOR v1.7] Hapus 'voice' ---
      // voice: data['voice'] as String? ?? 'id-ID-Chirp3-HD-Achernar',
      identifiedCharacters: (data['identifiedCharacters'] is List)
          ? List<Map<String, dynamic>>.from(
              (data['identifiedCharacters'] as List).map((item) =>
                  item is Map ? Map<String, dynamic>.from(item) : {}))
          : [],
      status: data['status'] as String?,
      createdAt: _getTimestamp(data['createdAt']),
      updatedAt: _getTimestamp(data['updatedAt']),
      // --- [REFAKTOR v1.7] Hapus 'thumbnailImageUrl' & 'thumbnailPrompt' ---
      // thumbnailImageUrl: data['thumbnailImageUrl'] as String?,
      errorDetail: data['errorDetail'] as String?,
      // thumbnailPrompt: data['thumbnailPrompt'] as String?,
      finalVideoUrl: data['finalVideoUrl'] as String?,
      visualSettings: data['visualSettings'] is Map
              ? Map<String, dynamic>.from(data['visualSettings'])
              : null,
          
      renderStartedAt: _getNullableTimestamp(data['renderStartedAt']),
    );
  }

  // Method to convert to map (Dipertahankan)
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'title': title,
      'rawScript': rawScript,
      'imageStyle': imageStyle,
      'aspectRatio': aspectRatio,
      'language': language,
      // --- [REFAKTOR v1.7] Hapus 'voice' ---
      // 'voice': voice,
      'identifiedCharacters': identifiedCharacters,
      if (status != null) 'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
      // --- [REFAKTOR v1.7] Hapus 'thumbnailImageUrl' & 'thumbnailPrompt' ---
      // if (thumbnailImageUrl != null) 'thumbnailImageUrl': thumbnailImageUrl,
      if (errorDetail != null) 'errorDetail': errorDetail,
      // if (thumbnailPrompt != null) 'thumbnailPrompt': thumbnailPrompt,
      if (finalVideoUrl != null) 'finalVideoUrl': finalVideoUrl,
      if (visualSettings != null) 'visualSettings': visualSettings,
      if (renderStartedAt != null) 'renderStartedAt': renderStartedAt,
    };
  }

  // copyWith method
  // --- KATEGORI_ISOLASI_VEO: Tipe return diubah ---
  VideoProjectVeo copyWith({
  // --- AKHIR MODIFIKASI ---
    String? id, String? userId, String? title, String? rawScript,
    String? imageStyle, String? aspectRatio, String? language, // String? voice, <-- Dihapus
    List<Map<String, dynamic>>? identifiedCharacters, String? status,
    Timestamp? createdAt, Timestamp? updatedAt, //String? thumbnailImageUrl, <-- Dihapus
    String? errorDetail, //String? thumbnailPrompt, <-- Dihapus
    String? finalVideoUrl,
    Map<String, dynamic>? visualSettings,
    bool clearVisualSettings = false,
    Timestamp? renderStartedAt,
    bool clearRenderStartedAt = false,
  }) {
    // --- KATEGORI_ISOLASI_VEO: Konstruktor diubah ---
    return VideoProjectVeo(
    // --- AKHIR MODIFIKASI ---
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      rawScript: rawScript ?? this.rawScript,
      imageStyle: imageStyle ?? this.imageStyle,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      language: language ?? this.language,
      // --- [REFAKTOR v1.7] Hapus 'voice' ---
      // voice: voice ?? this.voice,
      identifiedCharacters: identifiedCharacters ?? this.identifiedCharacters,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      // --- [REFAKTOR v1.7] Hapus 'thumbnailImageUrl' & 'thumbnailPrompt' ---
      // thumbnailImageUrl: thumbnailImageUrl ?? this.thumbnailImageUrl,
      errorDetail: errorDetail ?? this.errorDetail,
      // thumbnailPrompt: thumbnailPrompt ?? this.thumbnailPrompt,
      finalVideoUrl: finalVideoUrl ?? this.finalVideoUrl,
      visualSettings: clearVisualSettings ? null : (visualSettings ?? this.visualSettings),
      renderStartedAt: clearRenderStartedAt ? null : (renderStartedAt ?? this.renderStartedAt),
    );
  }

  // operator == and hashCode (Dipertahankan)
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    final listEquals = const DeepCollectionEquality().equals;
    final mapEquals = const DeepCollectionEquality().equals;

    // --- KATEGORI_ISOLASI_VEO: Tipe check diubah ---
    return other is VideoProjectVeo &&
    // --- AKHIR MODIFIKASI ---
        other.id == id &&
        other.userId == userId &&
        other.title == title &&
        other.rawScript == rawScript &&
        other.imageStyle == imageStyle &&
        other.aspectRatio == aspectRatio &&
        other.language == language &&
        // --- [REFAKTOR v1.7] Hapus 'voice' ---
        // other.voice == voice &&
        listEquals(other.identifiedCharacters, identifiedCharacters) &&
        other.status == status &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        // --- [REFAKTOR v1.7] Hapus 'thumbnailImageUrl' & 'thumbnailPrompt' ---
        // other.thumbnailImageUrl == thumbnailImageUrl &&
        other.errorDetail == errorDetail &&
        // other.thumbnailPrompt == thumbnailPrompt &&
        other.finalVideoUrl == finalVideoUrl &&
        mapEquals(other.visualSettings, visualSettings) &&
        other.renderStartedAt == renderStartedAt;
  }

  @override
  int get hashCode {
    final listHash = const DeepCollectionEquality().hash;
    final mapHash = const DeepCollectionEquality().hash;

    return id.hashCode ^ userId.hashCode ^ title.hashCode ^ rawScript.hashCode ^
        imageStyle.hashCode ^ aspectRatio.hashCode ^ language.hashCode ^ // voice.hashCode ^ <-- Dihapus
        listHash(identifiedCharacters).hashCode ^
        status.hashCode ^ createdAt.hashCode ^ updatedAt.hashCode ^
        // thumbnailImageUrl.hashCode ^ <-- Dihapus
        errorDetail.hashCode ^ // thumbnailPrompt.hashCode ^ <-- Dihapus
        finalVideoUrl.hashCode ^
        mapHash(visualSettings).hashCode ^
        renderStartedAt.hashCode;
  }
}