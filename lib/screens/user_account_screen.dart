//..................................................//
// LIB/SCREENS/USER_ACCOUNT_SCREEN.DART             //
//..................................................//

//No ke-1: IMPORTS .................................//
//..................................................//
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart'; // Tambahan untuk eksekusi tautan

import '../providers/user_provider.dart';
import '../view_model/auth_view_model.dart';
import '../providers/config_provider.dart';
//..................................................//

//No ke-2: WIDGET CLASS & HELPERS ..................//
//..................................................//
class UserAccountScreen extends ConsumerWidget {
  const UserAccountScreen({super.key});

  // Helper sederhana untuk menerjemahkan teks berdasarkan kode bahasa
  String _t(bool isIndo, String en, String id) {
    return isIndo ? id : en;
  }

  // Helper untuk membangun UI Baris Info
  Widget _buildInfoRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // Helper untuk membuka URL eksternal (Browser / PlayStore)
  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $urlString');
    }
  }

  // Helper untuk UI Tombol Platform yang Modern (Solid Color & Ripple Effect)
  Widget _buildPlatformButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required String url,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.4), // Shadow lebih kuat untuk kesan melayang (3D)
            blurRadius: 12,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Material(
        color: color, // Latar belakang warna solid
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          splashColor: Colors.white.withOpacity(0.3), // Efek ripple putih saat disentuh
          highlightColor: Colors.white.withOpacity(0.1), // Efek hover/tekan
          onTap: () => _launchURL(url),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
               children: [
                 Container(
                   padding: const EdgeInsets.all(12),
                   decoration: BoxDecoration(
                     color: Colors.white.withOpacity(0.2), // Lingkaran transparan
                     shape: BoxShape.circle,
                   ),
                   child: Icon(icon, color: Colors.white, size: 28),
                 ),
                 const SizedBox(width: 16),
                 Expanded(
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       Text(
                         title,
                         style: const TextStyle(
                           fontWeight: FontWeight.bold, 
                           fontSize: 16,
                           color: Colors.white, // Teks putih agar kontras
                         ),
                       ),
                       const SizedBox(height: 4),
                       Text(
                         subtitle,
                         style: const TextStyle(
                           color: Colors.white70, // Teks subtitle putih agak pudar
                           fontSize: 13
                         ),
                       ),
                     ],
                   ),
                 ),
                 const Icon(Icons.open_in_new, color: Colors.white70, size: 20),
               ],
            ),
          ),
        ),
      ),
    );
  }
//..................................................//

//No ke-3: MAIN BUILD & APPBAR .....................//
//..................................................//
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // KUNCI 1: Watch Data User
    final userAsyncValue = ref.watch(firestoreUserProvider);
    
    // KUNCI 2: Watch State Bahasa
    final currentLocale = ref.watch(appLanguageProvider);
    final isIndo = currentLocale.languageCode == 'id';

    return Scaffold(
      appBar: AppBar(
        // Judul berubah sesuai bahasa
        title: Text(_t(isIndo, 'My Account', 'Akun Saya')),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: _t(isIndo, 'Sign Out', 'Keluar'),
            onPressed: () {
              ref.read(authViewModelProvider.notifier).signOut();
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
            },
          ),
        ],
      ),
//..................................................//

//No ke-4: STATE HANDLING (LOADING & ERROR) ........//
//..................................................//
      body: userAsyncValue.when(
        // --- 1. State Loading ---
        loading: () => const Center(child: CircularProgressIndicator()),

        // --- 2. State Error ---
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              _t(isIndo, 'Error loading user data: $error', 'Gagal memuat data pengguna: $error'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ),
//..................................................//

//No ke-5: STATE DATA (SUCCESS) & MAIN UI ..........//
//..................................................//
        // --- 3. State Data (Sukses) ---
        data: (user) {
          if (user.uid.isEmpty) {
            return Center(
              child: Text(_t(isIndo, 'User not logged in.', 'Pengguna belum login.')),
            );
          }

          return ListView( // Menggunakan ListView agar bisa scroll jika konten panjang
            padding: const EdgeInsets.all(24.0),
            children: [
              Text(
                _t(isIndo, 'Account Details', 'Detail Akun'),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              
              // --- Detail User ---
              _buildInfoRow('Email', user.email),
              const Divider(),
              _buildInfoRow(
                _t(isIndo, 'Membership Status', 'Status Keanggotaan'),
                user.userTier.toUpperCase(),
              ),
              const Divider(),
              _buildInfoRow(
                _t(isIndo, 'Token Majiku (TM)', 'Token Majiku (TM)'),
                user.tokenBalance.toString(),
              ),
              const Divider(),
              
              const SizedBox(height: 40),

              // --- Bagian Pengaturan Aplikasi ---
              Text(
                _t(isIndo, 'App Settings', 'Pengaturan Aplikasi'),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              
              // Kartu Pengaturan Bahasa
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.language, color: Colors.blueGrey),
                      title: Text(_t(isIndo, 'Language', 'Bahasa')),
                      subtitle: Text(isIndo ? 'Indonesia' : 'English'),
                      trailing: Switch(
                        activeColor: Colors.blue,
                        value: isIndo,
                        onChanged: (val) {
                          // Logika Ganti Bahasa
                          if (val) {
                            ref.read(appLanguageProvider.notifier).state = const Locale('id');
                          } else {
                            ref.read(appLanguageProvider.notifier).state = const Locale('en');
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // --- Bagian Platform Eksternal (BARU) ---
              Text(
                _t(isIndo, 'Other Platforms', 'Platform Lainnya'),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              
              // Tombol Versi Web (Ungu)
              _buildPlatformButton(
                icon: Icons.language,
                title: _t(isIndo, 'Web Version', 'Versi Web'),
                subtitle: 'app.majiku.net',
                url: 'https://app.majiku.net/',
                color: Colors.deepPurple,
              ),

              // Tombol Versi App (Google Play - Hijau)
              _buildPlatformButton(
                icon: Icons.shop,
                title: _t(isIndo, 'App Version', 'Versi Aplikasi'),
                subtitle: 'Google Play Store',
                url: 'https://play.google.com/store/apps/details?id=com.mslstudio.majiku',
                color: Colors.green,
              ),
              
              const SizedBox(height: 20), // Spacing tambahan di paling bawah
            ],
          );
        },
      ),
    );
  }
}
//..................................................//