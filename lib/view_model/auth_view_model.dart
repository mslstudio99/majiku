//................................................................//
// NAMA FILE: AUTH_VIEW_MODEL.DART                                //
// PATH/DIREKTORI: lib/view_model/auth_view_model.dart            //
// FUNGSI UTAMA: STATE NOTIFIER AUTHENTICATION & SESSION FLOW     //
//................................................................//

//No ke-1.........................................................//
// IMPORT, EXCEPTION & SETUP PROVIDER                             //
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/firestore_service.dart';

// Import provider untuk pembersihan state
import '../providers/user_provider.dart';
import '../view_model/dashboard_view_model.dart';
import '../view_model_veo/dashboard_veo_view_model.dart';

/*
KATEGORI_ARSITEKTUR_BARU NO_URUT_13 (REVISI FINAL 7.0 - DIRECT TO VERIFY SCREEN & ANTI-REGRESI)
Nama File: lib/view_model/auth_view_model.dart
Tujuan:
- [SEAMLESS TRANSITION] Membiarkan sesi aktif agar main.dart langsung mengarahkan pendaftar baru ke VerifyEmailScreen.
- [AUTO BONUS CLAIM] Memanggil claimWelcomeBonus() saat login jika email sudah terbukti verified.
- [KIRIM ULANG LINK] Menyediakan fungsi resendVerificationEmail untuk layar verifikasi.
- [ANTI DATA LEAK] State invalidated saat logout.
*/

// Provider 1: Menyediakan instance AuthService.
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

// Provider tambahan untuk FirestoreService agar bisa diakses di ViewModel
final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService();
});

// Provider 2: StreamProvider yang mendengarkan perubahan status autentikasi.
final authStateChangesProvider = StreamProvider<User?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
});

// Provider 3: ViewModel (StateNotifier).
final authViewModelProvider = StateNotifierProvider<AuthViewModel, bool>((ref) {
  final authService = ref.watch(authServiceProvider);
  return AuthViewModel(authService, ref); 
});
//................................................................//

//No ke-2.........................................................//
// KELOMPOK STATE NOTIFIER AUTHENTICATION (INTEGRAL)              //
class AuthViewModel extends StateNotifier<bool> {
  final AuthService _authService;
  final Ref _ref;

  // State berupa boolean mewakili status loading.
  AuthViewModel(this._authService, this._ref) : super(false);

  // --- Core Methods ---

  /// Method Private untuk Melacak Lokasi secara Background (Anti-Regresi & Safe Fail)
  Future<Map<String, String>> _fetchLocationData() async {
    try {
      final response = await http
          .get(Uri.parse('https://ipwho.is/'))
          .timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return {
            'country': data['country'] ?? 'Unknown',
            'city': data['city'] ?? 'Unknown',
          };
        }
      }
    } catch (e) {
      debugPrint("⚠️ Pelacakan lokasi gagal (TimeOut/Error), fallback ke Unknown: $e");
    }
    return {'country': 'Unknown', 'city': 'Unknown'};
  }

  /// Method Login
  Future<bool> signInWithEmail(String email, String password) async {
    state = true;
    try {
      final userCredential = await _authService.signInWithEmailAndPassword(email, password);
      
      if (userCredential != null && userCredential.user != null) {
        // 1. Reload profil user untuk memastikan status emailVerified paling mutakhir
        await _authService.reloadCurrentUser();

        // 2. Jika email terbukti verified, langsung coba klaim bonus selamat datang jika belum
        if (_authService.isEmailVerified) {
          await _authService.claimWelcomeBonus();
        }

        // 3. Sinkronisasi data user & lokasi di Firestore
        final firestoreService = _ref.read(firestoreServiceProvider);
        final location = await _fetchLocationData();

        await firestoreService.ensureUserDocumentExists(
          isNewRegistration: false,
          country: location['country'],
          city: location['city'],
        );
        
        debugPrint("✅ AuthViewModel: Sign In sukses & sinkronisasi data dipicu.");
      }
      
      state = false;
      return userCredential != null;
    } catch (e) {
      state = false;
      debugPrint("❌ AuthViewModel: Login failed: $e");
      rethrow;
    }
  }

  /// Method Pendaftaran (Mulus langsung menuju VerifyEmailScreen via main.dart)
  Future<bool> createUserWithEmail(String email, String password) async {
    state = true;
    try {
      final userCredential = await _authService.createUserWithEmailAndPassword(email, password);
      
      if (userCredential != null && userCredential.user != null) {
        final firestoreService = _ref.read(firestoreServiceProvider);
        final location = await _fetchLocationData();

        // Buat profil Firestore dengan status pendaftar baru
        await firestoreService.ensureUserDocumentExists(
          isNewRegistration: true,
          country: location['country'],
          city: location['city'],
          acquisitionSource: 'Organic (App Register)',
        );

        // CATATAN KRITIS: Kita TIDAK memanggil signOut() di sini!
        // Sesi sengaja dibiarkan aktif agar router di main.dart langsung mendeteksi
        // user baru yang belum verified dan otomatis menampilkan VerifyEmailScreen.
        debugPrint("✅ AuthViewModel: Registrasi sukses, mengalirkan user langsung ke VerifyEmailScreen.");
      }
      
      state = false;
      return userCredential != null;
    } catch (e) {
      state = false;
      debugPrint("❌ AuthViewModel: Registration Error: $e");
      rethrow;
    }
  }

  /// Method untuk Mengirim Ulang Tautan Verifikasi Email
  Future<void> resendVerificationEmail({required String email, String? password}) async {
    state = true;
    try {
      if (_authService.currentUser != null) {
        await _authService.sendEmailVerification();
      } else if (password != null && password.isNotEmpty) {
        final cred = await _authService.signInWithEmailAndPassword(email, password);
        if (cred?.user != null) {
          await _authService.sendEmailVerification();
        }
      } else {
        throw Exception("Kata sandi diperlukan untuk mengirim ulang tautan verifikasi.");
      }
      debugPrint("✅ AuthViewModel: Tautan verifikasi berhasil dikirim ulang ke: $email");
    } catch (e) {
      debugPrint("❌ AuthViewModel: Gagal kirim ulang tautan verifikasi: $e");
      rethrow;
    } finally {
      state = false;
    }
  }

  /// Method untuk mengirim email reset password
  Future<void> sendPasswordResetEmail(String email) async {
    state = true; 
    try {
      await _authService.sendPasswordResetEmail(email);
      debugPrint("✅ AuthViewModel: Reset password email sent to $email");
    } catch (e) {
      debugPrint("❌ AuthViewModel: Reset Password Error: $e");
      rethrow; 
    } finally {
      state = false; 
    }
  }

  /// Method untuk Sign Out dengan pembersihan cache (Anti-Leak)
  Future<void> signOut() async {
    state = true;
    try {
      _ref.invalidate(firestoreUserProvider);
      _ref.invalidate(projectsStreamProvider);
      _ref.invalidate(projectsVeoStreamProvider);

      await _authService.signOut();
      debugPrint("✅ AuthViewModel: Sign out success & state invalidated.");
    } catch (e) {
      debugPrint("❌ AuthViewModel: Sign Out Error: $e");
    } finally {
      state = false;
    }
  }
}
//................................................................//