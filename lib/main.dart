// KATEGORI_PENYESUAIAN_TEMA NO_URUT_03
// NAMA FILE: lib/main.dart
// TUJUAN: Mengaktifkan "Dark Modern Theme" (Hitam/Ungu/Emas)
// secara global di level MaterialApp.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:majiku/screens/login_screen.dart'; // <-- DIPERBAIKI
import 'package:majiku/screens/project_dashboard_screen.dart'; // <-- DIPERBAIKI
import 'firebase_options.dart';
import 'view_model/auth_view_model.dart';

// --- KATEGORI_PENYESUAIAN_TEMA (PERUBAHAN 1): Impor tema ---
import 'package:majiku/theme/app_theme.dart';
// --- AKHIR PENYESUAIAN_TEMA ---

// Pastikan alamat ini benar. "localhost" adalah yang paling umum.
const String emulatorHost = "localhost";

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // --- KATEGORI: KONFIGURASI / NO_URUT: 01 ---
  // Penyesuaian: Blok emulator dimatikan (diberi komentar)
  // untuk beralih dari mode Emulator Lokal ke mode Firebase LIVE (Deploy).
  /*
  // Blok krusial untuk koneksi ke emulator
  if (kDebugMode) {
    try {
      print("===== MENGHUBUNGKAN KE EMULATOR LOKAL =====");
      await FirebaseAuth.instance.useAuthEmulator(emulatorHost, 9099);
      FirebaseFirestore.instance.useFirestoreEmulator(emulatorHost, 8080);
      print("===== BERHASIL TERHUBUNG KE EMULATOR =====");
    } catch (e) {
      print("!!! GAGAL TERHUBUNG KE EMULATOR: $e");
    }
  }
  */
  // --- AKHIR PENYESUAIAN ---

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

// ... sisa kode MyApp tetap sama ...

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateChangesProvider);

    return MaterialApp(
      title: 'Majiku',
      debugShowCheckedModeBanner: false,

      // --- KATEGORI_PENYESUAIAN_TEMA (PERUBAHAN 2): Terapkan Tema Global ---
      // Menghapus ThemeData(primarySwatch: Colors.indigo...) yang lama
      // dan menggantinya dengan tema "Dark Modern" (Hitam/Ungu/Emas).
      theme: AppTheme.darkTheme,
      // --- AKHIR PENYESUAIAN_TEMA ---

      home: authState.when(
        data: (user) {
          if (user != null) {
            return const ProjectDashboardScreen();
          }
          return const LoginScreen();
        },
        loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (error, stack) => Scaffold(body: Center(child: Text("Error: $error"))),
      ),
    );
  }
}