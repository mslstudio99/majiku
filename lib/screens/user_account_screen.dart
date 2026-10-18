//============================================================================//
// DIREKTORI: LIB/SCREENS/                                                    //
// FILE: USER_ACCOUNT_SCREEN.DART                                             //
// HALAMAN AKUN PENGGUNA & KONTROL ADMIN (STUDIO, APPROVAL, & UPGRADE PORTAL) //
//============================================================================//

//No ke-1....................................................................//
//IMPORTS & DEPENDENCIES                                                     //
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/user_provider.dart';
import '../view_model/auth_view_model.dart';
import '../providers/config_provider.dart';

// --- [MYTUBE] Impor Layar Portal Hub, Approval, & Account Upgrade Admin ---
import '../entertainment/mytube/screens/mytube_admin_portal_screen.dart';
import '../entertainment/mytube/screens/mytube_approval_screen.dart';
import '../entertainment/mytube/screens/mytube_account_upgrade.dart';
//............................................................................//

//No ke-2....................................................................//
//WIDGET CLASS & HELPERS                                                     //
class UserAccountScreen extends ConsumerWidget {
  const UserAccountScreen({super.key});

  String _t(bool isIndo, String en, String id) {
    return isIndo ? id : en;
  }

  Widget _buildInfoRow(String title, String value, {bool isHighlightAdmin = false}) {
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
          if (isHighlightAdmin)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.amberAccent, width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.security, color: Colors.amberAccent, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.amberAccent,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            )
          else
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

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $urlString');
    }
  }

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
            color: color.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          splashColor: Colors.white.withOpacity(0.3),
          highlightColor: Colors.white.withOpacity(0.1),
          onTap: () => _launchURL(url),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
               children: [
                 Container(
                   padding: const EdgeInsets.all(12),
                   decoration: BoxDecoration(
                     color: Colors.white.withOpacity(0.2),
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
                           color: Colors.white,
                         ),
                       ),
                       const SizedBox(height: 4),
                       Text(
                         subtitle,
                         style: const TextStyle(
                           color: Colors.white70,
                           fontSize: 13,
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

  // Tombol 1: Mytube Creator Studio (Bisa Diakses Creator & Admin)
  Widget _buildAdminPortalButton({
    required BuildContext context,
    required bool isIndo,
    required bool hasAccess,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasAccess ? Colors.amberAccent.withOpacity(0.6) : Colors.white12,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: hasAccess ? Colors.amber.withOpacity(0.2) : Colors.black26,
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Material(
        color: hasAccess ? const Color(0xFF231F15) : const Color(0xFF1E1E24),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          splashColor: Colors.amberAccent.withOpacity(0.2),
          onTap: () {
            if (hasAccess) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const MytubeAdminPortalScreen(),
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    _t(
                      isIndo,
                      'Access Denied: Creator or Admin membership required.',
                      'Akses Ditolak: Membutuhkan status keanggotaan Creator atau Admin.',
                    ),
                  ),
                  backgroundColor: Colors.redAccent,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: hasAccess ? Colors.amberAccent.withOpacity(0.2) : Colors.white10,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    hasAccess ? Icons.video_collection_rounded : Icons.lock_outline,
                    color: hasAccess ? Colors.amberAccent : Colors.white38,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              _t(isIndo, 'Mytube Creator Studio', 'Studio Creator Mytube'),
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: hasAccess ? Colors.amberAccent : Colors.white60,
                              ),
                            ),
                          ),
                          if (hasAccess) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.verified, color: Colors.amberAccent, size: 14),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hasAccess
                            ? _t(isIndo, 'Upload & manage your channel videos', 'Unggah & kelola video saluran Anda')
                            : _t(isIndo, 'Creator or Admin membership required', 'Perlu status Creator atau Admin'),
                        style: TextStyle(
                          color: hasAccess ? Colors.white70 : Colors.white30,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: hasAccess ? Colors.amberAccent : Colors.white24,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Tombol 2: Pusat Persetujuan & Moderasi Konten (DIPERBARUI: BEBAS OVERFLOW)
  Widget _buildApprovalPortalButton({
    required BuildContext context,
    required bool isIndo,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF2563EB).withOpacity(0.6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Material(
        color: const Color(0xFF141C2E), // Deep Navy Studio
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          splashColor: const Color(0xFF2563EB).withOpacity(0.2),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const MytubeApprovalScreen(),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.gavel_rounded,
                    color: Color(0xFF60A5FA),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              _t(isIndo, 'Content Approval', 'Persetujuan Konten'),
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Color(0xFF60A5FA),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB).withOpacity(0.25),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Admin Pusat',
                              style: TextStyle(
                                color: Color(0xFF93C5FD),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _t(
                          isIndo,
                          'Review creator edit & delete video requests',
                          'Tinjau permohonan edit & hapus video kreator',
                        ),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Color(0xFF60A5FA),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Tombol 3: Pendaftaran & Manajemen Akun Creator (DIPERBARUI: BEBAS OVERFLOW)
  Widget _buildUpgradePortalButton({
    required BuildContext context,
    required bool isIndo,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF10B981).withOpacity(0.6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Material(
        color: const Color(0xFF12241D), // Deep Emerald Dark Green
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          splashColor: const Color(0xFF10B981).withOpacity(0.2),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const MytubeAccountUpgradeScreen(),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.manage_accounts_rounded,
                    color: Color(0xFF34D399),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              _t(isIndo, 'Account Management', 'Manajemen Akun'),
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Color(0xFF34D399),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withOpacity(0.25),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Admin Pusat',
                              style: TextStyle(
                                color: Color(0xFFA7F3D0),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _t(
                          isIndo,
                          'Manage creator memberships & upgrade user accounts',
                          'Kelola keanggotaan creator & upgrade status user',
                        ),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Color(0xFF34D399),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
//............................................................................//

//No ke-3....................................................................//
//MAIN BUILD & APPBAR                                                        //
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsyncValue = ref.watch(firestoreUserProvider);
    final currentLocale = ref.watch(appLanguageProvider);
    final isIndo = currentLocale.languageCode == 'id';

    return Scaffold(
      appBar: AppBar(
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
//............................................................................//

//No ke-4....................................................................//
//STATE HANDLING (LOADING & ERROR)                                           //
      body: userAsyncValue.when(
        loading: () => const Center(child: CircularProgressIndicator()),
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
//............................................................................//

//No ke-5....................................................................//
//STATE DATA (SUCCESS) & MAIN UI                                             //
        data: (user) {
          if (user.uid.isEmpty) {
            return Center(
              child: Text(_t(isIndo, 'User not logged in.', 'Pengguna belum login.')),
            );
          }

          final userTierLower = user.userTier.toLowerCase();
          final isAdmin = userTierLower == 'admin';
          final isCreator = userTierLower == 'creator' || isAdmin;

          return ListView(
            padding: const EdgeInsets.all(24.0),
            children: [
              Text(
                _t(isIndo, 'Account Details', 'Detail Akun'),
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              
              _buildInfoRow('Email', user.email),
              const Divider(),
              
              _buildInfoRow(
                _t(isIndo, 'Membership Status', 'Status Keanggotaan'),
                user.userTier.toUpperCase(),
                isHighlightAdmin: isAdmin,
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
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              
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

              // --- Bagian Platform Eksternal ---
              Text(
                _t(isIndo, 'Other Platforms', 'Platform Lainnya'),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              
              _buildPlatformButton(
                icon: Icons.language,
                title: _t(isIndo, 'Web Version', 'Versi Web'),
                subtitle: 'app.majiku.net',
                url: 'https://app.majiku.net/',
                color: Colors.deepPurple,
              ),

              _buildPlatformButton(
                icon: Icons.shop,
                title: _t(isIndo, 'App Version', 'Versi Aplikasi'),
                subtitle: 'Google Play Store',
                url: 'https://play.google.com/store/apps/details?id=com.mslstudio.majiku',
                color: Colors.green,
              ),

              const SizedBox(height: 24),

              // --- Bagian Akses Portal Admin (Paling Bawah) ---
              Text(
                _t(isIndo, 'Admin Area', 'Area Admin'),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              
              // 1. Tombol Studio Creator (Emas: Bisa diakses status 'creator' & 'admin')
              _buildAdminPortalButton(
                context: context,
                isIndo: isIndo,
                hasAccess: isCreator,
              ),

              // 2. Tombol Pusat Persetujuan & Moderasi (ROYAL BLUE: HANYA MUNCUL JIKA STATUS 'admin')
              if (isAdmin)
                _buildApprovalPortalButton(
                  context: context,
                  isIndo: isIndo,
                ),

              // 3. Tombol Pendaftaran & Upgrade Akun (EMERALD GREEN: HANYA MUNCUL JIKA STATUS 'admin')
              if (isAdmin)
                _buildUpgradePortalButton(
                  context: context,
                  isIndo: isIndo,
                ),
              
              const SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }
}
//............................................................................//