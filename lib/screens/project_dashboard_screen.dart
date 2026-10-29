//============================================================================//
// DIREKTORI: LIB/SCREENS/                                                    //
// FILE: PROJECT_DASHBOARD_SCREEN.DART                                        //
// DASHBOARD UTAMA MAJIKU                                                     //
//============================================================================//

//No ke-1....................................................................//
//IMPOR DEPENDENSI & LAYAR TERKAIT                                           //
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

// --- [CONFIG] Provider Bahasa ---
import '../providers/config_provider.dart';

// --- [ENTERTAINMENT] Impor Layar Mytube ---
import '../entertainment/mytube/screens/mytube_home_screen.dart';

// --- [BARU] Impor Layar Generator (Menu Utama) ---
import '../screens_naraku/generator_konten_short_screen.dart'; // Narrative
import '../screens_storinema/input_script_storinema_screen.dart'; // VStorinema
import 'input_script_screen.dart'; // VMotion
import '../screens_veo/input_script_veo_screen.dart'; // VFootage

// --- [MARKETING VIDEO] Impor Layar Generator ---
import '../screens_marketting_video/input_script_marketting_video_screen.dart';

// --- [BARU] Impor Layar Histori (Menu Utama) ---
import 'history_motion_screen.dart'; // Histori VMotion
import '../screens_veo/history_footage_screen.dart'; // Histori VFootage
import '../screens_storinema/history_storinema_screen.dart'; // Histori VStorinema

// --- [MARKETING VIDEO] Impor Layar Histori ---
import '../screens_marketting_video/history_marketting_video_screen.dart';

// --- [NARACINEMA PLUS] Impor Layar Generator & Histori ---
import '../screens_naracinema_plus/input_script_naracinema_plus_screen.dart'; 
import '../screens_naracinema_plus/history_naracinema_plus_screen.dart';

// --- [OTHER TOOLS] Impor Folder Menu Sekunder ---
import 'other_tools_screen.dart'; // Layar Other Tools Create
import 'other_tools_history_screen.dart'; // Layar Other Tools History

// --- [DAILY FREE & ENTERTAINMENT] Impor Layar Generator Harian ---
import '../screens_daily_free/free_t2image_screen.dart';
import '../screens_daily_free/free_t2speech_screen.dart';
import '../screens_daily_free/free_daily_quotes_screen.dart';

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
//............................................................................//

//No ke-2....................................................................//
//STATEFUL WIDGET DASHBOARD & HELPER                                         //
class ProjectDashboardScreen extends ConsumerStatefulWidget {
  const ProjectDashboardScreen({super.key});

  @override
  ConsumerState<ProjectDashboardScreen> createState() => _ProjectDashboardScreenState();
}

class _ProjectDashboardScreenState extends ConsumerState<ProjectDashboardScreen> {
  bool _imagesPrecached = false;
  bool _isNavigating = false; // [PENGAMAN MULTI-TAP / RAPID NAVIGATION LOCK]

  @override
  void initState() {
    super.initState();
  }

  // --- [PRE-CACHE ASSET IMAGES: HILANGKAN KEDIPAN & JITTER LAYAR] ---
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_imagesPrecached) {
      _imagesPrecached = true;
      _precacheDashboardImages();
    }
  }

  void _precacheDashboardImages() {
    const assetNames = [
      'assets/tombol-dashboard/mytube.png',
      'assets/tombol-dashboard/narrative.png',
      'assets/tombol-dashboard/vstorimotion.png',
      'assets/tombol-dashboard/marketing_video.png',
      'assets/tombol-dashboard/vstorinema.png',
      'assets/tombol-dashboard/vcinema.png',
      'assets/tombol-dashboard/vmovie.png',
      'assets/tombol-dashboard/othertools.png',
      'assets/tombol-dashboard/freet2image.png',
      'assets/tombol-dashboard/freet2speech.png',
      'assets/tombol-dashboard/daily_quotes.png',
    ];
    for (final path in assetNames) {
      precacheImage(AssetImage(path), context);
    }
  }

  // --- [HELPER] Navigasi dengan Navigation Lock (Bebas Tabrakan Rute) ---
  void _navigateTo(Widget screen) {
    if (_isNavigating) return;
    _isNavigating = true;

    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => screen),
    ).then((_) {
      if (mounted) {
        _isNavigating = false;
      }
    });
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
//............................................................................//

//No ke-3....................................................................//
//BUILD METHOD UTAMA & STRUKTUR LAYOUT (SMOOTH TRANSITION & ZERO FLICKER)    //
  @override
  Widget build(BuildContext context) {
    final userAsyncValue = ref.watch(firestoreUserProvider);
    final currentLocale = ref.watch(appLanguageProvider);
    final isIndo = currentLocale.languageCode == 'id';
    
    String t(String en, String id) => isIndo ? id : en;

    return Theme(
      data: AppTheme.darkTheme,
      // [TRANSISI SATU PINTU]: Mengeliminasi 2x kedipan dengan menunggu data akun & aset siap
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        switchInCurve: Curves.easeInOut,
        switchOutCurve: Curves.easeInOut,
        child: userAsyncValue.when(
          // 1. Layar Loading Awal Elegan (Gelap & Tenang tanpa elemen kaget)
          loading: () => Scaffold(
            key: const ValueKey('dashboard_initial_loading'),
            backgroundColor: const Color(0xFF121212),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 38,
                    height: 38,
                    child: CircularProgressIndicator(
                      strokeWidth: 3.0,
                      color: Colors.amberAccent,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    t('Loading Majiku...', 'Memuat Majiku...'),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. Layar Error jika data pengguna gagal diambil
          error: (error, _) => Scaffold(
            key: const ValueKey('dashboard_error_state'),
            backgroundColor: const Color(0xFF121212),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      t('Failed to load user data: $error', 'Gagal memuat data pengguna: $error'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70, fontSize: 13.5),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 3. Tampilan Dasbor Utama (Muncul Melarut Halus Bersama Semua Data yang Sudah Matang)
          data: (user) {
            return Scaffold(
              key: const ValueKey('dashboard_loaded_view'),
              appBar: AppBar(
                title: const SizedBox.shrink(),
                
                // Tombol Bantuan (Kiri Atas)
                leading: IconButton(
                  icon: const Icon(Icons.help_outline, color: Colors.white70),
                  tooltip: t('Help & Features', 'Bantuan & Fitur'),
                  onPressed: () => _navigateTo(const MajikuProductScreen()),
                ),
                
                actions: [
                  if (user.uid.isNotEmpty) ...[
                    // 1. Tampilan Saldo Token
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
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
                    ),

                    // 2. Tombol Upgrade
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
                        onPressed: () => _navigateTo(const UpgradeScreen()),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // 3. Tombol +Token
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
                        onPressed: () => _navigateTo(const TopUpScreen()),
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],

                  // 4. Tombol Akun
                  IconButton(
                    icon: const Icon(Icons.account_circle_outlined),
                    tooltip: t('My Account', 'Akun Saya'),
                    onPressed: () => _navigateTo(const UserAccountScreen()),
                  ),
                ],
              ),

              // BODY: Layout Modern Grid
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
                        // --- 1. HEADER ENTERTAINMENT & GRID (PALING ATAS) ---
                        Text(
                          t('Entertainment', 'Hiburan'),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.amberAccent[400],
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        _buildEntertainmentButtonsGrid(),
                        
                        const SizedBox(height: 36),

                        // --- 2. HEADER CREATE AUTO-PROJECT & TOMBOL TUTORIAL ---
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              t('Create Auto-Project', 'Buat Auto-Project'),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.amberAccent[400],
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
                        
                        _buildImageButtonsGrid(),
                        
                        const SizedBox(height: 36),
                        
                        // --- 3. HEADER HISTORI & TOMBOL FEED BACK ---
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
                              onPressed: () => _navigateTo(const UserRateUsScreen()),
                              icon: Icon(Icons.star, color: Colors.amberAccent[400], size: 16),
                              label: Text(
                                t('Feed Back', 'Umpan Balik'),
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
                        
                        _buildHistoryButtonsGrid(),
                        
                        const SizedBox(height: 36),

                        // --- 4. HEADER DAILY FREE ---
                        Text(
                          t('Daily Free', 'Gratis Harian'),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white.withOpacity(0.9),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        _buildDailyFreeButtonsGrid(),

                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
//............................................................................//

//No ke-4....................................................................//
//WIDGET BUILDER UNTUK GRID MENU (DILENGKAPI FRAMEBUILDER FADE-IN GAMBAR)    //

  // --- 0. Grid Entertainment (Baris Paling Atas) ---
  Widget _buildEntertainmentButtonsGrid() {
    final List<Map<String, dynamic>> entertainmentItems = [
      // [PINTU MASUK MYTUBE]: Sekarang langsung membuka Beranda Katalog MyTube (MytubeHomeScreen)
      {'img': 'mytube.png', 'title': 'SHORT VIDEO', 'action': () => _navigateTo(const MytubeHomeScreen())},
      {'img': 'daily_quotes.png', 'title': 'DAILY QUOTES', 'action': () => _navigateTo(const FreeDailyQuotesScreen())},
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
      itemCount: entertainmentItems.length,
      itemBuilder: (context, index) {
        final item = entertainmentItems[index];
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

  // --- 1. Grid Image Utama (Baris Kedua - Buat Proyek) ---
  Widget _buildImageButtonsGrid() {
    final List<Map<String, dynamic>> menuItems = [
      {'img': 'narrative.png', 'title': 'NARRATIVE', 'action': () => _navigateTo(GeneratorKontenShortScreen())},
      {'img': 'vstorimotion.png', 'title': 'NARAMOTION', 'action': () => _navigateTo(InputScriptScreen())},
      {'img': 'marketing_video.png', 'title': 'MARKETING VIDEO', 'action': () => _navigateTo(const InputScriptMarkettingVideoScreen())},
      {'img': 'vstorinema.png', 'title': 'NARACINEMA', 'action': () => _navigateTo(InputScriptStorinemaScreen())},
      {'img': 'vcinema.png', 'title': 'NARACINEMA + CHARACTER', 'action': () => _navigateTo(const InputScriptNaracinemaPlusScreen())},
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
          widthLogo: 0.75,
          heightLogo: 0.85,
        );
      },
    );
  }

  // --- 2. Grid Histori (Baris Ketiga - Riwayat Proyek) ---
  Widget _buildHistoryButtonsGrid() {
    final List<Map<String, dynamic>> historyItems = [
      {'img': 'narrative.png', 'title': 'NARRATIVE', 'action': null},
      {'img': 'vstorimotion.png', 'title': 'NARAMOTION', 'action': () => _navigateTo(HistoryMotionScreen())},
      {'img': 'marketing_video.png', 'title': 'MARKETING VIDEO', 'action': () => _navigateTo(const HistoryMarkettingVideoScreen())},
      {'img': 'vstorinema.png', 'title': 'NARACINEMA', 'action': () => _navigateTo(HistoryStorinemaScreen())},
      {'img': 'vcinema.png', 'title': 'NARACINEMA + CHARACTER', 'action': () => _navigateTo(const HistoryNaracinemaPlusScreen())},
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
          widthLogo: 0.50,
          heightLogo: 0.50,
        );
      },
    );
  }

  // --- 3. Grid Daily Free (Baris Paling Bawah) ---
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

  // --- Komponen Satuan: Tombol Gambar Reusable dengan Proteksi Fade-In Anti-Kedip ---
  Widget _buildImageButton({
    required String imagePath, 
    required String title, 
    required VoidCallback onTap,
    required bool isActive, 
    required double widthLogo, 
    required double heightLogo, 
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isActive ? Colors.grey[900]?.withOpacity(0.3) : Colors.grey[900]?.withOpacity(0.1), 
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? Colors.white12 : Colors.white10.withOpacity(0.02), 
          width: 1.5,
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
                    widthFactor: widthLogo,   
                    heightFactor: heightLogo, 
                    child: Opacity(
                      opacity: isActive ? 1.0 : 0.3, 
                      // [PROTEKSI ANTI POP-IN]: FrameBuilder memberikan transisi kehalusan saat decode gambar
                      child: Image.asset(
                        imagePath, 
                        fit: BoxFit.contain,
                        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                          if (wasSynchronouslyLoaded) return child;
                          return AnimatedOpacity(
                            opacity: frame == null ? 0.0 : 1.0,
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOut,
                            child: child,
                          );
                        },
                      ),
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
                    color: isActive ? Colors.white70 : Colors.white38,
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
//............................................................................//