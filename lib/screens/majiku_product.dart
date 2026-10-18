// LIB/SCREENS/MAJIKU_PRODUCT.DART //
// UI SCREEN FRONTEND //
// DAFTAR PRODUK DAN FITUR UTAMA MAJIKU BILINGUAL //

//No ke-1 : IMPOR DEPENDENSI & KELAS DATA//
//Mengimpor komponen UI, Riverpod untuk bahasa, dan model data produk//
//.......................................................//
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// --- Provider untuk pengaturan bahasa ---
import '../providers/config_provider.dart';

// --- Tema Aplikasi (Pastikan tema dark modern aktif) ---
import '../theme/app_theme.dart';

// --- [STRUKTUR DATA] Model Atribut Produk ---
class ProductAttribute {
  final String labelId;
  final String labelEn;
  final String valueId;
  final String valueEn;

  ProductAttribute({
    required this.labelId,
    required this.labelEn,
    required this.valueId,
    required this.valueEn,
  });
}

// --- [STRUKTUR DATA] Model Produk Utama (Dengan Dukungan Gambar & Ikon) ---
class MajikuProduct {
  final String title;
  final IconData? icon;
  final String? imageAsset;
  final Color highlightColor;
  final List<ProductAttribute> attributes;

  MajikuProduct({
    required this.title,
    this.icon,
    this.imageAsset,
    required this.highlightColor,
    required this.attributes,
  });
}
//........//

//No ke-2 : STATELESS WIDGET UTAMA & DATA PRODUK//
//Berisi daftar lengkap 8 produk resmi Majiku beserta terjemahannya (Default Inggris)//
//.......................................................//
class MajikuProductScreen extends ConsumerWidget {
  const MajikuProductScreen({super.key});

  // --- Helper Penerjemah (Default: Bahasa Inggris) ---
  String _t(bool isIndo, String en, String id) => isIndo ? id : en;

  // --- Sumber Data 8 Produk Majiku Terupdate ---
  List<MajikuProduct> _getProducts() {
    return [
      // 1. AUTO NARRATIVE
      MajikuProduct(
        title: '1. AUTO NARRATIVE',
        imageAsset: 'assets/tombol-dashboard/narrative.png',
        icon: Icons.auto_stories_rounded,
        highlightColor: Colors.amber,
        attributes: [
          ProductAttribute(
            labelId: 'Deskripsi',
            labelEn: 'Description',
            valueId: 'Fitur untuk merubah ide menjadi teks cerita atau narasi konten otomatis. Bisa untuk pembuatan teks narasi konten shorts, umum, islami, sejarah, legenda, horor, hingga dongeng custom. Teks hasil narasi bisa di-salin (copy) atau dikirim (send) langsung ke modul pembuatan video otomatis (seperti Naramotion, Naracinema, Naracinema + Character, Automovie, dll.).',
            valueEn: 'Feature to transform ideas into automatic story texts or content narratives. Can be used for creating narrative scripts for shorts, general, Islamic, history, legends, horror, to custom fairy tales. Narrative outputs can be copied or sent directly to automatic video creation modules (such as Naramotion, Naracinema, Naracinema + Character, Automovie, etc.).',
          ),
        ],
      ),

      // 2. NARAMOTION
      MajikuProduct(
        title: '2. NARAMOTION',
        imageAsset: 'assets/tombol-dashboard/vstorimotion.png',
        icon: Icons.movie_filter_rounded,
        highlightColor: Colors.orangeAccent,
        attributes: [
          ProductAttribute(
            labelId: 'Deskripsi',
            labelEn: 'Description',
            valueId: 'Fitur untuk merubah teks cerita atau narasi menjadi video konten storytelling berbasis gambar bergerak (motion image) dengan audio narasi (voiceover) secara otomatis. Biaya sangat efisien, mendukung berbagai style gambar, rasio, bahasa, tipe vocal, dengan durasi video hingga 20 menit.',
            valueEn: 'Feature to transform story texts or narratives into storytelling video content based on motion images with automatic narrative audio (voiceover). Highly cost-efficient, supports various image styles, aspect ratios, languages, vocal types, with video durations up to 20 minutes.',
          ),
        ],
      ),

      // 3. MARKETING-VIDEO
      MajikuProduct(
        title: '3. MARKETING-VIDEO',
        imageAsset: 'assets/tombol-dashboard/marketting.png',
        icon: Icons.campaign_rounded,
        highlightColor: Colors.blueAccent,
        attributes: [
          ProductAttribute(
            labelId: 'Deskripsi',
            labelEn: 'Description',
            valueId: 'Fitur untuk merubah gambar produk menjadi narasi dan video promosi menarik berbasis klip (footage) dengan audio narasi (voiceover) secara otomatis. Mendukung berbagai style gambar, rasio, bahasa, dan tipe vocal.',
            valueEn: 'Feature to transform product images into engaging narratives and promotional videos based on footage clips with automatic narrative audio (voiceover). Supports various image styles, aspect ratios, languages, and vocal types.',
          ),
        ],
      ),

      // 4. NARACINEMA
      MajikuProduct(
        title: '4. NARACINEMA',
        imageAsset: 'assets/tombol-dashboard/vstorinema.png',
        icon: Icons.movie_creation_rounded,
        highlightColor: Colors.redAccent,
        attributes: [
          ProductAttribute(
            labelId: 'Deskripsi',
            labelEn: 'Description',
            valueId: 'Fitur untuk merubah teks cerita atau narasi menjadi video konten storytelling berbasis klip (footage) dengan audio narasi (voiceover) secara otomatis. Mendukung berbagai style gambar, rasio, bahasa, tipe vocal, dengan durasi video hingga 20 menit.',
            valueEn: 'Feature to transform story texts or narratives into storytelling video content based on footage clips with automatic narrative audio (voiceover). Supports various image styles, aspect ratios, languages, vocal types, with video durations up to 20 minutes.',
          ),
        ],
      ),

      // 5. NARACINEMA + CHARACTER
      MajikuProduct(
        title: '5. NARACINEMA + CHARACTER',
        imageAsset: 'assets/tombol-dashboard/vcinema.png',
        icon: Icons.person_pin_rounded,
        highlightColor: Colors.pinkAccent,
        attributes: [
          ProductAttribute(
            labelId: 'Deskripsi',
            labelEn: 'Description',
            valueId: 'Fitur untuk merubah teks cerita atau narasi menjadi video konten storytelling berbasis klip (footage), bisa custom, auto dan konsistensi character dengan audio narasi (voiceover) secara otomatis. Mendukung berbagai style gambar, rasio, bahasa, tipe vocal, dengan durasi video hingga 20 menit.',
            valueEn: 'Feature to transform story texts or narratives into storytelling video content based on footage clips, supporting custom, automatic, and consistent characters with automatic narrative audio (voiceover). Supports various image styles, aspect ratios, languages, vocal types, with video durations up to 20 minutes.',
          ),
        ],
      ),

      // 6. AUTOMOVIE
      MajikuProduct(
        title: '6. AUTOMOVIE',
        imageAsset: 'assets/tombol-dashboard/vmovie.png',
        icon: Icons.videocam_rounded,
        highlightColor: Colors.tealAccent,
        attributes: [
          ProductAttribute(
            labelId: 'Deskripsi',
            labelEn: 'Description',
            valueId: 'Fitur untuk merubah teks cerita atau narasi menjadi film, bisa custom, auto dan konsistensi character, dengan sync audio speech dan suara latar. Mendukung berbagai style gambar, rasio, bahasa, dengan durasi hingga 20 menit.',
            valueEn: 'Feature to transform story texts or narratives into full movies, supporting custom, automatic, and consistent characters, with audio speech synchronization and background sound. Supports various image styles, aspect ratios, languages, with durations up to 20 minutes.',
          ),
        ],
      ),

      // 7. OTHER TOOLS
      MajikuProduct(
        title: '7. OTHER TOOLS',
        icon: Icons.widgets_rounded,
        highlightColor: Colors.cyanAccent,
        attributes: [
          ProductAttribute(
            labelId: 'Deskripsi',
            labelEn: 'Description',
            valueId: 'Majiku memiliki alat bantu produksi audio visual lainnya yang terus dikembangkan secara berkala, seperti: t2video, t2speech, t2image, image2video, dan lainnya.',
            valueEn: 'Majiku provides other audio-visual production tools that are continuously developed, such as: t2video, t2speech, t2image, image2video, and others.',
          ),
        ],
      ),

      // 8. DAILY-FREE
      MajikuProduct(
        title: '8. DAILY-FREE',
        icon: Icons.card_giftcard_rounded,
        highlightColor: Colors.purpleAccent,
        attributes: [
          ProductAttribute(
            labelId: 'Deskripsi',
            labelEn: 'Description',
            valueId: 'Fitur harian gratis untuk user, seperti; free t2image, freet2speech, daily_quotes, dan lainnya.',
            valueEn: 'Daily free features for users, such as: free t2image, free t2speech, daily quotes, and others.',
          ),
        ],
      ),
    ];
  }
//........//

//No ke-3 : BUILD UTAMA & PENGATURAN UI//
//Merender halaman Scaffold dan daftar kartu produk dengan scroll halus//
//.......................................................//
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Memantau state bahasa aplikasi (Jika bukan 'id', maka default Bahasa Inggris)
    final currentLocale = ref.watch(appLanguageProvider);
    final isIndo = currentLocale.languageCode == 'id';

    final products = _getProducts();

    return Theme(
      data: AppTheme.darkTheme,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _t(isIndo, 'Majiku Products & Features', 'Produk & Fitur Majiku'),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              letterSpacing: 0.5,
            ),
          ),
          backgroundColor: const Color(0xFF121212),
          elevation: 0,
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
          child: ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            itemCount: products.length,
            itemBuilder: (context, index) {
              return _buildProductCard(products[index], isIndo);
            },
          ),
        ),
      ),
    );
  }
//........//

//No ke-4 : WIDGET KARTU PRODUK (GLASSMORPHISM)//
//Membangun desain kartu yang memuat rincian fitur secara dinamis dan teks jelas//
//.......................................................//
  Widget _buildProductCard(MajikuProduct product, bool isIndo) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- HEADER KARTU (Ikon/Gambar & Judul) ---
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: product.highlightColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: product.highlightColor.withOpacity(0.35)),
                  ),
                  child: Center(
                    child: product.imageAsset != null
                        ? Image.asset(
                            product.imageAsset!,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => Icon(
                              product.icon ?? Icons.auto_awesome,
                              color: product.highlightColor,
                              size: 28,
                            ),
                          )
                        : Icon(
                            product.icon ?? Icons.auto_awesome,
                            color: product.highlightColor,
                            size: 28,
                          ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    product.title,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(color: Colors.white12, height: 1, thickness: 1),
            const SizedBox(height: 16),

            // --- DAFTAR ATRIBUT TEKS (Tipografi Jelas & Mudah Dibaca) ---
            ...product.attributes.map((attr) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      height: 1.5,
                      fontSize: 15.5,
                      letterSpacing: 0.2,
                    ),
                    children: [
                      TextSpan(
                        text: '• ${_t(isIndo, attr.labelEn, attr.labelId)}: ',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: product.highlightColor,
                        ),
                      ),
                      TextSpan(
                        text: _t(isIndo, attr.valueEn, attr.valueId),
                        style: TextStyle(
                          fontWeight: FontWeight.normal,
                          color: Colors.white.withOpacity(0.88),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}
//........//