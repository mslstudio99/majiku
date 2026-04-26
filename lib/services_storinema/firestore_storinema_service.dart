//................................................................//
// NAMA FILE: FIRESTORE_STORINEMA_SERVICE.DART                    //
// PATH: LIB/SERVICES_STORINEMA/FIRESTORE_STORINEMA_SERVICE.DART  //
// DESKRIPSI: LAYANAN UTAMA UNTUK INTERAKSI FIRESTORE STORINEMA   //
//................................................................//

//No ke-1: IMPORT DEPENDENSI & SETUP AWAL ........................//
//................................................................//
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models_storinema/scene_storinema.dart';
import '../models_storinema/video_project_storinema.dart';
import '../providers_storinema/visual_settings_storinema_provider.dart';
//................................................................//

//No ke-2: SERVICE CLASS DAN OPERASI READ ........................//
//................................................................//
class FirestoreStorinemaService {
  final FirebaseFirestore? _dbInstance;
  final FirebaseAuth? _authInstance;

  FirebaseFirestore get _db => _dbInstance ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => _authInstance ?? FirebaseAuth.instance;

  FirestoreStorinemaService({FirebaseFirestore? db, FirebaseAuth? auth})
      : _dbInstance = db,
        _authInstance = auth;

  Stream<List<VideoProjectStorinema>> getProjectsForUser() {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint("getProjectsForUser (STORINEMA): No user logged in.");
      return Stream.value([]);
    }
    debugPrint("getProjectsForUser (STORINEMA): Fetching projects for user ${user.uid}");
    return _db
        .collection('projects_storinema')
        .where('userId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      debugPrint("getProjectsForUser (STORINEMA): Received ${snapshot.docs.length} project snapshots.");
      return snapshot.docs.map((doc) {
        try {
          return VideoProjectStorinema.fromFirestore(doc);
        } catch (e) {
          debugPrint("Error parsing project (STORINEMA) ${doc.id}: $e");
          return null;
        }
      }).whereType<VideoProjectStorinema>().toList();
    }).handleError((error) {
      debugPrint("Error in getProjectsForUser (STORINEMA) stream: $error");
      return <VideoProjectStorinema>[];
    });
  }

  Stream<VideoProjectStorinema> getProjectStream(String projectId) {
    debugPrint("getProjectStream (STORINEMA): Subscribing to project $projectId");
    return _db
        .collection('projects_storinema')
        .doc(projectId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) {
        debugPrint("getProjectStream (STORINEMA): Project $projectId does not exist.");
        throw Exception('Project not found');
      }
      try {
        return VideoProjectStorinema.fromFirestore(snapshot);
      } catch (e) {
        debugPrint("Error parsing project (STORINEMA) stream for ${snapshot.id}: $e");
        throw Exception('Error parsing project data (STORINEMA): $e');
      }
    }).handleError((error) {
      debugPrint("Error in getProjectStream (STORINEMA) for $projectId: $error");
      throw error;
    });
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getProject(String projectId) async {
    debugPrint("getProject (STORINEMA): Fetching single snapshot for project $projectId");
    try {
      final doc = await _db.collection('projects_storinema').doc(projectId).get();
      if (!doc.exists) {
        debugPrint("getProject (STORINEMA): Project $projectId does not exist.");
        throw Exception('Project not found');
      }
      return doc;
    } catch (e) {
      debugPrint("Error fetching project (STORINEMA) $projectId: $e");
      rethrow;
    }
  }

  Stream<List<SceneStorinema>> getScenesStream(String projectId) {
    debugPrint("getScenesStream (STORINEMA): Subscribing to scenes for project $projectId");
    return _db
        .collection('projects_storinema')
        .doc(projectId)
        .collection('scenes')
        .orderBy('segmentIndex')
        .snapshots()
        .map((snapshot) {
      debugPrint("getScenesStream (STORINEMA): Received ${snapshot.docs.length} scene snapshots for project $projectId.");
      return snapshot.docs.map((doc) {
        try {
          return SceneStorinema.fromFirestore(doc);
        } catch (e) {
          debugPrint("Error parsing scene (STORINEMA) ${doc.id} for project $projectId: $e");
          return null;
        }
      }).whereType<SceneStorinema>().toList();
    }).where((list) => list.isNotEmpty); 
  }
//................................................................//

//No ke-3: OPERASI UPDATE, REGENERATE, DAN DELETE ................//
//................................................................//
  Future<void> updateProject(String projectId, Map<String, dynamic> data) async {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint(
          "updateProject (STORINEMA): No user logged in. Update cancelled for $projectId.");
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
          "updateProject (STORINEMA deep merge): Updating project $projectId with keys: ${flattenedData.keys.join(', ')}");

      await _db.collection('projects_storinema').doc(projectId).update(flattenedData);

      debugPrint("updateProject (STORINEMA): Project $projectId updated successfully.");
    } catch (e) {
      debugPrint("❌ Error updating project (STORINEMA) $projectId: $e");
      rethrow;
    }
  }

  Future<void> deleteProject(String projectId) async {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint("deleteProject (STORINEMA): No user logged in. Delete cancelled for $projectId.");
        throw Exception('User not logged in');
      }

    try {
      final projectRef = _db.collection('projects_storinema').doc(projectId);
      debugPrint("deleteProject (STORINEMA): Deleting project $projectId and its scenes...");

      final scenesSnapshot = await projectRef.collection('scenes').get();
      if (scenesSnapshot.docs.isNotEmpty) {
          final batch = _db.batch();
          for (var doc in scenesSnapshot.docs) {
            batch.delete(doc.reference);
          }
          await batch.commit();
          debugPrint("deleteProject (STORINEMA): Deleted ${scenesSnapshot.docs.length} scenes for project $projectId.");
      } else {
          debugPrint("deleteProject (STORINEMA): No scenes found to delete for project $projectId.");
      }

      await projectRef.delete();
      debugPrint("✅ deleteProject (STORINEMA): Project $projectId deleted successfully.");
    } catch (e) {
      debugPrint("❌ Error deleting project (STORINEMA) $projectId: $e");
      rethrow;
    }
  }

  // [PERBAIKAN]: Menyamakan nama method dengan pemanggilan di Screen UI (requestVideoRegeneration)
  Future<void> requestVideoRegeneration(String projectId, String sceneId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    try {
      final sceneRef = _db.collection('projects_storinema').doc(projectId).collection('scenes').doc(sceneId);
      debugPrint("requestVideoRegeneration (STORINEMA): Requesting regeneration for scene $sceneId in project $projectId");

      await sceneRef.update({
        'status': 'PENDING_REFINEMENT',
        'imageUrl': FieldValue.delete(), // Menghapus field imageUrl (jika masih ada)
        'videoUrl': FieldValue.delete(), // Menghapus video AI lama
        'ttsAudioUrl': FieldValue.delete(), // [PERBAIKAN MUTLAK]: Membersihkan memori Audio TTS Lama
        'errorDetail': FieldValue.delete(), 
      });
        debugPrint("requestVideoRegeneration (STORINEMA): Regeneration requested for scene $sceneId.");
    } catch (e) {
      debugPrint("❌ Failed to request regeneration (STORINEMA) for scene $sceneId: $e");
      rethrow;
    }
  }

  Future<void> updateScenePromptAndRegenerate(
      String projectId, String sceneId, String newPrompt) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    try {
      final sceneRef = _db
          .collection('projects_storinema')
          .doc(projectId)
          .collection('scenes')
          .doc(sceneId);

      debugPrint(
          "updateScenePromptAndRegenerate (STORINEMA): Updating prompt for scene $sceneId");

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
      
      debugPrint("updateScenePromptAndRegenerate (STORINEMA): Success.");
    } catch (e) {
      debugPrint("❌ Failed to update prompt and regenerate (STORINEMA): $e");
      rethrow;
    }
  }
//................................................................//

//No ke-4: OPERASI CREATE DAN HELPER METHOD ......................//
//................................................................//
  Future<String?> addProject({
    required String title,
    required String rawScript,
    required String imageStyle,
    required String aspectRatio,
    required String language,
    required String voice,         
    required bool showSubtitles,   
    required String resolution,    // [TAMBAHAN BARU] Menangkap Resolusi
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint("❌ Error: User not logged in. Cannot add project (STORINEMA).");
      return null;
    }

    try {
      final defaultVisualSettings = VisualSettingsStorinema.defaultSettingsWithTitle(title);
      final double aspectRatioValue = _calculateAspectRatioFromString(aspectRatio);
      final visualSettingsMap = defaultVisualSettings.toJson(aspectRatioValue);

      debugPrint("addProject (STORINEMA): Creating new project for user ${user.uid} with title: $title");
      
      final docRef = await _db.collection('projects_storinema').add({
        'userId': user.uid,
        'title': title.isNotEmpty ? title : "Untitled Storinema Project",
        'rawScript': rawScript,
        'imageStyle': imageStyle,
        'aspectRatio': aspectRatio,
        'language': language, 
        'voice': voice,                 
        'showSubtitles': showSubtitles, 
        'resolution': resolution,       // [TAMBAHAN BARU] Save Resolusi ke DB
        
        'status': 'PROCESSING_SCENE', 
        
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),

        'expireAt': Timestamp.fromDate(DateTime.now().add(const Duration(hours: 24))),

        'visualSettings': visualSettingsMap,
        'thumbnailImageUrl': null,
        'finalVideoUrl': null,
        'errorDetail': null,
      });

      debugPrint('✅ Project (STORINEMA) created with ID ${docRef.id} and default visual settings. Backend auto-triggered.');
      return docRef.id;

    } catch (e) {
      debugPrint("❌ Error adding project (STORINEMA) to Firestore: $e");
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
    debugPrint("Invalid aspectRatio string '$ratioString' in FirestoreStorinemaService, falling back to 16/9.");
    return 16 / 9;
  }
}
//................................................................//