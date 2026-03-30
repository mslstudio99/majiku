// [RILIS FINAL - DASHBOARD: NOTIFIKASI AUTO-DELETE NON-INTRUSIF]
// KATEGORI_UI_UPDATE_07
// Lokasi: lib/screens/project_dashboard_screen.dart
// TUJUAN:
// - [UX] Mengubah peringatan Auto-Delete dari Auto-Popup menjadi Tombol Notifikasi Manual.
// - [UI] Menambahkan ikon peringatan di sebelah kiri judul "Majiku".
// - [MAINTENANCE] Mempertahankan dukungan Bahasa dan Tema Dark Modern.

import 'dart:ui'; // Diperlukan untuk ImageFilter (Blur Effect)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// --- [CONFIG] Provider Bahasa ---
import '../providers/config_provider.dart';

// --- [LAMA] Impor untuk Alur IMAGEN (Motion) ---
import '../models/video_project.dart';
import '../view_model/dashboard_view_model.dart';
import 'input_script_screen.dart';
import 'timeline_review_screen.dart';
import 'project_loading_screen.dart';

// --- [LAMA] Impor Alur VEO (Footage) ---
import '../screens_veo/input_script_veo_screen.dart';
import '../models_veo/video_project_veo.dart';
import '../view_model_veo/dashboard_veo_view_model.dart';
import '../screens_veo/project_loading_veo_screen.dart';
import '../screens_veo/timeline_review_veo_screen.dart';

// --- [BARU] Impor Layar Generator Short ---
import '../screens_naraku/generator_konten_short_screen.dart';

// --- [LAMA] Integrasi Token & Akun ---
import '../providers/user_provider.dart';
import 'user_account_screen.dart'; 
import 'upgrade_screen.dart';
import 'top_up_screen.dart';

// --- [BARU] Impor Tema Dark Modern ---
import '../theme/app_theme.dart';

class ProjectDashboardScreen extends ConsumerStatefulWidget {
  const ProjectDashboardScreen({super.key});

  @override
  ConsumerState<ProjectDashboardScreen> createState() => _ProjectDashboardScreenState();
}

class _ProjectDashboardScreenState extends ConsumerState<ProjectDashboardScreen> {
  
  @override
  void initState() {
    super.initState();
    // [PERUBAHAN UX] Dialog otomatis dihapus agar tidak mengganggu.
    // Peringatan sekarang diakses via tombol notifikasi di AppBar.
  }

  // --- [FITUR BARU] MODERN ALERT DIALOG (MULTI-LANGUAGE) ---
  void _showModernAutoDeleteDialog() {
    // Ambil status bahasa saat dialog muncul (Snapshot)
    final currentLocale = ref.read(appLanguageProvider);
    final isIndo = currentLocale.languageCode == 'id';

    // Helper teks lokal
    String t(String en, String id) => isIndo ? id : en;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withOpacity(0.8), // Latar belakang gelap pekat
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (ctx, anim1, anim2) {
        return Center(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5), // Efek Blur Mewah
            child: Container(
              width: MediaQuery.of(context).size.width * 0.85,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E), // Dark Surface
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.amber.withOpacity(0.3), // Glowing Border Tipis
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.amber.withOpacity(0.1),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. Ikon Peringatan Besar
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.timer_off_outlined, // Ikon Waktu Habis
                      size: 48,
                      color: Colors.amberAccent[400],
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // 2. Judul
                  Text(
                    t("Auto-Delete Warning", "Peringatan Hapus Otomatis"),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.none,
                      fontFamily: 'Poppins',
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  
                  // 3. Pesan Body
                  Text(
                    t(
                      "System will automatically delete project data every week to maintain server performance.", 
                      "Sistem akan otomatis menghapus data proyek setiap minggu untuk menjaga performa server."
                    ),
                    style: TextStyle(
                      color: Colors.grey[300],
                      fontSize: 14,
                      height: 1.5,
                      decoration: TextDecoration.none,
                      fontWeight: FontWeight.normal,
                      fontFamily: 'Poppins',
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t(
                      "Immediately DOWNLOAD your generated videos to your device.",
                      "Segera DOWNLOAD video hasil generasi Anda ke perangkat."
                    ),
                    style: TextStyle(
                      color: Colors.amber[200], // Highlight warna emas
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.none,
                      fontFamily: 'Poppins',
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  
                  // 4. Tombol Mengerti
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple.shade800,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                      ),
                      child: Text(
                        t("I Understand", "Saya Mengerti"),
                        style: const TextStyle(
                          fontSize: 16, 
                          fontWeight: FontWeight.bold
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      // Efek animasi masuk (Scale & Fade)
      transitionBuilder: (ctx, anim1, anim2, child) {
        return Transform.scale(
          scale: Curves.easeOutBack.transform(anim1.value),
          child: FadeTransition(
            opacity: anim1,
            child: child,
          ),
        );
      },
    );
  }

  // --- FUNGSI HELPER UNTUK IMAGEN (Motion) ---
  Widget _buildStatus(BuildContext context, VideoProject project, bool isIndo) {
    final String status = project.status ?? 'UNKNOWN';

    // Helper lokal untuk status
    String t(String en, String id) => isIndo ? id : en;

    if (status == 'RENDER_COMPLETED' &&
        project.finalVideoUrl != null &&
        project.finalVideoUrl!.isNotEmpty) {
      return Text(
        t('Render Success', 'Render Berhasil'),
        style: TextStyle(
          color: Colors.green.shade700,
          fontWeight: FontWeight.bold,
        ),
      );
    }

    return Text('Status: $status');
  }

  // --- FUNGSI HELPER UNTUK VEO (Footage) ---
  Widget _buildStatusVeo(BuildContext context, VideoProjectVeo project, bool isIndo) {
    final String status = project.status ?? 'UNKNOWN';

    // Helper lokal untuk status
    String t(String en, String id) => isIndo ? id : en;

    if (status == 'ASSETS_COMPLETE') {
      return Text(
        t('Assets Ready', 'Aset Siap'),
        style: TextStyle(
          color: Colors.green.shade700,
          fontWeight: FontWeight.bold,
        ),
      );
    }

    if (status == 'RENDER_READY') {
      return Text(
        t('Ready to Render', 'Siap Render'),
        style: const TextStyle(
          color: Colors.blueAccent,
          fontWeight: FontWeight.bold,
        ),
      );
    }

    if (status == 'RENDER_COMPLETED' &&
        project.finalVideoUrl != null &&
        project.finalVideoUrl!.isNotEmpty) {
      return Text(
        t('Render Success', 'Render Berhasil'),
        style: TextStyle(
          color: Colors.green.shade700,
          fontWeight: FontWeight.bold,
        ),
      );
    }

    if (status.startsWith('ERROR_')) {
      return Text(
        '${t('Error', 'Eror')}: $status',
        style: const TextStyle(
          color: Colors.redAccent,
          fontWeight: FontWeight.bold,
        ),
        overflow: TextOverflow.ellipsis,
      );
    }

    return Text('Status: $status');
  }

  // --- Helper untuk Judul Bagian ---
  Widget _buildSectionHeader(BuildContext context, String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20.0, 20.0, 16.0, 8.0),
        child: Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.white, // <-- Paksa warna putih
              ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Provider 1 (Imagen / Motion)
    final projectsAsyncValue = ref.watch(projectsStreamProvider);

    // Provider 2 (Veo / Footage)
    final projectsVeoAsyncValue = ref.watch(projectsVeoStreamProvider);

    // Provider 3 (User / Token)
    final userAsyncValue = ref.watch(firestoreUserProvider);

    // [BARU] Provider Bahasa
    final currentLocale = ref.watch(appLanguageProvider);
    final isIndo = currentLocale.languageCode == 'id';
    
    // Helper lokal untuk build utama
    String t(String en, String id) => isIndo ? id : en;

    // [BARU] Menerapkan tema Dark Modern HANYA ke halaman ini
    return Theme(
      data: AppTheme.darkTheme,
      child: Scaffold(
        appBar: AppBar(
          // [MODIFIKASI] Menambahkan Tombol Notifikasi di sebelah kiri Judul
          title: Row(
            mainAxisSize: MainAxisSize.min, // Agar tidak mengambil lebar penuh
            children: [
              // Tombol Notifikasi Kecil (Pop-up trigger)
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(
                  Icons.info_outline, // Ikon Info/Peringatan
                  color: Colors.amber[700], // Warna Amber agar mencolok sedikit
                  size: 20,
                ),
                tooltip: t('Auto-Delete Info', 'Info Hapus Otomatis'),
                onPressed: _showModernAutoDeleteDialog, // Panggil dialog manual
              ),
            ],
          ),
          actions: [
            // 1. Tampilan Saldo Token
            userAsyncValue.when(
              data: (user) {
                if (user.uid.isEmpty) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.monetization_on, 
                            color: Colors.amberAccent[400], 
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${user.tokenBalance} TM',
                            style: TextStyle(
                              color: Colors.lightGreenAccent[400],
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              shadows: const [
                                Shadow(
                                  blurRadius: 2,
                                  color: Colors.black45,
                                  offset: Offset(1, 1),
                                )
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
              loading: () => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.0),
                ),
              ),
              error: (e, s) => const Padding(
                padding: EdgeInsets.only(right: 8.0),
                child: Icon(Icons.error_outline, color: Colors.redAccent),
              ),
            ),

            // 2. Tombol Upgrade & +Token
            userAsyncValue.when(
              data: (user) {
                if (user.uid.isEmpty) return const SizedBox.shrink();
                final bool isFreeUser = (user.userTier == 'free');
                return Row(
                  children: [
                    // Tombol Upgrade
                    SizedBox(
                      height: 36,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber[900],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          elevation: 2,
                        ),
                        child: Text(
                          t('Upgrade', 'Upgrade'), // Terjemahan tombol
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (context) => const UpgradeScreen()),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    
                    // Tombol +Token
                    SizedBox(
                      height: 36,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.cyan[800],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          elevation: 2, 
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: Text(
                          '+Token', // Universal, tidak perlu translate
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        onPressed: isFreeUser
                            ? null 
                            : () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (context) => const TopUpScreen()),
                                );
                              },
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (e, s) => const SizedBox.shrink(),
            ),

            // 3. Tombol Akun
            IconButton(
              icon: const Icon(Icons.account_circle_outlined),
              tooltip: t('My Account', 'Akun Saya'),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const UserAccountScreen(),
                  ),
                );
              },
            ),
          ],
        ),

        // --- Body: CustomScrollView ---
        body: CustomScrollView(
          slivers: [
            _buildSectionHeader(context, t('My Projects (Motion)', 'Proyek Saya (Motion)')),
            _buildImagenProjectList(context, ref, projectsAsyncValue, isIndo),

            _buildSectionHeader(context, t('My Projects (Footage)', 'Proyek Saya (Footage)')),
            _buildVeoProjectList(context, ref, projectsVeoAsyncValue, isIndo),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),

        // Footer Buttons (Warna Gelap & Teks Kontras)
        persistentFooterButtons: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // --- Tombol +Narrative ---
                Expanded(
                  child: ElevatedButton(
                    child: Text(
                      t('+Narrative', '+Narasi'), // Terjemahan
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: Colors.teal.shade800,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => GeneratorKontenShortScreen(), 
                        ),
                      );
                    },
                  ),
                ),
                
                const SizedBox(width: 8),
                
                // --- Tombol +VMotion ---
                Expanded(
                  child: ElevatedButton(
                    child: const Text(
                      '+VMotion', // Nama Fitur (Brand), tidak perlu translate
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: Colors.blue.shade900,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => InputScriptScreen(),
                        ),
                      );
                    },
                  ),
                ),
                
                const SizedBox(width: 8),
                
                // --- Tombol +VFootage ---
                Expanded(
                  child: ElevatedButton(
                    child: const Text(
                      '+VFootage', // Nama Fitur (Brand), tidak perlu translate
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: Colors.deepPurple.shade900,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => InputScriptVeoScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Helper Daftar Proyek IMAGEN (Motion) ---
  Widget _buildImagenProjectList(BuildContext context, WidgetRef ref,
      AsyncValue<List<VideoProject>> asyncValue, bool isIndo) {
    
    String t(String en, String id) => isIndo ? id : en;

    return asyncValue.when(
      loading: () => const SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: CircularProgressIndicator(),
          ),
        ),
      ),
      error: (error, stack) => SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('Error loading Motion projects: $error'),
          ),
        ),
      ),
      data: (projects) {
        if (projects.isEmpty) {
          return SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  t('No (Motion) projects yet. Create one below!', 'Belum ada proyek (Motion). Buat baru di bawah!'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            ),
          );
        }
        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final VideoProject project = projects[index];
              return Card(
                elevation: 2,
                color: Colors.grey[900],
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: InkWell(
                  hoverColor: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    final String status = project.status ?? '';
                    if (status == 'ASSETS_COMPLETE' ||
                        status == 'RENDER_START' ||
                        status == 'RENDERING' ||
                        status == 'RENDER_COMPLETED' ||
                        status.startsWith('ERROR_')) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) =>
                              TimelineReviewScreen(projectId: project.id),
                        ),
                      );
                    } else {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) =>
                              ProjectLoadingScreen(projectId: project.id),
                        ),
                      );
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: ListTile(
                      leading: const Icon(Icons.image_search, color: Colors.blueAccent),
                      title: Text(
                        project.title,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: _buildStatus(context, project, isIndo),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.redAccent),
                        tooltip: t('Delete Project', 'Hapus Proyek'),
                        onPressed: () {
                          ref
                              .read(dashboardViewModelProvider)
                              .deleteProject(project.id);
                        },
                      ),
                    ),
                  ),
                ),
              );
            },
            childCount: projects.length,
          ),
        );
      },
    );
  }

  // --- Helper Daftar Proyek VEO (Footage) ---
  Widget _buildVeoProjectList(BuildContext context, WidgetRef ref,
      AsyncValue<List<VideoProjectVeo>> asyncValue, bool isIndo) {
    
    String t(String en, String id) => isIndo ? id : en;

    return asyncValue.when(
      loading: () => const SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: CircularProgressIndicator(),
          ),
        ),
      ),
      error: (error, stack) => SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('Error loading Footage projects: $error'),
          ),
        ),
      ),
      data: (projects) {
        if (projects.isEmpty) {
          return SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  t('No (Footage) projects yet. Create one below!', 'Belum ada proyek (Footage). Buat baru di bawah!'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            ),
          );
        }
        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final VideoProjectVeo project = projects[index];
              return Card(
                elevation: 2,
                color: Colors.grey[900],
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: InkWell(
                  hoverColor: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    final String status = project.status ?? '';

                    if (status == 'ASSETS_COMPLETE' ||
                        status == 'RENDER_READY' ||
                        status == 'RENDER_START' ||
                        status == 'RENDERING' ||
                        status == 'RENDER_COMPLETED' ||
                        status.startsWith('ERROR_')) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) =>
                              TimelineReviewVeoScreen(projectId: project.id),
                        ),
                      );
                    } else {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) =>
                              ProjectLoadingVeoScreen(projectId: project.id),
                        ),
                      );
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: ListTile(
                      leading: const Icon(Icons.movie_filter, color: Colors.deepPurpleAccent),
                      title: Text(
                        project.title,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: _buildStatusVeo(context, project, isIndo),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.redAccent),
                        tooltip: t('Delete Project', 'Hapus Proyek'),
                        onPressed: () {
                          ref
                              .read(dashboardVeoViewModelProvider)
                              .deleteProject(project.id);
                        },
                      ),
                    ),
                  ),
                ),
              );
            },
            childCount: projects.length,
          ),
        );
      },
    );
  }
}