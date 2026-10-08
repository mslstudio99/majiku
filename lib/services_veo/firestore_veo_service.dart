//................................................................//
// NAMA FILE: FIRESTORE_VEO_SERVICE.DART                          //
// PATH: LIB/SERVICES_VEO/FIRESTORE_VEO_SERVICE.DART              //
//................................................................//

//No ke-1.........................................................//
// IMPORT & SETUP CLASS                                           //
//................................................................//
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models_veo/scene_veo.dart';
import '../models_veo/video_project_veo.dart';
import '../providers_veo/visual_settings_veo_provider.dart';

class FirestoreVeoService {
  final FirebaseFirestore? _dbInstance;
  final FirebaseAuth? _authInstance;

  FirebaseFirestore get _db => _dbInstance ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => _authInstance ?? FirebaseAuth.instance;

  FirestoreVeoService({FirebaseFirestore? db, FirebaseAuth? auth})
      : _dbInstance = db,
        _authInstance = auth;

//No ke-2.........................................................//
// READ OPERATIONS - GET & STREAM                                 //
//................................................................//
  /// Mengambil stream real-time dari semua proyek VEO milik pengguna saat ini.
  Stream<List<VideoProjectVeo>> getProjectsForUser() {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint("getProjectsForUser (VEO): No user logged in.");
      return Stream.value([]);
    }
    debugPrint("getProjectsForUser (VEO): Fetching projects for user ${user.uid}");
    return _db
        .collection('projects_veo')
        .where('userId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      debugPrint("getProjectsForUser (VEO): Received ${snapshot.docs.length} project snapshots.");
      return snapshot.docs.map((doc) {
        try {
          return VideoProjectVeo.fromFirestore(doc);
        } catch (e) {
          debugPrint("Error parsing project (VEO) ${doc.id}: $e");
          return null;
        }
      }).whereType<VideoProjectVeo>().toList();
    }).handleError((error) {
      debugPrint("Error in getProjectsForUser (VEO) stream: $error");
      return [];
    });
  }

  // --- Operasi untuk Timeline & Pengaturan ---

  /// Mengambil stream real-time dari SATU dokumen proyek VEO spesifik.
  Stream<VideoProjectVeo> getProjectStream(String projectId) {
    debugPrint("getProjectStream (VEO): Subscribing to project $projectId");
    return _db
        .collection('projects_veo')
        .doc(projectId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) {
        debugPrint("getProjectStream (VEO): Project $projectId does not exist.");
        throw Exception('Project not found');
      }
      try {
        return VideoProjectVeo.fromFirestore(snapshot);
      } catch (e) {
        debugPrint("Error parsing project (VEO) stream for ${snapshot.id}: $e");
        throw Exception('Error parsing project data (VEO): $e');
      }
    }).handleError((error) {
      debugPrint("Error in getProjectStream (VEO) for $projectId: $error");
      throw error;
    });
  }

  /// Mengambil SATU kali data dokumen proyek VEO spesifik (Future).
  Future<DocumentSnapshot<Map<String, dynamic>>> getProject(String projectId) async {
    debugPrint("getProject (VEO): Fetching single snapshot for project $projectId");
    try {
      final doc = await _db.collection('projects_veo').doc(projectId).get();
      if (!doc.exists) {
        debugPrint("getProject (VEO): Project $projectId does not exist.");
        throw Exception('Project not found');
      }
      return doc;
    } catch (e) {
      debugPrint("Error fetching project (VEO) $projectId: $e");
      rethrow;
    }
  }

  /// Mengambil stream real-time dari SEMUA 'scenes_veo' di bawah satu proyek VEO.
  Stream<List<SceneVeo>> getScenesStream(String projectId) {
    debugPrint("getScenesStream (VEO): Subscribing to scenes for project $projectId");
    return _db
        .collection('projects_veo')
        .doc(projectId)
        .collection('scenes')
        .orderBy('segmentIndex')
        .snapshots()
        .map((snapshot) {
      debugPrint("getScenesStream (VEO): Received ${snapshot.docs.length} scene snapshots for project $projectId.");
      return snapshot.docs.map((doc) {
        try {
          return SceneVeo.fromFirestore(doc);
        } catch (e) {
          debugPrint("Error parsing scene (VEO) ${doc.id} for project $projectId: $e");
          return null;
        }
      }).whereType<SceneVeo>().toList();
    }).where((list) => list.isNotEmpty); // Opsional: pastikan list tidak kosong jika perlu
  }

//No ke-3.........................................................//
// WRITE OPERATIONS - UPDATE, DELETE, REGENERATE                  //
//................................................................//
  /// Memperbarui field spesifik pada dokumen proyek VEO.
  Future<void> updateProject(String projectId, Map<String, dynamic> data) async {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint(
          "updateProject (VEO): No user logged in. Update cancelled for $projectId.");
      throw Exception('User not logged in');
    }

    try {
      final Map<String, dynamic> flattenedData = {
        'updatedAt': FieldValue.serverTimestamp(),
      };

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

      await _db.collection('projects_veo').doc(projectId).update(flattenedData);

      debugPrint("updateProject (VEO): Project $projectId updated successfully.");
    } catch (e) {
      debugPrint("❌ Error updating project (VEO) $projectId: $e");
      rethrow;
    }
  }

  /// Menghapus dokumen proyek VEO beserta subkoleksi 'scenes'.
  Future<void> deleteProject(String projectId) async {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint("deleteProject (VEO): No user logged in. Delete cancelled for $projectId.");
        throw Exception('User not logged in');
      }

    try {
      final projectRef = _db.collection('projects_veo').doc(projectId);
      debugPrint("deleteProject (VEO): Deleting project $projectId and its scenes...");

      final scenesSnapshot = await projectRef.collection('scenes').get();
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

      await projectRef.delete();
      debugPrint("✅ deleteProject (VEO): Project $projectId deleted successfully.");
    } catch (e) {
      debugPrint("❌ Error deleting project (VEO) $projectId: $e");
      rethrow;
    }
  }

  /// Mengirim permintaan untuk meregenerasi video untuk satu scene VEO.
  Future<void> requestVideoRegeneration(String projectId, String sceneId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    try {
      final sceneRef = _db.collection('projects_veo').doc(projectId).collection('scenes').doc(sceneId);
      debugPrint("requestVideoRegeneration (VEO): Requesting regeneration for scene $sceneId in project $projectId");

      await sceneRef.update({
        'status': 'PENDING_REFINEMENT',
        'videoUrl': FieldValue.delete(), // Hapus URL video lama
        'errorDetail': FieldValue.delete(), // Hapus error lama
      });
        debugPrint("requestVideoRegeneration (VEO): Regeneration requested for scene $sceneId.");
    } catch (e) {
      debugPrint("❌ Failed to request regeneration (VEO) for scene $sceneId: $e");
      rethrow;
    }
  }

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

      if (newPrompt.trim().isEmpty) {
        debugPrint("❌ Error: Cannot update with an empty prompt.");
        throw Exception("Prompt cannot be empty.");
      }

      await sceneRef.update({
        'refinedPrompt': newPrompt,
        'status': 'PENDING_REFINEMENT',
        'errorDetail': FieldValue.delete(),
        'retryCount': 0,
        'videoUrl': FieldValue.delete(),
      });
      
      debugPrint("updateScenePromptAndRegenerate (VEO): Success.");
    } catch (e) {
      debugPrint("❌ Failed to update prompt and regenerate (VEO): $e");
      rethrow;
    }
  }

//No ke-4.........................................................//
// CREATE OPERATION - ADD PROJECT                                 //
//................................................................//
  Future<String?> addProject({
    required String title,
    required String rawScript,
    required String imageStyle,
    required String aspectRatio,
    required String resolution, // Menerima parameter resolusi
    String quality = 'Standard', // Menerima parameter quality (Standard / High)
    bool showTitle = true, // [BARU] Menerima parameter status ON/OFF Title Overlay
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint("❌ Error: User not logged in. Cannot add project (VEO).");
      return null;
    }

    try {
      // 1. Buat instance VisualSettings default menggunakan judul
      final defaultVisualSettings = VisualSettingsVeo.defaultSettingsWithTitle(title);

      // 2. Hitung nilai rasio aspek
      final double aspectRatioValue = _calculateAspectRatioFromString(aspectRatio);

      // 3. Konversi ke Map
      final visualSettingsMap = defaultVisualSettings.toJson(aspectRatioValue);

      // [SINKRONISASI DUAL-LAYER]: Masukkan status showTitle ke dalam visualSettingsMap
      visualSettingsMap['showTitle'] = showTitle;
      if (visualSettingsMap['titleSettings'] is Map) {
        (visualSettingsMap['titleSettings'] as Map<String, dynamic>)['show'] = showTitle;
      }

      // 4. Tambahkan dokumen baru ke Firestore
      debugPrint("addProject (VEO): Creating new project for user ${user.uid} with title: $title, Quality: $quality, showTitle: $showTitle");
      
      final docRef = await _db.collection('projects_veo').add({
        'userId': user.uid,
        'title': title.isNotEmpty ? title : "Untitled Veo Project",
        'rawScript': rawScript,
        'imageStyle': imageStyle,
        'aspectRatio': aspectRatio,
        'resolution': resolution, 
        'quality': quality, // Menyimpan quality ke Firestore
        'showTitle': showTitle, // [BARU] Menyimpan status ON/OFF Title Overlay
        
        'status': 'PROCESSING_SCENE', // Langsung memicu backend (VEO)
        
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),

        'expireAt': Timestamp.fromDate(DateTime.now().add(const Duration(hours: 24))),

        'visualSettings': visualSettingsMap,
        'thumbnailImageUrl': null,
        'finalVideoUrl': null,
        'errorDetail': null,
      });

      debugPrint('✅ Project (VEO) created with ID ${docRef.id}, resolution $resolution, quality $quality, showTitle: $showTitle. Backend auto-triggered.');
      return docRef.id;

    } catch (e) {
      debugPrint("❌ Error adding project (VEO) to Firestore: $e");
      rethrow;
    }
  }

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
    debugPrint("Invalid aspectRatio string '$ratioString' in FirestoreVeoService, falling back to 16/9.");
    return 16 / 9;
  }
}
//................................................................//