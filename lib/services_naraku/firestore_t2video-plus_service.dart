// FIRESTORE_T2VIDEO-PLUS_SERVICE.DART //
// LIB/SERVICES_NARAKU/FIRESTORE_T2VIDEO-PLUS_SERVICE.DART //
// MENYIMPAN, MEMBACA, DAN MENGHAPUS RIWAYAT T2VIDEO-PLUS //

// No ke-1 - FIREBASE SERVICE //
// SERVICE CRUD FIRESTORE UNTUK T2VIDEO-PLUS //
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models_naraku/video_project_t2video-plus.dart';

class FirestoreT2videoPlusService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Nama koleksi utama
  final String _collectionName = 'projects_t2video_plus';

  // [CREATE] Simpan proyek baru
  Future<void> saveProject(VideoProjectT2videoPlus project) async {
    try {
      final docRef = _firestore.collection(_collectionName).doc();
      final projectToSave = VideoProjectT2videoPlus(
        id: docRef.id,
        userid: project.userid,
        prompt: project.prompt,
        videourl: project.videourl,
        style: project.style,
        aspectratio: project.aspectratio,
        resolution: project.resolution,
        duration: project.duration,
        createdat: project.createdat,
      );
      await docRef.set(projectToSave.toMap());
    } catch (e) {
      throw Exception("Gagal menyimpan data T2Video-Plus: $e");
    }
  }

  // [READ] Mengambil daftar proyek user secara realtime (Stream)
  Stream<List<VideoProjectT2videoPlus>> streamUserProjects(String userId) {
    return _firestore
        .collection(_collectionName)
        .where('userid', isEqualTo: userId)
        // Catatan: orderBy dihapus untuk menghindari kebutuhan Composite Index di Firestore.
        // Pengurutan (sorting) tanggal dilakukan secara lokal di Riverpod Provider.
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return VideoProjectT2videoPlus.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  // [DELETE] Menghapus riwayat berdasarkan ID Dokumen
  Future<void> deleteProject(String projectId) async {
    try {
      await _firestore.collection(_collectionName).doc(projectId).delete();
    } catch (e) {
      throw Exception("Gagal menghapus data T2Video-Plus: $e");
    }
  }
}
// Penutup Blok //