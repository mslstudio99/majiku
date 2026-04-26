// [NAMA FILE: lib/models_naraku/video_project_t2video.dart] //
// [KATEGORI: MODEL] //
// [TUJUAN: Kerangka Data untuk Riwayat T2Video di Firestore] //

// No ke-1: KELAS MODEL DATA //
//.......................................................//
import 'package:cloud_firestore/cloud_firestore.dart';

class VideoProjectT2Video {
  final String id;
  final String userId;
  final String prompt;
  final String videoUrl;
  final String style;
  final String aspectRatio;
  final String resolution;
  final int duration;
  final DateTime createdAt;

  VideoProjectT2Video({
    required this.id,
    required this.userId,
    required this.prompt,
    required this.videoUrl,
    required this.style,
    required this.aspectRatio,
    required this.resolution,
    required this.duration,
    required this.createdAt,
  });

  // Konversi dari Model ke Map (Untuk dikirim ke Firestore)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'prompt': prompt,
      'videoUrl': videoUrl,
      'style': style,
      'aspectRatio': aspectRatio,
      'resolution': resolution,
      'duration': duration,
      'createdAt': FieldValue.serverTimestamp(), // Gunakan waktu server Firestore
    };
  }

  // Konversi dari Map (Firestore) ke Model (Untuk dibaca di Flutter)
  factory VideoProjectT2Video.fromMap(Map<String, dynamic> map, String documentId) {
    return VideoProjectT2Video(
      id: documentId,
      userId: map['userId'] ?? '',
      prompt: map['prompt'] ?? '',
      videoUrl: map['videoUrl'] ?? '',
      style: map['style'] ?? '',
      aspectRatio: map['aspectRatio'] ?? '',
      resolution: map['resolution'] ?? '',
      duration: map['duration'] ?? 0,
      createdAt: map['createdAt'] != null 
          ? (map['createdAt'] as Timestamp).toDate() 
          : DateTime.now(),
    );
  }
}
//.......................................................//