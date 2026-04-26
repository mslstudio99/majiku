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

// --- [STRUKTUR DATA] Model Produk Utama (DIMODIFIKASI UNTUK GAMBAR ASSET) ---
class MajikuProduct {
  final String title;
  final IconData? icon; // Dibuat nullable agar bisa diganti gambar
  final String? imageAsset; // Menampung path gambar PNG dari dashboard
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
//Berisi daftar lengkap 10 produk Majiku beserta terjemahannya//
//.......................................................//
class MajikuProductScreen extends ConsumerWidget {
  const MajikuProductScreen({super.key});

  // --- Helper Penerjemah Sederhana ---
  String _t(bool isIndo, String en, String id) => isIndo ? id : en;

  // --- Sumber Data Produk Majiku ---
  List<MajikuProduct> _getProducts() {
    return [
      MajikuProduct(
        title: '1. AUTO NARRATIVE',
        imageAsset: 'assets/tombol-dashboard/narrative.png',
        highlightColor: Colors.amber,
        attributes: [
          ProductAttribute(
            labelId: 'Deskripsi', labelEn: 'Description',
            valueId: 'Fitur pembuatan narasi konten otomatis.', 
            valueEn: 'Automatic content narrative generation feature.'
          ),
          ProductAttribute(
            labelId: 'Cara Pakai', labelEn: 'How to Use',
            valueId: 'Cukup masukkan judul atau kata kunci maka Majiku akan membuatkanmu narasi lengkap siap pakai untuk berbagai kebutuhan naskah konten, misal: short, storytelling, umum, islami, sejarah, legenda, pengalaman horror, dongeng custom dan sebagainya.', 
            valueEn: 'Simply enter a title or keyword, and Majiku will create a complete ready-to-use narrative for various content script needs, e.g., shorts, storytelling, general, Islamic, history, legends, horror experiences, custom fairy tales, etc.'
          ),
          ProductAttribute(
            labelId: 'Integrasi', labelEn: 'Integration',
            valueId: 'Kamu bisa copy atau langsung send ke fitur pembuatan video otomatis seperti auto naramotion, naracinema, auto movie dan sebagainya.', 
            valueEn: 'You can copy or directly send it to automatic video generation features like auto naramotion, naracinema, auto movie, and so on.'
          ),
        ],
      ),
      MajikuProduct(
        title: '2. TEXT TO IMAGE',
        imageAsset: 'assets/tombol-dashboard/t2image.png',
        highlightColor: Colors.blueAccent,
        attributes: [
          ProductAttribute(
            labelId: 'Deskripsi', labelEn: 'Description',
            valueId: 'Fitur pembuatan gambar berkualitas AI.', 
            valueEn: 'AI-quality image generation feature.'
          ),
          ProductAttribute(
            labelId: 'Cara Pakai', labelEn: 'How to Use',
            valueId: 'Cukup masukkan teks prompt atau narasi paragraph.', 
            valueEn: 'Simply enter a text prompt or narrative paragraph.'
          ),
        ],
      ),
      MajikuProduct(
        title: '3. TEXT TO VIDEO',
        imageAsset: 'assets/tombol-dashboard/t2video.png',
        highlightColor: Colors.purpleAccent,
        attributes: [
          ProductAttribute(
            labelId: 'Deskripsi', labelEn: 'Description',
            valueId: 'Fitur pembuatan VIDEO AI berkualitas.', 
            valueEn: 'Quality AI VIDEO generation feature.'
          ),
          ProductAttribute(
            labelId: 'Cara Pakai', labelEn: 'How to Use',
            valueId: 'Cukup masukkan teks prompt atau narasi paragraph.', 
            valueEn: 'Simply enter a text prompt or narrative paragraph.'
          ),
          ProductAttribute(
            labelId: 'Durasi', labelEn: 'Duration',
            valueId: 'OUTPUT VIDEO hingga 12 detik.', 
            valueEn: 'VIDEO OUTPUT up to 12 seconds.'
          ),
        ],
      ),
      MajikuProduct(
        title: '4. TEXT TO VIDEO PLUS',
        imageAsset: 'assets/tombol-dashboard/t2videoplus.png',
        highlightColor: Colors.deepPurpleAccent,
        attributes: [
          ProductAttribute(
            labelId: 'Deskripsi', labelEn: 'Description',
            valueId: 'Fitur pembuatan VIDEO AI berkualitas lebih tinggi.', 
            valueEn: 'Higher quality AI VIDEO generation feature.'
          ),
          ProductAttribute(
            labelId: 'Cara Pakai', labelEn: 'How to Use',
            valueId: 'Cukup masukkan teks prompt atau narasi paragraph.', 
            valueEn: 'Simply enter a text prompt or narrative paragraph.'
          ),
          ProductAttribute(
            labelId: 'Durasi', labelEn: 'Duration',
            valueId: 'OUTPUT VIDEO hingga 12 detik.', 
            valueEn: 'VIDEO OUTPUT up to 12 seconds.'
          ),
        ],
      ),
      MajikuProduct(
        title: '5. IMAGE TO VIDEO',
        imageAsset: 'assets/tombol-dashboard/i2video.png',
        highlightColor: Colors.cyanAccent,
        attributes: [
          ProductAttribute(
            labelId: 'Deskripsi', labelEn: 'Description',
            valueId: 'Fitur pembuatan VIDEO AI berkualitas.', 
            valueEn: 'Quality AI VIDEO generation feature.'
          ),
          ProductAttribute(
            labelId: 'Cara Pakai', labelEn: 'How to Use',
            valueId: 'Cukup masukkan gambar atau foto dan teks prompt atau narasi paragraph (opsional).', 
            valueEn: 'Simply enter an image or photo and a text prompt or narrative paragraph (optional).'
          ),
          ProductAttribute(
            labelId: 'Durasi', labelEn: 'Duration',
            valueId: 'OUTPUT VIDEO hingga 12 detik.', 
            valueEn: 'VIDEO OUTPUT up to 12 seconds.'
          ),
        ],
      ),
      MajikuProduct(
        title: '6. AUTO NARA MOTION',
        imageAsset: 'assets/tombol-dashboard/vstorimotion.png',
        highlightColor: Colors.orangeAccent,
        attributes: [
          ProductAttribute(
            labelId: 'Deskripsi', labelEn: 'Description',
            valueId: 'Fitur pembuatan video konten, storytelling dan film otomatis berbasis motion (image) dilengkapi dengan audio narasi.', 
            valueEn: 'Automatic video content, storytelling, and movie generation feature based on motion (images) equipped with audio narrative.'
          ),
          ProductAttribute(
            labelId: 'Keunggulan', labelEn: 'Advantage',
            valueId: 'Cukup masukkan narasi paragraph konten atau teks cerita (tidak perlu prompt).', 
            valueEn: 'Simply enter a narrative paragraph or story text (no prompt needed).'
          ),
          ProductAttribute(
            labelId: 'Efisiensi', labelEn: 'Efficiency',
            valueId: 'Sangat ekonomis, mendukung panjang video hingga lebih dari 15 menit.', 
            valueEn: 'Highly economical, supports video lengths of over 15 minutes.'
          ),
        ],
      ),
      MajikuProduct(
        title: '7. AUTO NARA CINEMA',
        imageAsset: 'assets/tombol-dashboard/vstorinema.png',
        highlightColor: Colors.redAccent,
        attributes: [
          ProductAttribute(
            labelId: 'Deskripsi', labelEn: 'Description',
            valueId: 'Fitur pembuatan video konten, storytelling dan film otomatis berbasis video AI dilengkapi dengan audio narasi.', 
            valueEn: 'Automatic video content, storytelling, and movie generation feature based on AI video equipped with audio narrative.'
          ),
          ProductAttribute(
            labelId: 'Keunggulan', labelEn: 'Advantage',
            valueId: 'Cukup masukkan narasi paragraph konten atau teks cerita (tidak perlu prompt).', 
            valueEn: 'Simply enter a narrative paragraph or story text (no prompt needed).'
          ),
          ProductAttribute(
            labelId: 'Efisiensi', labelEn: 'Efficiency',
            valueId: 'Cukup ekonomis, mendukung panjang video hingga lebih dari 15 menit.', 
            valueEn: 'Quite economical, supports video lengths of over 15 minutes.'
          ),
        ],
      ),
      MajikuProduct(
        title: '8. AUTO NARACINEMA-PLUS',
        imageAsset: 'assets/tombol-dashboard/vcinema.png',
        highlightColor: Colors.pinkAccent,
        attributes: [
          ProductAttribute(
            labelId: 'Deskripsi', labelEn: 'Description',
            valueId: 'Fitur pembuatan film/cinema otomatis berbasis video AI dan audio narasi berkualitas.', 
            valueEn: 'Quality AI video-based automatic movie/cinema generation feature equipped with narrative audio.'
          ),
          ProductAttribute(
            labelId: 'Keunggulan', labelEn: 'Advantage',
            valueId: 'Cukup masukkan teks narasi konten atau naskah cerita (tidak perlu prompt).', 
            valueEn: 'Simply enter a narrative or story script (no prompt needed).'
          ),
          ProductAttribute(
            labelId: 'Efisiensi', labelEn: 'Efficiency',
            valueId: 'Cukup ekonomis, mendukung panjang video hingga lebih dari 15 menit.', 
            valueEn: 'Quite economical, supports video lengths of over 15 minutes.'
          ),
        ],
      ),
      MajikuProduct(
        title: '9. AUTO MOVIE',
        imageAsset: 'assets/tombol-dashboard/vmovie.png',
        highlightColor: Colors.tealAccent,
        attributes: [
          ProductAttribute(
            labelId: 'Deskripsi', labelEn: 'Description',
            valueId: 'Fitur pembuatan film otomatis berbasis video AI kualitas tinggi dilengkapi dengan audio sync, dialog karakter dan backsound.', 
            valueEn: 'High-quality AI video-based automatic movie generation feature equipped with audio sync, character dialogue, and background music.'
          ),
          ProductAttribute(
            labelId: 'Keunggulan', labelEn: 'Advantage',
            valueId: 'Cukup masukkan narasi paragraph konten atau teks atau naskah cerita (tidak perlu prompt).', 
            valueEn: 'Simply enter a narrative paragraph or story script (no prompt needed).'
          ),
          ProductAttribute(
            labelId: 'Kapasitas', labelEn: 'Capacity',
            valueId: 'Mendukung panjang video hingga lebih dari 15 menit.', 
            valueEn: 'Supports video lengths of over 15 minutes.'
          ),
        ],
      ),
      MajikuProduct(
        title: '10. OTHERS',
        icon: Icons.stars, // Tetap menggunakan Icon bawaan
        highlightColor: Colors.yellowAccent,
        attributes: [
          ProductAttribute(
            labelId: 'Deskripsi', labelEn: 'Description',
            valueId: 'Masih banyak fitur menarik lainnya yang terus kami kembangkan untuk memenuhi kebutuhan kreator.', 
            valueEn: 'Many other exciting features that we continuously develop to meet creators\' needs.'
          ),
        ],
      ),
    ];
  }
//........//

//No ke-3 : BUILD UTAMA & PENGATURAN UI//
//Merender halaman Scaffold dan Grid/List tampilan modern//
//.......................................................//
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Memantau state bahasa aplikasi secara real-time
    final currentLocale = ref.watch(appLanguageProvider);
    final isIndo = currentLocale.languageCode == 'id';
    
    final products = _getProducts();

    return Theme(
      data: AppTheme.darkTheme, // Paksa tema gelap yang elegan
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _t(isIndo, 'Majiku Products & Features', 'Produk & Fitur Majiku'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
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
              colors: [Color(0xFF121212), Color(0xFF000000)], // Gradasi gelap modern
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
//Membangun desain kartu yang memuat rincian fitur secara dinamis//
//.......................................................//
  Widget _buildProductCard(MajikuProduct product, bool isIndo) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04), // Efek transparan kaca
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
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- HEADER KARTU (Ikon/Gambar & Judul) ---
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: product.highlightColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: product.highlightColor.withOpacity(0.3)),
                  ),
                  child: Center(
                    child: product.imageAsset != null
                        ? Image.asset(product.imageAsset!, fit: BoxFit.contain)
                        : Icon(product.icon, color: product.highlightColor, size: 28),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    product.title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white.withOpacity(0.95),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            const Divider(color: Colors.white10, height: 1, thickness: 1),
            const SizedBox(height: 16),
            
            // --- DAFTAR ATRIBUT (Deskripsi, Cara Pakai, dll) ---
            ...product.attributes.map((attr) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(height: 1.3, fontSize: 16),
                    children: [
                      TextSpan(
                        text: '• ${_t(isIndo, attr.labelEn, attr.labelId)}: ',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: product.highlightColor.withOpacity(0.9), // Warna label sesuai tema ikon
                        ),
                      ),
                      TextSpan(
                        text: _t(isIndo, attr.valueEn, attr.valueId),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.75),
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