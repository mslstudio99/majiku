// [RILIS UTUH - INTEGRASI AUTH + PERBAIKAN DOWNLOAD]
// KATEGORI_NARAKU_TOKEN NO_URUT_18
// Lokasi: lib/view_model_naraku/generator_gambar_thumbnail_view_model.dart
// TUJUAN:
// - [FITUR] Mengirimkan Firebase Auth ID Token (JWT) di header.
// - [REFAKTOR] Menyuntikkan 'Ref' ke ViewModel.
// - [PERBAIKAN] Logika downloadImage() diubah untuk memaksa download (cross-origin).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui';
import 'dart:html' as html;

// [IMPOR BARU UNTUK OTENTIKASI]
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../view_model/auth_view_model.dart'; // Untuk authStateChangesProvider

// [IMPOR BARU UNTUK DOWNLOAD BLOB]
import 'dart:typed_data'; // Diperlukan untuk Uint8List

// --- KATEGORI_INTEGRASI_THUMBNAIL NO_URUT_01: Data Localization ---
// (Tidak Berubah)
class GambarThumbnailLocalizationHelper {
  static const Map<String, Map<String, String>> translations = {
    'id': {
      'generatorTitle': "Generator Gambar Thumbnail",
      'promptLabel': "Masukkan Narasi Panjang Anda:",
      'promptPlaceholder':
          "Contoh: Seekor naga emas terbang di atas kerajaan yang terapung di awan...",
      'labelStyle': "Gaya Visual:",
      'styleRealistic': "Realistic",
      'styleCartoon3d': "Kartun 3D",
      'styleCartoon2d': "Kartun 2D",
      'labelRatio': "Rasio Gambar:",
      'btnGenerate': "Buat Gambar Thumbnail",
      'outputTitle': "Hasil Gambar Thumbnail",
      'outputPlaceholder': "Gambar yang digenerasi akan muncul disini...",
      'btnDownload': "Download Gambar",
      'btnClear': "Hapus Hasil",
      'alertNoInput': "Silakan masukkan narasi terlebih dahulu.",
      'statusGenerating': "Memproses...",
      'statusLoading': "Sedang membuat gambar, mohon tunggu...",
      'statusDownloadSuccess': "Download dimulai!",
      'statusDownloadFailed': "Gagal mengunduh gambar.",
      'alertApiError': "Terjadi kesalahan: {message}",
    },
    'en': {
      'generatorTitle': "Thumbnail Image Generator",
      'promptLabel': "Enter Your Long Narrative:",
      'promptPlaceholder':
          "Example: A golden dragon flies over a kingdom floating in the clouds...",
      'labelStyle': "Visual Style:",
      'styleRealistic': "Realistic",
      'styleCartoon3d': "3D Cartoon",
      'styleCartoon2d': "2D Cartoon",
      'labelRatio': "Image Ratio:",
      'btnGenerate': "Create Thumbnail Image",
      'outputTitle': "Generated Thumbnail Image",
      'outputPlaceholder': "Generated image will appear here...",
      'btnDownload': "Download Image",
      'btnClear': "Clear Results",
      'alertNoInput': "Please enter a narrative first.",
      'statusGenerating': "Processing...",
      'statusLoading': "Generating image, please wait...",
      'statusDownloadSuccess': "Download started!",
      'statusDownloadFailed': "Failed to download image.",
      'alertApiError': "An error occurred: {message}",
    }
  };

  static String get(String key, {String? localeCode}) {
    final lang = localeCode ?? PlatformDispatcher.instance.locale.languageCode;
    final langKey = lang == 'id' ? 'id' : 'en';
    final translationMap = translations[langKey] ?? translations['id']!;
    return translationMap[key] ?? key;
  }
}
// --- AKHIR DATA LOKALISASI ---

/// KATEGORI_INTEGRASI_THUMBNAIL NO_URUT_02
// (State Class Tidak Berubah)
@immutable
class GeneratorGambarThumbnailState {
  final bool isLoading;
  final String generatedImageUrl;
  final String? errorMessage;
  final String loadingText;
  final String selectedStyle;
  final String selectedRatio;

  const GeneratorGambarThumbnailState({
    this.isLoading = false,
    this.generatedImageUrl = '',
    this.errorMessage,
    this.loadingText = '',
    this.selectedStyle = "Hyperrealistic Style",
    this.selectedRatio = "16:9",
  });

  GeneratorGambarThumbnailState copyWith({
    bool? isLoading,
    String? generatedImageUrl,
    String? errorMessage,
    String? loadingText,
    bool clearError = false,
    String? selectedStyle,
    String? selectedRatio,
  }) {
    return GeneratorGambarThumbnailState(
      isLoading: isLoading ?? this.isLoading,
      generatedImageUrl: generatedImageUrl ?? this.generatedImageUrl,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      loadingText: loadingText ?? this.loadingText,
      selectedStyle: selectedStyle ?? this.selectedStyle,
      selectedRatio: selectedRatio ?? this.selectedRatio,
    );
  }
}

/// KATEGORI_INTEGRASI_THUMBNAIL NO_URUT_03 (DIMODIFIKASI)
class GeneratorGambarThumbnailViewModel
    extends StateNotifier<GeneratorGambarThumbnailState> {
  final TextEditingController narrativeController = TextEditingController();

  // [BARU] Tambahkan Ref untuk mengakses provider lain
  final Ref _ref;

  // [MODIFIKASI] Terima Ref di constructor
  GeneratorGambarThumbnailViewModel(this._ref)
      : super(const GeneratorGambarThumbnailState());

  // (URL Cloud Function Tidak Berubah)
  final String _cloudFunctionUrl =
      "https://asia-southeast2-majiku-5b07e.cloudfunctions.net/generatorGambarThumbnail";

  // (Metode setStyle & setRatio Tidak Berubah)
  void setStyle(String? value) {
    if (value == null) return;
    state = state.copyWith(selectedStyle: value);
  }

  void setRatio(String? value) {
    if (value == null) return;
    state = state.copyWith(selectedRatio: value);
  }

  Future<void> generateStory() async {
    if (state.isLoading) return;
    final narrative = narrativeController.text.trim();

    // (Validasi Tidak Berubah)
    if (narrative.isEmpty) {
      state = state.copyWith(
          errorMessage:
              GambarThumbnailLocalizationHelper.get('alertNoInput'),
          clearError: false);
      return;
    }

    state = state.copyWith(
        isLoading: true, clearError: true, loadingText: 'GENERATING');

    try {
      // --- [LOGIKA TOKEN BARU - LANGKAH 2A] ---
      final authUser = _ref.read(authStateChangesProvider).value;
      if (authUser == null) {
        throw Exception("Sesi pengguna tidak ditemukan. Harap login ulang.");
      }
      final idToken = await authUser.getIdToken(true);
      // --- [AKHIR LOGIKA TOKEN BARU] ---

      // (Payload Body Tidak Berubah)
      final body = jsonEncode({
        'data': {
          'narrativeValue': narrative,
          'selectedStyle': state.selectedStyle,
          'selectedRatio': state.selectedRatio,
        }
      });

      final response = await http
          .post(
            Uri.parse(_cloudFunctionUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken', // [MODIFIKASI]
            },
            body: body,
          )
          .timeout(const Duration(seconds: 300));

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        final resultUrl = responseBody['data'];

        if (resultUrl != null && (resultUrl as String).startsWith("http")) {
          state = state.copyWith(
            isLoading: false,
            generatedImageUrl: resultUrl,
            loadingText: '',
          );
        } else {
          throw Exception(
              "Respons sukses, namun 'data' (URL) tidak ditemukan di body.");
        }
      } else {
        final errorBody = jsonDecode(response.body);
        final errorMessage = errorBody['error']?['message'] ??
            'Error HTTP ${response.statusCode}';
        if (response.statusCode == 402) {
          throw Exception(errorMessage);
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: GambarThumbnailLocalizationHelper.get('alertApiError')
            .replaceFirst(
                '{message}', e.toString().replaceFirst('Exception: ', '')),
        loadingText: '',
      );
    }
  }

  // [KATEGORI_REFAKTOR_FITUR NO_URUT_03] Fungsi Download diperbarui (FIXED)
  Future<void> downloadImage() async {
    if (state.generatedImageUrl.isEmpty) return;

    try {
      // 1. Unduh data gambar menggunakan http.get
      final response = await http.get(Uri.parse(state.generatedImageUrl));

      if (response.statusCode != 200) {
        throw Exception(
            'Gagal mengunduh data gambar. Status: ${response.statusCode}');
      }

      // 2. Dapatkan data mentah (raw bytes)
      final Uint8List bytes = response.bodyBytes;

      // 3. Buat Blob (file di memori) dari data
      final blob = html.Blob([bytes], 'image/png'); // Asumsi PNG

      // 4. Buat URL lokal untuk Blob tersebut
      final url = html.Url.createObjectUrlFromBlob(blob);

      // 5. Buat anchor tag <a> baru yang menunjuk ke URL LOKAL
      final html.AnchorElement anchorElement = html.AnchorElement(href: url);

      // 6. Atur nama file download
      anchorElement.download = 'majiku_thumbnail.png'; // Nama file statis

      // 7. Klik link secara virtual untuk memicu download
      anchorElement.click();

      // 8. Hapus URL lokal dari memori setelah selesai
      html.Url.revokeObjectUrl(url);
    } catch (e) {
      state = state.copyWith(
          errorMessage:
              GambarThumbnailLocalizationHelper.get('statusDownloadFailed'),
          clearError: false);
    }
  }

  // (Metode clearAll Tidak Berubah)
  void clearAll() {
    narrativeController.clear();
    state = state.copyWith(
      generatedImageUrl: '',
      clearError: true,
      selectedStyle: "Hyperrealistic Style",
      selectedRatio: "16:9",
    );
  }

  // (Metode dispose Tidak Berubah)
  @override
  void dispose() {
    narrativeController.dispose();
    super.dispose();
  }
}

/// KATEGORI_INTEGRASI_THUMBNAIL NO_URUT_04 (DIMODIFIKASI)
final generatorGambarThumbnailViewModelProvider = StateNotifierProvider
    .autoDispose<GeneratorGambarThumbnailViewModel,
        GeneratorGambarThumbnailState>(
  (ref) {
    // [MODIFIKASI] Suntikkan 'ref' ke ViewModel
    return GeneratorGambarThumbnailViewModel(ref);
  },
);