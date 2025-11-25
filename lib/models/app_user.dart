import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth; // Alias

/*
KATEGORI_ARSITEKTUR_BARU NO_URUT_01 (REVISI FINAL 2.0)
Nama File: lib/models/app_user.dart
Tujuan:
- (Koreksi Kritis) Menghapus 'createdAt' (Timestamp) yang menyebabkan
- error 'int64 not supported by dart 2 js' di Flutter Web.
*/

class AppUser {
  final String uid;
  final String email;
  final String? displayName;
  final String userTier;
  final int tokenBalance;
  // final Timestamp createdAt; // <-- DIHAPUS (Penyebab error int64)

  const AppUser({
    required this.uid,
    required this.email,
    this.displayName,
    required this.userTier,
    required this.tokenBalance,
    // required this.createdAt, // <-- DIHAPUS
  });

  /// Helper: Membuat instance 'kosong' atau default
  static AppUser get empty {
    return const AppUser(
      uid: '',
      email: '',
      userTier: 'free', 
      tokenBalance: 0,
      // createdAt: Timestamp(0, 0), // <-- DIHAPUS
    );
  }

  /// Helper: Mengkonversi dari dokumen Firestore ke model AppUser
  factory AppUser.fromFirestore(
    firebase_auth.User authUser,
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {}; 

    final String tier = data['userTier'] as String? ?? 'free';
    final int balance = data['tokenBalance'] as int? ?? 0;
    // final Timestamp created = data['createdAt'] as Timestamp? ?? Timestamp.now(); // <-- DIHAPUS

    return AppUser(
      // Data dari Firebase Auth
      uid: authUser.uid,
      email: authUser.email ?? '',
      displayName: authUser.displayName,

      // Data dari Dokumen Firestore
      userTier: tier,
      tokenBalance: balance,
      // createdAt: created, // <-- DIHAPUS
    );
  }

  /// Helper: Mengkonversi model AppUser ke Map untuk ditulis ke Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'userTier': userTier,
      'tokenBalance': tokenBalance,
      // 'createdAt': createdAt, // <-- DIHAPUS
    };
  }
}