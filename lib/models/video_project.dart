//................................................................//
// NAMA FILE: VIDEO_PROJECT.DART                                  //
// PATH: LIB/MODELS/VIDEO_PROJECT.DART                            //
//................................................................//

//No ke-1.........................................................//
// IMPORT DEPENDENSI & SETUP MODEL                                //
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart'; // Import for DeepCollectionEquality
//................................................................//

//No ke-2.........................................................//
// SETUP KELAS VIDEO_PROJECT UTAMA                                //
class VideoProject {
  final String id;
  final String userId;
  final String title;
  final String description; // <-- [KATEGORI_PERBAIKAN: Tambahkan deskripsi kustom]
  final String rawScript;
  final String imageStyle;
  final String aspectRatio;
  final String language;
  final String voice;
  final List<Map<String, dynamic>> identifiedCharacters;
  final String? status;
  final Timestamp createdAt;
  final Timestamp updatedAt;
  final String? thumbnailImageUrl;
  final String? errorDetail;
  final String? thumbnailPrompt;
  final String? finalVideoUrl;
  final Map<String, dynamic>? visualSettings; // Tipe Map, bisa null

  // --- KATEGORI_FITUR_TIMEOUT NO_URUT_01: Tambahkan Field Timestamp ---
  /// Waktu (server) saat render diminta.
  /// Ini digunakan untuk menghitung sisa waktu timeout 60 menit.
  final Timestamp? renderStartedAt;
  // --- AKHIR FITUR ---

  VideoProject({
    required this.id,
    required this.userId,
    required this.title,
    required this.description, // <-- [KATEGORI_PERBAIKAN: Konstruktor deskripsi]
    required this.rawScript,
    required this.imageStyle,
    required this.aspectRatio,
    required this.language,
    required this.voice,
    required this.identifiedCharacters,
    this.status,
    required this.createdAt,
    required this.updatedAt,
    this.thumbnailImageUrl,
    this.errorDetail,
    this.thumbnailPrompt,
    this.finalVideoUrl,
    this.visualSettings, // Parameter opsional
    
    // --- KATEGORI_FITUR_TIMEOUT NO_URUT_02: Tambahkan ke Konstruktor ---
    this.renderStartedAt, // Parameter opsional
    // --- AKHIR FITUR ---
  });
//........//

//No ke-3.........................................................//
// FACTORY CONSTRUCTOR FROM FIRESTORE                             //
  factory VideoProject.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    // Helper untuk timestamp
    Timestamp _getTimestamp(dynamic value) {
        if (value is Timestamp) return value;
        // Coba parse jika format lain (meskipun sebaiknya Timestamp)
        if (value is Map && value.containsKey('_seconds')) {
            try { return Timestamp(value['_seconds'], value['_nanoseconds'] ?? 0); } catch (_) {}
        }
        return Timestamp.now(); // Fallback
    }
    
    // --- KATEGORI_FITUR_TIMEOUT NO_URUT_03: Helper Timestamp Nullable ---
    // Helper baru untuk membaca timestamp yang mungkin tidak ada (null)
    Timestamp? _getNullableTimestamp(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value;
      if (value is Map && value.containsKey('_seconds')) {
            try { return Timestamp(value['_seconds'], value['_nanoseconds'] ?? 0); } catch (_) {}
      }
      return null; // Fallback ke null jika tipe data tidak dikenal
    }
    // --- AKHIR FITUR ---

    return VideoProject(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      title: data['title'] as String? ?? 'Untitled Project',
      // --- [KATEGORI_PERBAIKAN: Baca deskripsi dari Firestore] ---
      description: data['description'] as String? ?? "Created @ majiku.net\nAuto Video Content & Film Maker",
      rawScript: data['rawScript'] as String? ?? '',
      imageStyle: data['imageStyle'] as String? ?? 'Realistic',
      aspectRatio: data['aspectRatio'] as String? ?? '16:9',
      language: data['language'] as String? ?? 'Indonesian',
      voice: data['voice'] as String? ?? 'id-ID-Chirp3-HD-Achernar',
      // Pastikan identifiedCharacters adalah List<Map>
      identifiedCharacters: (data['identifiedCharacters'] is List)
          ? List<Map<String, dynamic>>.from(
              (data['identifiedCharacters'] as List).map((item) =>
                  item is Map ? Map<String, dynamic>.from(item) : {}))
          : [], // Default list kosong jika bukan list
      status: data['status'] as String?,
      createdAt: _getTimestamp(data['createdAt']), // Gunakan helper
      updatedAt: _getTimestamp(data['updatedAt']), // Gunakan helper
      thumbnailImageUrl: data['thumbnailImageUrl'] as String?,
      errorDetail: data['errorDetail'] as String?,
      thumbnailPrompt: data['thumbnailPrompt'] as String?,
      finalVideoUrl: data['finalVideoUrl'] as String?,
      // --- Baca visualSettings dari Firestore ---
      // Pastikan tipenya Map<String, dynamic> dan bisa null
      visualSettings: data['visualSettings'] is Map
              ? Map<String, dynamic>.from(data['visualSettings'])
              : null, // null jika tidak ada atau tipe salah
              
      // --- KATEGORI_FITUR_TIMEOUT NO_URUT_04: Baca dari Firestore ---
      renderStartedAt: _getNullableTimestamp(data['renderStartedAt']),
      // --- AKHIR FITUR ---
    );
  }
//........//

//No ke-4.........................................................//
// METHOD TOFIRESTORE                                             //
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'title': title,
      'description': description, // --- [KATEGORI_PERBAIKAN: Simpan deskripsi] ---
      'rawScript': rawScript,
      'imageStyle': imageStyle,
      'aspectRatio': aspectRatio,
      'language': language,
      'voice': voice,
      'identifiedCharacters': identifiedCharacters,
      if (status != null) 'status': status,
      // Sebaiknya createdAt hanya diset sekali saat add, jangan di-overwrite saat update
      // 'createdAt': createdAt,
      'updatedAt': FieldValue.serverTimestamp(), // Gunakan server timestamp saat update
      if (thumbnailImageUrl != null) 'thumbnailImageUrl': thumbnailImageUrl,
      if (errorDetail != null) 'errorDetail': errorDetail,
      if (thumbnailPrompt != null) 'thumbnailPrompt': thumbnailPrompt,
      if (finalVideoUrl != null) 'finalVideoUrl': finalVideoUrl,
      // --- Tambahkan visualSettings ke map jika tidak null ---
      if (visualSettings != null) 'visualSettings': visualSettings,
      // --- KATEGORI_FITUR_TIMEOUT NO_URUT_05: Tambahkan ke toFirestore ---
      if (renderStartedAt != null) 'renderStartedAt': renderStartedAt,
      // --- AKHIR FITUR ---
    };
  }
//........//

//No ke-5.........................................................//
// COPYWITH METHOD                                                //
  VideoProject copyWith({
    String? id, String? userId, String? title, String? description, // <-- [KATEGORI_PERBAIKAN: Parameter copyWith]
    String? rawScript, String? imageStyle, String? aspectRatio, String? language, String? voice,
    List<Map<String, dynamic>>? identifiedCharacters, String? status,
    Timestamp? createdAt, Timestamp? updatedAt, String? thumbnailImageUrl,
    String? errorDetail, String? thumbnailPrompt, String? finalVideoUrl,
    Map<String, dynamic>? visualSettings, // Bisa null
    bool clearVisualSettings = false, // Opsi untuk menghapus
    
    // --- KATEGORI_FITUR_TIMEOUT NO_URUT_06: Tambahkan ke copyWith ---
    Timestamp? renderStartedAt,
    bool clearRenderStartedAt = false, // Opsi untuk menghapus
    // --- AKHIR FITUR ---
  }) {
    return VideoProject(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description, // <-- [KATEGORI_PERBAIKAN: Clone deskripsi]
      rawScript: rawScript ?? this.rawScript,
      imageStyle: imageStyle ?? this.imageStyle,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      language: language ?? this.language,
      voice: voice ?? this.voice,
      identifiedCharacters: identifiedCharacters ?? this.identifiedCharacters,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      thumbnailImageUrl: thumbnailImageUrl ?? this.thumbnailImageUrl,
      errorDetail: errorDetail ?? this.errorDetail,
      thumbnailPrompt: thumbnailPrompt ?? this.thumbnailPrompt,
      finalVideoUrl: finalVideoUrl ?? this.finalVideoUrl,
      visualSettings: clearVisualSettings ? null : (visualSettings ?? this.visualSettings),
      
      // --- KATEGORI_FITUR_TIMEOUT NO_URUT_07: Logika copyWith ---
      renderStartedAt: clearRenderStartedAt ? null : (renderStartedAt ?? this.renderStartedAt),
      // --- AKHIR FITUR ---
    );
  }
//........//

//No ke-6.........................................................//
// OPERATORS OVERRIDE & HASHCODE                                  //
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    // Gunakan DeepCollectionEquality untuk list dan map
    final listEquals = const DeepCollectionEquality().equals;
    final mapEquals = const DeepCollectionEquality().equals;

    return other is VideoProject &&
        other.id == id &&
        other.userId == userId &&
        other.title == title &&
        other.description == description && // <-- [KATEGORI_PERBAIKAN: Pembanding deskripsi]
        other.rawScript == rawScript &&
        other.imageStyle == imageStyle &&
        other.aspectRatio == aspectRatio &&
        other.language == language &&
        other.voice == voice &&
        listEquals(other.identifiedCharacters, identifiedCharacters) && // Bandingkan list
        other.status == status &&
        other.createdAt == createdAt && // Bandingkan timestamp
        other.updatedAt == updatedAt && // Bandingkan timestamp
        other.thumbnailImageUrl == thumbnailImageUrl &&
        other.errorDetail == errorDetail &&
        other.thumbnailPrompt == thumbnailPrompt &&
        other.finalVideoUrl == finalVideoUrl &&
        mapEquals(other.visualSettings, visualSettings) && // Bandingkan map
        // --- KATEGORI_FITUR_TIMEOUT NO_URUT_08: Bandingkan di operator== ---
        other.renderStartedAt == renderStartedAt; // Bandingkan timestamp
        // --- AKHIR FITUR ---
  }

  @override
  int get hashCode {
      // Gunakan DeepCollectionEquality untuk hash list dan map
    final listHash = const DeepCollectionEquality().hash;
    final mapHash = const DeepCollectionEquality().hash;

    return id.hashCode ^ userId.hashCode ^ title.hashCode ^ description.hashCode ^ // <-- [KATEGORI_PERBAIKAN: Hash deskripsi]
        rawScript.hashCode ^ imageStyle.hashCode ^ aspectRatio.hashCode ^ language.hashCode ^ voice.hashCode ^
        listHash(identifiedCharacters).hashCode ^
        status.hashCode ^ createdAt.hashCode ^ updatedAt.hashCode ^
        thumbnailImageUrl.hashCode ^ errorDetail.hashCode ^ thumbnailPrompt.hashCode ^
        finalVideoUrl.hashCode ^
        mapHash(visualSettings).hashCode ^ // Hash map
        // --- KATEGORI_FITUR_TIMEOUT NO_URUT_09: Hash field baru ---
        renderStartedAt.hashCode;
        // --- AKHIR FITUR ---
  }
}
//........//