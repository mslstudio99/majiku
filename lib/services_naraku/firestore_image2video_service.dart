// [NAMA FILE: lib/services_naraku/firestore_image2video_service.dart] //
// [KATEGORI: SERVICE FIRESTORE] //
// [TUJUAN: Menyimpan, membaca, dan menghapus riwayat Image2Video] //

// No ke-1: FIREBASE SERVICE //
//.......................................................//
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models_naraku/video_project_image2video.dart'; // [SESUAIKAN] Menggunakan model Image2Video

class FirestoreImage2VideoService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Nama koleksi utama
  final String _collectionName = 'projects_image2video'; // [SESUAIKAN] Koleksi khusus Image2Video

  // [CREATE] Simpan proyek baru
  Future<void> saveProject(VideoProjectImage2Video project) async {
    try {
      final docRef = _firestore.collection(_collectionName).doc();
      final projectToSave = VideoProjectImage2Video(
        id: docRef.id,
        userId: project.userId,
        imageUrl: project.imageUrl, // [BARU] Menyisipkan imageUrl agar tidak hilang saat disave
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
      throw Exception("Gagal menyimpan data Image2Video: $e");
    }
  }

  // [READ] Mengambil daftar proyek user secara realtime (Stream)
  Stream<List<VideoProjectImage2Video>> streamUserProjects(String userId) {
    return _firestore
        .collection(_collectionName)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return VideoProjectImage2Video.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  // [DELETE] Menghapus riwayat berdasarkan ID Dokumen
  Future<void> deleteProject(String projectId) async {
    try {
      await _firestore.collection(_collectionName).doc(projectId).delete();
    } catch (e) {
      throw Exception("Gagal menghapus data Image2Video: $e");
    }
  }
}
//.......................................................//