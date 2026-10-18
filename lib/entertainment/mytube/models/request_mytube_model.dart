//============================================================================//
// DIREKTORI: lib/entertainment/mytube/models/                                //
// FILE: REQUEST_MYTUBE_MODEL.DART                                            //
// MODEL PERMOHONAN MODERASI EDIT & DELETE VIDEO MYTUBE                       //
//============================================================================//

//No ke-1....................................................................//
//IMPORTS & DEPENDENCIES                                                     //
import 'package:cloud_firestore/cloud_firestore.dart';
//............................................................................//

//No ke-2....................................................................//
//MODEL PROPERTIES & CONSTRUCTOR                                             //
class RequestMytubeModel {
  final String id;
  final String requestType; // 'EDIT' atau 'DELETE'
  final String status; // 'PENDING', 'APPROVED', 'REJECTED'

  // Data Video Target & Tautan Pemutaran untuk Verifikasi Admin
  final String videoId;
  final String videoType; // 'SHORT' atau 'LONG'
  final String videoUrl; // [PENTING]: URL untuk admin memutar dan mengecek video
  final String thumbnailUrl;
  final String videoTitle;

  // Data Creator Pengaju
  final String creatorEmail;
  final String creatorId; // UID Creator
  final String channelName;

  // Data Perubahan (Khusus Tipe 'EDIT')
  final String? oldTitle;
  final String? newTitle;
  final String? oldCategory;
  final String? newCategory;
  final String? oldLanguage;
  final String? newLanguage;

  // Data Alasan (Khusus Tipe 'DELETE')
  final String? deleteReason;

  // Catatan & Audit Trail Admin Pusat
  final String? adminNotes;
  final String? reviewedBy; // Email Admin yang menyetujui/menolak
  final DateTime createdAt;
  final DateTime? reviewedAt;

  const RequestMytubeModel({
    required this.id,
    required this.requestType,
    this.status = 'PENDING',
    required this.videoId,
    required this.videoType,
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.videoTitle,
    required this.creatorEmail,
    required this.creatorId,
    required this.channelName,
    this.oldTitle,
    this.newTitle,
    this.oldCategory,
    this.newCategory,
    this.oldLanguage,
    this.newLanguage,
    this.deleteReason,
    this.adminNotes,
    this.reviewedBy,
    required this.createdAt,
    this.reviewedAt,
  });
//............................................................................//

//No ke-3....................................................................//
//FACTORIES & DESERIALIZATION                                                //
  factory RequestMytubeModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return RequestMytubeModel.fromMap(data, doc.id);
  }

  factory RequestMytubeModel.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parsedCreatedAt;
    if (map['created_at'] is Timestamp) {
      parsedCreatedAt = (map['created_at'] as Timestamp).toDate();
    } else {
      parsedCreatedAt = DateTime.now();
    }

    DateTime? parsedReviewedAt;
    if (map['reviewed_at'] is Timestamp) {
      parsedReviewedAt = (map['reviewed_at'] as Timestamp).toDate();
    }

    return RequestMytubeModel(
      id: docId,
      requestType: map['request_type'] as String? ?? 'EDIT',
      status: map['status'] as String? ?? 'PENDING',
      videoId: map['video_id'] as String? ?? '',
      videoType: map['video_type'] as String? ?? 'SHORT',
      videoUrl: map['video_url'] as String? ?? '',
      thumbnailUrl: map['thumbnail_url'] as String? ?? '',
      videoTitle: map['video_title'] as String? ?? '',
      creatorEmail: map['creator_email'] as String? ?? '',
      creatorId: map['creator_id'] as String? ?? '',
      channelName: map['channel_name'] as String? ?? '',
      oldTitle: map['old_title'] as String?,
      newTitle: map['new_title'] as String?,
      oldCategory: map['old_category'] as String?,
      newCategory: map['new_category'] as String?,
      oldLanguage: map['old_language'] as String?,
      newLanguage: map['new_language'] as String?,
      deleteReason: map['delete_reason'] as String?,
      adminNotes: map['admin_notes'] as String?,
      reviewedBy: map['reviewed_by'] as String?,
      createdAt: parsedCreatedAt,
      reviewedAt: parsedReviewedAt,
    );
  }
//............................................................................//

//No ke-4....................................................................//
//SERIALIZATION (toMap) & COPYWITH                                           //
  Map<String, dynamic> toMap() {
    return {
      'request_type': requestType,
      'status': status,
      'video_id': videoId,
      'video_type': videoType,
      'video_url': videoUrl,
      'thumbnail_url': thumbnailUrl,
      'video_title': videoTitle,
      'creator_email': creatorEmail,
      'creator_id': creatorId,
      'channel_name': channelName,
      'old_title': oldTitle,
      'new_title': newTitle,
      'old_category': oldCategory,
      'new_category': newCategory,
      'old_language': oldLanguage,
      'new_language': newLanguage,
      'delete_reason': deleteReason,
      'admin_notes': adminNotes,
      'reviewed_by': reviewedBy,
      'created_at': Timestamp.fromDate(createdAt),
      'reviewed_at': reviewedAt != null ? Timestamp.fromDate(reviewedAt!) : null,
    };
  }

  RequestMytubeModel copyWith({
    String? id,
    String? requestType,
    String? status,
    String? videoId,
    String? videoType,
    String? videoUrl,
    String? thumbnailUrl,
    String? videoTitle,
    String? creatorEmail,
    String? creatorId,
    String? channelName,
    String? oldTitle,
    String? newTitle,
    String? oldCategory,
    String? newCategory,
    String? oldLanguage,
    String? newLanguage,
    String? deleteReason,
    String? adminNotes,
    String? reviewedBy,
    DateTime? createdAt,
    DateTime? reviewedAt,
  }) {
    return RequestMytubeModel(
      id: id ?? this.id,
      requestType: requestType ?? this.requestType,
      status: status ?? this.status,
      videoId: videoId ?? this.videoId,
      videoType: videoType ?? this.videoType,
      videoUrl: videoUrl ?? this.videoUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      videoTitle: videoTitle ?? this.videoTitle,
      creatorEmail: creatorEmail ?? this.creatorEmail,
      creatorId: creatorId ?? this.creatorId,
      channelName: channelName ?? this.channelName,
      oldTitle: oldTitle ?? this.oldTitle,
      newTitle: newTitle ?? this.newTitle,
      oldCategory: oldCategory ?? this.oldCategory,
      newCategory: newCategory ?? this.newCategory,
      oldLanguage: oldLanguage ?? this.oldLanguage,
      newLanguage: newLanguage ?? this.newLanguage,
      deleteReason: deleteReason ?? this.deleteReason,
      adminNotes: adminNotes ?? this.adminNotes,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      createdAt: createdAt ?? this.createdAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
    );
  }
}
//............................................................................//