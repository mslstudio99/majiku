// [NAMA FILE: lib/models_naraku/image_project_t2image.dart] //
// [KATEGORI: MODEL] //
// [TUJUAN: Kerangka Data untuk Riwayat T2Image di Firestore] //

// No ke-1: KELAS MODEL DATA //
//.......................................................//
import 'package:cloud_firestore/cloud_firestore.dart';

class ImageProjectT2Image {
  final String id;
  final String userId;
  final String prompt;
  final String imageUrl; // Diubah dari videoUrl
  final String style;
  final String aspectRatio;
  final DateTime createdAt;

  ImageProjectT2Image({
    required this.id,
    required this.userId,
    required this.prompt,
    required this.imageUrl,
    required this.style,
    required this.aspectRatio,
    required this.createdAt,
  });

  // Konversi dari Model ke Map (Untuk dikirim ke Firestore)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'prompt': prompt,
      'imageUrl': imageUrl,
      'style': style,
      'aspectRatio': aspectRatio,
      'createdAt': FieldValue.serverTimestamp(), // Gunakan waktu server Firestore
    };
  }

  // Konversi dari Map (Firestore) ke Model (Untuk dibaca di Flutter)
  factory ImageProjectT2Image.fromMap(Map<String, dynamic> map, String documentId) {
    return ImageProjectT2Image(
      id: documentId,
      userId: map['userId'] ?? '',
      prompt: map['prompt'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      style: map['style'] ?? '',
      aspectRatio: map['aspectRatio'] ?? '',
      createdAt: map['createdAt'] != null 
          ? (map['createdAt'] as Timestamp).toDate() 
          : DateTime.now(),
    );
  }
}
//.......................................................//