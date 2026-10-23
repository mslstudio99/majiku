//============================================================================//
// DIREKTORI: lib/entertainment/mytube/screens/                              //
// FILE: MYTUBE_ACCOUNT_UPGRADE.DART                                         //
// LAYAR PENDAFTARAN & MANAJEMEN STATUS AKUN CREATOR & ADMIN MYTUBE          //
//============================================================================//

//No ke-1....................................................................//
//IMPORTS & DEPENDENCIES                                                     //
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  User? _currentUser;
  bool _isSearching = false;
  bool _isProcessing = false;
  Map<String, dynamic>? _searchedUserData;
  String? _searchMessage;

  // [CHANNEL ID ADMIN SENDIRI]
  String? _adminChannelId;
  bool _isLoadingAdminChannel = true;
//............................................................................//

//No ke-3....................................................................//
//LIFECYCLE & ACTION HANDLERS (SEARCH, UPGRADE, DOWNGRADE, TRANSFER, REACTIVATE)//
  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    _loadAdminChannelInfo();
  }

  @override
  void dispose() {
    _emailSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadAdminChannelInfo() async {
    final uid = _currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      if (mounted) setState(() => _isLoadingAdminChannel = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (mounted) {
        setState(() {
          _adminChannelId = doc.data()?['channel_id']?.toString();
          _isLoadingAdminChannel = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingAdminChannel = false);
    }
  }

  Future<void> _handleCreateOwnAdminChannel(bool isIndo) async {
    final uid = _currentUser?.uid;
    final email = _currentUser?.email;
    final name = _currentUser?.displayName ?? 'Admin Official';

    if (uid == null || email == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.shield_rounded, color: Color(0xFF6366F1), size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isIndo ? 'Buat Channel Admin Sendiri?' : 'Create Own Admin Channel ID?',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          isIndo
              ? 'Sistem akan membuat Channel ID resmi berbasis Auto-ID Firestore untuk akun Admin Anda ($email). Anda akan memiliki akses upload video MyTube resmi dengan status tertinggi [ADMIN].'
              : 'The system will generate an official Firestore Auto-ID Channel for your Admin account ($email). You will be able to upload official MyTube videos with the highest [ADMIN] status.',
          style: const TextStyle(color: Colors.white70, fontSize: 13.5, height: 1.4),
        ),
        actions: [
          TextButton(
            child: Text(isIndo ? 'Batal' : 'Cancel', style: const TextStyle(color: Colors.white54)),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
            ),
            child: Text(isIndo ? 'Ya, Buat Channel' : 'Yes, Create Channel', style: const TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isProcessing = true);
      final res = await _service.createOrGetAdminOwnChannel(
        adminUid: uid,
        adminEmail: email,
        displayName: name,
      );

      if (mounted) {
        setState(() {
          _isProcessing = false;
          if (res['success'] == true) {
            _adminChannelId = res['channelId'];
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? (isIndo ? 'Proses selesai.' : 'Process completed.')),
            backgroundColor: (res['success'] == true) ? const Color(0xFF6366F1) : Colors.redAccent,
          ),
        );
      }
    }
  }

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
              ? 'Akun "$email" akan mendapatkan Channel ID resmi dan akses penuh ke Studio Creator MyTube.'
              : 'Account "$email" will receive an official Channel ID and full access to MyTube Creator Studio.',
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
            // [UX BERSIH]: Langsung tutup kartu pencarian dan bersihkan textfield
            _searchedUserData = null;
            _emailSearchController.clear();
            _searchMessage = null;
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? (isIndo ? 'Berhasil! Akun resmi menjadi Creator MyTube dan terdata di tabel bawah.' : 'Success! Account is now an official MyTube Creator.')
                  : (isIndo ? 'Gagal mengubah status akun.' : 'Failed to update account status.'),
              style: const TextStyle(fontSize: 14),
            ),
            backgroundColor: success ? const Color(0xFF10B981) : Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _handleDowngradeToFree(String uid, String email, bool isIndo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.pause_circle_outline_rounded, color: Colors.orangeAccent, size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isIndo ? 'Kembalikan Status ke Free?' : 'Revoke Status to Free?',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          isIndo
              ? 'Akses akun "$email" akan dikembalikan ke Free User. Saluran dan video tetap utuh tersimpan di data perusahaan.'
              : 'Access for "$email" will be revoked to Free User. Channel data and videos remain intact.',
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
            _searchedUserData!['previous_tier'] = _searchedUserData!['userTier'];
            _searchedUserData!['userTier'] = 'free';
            _searchedUserData!['role'] = 'user';
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? (isIndo ? 'Akses creator dicabut (Saluran masuk ke inventaris Non-Aktif).' : 'Access revoked (Channel moved to Dormant).')
                  : (isIndo ? 'Gagal mencabut status akun.' : 'Failed to revoke status.'),
              style: const TextStyle(fontSize: 14),
            ),
            backgroundColor: success ? Colors.orangeAccent : Colors.redAccent,
          ),
        );
      }
    }
  }

  // Logika Reaktivasi Saluran Non-Aktif
  Future<void> _handleReactivateChannel(String channelId, String email, bool isIndo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.settings_backup_restore_rounded, color: Color(0xFF10B981), size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isIndo ? 'Reaktivasi Saluran Ini?' : 'Reactivate This Channel?',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          isIndo
              ? 'Saluran dengan ID "$channelId" akan diaktifkan kembali dan ditautkan ke akun "$email".'
              : 'Channel "$channelId" will be reactivated and linked to account "$email".',
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
            child: Text(isIndo ? 'Ya, Reaktivasi' : 'Yes, Reactivate', style: const TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isProcessing = true);
      final res = await _service.reactivateChannel(channelId: channelId, email: email);

      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? (isIndo ? 'Selesai.' : 'Done.')),
            backgroundColor: (res['success'] == true) ? const Color(0xFF10B981) : Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _handleTransferEmailDialog(String channelId, String currentEmail, bool isIndo) async {
    final newEmailController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.swap_horiz_rounded, color: Colors.cyanAccent, size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isIndo ? 'Ganti Email Petugas Channel' : 'Transfer Channel Email',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isIndo
                  ? 'Email baru akan memegang Channel ID ini beserta seluruh videonya, dan otomatis aktif kembali jika sebelumnya non-aktif.'
                  : 'The new email will manage this Channel ID and its videos, and auto-reactivate if dormant.',
              style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.35),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Channel ID: $channelId', style: const TextStyle(color: Colors.amberAccent, fontSize: 11.5, fontFamily: 'monospace')),
                  const SizedBox(height: 3),
                  Text('${isIndo ? "Email Lama" : "Old Email"}: $currentEmail', style: const TextStyle(color: Colors.white54, fontSize: 11.5)),
                ],
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: newEmailController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                hintText: isIndo ? 'Ketik email petugas baru...' : 'Enter new staff email...',
                hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
                filled: true,
                fillColor: const Color(0xFF141418),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: Text(isIndo ? 'Batal' : 'Cancel', style: const TextStyle(color: Colors.white54)),
            onPressed: () => Navigator.of(ctx).pop(null),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.cyanAccent,
              foregroundColor: Colors.black,
            ),
            child: Text(isIndo ? 'Alihkan Hak Akses' : 'Transfer Ownership', style: const TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () {
              final email = newEmailController.text.trim();
              if (email.isNotEmpty) Navigator.of(ctx).pop(email);
            },
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && mounted) {
      setState(() => _isProcessing = true);

      final res = await _service.transferChannelOwnership(
        channelId: channelId,
        newEmail: result,
        oldEmail: currentEmail,
      );

      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? (isIndo ? 'Selesai.' : 'Done.')),
            backgroundColor: (res['success'] == true) ? const Color(0xFF10B981) : Colors.redAccent,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  // Logika Hapus Saluran Secara Permanen (Storage + Firestore Bersih, User Auth Tetap Aman)
  Future<void> _handleDeleteDormantChannel(String channelId, String email, bool isIndo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.delete_forever_rounded, color: Colors.redAccent, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isIndo ? 'Hapus Permanen Saluran?' : 'Delete Channel Permanently?',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isIndo
                  ? 'PERINGATAN: Tindakan ini TIDAK DAPAT DIBATALKAN. Seluruh folder video, file HLS, subtitle, dan thumbnail di Cloud Storage serta data saluran di Firestore akan dihapus bersih.'
                  : 'WARNING: This action CANNOT BE UNDONE. All video folders, HLS files, subtitles, and thumbnails in Cloud Storage and Firestore data will be permanently deleted.',
              style: const TextStyle(color: Colors.redAccent, fontSize: 13, height: 1.4, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(8)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Channel ID: $channelId', style: const TextStyle(color: Colors.amberAccent, fontSize: 11.5, fontFamily: 'monospace')),
                  const SizedBox(height: 3),
                  Text('Email: $email', style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isIndo
                  ? 'Catatan: Akun login pengguna ($email) dan UID Auth TETAP AMAN dan akan dinormalkan kembali sebagai Free User.'
                  : 'Note: User login account ($email) and Auth UID REMAIN SAFE and status will be reset to Free User.',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: Text(isIndo ? 'Batal' : 'Cancel', style: const TextStyle(color: Colors.white54)),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: Text(
              isIndo ? 'Ya, Hapus Permanen' : 'Yes, Delete Permanently',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isProcessing = true);
      final res = await _service.deleteChannelPermanently(channelId: channelId, email: email);

      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? (isIndo ? 'Selesai.' : 'Done.')),
            backgroundColor: (res['success'] == true) ? const Color(0xFF10B981) : Colors.redAccent,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
//............................................................................//

//No ke-4....................................................................//
//MAIN BUILD, ADMIN CHANNEL CARD & SEARCH FORM                               //
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
          t('Mytube Account Governance', 'Manajemen Akun & Saluran MyTube'),
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Tombol Khusus Admin (Admin Own Channel Card)
            _buildAdminOwnChannelCard(t, isIndo),
            const SizedBox(height: 22),

            // 2. Baris Pencarian Email Pengguna
            Text(
              t('SEARCH USER ACCOUNT BY EMAIL', 'CARI AKUN PENGGUNA BERDASARKAN EMAIL'),
              style: const TextStyle(
                color: Color(0xFF10B981),
                fontSize: 12.5,
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
            const SizedBox(height: 16),

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
              const SizedBox(height: 16),
            ],

            if (_searchedUserData != null) ...[
              _buildSearchResultCard(t, isIndo),
              const SizedBox(height: 24),
            ],

            const Divider(color: Colors.white12, height: 28),

            // 3. Seksi Daftar Admin Aktif
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  t('ACTIVE ADMINS', 'DAFTAR ADMIN PUSAT AKTIF'),
                  style: const TextStyle(
                    color: Color(0xFF6366F1),
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFF6366F1).withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                  child: Text('ROOT ACCESS', style: TextStyle(color: Colors.indigoAccent[100], fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _buildActiveAdminsStream(t, isIndo),

            const Divider(color: Colors.white12, height: 32),

            // 4. Seksi Daftar Kreator Aktif
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  t('ACTIVE CREATORS & CHANNELS', 'DAFTAR KREATOR & SALURAN AKTIF'),
                  style: const TextStyle(
                    color: Color(0xFF10B981),
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                  child: const Text('AUTO-ID ANCHOR', style: TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _buildActiveCreatorsStream(t, isIndo),

            const Divider(color: Colors.white12, height: 32),

            // 5. Seksi Daftar Saluran Non-Aktif / Ditangguhkan (Dormant Channels)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  t('INACTIVE / DORMANT CHANNELS', 'DAFTAR SALURAN NON-AKTIF / TERDATA'),
                  style: const TextStyle(
                    color: Colors.orangeAccent,
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: Colors.orangeAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                  child: const Text('DATA INTACT', style: TextStyle(color: Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              t(
                'Channels whose access was revoked. Data and videos remain safe and can be reactivated anytime.',
                'Saluran yang aksesnya pernah dicabut. Data dan video tetap aman serta dapat direaktivasi kapan saja.',
              ),
              style: const TextStyle(color: Colors.white54, fontSize: 11.5),
            ),
            const SizedBox(height: 10),
            _buildInactiveChannelsStream(t, isIndo),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
//............................................................................//

//No ke-5....................................................................//
//ADMIN OWN CHANNEL CARD (ROYAL BLUE / INDIGO DESIGN)                        //
  Widget _buildAdminOwnChannelCard(String Function(String, String) t, bool isIndo) {
    final hasChannel = _adminChannelId != null && _adminChannelId!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: hasChannel
              ? [const Color(0xFF1E1B4B), const Color(0xFF312E81)] // Deep Indigo
              : [const Color(0xFF1E1E2E), const Color(0xFF28254A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF6366F1).withOpacity(0.6),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t('Admin Official Channel Hub', 'Pusat Saluran Resmi Admin'),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14.5),
                    ),
                    Text(
                      hasChannel
                          ? t('Your official admin channel is active & verified.', 'Saluran resmi admin Anda aktif dan terverifikasi.')
                          : t('Initialize your own official admin channel.', 'Inisialisasi Channel ID resmi admin Anda sekarang.'),
                      style: TextStyle(color: Colors.indigoAccent[100], fontSize: 11.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 12),

          if (_isLoadingAdminChannel)
            const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(color: Color(0xFF6366F1))))
          else if (hasChannel) ...[
            // Tampilan jika Admin sudah memiliki Channel ID
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t('ADMIN CHANNEL ID', 'CHANNEL ID ADMIN'), style: const TextStyle(color: Colors.white54, fontSize: 10.5, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      SelectableText(
                        _adminChannelId!,
                        style: const TextStyle(color: Colors.amberAccent, fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, color: Colors.amberAccent, size: 18),
                  tooltip: t('Copy Channel ID', 'Salin Channel ID'),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _adminChannelId!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(isIndo ? 'Channel ID Admin berhasil disalin!' : 'Admin Channel ID copied!'), duration: const Duration(seconds: 2)),
                    );
                  },
                ),
              ],
            ),
          ] else ...[
            // Tombol Buat Channel ID Admin Baru (Warna Biru-Ungu Elektrik)
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1), // Royal Blue / Indigo
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _isProcessing ? null : () => _handleCreateOwnAdminChannel(isIndo),
                icon: _isProcessing
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.add_moderator_rounded, size: 20),
                label: Text(
                  _isProcessing
                      ? t('Initializing Channel...', 'Membuat Saluran...')
                      : t('Create Own Admin Channel ID', 'Buat Channel ID Admin Sendiri'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchResultCard(String Function(String, String) t, bool isIndo) {
    final data = _searchedUserData!;
    final email = data['email'] as String? ?? '-';
    final name = data['displayName'] as String? ?? 'Pengguna';
    final uid = data['uid'] as String? ?? '-';
    final tier = (data['userTier'] as String? ?? 'free').toLowerCase();
    final channelId = data['channel_id'] as String? ?? '';

    final isCreator = tier == 'creator';
    final isAdmin = tier == 'admin';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E24),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCreator ? const Color(0xFF10B981) : (isAdmin ? const Color(0xFF6366F1) : Colors.white24),
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
                backgroundColor: isCreator ? const Color(0xFF10B981).withOpacity(0.2) : (isAdmin ? const Color(0xFF6366F1).withOpacity(0.2) : Colors.white10),
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
                    Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(email, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                ),
              ),
              _buildRoleBadge(tier),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 10),

          if (channelId.isNotEmpty) ...[
            Text('Channel ID: $channelId', style: const TextStyle(color: Colors.amberAccent, fontSize: 11.5, fontFamily: 'monospace')),
            const SizedBox(height: 4),
          ],
          Text('UID: $uid', style: const TextStyle(color: Colors.white30, fontSize: 11, fontFamily: 'monospace')),
          const SizedBox(height: 14),

          // Tombol Aksi Sesuai Role
          if (isAdmin) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: const Color(0xFF6366F1).withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  const Icon(Icons.verified, color: Colors.amberAccent, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      t('Admin account with supreme system privileges.', 'Akun Admin Pusat dengan hak akses sistem tertinggi.'),
                      style: TextStyle(color: Colors.indigoAccent[100], fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (isCreator) ...[
            // [DIHILANGKAN]: Tombol Revoke ditiadakan dari kartu pencarian.
            // Digantikan banner status hijau informatif karena aksi revoke resmi sudah ada di tabel bawah.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified, color: Color(0xFF10B981), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      t(
                        'Active Creator account. Access management & revocation can be found in the Active Creators list below.',
                        'Akun resmi Creator aktif. Pengelolaan hak akses tersedia di Daftar Kreator & Saluran Aktif di bawah.',
                      ),
                      style: const TextStyle(color: Color(0xFF10B981), fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
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
                label: Text(t('Approve & Upgrade to Creator', 'Setujui & Jadikan Creator MyTube'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                onPressed: _isProcessing ? null : () => _handleUpgradeToCreator(isIndo),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRoleBadge(String tier) {
    Color color = Colors.blueGrey;
    String label = 'FREE USER';

    if (tier == 'creator') {
      color = const Color(0xFF10B981);
      label = 'CREATOR';
    } else if (tier == 'admin') {
      color = const Color(0xFF6366F1);
      label = 'ADMIN';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)),
    );
  }
//............................................................................//

//No ke-6....................................................................//
//SEKSI 1: DAFTAR ADMIN AKTIF (STREAMBUILDER)                                //
  Widget _buildActiveAdminsStream(String Function(String, String) t, bool isIndo) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _service.streamActiveAdmins(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(color: Color(0xFF6366F1))));
        }

        final admins = snapshot.data ?? [];

        if (admins.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFF1E1E24), borderRadius: BorderRadius.circular(10)),
            child: Center(
              child: Text(t('No active admins recorded.', 'Belum ada data admin tercatat.'), style: const TextStyle(color: Colors.white54, fontSize: 12.5)),
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: admins.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final a = admins[index];
            final email = a['email'] as String? ?? '-';
            final name = a['displayName'] as String? ?? 'Admin Pusat';
            final channelId = a['channel_id'] as String? ?? '';
            final createdAt = a['created_at'];

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E24),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shield_rounded, color: Color(0xFF6366F1), size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(color: Colors.amberAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                              child: const Text('ADMIN', style: TextStyle(color: Colors.amberAccent, fontSize: 9.5, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(email, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              channelId.isNotEmpty ? 'Channel: $channelId' : t('No Channel ID', 'Belum Ada Channel ID'),
                              style: TextStyle(color: channelId.isNotEmpty ? Colors.cyanAccent : Colors.white30, fontSize: 11, fontFamily: 'monospace'),
                            ),
                            if (channelId.isNotEmpty) ...[
                              const SizedBox(width: 4),
                              InkWell(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: channelId));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(isIndo ? 'Channel ID disalin!' : 'Channel ID copied!'), duration: const Duration(seconds: 1)),
                                  );
                                },
                                child: const Icon(Icons.copy_rounded, color: Colors.cyanAccent, size: 13),
                              ),
                            ],
                            const Spacer(),
                            Text(_formatDateShort(createdAt, t), style: const TextStyle(color: Colors.white38, fontSize: 10.5)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
//............................................................................//

//No ke-7....................................................................//
//INACTIVE CHANNELS STREAMBUILDER & STREAM HELPERS                           //
  // [BARU]: StreamBuilder Daftar Saluran Non-Aktif (Dormant Channels)
  Widget _buildInactiveChannelsStream(String Function(String, String) t, bool isIndo) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _service.streamInactiveChannels(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(color: Colors.orangeAccent)));
        }

        final dormantChannels = snapshot.data ?? [];

        if (dormantChannels.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: const Color(0xFF1E1E24), borderRadius: BorderRadius.circular(10)),
            child: Center(
              child: Text(
                t('No inactive channels found.', 'Tidak ada saluran non-aktif.'),
                style: const TextStyle(color: Colors.white54, fontSize: 12.5),
              ),
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: dormantChannels.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final c = dormantChannels[index];
            final channelId = c['channel_id'] as String? ?? '-';
            final email = c['email'] as String? ?? '-';
            final name = c['channel_name'] as String? ?? 'Saluran Non-Aktif';
            final createdAt = c['created_at'];

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E24),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orangeAccent.withOpacity(0.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 17,
                        backgroundColor: Colors.orangeAccent.withOpacity(0.18),
                        child: const Icon(Icons.archive_rounded, color: Colors.orangeAccent, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5)),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(color: Colors.orangeAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                                  child: const Text('NON-AKTIF', style: TextStyle(color: Colors.orangeAccent, fontSize: 9.5, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(email, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                      ),
                      // Tombol Tindakan Saluran Non-Aktif
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert_rounded, color: Colors.white70, size: 20),
                        color: const Color(0xFF262630),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        onSelected: (val) {
                          if (val == 'reactivate') {
                            _handleReactivateChannel(channelId, email, isIndo);
                          } else if (val == 'transfer') {
                            _handleTransferEmailDialog(channelId, email, isIndo);
                          } else if (val == 'delete') {
                            _handleDeleteDormantChannel(channelId, email, isIndo);
                          }
                        },
                        itemBuilder: (ctx) => [
                          PopupMenuItem(
                            value: 'reactivate',
                            child: Row(
                              children: [
                                const Icon(Icons.settings_backup_restore_rounded, color: Color(0xFF10B981), size: 18),
                                const SizedBox(width: 10),
                                Text(t('Reactivate Channel', 'Reaktivasi Saluran'), style: const TextStyle(color: Color(0xFF10B981), fontSize: 12.5, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'transfer',
                            child: Row(
                              children: [
                                const Icon(Icons.swap_horiz_rounded, color: Colors.cyanAccent, size: 18),
                                const SizedBox(width: 10),
                                Text(t('Assign New Email', 'Ganti Email Baru'), style: const TextStyle(color: Colors.cyanAccent, fontSize: 12.5, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                          const PopupMenuDivider(height: 1),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                const Icon(Icons.delete_forever_rounded, color: Colors.redAccent, size: 18),
                                const SizedBox(width: 10),
                                Text(t('Delete Permanently', 'Hapus Saluran Permanen'), style: const TextStyle(color: Colors.redAccent, fontSize: 12.5, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Divider(color: Colors.white10, height: 1),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      const Icon(Icons.tag_rounded, color: Colors.amberAccent, size: 14),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          channelId,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                        ),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: channelId));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(isIndo ? 'Channel ID disalin!' : 'Channel ID copied!'), duration: const Duration(seconds: 1)),
                          );
                        },
                        child: const Icon(Icons.copy_rounded, color: Colors.white54, size: 12),
                      ),
                      const Spacer(),
                      Text(_formatDateShort(createdAt, t), style: const TextStyle(color: Colors.white38, fontSize: 10.5)),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Helper StreamBuilder Aktif Kreator
  Widget _buildActiveCreatorsStream(String Function(String, String) t, bool isIndo) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _service.streamActiveCreators(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(color: Color(0xFF10B981))));
        }

        final creators = snapshot.data ?? [];

        if (creators.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: const Color(0xFF1E1E24), borderRadius: BorderRadius.circular(10)),
            child: Center(
              child: Text(t('No active creators yet.', 'Belum ada creator aktif.'), style: const TextStyle(color: Colors.white54, fontSize: 12.5)),
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
            final email = c['email'] as String? ?? '-';
            final name = c['displayName'] as String? ?? 'Creator';
            final uid = c['uid'] as String? ?? '-';
            final channelId = c['channel_id'] as String? ?? '';
            final prevTier = c['previous_tier'] as String? ?? 'free';
            final createdAt = c['created_at'];

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E24),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 17,
                        backgroundColor: const Color(0xFF10B981).withOpacity(0.18),
                        child: const Icon(Icons.verified, color: Color(0xFF10B981), size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5)),
                            const SizedBox(height: 2),
                            Text(email, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert_rounded, color: Colors.white70, size: 20),
                        color: const Color(0xFF262630),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        onSelected: (val) {
                          if (val == 'revoke') {
                            _handleDowngradeToFree(uid, email, isIndo);
                          } else if (val == 'transfer') {
                            if (channelId.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(isIndo ? 'Kreator ini belum memiliki Channel ID.' : 'No Channel ID assigned.'), backgroundColor: Colors.redAccent),
                              );
                              return;
                            }
                            _handleTransferEmailDialog(channelId, email, isIndo);
                          }
                        },
                        itemBuilder: (ctx) => [
                          PopupMenuItem(
                            value: 'revoke',
                            child: Row(
                              children: [
                                const Icon(Icons.pause_circle_outline_rounded, color: Colors.orangeAccent, size: 18),
                                const SizedBox(width: 10),
                                Text(t('Revoke Access', 'Cabut Akses'), style: const TextStyle(color: Colors.orangeAccent, fontSize: 12.5, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'transfer',
                            child: Row(
                              children: [
                                const Icon(Icons.swap_horiz_rounded, color: Colors.cyanAccent, size: 18),
                                const SizedBox(width: 10),
                                Text(t('Change Staff Email', 'Ganti Email Petugas'), style: const TextStyle(color: Colors.cyanAccent, fontSize: 12.5, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Divider(color: Colors.white10, height: 1),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      const Icon(Icons.tag_rounded, color: Colors.amberAccent, size: 14),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          channelId.isNotEmpty ? channelId : 'No ID',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                        ),
                      ),
                      if (channelId.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: channelId));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(isIndo ? 'Channel ID disalin!' : 'Channel ID copied!'), duration: const Duration(seconds: 1)),
                            );
                          },
                          child: const Icon(Icons.copy_rounded, color: Colors.white54, size: 12),
                        ),
                      ],
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(4)),
                        child: Text(
                          '${prevTier.toUpperCase()} ➔ CREATOR',
                          style: const TextStyle(color: Color(0xFF10B981), fontSize: 9.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(_formatDateShort(createdAt, t), style: const TextStyle(color: Colors.white38, fontSize: 10.5)),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _formatDateShort(dynamic dt, String Function(String, String) t) {
    if (dt == null) return '-';
    DateTime date;
    if (dt is Timestamp) {
      date = dt.toDate();
    } else if (dt is DateTime) {
      date = dt;
    } else {
      return '-';
    }
    const monthsEn = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const monthsId = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    final m = t(monthsEn[date.month - 1], monthsId[date.month - 1]);
    return '${date.day} $m ${date.year}';
  }
}
//............................................................................//