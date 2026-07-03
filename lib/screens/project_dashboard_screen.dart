//......................................................//
// LIB/SCREENS/PROJECT_DASHBOARD_SCREEN.DART            //
// DASHBOARD UTAMA                                      //
//......................................................//

// No ke-1 - IMPOR DEPENDENSI & LAYAR TERKAIT           //
// Konfigurasi provider, layar generator, histori, dan tema //
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart'; // [BARU] Impor url_launcher untuk buka link Tutorial

// --- [CONFIG] Provider Bahasa ---
import '../providers/config_provider.dart';

// --- [BARU] Impor Layar Generator (Menu Utama) ---
import '../screens_naraku/generator_konten_short_screen.dart'; // Narrative
import '../screens_storinema/input_script_storinema_screen.dart'; // VStorinema
import 'input_script_screen.dart'; // VMotion
import '../screens_veo/input_script_veo_screen.dart'; // VFootage

// --- [BARU] Impor Layar Histori (Menu Utama) ---
import 'history_motion_screen.dart'; // Histori VMotion
import '../screens_veo/history_footage_screen.dart'; // Histori VFootage
import '../screens_storinema/history_storinema_screen.dart'; // Histori VStorinema

// --- [NARACINEMA PLUS] Impor Layar Generator & Histori ---
import '../screens_naracinema_plus/input_script_naracinema_plus_screen.dart'; 
import '../screens_naracinema_plus/history_naracinema_plus_screen.dart';

// --- [OTHER TOOLS] Impor Folder Menu Sekunder ---
import 'other_tools_screen.dart'; // Layar Other Tools Create
import 'other_tools_history_screen.dart'; // Layar Other Tools History

// --- [DAILY FREE] Impor Layar Generator Gratis Harian ---
import '../screens_daily_free/free_t2image_screen.dart';
import '../screens_daily_free/free_t2speech_screen.dart';

// --- [LAMA] Integrasi Token & Akun (Dipertahankan 100%) ---
import '../providers/user_provider.dart';
import 'user_account_screen.dart'; 
import 'upgrade_screen.dart';
import 'top_up_screen.dart';

// --- [BARU] Impor Layar Produk/Bantuan & Rate Us ---
import 'majiku_product.dart';
import 'user_rate_us_screen.dart';

// --- [BARU] Impor Tema Dark Modern ---
import '../theme/app_theme.dart';
// Penutup Blok //

// No ke-2 - STATEFUL WIDGET DASHBOARD & HELPER         //
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

// No ke-3 - BUILD METHOD UTAMA                         //
// Merender AppBar Token/Akun dan Layout Grid Menu      //
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
                  // --- HEADER CREATE PROYEK & TOMBOL TUTORIAL [BARU] ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        t('Create New Project', 'Buat Proyek Baru'),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white.withOpacity(0.9),
                          letterSpacing: 0.5,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () async {
                          final Uri url = Uri.parse('https://majiku.net/demo/');
                          if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Could not launch tutorial link.')),
                              );
                            }
                          }
                        },
                        icon: Icon(Icons.play_circle_fill, color: Colors.cyanAccent[400], size: 16),
                        label: Text(
                          t('Tutorial', 'Tutorial'),
                          style: TextStyle(
                            color: Colors.cyanAccent[400],
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.cyanAccent.withOpacity(0.1),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(color: Colors.cyanAccent.withOpacity(0.3)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // --- GRID IMAGE TOMBOL UTAMA ---
                  _buildImageButtonsGrid(),
                  
                  const SizedBox(height: 36),
                  
                  // --- HEADER HISTORI & TOMBOL RATE US ---
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
                  
                  // --- GRID HISTORI TOMBOL ---
                  _buildHistoryButtonsGrid(),
                  
                  const SizedBox(height: 36),

                  // --- HEADER DAILY FREE ---
                  Text(
                    t('Daily Free', 'Gratis Harian'),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.amberAccent[400], 
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // --- GRID DAILY FREE TOMBOL ---
                  _buildDailyFreeButtonsGrid(),

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

// No ke-4 - WIDGET BUILDER UNTUK GRID MENU             //
// Membangun Grid Proyek Baru dan Grid Histori          //

  // --- 1. Grid Image Utama (Baris Atas - Buat Proyek) ---
  Widget _buildImageButtonsGrid() {
    final List<Map<String, dynamic>> menuItems = [
      {'img': 'narrative.png', 'title': 'AUTO NARRATIVE', 'action': () => _navigateTo(GeneratorKontenShortScreen())},
      {'img': 'vstorimotion.png', 'title': 'AUTO NARA MOTION', 'action': () => _navigateTo(InputScriptScreen())},
      {'img': 'vstorinema.png', 'title': 'AUTO NARA CINEMA', 'action': () => _navigateTo(InputScriptStorinemaScreen())},
      {'img': 'vcinema.png', 'title': 'AUTO NARACINEMA-PLUS', 'action': () => _navigateTo(const InputScriptNaracinemaPlusScreen())},
      {'img': 'vmovie.png', 'title': 'AUTO MOVIE', 'action': () => _navigateTo(InputScriptVeoScreen())},
      {'img': 'othertools.png', 'title': 'OTHER TOOLS', 'action': () => _navigateTo(const OtherToolsScreen())},
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
          // 👇 UBAH ANGKA DI BAWAH INI UNTUK UKURAN LOGO CREATE NEW PROJECT 👇
          widthLogo: 0.75, // Lebar logo (75%)
          heightLogo: 0.85, // Tinggi logo (85%)
        );
      },
    );
  }

  // --- 2. Grid Histori (Baris Tengah - Riwayat Proyek) ---
  Widget _buildHistoryButtonsGrid() {
    final List<Map<String, dynamic>> historyItems = [
      {'img': 'narrative.png', 'title': 'AUTO NARRATIVE', 'action': null},
      {'img': 'vstorimotion.png', 'title': 'AUTO NARA MOTION', 'action': () => _navigateTo(HistoryMotionScreen())},
      {'img': 'vstorinema.png', 'title': 'AUTO NARA CINEMA', 'action': () => _navigateTo(HistoryStorinemaScreen())},
      {'img': 'vcinema.png', 'title': 'AUTO NARACINEMA-PLUS', 'action': () => _navigateTo(const HistoryNaracinemaPlusScreen())},
      {'img': 'vmovie.png', 'title': 'AUTO MOVIE', 'action': () => _navigateTo(HistoryFootageScreen())},
      {'img': 'othertools.png', 'title': 'OTHER TOOLS', 'action': () => _navigateTo(const OtherToolsHistoryScreen())},
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
      itemCount: historyItems.length,
      itemBuilder: (context, index) {
        final item = historyItems[index];
        final bool isActive = item['action'] != null;
        
        return _buildImageButton(
          imagePath: 'assets/tombol-dashboard/${item['img']}',
          title: item['title'] as String,
          onTap: isActive ? item['action'] as VoidCallback : _showComingSoon,
          isActive: isActive,
          // 👇 UBAH ANGKA DI BAWAH INI UNTUK UKURAN LOGO PROJECT HISTORY (LEBIH KECIL) 👇
          widthLogo: 0.50, // Lebar logo histori diatur lebih kecil (50%)
          heightLogo: 0.50, // Tinggi logo histori diatur lebih kecil (50%)
        );
      },
    );
  }

  // --- 3. Grid Daily Free (Baris Bawah) ---
  Widget _buildDailyFreeButtonsGrid() {
    final List<Map<String, dynamic>> freeItems = [
      {'img': 'freet2image.png', 'title': 'FREE T2IMAGE', 'action': () => _navigateTo(const FreeT2ImageScreen())}, 
      {'img': 'freet2speech.png', 'title': 'FREE T2SPEECH', 'action': () => _navigateTo(const FreeT2SpeechScreen())}, 
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
      itemCount: freeItems.length,
      itemBuilder: (context, index) {
        final item = freeItems[index];
        final bool isActive = item['action'] != null; 
        
        return _buildImageButton(
          imagePath: 'assets/tombol-dashboard/${item['img']}',
          title: item['title'] as String,
          onTap: isActive ? item['action'] as VoidCallback : _showComingSoon,
          isActive: isActive, 
          widthLogo: 0.75,
          heightLogo: 0.85,
        );
      },
    );
  }

  // --- Komponen Satuan: Tombol Gambar Reusable ---
  Widget _buildImageButton({
    required String imagePath, 
    required String title, 
    required VoidCallback onTap,
    required bool isActive, 
    required double widthLogo, // [BARU] Parameter Lebar Logo
    required double heightLogo, // [BARU] Parameter Tinggi Logo
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
                child: Center(
                  child: FractionallySizedBox(
                    widthFactor: widthLogo,   // <--- Diterapkan di sini
                    heightFactor: heightLogo, // <--- Diterapkan di sini
                    child: Opacity(
                      opacity: isActive ? 1.0 : 0.3, 
                      child: Image.asset(imagePath, fit: BoxFit.contain),
                    ),
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
}
// Penutup Blok //