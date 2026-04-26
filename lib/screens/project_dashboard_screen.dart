// PROJECT_DASHBOARD_SCREEN.DART //
// LIB/SCREENS/PROJECT_DASHBOARD_SCREEN.DART //
// DASHBOARD UTAMA //

// No ke-1 - IMPOR DEPENDENSI & LAYAR TERKAIT //
// Konfigurasi provider, layar generator, histori, dan tema //
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// --- [CONFIG] Provider Bahasa ---
import '../providers/config_provider.dart';

// --- [BARU] Impor Layar Generator (Menu Utama) ---
import '../screens_naraku/generator_konten_short_screen.dart'; // Narrative
import '../screens_naraku/t2video_screen.dart'; // T2Video
import '../screens_naraku/t2image_screen.dart'; // T2Image
import '../screens_naraku/image2video_screen.dart'; // [AKTIF] Integrasi Image2Video
import '../screens_naraku/t2video-plus_screen.dart'; // [AKTIF] T2Video-Plus
import '../screens_storinema/input_script_storinema_screen.dart'; // VStorinema
import 'input_script_screen.dart'; // VMotion
import '../screens_veo/input_script_veo_screen.dart'; // VFootage

// --- [BARU] Impor Layar Histori ---
import 'history_motion_screen.dart'; // Histori VMotion
import '../screens_veo/history_footage_screen.dart'; // Histori VFootage
import '../screens_storinema/history_storinema_screen.dart'; // Histori VStorinema
import '../screens_naraku/history_t2video_screen.dart'; // Histori T2Video
import '../screens_naraku/history_t2image_screen.dart'; // Histori T2Image
import '../screens_naraku/history_image2video_screen.dart'; // [AKTIF] Histori Image2Video
import '../screens_naraku/history_t2video-plus_screen.dart'; // [AKTIF] Histori T2Video-Plus

// --- [NARACINEMA PLUS] Impor Layar Generator & Histori Baru ---
import '../screens_naracinema_plus/input_script_naracinema_plus_screen.dart'; 
import '../screens_naracinema_plus/history_naracinema_plus_screen.dart';

// --- [LAMA] Integrasi Token & Akun (Dipertahankan 100%) ---
import '../providers/user_provider.dart';
import 'user_account_screen.dart'; 
import 'upgrade_screen.dart';
import 'top_up_screen.dart';

// --- [BARU] Impor Layar Produk/Bantuan & Rate Us ---
import 'majiku_product.dart';
import 'user_rate_us_screen.dart'; // [TAMBAHAN BARU UNTUK FITUR RATE US]

// --- [BARU] Impor Tema Dark Modern ---
import '../theme/app_theme.dart';
// Penutup Blok //

// No ke-2 - STATEFUL WIDGET DASHBOARD & HELPER //
// Manajemen state untuk Dashboard dan fungsi utilitas navigasi //
class ProjectDashboardScreen extends ConsumerStatefulWidget {
  const ProjectDashboardScreen({super.key});

  @override
  ConsumerState<ProjectDashboardScreen> createState() => _ProjectDashboardScreenState();
}

class _ProjectDashboardScreenState extends ConsumerState<ProjectDashboardScreen> {
  
  @override
  void initState() {
    super.initState();
  }

  // --- [HELPER] Navigasi & Coming Soon ---
  void _navigateTo(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (context) => screen));
  }

  void _showComingSoon() {
    final isIndo = ref.read(appLanguageProvider).languageCode == 'id';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isIndo ? 'Fitur ini segera hadir!' : 'This feature is coming soon!',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.amber.shade800,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }
// Penutup Blok //

// No ke-3 - BUILD METHOD UTAMA //
// Merender AppBar Token/Akun dan Layout Grid Menu //
  @override
  Widget build(BuildContext context) {
    final userAsyncValue = ref.watch(firestoreUserProvider);
    final currentLocale = ref.watch(appLanguageProvider);
    final isIndo = currentLocale.languageCode == 'id';
    
    String t(String en, String id) => isIndo ? id : en;

    return Theme(
      data: AppTheme.darkTheme,
      child: Scaffold(
        appBar: AppBar(
          title: const SizedBox.shrink(),
          
          // --- [BARU] Tombol Bantuan (Kiri Atas) mengarah ke MajikuProductScreen ---
          leading: IconButton(
            icon: const Icon(Icons.help_outline, color: Colors.white70),
            tooltip: t('Help & Features', 'Bantuan & Fitur'),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const MajikuProductScreen(),
                ),
              );
            },
          ),
          
          actions: [
            // 1. Tampilan Saldo Token
            userAsyncValue.when(
              data: (user) {
                if (user.uid.isEmpty) return const SizedBox.shrink();
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
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
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
                return Row(
                  children: [
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
                          t('Upgrade', 'Upgrade'), 
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
                        child: const Text(
                          '+Token', 
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        onPressed: () {
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

        // --- BODY: Layout Modern Grid ---
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF121212), Color(0xFF000000)],
            ),
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- HEADER CREATE PROYEK ---
                  Text(
                    t('Create New Project', 'Buat Proyek Baru'),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white.withOpacity(0.9),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // --- GRID IMAGE TOMBOL (3x3) ---
                  _buildImageButtonsGrid(),
                  
                  const SizedBox(height: 36),
                  
                  // --- [MODIFIKASI BARU] HEADER HISTORI & TOMBOL RATE US ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        t('Project History', 'Histori Proyek'),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white.withOpacity(0.9),
                          letterSpacing: 0.5,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (context) => const UserRateUsScreen()),
                          );
                        },
                        icon: Icon(Icons.star, color: Colors.amberAccent[400], size: 16),
                        label: Text(
                          t('Rate Us', 'Nilai Kami'),
                          style: TextStyle(
                            color: Colors.amberAccent[400],
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.amberAccent.withOpacity(0.1),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(color: Colors.amberAccent.withOpacity(0.3)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // --- GRID HISTORI TOMBOL (3x3) ---
                  _buildHistoryButtonsGrid(),
                  
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
// Penutup Blok //

// No ke-4 - WIDGET BUILDER UNTUK GRID MENU //
// Membangun Grid Proyek Baru dan Grid Histori dengan Ikon Miniatur //

  // --- 1. Grid Image Utama (Baris Atas - Buat Proyek) ---
  Widget _buildImageButtonsGrid() {
    final List<Map<String, dynamic>> menuItems = [
      {'img': 'narrative.png', 'title': 'AUTO NARRATIVE', 'action': () => _navigateTo(GeneratorKontenShortScreen())},
      {'img': 't2image.png', 'title': 'TEXT TO IMAGE', 'action': () => _navigateTo(T2ImageScreen())},
      {'img': 't2video.png', 'title': 'TEXT TO VIDEO', 'action': () => _navigateTo(T2VideoScreen())},
      {'img': 'i2video.png', 'title': 'IMAGE TO VIDEO', 'action': () => _navigateTo(Image2VideoScreen())},
      {'img': 't2videoplus.png', 'title': 'TEXT TO VIDEOPLUS', 'action': () => _navigateTo(T2videoPlusScreen())},
      {'img': 'vstorinema.png', 'title': 'AUTO NARA CINEMA', 'action': () => _navigateTo(InputScriptStorinemaScreen())},
      {'img': 'vstorimotion.png', 'title': 'AUTO NARA MOTION', 'action': () => _navigateTo(InputScriptScreen())},
      
      // [UPDATE] Mengubah AUTO CINEMA menjadi AUTO NARACINEMA-PLUS & Menghubungkan Navigasi
      {'img': 'vcinema.png', 'title': 'AUTO NARACINEMA-PLUS', 'action': () => _navigateTo(const InputScriptNaracinemaPlusScreen())},
      
      {'img': 'vmovie.png', 'title': 'AUTO MOVIE', 'action': () => _navigateTo(InputScriptVeoScreen())},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 20.0, 
        mainAxisSpacing: 32.0,  
        childAspectRatio: 0.90, 
      ),
      itemCount: menuItems.length,
      itemBuilder: (context, index) {
        final item = menuItems[index];
        final bool isActive = item['action'] != null; 
        
        return _buildImageButton(
          imagePath: 'assets/tombol-dashboard/${item['img']}',
          title: item['title'] as String,
          onTap: isActive ? item['action'] as VoidCallback : _showComingSoon,
          isActive: isActive, 
        );
      },
    );
  }

  // --- 2. Grid Histori (Baris Bawah - Riwayat Proyek) ---
  Widget _buildHistoryButtonsGrid() {
    final List<Map<String, dynamic>> historyItems = [
      {'img': 'narrative.png', 'title': 'Narrative', 'action': null},
      {'img': 't2image.png', 'title': 'T2Image', 'action': () => _navigateTo(HistoryT2ImageScreen())},
      {'img': 't2video.png', 'title': 'T2Video', 'action': () => _navigateTo(HistoryT2VideoScreen())},
      {'img': 'i2video.png', 'title': 'I2Video', 'action': () => _navigateTo(HistoryImage2VideoScreen())}, 
      {'img': 't2videoplus.png', 'title': 'T2Video+', 'action': () => _navigateTo(HistoryT2videoPlusScreen())},
      {'img': 'vstorinema.png', 'title': 'VStorinema', 'action': () => _navigateTo(HistoryStorinemaScreen())},
      {'img': 'vstorimotion.png', 'title': 'VStorimotion', 'action': () => _navigateTo(HistoryMotionScreen())},
      
      // [UPDATE] Menghubungkan Histori Naracinema-Plus
      {'img': 'vcinema.png', 'title': 'VNaracinema+', 'action': () => _navigateTo(const HistoryNaracinemaPlusScreen())},
      
      {'img': 'vmovie.png', 'title': 'VMovie', 'action': () => _navigateTo(HistoryFootageScreen())},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 20.0, 
        mainAxisSpacing: 24.0,  
        childAspectRatio: 0.90, 
      ),
      itemCount: historyItems.length,
      itemBuilder: (context, index) {
        final item = historyItems[index];
        return _buildHistoryButton(
          imagePath: 'assets/tombol-dashboard/${item['img']}',
          title: item['title'] as String,
          onTap: item['action'] != null ? item['action'] as VoidCallback : _showComingSoon,
          isActive: item['action'] != null,
        );
      },
    );
  }

  // --- Komponen Satuan: Tombol Gambar Utama (Create) ---
  Widget _buildImageButton({
    required String imagePath, 
    required String title, 
    required VoidCallback onTap,
    required bool isActive, 
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isActive ? Colors.grey[900]?.withOpacity(0.3) : Colors.grey[900]?.withOpacity(0.1), 
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? Colors.white12 : Colors.white10.withOpacity(0.02), 
          width: 1.5
        ), 
        boxShadow: isActive ? [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ] : [], 
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: isActive ? Colors.white24 : Colors.transparent, 
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: FractionallySizedBox(
                  widthFactor: 0.75,
                  heightFactor: 0.85,
                  child: Opacity(
                    opacity: isActive ? 1.0 : 0.3, 
                    child: Image.asset(imagePath, fit: BoxFit.contain),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0, left: 4, right: 4),
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: TextStyle(
                    fontSize: 11, 
                    fontWeight: FontWeight.bold, 
                    color: isActive ? Colors.white70 : Colors.white38 
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Komponen Satuan: Tombol Histori (Miniatur Grid) ---
  Widget _buildHistoryButton({
    required String imagePath, 
    required String title, 
    required VoidCallback onTap, 
    required bool isActive
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isActive ? Colors.grey[850] : Colors.grey[900]?.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? Colors.white24 : Colors.white10,
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Center(
                  child: FractionallySizedBox(
                    widthFactor: 0.5, 
                    heightFactor: 0.5,
                    child: Opacity(
                      opacity: isActive ? 1.0 : 0.3,
                      child: Image.asset(imagePath, fit: BoxFit.contain),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0, left: 4, right: 4),
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11, 
                    fontWeight: FontWeight.bold,
                    color: isActive ? Colors.white : Colors.white38,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
 }
// Penutup Blok //