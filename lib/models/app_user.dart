//..................................................//
// LIB/MODELS/APP_USER.DART                         //
//..................................................//

//No ke-1...........................................//
// MODEL PENGGUNA DAN KONVERSI FIRESTORE            //
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

/*
KATEGORI_ARSITEKTUR_BARU NO_URUT_01 (REVISI PARIPURNA 2.5 - SECURITY FIXED)
Nama File: lib/models/app_user.dart
Tujuan:
- [FIX KRITIS] Menghapus logika "Sinterklas" (Pemberian Token Lokal).
- [SECURITY] Nilai token 100% bergantung pada Firestore. Default 0 mutlak jika belum ada.
- [WEB-OPTIMIZED] Tetap tanpa Timestamp agar aman dideploy ke Hostinger/Web.
*/
class AppUser {
  final String uid;
  final String email;
  final String? displayName;
  final String userTier;
  final int tokenBalance;

  const AppUser({
    required this.uid,
    required this.email,
    this.displayName,
    required this.userTier,
    required this.tokenBalance,
  });

  /// Helper: Membuat instance 'kosong' atau default (Initial State)
  static AppUser get empty {
    return const AppUser(
      uid: '',
      email: '',
      userTier: 'free', 
      tokenBalance: 0,
    );
  }

  /// Helper: Mengkonversi dari dokumen Firestore ke model AppUser
  factory AppUser.fromFirestore(
    firebase_auth.User authUser,
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    // 1. Ambil data mentah dari dokumen
    final Map<String, dynamic> data = doc.data() ?? {}; 

    // 2. KEAMANAN TINGKAT TINGGI: Tidak ada lagi saldo bayangan lokal!
    // Semua token 100% berasal dari database. Jika kosong/null, nilainya mutlak 0.
    final int balance = (data['tokenBalance'] ?? 0).toInt();

    // 3. Fallback untuk userTier
    final String tier = data['userTier'] as String? ?? 'free';

    return AppUser(
      uid: authUser.uid,
      email: authUser.email ?? '',
      displayName: data['displayName'] as String? ?? authUser.displayName,
      userTier: tier,
      tokenBalance: balance,
    );
  }

  /// Helper: Mengkonversi model AppUser ke Map untuk Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'userTier': userTier,
      'tokenBalance': tokenBalance,
    };
  }
}
//..................................................//