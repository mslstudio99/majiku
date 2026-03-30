// [RILIS KHUSUS TESTING - APP CHECK DISABLED]
// KATEGORI_CONFIG_UPDATE NO_URUT_06
// TUJUAN:
// 1. MEMATIKAN App Check sementara agar Generasi Narasi jalan (Bypass Error 403).
// 2. Tetap menggunakan Tema Dark Modern.
// 3. Routing Otomatis (Login/Dashboard).

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'; // Untuk kDebugMode
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// [IMPORT APP CHECK - Disimpan untuk nanti]
import 'package:firebase_app_check/firebase_app_check.dart';

import 'package:majiku/screens/login_screen.dart'; 
import 'package:majiku/screens/project_dashboard_screen.dart'; 
import 'firebase_options.dart';
import 'view_model/auth_view_model.dart';
import 'package:majiku/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // --- [MODIFIKASI SEMENTARA: APP CHECK DIMATIKAN] ---
  // Saya menonaktifkan blok ini agar aplikasi TIDAK mengirim token error ke server.
  // Karena server sudah 'Unenforced', request akan diterima tanpa token ini.
  
  /* // ^^^ KODE INI AKAN KITA NYALAKAN LAGI SAAT MAU UPLOAD PLAY STORE ^^^
  
  await FirebaseAppCheck.instance.activate(
    androidProvider: kDebugMode 
        ? AndroidProvider.debug 
        : AndroidProvider.playIntegrity,
    appleProvider: AppleProvider.appAttest,
  );
  
  */ 
  // -----------------------------------------------------

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateChangesProvider);

    return MaterialApp(
      title: 'Majiku',
      debugShowCheckedModeBanner: false,
      
      // Tema Global (Dark Modern)
      theme: AppTheme.darkTheme, 
      
      home: authState.when(
        data: (user) {
          if (user != null) {
            return const ProjectDashboardScreen();
          }
          return const LoginScreen();
        },
        loading: () => const Scaffold(
          backgroundColor: Colors.black,
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (error, stack) => Scaffold(
          body: Center(child: Text("Error Init: $error")),
        ),
      ),
    );
  }
}