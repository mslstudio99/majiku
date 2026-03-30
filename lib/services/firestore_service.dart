//..................................................//
// LIB/SERVICES/FIRESTORE_SERVICE.DART              //
//..................................................//

//No ke-1...........................................//
// IMPORT, SETUP KEAMANAN, DAN DEPENDENSI           //
import 'dart:io' show Platform;
import 'dart:ui' as ui; // Digunakan untuk mengambil resolusi layar fisik
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart'; 

// Package Keamanan & Anti-Fraud
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:android_id/android_id.dart'; // [BARU] Khusus untuk Plat Nomor Mesin Murni

// Import model Scene dan VideoProject
import '../models/scene.dart';
import '../models/video_project.dart';
// Import model VisualSettings dari provider
import '../providers/visual_settings_provider.dart';

/*
KATEGORI_ARSITEKTUR_BARU NO_URUT_15 (REVISI PARIPURNA 6.0 - STRICT ID + FORENSIC LOG)
Nama File: lib/services/firestore_service.dart
Status: STABIL, ANTI-REGRESI, & ANTI-FARMING AKURAT
Perubahan: 
- Mencabut IP tracking agar tidak rancu dengan jaringan WiFi/CGNAT publik.
- Memisahkan Hardware ID Mutlak (ANDROID_ID) dengan Spesifikasi Kosmetik (Merk HP).
- Menambahkan 'totalRegistrations' untuk monitoring peternak akun.
*/
//..................................................//

//No ke-2...........................................//
// CLASS SERVICE DAN LOGIKA ANTI-FRAUD IDENTITAS    //
class FirestoreService {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  // Konstruktor dengan instance default
  FirestoreService({FirebaseFirestore? db, FirebaseAuth? auth})
      : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  /// Mengambil Detail Spesifikasi Kosmetik (HANYA UNTUK CATATAN/INFO, BUKAN ID)
  Future<Map<String, dynamic>> _getDeviceSpecs() async {
    final deviceInfo = DeviceInfoPlugin();
    final double width = ui.PlatformDispatcher.instance.views.first.physicalSize.width;
    final double height = ui.PlatformDispatcher.instance.views.first.physicalSize.height;

    try {
      if (kIsWeb) {
        final web = await deviceInfo.webBrowserInfo;
        return {
          'mesin': '${web.browserName} on ${web.platform}',
          'resolusi': '${width.toInt()}x${height.toInt()}',
          'cores': web.hardwareConcurrency,
          'userAgent': web.userAgent,
        };
      } else if (Platform.isAndroid) {
        final android = await deviceInfo.androidInfo;
        return {
          'brand': android.brand,
          'model': android.model,
          'resolusi': '${width.toInt()}x${height.toInt()}',
          'hardware': android.hardware,
          'androidVer': android.version.release,
        };
      }
    } catch (e) {
      debugPrint("⚠️ Gagal ambil spek hardware kosmetik: $e");
    }
    return {'info': 'generic_device'};
  }

  /// Menghasilkan ID Unik Mutlak Fisik Mesin (ANDROID_ID murni / UUID Web).
  Future<String?> _getStrictHardwareId() async {
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        String? deviceId = prefs.getString('web_persistent_id');
        if (deviceId == null) {
          deviceId = const Uuid().v4();
          await prefs.setString('web_persistent_id', deviceId);
        }
        return "web_$deviceId";
      } else if (Platform.isAndroid) {
        const androidIdPlugin = AndroidId();
        final String? androidId = await androidIdPlugin.getId();
        return androidId != null ? "android_$androidId" : null;
      }
    } catch (e) {
      debugPrint("❌ Gagal mengambil Strict Hardware ID: $e");
    }
    return null;
  }

  /// Logika Anti-Fraud (MASTER RECORD): isNewRegistration memblokir Race Condition,
  /// Menggunakan STRICT HARDWARE ID sebagai indikator tunggal, Merk HP sebagai catatan.
  Future<void> ensureUserDocumentExists({bool isNewRegistration = false}) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      debugPrint("[UserInit] Gagal: User/Email null.");
      return;
    }

    final userRef = _db.collection('users').doc(user.uid);
    final String userEmail = user.email!.toLowerCase().trim();
    
    try {
      final doc = await userRef.get();
      
      // 1. Ambil Nilai Config Bonus Langsung Dari Database
      int configuredBonus = 1000; 
      try {
        final configDoc = await _db.collection('config').doc('tokens_setting').get();
        if (configDoc.exists) {
          final data = configDoc.data();
          if (data != null && data.containsKey('free_tokens')) {
            configuredBonus = data['free_tokens'] ?? 1000;
          } else if (data != null && data.containsKey('costs')) {
            final costsData = data['costs'] as Map<String, dynamic>;
            configuredBonus = costsData['free_tokens'] ?? 1000;
          }
        }
      } catch (e) {
        debugPrint("⚠️ FirestoreService: Gagal membaca config tokens_setting: $e");
      }

      // 2. Persiapan Data (Indikator Mutlak + Catatan Kosmetik)
      final String safeDeviceId = await _getStrictHardwareId() ?? "unknown_device_${user.uid}";
      final Map<String, dynamic> deviceSpecs = await _getDeviceSpecs();
      
      bool isDeviceEligible = false; 
      
      // Audit Silang KUNCI FORENSIK dengan ID Mutlak
      final deviceRef = _db.collection('device_claims').doc(safeDeviceId);
      final deviceDoc = await deviceRef.get();
      
      if (!deviceDoc.exists) {
        isDeviceEligible = true; // Skenario 1: Mesin Fisik Bersih (Belum pernah klaim)
      } else {
        isDeviceEligible = false; // Skenario 2: Ternak Akun (Mesin ini sudah pernah dipakai!)
        debugPrint("⚠️ FRAUD: HardwareId $safeDeviceId sudah pernah diklaim.");
      }

      // Jika fraud, bonus disetel paksa menjadi 0
      final int finalBonus = isDeviceEligible ? configuredBonus : 0;

      // 3. Eksekusi Penciptaan atau Pembaruan Data (Menggunakan ATOMIC BATCH)
      final batch = _db.batch();

      // LOGIKA ANTI RACE-CONDITION: Menimpa paksa walau UI curi start
      if (!doc.exists || isNewRegistration) {
        debugPrint("[UserInit] Eksekusi Paksa Akun: $userEmail. Bonus: $finalBonus TM.");
        
        // Eksekusi Dokumen User
        batch.set(userRef, {
          'uid': user.uid,
          'email': userEmail,
          'displayName': user.displayName ?? '',
          'userTier': 'free',
          'tokenBalance': finalBonus, 
          'hasReceivedWelcomeBonus': true, 
          'isFraudDetected': !isDeviceEligible, 
          'createdAt': doc.exists ? (doc.data()?['createdAt'] ?? FieldValue.serverTimestamp()) : FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // Eksekusi Master Record Perangkat (Catat ID Mutlak + Log Merk HP)
        if (isDeviceEligible) {
          batch.set(deviceRef, {
            'hardwareId': safeDeviceId,
            'firstEmail': userEmail,
            'registeredEmails': [userEmail],
            'totalRegistrations': 1, // Start dari 1
            'hardwareDetail': deviceSpecs, // Hanya sebagai info/catatan
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          // Update Master: Tambahkan email nakal ke array dan naikkan counter
          batch.update(deviceRef, {
            'registeredEmails': FieldValue.arrayUnion([userEmail]),
            'totalRegistrations': FieldValue.increment(1),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

      } else {
        // Kasus Login Normal: Penyelamatan User Lama
        final data = doc.data()!;
        if ((data['tokenBalance'] ?? 0) <= 0 && !(data['hasReceivedWelcomeBonus'] ?? false)) {
          debugPrint("[UserInit] Menyelamatkan user lama $userEmail. Bonus: $finalBonus TM.");
          
          batch.update(userRef, {
            'tokenBalance': finalBonus,
            'hasReceivedWelcomeBonus': true,
            'isFraudDetected': !isDeviceEligible,
            'updatedAt': FieldValue.serverTimestamp(),
          });

          if (isDeviceEligible) {
            batch.set(deviceRef, {
              'hardwareId': safeDeviceId,
              'firstEmail': userEmail,
              'registeredEmails': [userEmail],
              'totalRegistrations': 1,
              'hardwareDetail': deviceSpecs,
              'createdAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            });
          } else {
            batch.update(deviceRef, {
              'registeredEmails': FieldValue.arrayUnion([userEmail]),
              'totalRegistrations': FieldValue.increment(1),
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        }
      }

      // COMMIT BATCH (Menjamin semua ditulis utuh dalam 1 waktu)
      await batch.commit();

    } catch (e) {
      debugPrint("❌ FirestoreService Error pada ensureUserDocumentExists: $e");
    }
  }
//..................................................//

//No ke-3...........................................//
// OPERASI DATA PROYEK (INTEGRITAS PENUH)           //
  Stream<List<VideoProject>> getProjectsForUser() {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint("getProjectsForUser: Gagal, tidak ada user login.");
      return Stream.value([]); 
    }
    
    debugPrint("getProjectsForUser: Memulai stream untuk user ${user.uid}");
    return _db
        .collection('projects')
        .where('userId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      debugPrint("getProjectsForUser: Berhasil memuat ${snapshot.docs.length} dokumen.");
      return snapshot.docs.map((doc) {
        try {
          return VideoProject.fromFirestore(doc);
        } catch (e) {
          debugPrint("❌ Error parsing VideoProject pada ID ${doc.id}: $e");
          return null; 
        }
      }).whereType<VideoProject>().toList(); 
    }).handleError((error) {
      debugPrint("❌ Error pada stream getProjectsForUser: $error");
      return <VideoProject>[]; 
    });
  }

  Stream<VideoProject> getProjectStream(String projectId) {
    debugPrint("getProjectStream: Berlangganan pada proyek $projectId");
    return _db
        .collection('projects')
        .doc(projectId)
        .snapshots()
        .map((snapshot) {
          if (!snapshot.exists) {
              debugPrint("getProjectStream: Proyek $projectId tidak ditemukan.");
              throw Exception('Project not found'); 
          }
          try {
            return VideoProject.fromFirestore(snapshot);
          } catch (e) {
            debugPrint("❌ Error parsing stream proyek $projectId: $e");
            throw Exception('Error parsing project data: $e');
          }
        }).handleError((error) {
          debugPrint("❌ Error pada getProjectStream: $error");
          throw error;
        });
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getProject(String projectId) async {
    debugPrint("getProject: Mengambil snapshot tunggal untuk $projectId");
    try {
      final doc = await _db.collection('projects').doc(projectId).get();
      if (!doc.exists) {
        debugPrint("getProject: Proyek $projectId tidak ada.");
        throw Exception('Project not found');
      }
      return doc;
    } catch (e) {
      debugPrint("❌ Gagal mengambil data proyek $projectId: $e");
      rethrow; 
    }
  }

  Stream<List<Scene>> getScenesStream(String projectId) {
    debugPrint("getScenesStream: Berlangganan pada scenes proyek $projectId");
    return _db
        .collection('projects')
        .doc(projectId)
        .collection('scenes')
        .orderBy('segmentIndex')
        .snapshots()
        .map((snapshot) {
      debugPrint("getScenesStream: Memuat ${snapshot.docs.length} scenes.");
      return snapshot.docs.map((doc) {
        try {
          return Scene.fromFirestore(doc);
        } catch (e) {
          debugPrint("❌ Error parsing Scene ID ${doc.id}: $e");
          return null; 
        }
      }).whereType<Scene>().toList(); 
    }).handleError((error) {
      debugPrint("❌ Error pada getScenesStream proyek $projectId: $error");
      return <Scene>[]; 
    });
  }
//..................................................//

//No ke-4...........................................//
// OPERASI UPDATE, DELETE, & REGENERATE             //
  Future<void> updateProject(String projectId, Map<String, dynamic> data) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

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

      debugPrint("updateProject (deep merge): Updating $projectId with keys: ${flattenedData.keys.join(', ')}");
      await _db.collection('projects').doc(projectId).update(flattenedData);
    } catch (e) {
      debugPrint("❌ Error updating project $projectId: $e");
      rethrow;
    }
  }

  Future<void> deleteProject(String projectId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    try {
      final projectRef = _db.collection('projects').doc(projectId);
      debugPrint("deleteProject: Starting batch delete for project $projectId");

      final scenesSnapshot = await projectRef.collection('scenes').get();
      if (scenesSnapshot.docs.isNotEmpty) {
        final batch = _db.batch();
        for (var doc in scenesSnapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
        debugPrint("deleteProject: Deleted ${scenesSnapshot.docs.length} scenes.");
      }

      await projectRef.delete();
      debugPrint("✅ deleteProject: Project $projectId deleted successfully.");
    } catch (e) {
      debugPrint("❌ Error deleting project $projectId: $e");
      rethrow;
    }
  }

  Future<void> requestImageRegeneration(String projectId, String sceneId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    try {
      final sceneRef = _db.collection('projects').doc(projectId).collection('scenes').doc(sceneId);
      debugPrint("requestImageRegeneration: Requesting for scene $sceneId");
      await sceneRef.update({
        'status': 'PENDING_REGENERATION',
        'imageUrl': FieldValue.delete(),
        'errorDetail': FieldValue.delete(),
      });
    } catch (e) {
      debugPrint("❌ Failed to request regeneration: $e");
      rethrow;
    }
  }

  Future<String?> addProject({
    required String title,
    required String rawScript,
    required String imageStyle,
    required String aspectRatio,
    required String language,
    required String voice,
    required bool showSubtitles, 
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint("❌ addProject: User not logged in.");
      return null;
    }

    try {
      final defaultVisualSettings = VisualSettings.defaultSettingsWithTitle(title)
          .copyWith(showSubtitles: showSubtitles);
      
      final double aspectRatioValue = _calculateAspectRatioFromString(aspectRatio);
      
      final visualSettingsMap = defaultVisualSettings.toJson(aspectRatioValue);

      debugPrint("addProject: Creating new project with title: $title");
      final docRef = await _db.collection('projects').add({
        'userId': user.uid,
        'title': title.isNotEmpty ? title : "Untitled Project",
        'rawScript': rawScript,
        'imageStyle': imageStyle,
        'aspectRatio': aspectRatio,
        'language': language,
        'voice': voice,
        'status': 'PROCESSING_GENERATION',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'expireAt': Timestamp.fromDate(DateTime.now().add(const Duration(hours: 24))),
        'visualSettings': visualSettingsMap,
        'thumbnailImageUrl': null,
        'finalVideoUrl': null,
        'errorDetail': null,
      });

      debugPrint('✅ Project created with ID ${docRef.id}.');
      return docRef.id;
    } catch (e) {
      debugPrint("❌ Error adding project: $e");
      return null;
    }
  }

  double _calculateAspectRatioFromString(String? ratioString) {
    if (ratioString == null || ratioString.isEmpty) return 16 / 9;
    final parts = ratioString.split(':');
    if (parts.length == 2) {
      final double? width = double.tryParse(parts[0]);
      final double? height = double.tryParse(parts[1]);
      if (width != null && height != null && height != 0) return width / height;
    }
    debugPrint("Invalid aspectRatio '$ratioString', falling back to 16/9.");
    return 16 / 9;
  }
} 
//..................................................//