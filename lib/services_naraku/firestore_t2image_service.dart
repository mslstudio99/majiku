// [NAMA FILE: lib/services_naraku/firestore_t2image_service.dart] //
// [KATEGORI: SERVICE FIRESTORE] //
// [TUJUAN: Menyimpan, membaca, dan menghapus riwayat T2Image] //

// No ke-1: FIREBASE SERVICE //
//.......................................................//
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models_naraku/image_project_t2image.dart'; // DIUBAH: Menggunakan model T2Image

class FirestoreT2ImageService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Nama koleksi utama
  final String _collectionName = 'projects_t2image'; // DIUBAH: Nama koleksi baru

  // [CREATE] Simpan proyek baru
  Future<String> saveProject(ImageProjectT2Image project) async {
    try {
      final docRef = _firestore.collection(_collectionName).doc();
      final projectToSave = ImageProjectT2Image(
        id: docRef.id, // ID diambil dari referensi dokumen baru
        userId: project.userId,
        prompt: project.prompt,
        imageUrl: project.imageUrl,
        style: project.style,
        aspectRatio: project.aspectRatio,
        createdAt: project.createdAt,
      );
      await docRef.set(projectToSave.toMap());
      return docRef.id; // Mengembalikan ID dokumen yang baru dibuat
    } catch (e) {
      throw Exception("Gagal menyimpan data T2Image: $e");
    }
  }

  // [READ] Mengambil daftar proyek user secara realtime (Stream)
  Stream<List<ImageProjectT2Image>> streamUserProjects(String userId) {
    return _firestore
        .collection(_collectionName)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return ImageProjectT2Image.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  // [DELETE] Menghapus riwayat berdasarkan ID Dokumen
  Future<void> deleteProject(String projectId) async {
    try {
      await _firestore.collection(_collectionName).doc(projectId).delete();
    } catch (e) {
      throw Exception("Gagal menghapus data T2Image: $e");
    }
  }
}
//.......................................................//