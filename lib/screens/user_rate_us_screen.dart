//===================================================================//
// NAMA FILE: USER_RATE_US_SCREEN.DART                               //
// PATH: LIB/SCREENS/USER_RATE_US_SCREEN.DART                        //
//===================================================================//

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../providers/user_provider.dart';
import '../providers/config_provider.dart'; // [TAMBAHAN] Import provider bahasa

//No ke-1 - WIDGET UTAMA & LOGIKA RATE US............................//
// Mengelola state rating, text controller, dan pengiriman Firebase..//
class UserRateUsScreen extends ConsumerStatefulWidget {
  const UserRateUsScreen({super.key});

  @override
  ConsumerState<UserRateUsScreen> createState() => _UserRateUsScreenState();
}

class _UserRateUsScreenState extends ConsumerState<UserRateUsScreen> {
  int _rating = 0;
  final TextEditingController _saranController = TextEditingController();
  bool _isSubmitting = false;

  // Helper sederhana untuk menerjemahkan teks
  String _t(bool isIndo, String en, String id) {
    return isIndo ? id : en;
  }

  @override
  void dispose() {
    _saranController.dispose();
    super.dispose();
  }

  Future<void> _submitFeedback() async {
    // Ambil status bahasa untuk peringatan/notifikasi di luar widget build
    final isIndo = ref.read(appLanguageProvider).languageCode == 'id';

    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t(isIndo, 'Please provide a star rating first.', 'Silakan berikan rating bintang terlebih dahulu.')),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Ambil data user saat ini
      final user = ref.read(firestoreUserProvider).value;
      final uid = user?.uid ?? 'unknown_uid';
      final email = user?.email ?? 'unknown_email';
      
      // Ambil versi aplikasi
      String appVersion = 'unknown';
      try {
        final packageInfo = await PackageInfo.fromPlatform();
        appVersion = packageInfo.version;
      } catch (_) {}

      // --- [MODIFIKASI BARU] VALIDASI SILANG ANTI-SPAM ---
      // Cek apakah user ini sudah pernah memberi feedback
      final existingFeedbacks = await FirebaseFirestore.instance
          .collection('user_feedbacks')
          .where('userId', isEqualTo: uid)
          .get();

      // Filter lokal untuk mencocokkan versi aplikasi (Menghindari error Composite Index Firestore)
      final hasRatedThisVersion = existingFeedbacks.docs.any(
        (doc) => doc.data()['appVersion'] == appVersion
      );

      if (hasRatedThisVersion) {
        if (!mounted) return;
        
        // Tampilkan notifikasi penolakan halus
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _t(
                isIndo, 
                'Thank you, you have already provided feedback for this version...', 
                'Terima kasih, kamu sudah pernah memberikan feedback untuk versi ini...'
              ),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
            ),
            backgroundColor: Colors.amber[800], // Warna peringatan elegan
            duration: const Duration(seconds: 4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
        
        setState(() {
          _isSubmitting = false;
        });
        return; // Hentikan eksekusi, jangan kirim ke Firestore
      }
      // --- END VALIDASI SILANG ---

      // Jika lolos validasi, kirim ke Firestore collection 'user_feedbacks'
      await FirebaseFirestore.instance.collection('user_feedbacks').add({
        'rating': _rating,
        'saran': _saranController.text.trim(),
        'userId': uid,
        'userEmail': email,
        'appVersion': appVersion,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      // Tampilkan ucapan terima kasih elegan (Bilingual)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              isIndo, 
              'Thank you for your support to Majiku, please don\'t hesitate to come back...', 
              'Terimakasih atas dukunganmu untuk Majiku, jangan bosan untuk kembali lagi...'
            ),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
          ),
          backgroundColor: Colors.purple[800], // Warna ungu elegan
          duration: const Duration(seconds: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
        ),
      );

      Navigator.of(context).pop(); // Kembali ke dashboard
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t(isIndo, 'An error occurred: $e', 'Terjadi kesalahan: $e'))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }
// Penutup Blok //

//No ke-2 - ANTARMUKA PENGGUNA (UI) FORM BILINGUAL...................//
// Render tampilan minimalis elegan nuansa hitam, ungu, dan emas.....//
  @override
  Widget build(BuildContext context) {
    // Membaca status bahasa dari provider
    final currentLocale = ref.watch(appLanguageProvider);
    final isIndo = currentLocale.languageCode == 'id';

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white70),
        title: Text(
          _t(isIndo, 'Rate Us', 'Nilai Kami'),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Stack(
        children: [
          // Background Gradient Majiku (Hitam ke Ungu Gelap)
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF121212), Color(0xFF1A0B2E)],
              ),
            ),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _t(isIndo, 'How was your experience using Majiku?', 'Bagaimana pengalaman Anda menggunakan Majiku?'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 36),
                
                // --- Input Bintang 1-5 ---
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(5, (index) {
                      return IconButton(
                        iconSize: 48,
                        icon: Icon(
                          index < _rating ? Icons.star : Icons.star_border,
                          color: index < _rating ? Colors.amberAccent[400] : Colors.white30,
                        ),
                        onPressed: () {
                          setState(() {
                            _rating = index + 1; // Rating 1-5
                          });
                        },
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 40),
                
                // --- Kotak Saran (Opsional) ---
                Text(
                  _t(isIndo, 'Suggestions & Feedback', 'Saran & Masukan'),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _saranController,
                  maxLines: 5,
                  maxLength: 1000, // [MODIFIKASI BARU] Batasan 1000 karakter
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: _t(isIndo, 'Write your experience or suggestions for us...', 'Tuliskan pengalaman atau saran Anda untuk kami...'),
                    hintStyle: const TextStyle(color: Colors.white30),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.04), // Elegan transparan
                    counterStyle: const TextStyle(color: Colors.white54, fontSize: 12), // [MODIFIKASI BARU] Gaya angka counter
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.purpleAccent.withOpacity(0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Colors.purpleAccent, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                
                // --- Tombol Send Kanan Bawah ---
                Align(
                  alignment: Alignment.bottomRight,
                  child: _isSubmitting
                      ? const Padding(
                          padding: EdgeInsets.only(right: 24.0),
                          child: CircularProgressIndicator(color: Colors.amberAccent),
                        )
                      : ElevatedButton.icon(
                          onPressed: _submitFeedback,
                          icon: const Icon(Icons.send_rounded, color: Colors.black87),
                          label: Text(
                            _t(isIndo, 'Send', 'Kirim'),
                            style: const TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amberAccent[400], // Emas
                            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            elevation: 8,
                            shadowColor: Colors.amberAccent.withOpacity(0.4),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  }
// Penutup Blok //