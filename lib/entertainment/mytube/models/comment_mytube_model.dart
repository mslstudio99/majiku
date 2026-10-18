//============================================================================//
// DIREKTORI: lib/entertainment/mytube/models/                                //
// FILE: COMMENT_MYTUBE_MODEL.DART                                            //
//============================================================================//

//No ke-1....................................................................//
//IMPORTS & DEPENDENCIES                                                     //
import 'package:cloud_firestore/cloud_firestore.dart';
//............................................................................//

//No ke-2....................................................................//
//MODEL PROPERTIES & CONSTRUCTOR                                             //
class CommentMytubeModel {
  final String id;
  final String videoId;
  final String userId;
  final String userName;
  final String userAvatarUrl;
  final String commentText;
  final int likesCount;
  final bool isAdminComment;
  final DateTime createdAt;

  const CommentMytubeModel({
    required this.id,
    required this.videoId,
    required this.userId,
    required this.userName,
    required this.userAvatarUrl,
    required this.commentText,
    this.likesCount = 0,
    this.isAdminComment = false,
    required this.createdAt,
  });
//............................................................................//

//No ke-3....................................................................//
//FACTORY DESERIALIZATION (fromFirestore & fromMap)                          //
  factory CommentMytubeModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return CommentMytubeModel.fromMap(data, doc.id);
  }

  factory CommentMytubeModel.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parsedDate;
    if (map['created_at'] is Timestamp) {
      parsedDate = (map['created_at'] as Timestamp).toDate();
    } else if (map['created_at'] is String) {
      parsedDate = DateTime.tryParse(map['created_at']) ?? DateTime.now();
    } else if (map['created_at'] is int) {
      parsedDate = DateTime.fromMillisecondsSinceEpoch(map['created_at']);
    } else {
      parsedDate = DateTime.now();
    }

    return CommentMytubeModel(
      id: docId,
      videoId: map['video_id'] ?? '',
      userId: map['user_id'] ?? '',
      userName: map['user_name'] ?? 'Pengguna',
      userAvatarUrl: map['user_avatar_url'] ?? '',
      commentText: map['comment_text'] ?? '',
      likesCount: (map['likes_count'] as num?)?.toInt() ?? 0,
      isAdminComment: map['is_admin_comment'] ?? false,
      createdAt: parsedDate,
    );
  }
//............................................................................//

//No ke-4....................................................................//
//SERIALIZATION (toMap)                                                      //
  Map<String, dynamic> toMap() {
    return {
      'video_id': videoId,
      'user_id': userId,
      'user_name': userName,
      'user_avatar_url': userAvatarUrl,
      'comment_text': commentText,
      'likes_count': likesCount,
      'is_admin_comment': isAdminComment,
      'created_at': Timestamp.fromDate(createdAt),
    };
  }
//............................................................................//

//No ke-5....................................................................//
//UTILITY METHODS & COPYWITH                                                 //
  CommentMytubeModel copyWith({
    String? id,
    String? videoId,
    String? userId,
    String? userName,
    String? userAvatarUrl,
    String? commentText,
    int? likesCount,
    bool? isAdminComment,
    DateTime? createdAt,
  }) {
    return CommentMytubeModel(
      id: id ?? this.id,
      videoId: videoId ?? this.videoId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userAvatarUrl: userAvatarUrl ?? this.userAvatarUrl,
      commentText: commentText ?? this.commentText,
      likesCount: likesCount ?? this.likesCount,
      isAdminComment: isAdminComment ?? this.isAdminComment,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
//............................................................................//