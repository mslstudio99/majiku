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
//CREATOR PROFILE MANAGEMENT (mytube/{creatorEmail})                         //
  Future<CreatorMytubeModel?> getCreatorProfile(String email, {String? userId}) async {
    final cleanKey = email.trim().toLowerCase();
    if (cleanKey.isEmpty && (userId == null || userId.isEmpty)) return null;

    try {
      if (cleanKey.isNotEmpty) {
        final doc = await _firestore.collection(colMytube).doc(cleanKey).get();
        if (doc.exists) {
          return CreatorMytubeModel.fromFirestore(doc);
        }
      }
      if (userId != null && userId.isNotEmpty) {
        final doc = await _firestore.collection(colMytube).doc(userId).get();
        if (doc.exists) {
          return CreatorMytubeModel.fromFirestore(doc);
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Stream<CreatorMytubeModel?> streamCreatorProfile(String email, {String? userId}) {
    final cleanKey = email.trim().toLowerCase().isNotEmpty ? email.trim().toLowerCase() : (userId ?? '');
    if (cleanKey.isEmpty) return Stream.value(null);

    return _firestore.collection(colMytube).doc(cleanKey).snapshots().map((doc) {
      if (doc.exists) {
        return CreatorMytubeModel.fromFirestore(doc);
      }
      return null;
    });
  }

  Future<void> saveCreatorProfile(CreatorMytubeModel creator) async {
    final cleanEmail = creator.email.trim().toLowerCase();
    final docKey = cleanEmail.isNotEmpty ? cleanEmail : creator.id;
    if (docKey.isEmpty) return;

    await _firestore.collection(colMytube).doc(docKey).set(
          {
            ...creator.toMap(),
            'creator_id': creator.id,
          },
          SetOptions(merge: true),
        );
  }
//............................................................................//

//No ke-5....................................................................//
//VIDEO CREATION (mytube/{creatorEmail}/short_video/{titleSlug-uniqueSuffix})//
  Future<String> createVideoPost(VideoMytubeModel video) async {
    final creatorKey = video.uploaderEmail.trim().toLowerCase().isNotEmpty
        ? video.uploaderEmail.trim().toLowerCase()
        : video.uploaderId;

    if (creatorKey.isEmpty) throw Exception('Email atau UID uploader tidak boleh kosong.');

    final isLong = video.videoType.toUpperCase() == 'LONG';
    final targetSubCol = isLong ? subColLongVideo : subColShortVideo;

    final docRef = video.id.isNotEmpty
        ? _firestore.collection(colMytube).doc(creatorKey).collection(targetSubCol).doc(video.id)
        : _firestore.collection(colMytube).doc(creatorKey).collection(targetSubCol).doc();

    // [INISIALISASI HLS V2]: Mengunci skema multi-bitrate sejak data pertama kali disimpan
    final modelWithId = video.copyWith(
      id: docRef.id,
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
    String? uploaderEmail,
    String? uploaderId,
    int limit = 50,
  }) {
    final isLong = videoType.toUpperCase() == 'LONG';
    final subCol = isLong ? subColLongVideo : subColShortVideo;
    final creatorKey = (uploaderEmail != null && uploaderEmail.isNotEmpty)
        ? uploaderEmail.trim().toLowerCase()
        : uploaderId;

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

  Future<DocumentReference?> _resolveVideoDocRef({
    required String videoId,
    String? uploaderEmail,
    String? uploaderId,
    String videoType = 'SHORT',
  }) async {
    final subCol = videoType.toUpperCase() == 'LONG' ? subColLongVideo : subColShortVideo;
    final creatorKey = (uploaderEmail != null && uploaderEmail.isNotEmpty)
        ? uploaderEmail.trim().toLowerCase()
        : uploaderId;

    if (creatorKey != null && creatorKey.isNotEmpty) {
      return _firestore.collection(colMytube).doc(creatorKey).collection(subCol).doc(videoId);
    }

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
    String? uploaderEmail,
    String? uploaderId,
    String videoType = 'SHORT',
  }) async {
    try {
      final docRef = await _resolveVideoDocRef(
        videoId: videoId,
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
    int categoryWeight = 1,
    int channelWeight = 1,
    int languageWeight = 1,
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

      await tasteDocRef.set(updateData, SetOptions(merge: true));
    } catch (_) {}
  }

  // --- 1. TAYANGAN (VIEW COUNT + AFFINITY) ---
  Future<void> incrementViewCount(
    String videoId, {
    String? uploaderEmail,
    String? uploaderId,
    String videoType = 'SHORT',
    String? userId,
    String? category,
    String? language,
    String? channelName,
  }) async {
    if (videoId.isEmpty) return;
    try {
      final docRef = await _resolveVideoDocRef(
        videoId: videoId,
        uploaderEmail: uploaderEmail,
        uploaderId: uploaderId,
        videoType: videoType,
      );

      if (docRef != null) {
        await docRef.update({
          'views_count': FieldValue.increment(1),
        });

        final creatorDocKey = uploaderEmail?.trim().toLowerCase() ?? docRef.parent.parent?.id;
        if (creatorDocKey != null && creatorDocKey.isNotEmpty) {
          await _firestore.collection(colMytube).doc(creatorDocKey).update({
            'total_views': FieldValue.increment(1),
          });
        }

        if (userId != null && userId.isNotEmpty && category != null) {
          recordUserAffinitySignal(
            userId: userId,
            category: category,
            language: language ?? '',
            channelKey: creatorDocKey ?? '',
            channelName: channelName ?? '',
            categoryWeight: 1,
            channelWeight: 1,
            languageWeight: 1,
          );
        }
      }
    } catch (_) {}
  }

  // --- 2. LIKE (TOGGLE LIKE + AFFINITY +3) ---
  Future<bool> toggleLikeVideo({
    required String videoId,
    required String userId,
    String? uploaderEmail,
    String? uploaderId,
    String videoType = 'SHORT',
    String? category,
    String? language,
    String? channelName,
  }) async {
    if (videoId.isEmpty || userId.isEmpty) return false;

    final videoDocRef = await _resolveVideoDocRef(
      videoId: videoId,
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
      final channelKey = (uploaderEmail != null && uploaderEmail.isNotEmpty) ? uploaderEmail : (uploaderId ?? '');
      recordUserAffinitySignal(
        userId: userId,
        category: category,
        language: language ?? '',
        channelKey: channelKey,
        channelName: channelName ?? '',
        categoryWeight: 3,
        channelWeight: 3,
        languageWeight: 2,
      );
    }

    return isLikedNow;
  }

  Future<bool> checkIsVideoLiked({
    required String videoId,
    required String userId,
    String? uploaderEmail,
    String? uploaderId,
    String videoType = 'SHORT',
  }) async {
    if (videoId.isEmpty || userId.isEmpty) return false;
    try {
      final videoDocRef = await _resolveVideoDocRef(
        videoId: videoId,
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
    String? uploaderEmail,
    String? uploaderId,
    String videoType = 'SHORT',
    String? category,
    String? language,
    String? channelName,
  }) async {
    if (videoId.isEmpty || userId.isEmpty) return false;

    final videoDocRef = await _resolveVideoDocRef(
      videoId: videoId,
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
      final channelKey = (uploaderEmail != null && uploaderEmail.isNotEmpty) ? uploaderEmail : (uploaderId ?? '');
      recordUserAffinitySignal(
        userId: userId,
        category: category,
        language: language ?? '',
        channelKey: channelKey,
        channelName: channelName ?? '',
        categoryWeight: 5,
        channelWeight: 4,
        languageWeight: 3,
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
    String? uploaderEmail,
    String? uploaderId,
    String videoType = 'SHORT',
    String? userId,
    String? category,
    String? language,
    String? channelName,
  }) async {
    if (videoId.isEmpty) return;
    try {
      final videoDocRef = await _resolveVideoDocRef(
        videoId: videoId,
        uploaderEmail: uploaderEmail,
        uploaderId: uploaderId,
        videoType: videoType,
      );
      if (videoDocRef != null) {
        await videoDocRef.update({
          'shares_count': FieldValue.increment(1),
        });

        if (userId != null && userId.isNotEmpty && category != null) {
          final channelKey = (uploaderEmail != null && uploaderEmail.isNotEmpty) ? uploaderEmail : (uploaderId ?? '');
          recordUserAffinitySignal(
            userId: userId,
            category: category,
            language: language ?? '',
            channelKey: channelKey,
            channelName: channelName ?? '',
            categoryWeight: 5,
            channelWeight: 5,
            languageWeight: 3,
          );
        }
      }
    } catch (_) {}
  }

  // --- 5. FOLLOW CREATOR (DUAL-SIDED + DECOUPLED WRITE + EMAIL RECORDING) ---
  Future<bool> toggleFollowCreator({
    required String userId,
    required String creatorKey,
    required String channelName,
    String? avatarUrl,
    String? dominantCategory,
    String? preferredLanguage,
    String? followerName,
    String? followerAvatar,
    String? followerEmail,
  }) async {
    final cleanCreatorKey = creatorKey.trim().toLowerCase();
    if (userId.isEmpty || cleanCreatorKey.isEmpty) return false;

    final userFollowRef = _firestore
        .collection(colUsers)
        .doc(userId)
        .collection('mytube_following')
        .doc(cleanCreatorKey);

    final creatorFollowerRef = _firestore
        .collection(colMytube)
        .doc(cleanCreatorKey)
        .collection('followers')
        .doc(userId);

    final creatorDocRef = _firestore.collection(colMytube).doc(cleanCreatorKey);

    try {
      final docSnap = await userFollowRef.get();
      final isCurrentlyFollowing = docSnap.exists;

      // 1. Prioritas penulisan sisi Pengguna
      if (isCurrentlyFollowing) {
        await userFollowRef.delete();
      } else {
        await userFollowRef.set({
          'channel_name': channelName,
          'creator_email': cleanCreatorKey,
          'avatar_url': avatarUrl ?? '',
          'followed_at': FieldValue.serverTimestamp(),
        });
      }

      // 2. Pembaruan sisi Creator (Penyimpanan Data Email Lengkap)
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
        print('⚠️ [MYTUBE FOLLOW] Peringatan pencatatan sisi creator: $creatorErr');
      }

      // 3. Rekam Minat Algoritma
      if (!isCurrentlyFollowing) {
        recordUserAffinitySignal(
          userId: userId,
          category: dominantCategory ?? '',
          language: preferredLanguage ?? '',
          channelKey: cleanCreatorKey,
          channelName: channelName,
          categoryWeight: 10,
          channelWeight: 15,
          languageWeight: 5,
        );
      }

      return !isCurrentlyFollowing;
    } catch (e) {
      print('❌ [MYTUBE FOLLOW] Gagal toggle follow: $e');
      return false;
    }
  }

  // --- [BARU]: STREAM DAFTAR PENGIKUT LENGKAP DENGAN EMAIL ---
  Stream<List<Map<String, dynamic>>> streamCreatorFollowers(String creatorEmail) {
    final cleanKey = creatorEmail.trim().toLowerCase();
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
//............................................................................//

//No ke-8....................................................................//
//COMMENT ENGINE & LIFECYCLE DELETION                                        //
  Stream<List<CommentMytubeModel>> getCommentsStream(
    String videoId, {
    String? uploaderEmail,
    String? uploaderId,
    String videoType = 'SHORT',
  }) {
    if (videoId.isEmpty) return Stream.value([]);
    final creatorKey = (uploaderEmail != null && uploaderEmail.isNotEmpty)
        ? uploaderEmail.trim().toLowerCase()
        : uploaderId;

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
    String? uploaderEmail,
    String? uploaderId,
    String videoType = 'SHORT',
  }) async {
    if (videoId.isEmpty) return;

    final videoDocRef = await _resolveVideoDocRef(
      videoId: videoId,
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
    required String creatorKey,
    String videoType = 'SHORT',
  }) async {
    if (videoId.isEmpty || creatorKey.isEmpty) return;
    try {
      final cleanKey = creatorKey.trim().toLowerCase();
      final subCol = videoType.toUpperCase() == 'LONG' ? subColLongVideo : subColShortVideo;
      final docRef = _firestore.collection(colMytube).doc(cleanKey).collection(subCol).doc(videoId);

      await docRef.delete();

      final fieldToDecrement = videoType.toUpperCase() == 'LONG' ? 'total_longs' : 'total_shorts';
      await _firestore.collection(colMytube).doc(cleanKey).update({
        fieldToDecrement: FieldValue.increment(-1),
        'updated_at': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }
//............................................................................//

//No ke-9....................................................................//
//MODERATION & APPROVAL ENGINE (PERMOHONAN CREATOR VS EKSEKUSI ADMIN PUSAT)  //
  // 1. Creator Mengajukan Permohonan Edit Video (Judul, Kategori, Bahasa)
  Future<void> submitEditRequest({
    required VideoMytubeModel currentVideo,
    required String newTitle,
    required String newCategory,
    required String newLanguage,
  }) async {
    final docRef = _firestore.collection(colRequests).doc();

    final request = RequestMytubeModel(
      id: docRef.id,
      requestType: 'EDIT',
      status: 'PENDING',
      videoId: currentVideo.id,
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
    final subCol = request.videoType.toUpperCase() == 'LONG' ? subColLongVideo : subColShortVideo;
    final videoDocRef = _firestore
        .collection(colMytube)
        .doc(request.creatorEmail.trim().toLowerCase())
        .collection(subCol)
        .doc(request.videoId);

    if (request.requestType == 'EDIT') {
      // Terapkan perubahan judul, kategori, dan bahasa ke dokumen video asli
      await videoDocRef.update({
        'title': request.newTitle ?? request.oldTitle,
        'category': request.newCategory ?? request.oldCategory,
        'language': request.newLanguage ?? request.oldLanguage,
        'updated_at': FieldValue.serverTimestamp(),
      });
    } else if (request.requestType == 'DELETE') {
      // Hapus video secara resmi
      await deleteVideoPost(
        videoId: request.videoId,
        creatorKey: request.creatorEmail,
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
//USER ACCOUNT UPGRADE & TIER MANAGEMENT (ADMIN PUSAT)                        //
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
        };
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // 2. Meningkatkan Status Akun Menjadi "creator"
  Future<bool> upgradeUserToCreator(
    String targetUserId, {
    required String targetEmail,
    String? displayName,
  }) async {
    final cleanEmail = targetEmail.trim().toLowerCase();
    if (targetUserId.isEmpty || cleanEmail.isEmpty) return false;

    try {
      final batch = _firestore.batch();

      final userRef = _firestore.collection(colUsers).doc(targetUserId);
      batch.update(userRef, {
        'userTier': 'creator',
        'role': 'creator',
        'is_mytube_admin': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final creatorRef = _firestore.collection(colMytube).doc(cleanEmail);
      batch.set(
        creatorRef,
        {
          'email': cleanEmail,
          'creator_id': targetUserId,
          'channel_name': displayName ?? 'Kreator Baru',
          'handle': '@${cleanEmail.split('@')[0]}',
          'is_verified': true,
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

  // 3. Menurunkan Status Akun Kembali Menjadi "free" (User Biasa)
  Future<bool> downgradeUserToFree(
    String targetUserId, {
    required String targetEmail,
  }) async {
    final cleanEmail = targetEmail.trim().toLowerCase();
    if (targetUserId.isEmpty) return false;

    try {
      final batch = _firestore.batch();

      final userRef = _firestore.collection(colUsers).doc(targetUserId);
      batch.update(userRef, {
        'userTier': 'free',
        'role': 'user',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (cleanEmail.isNotEmpty) {
        final creatorRef = _firestore.collection(colMytube).doc(cleanEmail);
        batch.set(
          creatorRef,
          {
            'is_verified': false,
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

  // 4. Membaca Daftar Seluruh Kreator yang Sedang Aktif Secara Real-Time
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
              };
            }).toList());
  }
} // <--- PENUTUP KELAS FirestoreMytubeService PINDAH KE SINI (AKHIR BLOK 10)
//............................................................................//