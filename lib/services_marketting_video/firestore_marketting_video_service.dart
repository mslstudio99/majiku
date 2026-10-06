//================================================================//
// NAMA FILE: FIRESTORE_MARKETTING_VIDEO_SERVICE.DART              //
// DIREKTORI: LIB/SERVICES_MARKETTING_VIDEO/                       //
// DESKRIPSI: LAYANAN UTAMA UNTUK INTERAKSI FIRESTORE MARKETTING_VIDEO //
//================================================================//

// No ke-1: IMPORT DEPENDENSI & SETUP AWAL                        //
//----------------------------------------------------------------//
import 'dart:io'; // [INJEKSI BARU]: Dibutuhkan untuk membaca File gambar
import 'package:flutter/foundation.dart' show kIsWeb; // [BARU]: Deteksi Platform (Web/Mobile)
import 'package:image_picker/image_picker.dart'; // [BARU]: Dukungan XFile untuk Web
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart'; // [INJEKSI BARU]: Untuk upload gambar ke Storage
import 'package:flutter/material.dart';

// [PERBAIKAN MUTLAK]: Path disesuaikan ke direktori marketting_video
import '../models_marketting_video/scene_marketting_video.dart';
import '../models_marketting_video/video_project_marketting_video.dart';
import '../providers_marketting_video/visual_settings_marketting_video_provider.dart';
//----------------------------------------------------------------//

// No ke-2: SERVICE CLASS DAN OPERASI READ                        //
//----------------------------------------------------------------//
class FirestoreMarkettingVideoService {
  final FirebaseFirestore? _dbInstance;
  final FirebaseAuth? _authInstance;

  FirebaseFirestore get _db => _dbInstance ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => _authInstance ?? FirebaseAuth.instance;

  FirestoreMarkettingVideoService({FirebaseFirestore? db, FirebaseAuth? auth})
      : _dbInstance = db,
        _authInstance = auth;

  Stream<List<VideoProjectMarkettingVideo>> getProjectsForUser() {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint("getProjectsForUser (MARKETTING VIDEO): No user logged in.");
      return Stream.value([]);
    }
    debugPrint("getProjectsForUser (MARKETTING VIDEO): Fetching projects for user ${user.uid}");
    return _db
        .collection('projects_marketting_video')
        .where('userId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      debugPrint("getProjectsForUser (MARKETTING VIDEO): Received ${snapshot.docs.length} project snapshots.");
      return snapshot.docs.map((doc) {
        try {
          return VideoProjectMarkettingVideo.fromFirestore(doc);
        } catch (e) {
          debugPrint("Error parsing project (MARKETTING VIDEO) ${doc.id}: $e");
          return null;
        }
      }).whereType<VideoProjectMarkettingVideo>().toList();
    }).handleError((error) {
      debugPrint("Error in getProjectsForUser (MARKETTING VIDEO) stream: $error");
      throw error; 
    });
  }

  Stream<VideoProjectMarkettingVideo> getProjectStream(String projectId) {
    debugPrint("getProjectStream (MARKETTING VIDEO): Subscribing to project $projectId");
    return _db
        .collection('projects_marketting_video')
        .doc(projectId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) {
        debugPrint("getProjectStream (MARKETTING VIDEO): Project $projectId does not exist.");
        throw Exception('Project not found');
      }
      try {
        return VideoProjectMarkettingVideo.fromFirestore(snapshot);
      } catch (e) {
        debugPrint("Error parsing project (MARKETTING VIDEO) stream for ${snapshot.id}: $e");
        throw Exception('Error parsing project data (MARKETTING VIDEO): $e');
      }
    }).handleError((error) {
      debugPrint("Error in getProjectStream (MARKETTING VIDEO) for $projectId: $error");
      throw error;
    });
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getProject(String projectId) async {
    debugPrint("getProject (MARKETTING VIDEO): Fetching single snapshot for project $projectId");
    try {
      final doc = await _db.collection('projects_marketting_video').doc(projectId).get();
      if (!doc.exists) {
        debugPrint("getProject (MARKETTING VIDEO): Project $projectId does not exist.");
        throw Exception('Project not found');
      }
      return doc;
    } catch (e) {
      debugPrint("Error fetching project (MARKETTING VIDEO) $projectId: $e");
      rethrow;
    }
  }

  Stream<List<SceneMarkettingVideo>> getScenesStream(String projectId) {
    debugPrint("getScenesStream (MARKETTING VIDEO): Subscribing to scenes for project $projectId");
    return _db
        .collection('projects_marketting_video')
        .doc(projectId)
        .collection('scenes')
        .orderBy('segmentIndex')
        .snapshots()
        .map((snapshot) {
      debugPrint("getScenesStream (MARKETTING VIDEO): Received ${snapshot.docs.length} scene snapshots for project $projectId.");
      return snapshot.docs.map((doc) {
        try {
          return SceneMarkettingVideo.fromFirestore(doc);
        } catch (e) {
          debugPrint("Error parsing scene (MARKETTING VIDEO) ${doc.id} for project $projectId: $e");
          return null;
        }
      }).whereType<SceneMarkettingVideo>().toList();
    }).where((list) => list.isNotEmpty); 
  }
//----------------------------------------------------------------//

// No ke-3: OPERASI UPDATE, REGENERATE, DAN DELETE                //
//----------------------------------------------------------------//
  Future<void> updateProject(String projectId, Map<String, dynamic> data) async {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint("updateProject (MARKETTING VIDEO): No user logged in. Update cancelled for $projectId.");
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

      debugPrint("updateProject (MARKETTING VIDEO deep merge): Updating project $projectId with keys: ${flattenedData.keys.join(', ')}");

      await _db.collection('projects_marketting_video').doc(projectId).update(flattenedData);

      debugPrint("updateProject (MARKETTING VIDEO): Project $projectId updated successfully.");
    } catch (e) {
      debugPrint("❌ Error updating project (MARKETTING VIDEO) $projectId: $e");
      rethrow;
    }
  }

  Future<void> deleteProject(String projectId) async {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint("deleteProject (MARKETTING VIDEO): No user logged in. Delete cancelled for $projectId.");
        throw Exception('User not logged in');
      }

    try {
      final projectRef = _db.collection('projects_marketting_video').doc(projectId);
      debugPrint("deleteProject (MARKETTING VIDEO): Deleting project $projectId and its scenes...");

      final scenesSnapshot = await projectRef.collection('scenes').get();
      if (scenesSnapshot.docs.isNotEmpty) {
          final batch = _db.batch();
          for (var doc in scenesSnapshot.docs) {
            batch.delete(doc.reference);
          }
          await batch.commit();
          debugPrint("deleteProject (MARKETTING VIDEO): Deleted ${scenesSnapshot.docs.length} scenes for project $projectId.");
      } else {
          debugPrint("deleteProject (MARKETTING VIDEO): No scenes found to delete for project $projectId.");
      }

      await projectRef.delete();
      
      // Catatan: Penghapusan file aset di Storage (termasuk gambar produk) ditangani secara otomatis 
      // oleh Cloud Function 'onProjectDeleted_marketting_video' yang sudah kita buat sebelumnya.
      
      debugPrint("✅ deleteProject (MARKETTING VIDEO): Project $projectId deleted successfully.");
    } catch (e) {
      debugPrint("❌ Error deleting project (MARKETTING VIDEO) $projectId: $e");
      rethrow;
    }
  }

  Future<void> requestVideoRegeneration(String projectId, String sceneId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    try {
      final sceneRef = _db.collection('projects_marketting_video').doc(projectId).collection('scenes').doc(sceneId);
      debugPrint("requestVideoRegeneration (MARKETTING VIDEO): Requesting regeneration for scene $sceneId in project $projectId");

      await sceneRef.update({
        'status': 'PENDING_REFINEMENT',
        'imageUrl': FieldValue.delete(), 
        'videoUrl': FieldValue.delete(), 
        'ttsAudioUrl': FieldValue.delete(), 
        'errorDetail': FieldValue.delete(), 
      });
        debugPrint("requestVideoRegeneration (MARKETTING VIDEO): Regeneration requested for scene $sceneId.");
    } catch (e) {
      debugPrint("❌ Failed to request regeneration (MARKETTING VIDEO) for scene $sceneId: $e");
      rethrow;
    }
  }

  Future<void> updateScenePromptAndRegenerate(
      String projectId, String sceneId, String newPrompt) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    try {
      final sceneRef = _db
          .collection('projects_marketting_video')
          .doc(projectId)
          .collection('scenes')
          .doc(sceneId);

      debugPrint("updateScenePromptAndRegenerate (MARKETTING VIDEO): Updating prompt for scene $sceneId");

      if (newPrompt.trim().isEmpty) {
        debugPrint("❌ Error: Cannot update with an empty prompt.");
        throw Exception("Prompt cannot be empty.");
      }

      await sceneRef.update({
        'refinedPrompt': newPrompt,
        'status': 'PENDING_REFINEMENT',
        'errorDetail': FieldValue.delete(),
        'retryCount': 0,
        'imageUrl': FieldValue.delete(), 
        'videoUrl': FieldValue.delete(), 
        'ttsAudioUrl': FieldValue.delete(), 
      });
      
      debugPrint("updateScenePromptAndRegenerate (MARKETTING VIDEO): Success.");
    } catch (e) {
      debugPrint("❌ Failed to update prompt and regenerate (MARKETTING VIDEO): $e");
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
    required String costLevel,     
    required String description, 
    required String productType, // [BARU]: Jenis Produk
    required String brandName,   // [BARU]: Nama Merk
    required String productDesc, // [BARU]: Deskripsi Keunggulan
    File? productImageFile,      // File Gambar Produk (Mobile)
    File? logoImageFile,         // [BARU]: File Gambar Logo (Mobile)
    XFile? productImageXFile,    // [BARU]: Dukungan Upload Gambar Produk untuk Web
    XFile? logoImageXFile,       // [BARU]: Dukungan Upload Gambar Logo untuk Web
    String? descriptionTiming,   // [INJEKSI BARU]: Untuk posisi waktu deskripsi ('start' atau 'end')
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint("❌ Error: User not logged in. Cannot add project (MARKETTING VIDEO).");
      return null;
    }

    try {
      final docRef = _db.collection('projects_marketting_video').doc();
      final String projectId = docRef.id;
      
      String? uploadedProductImageUrl;
      String? uploadedLogoImageUrl;

      // [1] Upload Gambar Produk ke Firebase Storage (Dukungan Web & Mobile)
      if (kIsWeb && productImageXFile != null) {
        try {
          debugPrint("addProject (MARKETTING VIDEO): Uploading product image bytes for Web project $projectId...");
          final storageRef = FirebaseStorage.instance
              .ref()
              .child('projects_marketting_video_assets')
              .child(user.uid)
              .child('${projectId}_product.jpg');

          final bytes = await productImageXFile.readAsBytes();
          final uploadTask = await storageRef.putData(
            bytes,
            SettableMetadata(contentType: 'image/jpeg'),
          );
          
          uploadedProductImageUrl = await uploadTask.ref.getDownloadURL();
          debugPrint("✅ Product Image uploaded successfully (Web): $uploadedProductImageUrl");
        } catch (e) {
          debugPrint("❌ Error uploading product image (Web): $e");
          throw Exception("Gagal mengunggah gambar produk (Web). Pembuatan proyek dibatalkan.");
        }
      } else if (productImageFile != null) {
        try {
          debugPrint("addProject (MARKETTING VIDEO): Uploading product image file for Mobile project $projectId...");
          final storageRef = FirebaseStorage.instance
              .ref()
              .child('projects_marketting_video_assets')
              .child(user.uid)
              .child('${projectId}_product.jpg');

          final uploadTask = await storageRef.putFile(
            productImageFile,
            SettableMetadata(contentType: 'image/jpeg'),
          );
          
          uploadedProductImageUrl = await uploadTask.ref.getDownloadURL();
          debugPrint("✅ Product Image uploaded successfully (Mobile): $uploadedProductImageUrl");
        } catch (e) {
          debugPrint("❌ Error uploading product image (Mobile): $e");
          throw Exception("Gagal mengunggah gambar produk. Pembuatan proyek dibatalkan.");
        }
      }

      // [2] Upload Gambar Logo ke Firebase Storage (Dukungan Web & Mobile)
      if (kIsWeb && logoImageXFile != null) {
        try {
          debugPrint("addProject (MARKETTING VIDEO): Uploading logo image bytes for Web project $projectId...");
          final storageRef = FirebaseStorage.instance
              .ref()
              .child('projects_marketting_video_assets')
              .child(user.uid)
              .child('${projectId}_logo.png');

          final bytes = await logoImageXFile.readAsBytes();
          final uploadTask = await storageRef.putData(
            bytes,
            SettableMetadata(contentType: 'image/png'),
          );
          
          uploadedLogoImageUrl = await uploadTask.ref.getDownloadURL();
          debugPrint("✅ Logo Image uploaded successfully (Web): $uploadedLogoImageUrl");
        } catch (e) {
          debugPrint("❌ Error uploading logo image (Web): $e");
          throw Exception("Gagal mengunggah gambar logo (Web). Pembuatan proyek dibatalkan.");
        }
      } else if (logoImageFile != null) {
        try {
          debugPrint("addProject (MARKETTING VIDEO): Uploading logo image file for Mobile project $projectId...");
          final storageRef = FirebaseStorage.instance
              .ref()
              .child('projects_marketting_video_assets')
              .child(user.uid)
              .child('${projectId}_logo.png');

          final uploadTask = await storageRef.putFile(
            logoImageFile,
            SettableMetadata(contentType: 'image/png'),
          );
          
          uploadedLogoImageUrl = await uploadTask.ref.getDownloadURL();
          debugPrint("✅ Logo Image uploaded successfully (Mobile): $uploadedLogoImageUrl");
        } catch (e) {
          debugPrint("❌ Error uploading logo image (Mobile): $e");
          throw Exception("Gagal mengunggah gambar logo (Mobile). Pembuatan proyek dibatalkan.");
        }
      }

      final String finalTitle = title.isNotEmpty ? title : "Untitled Marketting Video Project";
      
      final defaultVisualSettings = VisualSettingsMarkettingVideo.defaultSettingsWithTitle(finalTitle, description);
      final double aspectRatioValue = _calculateAspectRatioFromString(aspectRatio);
      
      final visualSettingsMap = defaultVisualSettings.toJson(aspectRatioValue, resolution);

      // [INJEKSI DINAMIS]: Suntikkan parameter posisi deskripsi (start atau end) ke dalam map visual settings
      if (visualSettingsMap['descriptionOverlay'] != null) {
        visualSettingsMap['descriptionOverlay']['position'] = descriptionTiming ?? 'start';
      }

      debugPrint("addProject (MARKETTING VIDEO): Creating new project for user ${user.uid} with title: $finalTitle");
      
      await docRef.set({
        'userId': user.uid,
        'title': finalTitle,
        'rawScript': rawScript,
        'imageStyle': imageStyle,
        'aspectRatio': aspectRatio,
        'language': language, 
        'voice': voice,                 
        'showSubtitles': showSubtitles, 
        'resolution': resolution,       
        'costLevel': costLevel,         
        'description': description, 
        
        // [INJEKSI DATA BARU]: Metadata Konsultan Pemasaran
        'productType': productType,
        'brandName': brandName,
        'productDesc': productDesc,
        'productImageUrl': uploadedProductImageUrl, 
        'logoImageUrl': uploadedLogoImageUrl, 
        
        'status': 'PROCESSING_SCENE', 
        
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'expireAt': Timestamp.fromDate(DateTime.now().add(const Duration(hours: 24))),

        'visualSettings': visualSettingsMap, 
        'renderPacket': {
          'styleSettings': visualSettingsMap,
        },
        
        'thumbnailImageUrl': null,
        'finalVideoUrl': null,
        'errorDetail': null,
      });

      debugPrint('✅ Project (MARKETTING VIDEO) created with ID $projectId. Backend auto-triggered.');
      return projectId;

    } catch (e) {
      debugPrint("❌ Error adding project (MARKETTING VIDEO) to Firestore: $e");
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
    debugPrint("Invalid aspectRatio string '$ratioString' in FirestoreMarkettingVideoService, falling back to 16/9.");
    return 16 / 9;
  }
} 
//----------------------------------------------------------------//