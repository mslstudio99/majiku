// [NAMA FILE: lib/models_naraku/audio_project_t2speech.dart] //
// [KATEGORI: MODEL] //
// [TUJUAN: Kerangka Data untuk Riwayat T2Image di Firestore] //

//================================================================//
// LIB/MODELS_NARAKU/AUDIO_PROJECT_T2SPEECH.DART                  //
// MODEL DATA PROJECT TEXT TO SPEECH (T2SPEECH)                   //
// STRUKTUR DATA AUDIO PROJECT UNTUK RIWAYAT DAN FIRESTORE        //
//================================================================//

//No ke-1: KELAS MODEL DATA AUDIO PROJECT T2SPEECH//
//DEFINISI PROPERTI, SERIALISASI DAN DESERIALISASI DATA FIRESTORE//
import 'package:cloud_firestore/cloud_firestore.dart';

class AudioProjectT2Speech {
  final String id;
  final String userId;
  final String text;
  final String audioUrl;
  final String voice;
  final String language;
  final DateTime createdAt;

  AudioProjectT2Speech({
    required this.id,
    required this.userId,
    required this.text,
    required this.audioUrl,
    required this.voice,
    required this.language,
    required this.createdAt,
  });

  // Konversi dari Model ke Map (Untuk dikirim ke Firestore)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'text': text,
      'audioUrl': audioUrl,
      'voice': voice,
      'language': language,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  // Konversi dari Map (Firestore) ke Model (Untuk dibaca di Flutter)
  factory AudioProjectT2Speech.fromMap(Map<String, dynamic> map, String documentId) {
    return AudioProjectT2Speech(
      id: documentId,
      userId: map['userId'] ?? '',
      text: map['text'] ?? '',
      audioUrl: map['audioUrl'] ?? '',
      voice: map['voice'] ?? '',
      language: map['language'] ?? '',
      createdAt: map['createdAt'] != null 
          ? (map['createdAt'] as Timestamp).toDate() 
          : DateTime.now(),
    );
  }
}
// END OF BLOK 1 //
//================================================================//