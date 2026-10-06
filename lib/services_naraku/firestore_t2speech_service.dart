//================================================================//
// LIB/SERVICES_NARAKU/FIRESTORE_T2SPEECH_SERVICE.DART            //
// SERVICE FIRESTORE UNTUK TEXT TO SPEECH (T2SPEECH)              //
// MENYIMPAN, MEMBACA STREAM, DAN MENGHAPUS RIWAYAT AUDIO PROJECT //
//================================================================//

//No ke-1: FIREBASE SERVICE T2SPEECH//
//OPERASI CRUD RIWAYAT GENERASI T2SPEECH PADA CLOUD FIRESTORE//
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models_naraku/audio_project_t2speech.dart';

class FirestoreT2SpeechService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Nama koleksi utama
  final String _collectionName = 'projects_t2speech';

  // [CREATE] Simpan proyek audio baru
  Future<String> saveProject(AudioProjectT2Speech project) async {
    try {
      final docRef = _firestore.collection(_collectionName).doc();
      final projectToSave = AudioProjectT2Speech(
        id: docRef.id,
        userId: project.userId,
        text: project.text,
        audioUrl: project.audioUrl,
        voice: project.voice,
        language: project.language,
        createdAt: project.createdAt,
      );
      await docRef.set(projectToSave.toMap());
      return docRef.id;
    } catch (e) {
      throw Exception("Gagal menyimpan data T2Speech: $e");
    }
  }

  // [READ] Mengambil daftar proyek user secara realtime (Stream)
  Stream<List<AudioProjectT2Speech>> streamUserProjects(String userId) {
    return _firestore
        .collection(_collectionName)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return AudioProjectT2Speech.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  // [DELETE] Menghapus riwayat berdasarkan ID Dokumen
  Future<void> deleteProject(String projectId) async {
    try {
      await _firestore.collection(_collectionName).doc(projectId).delete();
    } catch (e) {
      throw Exception("Gagal menghapus data T2Speech: $e");
    }
  }
}
// END OF BLOK 1 //
//================================================================//