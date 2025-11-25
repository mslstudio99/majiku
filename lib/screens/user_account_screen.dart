/*
KATEGORI_ARSITEKTUR_BARU NO_URUT_03 (KOREKSI KARAKTER)
Nama File: lib/screens/user_account_screen.dart
Tujuan:
- (Koreksi) Membersihkan semua karakter non-ASCII (U+00A0)
- Menangani state Loading dan Error dari provider.
*/

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// 1. Impor provider data user (yang baru dibuat)
import '../providers/user_provider.dart';

// 2. Impor provider auth (untuk fungsi logout)
import '../view_model/auth_view_model.dart';

class UserAccountScreen extends ConsumerWidget {
  const UserAccountScreen({super.key});

  // Helper untuk membangun UI
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
    // KUNCI UTAMA: Memperhatikan provider data user kustom
    final userAsyncValue = ref.watch(firestoreUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Account'),
        // Tombol Logout
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: () {
              // Panggil provider LAMA
              ref.read(authViewModelProvider.notifier).signOut();
              // Kembali ke layar sebelumnya
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
              'Error loading user data: $error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ),

        // --- 3. State Data (Sukses) ---
        data: (user) {
          // Cek jika data 'empty' (berarti user logout)
          if (user.uid.isEmpty) {
            return const Center(
              child: Text('User not logged in.'),
            );
          }

          // Tampilkan data user
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Account Details',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                _buildInfoRow('Email', user.email),
                const Divider(),
                _buildInfoRow(
                  'Membership Status',
                  // Menggunakan 'userTier' (akan menampilkan 'free' jika tidak ada)
                  user.userTier.toUpperCase(),
                ),
                const Divider(),
                _buildInfoRow(
                  'Token Majiku (TM)',
                  // Menampilkan saldo token
                  user.tokenBalance.toString(),
                ),
                const Divider(),
                // Nanti bisa ditambahkan tombol untuk 'Beli Token' atau 'Upgrade'
              ],
            ),
          );
        },
      ),
    );
  }
}