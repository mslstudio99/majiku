// VIDEO_PROJECT_T2VIDEO-PLUS.DART //
// LIB/MODELS_NARAKU/VIDEO_PROJECT_T2VIDEO-PLUS.DART //
// KERANGKA DATA UNTUK RIWAYAT T2VIDEO-PLUS DI FIRESTORE //

// No ke-1 - KELAS MODEL DATA //
// KELAS MODEL DAN KONVERSI FIRESTORE (DENGAN DUKUNGAN IMAGEURL) //
//.......................................................//
import 'package:cloud_firestore/cloud_firestore.dart';

class VideoProjectT2videoPlus {
  final String id;
  final String userid;
  final String prompt;
  final String videourl;
  final String? imageurl; // [BARU]: Menampung URL gambar acuan dari Gemini Flash Image
  final String style;
  final String aspectratio;
  final String resolution;
  final int duration;
  final DateTime createdat;

  VideoProjectT2videoPlus({
    required this.id,
    required this.userid,
    required this.prompt,
    required this.videourl,
    this.imageurl, // Dibuat opsional untuk menjamin backward-compatibility riwayat lama
    required this.style,
    required this.aspectratio,
    required this.resolution,
    required this.duration,
    required this.createdat,
  });

  // Konversi dari Model ke Map (Untuk dikirim ke Firestore)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userid': userid,
      'prompt': prompt,
      'videourl': videourl,
      'imageurl': imageurl, // [BARU]: Menyimpan URL gambar referensi ke dokumen Firestore
      'style': style,
      'aspectratio': aspectratio,
      'resolution': resolution,
      'duration': duration,
      'createdat': FieldValue.serverTimestamp(), // Gunakan waktu server Firestore
    };
  }

  // Konversi dari Map (Firestore) ke Model (Untuk dibaca di Flutter)
  factory VideoProjectT2videoPlus.fromMap(Map<String, dynamic> map, String documentid) {
    return VideoProjectT2videoPlus(
      id: documentid,
      userid: map['userid'] ?? '',
      prompt: map['prompt'] ?? '',
      videourl: map['videourl'] ?? '',
      imageurl: map['imageurl'], // [BARU]: Membaca URL gambar acuan (null-safe)
      style: map['style'] ?? '',
      aspectratio: map['aspectratio'] ?? '',
      resolution: map['resolution'] ?? '',
      duration: map['duration'] ?? 0,
      createdat: map['createdat'] != null 
          ? (map['createdat'] as Timestamp).toDate() 
          : DateTime.now(),
    );
  }
}
//.......................................................//