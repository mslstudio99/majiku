// [NAMA FILE: lib/services_naraku/firestore_t2video_service.dart] //
// [KATEGORI: SERVICE FIRESTORE] //
// [TUJUAN: Menyimpan, membaca, dan menghapus riwayat T2Video] //

// No ke-1: FIREBASE SERVICE //
//.......................................................//
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models_naraku/video_project_t2video.dart';

class FirestoreT2VideoService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Nama koleksi utama
  final String _collectionName = 'projects_t2video';

  // [CREATE] Simpan proyek baru
  Future<void> saveProject(VideoProjectT2Video project) async {
    try {
      final docRef = _firestore.collection(_collectionName).doc();
      final projectToSave = VideoProjectT2Video(
        id: docRef.id,
        userId: project.userId,
        prompt: project.prompt,
        videoUrl: project.videoUrl,
        style: project.style,
        aspectRatio: project.aspectRatio,
        resolution: project.resolution,
        duration: project.duration,
        createdAt: project.createdAt,
      );
      await docRef.set(projectToSave.toMap());
    } catch (e) {
      throw Exception("Gagal menyimpan data T2Video: $e");
    }
  }

  // [READ] Mengambil daftar proyek user secara realtime (Stream)
  Stream<List<VideoProjectT2Video>> streamUserProjects(String userId) {
    return _firestore
        .collection(_collectionName)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return VideoProjectT2Video.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  // [DELETE] Menghapus riwayat berdasarkan ID Dokumen
  Future<void> deleteProject(String projectId) async {
    try {
      await _firestore.collection(_collectionName).doc(projectId).delete();
    } catch (e) {
      throw Exception("Gagal menghapus data T2Video: $e");
    }
  }
}
//.......................................................//