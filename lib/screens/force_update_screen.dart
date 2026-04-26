//===================================================================//
// NAMA FILE: FORCE_UPDATE_SCREEN.DART                               //
// PATH: LIB/SCREENS/FORCE_UPDATE_SCREEN.DART                        //
//===================================================================//

//No ke-1............................................................//
// IMPORT & LAYOUT UTAMA (LAYAR BLOKIR)                              //
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ForceUpdateScreen extends StatelessWidget {
  final String playStoreUrl;

  const ForceUpdateScreen({
    super.key, 
    required this.playStoreUrl
  });

  Future<void> _launchStore() async {
    final Uri url = Uri.parse(playStoreUrl);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint("Gagal membuka URL Play Store: $playStoreUrl");
    }
  }

//No ke-2............................................................//
// UI DESIGN (TIDAK BISA DIBACK)                                     //
  @override
  Widget build(BuildContext context) {
    // Membungkus dengan PopScope agar pengguna tidak bisa menekan tombol 'Back' fisik HP
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black, // Dark Modern
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Icon Peringatan Update
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.system_update_rounded,
                    size: 80,
                    color: Colors.purpleAccent,
                  ),
                ),
                const SizedBox(height: 40),
                
                // Judul
                const Text(
                  "Pembaruan Wajib",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Deskripsi
                const Text(
                  "Versi aplikasi Anda sudah usang. Mohon perbarui Majiku ke versi terbaru untuk terus menikmati fitur AI dengan stabil dan aman.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 48),
                
                // Tombol Update ke Play Store
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _launchStore,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      "Update Sekarang",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
//-------------------------------------------------------------------//