// --- KATEGORI_ISOLASI_VEO: Path file: models_veo/scene_veo.dart ---

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'; // Import for listEquals

// --- KATEGORI_ISOLASI_VEO: Nama Class diubah ---
class SceneVeo {
// --- AKHIR MODIFIKASI ---
  final String id; // Document ID from Firestore
  final int segmentIndex;
  final String segmentText;
  // --- [REFAKTOR v1.7] Hapus ttsAudioUrl (Sinkronisasi dengan backend) ---
  // final String ttsAudioUrl; 
  final String rawPrompt;
  final String? refinedPrompt; // Nullable jika belum direfine
  
  // --- KATEGORI_ISOLASI_VEO: Perubahan Semantik (Gambar -> Video) ---
  final String videoUrl; // <-- Menggantikan imageUrl
  // --- AKHIR MODIFIKASI ---

  final String? status;
  final String? errorDetail; // Detail error jika ada (opsional)
  final double? duration; // Durasi audio/video akurat (ffprobe) dari backend

  // --- KATEGORI_ISOLASI_VEO: Konstruktor diubah ---
  SceneVeo({
  // --- AKHIR MODIFIKASI ---
    required this.id,
    required this.segmentIndex,
    required this.segmentText,
    // --- [REFAKTOR v1.7] Hapus ttsAudioUrl ---
    // required this.ttsAudioUrl,
    required this.rawPrompt,
    this.refinedPrompt,
    // --- KATEGORI_ISOLASI_VEO: Perubahan Semantik ---
    required this.videoUrl, // <-- Menggantikan imageUrl
    // --- AKHIR MODIFIKASI ---
    this.status,
    this.errorDetail,
    this.duration,
  });

  // Factory constructor to create a Scene from a Firestore document
  // --- KATEGORI_ISOLASI_VEO: Factory diubah ---
  factory SceneVeo.fromFirestore(DocumentSnapshot doc) {
  // --- AKHIR MODIFIKASI ---
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    // --- KATEGORI_ISOLASI_VEO: Return type diubah ---
    return SceneVeo(
    // --- AKHIR MODIFIKASI ---
      id: doc.id,
      segmentIndex: data['segmentIndex'] ?? -1,
      segmentText: data['segmentText'] ?? '',
      // --- [REFAKTOR v1.7] Hapus ttsAudioUrl ---
      // ttsAudioUrl: data['ttsAudioUrl'] ?? '',
      rawPrompt: data['rawPrompt'] ?? '',
      refinedPrompt: data['refinedPrompt'],
      // --- KATEGORI_ISOLASI_VEO: Perubahan Semantik ---
      videoUrl: data['videoUrl'] ?? '', // <-- Menggantikan imageUrl
      // --- AKHIR MODIFIKASI ---
      status: data['status'],
      errorDetail: data['errorDetail'],
      duration: (data['duration'] as num?)?.toDouble(),
    );
  }

  // Method to convert a Scene instance to a map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'segmentIndex': segmentIndex,
      'segmentText': segmentText,
      // --- [REFAKTOR v1.7] Hapus ttsAudioUrl ---
      // 'ttsAudioUrl': ttsAudioUrl,
      'rawPrompt': rawPrompt,
      if (refinedPrompt != null) 'refinedPrompt': refinedPrompt,
      // --- KATEGORI_ISOLASI_VEO: Perubahan Semantik ---
      'videoUrl': videoUrl, // <-- Menggantikan imageUrl
      // --- AKHIR MODIFIKASI ---
      if (status != null) 'status': status,
      if (errorDetail != null) 'errorDetail': errorDetail,
      if (duration != null) 'duration': duration,
    };
  }

  // --- copyWith (Diperbarui) ---
  // --- KATEGORI_ISOLASI_VEO: Tipe return diubah ---
  SceneVeo copyWith({
  // --- AKHIR MODIFIKASI ---
    String? id,
    int? segmentIndex,
    String? segmentText,
    // String? ttsAudioUrl, // <-- Dihapus
    String? rawPrompt,
    ValueGetter<String?>? refinedPrompt,
    // --- KATEGORI_ISOLASI_VEO: Perubahan Semantik ---
    String? videoUrl, // <-- Menggantikan imageUrl
    // --- AKHIR MODIFIKASI ---
    ValueGetter<String?>? status,
    ValueGetter<String?>? errorDetail,
    double? duration,
  }) {
    // --- KATEGORI_ISOLASI_VEO: Konstruktor diubah ---
    return SceneVeo(
    // --- AKHIR MODIFIKASI ---
      id: id ?? this.id,
      segmentIndex: segmentIndex ?? this.segmentIndex,
      segmentText: segmentText ?? this.segmentText,
      // --- [REFAKTOR v1.7] Hapus ttsAudioUrl ---
      // ttsAudioUrl: ttsAudioUrl ?? this.ttsAudioUrl,
      rawPrompt: rawPrompt ?? this.rawPrompt,
      refinedPrompt: refinedPrompt != null ? refinedPrompt() : this.refinedPrompt,
      // --- KATEGORI_ISOLASI_VEO: Perubahan Semantik ---
      videoUrl: videoUrl ?? this.videoUrl, // <-- Menggantikan imageUrl
      // --- AKHIR MODIFIKASI ---
      status: status != null ? status() : this.status,
      errorDetail: errorDetail != null ? errorDetail() : this.errorDetail,
      duration: duration ?? this.duration,
    );
  }

  // --- operator == dan hashCode (Diperbarui) ---
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    // --- KATEGORI_ISOLASI_VEO: Tipe check diubah ---
    return other is SceneVeo &&
    // --- AKHIR MODIFIKASI ---
        other.id == id &&
        other.segmentIndex == segmentIndex &&
        other.segmentText == segmentText &&
        // --- [REFAKTOR v1.7] Hapus ttsAudioUrl ---
        // other.ttsAudioUrl == ttsAudioUrl &&
        other.rawPrompt == rawPrompt &&
        other.refinedPrompt == refinedPrompt &&
        // --- KATEGORI_ISOLASI_VEO: Perubahan Semantik ---
        other.videoUrl == videoUrl && // <-- Menggantikan imageUrl
        // --- AKHIR MODIFIKASI ---
        other.status == status &&
        other.errorDetail == errorDetail &&
        other.duration == duration;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        segmentIndex.hashCode ^
        segmentText.hashCode ^
        // --- [REFAKTOR v1.7] Hapus ttsAudioUrl ---
        // ttsAudioUrl.hashCode ^
        rawPrompt.hashCode ^
        refinedPrompt.hashCode ^
        // --- KATEGORI_ISOLASI_VEO: Perubahan Semantik ---
        videoUrl.hashCode ^ // <-- Menggantikan imageUrl
        // --- AKHIR MODIFIKASI ---
        status.hashCode ^
        errorDetail.hashCode ^
        duration.hashCode;
  }
}