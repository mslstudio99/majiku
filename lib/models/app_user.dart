//................................................................//
// NAMA FILE: APP_USER.DART                                       //
// PATH/DIREKTORI: lib/models/app_user.dart                       //
// FUNGSI UTAMA: MODEL PENGGUNA DAN DATA PROFIL FIRESTORE         //
//................................................................//

//No ke-1.........................................................//
// MODEL PENGGUNA DAN KONVERSI FIRESTORE                          //
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

/*
KATEGORI_ARSITEKTUR_BARU NO_URUT_01 (REVISI PARIPURNA 2.7 - PROTEKSI VERIFIKASI & ANTI REGRESI)
Nama File: lib/models/app_user.dart
Tujuan:
- [ANTI-REGRESI LAMA] Fallback otomatis 'true' untuk pengguna lama agar tidak pernah terblokir.
- [STATUS VERIFIKASI] Menyimpan status isEmailVerified dan hasReceivedWelcomeBonus secara reaktif.
- [SECURITY] Nilai token 100% bergantung pada Firestore. Default 0 mutlak jika belum ada.
- [WEB-OPTIMIZED] Tetap tanpa Timestamp agar aman dideploy ke Hostinger/Web.
*/
class AppUser {
  final String uid;
  final String email;
  final String? displayName;
  final String userTier;
  final int tokenBalance;
  
  // --- Status Verifikasi & Bonus ---
  final bool isEmailVerified;
  final bool hasReceivedWelcomeBonus;

  // --- Data User Center (Profil & Pelacak) ---
  final String country;
  final String city;
  final String acquisitionSource;
  final Map<String, dynamic>? deviceInfo;

  const AppUser({
    required this.uid,
    required this.email,
    this.displayName,
    required this.userTier,
    required this.tokenBalance,
    // Nilai default aman (Anti-Regresi Akun Lama)
    this.isEmailVerified = true,
    this.hasReceivedWelcomeBonus = true,
    this.country = 'Unknown',
    this.city = 'Unknown',
    this.acquisitionSource = 'Organic',
    this.deviceInfo,
  });

  /// Helper: Membuat instance 'kosong' atau default (Initial State)
  static AppUser get empty {
    return const AppUser(
      uid: '',
      email: '',
      userTier: 'free', 
      tokenBalance: 0,
      isEmailVerified: false,
      hasReceivedWelcomeBonus: false,
    );
  }

  /// Helper: Mengkonversi dari dokumen Firestore ke model AppUser
  factory AppUser.fromFirestore(
    firebase_auth.User authUser,
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    // 1. Ambil data mentah dari dokumen
    final Map<String, dynamic> data = doc.data() ?? {}; 

    // 2. KEAMANAN TINGKAT TINGGI: Saldo token mutlak dari database
    final int balance = (data['tokenBalance'] ?? 0).toInt();

    // 3. Fallback untuk userTier
    final String tier = data['userTier'] as String? ?? 'free';

    // 4. [ANTI-REGRESI AKUN LAMA]:
    // Jika data['isEmailVerified'] bernilai null (akun lama), fallback adalah `true`
    // sehingga akun lama tidak pernah terblokir. Akun baru eksplisit memiliki nilai `false`.
    final bool emailVerified = data['isEmailVerified'] as bool? ?? true;
    final bool welcomeBonus = data['hasReceivedWelcomeBonus'] as bool? ?? true;

    return AppUser(
      uid: authUser.uid,
      email: authUser.email ?? '',
      displayName: data['displayName'] as String? ?? authUser.displayName,
      userTier: tier,
      tokenBalance: balance,
      isEmailVerified: emailVerified,
      hasReceivedWelcomeBonus: welcomeBonus,
      // Tarik data profil dengan fallback
      country: data['country'] as String? ?? 'Unknown',
      city: data['city'] as String? ?? 'Unknown',
      acquisitionSource: data['acquisitionSource'] as String? ?? 'Organic',
      deviceInfo: data['deviceInfo'] as Map<String, dynamic>?,
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
      'isEmailVerified': isEmailVerified,
      'hasReceivedWelcomeBonus': hasReceivedWelcomeBonus,
      'country': country,
      'city': city,
      'acquisitionSource': acquisitionSource,
      'deviceInfo': deviceInfo,
    };
  }
}
//................................................................//