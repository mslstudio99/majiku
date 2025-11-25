import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart'; // Dibutuhkan untuk debugPrint

// Import model Scene dan VideoProject
import '../models/scene.dart';
import '../models/video_project.dart';
// Import model VisualSettings dari provider
import '../providers/visual_settings_provider.dart'; // Pastikan path ini benar

class FirestoreService {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  // Konstruktor dengan instance default
  FirestoreService({FirebaseFirestore? db, FirebaseAuth? auth})
      : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  /// Mengambil stream real-time dari semua proyek video milik pengguna saat ini.
  Stream<List<VideoProject>> getProjectsForUser() {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint("getProjectsForUser: No user logged in.");
      return Stream.value([]); // Kembalikan stream kosong jika user tidak login
    }
    debugPrint("getProjectsForUser: Fetching projects for user ${user.uid}");
    return _db
        .collection('projects')
        .where('userId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      debugPrint("getProjectsForUser: Received ${snapshot.docs.length} project snapshots.");
      // Tambahkan penanganan error parsing per dokumen
      return snapshot.docs.map((doc) {
        try {
          return VideoProject.fromFirestore(doc);
        } catch (e) {
          debugPrint("Error parsing project ${doc.id}: $e");
          // Kembalikan objek default atau null, atau filter keluar
          return null; // Tandai sebagai null jika parsing gagal
        }
      }).whereType<VideoProject>().toList(); // Filter null
    }).handleError((error) {
      debugPrint("Error in getProjectsForUser stream: $error");
      return []; // Kembalikan list kosong jika ada error stream
    });
  }

  // --- Operasi untuk Timeline & Pengaturan ---

  /// Mengambil stream real-time dari SATU dokumen proyek spesifik.
  Stream<VideoProject> getProjectStream(String projectId) {
      debugPrint("getProjectStream: Subscribing to project $projectId");
    return _db
        .collection('projects')
        .doc(projectId)
        .snapshots()
        .map((snapshot) {
          if (!snapshot.exists) {
              debugPrint("getProjectStream: Project $projectId does not exist.");
              throw Exception('Project not found'); // Lemparkan error jika dokumen tidak ada
          }
          try {
           return VideoProject.fromFirestore(snapshot);
          } catch (e) {
           debugPrint("Error parsing project stream for ${snapshot.id}: $e");
           throw Exception('Error parsing project data: $e'); // Lemparkan error parsing
          }
        }).handleError((error) {
          debugPrint("Error in getProjectStream for $projectId: $error");
          // Anda bisa mengembalikan state error atau melempar ulang
          throw error;
        });
  }

    /// Mengambil SATU kali data dokumen proyek spesifik (Future).
    /// Berguna untuk load awal atau operasi yang tidak perlu realtime.
    Future<DocumentSnapshot<Map<String, dynamic>>> getProject(String projectId) async {
     debugPrint("getProject: Fetching single snapshot for project $projectId");
     try {
       final doc = await _db.collection('projects').doc(projectId).get();
       if (!doc.exists) {
         debugPrint("getProject: Project $projectId does not exist.");
         throw Exception('Project not found');
       }
       return doc;
     } catch (e) {
       debugPrint("Error fetching project $projectId: $e");
       rethrow; // Lemparkan error agar pemanggil tahu
     }
    }


  /// Mengambil stream real-time dari SEMUA 'scenes' di bawah satu proyek.
  Stream<List<Scene>> getScenesStream(String projectId) {
    debugPrint("getScenesStream: Subscribing to scenes for project $projectId");
    return _db
        .collection('projects')
        .doc(projectId)
        .collection('scenes')
        .orderBy('segmentIndex')
        .snapshots()
        .map((snapshot) {
      debugPrint("getScenesStream: Received ${snapshot.docs.length} scene snapshots for project $projectId.");
      return snapshot.docs.map((doc) {
       try {
         return Scene.fromFirestore(doc);
       } catch (e) {
         debugPrint("Error parsing scene ${doc.id} for project $projectId: $e");
         return null; // Tandai null jika gagal
       }
      }).whereType<Scene>().toList(); // Filter null
    }).handleError((error) {
      debugPrint("Error in getScenesStream for $projectId: $error");
      return []; // Kembalikan list kosong jika error stream
    });
  }

 // --- Operasi Update & Delete ---
/// Memperbarui field spesifik pada dokumen proyek.
/// Secara cerdas menangani 'renderPacket' untuk melakukan deep merge (Anti-Regresi).
Future<void> updateProject(String projectId, Map<String, dynamic> data) async {
  final user = _auth.currentUser;
  if (user == null) {
    debugPrint(
        "updateProject: No user logged in. Update cancelled for $projectId.");
    throw Exception('User not logged in');
  }

  try {
    // --- KATEGORI_PERBAIKAN_ARSITEKTUR (Deep Merge) ---
    // Logika baru untuk "meratakan" (flatten) nested map.
    // Ini PENTING untuk mencegah 'renderPacket.styleSettings'
    // menimpa 'renderPacket.scenes' dan 'renderPacket.timing'.
    final Map<String, dynamic> flattenedData = {
      // Selalu tambahkan timestamp update
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // Iterasi melalui data yang dikirim oleh client
    for (final entry in data.entries) {
      if (entry.key == 'renderPacket' && entry.value is Map) {
        // --- INI KASUS SPESIAL ---
        // Jika kuncinya 'renderPacket', kita ratakan isinya
        // (Contoh: {'styleSettings': ...} menjadi 'renderPacket.styleSettings': ...)
        final innerMap = entry.value as Map<String, dynamic>;
        for (final innerEntry in innerMap.entries) {
          flattenedData['renderPacket.${innerEntry.key}'] = innerEntry.value;
        }
      } else if (entry.key != 'updatedAt') {
        // Salin semua field lain (seperti 'status', 'finalVideoUrl', dll)
        flattenedData[entry.key] = entry.value;
      }
    }

    debugPrint(
        "updateProject (deep merge): Updating project $projectId with keys: ${flattenedData.keys.join(', ')}");

    // Ganti dari .set(merge: true) ke .update()
    // .update() secara native mendukung dot notation untuk deep merge.
    await _db.collection('projects').doc(projectId).update(flattenedData);
    // --- AKHIR PERBAIKAN ---

    debugPrint("updateProject: Project $projectId updated successfully.");
  } catch (e) {
    debugPrint("❌ Error updating project $projectId: $e");
    rethrow; // Lemparkan error agar UI bisa menangani
  }
}

  /// Menghapus dokumen proyek beserta subkoleksi 'scenes'.
  Future<void> deleteProject(String projectId) async {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint("deleteProject: No user logged in. Delete cancelled for $projectId.");
        throw Exception('User not logged in');
      }
      // Optional: Verifikasi kepemilikan

    try {
      final projectRef = _db.collection('projects').doc(projectId);
      debugPrint("deleteProject: Deleting project $projectId and its scenes...");

      // Hapus semua scene dalam batch (lebih efisien)
      final scenesSnapshot = await projectRef.collection('scenes').get();
      if (scenesSnapshot.docs.isNotEmpty) {
         final batch = _db.batch();
         for (var doc in scenesSnapshot.docs) {
           batch.delete(doc.reference);
         }
         await batch.commit();
         debugPrint("deleteProject: Deleted ${scenesSnapshot.docs.length} scenes for project $projectId.");
      } else {
         debugPrint("deleteProject: No scenes found to delete for project $projectId.");
      }

      // Hapus dokumen project utama
      await projectRef.delete();
      debugPrint("✅ deleteProject: Project $projectId deleted successfully.");
    } catch (e) {
      debugPrint("❌ Error deleting project $projectId: $e");
      rethrow; // Lemparkan error
    }
  }

  /// Mengirim permintaan untuk meregenerasi gambar untuk satu scene.
  Future<void> requestImageRegeneration(String projectId, String sceneId) async {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not logged in');
      // Optional: Verifikasi kepemilikan

    try {
      final sceneRef = _db.collection('projects').doc(projectId).collection('scenes').doc(sceneId);
      debugPrint("requestImageRegeneration: Requesting regeneration for scene $sceneId in project $projectId");
      await sceneRef.update({
        'status': 'PENDING_REGENERATION', // Memicu backend
        'imageUrl': FieldValue.delete(), // Hapus URL lama (atau null) agar UI update
        'errorDetail': FieldValue.delete(), // Hapus error lama
        // 'updatedAt': FieldValue.serverTimestamp(), // Opsional
      });
        debugPrint("requestImageRegeneration: Regeneration requested for scene $sceneId.");
    } catch (e) {
      debugPrint("❌ Failed to request regeneration for scene $sceneId: $e");
      rethrow;
    }
  }

  // --- PEMBARUAN UTAMA: Metode addProject ---
  /// Menambahkan dokumen proyek video baru ke Firestore,
  /// termasuk visualSettings default.
  Future<String?> addProject({
    required String title,
    required String rawScript,
    required String imageStyle,
    required String aspectRatio,
    required String language,
    required String voice,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint("❌ Error: User not logged in. Cannot add project.");
      return null; // Kembalikan null jika user tidak login
    }

    try {
      // 1. Buat instance VisualSettings default menggunakan judul
      final defaultVisualSettings = VisualSettings.defaultSettingsWithTitle(title);
      
      // --- KATEGORI_PERBAIKAN (Anti-Regresi Font Responsif) ---
      // 2. Hitung nilai rasio aspek dari string input
      //    (Kita butuh 'aspectRatio' dari parameter fungsi)
      final double aspectRatioValue = _calculateAspectRatioFromString(aspectRatio);
      
      // 3. Konversi ke Map menggunakan toJson() BARU
      final visualSettingsMap = defaultVisualSettings.toJson(aspectRatioValue);
      // --- AKHIR PERBAIKAN ---

      // 4. Tambahkan dokumen baru ke Firestore
      debugPrint("addProject: Creating new project for user ${user.uid} with title: $title");
      final docRef = await _db.collection('projects').add({
        'userId': user.uid,
        'title': title.isNotEmpty ? title : "Untitled Project", // Fallback judul
        'rawScript': rawScript,
        'imageStyle': imageStyle,
        'aspectRatio': aspectRatio,
        'language': language,
        'voice': voice,
        'status': 'PROCESSING_GENERATION', // Langsung memicu backend
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        
        // --- KATEGORI_FITUR_TTL NO_URUT_01: Tambahkan "Bom Waktu" ---
        // Menambahkan field 'expireAt' yang disetel 24 jam dari sekarang.
        'expireAt': Timestamp.fromDate(DateTime.now().add(const Duration(hours: 24))),
        // --- AKHIR FITUR ---
        
        'visualSettings': visualSettingsMap, // <-- SIMPAN VISUAL SETTINGS DEFAULT
        // Field lain bisa ditambahkan di sini jika perlu nilai awal
        'thumbnailImageUrl': null,
        'finalVideoUrl': null,
        'errorDetail': null,
        // 'identifiedCharacters': [], // Mungkin dibuat oleh backend?
      });

      debugPrint('✅ Project created with ID ${docRef.id} and default visual settings. Backend auto-triggered.');
      return docRef.id; // Kembalikan ID proyek baru

    } catch (e) {
      debugPrint("❌ Error adding project to Firestore: $e");
      // Pertimbangkan untuk melempar error agar UI bisa menangani lebih baik
      // throw Exception('Failed to add project: $e');
      return null; // Kembalikan null jika gagal
    }
  }
    // --- AKHIR PEMBARUAN ---

  // --- KATEGORI_LOGIKA_BARU (Helper Font Responsif) ---
  /// Helper untuk mengonversi string rasio aspek (cth: "16:9") ke nilai double (cth: 1.77).
  /// Diduplikasi dari provider agar file ini mandiri.
  double _calculateAspectRatioFromString(String? ratioString) {
    // Default ke 16:9 jika string null, kosong, atau format salah
    if (ratioString == null || ratioString.isEmpty) {
      return 16 / 9;
    }
    final parts = ratioString.split(':');
    if (parts.length == 2) {
      final double? width = double.tryParse(parts[0]);
      final double? height = double.tryParse(parts[1]);
      // Pastikan kedua bagian adalah angka valid dan height tidak nol
      if (width != null && height != null && height != 0) {
        return width / height;
      }
    }
    // Fallback jika format salah
    debugPrint("Invalid aspectRatio string '$ratioString' in FirestoreService, falling back to 16/9.");
    return 16 / 9;
  }
  // --- AKHIR LOGIKA BARU ---

} // Penutup Class FirestoreService