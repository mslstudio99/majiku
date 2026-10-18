//..................................................//
// LIB/PROVIDERS/USER_PROVIDER.DART                 //
//..................................................//

//No ke-1...........................................//
// IMPORT DEPENDENSI & SETUP AWAL                   //
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter_riverpod/flutter_riverpod.dart';

// --- Impor Dependensi ---
import '../view_model/auth_view_model.dart'; // Provider Auth
import '../models/app_user.dart'; // Model User 

/*
KATEGORI_ARSITEKTUR_BARU NO_URUT_02 (REVISI 4.2 - SENTRALISASI MUTLAK & ANTI RACE-CONDITION)
Nama File: lib/providers/user_provider.dart
Tujuan:
- [FIX KRITIS] Menghapus MockDocSnapshot yang menjadi "Pencuri Start" dan merusak logika anti-fraud.
- [SYNC] Menghubungkan AuthState dan FirestoreStream secara reaktif.
- [KEAMANAN] Memaksa aplikasi menunggu validasi dari firestore_service.dart sebelum menampilkan profil.
*/
//..................................................//

//No ke-2...........................................//
// FIREBASE FIRESTORE & DOCUMENT STREAM PROVIDER    //
/// Provider 1: Menyediakan instance FirebaseFirestore
final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

/// Provider 2: Stream Dokumen Pengguna (Raw Firestore Stream)
/// Menyederhanakan aliran data agar selalu sinkron dengan database asli.
final _userDocumentStreamProvider =
    StreamProvider.autoDispose<DocumentSnapshot<Map<String, dynamic>>?>((ref) {
  
  final authState = ref.watch(authStateChangesProvider);
  final db = ref.watch(firestoreProvider);

  return authState.when(
    data: (user) {
      if (user != null) {
        // User login: Buka kran data dari Firestore secara realtime
        return db.collection('users').doc(user.uid).snapshots();
      } else {
        // User logout: Kran ditutup (null)
        return Stream.value(null);
      }
    },
    loading: () => const Stream.empty(),
    error: (e, s) => Stream.error(e),
  );
});
//..................................................//

//No ke-3...........................................//
// APP USER PROVIDER (PINTU UTAMA UI & ANTI-FRAUD)  //
/// Provider 3: Provider AppUser
/// [KUNCI]: Menggabungkan data Auth dan Firestore untuk menghasilkan model AppUser.
/// Diperbarui dengan stabilisasi Stream.value(AppUser.empty) untuk mengeliminasi error defunct widget.
final firestoreUserProvider = StreamProvider.autoDispose<AppUser>((ref) {
  
  final authState = ref.watch(authStateChangesProvider);
  final docAsyncValue = ref.watch(_userDocumentStreamProvider);

  // 1. Tangani State Loading (Gunakan Stream.value(AppUser.empty) agar siklus stream tetap stabil)
  if (authState.isLoading || docAsyncValue.isLoading) {
    return Stream.value(AppUser.empty);
  }

  // 2. Tangani Error
  if (authState.hasError) return Stream.error(authState.error!);
  if (docAsyncValue.hasError) return Stream.error(docAsyncValue.error!);

  final authUser = authState.value;
  final docSnapshot = docAsyncValue.value;

  // 3. Skenario: User Logout
  if (authUser == null) {
    return Stream.value(AppUser.empty);
  }

  // 4. Skenario: Menunggu Validasi Anti-Fraud / Dokumen Belum Terbentuk
  if (docSnapshot == null || !docSnapshot.exists) {
    return Stream.value(AppUser.empty); 
  }

  // 5. Skenario: Sukses (Dokumen sah dan tervalidasi ditemukan)
  return Stream.value(AppUser.fromFirestore(authUser, docSnapshot));
});
//..................................................//