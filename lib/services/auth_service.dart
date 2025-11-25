import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth;

  // [MODIFIKASI] Constructor allows for dependency injection.
  // GoogleSignIn dihapus karena tidak lagi digunakan.
  AuthService({FirebaseAuth? firebaseAuth})
      : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  // Stream to listen for authentication state changes in real-time.
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  // Getter for the current user, if one exists.
  User? get currentUser => _firebaseAuth.currentUser;

  // --- Core Authentication Methods ---

  // [DIHAPUS] signInWithGoogle telah dihapus sesuai permintaan.

  // Sign in with Email and Password
  Future<UserCredential?> signInWithEmailAndPassword(String email, String password) async {
    try {
      return await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(), // Use trim to avoid whitespace issues
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      print("Firebase Auth Error on Email Sign-In: ${e.code} - ${e.message}");
      return null;
    }
  }

  // Register with Email and Password
  Future<UserCredential?> createUserWithEmailAndPassword(String email, String password) async {
    try {
      return await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(), // Use trim to avoid whitespace issues
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      print("Firebase Auth Error on User Creation: ${e.code} - ${e.message}");
      return null;
    }
  }

  // [BARU] Send Password Reset Email
  // Fitur ini diperlukan untuk tombol "Lupa Password" di Login Screen.
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(
        email: email.trim(), // Pastikan di-trim juga untuk keamanan
      );
    } on FirebaseAuthException catch (e) {
      print("Firebase Auth Error on Reset Password: ${e.code} - ${e.message}");
      rethrow; // Lempar error agar bisa ditangkap ViewModel/UI untuk menampilkan SnackBar
    }
  }

  // Sign out
  // [MODIFIKASI] Hanya sign out dari Firebase, GoogleSignIn dihapus.
  Future<void> signOut() async {
    try {
      await _firebaseAuth.signOut();
    } catch (e) {
      print("An error occurred during sign out: $e");
    }
  }
}