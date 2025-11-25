import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'; // Import for listEquals

class Scene {
  final String id; // Document ID from Firestore
  final int segmentIndex;
  final String segmentText;
  // final int charCount; // Field ini sepertinya tidak dipakai lagi di backend? Jika masih, aktifkan lagi.
  final String ttsAudioUrl;
  final String rawPrompt;
  final String? refinedPrompt; // Nullable jika belum direfine
  final String imageUrl;
  // final double calculatedDuration; // Field ini sepertinya tidak dipakai lagi? Jika masih, aktifkan lagi.
  // final double? userAdjustedDuration; // Nullable
  // final bool isEdited; // Field ini sepertinya tidak dipakai lagi? Jika masih, aktifkan lagi.
  final String? status;
  // --- PERBAIKAN: Tambah errorDetail ---
  final String? errorDetail; // Detail error jika ada (opsional)
  // --- AKHIR PERBAIKAN ---

  // --- KATEGORI_MODIFIKASI_MODEL (Perbaikan Fase 1) ---
  final double? duration; // Durasi audio akurat (ffprobe) dari backend
  // --- AKHIR MODIFIKASI ---

  Scene({
    required this.id,
    required this.segmentIndex,
    required this.segmentText,
    // required this.charCount,
    required this.ttsAudioUrl,
    required this.rawPrompt,
    this.refinedPrompt,
    required this.imageUrl,
    // required this.calculatedDuration,
    // this.userAdjustedDuration,
    // required this.isEdited,
    this.status,
    this.errorDetail, // Ditambahkan
    this.duration, // <-- Ditambahkan
  });

  // Factory constructor to create a Scene from a Firestore document
  factory Scene.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Scene(
      id: doc.id,
      segmentIndex: data['segmentIndex'] ?? -1, // Default -1 jika tidak ada
      segmentText: data['segmentText'] ?? '',
      // charCount: data['charCount'] ?? (data['segmentText'] as String? ?? '').length, // Kalkulasi jika perlu
      ttsAudioUrl: data['ttsAudioUrl'] ?? '',
      rawPrompt: data['rawPrompt'] ?? '',
      refinedPrompt: data['refinedPrompt'], // Biarkan null
      imageUrl: data['imageUrl'] ?? '',
      // calculatedDuration: (data['calculatedDuration'] ?? 0.0).toDouble(),
      // userAdjustedDuration: (data['userAdjustedDuration'] as num?)?.toDouble(),
      // isEdited: data['isEdited'] ?? false,
      status: data['status'], // Biarkan null
      // --- PERBAIKAN: Baca errorDetail ---
      errorDetail: data['errorDetail'], // Baca errorDetail, biarkan null
      // --- AKHIR PERBAIKAN ---

      // --- KATEGORI_MODIFIKASI_MODEL (Perbaikan Fase 1) ---
      // Baca 'duration' sebagai num? (int atau double) lalu konversi ke double?
      duration: (data['duration'] as num?)?.toDouble(),
      // --- AKHIR MODIFIKASI ---
    );
  }

  // Method to convert a Scene instance to a map for Firestore
  // (Biasanya tidak dibutuhkan di frontend jika hanya membaca data)
  Map<String, dynamic> toFirestore() {
    return {
      'segmentIndex': segmentIndex,
      'segmentText': segmentText,
      // 'charCount': charCount,
      'ttsAudioUrl': ttsAudioUrl,
      'rawPrompt': rawPrompt,
      if (refinedPrompt != null) 'refinedPrompt': refinedPrompt,
      'imageUrl': imageUrl,
      // 'calculatedDuration': calculatedDuration,
      // if (userAdjustedDuration != null) 'userAdjustedDuration': userAdjustedDuration,
      // 'isEdited': isEdited,
      if (status != null) 'status': status,
      if (errorDetail != null) 'errorDetail': errorDetail, // Ditambahkan
      if (duration != null) 'duration': duration, // <-- Ditambahkan
    };
  }

  // --- copyWith (Diperbarui) ---
   Scene copyWith({
    String? id,
    int? segmentIndex,
    String? segmentText,
    // int? charCount,
    String? ttsAudioUrl,
    String? rawPrompt,
    // Gunakan ValueGetter agar bisa set null secara eksplisit jika perlu
    ValueGetter<String?>? refinedPrompt,
    String? imageUrl,
    // double? calculatedDuration,
    // ValueGetter<double?>? userAdjustedDuration,
    // bool? isEdited,
    ValueGetter<String?>? status,
    ValueGetter<String?>? errorDetail,
    double? duration, // <-- Ditambahkan
  }) {
    return Scene(
      id: id ?? this.id,
      segmentIndex: segmentIndex ?? this.segmentIndex,
      segmentText: segmentText ?? this.segmentText,
      // charCount: charCount ?? this.charCount,
      ttsAudioUrl: ttsAudioUrl ?? this.ttsAudioUrl,
      rawPrompt: rawPrompt ?? this.rawPrompt,
      // refinedPrompt: refinedPrompt != null ? refinedPrompt() : this.refinedPrompt,
      // Menggunakan ?? untuk nullable field lebih sederhana jika tidak perlu set null eksplisit
      refinedPrompt: refinedPrompt != null ? refinedPrompt() : this.refinedPrompt,
      imageUrl: imageUrl ?? this.imageUrl,
      // calculatedDuration: calculatedDuration ?? this.calculatedDuration,
      // userAdjustedDuration: userAdjustedDuration != null ? userAdjustedDuration() : this.userAdjustedDuration,
      // isEdited: isEdited ?? this.isEdited,
      status: status != null ? status() : this.status,
      errorDetail: errorDetail != null ? errorDetail() : this.errorDetail,
      duration: duration ?? this.duration, // <-- Ditambahkan
    );
  }

  // --- operator == dan hashCode (Diperbarui) ---
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Scene &&
        other.id == id &&
        other.segmentIndex == segmentIndex &&
        other.segmentText == segmentText &&
        // other.charCount == charCount &&
        other.ttsAudioUrl == ttsAudioUrl &&
        other.rawPrompt == rawPrompt &&
        other.refinedPrompt == refinedPrompt &&
        other.imageUrl == imageUrl &&
        // other.calculatedDuration == calculatedDuration &&
        // other.userAdjustedDuration == userAdjustedDuration &&
        // other.isEdited == isEdited &&
        other.status == status &&
        other.errorDetail == errorDetail &&
        other.duration == duration; // <-- Ditambahkan
  }

  @override
  int get hashCode {
    return id.hashCode ^
        segmentIndex.hashCode ^
        segmentText.hashCode ^
        // charCount.hashCode ^
        ttsAudioUrl.hashCode ^
        rawPrompt.hashCode ^
        refinedPrompt.hashCode ^
        imageUrl.hashCode ^
        // calculatedDuration.hashCode ^
        // userAdjustedDuration.hashCode ^
        // isEdited.hashCode ^
        status.hashCode ^
        errorDetail.hashCode ^
        duration.hashCode; // <-- Ditambahkan
  }
}