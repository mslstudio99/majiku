// --- KATEGORI_ISOLASI_VEO: Path file: services_veo/firestore_veo_service.dart ---
// --- KATEGORI_PEMBERSIHAN: Karakter non-ASCII (U+00A0) telah dihapus ---

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart'; // Dibutuhkan untuk debugPrint

// --- KATEGORI_ISOLASI_VEO: Impor diubah ke model _veo ---
import '../models_veo/scene_veo.dart';
import '../models_veo/video_project_veo.dart';
// Import model VisualSettings dari provider
import '../providers_veo/visual_settings_veo_provider.dart'; // <-- Path diubah
// --- AKHIR MODIFIKASI ---

// --- KATEGORI_ISOLASI_VEO: Nama Class diubah ---
class FirestoreVeoService {
// --- AKHIR MODIFIKASI ---

  // --- KATEGORI_PERBAIKAN_ERROR_KONSTRUKTOR (Anti-Regresi) ---
  // Hapus 'final' dan instance default dari konstruktor.
  // Ini adalah instance yang diinjeksi (jika ada, untuk testing)
  final FirebaseFirestore? _dbInstance;
  final FirebaseAuth? _authInstance;

  // Terapkan Lazy Loading Getters.
  // Ini memastikan .instance HANYA dipanggil saat pertama kali dibutuhkan,
  // BUKAN saat konstruktor dijalankan.
  FirebaseFirestore get _db => _dbInstance ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => _authInstance ?? FirebaseAuth.instance;

  // Konstruktor sekarang hanya menyimpan instance yang diinjeksi (jika ada)
  // dan tidak melakukan I/O.
  FirestoreVeoService({FirebaseFirestore? db, FirebaseAuth? auth})
      : _dbInstance = db,
        _authInstance = auth;
  // --- AKHIR PERBAIKAN ---


  /// Mengambil stream real-time dari semua proyek VEO milik pengguna saat ini.
  // --- KATEGORI_ISOLASI_VEO: Tipe data diubah ---
  Stream<List<VideoProjectVeo>> getProjectsForUser() {
  // --- AKHIR MODIFIKASI ---
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint("getProjectsForUser (VEO): No user logged in.");
      return Stream.value([]); // Kembalikan stream kosong jika user tidak login
    }
    debugPrint("getProjectsForUser (VEO): Fetching projects for user ${user.uid}");
    return _db
        // --- KATEGORI_ISOLASI_VEO: Koleksi diubah ke 'projects_veo' ---
        .collection('projects_veo')
        // --- AKHIR MODIFIKASI ---
        .where('userId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      debugPrint("getProjectsForUser (VEO): Received ${snapshot.docs.length} project snapshots.");
      // Tambahkan penanganan error parsing per dokumen
      return snapshot.docs.map((doc) {
        try {
          // --- KATEGORI_ISOLASI_VEO: Tipe data diubah ---
          return VideoProjectVeo.fromFirestore(doc);
          // --- AKHIR MODIFIKASI ---
        } catch (e) {
          debugPrint("Error parsing project (VEO) ${doc.id}: $e");
          // Kembalikan objek default atau null, atau filter keluar
          return null; // Tandai sebagai null jika parsing gagal
        }
        // --- KATEGORI_ISOLASI_VEO: Tipe data diubah ---
      }).whereType<VideoProjectVeo>().toList(); // Filter null
      // --- AKHIR MODIFIKASI ---
    }).handleError((error) {
      debugPrint("Error in getProjectsForUser (VEO) stream: $error");
      return []; // Kembalikan list kosong jika ada error stream
    });
  }

  // --- Operasi untuk Timeline & Pengaturan ---

  /// Mengambil stream real-time dari SATU dokumen proyek VEO spesifik.
  // --- KATEGORI_ISOLASI_VEO: Tipe data diubah ---
  Stream<VideoProjectVeo> getProjectStream(String projectId) {
  // --- AKHIR MODIFIKASI ---
    debugPrint("getProjectStream (VEO): Subscribing to project $projectId");
    return _db
        // --- KATEGORI_ISOLASI_VEO: Koleksi diubah ke 'projects_veo' ---
        .collection('projects_veo')
        // --- AKHIR MODIFIKASI ---
        .doc(projectId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) {
        debugPrint("getProjectStream (VEO): Project $projectId does not exist.");
        throw Exception('Project not found'); // Lemparkan error jika dokumen tidak ada
      }
      try {
        // --- KATEGORI_ISOLASI_VEO: Tipe data diubah ---
        return VideoProjectVeo.fromFirestore(snapshot);
        // --- AKHIR MODIFIKASI ---
      } catch (e) {
        debugPrint("Error parsing project (VEO) stream for ${snapshot.id}: $e");
        throw Exception('Error parsing project data (VEO): $e'); // Lemparkan error parsing
      }
    }).handleError((error) {
      debugPrint("Error in getProjectStream (VEO) for $projectId: $error");
      // Anda bisa mengembalikan state error atau melempar ulang
      throw error;
    });
  }

  /// Mengambil SATU kali data dokumen proyek VEO spesifik (Future).
  /// Berguna untuk load awal atau operasi yang tidak perlu realtime.
  Future<DocumentSnapshot<Map<String, dynamic>>> getProject(String projectId) async {
    debugPrint("getProject (VEO): Fetching single snapshot for project $projectId");
    try {
      // --- KATEGORI_ISOLASI_VEO: Koleksi diubah ke 'projects_veo' ---
      final doc = await _db.collection('projects_veo').doc(projectId).get();
      // --- AKHIR MODIFIKASI ---
      if (!doc.exists) {
        debugPrint("getProject (VEO): Project $projectId does not exist.");
        throw Exception('Project not found');
      }
      return doc;
    } catch (e) {
      debugPrint("Error fetching project (VEO) $projectId: $e");
      rethrow; // Lemparkan error agar pemanggil tahu
    }
  }


  /// Mengambil stream real-time dari SEMUA 'scenes_veo' di bawah satu proyek VEO.
  // --- KATEGORI_ISOLASI_VEO: Tipe data diubah ---
  Stream<List<SceneVeo>> getScenesStream(String projectId) {
  // --- AKHIR MODIFIKASI ---
    debugPrint("getScenesStream (VEO): Subscribing to scenes for project $projectId");
    return _db
        // --- KATEGORI_ISOLASI_VEO: Koleksi diubah ke 'projects_veo' ---
        .collection('projects_veo')
        // --- AKHIR MODIFIKASI ---
        .doc(projectId)
        // --- KATEGORI_ISOLASI_VEO: Sub-Koleksi diubah ke 'scenes_veo' ---
        .collection('scenes') // <-- [REFAKTOR v1.7 SINKRONISASI] Backend menggunakan 'scenes'
        // --- AKHIR MODIFIKASI ---
        .orderBy('segmentIndex')
        .snapshots()
        .map((snapshot) {
      debugPrint("getScenesStream (VEO): Received ${snapshot.docs.length} scene snapshots for project $projectId.");
      return snapshot.docs.map((doc) {
        try {
          // --- KATEGORI_ISOLASI_VEO: Tipe data diubah ---
          return SceneVeo.fromFirestore(doc);
          // --- AKHIR MODIFIKASI ---
        } catch (e) {
          debugPrint("Error parsing scene (VEO) ${doc.id} for project $projectId: $e");
          return null; // Tandai null jika gagal
        }
        // --- KATEGORI_ISOLASI_VEO: Tipe data diubah ---
      }).whereType<SceneVeo>().toList(); // Filter null
      // --- AKHIR MODIFIKASI ---
    }).handleError((error) {
      debugPrint("Error in getScenesStream (VEO) for $projectId: $error");
      return []; // Kembalikan list kosong jika error stream
    });
  }

  // --- Operasi Update & Delete ---
  /// Memperbarui field spesifik pada dokumen proyek VEO.
  /// Secara cerdas menangani 'renderPacket' untuk melakukan deep merge (Anti-Regresi).
  Future<void> updateProject(String projectId, Map<String, dynamic> data) async {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint(
          "updateProject (VEO): No user logged in. Update cancelled for $projectId.");
      throw Exception('User not logged in');
    }

    try {
      // --- KATEGORI_PERBAIKAN_ARSITEKTUR (Deep Merge) ---
      // Logika (Anti-Regresi) ini dipertahankan
      final Map<String, dynamic> flattenedData = {
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Iterasi melalui data yang dikirim oleh client
      for (final entry in data.entries) {
        if (entry.key == 'renderPacket' && entry.value is Map) {
          final innerMap = entry.value as Map<String, dynamic>;
          for (final innerEntry in innerMap.entries) {
            flattenedData['renderPacket.${innerEntry.key}'] = innerEntry.value;
          }
        } else if (entry.key != 'updatedAt') {
          flattenedData[entry.key] = entry.value;
        }
      }

      debugPrint(
          "updateProject (VEO deep merge): Updating project $projectId with keys: ${flattenedData.keys.join(', ')}");

      // --- KATEGORI_ISOLASI_VEO: Koleksi diubah ke 'projects_veo' ---
      await _db.collection('projects_veo').doc(projectId).update(flattenedData);
      // --- AKHIR MODIFIKASI ---

      debugPrint("updateProject (VEO): Project $projectId updated successfully.");
    } catch (e) {
      debugPrint("❌ Error updating project (VEO) $projectId: $e");
      rethrow; // Lemparkan error agar UI bisa menangani
    }
  }

  /// Menghapus dokumen proyek VEO beserta subkoleksi 'scenes'.
  Future<void> deleteProject(String projectId) async {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint("deleteProject (VEO): No user logged in. Delete cancelled for $projectId.");
        throw Exception('User not logged in');
      }
      // Optional: Verifikasi kepemilikan

    try {
      // --- KATEGORI_ISOLASI_VEO: Koleksi diubah ke 'projects_veo' ---
      final projectRef = _db.collection('projects_veo').doc(projectId);
      // --- AKHIR MODIFIKASI ---
      debugPrint("deleteProject (VEO): Deleting project $projectId and its scenes...");

      // --- KATEGORI_ISOLASI_VEO: Sub-Koleksi diubah ke 'scenes' ---
      final scenesSnapshot = await projectRef.collection('scenes').get(); // <-- [REFAKTOR v1.7 SINKRONISASI]
      // --- AKHIR MODIFIKASI ---
      if (scenesSnapshot.docs.isNotEmpty) {
          final batch = _db.batch();
          for (var doc in scenesSnapshot.docs) {
            batch.delete(doc.reference);
          }
          await batch.commit();
          debugPrint("deleteProject (VEO): Deleted ${scenesSnapshot.docs.length} scenes for project $projectId.");
      } else {
          debugPrint("deleteProject (VEO): No scenes found to delete for project $projectId.");
      }

      // Hapus dokumen project utama
      await projectRef.delete();
      debugPrint("✅ deleteProject (VEO): Project $projectId deleted successfully.");
    } catch (e) {
      debugPrint("❌ Error deleting project (VEO) $projectId: $e");
      rethrow; // Lemparkan error
    }
  }

  /// Mengirim permintaan untuk meregenerasi (placeholder) untuk satu scene VEO.
  // --- KATEGORI_PENAMAAN_VEO (NO_URUT_03): Ganti nama requestImageRegeneration -> requestVideoRegeneration ---
  Future<void> requestVideoRegeneration(String projectId, String sceneId) async {
  // --- AKHIR PENAMAAN VEO ---
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');
    // Optional: Verifikasi kepemilikan

    try {
      // --- KATEGORI_ISOLASI_VEO: Koleksi & Sub-Koleksi diubah ---
      final sceneRef = _db.collection('projects_veo').doc(projectId).collection('scenes').doc(sceneId); // <-- [REFAKTOR v1.7 SINKRONISASI]
      // --- AKHIR MODIFIKASI ---
      debugPrint("requestVideoRegeneration (VEO): Requesting regeneration for scene $sceneId in project $projectId");

      // [REFAKTOR v1.7] Status pemicu diubah ke PENDING_REFINEMENT
      await sceneRef.update({
        'status': 'PENDING_REFINEMENT', // Memicu backend (VEO) v1.7
      // --- KATEGORI_ISOLASI_VEO: Logika disesuaikan (mungkin videoUrl?) ---
        'videoUrl': FieldValue.delete(), // Hapus URL video lama
        // 'imageUrl': FieldValue.delete(), // (Field ini mungkin tidak ada di VEO, hapus jika tidak relevan)
      // --- AKHIR MODIFIKASI ---
        'errorDetail': FieldValue.delete(), // Hapus error lama
      });
        debugPrint("requestVideoRegeneration (VEO): Regeneration requested for scene $sceneId.");
    } catch (e) {
      debugPrint("❌ Failed to request regeneration (VEO) for scene $sceneId: $e");
      rethrow;
    }
  }

  // [PATCH KATEGORI_EDIT_PROMPT - METODE BARU]
  /// Memperbarui 'refinedPrompt' dengan input manual user,
  /// lalu memicu regenerasi standar (PENDING_REFINEMENT).
  Future<void> updateScenePromptAndRegenerate(
      String projectId, String sceneId, String newPrompt) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    try {
      final sceneRef = _db
          .collection('projects_veo')
          .doc(projectId)
          .collection('scenes')
          .doc(sceneId);

      debugPrint(
          "updateScenePromptAndRegenerate (VEO): Updating prompt for scene $sceneId");

      // Periksa apakah prompt baru tidak kosong
      if (newPrompt.trim().isEmpty) {
        debugPrint("❌ Error: Cannot update with an empty prompt.");
        throw Exception("Prompt cannot be empty.");
      }

      await sceneRef.update({
        'refinedPrompt': newPrompt, // 1. Simpan prompt editan user
        'status': 'PENDING_REFINEMENT', // 2. Picu worker standar (regenerateSceneVideoAsset_veo)
        'errorDetail': FieldValue.delete(), // 3. Hapus error lama
        'retryCount': 0, // 4. Reset retry count agar dianggap job baru
        'videoUrl': FieldValue.delete(), // 5. Hapus video lama
      });
      
      debugPrint("updateScenePromptAndRegenerate (VEO): Success.");
    } catch (e) {
      debugPrint("❌ Failed to update prompt and regenerate (VEO): $e");
      rethrow;
    }
  }
  // [AKHIR PATCH]

  // --- PEMBARUAN UTAMA: Metode addProject (VEO) ---
  /// Menambahkan dokumen proyek VEO baru ke Firestore,
  /// termasuk visualSettings default.
  Future<String?> addProject({
    required String title,
    required String rawScript,
    required String imageStyle, // (Mungkin 'veo_style'?)
    required String aspectRatio,
    required String language,
    // --- KATEGORI_SINKRONISASI (NO_URUT_01): Hapus parameter voice ---
    // required String voice, // <-- DIHAPUS
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint("❌ Error: User not logged in. Cannot add project (VEO).");
      return null; // Kembalikan null jika user tidak login
    }

    try {
      // --- KATEGORI_ISOLASI_VEO: Tipe data diubah ---
      // 1. Buat instance VisualSettings default menggunakan judul
      final defaultVisualSettings = VisualSettingsVeo.defaultSettingsWithTitle(title);
      // --- AKHIR MODIFIKASI ---

      // 2. Hitung nilai rasio aspek (Logika ini dipertahankan)
      final double aspectRatioValue = _calculateAspectRatioFromString(aspectRatio);

      // 3. Konversi ke Map menggunakan toJson() BARU
      final visualSettingsMap = defaultVisualSettings.toJson(aspectRatioValue);

      // 4. Tambahkan dokumen baru ke Firestore
      debugPrint("addProject (VEO): Creating new project for user ${user.uid} with title: $title");
      // --- KATEGORI_ISOLASI_VEO: Koleksi diubah ke 'projects_veo' ---
      final docRef = await _db.collection('projects_veo').add({
      // --- AKHIR MODIFIKASI ---
        'userId': user.uid,
        'title': title.isNotEmpty ? title : "Untitled Veo Project", // Fallback judul
        'rawScript': rawScript,
        'imageStyle': imageStyle, // (Akan berisi style Veo)
        'aspectRatio': aspectRatio,
        'language': language, // <-- DIPERTAHANKAN
        // --- KATEGORI_SINKRONISASI (NO_URUT_02): Hapus field voice dari payload ---
        // 'voice': voice, // <-- DIHAPUS
        // --- AKHIR SINKRONISASI ---
        
        // [REFAKTOR v1.7 KRITIS] Status pemicu diubah ke PROCESSING_SCENE
        'status': 'PROCESSING_SCENE', // Langsung memicu backend (VEO)
        
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),

        // --- KATEGORI_FITUR_TTL (Dipertahankan) ---
        'expireAt': Timestamp.fromDate(DateTime.now().add(const Duration(hours: 24))),
        // --- AKHIR FITUR ---

        'visualSettings': visualSettingsMap, // <-- SIMPAN VISUAL SETTINGS DEFAULT
        'thumbnailImageUrl': null,
        'finalVideoUrl': null,
        'errorDetail': null,
      });

      debugPrint('✅ Project (VEO) created with ID ${docRef.id} and default visual settings. Backend auto-triggered.');
      return docRef.id; // Kembalikan ID proyek baru

    } catch (e) {
      debugPrint("❌ Error adding project (VEO) to Firestore: $e");
      // --- KATEGORI_PERBAIKAN_ERROR_KONSTRUKTOR ---
      // Lemparkan error agar UI bisa menampilkannya, alih-alih mengembalikan null
      // Ini akan ditangkap oleh input_script_veo_screen.dart
      rethrow;
      // --- AKHIR PERBAIKAN ---
    }
  }
  // --- AKHIR PEMBARUAN ---

  // --- KATEGORI_LOGIKA_BARU (Helper Font Responsif) ---
  // Logika ini dipertahankan karena bersifat universal
  double _calculateAspectRatioFromString(String? ratioString) {
    if (ratioString == null || ratioString.isEmpty) {
      return 16 / 9;
    }
    final parts = ratioString.split(':');
    if (parts.length == 2) {
      final double? width = double.tryParse(parts[0]);
      final double? height = double.tryParse(parts[1]);
      if (width != null && height != null && height != 0) {
        return width / height;
      }
    }
    // --- KATEGORI_ISOLASI_VEO: Log diubah ---
    debugPrint("Invalid aspectRatio string '$ratioString' in FirestoreVeoService, falling back to 16/9.");
    // --- AKHIR MODIFIKASI ---
    return 16 / 9;
  }
  // --- AKHIR LOGIKA BARU ---

} // Penutup Class FirestoreVeoService