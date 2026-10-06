
//................................................................//
// NAMA FILE: MAIN.DART                                           //
// PATH/DIREKTORI: lib/main.dart                                   //
// FUNGSI UTAMA: ENTRY POINT APLIKASI & ROUTER SENTRAL             //
//................................................................//

//No ke-1.........................................................//
// IMPORT, INISIALISASI FIREBASE, ADMOB & ROOT WIDGET             //
import 'dart:io' show Platform;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart'; // Impor SDK Google Mobile Ads

// [IMPORT APP CHECK - Disimpan untuk nanti]
import 'package:firebase_app_check/firebase_app_check.dart';

// Layar Aplikasi
import 'package:majiku/screens/login_screen.dart'; 
import 'package:majiku/screens/project_dashboard_screen.dart'; 
import 'package:majiku/screens/force_update_screen.dart';
import 'package:majiku/screens/verify_email_screen.dart';

// Provider & Konfigurasi
import 'firebase_options.dart';
import 'view_model/auth_view_model.dart';
import 'package:majiku/theme/app_theme.dart';
import 'package:majiku/providers/config_provider.dart';
import 'package:majiku/providers/user_provider.dart';

/*
KATEGORI_CONFIG_UPDATE NO_URUT_07 (REVISI PARIPURNA - ZERO FLICKER ROUTING & ANTI REGRESI)
Nama File: lib/main.dart
Tujuan:
- [ZERO FLICKER] Menghilangkan kedipan Dashboard saat user baru mendaftar.
- [ANTI-REGRESI LAMA] Mengizinkan akun lama langsung masuk tanpa halangan verifikasi.
- [ROUTER SENTRAL] Memilah user baru unverified langsung ke VerifyEmailScreen.
- [FORCE UPDATE] Tetap mempertahankan logika force update via Firestore.
- [BARU: GOOGLE ADMOB] Menginisialisasi SDK iklan AdMob di awal (tanpa pre-load global).
*/

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Inisialisasi Google Mobile Ads SDK (Hanya menyiapkan pustaka di memori)
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    try {
      await MobileAds.instance.initialize();
      debugPrint("✅ Google Mobile Ads SDK berhasil diinisialisasi.");
    } catch (e) {
      debugPrint("⚠️ Peringatan: Gagal inisialisasi MobileAds: $e");
    }
  }

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
      
      // Membungkus root dengan UpdateWrapper
      home: const UpdateWrapper(),
    );
  }
}
//................................................................//

//No ke-2.........................................................//
// WRAPPER LOGIC FORCE UPDATE & ROUTING OTOMATIS                  //
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
        return FutureBuilder<PackageInfo>(
          future: PackageInfo.fromPlatform(),
          builder: (context, snapshot) {
            // [ANTI-FLICKER]: Kunci tampilan loading hanya saat data benar-benar belum ada.
            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
              return _buildLoading();
            }
            
            if (snapshot.hasData) {
              final currentVersion = snapshot.data!.version;
              final minVersion = config.minAppVersion;

              // Pengecekan logika pemblokiran force update
              if (_isVersionLower(currentVersion, minVersion)) {
                return ForceUpdateScreen(playStoreUrl: config.playStoreUrl);
              }
            }
            
            // Versi aman -> Masuk ke Routing Utama
            return _buildMainRouting(ref);
          },
        );
      },
      loading: () => _buildLoading(),
      error: (error, stack) {
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

  // Routing Utama (Bebas Jebakan, End-to-End Mulus)
  Widget _buildMainRouting(WidgetRef ref) {
    final authState = ref.watch(authStateChangesProvider);

    return authState.when(
      data: (user) {
        // Skenario 1: Tidak ada sesi user aktif -> Halaman Login
        if (user == null) {
          return const LoginScreen();
        }

        // CEK 1: Status Auth SDK Paling Mutakhir
        // Menangkap status seketika setelah user klik tautan dari email
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null && currentUser.emailVerified) {
          return const ProjectDashboardScreen();
        }

        // CEK 2: Bukti Fisik dari Firestore
        // Diletakkan DI ATAS pengecekan waktu agar user yang sudah diverifikasi
        // tidak akan pernah terjebak di layar VerifyEmailScreen!
        final appUserAsync = ref.watch(firestoreUserProvider);
        final appUser = appUserAsync.asData?.value;

        if (appUser != null && appUser.uid.isNotEmpty) {
          // Jika Sah (Email Verified / Bonus Cair / Saldo > 0) -> Langsung Dashboard!
          if (appUser.isEmailVerified || appUser.hasReceivedWelcomeBonus || appUser.tokenBalance > 0) {
            return const ProjectDashboardScreen();
          }
          // Jika Profil sudah turun tapi belum verifikasi -> Tunggu di Verify Screen
          return const VerifyEmailScreen();
        }

        // CEK 3: Masa Transisi Loading Profil (Anti Kedip)
        final creationTime = user.metadata.creationTime;
        final lastSignInTime = user.metadata.lastSignInTime;
        bool isBrandNewRegistration = false;
        
        if (creationTime != null && lastSignInTime != null) {
          isBrandNewRegistration = lastSignInTime.difference(creationTime).inSeconds.abs() < 10;
        }

        if (isBrandNewRegistration) {
          // Pendaftar Baru: Langsung render Verify Screen tanpa berkedip loading spinner
          return const VerifyEmailScreen();
        }

        // Akun Lama: Tahan dengan loading spinner sampai profil selesai diunduh
        return _buildLoading();
      },
      loading: () => _buildLoading(),
      error: (error, stack) => Scaffold(
        body: Center(child: Text("Error Init: $error")),
      ),
    );
  }
}
//................................................................//