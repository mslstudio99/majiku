//============================================================================//
// DIREKTORI: lib/entertainment/mytube/screens/                              //
// FILE: MYTUBE_ADMIN_PORTAL_SCREEN.DART                                     //
// DASHBOARD HUB UTAMA PORTAL ADMIN & CREATOR STUDIO MYTUBE                  //
//============================================================================//

//No ke-1....................................................................//
//IMPORTS & DEPENDENCIES                                                     //
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../providers/config_provider.dart';
import '../models/creator_mytube_model.dart';
import '../services/firestore_mytube_service.dart';
import 'short_upload_content.dart';
import 'long_upload_content.dart';
import 'history_content.dart';
import 'mytube_admin_profile_screen.dart';
//............................................................................//

//No ke-2....................................................................//
//WIDGET DECLARATION & STATE SETUP                                           //
class MytubeAdminPortalScreen extends ConsumerStatefulWidget {
  const MytubeAdminPortalScreen({super.key});

  @override
  ConsumerState<MytubeAdminPortalScreen> createState() => _MytubeAdminPortalScreenState();
}

class _MytubeAdminPortalScreenState extends ConsumerState<MytubeAdminPortalScreen> {
  final FirestoreMytubeService _service = FirestoreMytubeService();
  User? _currentUser;
  bool _isLoading = true;
  bool _isAdminVerified = false;
  CreatorMytubeModel? _creatorProfile;
//............................................................................//

//No ke-3....................................................................//
//LIFECYCLE & AUTHORIZATION GATEWAY                                          //
  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    _verifyAccessAndLoadProfile();
  }

  Future<void> _verifyAccessAndLoadProfile() async {
    setState(() => _isLoading = true);
    final uid = _currentUser?.uid ?? '';
    final email = _currentUser?.email ?? '';

    if (uid.isNotEmpty) {
      // [PENYESUAIAN RBAC]: Mengizinkan status 'creator' dan 'admin'
      final hasAccess = await _service.checkIsCreatorOrAdmin(uid);
      if (hasAccess) {
        final profile = await _service.getCreatorProfile(email, userId: uid);
        
        if (mounted) {
          setState(() {
            _isAdminVerified = true;
            _creatorProfile = profile ??
                CreatorMytubeModel.empty(
                  uid,
                  defaultEmail: email,
                  defaultAvatar: _currentUser?.photoURL ?? '',
                );
            _isLoading = false;
          });
          return;
        }
      }
    }

    if (mounted) {
      setState(() {
        _isAdminVerified = false;
        _isLoading = false;
      });
    }
  }
//............................................................................//

//No ke-4....................................................................//
//MAIN BUILD & ACCESS GATEWAY                                                //
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
          t('Mytube Creator Studio', 'Studio Creator Mytube'),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            tooltip: t('Refresh', 'Segarkan'),
            onPressed: _verifyAccessAndLoadProfile,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.amberAccent))
          : !_isAdminVerified
              ? _buildAccessDenied(t)
              : _buildStudioDashboard(t, isIndo),
    );
  }

  Widget _buildAccessDenied(String Function(String, String) t) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, color: Colors.redAccent, size: 64),
            const SizedBox(height: 16),
            Text(
              t('Admin Access Required', 'Akses Admin Diperlukan'),
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              t(
                'Only users with verified Admin privileges can access the Mytube Creator Studio.',
                'Hanya pengguna dengan hak akses Admin yang terverifikasi yang dapat mengakses Studio Creator Mytube.',
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amberAccent, foregroundColor: Colors.black),
              onPressed: () => Navigator.of(context).pop(),
              child: Text(t('Back to Account', 'Kembali ke Akun')),
            ),
          ],
        ),
      ),
    );
  }
//............................................................................//

//No ke-5....................................................................//
//STUDIO DASHBOARD & CREATOR HEADER CARD                                     //
  Widget _buildStudioDashboard(String Function(String, String) t, bool isIndo) {
    final creator = _creatorProfile;

    return RefreshIndicator(
      color: Colors.amberAccent,
      backgroundColor: const Color(0xFF1E1E24),
      onRefresh: _verifyAccessAndLoadProfile,
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          // Kartu Header Identitas Creator Channel
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF262013), Color(0xFF1E1E24)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.amberAccent.withOpacity(0.4), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.amberAccent.withOpacity(0.2),
                  backgroundImage: (creator?.avatarUrl != null && creator!.avatarUrl.isNotEmpty)
                      ? NetworkImage(creator.avatarUrl)
                      : null,
                  child: (creator?.avatarUrl == null || creator!.avatarUrl.isEmpty)
                      ? const Icon(Icons.person, color: Colors.amberAccent, size: 32)
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              creator?.channelName.isNotEmpty == true
                                  ? creator!.channelName
                                  : (_currentUser?.displayName ?? 'Majiku Official'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.verified, color: Colors.blueAccent, size: 16),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        creator?.handle.isNotEmpty == true ? creator!.handle : '@creator',
                        style: const TextStyle(color: Colors.amberAccent, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        creator?.country.isNotEmpty == true
                            ? '${creator!.country} • ${t('Verified Admin', 'Admin Terverifikasi')}'
                            : t('Verified Admin Creator', 'Creator Admin Terverifikasi'),
                        style: const TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Judul Seksi Menu
          Text(
            t('CREATOR STUDIO ACTIONS', 'MENU AKSI CREATOR STUDIO'),
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 12),

          // 1. Opsi Profil Admin (Creator) - TERHUBUNG KE MYTUBE ADMIN PROFILE
          _buildMenuCard(
            icon: Icons.account_circle_outlined,
            iconColor: Colors.cyanAccent,
            title: t('Admin / Creator Profile', 'Profil Admin / Creator'),
            subtitle: t(
              'Manage channel name, auto-handle, address, bank payout & links',
              'Kelola nama channel, handle otomatis, alamat, rekening bank & tautan',
            ),
            badgeText: t('Branding', 'Identitas'),
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const MytubeAdminProfileScreen(),
                ),
              );
              _verifyAccessAndLoadProfile();
            },
          ),
          const SizedBox(height: 14),

          // 2. Opsi Create Short Content - TERHUBUNG KE SHORT UPLOAD CONTENT
          _buildMenuCard(
            icon: Icons.bolt_rounded,
            iconColor: Colors.amberAccent,
            title: t('Create Short Content', 'Buat Konten Short'),
            subtitle: t(
              'Upload 9:16 portrait video up to 3 minutes for swipeable feed',
              'Unggah video portrait 9:16 maksimal 3 menit untuk feed vertikal',
            ),
            badgeText: '9:16 Short',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ShortUploadContentScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 14),

          // 3. Opsi Create Long Content - TERHUBUNG KE LONG UPLOAD CONTENT
          _buildMenuCard(
            icon: Icons.tv_rounded,
            iconColor: Colors.orangeAccent,
            title: t('Create Long Content', 'Buat Konten Panjang'),
            subtitle: t(
              'Upload 16:9 landscape cinematic video for long-form streaming',
              'Unggah video lanskap 16:9 sinematik untuk tayangan berdurasi panjang',
            ),
            badgeText: '16:9 Landscape',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const LongUploadContentScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 14),

          // 4. Opsi History Content (Berisi 2 Tombol Sub-Aksi)
          _buildHistoryMenuCard(t, isIndo),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
//............................................................................//

//No ke-6....................................................................//
//CUSTOM UI CARDS & SUB-BUTTONS                                              //
  Widget _buildMenuCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String badgeText,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E24),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              badgeText,
                              style: TextStyle(color: iconColor, fontSize: 10, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(color: Colors.white54, fontSize: 12, height: 1.3),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 14),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryMenuCard(String Function(String, String) t, bool isIndo) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E24),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.purpleAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.video_collection_outlined, color: Colors.purpleAccent, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t('Content History', 'Riwayat Konten'),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      t(
                        'Track published videos, views, transcoding status, and manage content',
                        'Pantau video terbit, tayangan, status transcoding, dan kelola konten',
                      ),
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 14),

          // 2 Tombol Sub-Aksi (const telah dihapus untuk mencegah error kompilasi)
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.amberAccent,
                    side: const BorderSide(color: Colors.amberAccent, width: 1),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.bolt, size: 18),
                  label: Text(
                    t('Shorts History', 'Riwayat Shorts'),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => HistoryContentScreen(initialTabIndex: 0),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orangeAccent,
                    side: const BorderSide(color: Colors.orangeAccent, width: 1),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.tv, size: 18),
                  label: Text(
                    t('Longs History', 'Riwayat Longs'),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => HistoryContentScreen(initialTabIndex: 1),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showComingSoonNotice(BuildContext context, String featureName, bool isIndo) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isIndo
              ? '$featureName sedang disiapkan di tahap berikutnya.'
              : '$featureName is being prepared in the next phase.',
        ),
        backgroundColor: Colors.blueGrey,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
//............................................................................//