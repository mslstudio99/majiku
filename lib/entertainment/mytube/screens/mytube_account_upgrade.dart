//============================================================================//
// DIREKTORI: lib/entertainment/mytube/screens/                              //
// FILE: MYTUBE_ACCOUNT_UPGRADE.DART                                         //
// LAYAR PENDAFTARAN & MANAJEMEN STATUS AKUN CREATOR MYTUBE (ADMIN PUSAT)    //
//============================================================================//

//No ke-1....................................................................//
//IMPORTS & DEPENDENCIES                                                     //
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../providers/config_provider.dart';
import '../services/firestore_mytube_service.dart';
//............................................................................//

//No ke-2....................................................................//
//WIDGET DECLARATION & STATE SETUP                                           //
class MytubeAccountUpgradeScreen extends ConsumerStatefulWidget {
  const MytubeAccountUpgradeScreen({super.key});

  @override
  ConsumerState<MytubeAccountUpgradeScreen> createState() => _MytubeAccountUpgradeScreenState();
}

class _MytubeAccountUpgradeScreenState extends ConsumerState<MytubeAccountUpgradeScreen> {
  final FirestoreMytubeService _service = FirestoreMytubeService();
  final TextEditingController _emailSearchController = TextEditingController();

  bool _isSearching = false;
  bool _isProcessing = false;
  Map<String, dynamic>? _searchedUserData;
  String? _searchMessage;
//............................................................................//

//No ke-3....................................................................//
//LIFECYCLE & SEARCH/UPGRADE LOGIC                                           //
  @override
  void dispose() {
    _emailSearchController.dispose();
    super.dispose();
  }

  // 1. Logika Pencarian Akun Pengguna
  Future<void> _handleSearchUser(bool isIndo) async {
    final email = _emailSearchController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isIndo ? 'Masukkan alamat email yang ingin dicari.' : 'Enter email address to search.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() {
      _isSearching = true;
      _searchMessage = null;
      _searchedUserData = null;
    });

    final userData = await _service.findUserByEmail(email);

    if (mounted) {
      setState(() {
        _isSearching = false;
        if (userData != null) {
          _searchedUserData = userData;
        } else {
          _searchMessage = isIndo
              ? 'Akun dengan email "$email" tidak ditemukan di sistem Majiku.'
              : 'User with email "$email" was not found in the Majiku system.';
        }
      });
    }
  }

  // 2. Logika Upgrade ke Creator (Hijau Emerald)
  Future<void> _handleUpgradeToCreator(bool isIndo) async {
    if (_searchedUserData == null) return;
    final uid = _searchedUserData!['uid'] as String;
    final email = _searchedUserData!['email'] as String;
    final name = _searchedUserData!['displayName'] as String?;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.verified_user_rounded, color: Color(0xFF10B981), size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isIndo ? 'Jadikan Akun Creator?' : 'Upgrade to Creator?',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          isIndo
              ? 'Akun "$email" akan mendapatkan akses penuh ke Studio Creator MyTube untuk mengunggah Short dan Long Video.'
              : 'Account "$email" will get full access to MyTube Creator Studio to upload Shorts and Long Videos.',
          style: const TextStyle(color: Colors.white70, fontSize: 13.5, height: 1.4),
        ),
        actions: [
          TextButton(
            child: Text(isIndo ? 'Batal' : 'Cancel', style: const TextStyle(color: Colors.white54)),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
            ),
            child: Text(isIndo ? 'Ya, Jadikan Creator' : 'Yes, Make Creator', style: const TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isProcessing = true);
      final success = await _service.upgradeUserToCreator(uid, targetEmail: email, displayName: name);

      if (mounted) {
        setState(() {
          _isProcessing = false;
          if (success) {
            _searchedUserData!['userTier'] = 'creator';
            _searchedUserData!['role'] = 'creator';
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? (isIndo ? 'Berhasil! Akun resmi menjadi Creator MyTube.' : 'Success! Account is now an official MyTube Creator.')
                  : (isIndo ? 'Gagal mengubah status akun.' : 'Failed to update account status.'),
              style: const TextStyle(fontSize: 14),
            ),
            backgroundColor: success ? const Color(0xFF10B981) : Colors.redAccent,
          ),
        );
      }
    }
  }

  // 3. Logika Downgrade ke Free User
  Future<void> _handleDowngradeToFree(String uid, String email, bool isIndo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.remove_circle_outline_rounded, color: Colors.orangeAccent, size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isIndo ? 'Cabut Akses Creator?' : 'Revoke Creator Access?',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          isIndo
              ? 'Status akun "$email" akan dikembalikan menjadi User Free biasa. Akun ini tidak akan bisa mengunggah video lagi.'
              : 'Account "$email" will be downgraded to Free User and will no longer be able to upload videos.',
          style: const TextStyle(color: Colors.white70, fontSize: 13.5, height: 1.4),
        ),
        actions: [
          TextButton(
            child: Text(isIndo ? 'Batal' : 'Cancel', style: const TextStyle(color: Colors.white54)),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orangeAccent,
              foregroundColor: Colors.black,
            ),
            child: Text(isIndo ? 'Ya, Kembalikan ke Free' : 'Yes, Downgrade to Free', style: const TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isProcessing = true);
      final success = await _service.downgradeUserToFree(uid, targetEmail: email);

      if (mounted) {
        setState(() {
          _isProcessing = false;
          if (success && _searchedUserData != null && _searchedUserData!['uid'] == uid) {
            _searchedUserData!['userTier'] = 'free';
            _searchedUserData!['role'] = 'user';
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? (isIndo ? 'Akses creator berhasil dicabut (Kembali ke Free).' : 'Creator access revoked (Back to Free User).')
                  : (isIndo ? 'Gagal mengubah status akun.' : 'Failed to downgrade account.'),
              style: const TextStyle(fontSize: 14),
            ),
            backgroundColor: success ? Colors.orangeAccent : Colors.redAccent,
          ),
        );
      }
    }
  }
//............................................................................//

//No ke-4....................................................................//
//MAIN BUILD & SEARCH INPUT BAR                                              //
  @override
  Widget build(BuildContext context) {
    final currentLocale = ref.watch(appLanguageProvider);
    final isIndo = currentLocale.languageCode == 'id';
    String t(String en, String id) => isIndo ? id : en;

    return Scaffold(
      backgroundColor: const Color(0xFF121214),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E24),
        elevation: 0,
        title: Text(
          t('Mytube Account Upgrade', 'Pendaftaran Creator Mytube'),
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner Info
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.admin_panel_settings_rounded, color: Color(0xFF10B981), size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      t(
                        'Central Admin Tool: Register and manage creator memberships for MyTube.',
                        'Fitur Admin Pusat: Daftarkan dan kelola keanggotaan creator untuk MyTube.',
                      ),
                      style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // Baris Pencarian Email
            Text(
              t('SEARCH USER ACCOUNT BY EMAIL', 'CARI AKUN PENGGUNA BERDASARKAN EMAIL'),
              style: const TextStyle(
                color: Color(0xFF10B981),
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _emailSearchController,
                    style: const TextStyle(color: Colors.white, fontSize: 14.5),
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: t('Enter user email (e.g. user@gmail.com)', 'Ketik email user (cth: user@gmail.com)'),
                      hintStyle: const TextStyle(color: Colors.white24, fontSize: 13.5),
                      prefixIcon: const Icon(Icons.search, color: Colors.white54, size: 22),
                      filled: true,
                      fillColor: const Color(0xFF1E1E24),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    onSubmitted: (_) => _handleSearchUser(isIndo),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      elevation: 0,
                    ),
                    onPressed: _isSearching ? null : () => _handleSearchUser(isIndo),
                    child: _isSearching
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(t('Check', 'Cari'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Pesan Error jika tidak ditemukan
            if (_searchMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.redAccent, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(_searchMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
            ],

            // Kartu Hasil Pencarian
            if (_searchedUserData != null) ...[
              _buildSearchResultCard(t, isIndo),
              const SizedBox(height: 28),
            ],

            const Divider(color: Colors.white12, height: 32),

            // Daftar Seluruh Creator yang Sedang Aktif
            Text(
              t('CURRENT ACTIVE CREATORS', 'DAFTAR KREATOR AKTIF SAAT INI'),
              style: const TextStyle(
                color: Color(0xFF10B981),
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 12),
            _buildActiveCreatorsStream(t, isIndo),
          ],
        ),
      ),
    );
  }
//............................................................................//

//No ke-5....................................................................//
//SEARCH RESULT CARD & UPGRADE/DOWNGRADE ACTION BUTTONS                      //
  Widget _buildSearchResultCard(String Function(String, String) t, bool isIndo) {
    final data = _searchedUserData!;
    final email = data['email'] as String? ?? '-';
    final name = data['displayName'] as String? ?? 'Pengguna';
    final uid = data['uid'] as String? ?? '-';
    final tier = (data['userTier'] as String? ?? 'free').toLowerCase();

    final isCreator = tier == 'creator';
    final isAdmin = tier == 'admin';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E24),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCreator ? const Color(0xFF10B981) : Colors.white24,
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: isCreator ? const Color(0xFF10B981).withOpacity(0.2) : Colors.white10,
                child: Icon(
                  isCreator ? Icons.verified : (isAdmin ? Icons.security : Icons.person),
                  color: isCreator ? const Color(0xFF10B981) : (isAdmin ? Colors.amberAccent : Colors.white54),
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      email,
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
              _buildTierBadge(tier),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 10),

          Text(
            'UID: $uid',
            style: const TextStyle(color: Colors.white30, fontSize: 11, fontFamily: 'monospace'),
          ),
          const SizedBox(height: 14),

          // Tombol Aksi (Tergantung Status Akun)
          if (isAdmin) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.security, color: Colors.amberAccent, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      t('This is an Admin account with full system access.', 'Ini adalah akun Admin Pusat dengan akses tertinggi.'),
                      style: const TextStyle(color: Colors.amberAccent, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (isCreator) ...[
            // Akun sudah Creator -> Tombol Kembalikan ke Free User
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orangeAccent,
                  side: const BorderSide(color: Colors.orangeAccent, width: 1.2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.remove_circle_outline_rounded, size: 18),
                label: Text(
                  t('Revoke Creator Access (Back to Free)', 'Cabut Akses Creator (Kembalikan ke Free)'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                onPressed: _isProcessing ? null : () => _handleDowngradeToFree(uid, email, isIndo),
              ),
            ),
          ] else ...[
            // Akun belum Creator -> Tombol Upgrade ke Creator (Hijau Emerald)
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.verified, size: 18),
                label: Text(
                  t('Approve & Upgrade to Creator', 'Setujui & Jadikan Creator MyTube'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                ),
                onPressed: _isProcessing ? null : () => _handleUpgradeToCreator(isIndo),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTierBadge(String tier) {
    Color color = Colors.blueGrey;
    String label = 'FREE USER';

    if (tier == 'creator') {
      color = const Color(0xFF10B981);
      label = 'CREATOR';
    } else if (tier == 'admin') {
      color = Colors.amberAccent;
      label = 'ADMIN';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
      ),
    );
  }
//............................................................................//

//No ke-6....................................................................//
//ACTIVE CREATORS LIST STREAMBUILDER (REALTIME DASHBOARD)                    //
  Widget _buildActiveCreatorsStream(String Function(String, String) t, bool isIndo) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _service.streamActiveCreators(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)));
        }

        final creators = snapshot.data ?? [];

        if (creators.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E24),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Column(
                children: [
                  const Icon(Icons.people_outline, color: Colors.white24, size: 40),
                  const SizedBox(height: 8),
                  Text(
                    t('No active creators yet.', 'Belum ada creator aktif.'),
                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: creators.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final c = creators[index];
            final email = c['email'] as String;
            final name = c['displayName'] as String;
            final uid = c['uid'] as String;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E24),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified, color: Color(0xFF10B981), size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5)),
                        Text(email, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: Colors.orangeAccent, size: 20),
                    tooltip: t('Revoke to Free', 'Cabut ke Free'),
                    onPressed: () => _handleDowngradeToFree(uid, email, isIndo),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
//............................................................................//