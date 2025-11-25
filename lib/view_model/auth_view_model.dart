/*
KATEGORI_PERBAIKAN_KEAMANAN NO_URUT_01 (REVISI 2.0 - DATA LEAK PATCH)
KATEGORI_AUTH_UPDATE_02 (FITUR RESET PASSWORD & HAPUS GOOGLE)
Tujuan:
- [KEAMANAN] Memperbaiki kebocoran data antar akun saat logout.
- [FITUR] Menambahkan fungsi sendPasswordResetEmail.
- [CLEANUP] Menghapus fungsi signInWithGoogle.
*/

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

// [KATEGORI_REFAKTOR NO_URUT_02] Menambahkan impor provider yang bocor
import '../providers/user_provider.dart';
import '../view_model/dashboard_view_model.dart';
import '../view_model_veo/dashboard_veo_view_model.dart';

// Provider 1: Exposes an instance of AuthService.
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

// Provider 2: A StreamProvider that listens to the authentication state changes.
final authStateChangesProvider = StreamProvider<User?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
});

// Provider 3: The ViewModel (StateNotifier).
final authViewModelProvider = StateNotifierProvider<AuthViewModel, bool>((ref) {
  final authService = ref.watch(authServiceProvider);
  return AuthViewModel(authService, ref); 
});

class AuthViewModel extends StateNotifier<bool> {
  final AuthService _authService;
  final Ref _ref;

  // The state of this notifier is a boolean representing the loading state.
  AuthViewModel(this._authService, this._ref) : super(false);

  // [DIHAPUS] Method signInWithGoogle dihapus sesuai permintaan.

  // Method to sign in with email and password
  Future<bool> signInWithEmail(String email, String password) async {
    state = true;
    final userCredential = await _authService.signInWithEmailAndPassword(email, password);
    state = false;
    return userCredential != null;
  }

  // Method to register with email and password
  Future<bool> createUserWithEmail(String email, String password) async {
    state = true;
    final userCredential = await _authService.createUserWithEmailAndPassword(email, password);
    state = false;
    return userCredential != null;
  }

  // [BARU] Method untuk mengirim email reset password
  // Digunakan oleh tombol 'Lupa Password' di LoginScreen
  Future<void> sendPasswordResetEmail(String email) async {
    state = true; // Set loading state to true
    try {
      await _authService.sendPasswordResetEmail(email);
    } catch (e) {
      // Opsional: Anda bisa menangani error spesifik di sini atau melemparnya ke UI
      rethrow; 
    } finally {
      state = false; // Set loading state to false (selalu dijalankan)
    }
  }

  // Method to sign out
  // [KATEGORI_REFAKTOR NO_URUT_03] (Perbaikan Kritis Data Leak)
  Future<void> signOut() async {
    state = true;
    
    // --- [PERBAIKAN KEAMANAN DATA LEAK] ---
    // Paksa Riverpod untuk membersihkan cache data pengguna LAMA
    // sebelum kita benar-benar logout.
    _ref.invalidate(firestoreUserProvider);
    _ref.invalidate(projectsStreamProvider);
    _ref.invalidate(projectsVeoStreamProvider);
    // --- [AKHIR PERBAIKAN] ---

    await _authService.signOut();
    state = false;
  }
}