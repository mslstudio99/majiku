//================================================================//
// LIB/SCREENS/OTHER_TOOLS_HISTORY_SCREEN.DART                    //
// LAYAR HISTORI OTHER TOOLS (FITUR SEKUNDER MAJIKU)              //
// GRID MENU RIWAYAT NARAKU AI SUITE TERMASUK TEXT TO SPEECH      //
//================================================================//

//No ke-1: IMPOR DEPENDENSI & LAYAR HISTORI                       //
//IMPORT MATERIAL, THEME & DAFTAR LAYAR RIWAYAT NARAKU            //
import 'package:flutter/material.dart';

// --- Impor Layar Histori Naraku ---
import '../screens_naraku/history_t2image_screen.dart';
import '../screens_naraku/history_t2video_screen.dart';
import '../screens_naraku/history_image2video_screen.dart';
import '../screens_naraku/history_t2video-plus_screen.dart';
import '../screens_naraku/history_t2speech_screen.dart'; // [BARU] Layar Histori T2Speech

// --- Impor Tema ---
import '../theme/app_theme.dart';
// END OF BLOK 1 //
//================================================================//

//No ke-2: WIDGET OTHER TOOLS HISTORY SCREEN & LAYOUT DASAR       //
//SCAFFOLD, GRADIENT BACKGROUND & SCROLL CONTAINER RIWAYAT        //
class OtherToolsHistoryScreen extends StatelessWidget {
  const OtherToolsHistoryScreen({super.key});

  void _navigateTo(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (context) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.darkTheme,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Other Tools History', style: TextStyle(fontWeight: FontWeight.bold)),
          centerTitle: true,
        ),
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
              child: _buildOtherHistoryGrid(context),
            ),
          ),
        ),
      ),
    );
  }
// END OF BLOK 2 //
//================================================================//

//No ke-3: BUILDER WIDGET & KOMPONEN GRID RIWAYAT                 //
//GRID VIEW ITEMS HISTORI DENGAN FORMAT & UKURAN IKON IDENTIK     //
  Widget _buildOtherHistoryGrid(BuildContext context) {
    final List<Map<String, dynamic>> historyItems = [
      {'img': 't2image.png', 'title': 'T2IMAGE', 'action': () => _navigateTo(context, HistoryT2ImageScreen())},
      {'img': 't2video.png', 'title': 'T2VIDEO', 'action': () => _navigateTo(context, HistoryT2VideoScreen())},
      {'img': 'i2video.png', 'title': 'I2VIDEO', 'action': () => _navigateTo(context, HistoryImage2VideoScreen())}, 
      {'img': 't2videoplus.png', 'title': 'T2VIDEO+', 'action': () => _navigateTo(context, HistoryT2videoPlusScreen())},
      {'img': 't2speech.png', 'title': 'T2SPEECH', 'action': () => _navigateTo(context, const HistoryT2SpeechScreen())},
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
          onTap: isActive ? item['action'] as VoidCallback : () {},
          isActive: isActive,
        );
      },
    );
  }

  // Komponen identik dengan ProjectDashboardScreen dilengkapi fallback anti-error
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
                    child: Image.asset(
                      imagePath, 
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        // Fallback cerdas: jika t2speech.png belum ter-cache browser, tampilkan freet2speech.png atau icon
                        return Image.asset(
                          'assets/tombol-dashboard/freet2speech.png',
                          fit: BoxFit.contain,
                          errorBuilder: (ctx, err, st) => const Icon(
                            Icons.record_voice_over_rounded,
                            color: Colors.amber,
                            size: 38,
                          ),
                        );
                      },
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
// END OF BLOK 3 //