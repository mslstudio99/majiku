/*
KATEGORI_ARSITEKTUR_BARU NO_URUT_02 (REVISI 3 - FINAL)
Nama File: lib/providers/user_provider.dart
Tujuan:
- (Koreksi Kritis Final) Memperbaiki arsitektur provider yang salah menangani state loading.
- Logika baru ini memastikan provider dokumen (_userDocumentStreamProvider)
- menunggu (respects) state loading dari provider auth (authStateChangesProvider).
*/

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter_riverpod/flutter_riverpod.dart';

// --- Impor Dependensi ---
import '../view_model/auth_view_model.dart'; // (Provider Auth yang ada)
import '../models/app_user.dart'; // (Model User yang ada)

// --- Definisi Provider ---

/// Provider 1: Menyediakan instance FirebaseFirestore (helper)
final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

/// Provider 2: Stream Dokumen Pengguna (HANYA aktif saat login)
/// [KOREKSI KUNCI]: Provider ini sekarang menggunakan .when() untuk
/// menangani state loading/error dari provider auth dengan benar.
final _userDocumentStreamProvider =
    StreamProvider.autoDispose<DocumentSnapshot<Map<String, dynamic>>>((ref) {
  
  // Perhatikan provider status auth
  final authState = ref.watch(authStateChangesProvider);
  final db = ref.watch(firestoreProvider);

  // Gunakan .when() untuk menangani SEMUA state dari provider auth
  return authState.when(
    data: (user) {
      if (user != null) {
        // SUKSES: User login, BUKA stream ke dokumen 'users/[UID]'
        return db.collection('users').doc(user.uid).snapshots();
      } else {
        // SUKSES: User logout, kembalikan stream snapshot kosong
        return Stream.value(_EmptyDocumentSnapshot());
      }
    },
    loading: () {
      // LOADING: Auth masih loading, provider ini juga loading.
      // Kembalikan stream yang tidak pernah emit (menjaga state loading)
      return const Stream.empty();
    },
    error: (e, s) {
      // ERROR: Auth error, teruskan error
      return Stream.error(e);
    },
  );
});

/// Provider 3: Provider AppUser (Provider Publik untuk UI)
/// KUNCI UTAMA: Ini yang akan di-watch oleh UI.
/// Menggabungkan state Auth dan state Dokumen Firestore.
/// [KOREKSI KUNCI]: Logika ini sekarang disederhanakan karena provider
/// di atas sudah menangani state loading auth.
final firestoreUserProvider = StreamProvider.autoDispose<AppUser>((ref) {
  
  // Perhatikan DUA provider sekaligus
  final authState = ref.watch(authStateChangesProvider);
  final docAsyncValue = ref.watch(_userDocumentStreamProvider);

  // Ambil data user dari auth state (bisa null jika logout)
  final authUser = authState.value;

  // Skenario 1: authUser atau dokumen masih loading
  if (authUser == null && authState.isLoading) {
     return const Stream.empty(); // Auth masih loading
  }
  if (!docAsyncValue.hasValue) {
     return const Stream.empty(); // Dokumen masih loading
  }

  // Skenario 2: Auth error atau Dokumen error
  if (authState.hasError) return Stream.error(authState.error!);
  if (docAsyncValue.hasError) return Stream.error(docAsyncValue.error!);
  
  // Skenario 3: User Logout (authUser adalah null TAPI authState tidak loading)
  if (authUser == null) {
    return Stream.value(AppUser.empty); // Kembalikan data kosong
  }

  // Skenario 4: Sukses (User Login dan Dokumen Terbaca)
  final doc = docAsyncValue.value;
  if (doc != null) {
    // Gabungkan data Auth (authUser) dan data Dokumen (doc)
    final appUser = AppUser.fromFirestore(authUser, doc);
    return Stream.value(appUser);
  }
  
  // Fallback (seharusnya tidak terjadi, tapi untuk keamanan)
  return const Stream.empty();
});

// --- Helper Class (Diperlukan untuk state logout) ---
// Kelas helper privat untuk mengembalikan DocumentSnapshot palsu yang "kosong".
class _EmptyDocumentSnapshot implements DocumentSnapshot<Map<String, dynamic>> {
  @override
  bool get exists => false;

  @override
  Map<String, dynamic>? data() => null;
  
  @override
  dynamic operator [](Object field) => null;

  @override
  dynamic get(Object field) => null;
  @override
  T? getAs<T>(String field) => null;
  @override
  String get id => '';
  @override
  DocumentReference<Map<String, dynamic>> get reference =>
      throw UnimplementedError();
  @override
  SnapshotMetadata get metadata => throw UnimplementedError();
}