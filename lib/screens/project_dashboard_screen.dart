// [RILIS BERSIH - DASHBOARD DENGAN MODERN AUTO-DELETE ALERT]
// KATEGORI_UI_UPDATE_05
// Lokasi: lib/screens/project_dashboard_screen.dart
// TUJUAN:
// - [FITUR BARU] Menampilkan "Modern Alert Dialog" saat dashboard dibuka pertama kali.
// - [UX] Mengingatkan user tentang penghapusan data otomatis mingguan.
// - [ANTI-REGRESI] Semua fitur lama (Imagen, Veo, Token, Navigasi) tetap berjalan normal.

import 'dart:ui'; // Diperlukan untuk ImageFilter (Blur Effect)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// --- [LAMA] Impor untuk Alur IMAGEN (Motion) ---
import '../models/video_project.dart';
import '../view_model/dashboard_view_model.dart';
import 'input_script_screen.dart';
import 'timeline_review_screen.dart';
import 'project_loading_screen.dart';

// --- [LAMA] KATEGORI_INTEGRASI_VEO NO_URUT_01: Impor Alur VEO (Footage) ---
import '../screens_veo/input_script_veo_screen.dart';
import '../models_veo/video_project_veo.dart';
import '../view_model_veo/dashboard_veo_view_model.dart';
import '../screens_veo/project_loading_veo_screen.dart';
import '../screens_veo/timeline_review_veo_screen.dart';

// --- [PERBAIKAN] KATEGORI_INTEGRASI_KONTEN_SHORT NO_URUT_01: Impor Layar Baru ---
import '../screens_naraku/generator_konten_short_screen.dart';

// --- [LAMA] KATEGORI_INTEGRASI_TOKEN: Impor Provider & Screen Baru ---
import '../providers/user_provider.dart';
import 'user_account_screen.dart'; // Screen tujuan navigasi
import 'upgrade_screen.dart';
import 'top_up_screen.dart';

// --- [BARU] Impor Tema Dark Modern ---
import '../theme/app_theme.dart';

// [PERUBAHAN] Diubah menjadi Stateful untuk menangani Lifecycle (InitState)
class ProjectDashboardScreen extends ConsumerStatefulWidget {
  const ProjectDashboardScreen({super.key});

  @override
  ConsumerState<ProjectDashboardScreen> createState() => _ProjectDashboardScreenState();
}

class _ProjectDashboardScreenState extends ConsumerState<ProjectDashboardScreen> {
  // [LOGIKA SESI] Static variable agar notifikasi hanya muncul 1x per sesi aplikasi berjalan
  static bool _hasShownAutoDeleteWarning = false;

  @override
  void initState() {
    super.initState();
    // Panggil notifikasi setelah frame pertama selesai dirender
    if (!_hasShownAutoDeleteWarning) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showModernAutoDeleteDialog();
        _hasShownAutoDeleteWarning = true; // Tandai sudah muncul
      });
    }
  }

  // --- [FITUR BARU] MODERN ALERT DIALOG ---
  void _showModernAutoDeleteDialog() {
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
                  const Text(
                    "Auto-Delete Warning",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.none,
                      fontFamily: 'Poppins', // Asumsi font aplikasi
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  
                  // 3. Pesan Body
                  Text(
                    "Sistem akan otomatis menghapus data proyek setiap minggu untuk menjaga performa server.",
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
                    "Segera DOWNLOAD video hasil generasi Anda ke perangkat.",
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
                      child: const Text(
                        "Saya Mengerti",
                        style: TextStyle(
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

  // --- [LAMA] FUNGSI HELPER UNTUK IMAGEN (Motion) ---
  Widget _buildStatus(BuildContext context, VideoProject project) {
    final String status = project.status ?? 'UNKNOWN';

    if (status == 'RENDER_COMPLETED' &&
        project.finalVideoUrl != null &&
        project.finalVideoUrl!.isNotEmpty) {
      return Text(
        'Render Success',
        style: TextStyle(
          color: Colors.green.shade700,
          fontWeight: FontWeight.bold,
        ),
      );
    }

    return Text('Status: $status');
  }
  // --- AKHIR HELPER IMAGEN ---

  // --- [LAMA] FUNGSI HELPER UNTUK VEO (Footage) ---
  Widget _buildStatusVeo(BuildContext context, VideoProjectVeo project) {
    final String status = project.status ?? 'UNKNOWN';

    if (status == 'ASSETS_COMPLETE') {
      return Text(
        'Assets Ready',
        style: TextStyle(
          color: Colors.green.shade700,
          fontWeight: FontWeight.bold,
        ),
      );
    }

    if (status == 'RENDER_READY') {
      return const Text(
        'Ready to Render',
        style: TextStyle(
          color: Colors.blueAccent,
          fontWeight: FontWeight.bold,
        ),
      );
    }

    if (status == 'RENDER_COMPLETED' &&
        project.finalVideoUrl != null &&
        project.finalVideoUrl!.isNotEmpty) {
      return Text(
        'Render Success',
        style: TextStyle(
          color: Colors.green.shade700,
          fontWeight: FontWeight.bold,
        ),
      );
    }

    if (status.startsWith('ERROR_')) {
      return Text(
        'Error: $status',
        style: const TextStyle(
          color: Colors.redAccent,
          fontWeight: FontWeight.bold,
        ),
        overflow: TextOverflow.ellipsis,
      );
    }

    return Text('Status: $status');
  }
  // --- AKHIR HELPER VEO ---

  // --- [DIMODIFIKASI] Helper untuk Judul Bagian ---
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
  // --- AKHIR HELPER JUDUL ---

  @override
  Widget build(BuildContext context) {
    // Provider 1 (Imagen / Motion)
    final projectsAsyncValue = ref.watch(projectsStreamProvider);

    // Provider 2 (Veo / Footage)
    final projectsVeoAsyncValue = ref.watch(projectsVeoStreamProvider);

    // Provider 3 (User / Token)
    final userAsyncValue = ref.watch(firestoreUserProvider);

    // [BARU] Menerapkan tema Dark Modern HANYA ke halaman ini
    return Theme(
      data: AppTheme.darkTheme,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Majiku'),
          actions: [
            // 1. Tampilan Saldo Token (Koin Emas & Hijau Kemilau)
            userAsyncValue.when(
              data: (user) {
                if (user.uid.isEmpty) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(right: 12.0), // Spasi kanan sedikit diperlebar
                  child: Center(
                    child: Container( // Container opsional untuk background tipis
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black26, // Latar belakang tipis agar kontras
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // [FITUR UI] Ikon Koin Emas
                          Icon(
                            Icons.monetization_on, 
                            color: Colors.amberAccent[400], // Emas Kemilau
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          // [FITUR UI] Teks Hijau Kemilau
                          Text(
                            '${user.tokenBalance} TM',
                            style: TextStyle(
                              color: Colors.lightGreenAccent[400], // Hijau Kemilau (Neon)
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              shadows: const [ // Efek Glow halus
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.0,
                  ),
                ),
              ),
              error: (e, s) => const Padding(
                padding: EdgeInsets.only(right: 8.0),
                child: Icon(Icons.error_outline, color: Colors.redAccent),
              ),
            ),

            // [MODIFIKASI] Tombol Upgrade & +Token
            userAsyncValue.when(
              data: (user) {
                if (user.uid.isEmpty) {
                  return const SizedBox.shrink(); // User logout
                }
                final bool isFreeUser = (user.userTier == 'free');
                return Row(
                  children: [
                    // Tombol Upgrade (Boxy & Rapi)
                    SizedBox(
                      height: 36,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber[900], // Emas Tua
                          foregroundColor: Colors.white, // Teks Putih
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6), // Tidak terlalu bundar
                          ),
                          elevation: 2,
                        ),
                        child: const Text(
                          'Upgrade',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (context) => const UpgradeScreen()),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    
                    // Tombol +Token (Boxy & Rapi - Tinggi Sama)
                    SizedBox(
                      height: 36,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.cyan[800], // Cyan Gelap
                          foregroundColor: Colors.white, // Teks Putih
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          elevation: 2, 
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6), // Disamakan dengan Upgrade
                          ),
                        ),
                        child: const Text(
                          '+Token', 
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        onPressed: isFreeUser
                            ? null 
                            : () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (context) => const TopUpScreen()),
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

            // 3. Tombol Akun (Navigasi)
            IconButton(
              icon: const Icon(Icons.account_circle_outlined),
              tooltip: 'My Account',
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
            _buildSectionHeader(context, 'My Projects (Motion)'),
            _buildImagenProjectList(context, ref, projectsAsyncValue),

            _buildSectionHeader(context, 'My Projects (Footage)'),
            _buildVeoProjectList(context, ref, projectsVeoAsyncValue),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),

        // [MODIFIKASI] Footer Buttons (Warna Gelap & Teks Kontras)
        persistentFooterButtons: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly, // Ratakan tombol
              children: [
                // --- Tombol +Narrative (TEAL GELAP) ---
                Expanded(
                  child: ElevatedButton(
                    child: const Text(
                      '+Narrative',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16, 
                        fontWeight: FontWeight.bold, 
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: Colors.teal.shade800, // Diubah lebih gelap
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) =>
                              GeneratorKontenShortScreen(), 
                        ),
                      );
                    },
                  ),
                ),
                
                // --- Spasi ---
                const SizedBox(width: 8),
                
                // --- Tombol +VMotion (BIRU TUA) ---
                Expanded(
                  child: ElevatedButton(
                    child: const Text(
                      '+VMotion',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: Colors.blue.shade900, // Diubah lebih gelap/tua
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
                
                // --- Spasi ---
                const SizedBox(width: 8),
                
                // --- Tombol +VFootage (UNGU TUA) ---
                Expanded(
                  child: ElevatedButton(
                    child: const Text(
                      '+VFootage',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: Colors.deepPurple.shade900, // Diubah lebih gelap/tua
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

  // --- [LAMA] Helper Daftar Proyek IMAGEN (Motion) ---
  Widget _buildImagenProjectList(BuildContext context, WidgetRef ref,
      AsyncValue<List<VideoProject>> asyncValue) {
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
          return const SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'No (Motion) projects yet. Create one below!',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }
        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final VideoProject project = projects[index];
              // [UI FIX] Menghilangkan warna belang
              return Card(
                elevation: 2, // Sedikit bayangan agar rapi
                color: Colors.grey[900], // Warna dasar card gelap konsisten
                margin:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6), // Jarak antar card
                child: InkWell( // Menggunakan InkWell untuk efek hover
                  hoverColor: Colors.white.withOpacity(0.05), // Efek hover halus
                  borderRadius: BorderRadius.circular(12), // Mengikuti bentuk card
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
                  child: Padding( // Padding dipindah ke dalam InkWell
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: ListTile(
                      leading: const Icon(Icons.image_search, color: Colors.blueAccent), // Icon diberi warna
                      title: Text(
                        project.title,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: _buildStatus(context, project),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.redAccent),
                        tooltip: 'Delete Project',
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
  // --- AKHIR HELPER IMAGEN ---

  // --- [LAMA] Helper Daftar Proyek VEO (Footage) ---
  Widget _buildVeoProjectList(BuildContext context, WidgetRef ref,
      AsyncValue<List<VideoProjectVeo>> asyncValue) {
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
          return const SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'No (Footage) projects yet. Create one below!',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }
        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final VideoProjectVeo project = projects[index];
              // [UI FIX] Menghilangkan warna belang (Sama dengan Imagen)
              return Card(
                elevation: 2,
                color: Colors.grey[900],
                margin:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
                      leading: const Icon(Icons.movie_filter, color: Colors.deepPurpleAccent), // Icon diberi warna
                      title: Text(
                        project.title,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: _buildStatusVeo(context, project),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.redAccent),
                        tooltip: 'Delete Project',
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
  // --- AKHIR HELPER VEO ---
}