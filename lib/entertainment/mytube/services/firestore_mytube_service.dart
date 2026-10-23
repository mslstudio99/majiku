//============================================================================//
// DIREKTORI: lib/entertainment/mytube/services/                             //
// FILE: FIRESTORE_MYTUBE_SERVICE.DART                                       //
// SERVICE FIRESTORE MYTUBE (DUKUNGAN PERSETUJUAN MODERASI CREATOR VS ADMIN)  //
//============================================================================//

//No ke-1....................................................................//
//IMPORTS & DEPENDENCIES                                                     //
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/video_mytube_model.dart';
import '../models/comment_mytube_model.dart';
import '../models/creator_mytube_model.dart';
import '../models/request_mytube_model.dart';
//............................................................................//

//No ke-2....................................................................//
//SERVICE DEFINITION & HIERARCHICAL DATABASE CONSTANTS                       //
class FirestoreMytubeService {
  final FirebaseFirestore _firestore;

  FirestoreMytubeService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  static const String colMytube = 'mytube';
  static const String subColShortVideo = 'short_video';
  static const String subColLongVideo = 'long_video';

  // Koleksi Antrean Permohonan Moderasi (Edit & Delete)
  static const String colRequests = 'mytube_requests';

  static const String colUsers = 'users';
  static const String colAdmins = 'mytube_admins';
  static const String subColComments = 'comments';
  static const String subColLikes = 'likes';
  static const String subColSaves = 'mytube_saves';
//............................................................................//

//No ke-3....................................................................//
//RBAC GATEWAYS (CREATOR VS ADMIN PUSAT)                                     //
  // Pengecekan 1: Khusus Admin Pusat (Persetujuan & Moderasi Penuh)
  Future<bool> checkIsAdmin(String userId) async {
    if (userId.isEmpty) return false;
    try {
      final userDoc = await _firestore.collection(colUsers).doc(userId).get();
      if (userDoc.exists) {
        final userData = userDoc.data();
        if (userData != null) {
          final userTier = userData['userTier']?.toString().toLowerCase();
          final role = userData['role']?.toString().toLowerCase();
          if (userTier == 'admin' || role == 'admin' || role == 'mytube_admin') {
            return true;
          }
        }
      }
      final adminDoc = await _firestore.collection(colAdmins).doc(userId).get();
      if (adminDoc.exists && (adminDoc.data()?['is_active'] == true)) {
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  // Pengecekan 2: Hak Akses Creator Studio (Bisa Creator ATAU Admin)
  Future<bool> checkIsCreatorOrAdmin(String userId) async {
    if (userId.isEmpty) return false;
    try {
      final userDoc = await _firestore.collection(colUsers).doc(userId).get();
      if (userDoc.exists) {
        final userData = userDoc.data();
        if (userData != null) {
          final userTier = userData['userTier']?.toString().toLowerCase();
          final role = userData['role']?.toString().toLowerCase();
          final isMytubeAdmin = userData['is_mytube_admin'];

          if (userTier == 'admin' ||
              userTier == 'creator' ||
              role == 'admin' ||
              role == 'creator' ||
              role == 'mytube_admin' ||
              isMytubeAdmin == true) {
            return true;
          }
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }
//............................................................................//

//No ke-4....................................................................//
//CREATOR PROFILE MANAGEMENT (mytube/{channelId} DENGAN FALLBACK LENGKAP)    //
  Future<CreatorMytubeModel?> getCreatorProfile(
    String email, {
    String? userId,
    String? channelId,
  }) async {
    final cleanEmail = email.trim().toLowerCase();

    try {
      // 1. Prioritas Tertinggi: Cari langsung via channelId abadi
      if (channelId != null && channelId.trim().isNotEmpty) {
        final doc = await _firestore.collection(colMytube).doc(channelId.trim()).get();
        if (doc.exists) {
          return CreatorMytubeModel.fromFirestore(doc);
        }
      }

      // 2. Prioritas Kedua: Cari via userId (UID) -> Cek channel_id di users/{uid}
      if (userId != null && userId.trim().isNotEmpty) {
        final userDoc = await _firestore.collection(colUsers).doc(userId.trim()).get();
        if (userDoc.exists) {
          final mappedChannelId = userDoc.data()?['channel_id']?.toString();
          if (mappedChannelId != null && mappedChannelId.isNotEmpty) {
            final channelDoc = await _firestore.collection(colMytube).doc(mappedChannelId).get();
            if (channelDoc.exists) {
              return CreatorMytubeModel.fromFirestore(channelDoc);
            }
          }
        }

        // Cari via query field creator_id di mytube
        final qSnap = await _firestore
            .collection(colMytube)
            .where('creator_id', isEqualTo: userId.trim())
            .limit(1)
            .get();
        if (qSnap.docs.isNotEmpty) {
          return CreatorMytubeModel.fromFirestore(qSnap.docs.first);
        }

        // Fallback jalur lama dokumen bernama UID
        final legacyUidDoc = await _firestore.collection(colMytube).doc(userId.trim()).get();
        if (legacyUidDoc.exists) {
          return CreatorMytubeModel.fromFirestore(legacyUidDoc);
        }
      }

      // 3. Prioritas Ketiga: Fallback via Email (Pencarian dokumen lama)
      if (cleanEmail.isNotEmpty) {
        // Cek dokumen lama yang ID-nya berupa alamat email
        final directEmailDoc = await _firestore.collection(colMytube).doc(cleanEmail).get();
        if (directEmailDoc.exists) {
          return CreatorMytubeModel.fromFirestore(directEmailDoc);
        }

        // Cek via query field email
        final emailSnap = await _firestore
            .collection(colMytube)
            .where('email', isEqualTo: cleanEmail)
            .limit(1)
            .get();
        if (emailSnap.docs.isNotEmpty) {
          return CreatorMytubeModel.fromFirestore(emailSnap.docs.first);
        }
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  Stream<CreatorMytubeModel?> streamCreatorProfile(
    String email, {
    String? userId,
    String? channelId,
  }) {
    final cleanKey = (channelId != null && channelId.isNotEmpty)
        ? channelId
        : (email.trim().toLowerCase().isNotEmpty ? email.trim().toLowerCase() : (userId ?? ''));

    if (cleanKey.isEmpty) return Stream.value(null);

    return _firestore.collection(colMytube).doc(cleanKey).snapshots().map((doc) {
      if (doc.exists) {
        return CreatorMytubeModel.fromFirestore(doc);
      }
      return null;
    });
  }

  Future<void> saveCreatorProfile(CreatorMytubeModel creator) async {
    // [KUNCI ABADI]: Kunci dokumen selalu menggunakan Channel ID
    final docKey = creator.channelId.isNotEmpty ? creator.channelId : creator.id;
    if (docKey.isEmpty) return;

    await _firestore.collection(colMytube).doc(docKey).set(
          creator.toMap(),
          SetOptions(merge: true),
        );

    // Sinkronkan channel_id ke dokumen users/{creatorId} agar selalu terhubung
    if (creator.creatorId.isNotEmpty) {
      try {
        await _firestore.collection(colUsers).doc(creator.creatorId).set({
          'channel_id': docKey,
        }, SetOptions(merge: true));
      } catch (_) {}
    }
  }
//............................................................................//

//No ke-5....................................................................//
//VIDEO CREATION (STRICT CHANNEL ID DENGAN RESOLVER OTOMATIS)                //
  Future<String> createVideoPost(VideoMytubeModel video) async {
    // [STRICT NEW WRITE]: Wajib memprioritaskan channelId resmi sebagai jangkar utama
    String creatorKey = video.channelId.trim();

    // Fallback darurat jika video baru belum membawa channelId: cari channel_id dari profil user
    if (creatorKey.isEmpty) {
      if (video.uploaderId.trim().isNotEmpty) {
        try {
          final userDoc = await _firestore.collection(colUsers).doc(video.uploaderId.trim()).get();
          final mappedChannelId = userDoc.data()?['channel_id']?.toString();
          if (mappedChannelId != null && mappedChannelId.trim().isNotEmpty) {
            creatorKey = mappedChannelId.trim();
          }
        } catch (_) {}
      }
    }

    // Fallback terakhir khusus untuk video lama / legacy uploader
    if (creatorKey.isEmpty) {
      creatorKey = video.uploaderEmail.trim().toLowerCase().isNotEmpty
          ? video.uploaderEmail.trim().toLowerCase()
          : video.uploaderId.trim();
    }

    if (creatorKey.isEmpty) throw Exception('Channel ID, Email, atau UID uploader tidak boleh kosong.');

    final isLong = video.videoType.toUpperCase() == 'LONG';
    final targetSubCol = isLong ? subColLongVideo : subColShortVideo;

    final docRef = video.id.isNotEmpty
        ? _firestore.collection(colMytube).doc(creatorKey).collection(targetSubCol).doc(video.id)
        : _firestore.collection(colMytube).doc(creatorKey).collection(targetSubCol).doc();

    // [INISIALISASI HLS V2]: Mengunci skema multi-bitrate dan menyematkan channel_id resmi ke dokumen video
    final modelWithId = video.copyWith(
      id: docRef.id,
      channelId: creatorKey,
      hlsVersion: 2,
      hlsStatus: 'PENDING',
      availableResolutions: video.availableResolutions.isNotEmpty
          ? video.availableResolutions
          : const [],
    );
    await docRef.set(modelWithId.toMap());

    try {
      await _firestore.collection(colMytube).doc(creatorKey).update({
        isLong ? 'total_longs' : 'total_shorts': FieldValue.increment(1),
        'total_videos': FieldValue.increment(1),
        'updated_at': FieldValue.serverTimestamp(),
      });
    } catch (_) {}

    return docRef.id;
  }
//............................................................................//

//No ke-6....................................................................//
//VIDEO FEED & QUERIES (COLLECTION GROUP UNTUK FEED PUBLIK & ANTREAN HLS)    //
  Stream<List<VideoMytubeModel>> getVideosStream({int limit = 30}) {
    return _firestore
        .collectionGroup(subColShortVideo)
        .orderBy('created_at', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => VideoMytubeModel.fromFirestore(doc))
          .toList();
    });
  }

  Stream<List<VideoMytubeModel>> getVideosByTypeStream({
    required String videoType,
    String? channelId,
    String? uploaderEmail,
    String? uploaderId,
    int limit = 50,
  }) {
    final isLong = videoType.toUpperCase() == 'LONG';
    final subCol = isLong ? subColLongVideo : subColShortVideo;
    
    // [DUAL-COMPATIBILITY]: Prioritaskan channelId, fallback ke email/uid
    final creatorKey = (channelId != null && channelId.trim().isNotEmpty)
        ? channelId.trim()
        : ((uploaderEmail != null && uploaderEmail.isNotEmpty)
            ? uploaderEmail.trim().toLowerCase()
            : uploaderId);

    if (creatorKey != null && creatorKey.isNotEmpty) {
      return _firestore
          .collection(colMytube)
          .doc(creatorKey)
          .collection(subCol)
          .orderBy('created_at', descending: true)
          .limit(limit)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs
            .map((doc) => VideoMytubeModel.fromFirestore(doc))
            .toList();
      });
    }

    return _firestore
        .collectionGroup(subCol)
        .orderBy('created_at', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => VideoMytubeModel.fromFirestore(doc))
          .toList();
    });
  }

  // [RESOLVER HIBRIDA CERDAS]: Cek direktori channelId baru dahulu -> Fallback ke direktori email/UID (8 video lama) -> Fallback collectionGroup
  Future<DocumentReference?> _resolveVideoDocRef({
    required String videoId,
    String? channelId,
    String? uploaderEmail,
    String? uploaderId,
    String videoType = 'SHORT',
  }) async {
    final subCol = videoType.toUpperCase() == 'LONG' ? subColLongVideo : subColShortVideo;

    // 1. Prioritas Utama: Jalur Baru mytube/{channelId}/{subCol}/{videoId}
    if (channelId != null && channelId.trim().isNotEmpty) {
      final newPathRef = _firestore.collection(colMytube).doc(channelId.trim()).collection(subCol).doc(videoId);
      final snap = await newPathRef.get();
      if (snap.exists) return newPathRef;
    }

    // 2. Prioritas Kedua (Penyelamat 8 Video Lama): Jalur Lama mytube/{email}/{subCol}/{videoId}
    final cleanEmail = uploaderEmail?.trim().toLowerCase();
    if (cleanEmail != null && cleanEmail.isNotEmpty) {
      final legacyEmailRef = _firestore.collection(colMytube).doc(cleanEmail).collection(subCol).doc(videoId);
      final snap = await legacyEmailRef.get();
      if (snap.exists) return legacyEmailRef;
    }

    // 3. Fallback Jalur UID jika pernah ada
    if (uploaderId != null && uploaderId.trim().isNotEmpty) {
      final legacyUidRef = _firestore.collection(colMytube).doc(uploaderId.trim()).collection(subCol).doc(videoId);
      final snap = await legacyUidRef.get();
      if (snap.exists) return legacyUidRef;
    }

    // 4. Fallback Terakhir Universal: Collection Group Search
    try {
      final query = await _firestore.collectionGroup(subCol).where(FieldPath.documentId, isEqualTo: videoId).limit(1).get();
      if (query.docs.isNotEmpty) {
        return query.docs.first.reference;
      }
    } catch (_) {}
    return null;
  }

  // --- [ANTREAN HLS V2]: PERMOHONAN RE-TRANSCODE BERURUTAN (ANTI-CRASH) ---
  /// Menandai dokumen video lama agar diproses ulang ke format HLS Multi-Bitrate (360p, 480p, 720p)
  Future<bool> requestVideoRetranscode({
    required String videoId,
    String? channelId,
    String? uploaderEmail,
    String? uploaderId,
    String videoType = 'SHORT',
  }) async {
    try {
      final docRef = await _resolveVideoDocRef(
        videoId: videoId,
        channelId: channelId,
        uploaderEmail: uploaderEmail,
        uploaderId: uploaderId,
        videoType: videoType,
      );
      if (docRef == null) return false;

      await docRef.update({
        'hls_version': 2,
        'hls_status': 'PENDING',
        'available_resolutions': [],
        'retranscode_requested_at': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Mengambil 1 video antrean berstatus PENDING secara bergiliran (Single Concurrency / Bebas OOM)
  Future<VideoMytubeModel?> getNextPendingTranscodeVideo({
    required String videoType,
  }) async {
    final subCol = videoType.toUpperCase() == 'LONG' ? subColLongVideo : subColShortVideo;
    try {
      final snap = await _firestore
          .collectionGroup(subCol)
          .where('hls_status', isEqualTo: 'PENDING')
          .limit(1)
          .get();

      if (snap.docs.isNotEmpty) {
        return VideoMytubeModel.fromFirestore(snap.docs.first);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// [PERBAIKAN SOLUSI UTAMA]: Mengambil video lama secara universal tanpa kendala index atau field kosong
  Future<List<VideoMytubeModel>> getLegacyVideosForMigration({
    required String videoType,
    int limit = 50,
  }) async {
    final subCol = videoType.toUpperCase() == 'LONG' ? subColLongVideo : subColShortVideo;
    try {
      // Hapus filter where Firestore agar dokumen lama yang belum punya field 'hls_version' tetap terbaca
      final snap = await _firestore
          .collectionGroup(subCol)
          .limit(limit)
          .get();

      return snap.docs.map((doc) => VideoMytubeModel.fromFirestore(doc)).toList();
    } catch (e) {
      print('🚨 [MYTUBE] Gagal memindai video legacy: $e');
      return [];
    }
  }

  /// Memperbarui progres status proses transcoding dan daftar resolusi yang rampung
  Future<bool> updateTranscodeProgress({
    required String videoId,
    String? channelId,
    String? uploaderEmail,
    String? uploaderId,
    String videoType = 'SHORT',
    required String status,
    String? hlsUrl,
    List<String>? availableResolutions,
    String? errorDetail,
  }) async {
    try {
      final docRef = await _resolveVideoDocRef(
        videoId: videoId,
        channelId: channelId,
        uploaderEmail: uploaderEmail,
        uploaderId: uploaderId,
        videoType: videoType,
      );
      if (docRef == null) return false;

      final Map<String, dynamic> updateMap = {
        'hls_status': status,
        'updated_at': FieldValue.serverTimestamp(),
      };

      if (hlsUrl != null && hlsUrl.isNotEmpty) {
        updateMap['hls_url'] = hlsUrl;
      }
      if (availableResolutions != null) {
        updateMap['available_resolutions'] = availableResolutions;
      }
      if (errorDetail != null && errorDetail.isNotEmpty) {
        updateMap['error_detail'] = errorDetail;
      }

      await docRef.update(updateMap);
      return true;
    } catch (_) {
      return false;
    }
  }
//............................................................................//

//No ke-7....................................................................//
//ATOMIC SOCIAL INTERACTIONS, AFFINITY & ON-DEMAND SUBTITLE CALLER           //
  // --- MESIN PEMBOBOTAN SINYAL MINAT PENGGUNA (ALGORITMA REKOMENDASI) ---
  Future<void> recordUserAffinitySignal({
    required String userId,
    required String category,
    required String language,
    required String channelKey,
    required String channelName,
    List<String>? topicLocations, // [BARU]: Target Topic Locations Video
    int categoryWeight = 1,
    int channelWeight = 1,
    int languageWeight = 1,
    int topicLocationWeight = 1, // [BARU]: Bobot Sinyal Minat Topic Location
  }) async {
    if (userId.isEmpty) return;

    try {
      final cleanChannelKey = channelKey.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9_-]'), '_');
      final tasteDocRef = _firestore
          .collection(colUsers)
          .doc(userId)
          .collection('mytube_interests')
          .doc('taste_profile');

      final Map<String, dynamic> updateData = {
        'summary.total_interactions': FieldValue.increment(1),
        'summary.last_updated_at': FieldValue.serverTimestamp(),
      };

      if (category.trim().isNotEmpty) {
        updateData['categories.${category.trim()}'] = FieldValue.increment(categoryWeight);
        updateData['summary.dominant_category'] = category.trim();
      }

      if (cleanChannelKey.isNotEmpty) {
        updateData['channels.$cleanChannelKey.channel_name'] = channelName.isNotEmpty ? channelName : 'Creator';
        updateData['channels.$cleanChannelKey.affinity_score'] = FieldValue.increment(channelWeight);
        updateData['channels.$cleanChannelKey.last_interacted_at'] = FieldValue.serverTimestamp();
      }

      if (language.trim().isNotEmpty) {
        updateData['languages.${language.trim()}'] = FieldValue.increment(languageWeight);
        updateData['summary.dominant_language'] = language.trim();
      }

      // [BARU - AKUMULASI SINYAL MINAT TOPIC LOCATION]:
      if (topicLocations != null && topicLocations.isNotEmpty) {
        for (final loc in topicLocations) {
          final cleanLoc = loc.trim();
          if (cleanLoc.isNotEmpty) {
            final safeLocKey = cleanLoc.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
            updateData['topic_locations.$safeLocKey'] = FieldValue.increment(topicLocationWeight);
          }
        }
        // Cari lokasi dominan spesifik (utamakan negara non-Global jika ada, fallback ke Global)
        final dominantLoc = topicLocations.firstWhere(
          (l) => l.trim().toLowerCase() != 'global',
          orElse: () => topicLocations.first,
        );
        updateData['summary.dominant_topic_location'] = dominantLoc.trim();
      }

      await tasteDocRef.set(updateData, SetOptions(merge: true));
    } catch (_) {}
  }

  // --- 1. TAYANGAN (VIEW COUNT + AFFINITY) ---
  Future<void> incrementViewCount(
    String videoId, {
    String? channelId,
    String? uploaderEmail,
    String? uploaderId,
    String videoType = 'SHORT',
    String? userId,
    String? category,
    String? language,
    String? channelName,
    List<String>? topicLocations, // [BARU]
  }) async {
    if (videoId.isEmpty) return;
    try {
      final docRef = await _resolveVideoDocRef(
        videoId: videoId,
        channelId: channelId,
        uploaderEmail: uploaderEmail,
        uploaderId: uploaderId,
        videoType: videoType,
      );

      if (docRef != null) {
        await docRef.update({
          'views_count': FieldValue.increment(1),
        });

        // [PENULISAN VIEWS KE CHANNEL ID RESMI]:
        final String? creatorDocKey = (channelId != null && channelId.trim().isNotEmpty)
            ? channelId.trim()
            : (docRef.parent.parent?.id ?? uploaderEmail?.trim().toLowerCase());

        if (creatorDocKey != null && creatorDocKey.isNotEmpty) {
          try {
            await _firestore.collection(colMytube).doc(creatorDocKey).update({
              'total_views': FieldValue.increment(1),
            });
          } catch (_) {}
        }

        if (userId != null && userId.isNotEmpty && category != null) {
          recordUserAffinitySignal(
            userId: userId,
            category: category,
            language: language ?? '',
            channelKey: creatorDocKey ?? '',
            channelName: channelName ?? '',
            topicLocations: topicLocations,
            categoryWeight: 1,
            channelWeight: 1,
            languageWeight: 1,
            topicLocationWeight: 1,
          );
        }
      }
    } catch (_) {}
  }

  // --- 2. LIKE (TOGGLE LIKE + AFFINITY +3) ---
  Future<bool> toggleLikeVideo({
    required String videoId,
    required String userId,
    String? channelId,
    String? uploaderEmail,
    String? uploaderId,
    String videoType = 'SHORT',
    String? category,
    String? language,
    String? channelName,
    List<String>? topicLocations, // [BARU]
  }) async {
    if (videoId.isEmpty || userId.isEmpty) return false;

    final videoDocRef = await _resolveVideoDocRef(
      videoId: videoId,
      channelId: channelId,
      uploaderEmail: uploaderEmail,
      uploaderId: uploaderId,
      videoType: videoType,
    );

    if (videoDocRef == null) return false;
    final likeDocRef = videoDocRef.collection(subColLikes).doc(userId);

    final isLikedNow = await _firestore.runTransaction<bool>((transaction) async {
      final likeSnapshot = await transaction.get(likeDocRef);

      if (likeSnapshot.exists) {
        transaction.delete(likeDocRef);
        transaction.update(videoDocRef, {
          'likes_count': FieldValue.increment(-1),
        });
        return false;
      } else {
        transaction.set(likeDocRef, {
          'user_id': userId,
          'created_at': FieldValue.serverTimestamp(),
        });
        transaction.update(videoDocRef, {
          'likes_count': FieldValue.increment(1),
        });
        return true;
      }
    });

    if (isLikedNow && category != null) {
      final channelKey = (channelId != null && channelId.trim().isNotEmpty)
          ? channelId.trim()
          : ((uploaderEmail != null && uploaderEmail.isNotEmpty) ? uploaderEmail : (uploaderId ?? ''));
      recordUserAffinitySignal(
        userId: userId,
        category: category,
        language: language ?? '',
        channelKey: channelKey,
        channelName: channelName ?? '',
        topicLocations: topicLocations,
        categoryWeight: 3,
        channelWeight: 3,
        languageWeight: 2,
        topicLocationWeight: 3,
      );
    }

    return isLikedNow;
  }

  Future<bool> checkIsVideoLiked({
    required String videoId,
    required String userId,
    String? channelId,
    String? uploaderEmail,
    String? uploaderId,
    String videoType = 'SHORT',
  }) async {
    if (videoId.isEmpty || userId.isEmpty) return false;
    try {
      final videoDocRef = await _resolveVideoDocRef(
        videoId: videoId,
        channelId: channelId,
        uploaderEmail: uploaderEmail,
        uploaderId: uploaderId,
        videoType: videoType,
      );
      if (videoDocRef == null) return false;

      final doc = await videoDocRef.collection(subColLikes).doc(userId).get();
      return doc.exists;
    } catch (_) {
      return false;
    }
  }

  // --- 3. SAVE / BOOKMARK (TOGGLE SAVE + AFFINITY +5) ---
  Future<bool> toggleSaveVideo({
    required String videoId,
    required String userId,
    String? channelId,
    String? uploaderEmail,
    String? uploaderId,
    String videoType = 'SHORT',
    String? category,
    String? language,
    String? channelName,
    List<String>? topicLocations, // [BARU]
  }) async {
    if (videoId.isEmpty || userId.isEmpty) return false;

    final videoDocRef = await _resolveVideoDocRef(
      videoId: videoId,
      channelId: channelId,
      uploaderEmail: uploaderEmail,
      uploaderId: uploaderId,
      videoType: videoType,
    );

    final saveDocRef = _firestore
        .collection(colUsers)
        .doc(userId)
        .collection(subColSaves)
        .doc(videoId);

    final isSavedNow = await _firestore.runTransaction<bool>((transaction) async {
      final saveSnapshot = await transaction.get(saveDocRef);

      if (saveSnapshot.exists) {
        transaction.delete(saveDocRef);
        if (videoDocRef != null) {
          transaction.update(videoDocRef, {
            'saves_count': FieldValue.increment(-1),
          });
        }
        return false;
      } else {
        transaction.set(saveDocRef, {
          'video_id': videoId,
          'channel_id': channelId ?? '',
          'uploader_email': uploaderEmail ?? '',
          'uploader_id': uploaderId ?? '',
          'video_type': videoType,
          'saved_at': FieldValue.serverTimestamp(),
        });
        if (videoDocRef != null) {
          transaction.update(videoDocRef, {
            'saves_count': FieldValue.increment(1),
          });
        }
        return true;
      }
    });

    if (isSavedNow && category != null) {
      final channelKey = (channelId != null && channelId.trim().isNotEmpty)
          ? channelId.trim()
          : ((uploaderEmail != null && uploaderEmail.isNotEmpty) ? uploaderEmail : (uploaderId ?? ''));
      recordUserAffinitySignal(
        userId: userId,
        category: category,
        language: language ?? '',
        channelKey: channelKey,
        channelName: channelName ?? '',
        topicLocations: topicLocations,
        categoryWeight: 5,
        channelWeight: 4,
        languageWeight: 3,
        topicLocationWeight: 4,
      );
    }

    return isSavedNow;
  }

  Future<bool> checkIsVideoSaved({
    required String videoId,
    required String userId,
  }) async {
    if (videoId.isEmpty || userId.isEmpty) return false;
    try {
      final doc = await _firestore
          .collection(colUsers)
          .doc(userId)
          .collection(subColSaves)
          .doc(videoId)
          .get();
      return doc.exists;
    } catch (_) {
      return false;
    }
  }

  // --- 4. SHARE (INCREMENT SHARE + AFFINITY +5) ---
  Future<void> incrementShareCount(
    String videoId, {
    String? channelId,
    String? uploaderEmail,
    String? uploaderId,
    String videoType = 'SHORT',
    String? userId,
    String? category,
    String? language,
    String? channelName,
    List<String>? topicLocations, // [BARU]
  }) async {
    if (videoId.isEmpty) return;
    try {
      final videoDocRef = await _resolveVideoDocRef(
        videoId: videoId,
        channelId: channelId,
        uploaderEmail: uploaderEmail,
        uploaderId: uploaderId,
        videoType: videoType,
      );
      if (videoDocRef != null) {
        await videoDocRef.update({
          'shares_count': FieldValue.increment(1),
        });

        if (userId != null && userId.isNotEmpty && category != null) {
          final channelKey = (channelId != null && channelId.trim().isNotEmpty)
              ? channelId.trim()
              : ((uploaderEmail != null && uploaderEmail.isNotEmpty) ? uploaderEmail : (uploaderId ?? ''));
          recordUserAffinitySignal(
            userId: userId,
            category: category,
            language: language ?? '',
            channelKey: channelKey,
            channelName: channelName ?? '',
            topicLocations: topicLocations,
            categoryWeight: 5,
            channelWeight: 5,
            languageWeight: 3,
            topicLocationWeight: 4,
          );
        }
      }
    } catch (_) {}
  }

  // --- 5. FOLLOW CREATOR (AUTO-RESOLVER CERDAS: EMAIL LAMA -> CHANNEL ID RESMI) ---
  Future<bool> toggleFollowCreator({
    required String userId,
    required String creatorKey, // Bisa berupa channelId atau email
    required String channelName,
    String? avatarUrl,
    String? dominantCategory,
    String? preferredLanguage,
    List<String>? preferredTopicLocations, // [BARU]
    String? followerName,
    String? followerAvatar,
    String? followerEmail,
  }) async {
    String effectiveChannelKey = creatorKey.trim();
    if (userId.isEmpty || effectiveChannelKey.isEmpty) return false;

    if (effectiveChannelKey.contains('@')) {
      try {
        final cleanEmail = effectiveChannelKey.toLowerCase();
        final userQuery = await _firestore
            .collection(colUsers)
            .where('email', isEqualTo: cleanEmail)
            .limit(1)
            .get();

        if (userQuery.docs.isNotEmpty) {
          final mappedChannelId = userQuery.docs.first.data()['channel_id']?.toString();
          if (mappedChannelId != null && mappedChannelId.trim().isNotEmpty) {
            effectiveChannelKey = mappedChannelId.trim();
          }
        }
      } catch (_) {}
    }

    final userFollowRef = _firestore
        .collection(colUsers)
        .doc(userId)
        .collection('mytube_following')
        .doc(effectiveChannelKey);

    final creatorFollowerRef = _firestore
        .collection(colMytube)
        .doc(effectiveChannelKey)
        .collection('followers')
        .doc(userId);

    final creatorDocRef = _firestore.collection(colMytube).doc(effectiveChannelKey);

    try {
      final docSnap = await userFollowRef.get();
      final isCurrentlyFollowing = docSnap.exists;

      if (isCurrentlyFollowing) {
        await userFollowRef.delete();
      } else {
        await userFollowRef.set({
          'channel_id': effectiveChannelKey,
          'channel_name': channelName,
          'creator_email': creatorKey.contains('@') ? creatorKey.toLowerCase() : '',
          'avatar_url': avatarUrl ?? '',
          'followed_at': FieldValue.serverTimestamp(),
        });
      }

      try {
        final creatorBatch = _firestore.batch();
        if (isCurrentlyFollowing) {
          creatorBatch.delete(creatorFollowerRef);
          creatorBatch.set(
            creatorDocRef,
            {'total_followers': FieldValue.increment(-1)},
            SetOptions(merge: true),
          );
        } else {
          creatorBatch.set(creatorFollowerRef, {
            'user_id': userId,
            'email': (followerEmail != null && followerEmail.trim().isNotEmpty) ? followerEmail.trim() : '',
            'display_name': (followerName != null && followerName.trim().isNotEmpty)
                ? followerName.trim()
                : 'Pengikut MyTube',
            'avatar_url': followerAvatar ?? '',
            'followed_at': FieldValue.serverTimestamp(),
          });
          creatorBatch.set(
            creatorDocRef,
            {'total_followers': FieldValue.increment(1)},
            SetOptions(merge: true),
          );
        }
        await creatorBatch.commit();
      } catch (creatorErr) {
        print('⚠️ [MYTUBE FOLLOW] Peringatan pencatatan sisi channel: $creatorErr');
      }

      if (!isCurrentlyFollowing) {
        recordUserAffinitySignal(
          userId: userId,
          category: dominantCategory ?? '',
          language: preferredLanguage ?? '',
          channelKey: effectiveChannelKey,
          channelName: channelName,
          topicLocations: preferredTopicLocations,
          categoryWeight: 10,
          channelWeight: 15,
          languageWeight: 5,
          topicLocationWeight: 8,
        );
      }

      return !isCurrentlyFollowing;
    } catch (e) {
      print('❌ [MYTUBE FOLLOW] Gagal toggle follow: $e');
      return false;
    }
  }

  // --- STREAM DAFTAR PENGIKUT SALURAN BERDASARKAN CHANNEL ID ATAU EMAIL ---
  Stream<List<Map<String, dynamic>>> streamCreatorFollowers(String channelOrEmailKey) {
    final cleanKey = channelOrEmailKey.trim();
    if (cleanKey.isEmpty) return Stream.value([]);

    return _firestore
        .collection(colMytube)
        .doc(cleanKey)
        .collection('followers')
        .orderBy('followed_at', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'user_id': data['user_id'] ?? doc.id,
          'email': data['email'] ?? '',
          'display_name': data['display_name'] ?? 'Pengikut MyTube',
          'avatar_url': data['avatar_url'] ?? '',
          'followed_at': data['followed_at'],
        };
      }).toList();
    });
  }

  // --- 6. PEMICU ON-DEMAND SUBTITLE CLOUD FUNCTION (34 BAHASA LAINNYA) ---
  Future<String?> requestOnDemandSubtitle({
    required String videoId,
    required String creatorEmail,
    String? channelId,
    required String videoType,
    required String targetLanguageCode,
    required String targetLanguageName,
  }) async {
    if (videoId.isEmpty || targetLanguageCode.isEmpty) return null;

    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();

      final url = Uri.parse(
        'https://asia-southeast2-majiku-5b07e.cloudfunctions.net/generateSubtitleOnDemand',
      );

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (idToken != null) 'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({
          'data': {
            'videoId': videoId,
            'creatorEmail': creatorEmail,
            'channelId': channelId?.trim() ?? '',
            'videoType': videoType,
            'targetLanguageCode': targetLanguageCode,
            'targetLanguageName': targetLanguageName,
          }
        }),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final result = decoded['result'];
        if (result != null && result['success'] == true) {
          return result['url'] as String?;
        }
      }
    } catch (_) {}
    return null;
  }

  // --- 7. [BARU - MLA DUBBING]: PEMICU ON-DEMAND DUBBING AUDIO CLOUD FUNCTION ---
  Future<Map<String, dynamic>?> requestOnDemandDubbing({
    required String videoId,
    required String creatorEmail,
    String? channelId,
    required String videoType,
    required String targetLanguageCode,
    required String targetLanguageName,
  }) async {
    if (videoId.isEmpty || targetLanguageCode.isEmpty) return null;

    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();

      final url = Uri.parse(
        'https://asia-southeast2-majiku-5b07e.cloudfunctions.net/generateDubbingOnDemand',
      );

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (idToken != null) 'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({
          'data': {
            'videoId': videoId,
            'creatorEmail': creatorEmail,
            'channelId': channelId?.trim() ?? '',
            'videoType': videoType,
            'targetLanguageCode': targetLanguageCode,
            'targetLanguageName': targetLanguageName,
          }
        }),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final result = decoded['result'];
        if (result != null && result['success'] == true) {
          return {
            'url': result['url'] as String?,
            'isOriginal': result['isOriginal'] == true,
          };
        }
      }
    } catch (_) {}
    return null;
  }
//............................................................................//

//No ke-8....................................................................//
//COMMENT ENGINE & LIFECYCLE DELETION                                        //
  Stream<List<CommentMytubeModel>> getCommentsStream(
    String videoId, {
    String? channelId,
    String? uploaderEmail,
    String? uploaderId,
    String videoType = 'SHORT',
  }) {
    if (videoId.isEmpty) return Stream.value([]);
    
    // [HIBRIDA]: Prioritas channelId -> Fallback email -> Fallback uploaderId
    final creatorKey = (channelId != null && channelId.trim().isNotEmpty)
        ? channelId.trim()
        : ((uploaderEmail != null && uploaderEmail.isNotEmpty)
            ? uploaderEmail.trim().toLowerCase()
            : uploaderId);

    if (creatorKey != null && creatorKey.isNotEmpty) {
      final subCol = videoType.toUpperCase() == 'LONG' ? subColLongVideo : subColShortVideo;
      return _firestore
          .collection(colMytube)
          .doc(creatorKey)
          .collection(subCol)
          .doc(videoId)
          .collection(subColComments)
          .orderBy('created_at', descending: true)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs
            .map((doc) => CommentMytubeModel.fromFirestore(doc))
            .toList();
      });
    }

    return Stream.value([]);
  }

  Future<void> addComment({
    required String videoId,
    required CommentMytubeModel comment,
    String? channelId,
    String? uploaderEmail,
    String? uploaderId,
    String videoType = 'SHORT',
  }) async {
    if (videoId.isEmpty) return;

    final videoDocRef = await _resolveVideoDocRef(
      videoId: videoId,
      channelId: channelId,
      uploaderEmail: uploaderEmail,
      uploaderId: uploaderId,
      videoType: videoType,
    );

    if (videoDocRef == null) return;
    final commentDocRef = videoDocRef.collection(subColComments).doc();
    final commentData = comment.copyWith(id: commentDocRef.id).toMap();

    final batch = _firestore.batch();
    batch.set(commentDocRef, commentData);
    batch.update(videoDocRef, {
      'comments_count': FieldValue.increment(1),
    });

    await batch.commit();
  }

  Future<void> deleteVideoPost({
    required String videoId,
    required String creatorKey, // Bisa berupa channelId atau email
    String videoType = 'SHORT',
  }) async {
    if (videoId.isEmpty || creatorKey.isEmpty) return;
    try {
      final cleanKey = creatorKey.trim();
      final subCol = videoType.toUpperCase() == 'LONG' ? subColLongVideo : subColShortVideo;
      
      // Coba hapus langsung dari path channelId atau email
      final docRef = _firestore.collection(colMytube).doc(cleanKey).collection(subCol).doc(videoId);
      final snap = await docRef.get();

      if (snap.exists) {
        await docRef.delete();
        final fieldToDecrement = videoType.toUpperCase() == 'LONG' ? 'total_longs' : 'total_shorts';
        await _firestore.collection(colMytube).doc(cleanKey).update({
          fieldToDecrement: FieldValue.increment(-1),
          'total_videos': FieldValue.increment(-1),
          'updated_at': FieldValue.serverTimestamp(),
        });
      } else {
        // Fallback resolver jika creatorKey adalah email tapi video sudah di channelId, atau sebaliknya
        final resolvedRef = await _resolveVideoDocRef(videoId: videoId, videoType: videoType);
        if (resolvedRef != null) {
          final parentDocKey = resolvedRef.parent.parent?.id;
          await resolvedRef.delete();
          if (parentDocKey != null && parentDocKey.isNotEmpty) {
            final fieldToDecrement = videoType.toUpperCase() == 'LONG' ? 'total_longs' : 'total_shorts';
            await _firestore.collection(colMytube).doc(parentDocKey).update({
              fieldToDecrement: FieldValue.increment(-1),
              'total_videos': FieldValue.increment(-1),
              'updated_at': FieldValue.serverTimestamp(),
            });
          }
        }
      }
    } catch (_) {}
  }
//............................................................................//

//No ke-9....................................................................//
//MODERATION & APPROVAL ENGINE (PERMOHONAN CREATOR VS EKSEKUSI ADMIN PUSAT)  //
  // 1. Creator Mengajukan Permohonan Edit Video (Judul, Kategori, Bahasa, Lokasi)
  Future<void> submitEditRequest({
    required VideoMytubeModel currentVideo,
    required String newTitle,
    required String newCategory,
    required String newLanguage,
    List<String>? newTargetLocations,
  }) async {
    final docRef = _firestore.collection(colRequests).doc();

    final request = RequestMytubeModel(
      id: docRef.id,
      requestType: 'EDIT',
      status: 'PENDING',
      videoId: currentVideo.id,
      channelId: currentVideo.channelId,
      videoType: currentVideo.videoType,
      videoUrl: currentVideo.streamingUrl, // Link aktif agar Admin Pusat bisa memutar video
      thumbnailUrl: currentVideo.thumbnailUrl,
      videoTitle: currentVideo.title,
      creatorEmail: currentVideo.uploaderEmail,
      creatorId: currentVideo.uploaderId,
      channelName: currentVideo.channelName,
      oldTitle: currentVideo.title,
      newTitle: newTitle,
      oldCategory: currentVideo.category,
      newCategory: newCategory,
      oldLanguage: currentVideo.language,
      newLanguage: newLanguage,
      oldTargetLocations: currentVideo.targetLocations,
      newTargetLocations: newTargetLocations ?? currentVideo.targetLocations,
      createdAt: DateTime.now(),
    );

    await docRef.set(request.toMap());
  }

  // 2. Creator Mengajukan Permohonan Hapus Video
  Future<void> submitDeleteRequest({
    required VideoMytubeModel currentVideo,
    String? reason,
  }) async {
    final docRef = _firestore.collection(colRequests).doc();

    final request = RequestMytubeModel(
      id: docRef.id,
      requestType: 'DELETE',
      status: 'PENDING',
      videoId: currentVideo.id,
      channelId: currentVideo.channelId,
      videoType: currentVideo.videoType,
      videoUrl: currentVideo.streamingUrl, // Link aktif agar Admin Pusat bisa memutar video
      thumbnailUrl: currentVideo.thumbnailUrl,
      videoTitle: currentVideo.title,
      creatorEmail: currentVideo.uploaderEmail,
      creatorId: currentVideo.uploaderId,
      channelName: currentVideo.channelName,
      deleteReason: reason ?? 'Permohonan penghapusan oleh kreator',
      createdAt: DateTime.now(),
    );

    await docRef.set(request.toMap());
  }

  // 3. Admin Pusat Membaca Daftar Permohonan (Pending / All)
  Stream<List<RequestMytubeModel>> streamRequests({String? statusFilter}) {
    Query query = _firestore.collection(colRequests).orderBy('created_at', descending: true);

    if (statusFilter != null && statusFilter.isNotEmpty) {
      query = query.where('status', isEqualTo: statusFilter);
    }

    return query.snapshots().map((snap) => snap.docs
        .map((doc) => RequestMytubeModel.fromFirestore(doc))
        .toList());
  }

  // 4. Admin Pusat Menyetujui Permohonan (APPROVE)
  Future<void> approveRequest(
    RequestMytubeModel request, {
    required String adminEmail,
  }) async {
    // [HIBRIDA]: Cari dokumen video via channelId terlebih dahulu, fallback ke creatorEmail
    final docRef = await _resolveVideoDocRef(
      videoId: request.videoId,
      channelId: request.channelId,
      uploaderEmail: request.creatorEmail,
      uploaderId: request.creatorId,
      videoType: request.videoType,
    );

    if (request.requestType == 'EDIT') {
      if (docRef != null) {
        final Map<String, dynamic> updateMap = {
          'title': request.newTitle ?? request.oldTitle,
          'category': request.newCategory ?? request.oldCategory,
          'language': request.newLanguage ?? request.oldLanguage,
          'updated_at': FieldValue.serverTimestamp(),
        };

        // Sinkronisasi pembaruan lokasi ke dokumen video
        if (request.newTargetLocations != null && request.newTargetLocations!.isNotEmpty) {
          updateMap['target_locations'] = request.newTargetLocations;
        }

        await docRef.update(updateMap);
      }
    } else if (request.requestType == 'DELETE') {
      final keyForDelete = request.channelId.isNotEmpty
          ? request.channelId
          : request.creatorEmail;
          
      await deleteVideoPost(
        videoId: request.videoId,
        creatorKey: keyForDelete,
        videoType: request.videoType,
      );
    }

    // Tandai status permohonan menjadi 'APPROVED'
    await _firestore.collection(colRequests).doc(request.id).update({
      'status': 'APPROVED',
      'reviewed_by': adminEmail,
      'reviewed_at': FieldValue.serverTimestamp(),
    });
  }

  // 5. Admin Pusat Menolak Permohonan (REJECT)
  Future<void> rejectRequest(
    String requestId, {
    required String adminEmail,
    String? rejectReason,
  }) async {
    await _firestore.collection(colRequests).doc(requestId).update({
      'status': 'REJECTED',
      'admin_notes': rejectReason ?? 'Permohonan ditolak oleh Admin Pusat',
      'reviewed_by': adminEmail,
      'reviewed_at': FieldValue.serverTimestamp(),
    });
  }
//............................................................................//

//No ke-10...................................................................//
//USER ACCOUNT UPGRADE & TIER MANAGEMENT (ADMIN PUSAT & CHANNEL GOVERNANCE)  //
  // 1. Mencari Akun Pengguna Berdasarkan Email
  Future<Map<String, dynamic>?> findUserByEmail(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty) return null;

    try {
      final querySnap = await _firestore
          .collection(colUsers)
          .where('email', isEqualTo: cleanEmail)
          .limit(1)
          .get();

      if (querySnap.docs.isNotEmpty) {
        final doc = querySnap.docs.first;
        final data = doc.data();
        return {
          'uid': doc.id,
          'email': data['email'] ?? cleanEmail,
          'displayName': data['displayName'] ?? 'Pengguna',
          'userTier': data['userTier']?.toString().toLowerCase() ?? 'free',
          'role': data['role']?.toString().toLowerCase() ?? 'user',
          'channel_id': data['channel_id'] ?? '',
          'previous_tier': data['previous_tier'] ?? 'free',
          'created_at': data['createdAt'] ?? data['updatedAt'],
        };
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // 2. [FITUR EKSKLUSIF ADMIN]: Inisialisasi Channel ID Milik Admin Sendiri
  Future<Map<String, dynamic>> createOrGetAdminOwnChannel({
    required String adminUid,
    required String adminEmail,
    String? displayName,
  }) async {
    final cleanEmail = adminEmail.trim().toLowerCase();
    if (adminUid.isEmpty) {
      return {'success': false, 'message': 'UID Admin tidak valid.'};
    }

    try {
      final userDoc = await _firestore.collection(colUsers).doc(adminUid).get();
      String channelId = userDoc.data()?['channel_id']?.toString() ?? '';

      if (channelId.isNotEmpty) {
        return {
          'success': true,
          'channelId': channelId,
          'isNew': false,
          'message': 'Channel Admin sudah aktif.',
        };
      }

      channelId = _firestore.collection(colMytube).doc().id;

      final batch = _firestore.batch();

      batch.set(
        _firestore.collection(colUsers).doc(adminUid),
        {
          'channel_id': channelId,
          'userTier': 'admin',
          'role': 'admin',
          'is_mytube_admin': true,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      final rawHandle = cleanEmail.contains('@') ? cleanEmail.split('@')[0] : 'admin';
      batch.set(
        _firestore.collection(colMytube).doc(channelId),
        {
          'channel_id': channelId,
          'creator_id': adminUid,
          'email': cleanEmail,
          'channel_name': displayName ?? 'Admin Official',
          'handle': '@$rawHandle',
          'is_verified': true,
          'is_admin_channel': true,
          'created_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      await batch.commit();
      return {
        'success': true,
        'channelId': channelId,
        'isNew': true,
        'message': 'Channel Admin resmi berhasil diaktifkan!',
      };
    } catch (e) {
      return {'success': false, 'message': 'Gagal membuat Channel Admin: $e'};
    }
  }

  // 3. Meningkatkan Status Akun Menjadi "creator" (Daftarkan Channel Baru)
  Future<bool> upgradeUserToCreator(
    String targetUserId, {
    required String targetEmail,
    String? displayName,
  }) async {
    final cleanEmail = targetEmail.trim().toLowerCase();
    if (targetUserId.isEmpty || cleanEmail.isEmpty) return false;

    try {
      final userDoc = await _firestore.collection(colUsers).doc(targetUserId).get();
      final currentTier = userDoc.data()?['userTier']?.toString().toLowerCase() ?? 'free';
      String channelId = userDoc.data()?['channel_id']?.toString() ?? '';

      if (channelId.isEmpty) {
        channelId = _firestore.collection(colMytube).doc().id;
      }

      final batch = _firestore.batch();

      final userRef = _firestore.collection(colUsers).doc(targetUserId);
      batch.set(
        userRef,
        {
          'userTier': 'creator',
          'role': 'creator',
          'previous_tier': currentTier,
          'channel_id': channelId,
          'is_mytube_admin': false,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      final creatorRef = _firestore.collection(colMytube).doc(channelId);
      final rawHandle = cleanEmail.split('@')[0];

      batch.set(
        creatorRef,
        {
          'channel_id': channelId,
          'creator_id': targetUserId,
          'email': cleanEmail,
          'channel_name': displayName ?? 'Kreator Baru',
          'handle': '@$rawHandle',
          'is_verified': true,
          'created_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      await batch.commit();
      return true;
    } catch (e) {
      return false;
    }
  }

  // 4. [CABUT STATUS KE FREE]: Data Channel & Video Tetap Utuh (Hanya Ditangguhkan)
  Future<bool> downgradeUserToFree(
    String targetUserId, {
    required String targetEmail,
  }) async {
    final cleanEmail = targetEmail.trim().toLowerCase();
    if (targetUserId.isEmpty) return false;

    try {
      final userDoc = await _firestore.collection(colUsers).doc(targetUserId).get();
      final currentTier = userDoc.data()?['userTier']?.toString().toLowerCase() ?? 'creator';
      final channelId = userDoc.data()?['channel_id']?.toString() ?? '';

      final batch = _firestore.batch();

      // 1. Cabut hak akses login user ke creator studio (kembalikan ke free)
      final userRef = _firestore.collection(colUsers).doc(targetUserId);
      batch.set(userRef, {
        'userTier': 'free',
        'role': 'user',
        'previous_tier': currentTier,
        'channel_id': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 2. Data Saluran mytube/{channelId} TIDAK DIHAPUS, melainkan ditandai non-aktif
      final docKey = channelId.isNotEmpty ? channelId : cleanEmail;
      if (docKey.isNotEmpty) {
        final creatorRef = _firestore.collection(colMytube).doc(docKey);
        batch.set(
          creatorRef,
          {
            'is_verified': false,
            'status_note': 'Akses saluran ditangguhkan oleh Admin',
            'updated_at': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      await batch.commit();
      return true;
    } catch (e) {
      return false;
    }
  }

  // 5. [REAKTIVASI SALURAN]: Mengaktifkan Kembali Saluran Non-Aktif untuk Email yang Sama
  Future<Map<String, dynamic>> reactivateChannel({
    required String channelId,
    required String email,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    if (channelId.isEmpty || cleanEmail.isEmpty) {
      return {'success': false, 'message': 'Parameter tidak valid.'};
    }

    try {
      // 1. Cari user di collection users
      final userQuery = await _firestore
          .collection(colUsers)
          .where('email', isEqualTo: cleanEmail)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) {
        return {
          'success': false,
          'message': 'Akun dengan email "$cleanEmail" belum terdaftar di sistem Majiku.',
        };
      }

      final userDoc = userQuery.docs.first;
      final uid = userDoc.id;

      final batch = _firestore.batch();

      // 2. Kembalikan status user menjadi creator dan pasang kembali channel_id
      batch.set(_firestore.collection(colUsers).doc(uid), {
        'userTier': 'creator',
        'role': 'creator',
        'channel_id': channelId,
        'previous_tier': 'free',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 3. Aktifkan kembali saluran di mytube/{channelId}
      batch.set(_firestore.collection(colMytube).doc(channelId), {
        'is_verified': true,
        'creator_id': uid,
        'email': cleanEmail,
        'status_note': FieldValue.delete(),
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await batch.commit();
      return {
        'success': true,
        'message': 'Saluran $channelId berhasil diaktifkan kembali untuk $cleanEmail!',
      };
    } catch (e) {
      return {'success': false, 'message': 'Gagal mengaktifkan saluran: $e'};
    }
  }

  // 6. [PERGANTIAN PETUGAS KREATOR]: Alihkan Saluran & Aktifkan ke Email Petugas Baru
  Future<Map<String, dynamic>> transferChannelOwnership({
    required String channelId,
    required String newEmail,
    required String oldEmail,
  }) async {
    final cleanNew = newEmail.trim().toLowerCase();
    final cleanOld = oldEmail.trim().toLowerCase();

    if (channelId.isEmpty || cleanNew.isEmpty) {
      return {'success': false, 'message': 'Parameter tidak valid.'};
    }
    if (cleanNew == cleanOld) {
      return {'success': false, 'message': 'Email baru tidak boleh sama dengan email lama.'};
    }

    try {
      final newUserQuery = await _firestore
          .collection(colUsers)
          .where('email', isEqualTo: cleanNew)
          .limit(1)
          .get();

      if (newUserQuery.docs.isEmpty) {
        return {
          'success': false,
          'message': 'Akun dengan email "$cleanNew" belum terdaftar di sistem Majiku.',
        };
      }

      final newUserDoc = newUserQuery.docs.first;
      final newUid = newUserDoc.id;
      final newUserData = newUserDoc.data();
      final String newPrevTier = newUserData['userTier']?.toString().toLowerCase() ?? 'free';

      String? oldUid;
      if (cleanOld.isNotEmpty) {
        final oldUserQuery = await _firestore
            .collection(colUsers)
            .where('email', isEqualTo: cleanOld)
            .limit(1)
            .get();
        if (oldUserQuery.docs.isNotEmpty) {
          oldUid = oldUserQuery.docs.first.id;
        }
      }

      final batch = _firestore.batch();

      // Berikan hak akses channel ke user baru & ubah menjadi creator
      batch.set(_firestore.collection(colUsers).doc(newUid), {
        'userTier': 'creator',
        'role': 'creator',
        'channel_id': channelId,
        'previous_tier': newPrevTier,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Cabut hak akses dari user lama jika ada
      if (oldUid != null && oldUid != newUid) {
        batch.set(_firestore.collection(colUsers).doc(oldUid), {
          'userTier': 'free',
          'role': 'user',
          'previous_tier': 'creator',
          'channel_id': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      // Perbarui dokumen mytube/{channelId} dan pastikan terverifikasi aktif
      batch.set(_firestore.collection(colMytube).doc(channelId), {
        'email': cleanNew,
        'creator_id': newUid,
        'transferred_from': cleanOld,
        'transferred_at': FieldValue.serverTimestamp(),
        'is_verified': true,
        'status_note': FieldValue.delete(),
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await batch.commit();
      return {
        'success': true,
        'message': 'Saluran berhasil dialihkan & diaktifkan untuk $cleanNew!',
      };
    } catch (e) {
      return {'success': false, 'message': 'Gagal mengalihkan saluran: $e'};
    }
  }

  // 7. [REALTIME STREAM]: Daftar Admin Pusat Aktif
  Stream<List<Map<String, dynamic>>> streamActiveAdmins() {
    return _firestore
        .collection(colUsers)
        .where('role', isEqualTo: 'admin')
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final d = doc.data();
              return {
                'uid': doc.id,
                'email': d['email'] ?? '-',
                'displayName': d['displayName'] ?? 'Admin Pusat',
                'userTier': d['userTier'] ?? 'admin',
                'role': d['role'] ?? 'admin',
                'channel_id': d['channel_id'] ?? '',
                'created_at': d['createdAt'] ?? d['updatedAt'],
              };
            }).toList());
  }

  // 8. [REALTIME STREAM]: Daftar Kreator Aktif Sedang Bertugas
  Stream<List<Map<String, dynamic>>> streamActiveCreators() {
    return _firestore
        .collection(colUsers)
        .where('userTier', isEqualTo: 'creator')
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final d = doc.data();
              return {
                'uid': doc.id,
                'email': d['email'] ?? '-',
                'displayName': d['displayName'] ?? 'Creator',
                'userTier': d['userTier'] ?? 'creator',
                'role': d['role'] ?? 'creator',
                'previous_tier': d['previous_tier'] ?? 'free',
                'channel_id': d['channel_id'] ?? '',
                'created_at': d['createdAt'] ?? d['updatedAt'],
                'updatedAt': d['updatedAt'],
              };
            }).toList());
  }

  // 9. [BARU - REALTIME STREAM]: Daftar Seluruh Saluran Non-Aktif / Terdata (Aset Perusahaan)
  Stream<List<Map<String, dynamic>>> streamInactiveChannels() {
    return _firestore
        .collection(colMytube)
        .where('is_verified', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final d = doc.data();
              return {
                'channel_id': d['channel_id'] ?? doc.id,
                'email': d['email'] ?? '-',
                'channel_name': d['channel_name'] ?? 'Saluran Non-Aktif',
                'handle': d['handle'] ?? '',
                'creator_id': d['creator_id'] ?? '',
                'is_verified': d['is_verified'] ?? false,
                'status_note': d['status_note'] ?? 'Akses saluran ditangguhkan',
                'created_at': d['created_at'] ?? d['updated_at'],
                'updated_at': d['updated_at'],
              };
            }).toList());
  }

  // Helper Traversal Rekursif Penghapusan Folder di Firebase Storage
  Future<void> _deleteStorageFolderRecursively(Reference ref) async {
    try {
      final listResult = await ref.listAll();
      for (final item in listResult.items) {
        try {
          await item.delete();
        } catch (_) {}
      }
      for (final prefix in listResult.prefixes) {
        await _deleteStorageFolderRecursively(prefix);
      }
    } catch (_) {}
  }

  // 10. [HAPUS SALURAN PERMANEN]: Menghapus Bersih Storage & Data Firestore Tanpa Menghapus User Auth
  Future<Map<String, dynamic>> deleteChannelPermanently({
    required String channelId,
    required String email,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanChannelId = channelId.trim();

    if (cleanChannelId.isEmpty && cleanEmail.isEmpty) {
      return {'success': false, 'message': 'Parameter Channel ID atau Email tidak valid.'};
    }

    try {
      final storage = FirebaseStorage.instance;

      // A. PEMBERSIHAN CLOUD STORAGE REKURSIF (Video, HLS, TS segments, Thumbnails, Subtitles)
      if (cleanEmail.isNotEmpty) {
        final emailStorageRef = storage.ref('mytube/$cleanEmail');
        await _deleteStorageFolderRecursively(emailStorageRef);
      }
      if (cleanChannelId.isNotEmpty && cleanChannelId != cleanEmail) {
        final channelStorageRef = storage.ref('mytube/$cleanChannelId');
        await _deleteStorageFolderRecursively(channelStorageRef);
      }

      // B. PEMBERSIHAN DATA VIDEO & SUBKOLEKSI DI FIRESTORE
      final List<String> channelKeysToClean = [];
      if (cleanChannelId.isNotEmpty) channelKeysToClean.add(cleanChannelId);
      if (cleanEmail.isNotEmpty && !channelKeysToClean.contains(cleanEmail)) channelKeysToClean.add(cleanEmail);

      for (final key in channelKeysToClean) {
        final channelDocRef = _firestore.collection(colMytube).doc(key);

        // Hapus Subkoleksi Short Videos & Komentar/Likes di dalamnya
        final shortsSnap = await channelDocRef.collection(subColShortVideo).get();
        for (final doc in shortsSnap.docs) {
          final commentsSnap = await doc.reference.collection(subColComments).get();
          for (final c in commentsSnap.docs) {
            await c.reference.delete();
          }
          final likesSnap = await doc.reference.collection(subColLikes).get();
          for (final l in likesSnap.docs) {
            await l.reference.delete();
          }
          await doc.reference.delete();
        }

        // Hapus Subkoleksi Long Videos & Komentar/Likes di dalamnya
        final longsSnap = await channelDocRef.collection(subColLongVideo).get();
        for (final doc in longsSnap.docs) {
          final commentsSnap = await doc.reference.collection(subColComments).get();
          for (final c in commentsSnap.docs) {
            await c.reference.delete();
          }
          final likesSnap = await doc.reference.collection(subColLikes).get();
          for (final l in likesSnap.docs) {
            await l.reference.delete();
          }
          await doc.reference.delete();
        }

        // Hapus Subkoleksi Followers
        final followersSnap = await channelDocRef.collection('followers').get();
        for (final f in followersSnap.docs) {
          await f.reference.delete();
        }

        // Hapus Dokumen Utama Channel di mytube/{key}
        await channelDocRef.delete();
      }

      // Hapus permohonan antrean moderasi terkait di mytube_requests
      if (cleanEmail.isNotEmpty) {
        final reqSnap = await _firestore
            .collection(colRequests)
            .where('creatorEmail', isEqualTo: cleanEmail)
            .get();
        for (final req in reqSnap.docs) {
          await req.reference.delete();
        }
      }

      // C. MENETRALISIR FIELD PENGGUNA DI USERS (AUTH UID & EMAIL TETAP AMAN / TIDAK DIHAPUS)
      if (cleanEmail.isNotEmpty) {
        final userQuery = await _firestore
            .collection(colUsers)
            .where('email', isEqualTo: cleanEmail)
            .limit(1)
            .get();

        if (userQuery.docs.isNotEmpty) {
          final userDoc = userQuery.docs.first;
          await _firestore.collection(colUsers).doc(userDoc.id).set({
            'channel_id': FieldValue.delete(),
            'userTier': 'free',
            'role': 'user',
            'is_mytube_admin': false,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      }

      return {
        'success': true,
        'message': 'Saluran, berkas Cloud Storage, dan data Firestore berhasil dihapus bersih!',
      };
    } catch (e) {
      return {'success': false, 'message': 'Gagal menghapus saluran: $e'};
    }
  }
} // <--- PENUTUP RESMI KELAS FirestoreMytubeService
//............................................................................//