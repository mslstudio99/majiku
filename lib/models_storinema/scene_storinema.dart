//................................................................//
// NAMA FILE: SCENE_STORINEMA.DART                                //
// DIREKTORI: LIB/MODELS_STORINEMA/                               //
// DESKRIPSI: KELAS MODEL DATA UNTUK SCENE STORINEMA (TTS READY)  //
//................................................................//

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

//No ke-1: KELAS SUBTITLE CHUNK (AUTO-SIMULASI) ..................//
//................................................................//
// Digunakan untuk mensimulasikan chunk agar UI tidak crash
@immutable
class SubtitleChunkStorinema {
  final String text;
  final double startTime;
  final double duration;

  const SubtitleChunkStorinema({
    required this.text,
    required this.startTime,
    required this.duration,
  });

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'startTime': startTime,
      'duration': duration,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SubtitleChunkStorinema &&
        other.text == text &&
        other.startTime == startTime &&
        other.duration == duration;
  }

  @override
  int get hashCode => text.hashCode ^ startTime.hashCode ^ duration.hashCode;
}
//................................................................//

class SceneStorinema {
//No ke-2: PROPERTI DAN KONSTRUKTOR ..............................//
//................................................................//
  final String id;
  final int segmentIndex;
  final String segmentText;
  final String rawPrompt;
  final String? refinedPrompt;
  final String videoUrl;
  final String ttsAudioUrl; 
  final String? status;
  final String? errorDetail;
  final double? duration;
  
  // [PERBAIKAN] Menambahkan tipe data statis agar UI terbebas dari dynamic casting
  final List<SubtitleChunkStorinema> subtitleChunks; 

  SceneStorinema({
    required this.id,
    required this.segmentIndex,
    required this.segmentText,
    required this.rawPrompt,
    this.refinedPrompt,
    required this.videoUrl,
    required this.ttsAudioUrl, 
    this.status,
    this.errorDetail,
    this.duration,
    this.subtitleChunks = const [], // Default array kosong
  });
//................................................................//

//No ke-3: SERIALISASI FIRESTORE & SIMULASI CERDAS ...............//
//................................................................//
  factory SceneStorinema.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    // Ambil durasi aktual atau gunakan standar Bytedance Seedance (8.0 detik)
    double parsedDuration = (data['duration'] as num?)?.toDouble() ?? 8.0;
    
    // Auto-Simulasi Subtitle Chunks
    List<SubtitleChunkStorinema> parsedChunks = [];
    if (data['subtitleChunks'] != null && data['subtitleChunks'] is List) {
      // Jika backend masa depan mulai mengirimkan array chunk
      parsedChunks = (data['subtitleChunks'] as List).map((c) {
        return SubtitleChunkStorinema(
          text: c['text'] ?? '',
          startTime: (c['startTime'] as num?)?.toDouble() ?? 0.0,
          duration: (c['duration'] as num?)?.toDouble() ?? parsedDuration,
        );
      }).toList();
    } else {
      // [CORE FIX] Jika kosong, ubah segmentText menjadi 1 subtitle penuh
      String txt = data['segmentText'] ?? '';
      if (txt.isNotEmpty) {
        parsedChunks = [
          SubtitleChunkStorinema(
            text: txt,
            startTime: 0.0,
            duration: parsedDuration,
          )
        ];
      }
    }

    return SceneStorinema(
      id: doc.id,
      segmentIndex: data['segmentIndex'] ?? -1,
      segmentText: data['segmentText'] ?? '',
      rawPrompt: data['rawPrompt'] ?? '',
      refinedPrompt: data['refinedPrompt'],
      videoUrl: data['videoUrl'] ?? '',
      ttsAudioUrl: data['ttsAudioUrl'] ?? '', 
      status: data['status'],
      errorDetail: data['errorDetail'],
      duration: parsedDuration,
      subtitleChunks: parsedChunks, // Suntikkan chunk yang sudah disimulasikan
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'segmentIndex': segmentIndex,
      'segmentText': segmentText,
      'rawPrompt': rawPrompt,
      if (refinedPrompt != null) 'refinedPrompt': refinedPrompt,
      'videoUrl': videoUrl,
      'ttsAudioUrl': ttsAudioUrl, 
      if (status != null) 'status': status,
      if (errorDetail != null) 'errorDetail': errorDetail,
      if (duration != null) 'duration': duration,
      'subtitleChunks': subtitleChunks.map((c) => c.toJson()).toList(), // Simpan kembali jika diperlukan
    };
  }
//................................................................//

//No ke-4: COPYWITH DAN EQUALITY .................................//
//................................................................//
  SceneStorinema copyWith({
    String? id,
    int? segmentIndex,
    String? segmentText,
    String? rawPrompt,
    ValueGetter<String?>? refinedPrompt,
    String? videoUrl,
    String? ttsAudioUrl, 
    ValueGetter<String?>? status,
    ValueGetter<String?>? errorDetail,
    double? duration,
    List<SubtitleChunkStorinema>? subtitleChunks,
  }) {
    return SceneStorinema(
      id: id ?? this.id,
      segmentIndex: segmentIndex ?? this.segmentIndex,
      segmentText: segmentText ?? this.segmentText,
      rawPrompt: rawPrompt ?? this.rawPrompt,
      refinedPrompt: refinedPrompt != null ? refinedPrompt() : this.refinedPrompt,
      videoUrl: videoUrl ?? this.videoUrl,
      ttsAudioUrl: ttsAudioUrl ?? this.ttsAudioUrl, 
      status: status != null ? status() : this.status,
      errorDetail: errorDetail != null ? errorDetail() : this.errorDetail,
      duration: duration ?? this.duration,
      subtitleChunks: subtitleChunks ?? this.subtitleChunks,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is SceneStorinema &&
        other.id == id &&
        other.segmentIndex == segmentIndex &&
        other.segmentText == segmentText &&
        other.rawPrompt == rawPrompt &&
        other.refinedPrompt == refinedPrompt &&
        other.videoUrl == videoUrl &&
        other.ttsAudioUrl == ttsAudioUrl && 
        other.status == status &&
        other.errorDetail == errorDetail &&
        other.duration == duration &&
        listEquals(other.subtitleChunks, subtitleChunks); // [EQUALITY SINKRON]
  }

  @override
  int get hashCode {
    return id.hashCode ^
        segmentIndex.hashCode ^
        segmentText.hashCode ^
        rawPrompt.hashCode ^
        refinedPrompt.hashCode ^
        videoUrl.hashCode ^
        ttsAudioUrl.hashCode ^ 
        status.hashCode ^
        errorDetail.hashCode ^
        duration.hashCode ^
        Object.hashAll(subtitleChunks); // [HASHCODE SINKRON]
  }
//................................................................//
}