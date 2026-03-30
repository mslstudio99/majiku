//..................................................//
// LIB/VIEW_MODELS/AUTH_VIEW_MODEL.DART             //
//..................................................//

//No ke-1...........................................//
// IMPORT DAN SETUP PROVIDER                        //
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart'; // Untuk debugPrint

import '../services/auth_service.dart';
import '../services/firestore_service.dart'; // [WAJIB] Untuk akses ensureUserDocumentExists

// Import provider untuk pembersihan state
import '../providers/user_provider.dart';
import '../view_model/dashboard_view_model.dart';
import '../view_model_veo/dashboard_veo_view_model.dart';

/*
KATEGORI_ARSITEKTUR_BARU NO_URUT_13 (REVISI FINAL 4.9 - ANTI RACE-CONDITION)
Nama File: lib/view_models/auth_view_model.dart
Tujuan:
- [SENTRALISASI] Menyerahkan seluruh logika token & fraud ke FirestoreService.
- [SINKRONISASI] Mengirim parameter `isNewRegistration` untuk membunuh tabrakan (Race Condition).
- [KEAMANAN] Pembersihan state (invalidate) saat logout untuk mencegah data leak.
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
//..................................................//

//No ke-2...........................................//
// KELOMPOK STATE NOTIFIER AUTHENTICATION (INTEGRAL)//
class AuthViewModel extends StateNotifier<bool> {
  final AuthService _authService;
  final Ref _ref;

  // State berupa boolean mewakili status loading.
  AuthViewModel(this._authService, this._ref) : super(false);

  // --- Core Methods ---

  /// [MODIFIKASI KRITIS] Method Login
  /// Memanggil FirestoreService untuk verifikasi identitas (Mode Normal)
  Future<bool> signInWithEmail(String email, String password) async {
    state = true;
    try {
      final userCredential = await _authService.signInWithEmailAndPassword(email, password);
      
      if (userCredential != null) {
        // --- [SENTRALISASI KEAMANAN] ---
        // Mode Login: Tidak disetel sebagai pendaftar baru
        final firestoreService = _ref.read(firestoreServiceProvider);
        await firestoreService.ensureUserDocumentExists(isNewRegistration: false);
        
        debugPrint("✅ AuthViewModel: Login sukses & Sinkronisasi profil dipicu.");
      }
      
      state = false;
      return userCredential != null;
    } catch (e) {
      state = false;
      debugPrint("❌ AuthViewModel: Login failed: $e");
      rethrow;
    }
  }

  /// [REVISI PARIPURNA] Method Pendaftaran (Anti-Fraud Sentral & Anti Race-Condition)
  /// Mengirim flag isNewRegistration = true ke FirestoreService.
  Future<bool> createUserWithEmail(String email, String password) async {
    state = true;
    try {
      final userCredential = await _authService.createUserWithEmailAndPassword(email, password);
      
      if (userCredential != null && userCredential.user != null) {
        // --- [LOGIKA ANTI-FRAUD TERPUSAT] ---
        // Penulisan dokumen dipaksa (Force Overwrite) menggunakan parameter isNewRegistration
        // Untuk membunuh Race Condition jika UI/Dashboard mencoba mencuri start.
        final firestoreService = _ref.read(firestoreServiceProvider);
        await firestoreService.ensureUserDocumentExists(isNewRegistration: true);
        
        debugPrint("✅ AuthViewModel: Registrasi Berhasil & Profil dipaksa sinkronisasi anti-fraud.");
      }
      
      state = false;
      return userCredential != null;
    } catch (e) {
      state = false;
      debugPrint("❌ AuthViewModel: Registration Error: $e");
      rethrow;
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
      // --- [ANTI-REGRESI: PEMBERSIHAN CACHE] ---
      // Wajib dilakukan agar user selanjutnya tidak melihat data user sebelumnya.
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
//..................................................//