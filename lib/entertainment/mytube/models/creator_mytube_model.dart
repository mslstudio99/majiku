//============================================================================//
// DIREKTORI: lib/entertainment/mytube/models/                               //
// FILE: CREATOR_MYTUBE_MODEL.DART                                            //
// MODEL DATA PROFIL CREATOR / ADMIN MYTUBE RESMI                             //
//============================================================================//

//No ke-1....................................................................//
//IMPORTS & DEPENDENCIES                                                     //
import 'package:cloud_firestore/cloud_firestore.dart';
//............................................................................//

//No ke-2....................................................................//
//MODEL PROPERTIES & CONSTRUCTOR                                             //
class CreatorMytubeModel {
  final String id; // UID Admin
  final String email;
  final String channelName; // Maksimal 30 karakter
  final String handle; // Otomatis terisi (@nama_channel)
  final String creatorLegalName; // Nama KTP / Identitas resmi
  final String address; // Maksimal 100 karakter
  final String country; // Pilihan seluruh dunia (disinkronkan dengan 37 negara)
  final String city;
  final String phoneNumber;
  final String avatarUrl;

  // Data Rekening Bank untuk Payout / Monetisasi
  final String bankName;
  final String bankAccountHolder;
  final String bankAccountNumber;

  // Tautan Media Sosial Spesifik (YouTube, FB, TikTok, Other)
  final String youtubeHandle; // YouTube Channel
  final String facebookUrl; // Facebook
  final String tiktokUrl; // TikTok
  final String otherUrl; // Other Link
  final String websiteUrl; // Tautan opsional tambahan
  final String instagramHandle; // Backward compatibility

  final bool isVerified;
  final int totalVideos;
  final int totalViews;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const CreatorMytubeModel({
    required this.id,
    this.email = '',
    required this.channelName,
    this.handle = '',
    this.creatorLegalName = '',
    this.address = '',
    this.country = 'Indonesia 🇮🇩',
    this.city = '',
    this.phoneNumber = '',
    this.avatarUrl = '',
    this.bankName = '',
    this.bankAccountHolder = '',
    this.bankAccountNumber = '',
    this.youtubeHandle = '',
    this.facebookUrl = '',
    this.tiktokUrl = '',
    this.otherUrl = '',
    this.websiteUrl = '',
    this.instagramHandle = '',
    this.isVerified = true,
    this.totalVideos = 0,
    this.totalViews = 0,
    this.createdAt,
    this.updatedAt,
  });
//............................................................................//

//No ke-3....................................................................//
//FACTORIES & DESERIALIZATION                                                //
  factory CreatorMytubeModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return CreatorMytubeModel.fromMap(data, doc.id);
  }

  factory CreatorMytubeModel.fromMap(Map<String, dynamic> map, String docId) {
    return CreatorMytubeModel(
      id: docId,
      email: map['email'] as String? ?? '',
      channelName: map['channel_name'] as String? ?? '',
      handle: map['handle'] as String? ?? '',
      creatorLegalName: map['creator_legal_name'] as String? ?? '',
      address: map['address'] as String? ?? '',
      country: map['country'] as String? ?? 'Indonesia 🇮🇩',
      city: map['city'] as String? ?? '',
      phoneNumber: map['phone_number'] as String? ?? '',
      avatarUrl: map['avatar_url'] as String? ?? '',
      bankName: map['bank_name'] as String? ?? '',
      bankAccountHolder: map['bank_account_holder'] as String? ?? '',
      bankAccountNumber: map['bank_account_number'] as String? ?? '',
      youtubeHandle: map['youtube_handle'] as String? ?? map['youtube_url'] as String? ?? '',
      facebookUrl: map['facebook_url'] as String? ?? '',
      tiktokUrl: map['tiktok_url'] as String? ?? '',
      otherUrl: map['other_url'] as String? ?? map['website_url'] as String? ?? '',
      websiteUrl: map['website_url'] as String? ?? '',
      instagramHandle: map['instagram_handle'] as String? ?? '',
      isVerified: map['is_verified'] as bool? ?? true,
      totalVideos: (map['total_videos'] as num?)?.toInt() ?? 0,
      totalViews: (map['total_views'] as num?)?.toInt() ?? 0,
      createdAt: (map['created_at'] as Timestamp?)?.toDate(),
      updatedAt: (map['updated_at'] as Timestamp?)?.toDate(),
    );
  }

  factory CreatorMytubeModel.empty(
    String uid, {
    String defaultEmail = '',
    String defaultName = '',
    String defaultAvatar = '',
  }) {
    final cleanHandle = defaultName
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[^a-z0-9_]'), '');

    return CreatorMytubeModel(
      id: uid,
      email: defaultEmail,
      channelName: defaultName,
      handle: cleanHandle.isNotEmpty ? '@$cleanHandle' : '',
      avatarUrl: defaultAvatar,
      isVerified: true,
    );
  }
//............................................................................//

//No ke-4....................................................................//
//SERIALIZATION & COPYWITH UTILITIES                                         //
  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'channel_name': channelName,
      'handle': handle.startsWith('@') ? handle : (handle.isNotEmpty ? '@$handle' : ''),
      'creator_legal_name': creatorLegalName,
      'address': address,
      'country': country,
      'city': city,
      'phone_number': phoneNumber,
      'avatar_url': avatarUrl,
      'bank_name': bankName,
      'bank_account_holder': bankAccountHolder,
      'bank_account_number': bankAccountNumber,
      'youtube_handle': youtubeHandle,
      'facebook_url': facebookUrl,
      'tiktok_url': tiktokUrl,
      'other_url': otherUrl,
      'website_url': websiteUrl.isNotEmpty ? websiteUrl : otherUrl,
      'instagram_handle': instagramHandle,
      'is_verified': isVerified,
      'total_videos': totalVideos,
      'total_views': totalViews,
      'created_at': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    };
  }

  CreatorMytubeModel copyWith({
    String? id,
    String? email,
    String? channelName,
    String? handle,
    String? creatorLegalName,
    String? address,
    String? country,
    String? city,
    String? phoneNumber,
    String? avatarUrl,
    String? bankName,
    String? bankAccountHolder,
    String? bankAccountNumber,
    String? youtubeHandle,
    String? facebookUrl,
    String? tiktokUrl,
    String? otherUrl,
    String? websiteUrl,
    String? instagramHandle,
    bool? isVerified,
    int? totalVideos,
    int? totalViews,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CreatorMytubeModel(
      id: id ?? this.id,
      email: email ?? this.email,
      channelName: channelName ?? this.channelName,
      handle: handle ?? this.handle,
      creatorLegalName: creatorLegalName ?? this.creatorLegalName,
      address: address ?? this.address,
      country: country ?? this.country,
      city: city ?? this.city,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bankName: bankName ?? this.bankName,
      bankAccountHolder: bankAccountHolder ?? this.bankAccountHolder,
      bankAccountNumber: bankAccountNumber ?? this.bankAccountNumber,
      youtubeHandle: youtubeHandle ?? this.youtubeHandle,
      facebookUrl: facebookUrl ?? this.facebookUrl,
      tiktokUrl: tiktokUrl ?? this.tiktokUrl,
      otherUrl: otherUrl ?? this.otherUrl,
      websiteUrl: websiteUrl ?? this.websiteUrl,
      instagramHandle: instagramHandle ?? this.instagramHandle,
      isVerified: isVerified ?? this.isVerified,
      totalVideos: totalVideos ?? this.totalVideos,
      totalViews: totalViews ?? this.totalViews,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
//............................................................................//