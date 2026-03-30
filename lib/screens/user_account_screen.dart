// KATEGORI_UI_UPDATE NO_URUT_02
// NAMA FILE: lib/screens/user_account_screen.dart
// TUJUAN:
// - Menampilkan data user.
// - Menambahkan fitur Ganti Bahasa (Inggris <-> Indonesia).
// - Menerapkan terjemahan pada teks UI.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// 1. Impor provider data user
import '../providers/user_provider.dart';

// 2. Impor provider auth (untuk logout)
import '../view_model/auth_view_model.dart';

// 3. Impor provider config (untuk bahasa)
import '../providers/config_provider.dart';

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
              const SizedBox(height: 10),
              
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
                            // Jika Switch ON -> Set ke Indonesia
                            ref.read(appLanguageProvider.notifier).state = const Locale('id');
                          } else {
                            // Jika Switch OFF -> Set ke English
                            ref.read(appLanguageProvider.notifier).state = const Locale('en');
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}