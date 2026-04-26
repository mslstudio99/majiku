//===================================================================//
// NAMA FILE: MAIN.DART                                              //
// PATH: LIB/MAIN.DART                                               //
//===================================================================//

// [RILIS KHUSUS TESTING - APP CHECK DISABLED]
// KATEGORI_CONFIG_UPDATE NO_URUT_06
// TUJUAN:
// 1. MEMATIKAN App Check sementara agar Generasi Narasi jalan (Bypass Error 403).
// 2. Tetap menggunakan Tema Dark Modern.
// 3. Routing Otomatis (Login/Dashboard).
// 4. [MODIFIKASI BARU] Menambahkan Logic Force Update via Firestore.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'; // Untuk kDebugMode
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart'; // [TAMBAHAN BARU]

// [IMPORT APP CHECK - Disimpan untuk nanti]
import 'package:firebase_app_check/firebase_app_check.dart';

import 'package:majiku/screens/login_screen.dart'; 
import 'package:majiku/screens/project_dashboard_screen.dart'; 
import 'package:majiku/screens/force_update_screen.dart'; // [TAMBAHAN BARU] Layar blokir
import 'firebase_options.dart';
import 'view_model/auth_view_model.dart';
import 'package:majiku/theme/app_theme.dart';
import 'package:majiku/providers/config_provider.dart'; // [TAMBAHAN BARU] Untuk narik config firestore

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
    return MaterialApp(
      title: 'Majiku',
      debugShowCheckedModeBanner: false,
      
      // Tema Global (Dark Modern)
      theme: AppTheme.darkTheme, 
      
      // [MODIFIKASI BARU] Membungkus root dengan UpdateWrapper
      home: const UpdateWrapper(),
    );
  }
}

//No ke-1............................................................//
// WRAPPER LOGIC FORCE UPDATE & ROUTING OTOMATIS                     //
class UpdateWrapper extends ConsumerWidget {
  const UpdateWrapper({super.key});

  // Fungsi helper untuk membandingkan versi (Format: X.Y.Z)
  bool _isVersionLower(String currentVersion, String minVersion) {
    List<int> currentParts = currentVersion.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    List<int> minParts = minVersion.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    for (int i = 0; i < 3; i++) {
      int current = i < currentParts.length ? currentParts[i] : 0;
      int min = i < minParts.length ? minParts[i] : 0;
      
      if (current < min) return true; // Versi HP lebih rendah dari minimum
      if (current > min) return false; // Versi HP lebih tinggi (aman)
    }
    return false; // Versi sama (aman)
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Memantau Config dari Firestore
    final configAsync = ref.watch(appConfigProvider);

    return configAsync.when(
      data: (config) {
        // Jika config didapat, baca versi HP pengguna
        return FutureBuilder<PackageInfo>(
          future: PackageInfo.fromPlatform(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildLoading();
            }
            
            if (snapshot.hasData) {
              final currentVersion = snapshot.data!.version; // cth: "2.0.4"
              final minVersion = config.minAppVersion; // cth: "2.0.5"

              // Pengecekan logika pemblokiran
              if (_isVersionLower(currentVersion, minVersion)) {
                // VERSI USANG -> LEMPAR KE LAYAR BLOKIR
                return ForceUpdateScreen(playStoreUrl: config.playStoreUrl);
              }
            }
            
            // VERSI AMAN -> LANJUTKAN KE ROUTING ASLI (LOGIN / DASHBOARD)
            return _buildMainRouting(ref);
          },
        );
      },
      loading: () => _buildLoading(),
      error: (error, stack) {
        // Jika gagal ngambil config, biarkan masuk (Failsafe agar tidak stuck selamanya)
        debugPrint("Gagal mengambil Config Force Update: $error");
        return _buildMainRouting(ref); 
      },
    );
  }

  // UI Loading standar
  Widget _buildLoading() {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(child: CircularProgressIndicator(color: Colors.purpleAccent)),
    );
  }

  // Routing asli Anda yang tidak dirubah
  Widget _buildMainRouting(WidgetRef ref) {
    final authState = ref.watch(authStateChangesProvider);
    return authState.when(
      data: (user) {
        if (user != null) {
          return const ProjectDashboardScreen();
        }
        return const LoginScreen();
      },
      loading: () => _buildLoading(),
      error: (error, stack) => Scaffold(
        body: Center(child: Text("Error Init: $error")),
      ),
    );
  }
}
//-------------------------------------------------------------------//