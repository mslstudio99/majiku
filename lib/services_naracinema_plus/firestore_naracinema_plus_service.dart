//================================================================//
// NAMA FILE: FIRESTORE_NARACINEMA_PLUS_SERVICE.DART              //
// DIREKTORI: LIB/SERVICES_NARACINEMA_PLUS/                       //
// DESKRIPSI: LAYANAN UTAMA UNTUK INTERAKSI FIRESTORE NARACINEMA  //
//================================================================//

// No ke-1: IMPORT DEPENDENSI & SETUP AWAL                        //
//----------------------------------------------------------------//
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models_naracinema_plus/scene_naracinema_plus.dart';
import '../models_naracinema_plus/video_project_naracinema_plus.dart';
import '../providers_naracinema_plus/visual_settings_naracinema_plus_provider.dart';
//----------------------------------------------------------------//

// No ke-2: SERVICE CLASS DAN OPERASI READ                        //
//----------------------------------------------------------------//
class FirestoreNaracinemaPlusService {
  final FirebaseFirestore? _dbInstance;
  final FirebaseAuth? _authInstance;

  FirebaseFirestore get _db => _dbInstance ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => _authInstance ?? FirebaseAuth.instance;

  FirestoreNaracinemaPlusService({FirebaseFirestore? db, FirebaseAuth? auth})
      : _dbInstance = db,
        _authInstance = auth;

  Stream<List<VideoProjectNaracinemaPlus>> getProjectsForUser() {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint("getProjectsForUser (NARACINEMA PLUS): No user logged in.");
      return Stream.value([]);
    }
    debugPrint("getProjectsForUser (NARACINEMA PLUS): Fetching projects for user ${user.uid}");
    return _db
        .collection('projects_naracinema_plus')
        .where('userId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      debugPrint("getProjectsForUser (NARACINEMA PLUS): Received ${snapshot.docs.length} project snapshots.");
      return snapshot.docs.map((doc) {
        try {
          return VideoProjectNaracinemaPlus.fromFirestore(doc);
        } catch (e) {
          debugPrint("Error parsing project (NARACINEMA PLUS) ${doc.id}: $e");
          return null;
        }
      }).whereType<VideoProjectNaracinemaPlus>().toList();
    }).handleError((error) {
      debugPrint("Error in getProjectsForUser (NARACINEMA PLUS) stream: $error");
      throw error; // [PERBAIKAN MUTLAK]: Melempar error agar StreamBuilder menangkapnya & memunculkan link index
    });
  }

  Stream<VideoProjectNaracinemaPlus> getProjectStream(String projectId) {
    debugPrint("getProjectStream (NARACINEMA PLUS): Subscribing to project $projectId");
    return _db
        .collection('projects_naracinema_plus')
        .doc(projectId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) {
        debugPrint("getProjectStream (NARACINEMA PLUS): Project $projectId does not exist.");
        throw Exception('Project not found');
      }
      try {
        return VideoProjectNaracinemaPlus.fromFirestore(snapshot);
      } catch (e) {
        debugPrint("Error parsing project (NARACINEMA PLUS) stream for ${snapshot.id}: $e");
        throw Exception('Error parsing project data (NARACINEMA PLUS): $e');
      }
    }).handleError((error) {
      debugPrint("Error in getProjectStream (NARACINEMA PLUS) for $projectId: $error");
      throw error;
    });
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getProject(String projectId) async {
    debugPrint("getProject (NARACINEMA PLUS): Fetching single snapshot for project $projectId");
    try {
      final doc = await _db.collection('projects_naracinema_plus').doc(projectId).get();
      if (!doc.exists) {
        debugPrint("getProject (NARACINEMA PLUS): Project $projectId does not exist.");
        throw Exception('Project not found');
      }
      return doc;
    } catch (e) {
      debugPrint("Error fetching project (NARACINEMA PLUS) $projectId: $e");
      rethrow;
    }
  }

  Stream<List<SceneNaracinemaPlus>> getScenesStream(String projectId) {
    debugPrint("getScenesStream (NARACINEMA PLUS): Subscribing to scenes for project $projectId");
    return _db
        .collection('projects_naracinema_plus')
        .doc(projectId)
        .collection('scenes')
        .orderBy('segmentIndex')
        .snapshots()
        .map((snapshot) {
      debugPrint("getScenesStream (NARACINEMA PLUS): Received ${snapshot.docs.length} scene snapshots for project $projectId.");
      return snapshot.docs.map((doc) {
        try {
          return SceneNaracinemaPlus.fromFirestore(doc);
        } catch (e) {
          debugPrint("Error parsing scene (NARACINEMA PLUS) ${doc.id} for project $projectId: $e");
          return null;
        }
      }).whereType<SceneNaracinemaPlus>().toList();
    }).where((list) => list.isNotEmpty); 
  }
//----------------------------------------------------------------//

// No ke-3: OPERASI UPDATE, REGENERATE, DAN DELETE                //
//----------------------------------------------------------------//
  Future<void> updateProject(String projectId, Map<String, dynamic> data) async {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint(
          "updateProject (NARACINEMA PLUS): No user logged in. Update cancelled for $projectId.");
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
          "updateProject (NARACINEMA PLUS deep merge): Updating project $projectId with keys: ${flattenedData.keys.join(', ')}");

      await _db.collection('projects_naracinema_plus').doc(projectId).update(flattenedData);

      debugPrint("updateProject (NARACINEMA PLUS): Project $projectId updated successfully.");
    } catch (e) {
      debugPrint("❌ Error updating project (NARACINEMA PLUS) $projectId: $e");
      rethrow;
    }
  }

  Future<void> deleteProject(String projectId) async {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint("deleteProject (NARACINEMA PLUS): No user logged in. Delete cancelled for $projectId.");
        throw Exception('User not logged in');
      }

    try {
      final projectRef = _db.collection('projects_naracinema_plus').doc(projectId);
      debugPrint("deleteProject (NARACINEMA PLUS): Deleting project $projectId and its scenes...");

      final scenesSnapshot = await projectRef.collection('scenes').get();
      if (scenesSnapshot.docs.isNotEmpty) {
          final batch = _db.batch();
          for (var doc in scenesSnapshot.docs) {
            batch.delete(doc.reference);
          }
          await batch.commit();
          debugPrint("deleteProject (NARACINEMA PLUS): Deleted ${scenesSnapshot.docs.length} scenes for project $projectId.");
      } else {
          debugPrint("deleteProject (NARACINEMA PLUS): No scenes found to delete for project $projectId.");
      }

      await projectRef.delete();
      debugPrint("✅ deleteProject (NARACINEMA PLUS): Project $projectId deleted successfully.");
    } catch (e) {
      debugPrint("❌ Error deleting project (NARACINEMA PLUS) $projectId: $e");
      rethrow;
    }
  }

  // [PERBAIKAN]: Menyamakan nama method dengan pemanggilan di Screen UI (requestVideoRegeneration)
  Future<void> requestVideoRegeneration(String projectId, String sceneId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    try {
      final sceneRef = _db.collection('projects_naracinema_plus').doc(projectId).collection('scenes').doc(sceneId);
      debugPrint("requestVideoRegeneration (NARACINEMA PLUS): Requesting regeneration for scene $sceneId in project $projectId");

      await sceneRef.update({
        'status': 'PENDING_REFINEMENT',
        'imageUrl': FieldValue.delete(), // Menghapus field imageUrl (jika masih ada)
        'videoUrl': FieldValue.delete(), // Menghapus video AI lama
        'ttsAudioUrl': FieldValue.delete(), // [PERBAIKAN MUTLAK]: Membersihkan memori Audio TTS Lama
        'errorDetail': FieldValue.delete(), 
      });
        debugPrint("requestVideoRegeneration (NARACINEMA PLUS): Regeneration requested for scene $sceneId.");
    } catch (e) {
      debugPrint("❌ Failed to request regeneration (NARACINEMA PLUS) for scene $sceneId: $e");
      rethrow;
    }
  }

  Future<void> updateScenePromptAndRegenerate(
      String projectId, String sceneId, String newPrompt) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    try {
      final sceneRef = _db
          .collection('projects_naracinema_plus')
          .doc(projectId)
          .collection('scenes')
          .doc(sceneId);

      debugPrint(
          "updateScenePromptAndRegenerate (NARACINEMA PLUS): Updating prompt for scene $sceneId");

      if (newPrompt.trim().isEmpty) {
        debugPrint("❌ Error: Cannot update with an empty prompt.");
        throw Exception("Prompt cannot be empty.");
      }

      await sceneRef.update({
        'refinedPrompt': newPrompt,
        'status': 'PENDING_REFINEMENT',
        'errorDetail': FieldValue.delete(),
        'retryCount': 0,
        'imageUrl': FieldValue.delete(), // Hapus data lama sebelum generate ulang
        'videoUrl': FieldValue.delete(), // Hapus video AI lama
        'ttsAudioUrl': FieldValue.delete(), // [PERBAIKAN MUTLAK]: Membersihkan memori Audio TTS Lama
      });
      
      debugPrint("updateScenePromptAndRegenerate (NARACINEMA PLUS): Success.");
    } catch (e) {
      debugPrint("❌ Failed to update prompt and regenerate (NARACINEMA PLUS): $e");
      rethrow;
    }
  }
//----------------------------------------------------------------//

// No ke-4: OPERASI CREATE DAN HELPER METHOD                      //
//----------------------------------------------------------------//
  Future<String?> addProject({
    required String title,
    required String rawScript,
    required String imageStyle,
    required String aspectRatio,
    required String language,
    required String voice,         
    required bool showSubtitles,   
    required String resolution,    
    required String costLevel,     // [PERBAIKAN FITUR BARU]: Menangkap Cost Level
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint("❌ Error: User not logged in. Cannot add project (NARACINEMA PLUS).");
      return null;
    }

    try {
      // [PERBAIKAN MUTLAK]: Buat referensi dokumen di awal untuk mendapatkan projectId
      // sebelum menyusun visualSettingsMap agar menghindari error kompilasi.
      final docRef = _db.collection('projects_naracinema_plus').doc();
      final String projectId = docRef.id;

      final defaultVisualSettings = VisualSettingsNaracinemaPlus.defaultSettingsWithTitle(title);
      final double aspectRatioValue = _calculateAspectRatioFromString(aspectRatio);
      
      // Sekarang variabel projectId sudah tersedia secara legal
      final visualSettingsMap = defaultVisualSettings.toJson(aspectRatioValue, projectId);

      debugPrint("addProject (NARACINEMA PLUS): Creating new project for user ${user.uid} with title: $title");
      
      // Gunakan .set() karena docRef sudah dibuat di awal
      await docRef.set({
        'userId': user.uid,
        'title': title.isNotEmpty ? title : "Untitled Naracinema Plus Project",
        'rawScript': rawScript,
        'imageStyle': imageStyle,
        'aspectRatio': aspectRatio,
        'language': language, 
        'voice': voice,                 
        'showSubtitles': showSubtitles, 
        'resolution': resolution,       
        'costLevel': costLevel,         // [PERBAIKAN FITUR BARU]: Save Cost Level ke DB
        
        'status': 'PROCESSING_SCENE', 
        
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),

        'expireAt': Timestamp.fromDate(DateTime.now().add(const Duration(hours: 24))),

        'visualSettings': visualSettingsMap,
        'thumbnailImageUrl': null,
        'finalVideoUrl': null,
        'errorDetail': null,
      });

      debugPrint('✅ Project (NARACINEMA PLUS) created with ID $projectId and default visual settings. Backend auto-triggered.');
      return projectId;

    } catch (e) {
      debugPrint("❌ Error adding project (NARACINEMA PLUS) to Firestore: $e");
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
    debugPrint("Invalid aspectRatio string '$ratioString' in FirestoreNaracinemaPlusService, falling back to 16/9.");
    return 16 / 9;
  }
} // <-- PENUTUP CLASS YANG BENAR (Blok 2, 3, dan 4 berada di dalam Class)
//----------------------------------------------------------------//