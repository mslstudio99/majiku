//................................................................//
// LIB/SERVICES/AUTH_SERVICE.DART                                 //
//................................................................//

// No ke-1........................................................//
// IMPORT & INISIALISASI SERVICE                                  //
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth;

  // Constructor mendukung dependency injection
  AuthService({FirebaseAuth? firebaseAuth})
      : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  // Stream status autentikasi realtime
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  // Getter user aktif saat ini
  User? get currentUser => _firebaseAuth.currentUser;

  // Getter status apakah email user aktif sudah terverifikasi
  bool get isEmailVerified => _firebaseAuth.currentUser?.emailVerified ?? false;
//................................................................//

// No ke-2........................................................//
// METODE AUTENTIKASI (SIGN IN, REGISTER, SIGN OUT)               //
  // Sign in dengan Email dan Password
  Future<UserCredential?> signInWithEmailAndPassword(String email, String password) async {
    try {
      return await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      debugPrint("Firebase Auth Error on Email Sign-In: ${e.code} - ${e.message}");
      rethrow;
    }
  }

  // Register dengan Email dan Password + Otomatis Kirim Tautan Verifikasi
  Future<UserCredential?> createUserWithEmailAndPassword(String email, String password) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      // [PENGAMAN]: Otomatis kirim tautan verifikasi ke inbox email pengguna baru
      if (credential.user != null && !credential.user!.emailVerified) {
        await credential.user!.sendEmailVerification();
        debugPrint("[AuthService] Tautan verifikasi email berhasil dikirim ke: ${credential.user!.email}");
      }

      return credential;
    } on FirebaseAuthException catch (e) {
      debugPrint("Firebase Auth Error on User Creation: ${e.code} - ${e.message}");
      rethrow;
    }
  }

  // Sign out dari sesi aktif
  Future<void> signOut() async {
    try {
      await _firebaseAuth.signOut();
      debugPrint("[AuthService] Sesi berhasil keluar.");
    } catch (e) {
      debugPrint("An error occurred during sign out: $e");
      rethrow;
    }
  }
//................................................................//

// No ke-3........................................................//
// VERIFIKASI EMAIL & RECOVERY (EMAIL VERIFICATION & RESET)       //
  // Mengirim ulang email verifikasi secara manual jika diminta user
  Future<void> sendEmailVerification() async {
    final user = _firebaseAuth.currentUser;
    if (user != null && !user.emailVerified) {
      try {
        await user.sendEmailVerification();
        debugPrint("[AuthService] Tautan verifikasi email dikirim ulang ke: ${user.email}");
      } on FirebaseAuthException catch (e) {
        debugPrint("Firebase Auth Error on Send Email Verification: ${e.code} - ${e.message}");
        rethrow;
      }
    }
  }

  // Memperbarui cache user di HP untuk mendeteksi apakah link email sudah diklik
  Future<void> reloadCurrentUser() async {
    try {
      await _firebaseAuth.currentUser?.reload();
      debugPrint("[AuthService] Profil user berhasil di-reload. Status Verified: ${_firebaseAuth.currentUser?.emailVerified}");
    } catch (e) {
      debugPrint("Error reloading current user: $e");
    }
  }

  // Memanggil Cloud Function untuk mencairkan bonus selamat datang setelah verifikasi sah
  Future<void> claimWelcomeBonus() async {
    try {
      final functions = FirebaseFunctions.instanceFor(region: "asia-southeast2");
      final callable = functions.httpsCallable('claimWelcomeBonusAfterEmailVerification');
      final result = await callable.call();
      debugPrint("[AuthService] Hasil klaim bonus verifikasi: ${result.data}");
    } catch (e) {
      debugPrint("[AuthService] Gagal mencairkan bonus verifikasi: $e");
    }
  }

  // Mengirim tautan reset kata sandi (Lupa Password)
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(
        email: email.trim(),
      );
      debugPrint("[AuthService] Tautan reset kata sandi terkirim ke: $email");
    } on FirebaseAuthException catch (e) {
      debugPrint("Firebase Auth Error on Reset Password: ${e.code} - ${e.message}");
      rethrow;
    }
  }
}
//................................................................//