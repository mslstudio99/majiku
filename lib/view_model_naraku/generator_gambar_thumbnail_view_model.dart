// [RILIS UTUH - INTEGRASI STABLE DIFFUSION 3.5 LARGE]
// KATEGORI_NARAKU_TOKEN NO_URUT_20
// TUJUAN: Mengganti Imagen dengan SD 3.5 Engine (Cloud Run) secara transparan.

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'dart:html' if (dart.library.io) '../utils/html_stub.dart' as html;

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../view_model/auth_view_model.dart'; 

// --- HELPER LOKALISASI (TETAP SAMA) ---
class GambarThumbnailLocalizationHelper {
  static const Map<String, Map<String, String>> translations = {
    'id': {
      'generatorTitle': "Generator Gambar Thumbnail",
      'promptLabel': "Masukkan Narasi Panjang Anda:",
      'promptPlaceholder': "Contoh: Seekor naga emas terbang di atas kerajaan...",
      'labelStyle': "Gaya Visual:",
      'labelRatio': "Rasio Gambar:",
      'btnGenerate': "Buat Gambar SD 3.5",
      'outputTitle': "Hasil Gambar Majiku Engine",
      'outputPlaceholder': "Gambar sedang dilukis oleh SD 3.5 Large...",
      'btnDownload': "Simpan ke Galeri",
      'btnClear': "Hapus Hasil",
      'alertNoInput': "Silakan masukkan narasi terlebih dahulu.",
      'statusGenerating': "Mesin Berputar...",
      'statusLoading': "SD 3.5 sedang menggambar, mohon tunggu sekitar 30 detik...",
      'statusDownloadSuccess': "Gambar disimpan di: {path}",
      'statusDownloadFailed': "Gagal mengunduh gambar.",
      'alertApiError': "Terjadi kesalahan mesin: {message}",
    },
    'en': {
      'generatorTitle': "Thumbnail Image Generator",
      'promptLabel': "Enter Your Narrative:",
      'promptPlaceholder': "Example: A golden dragon flies over a kingdom...",
      'labelStyle': "Visual Style:",
      'labelRatio': "Image Ratio:",
      'btnGenerate': "Create SD 3.5 Image",
      'outputTitle': "Majiku Engine Result",
      'outputPlaceholder': "SD 3.5 Large is painting your image...",
      'btnDownload': "Download Image",
      'btnClear': "Clear Results",
      'alertNoInput': "Please enter a narrative first.",
      'statusGenerating': "Engine Spinning...",
      'statusLoading': "SD 3.5 is painting, please wait ~30 seconds...",
      'statusDownloadSuccess': "Image saved to: {path}",
      'statusDownloadFailed': "Failed to download image.",
      'alertApiError': "Engine Error: {message}",
    }
  };

  static String get(String key, {String? localeCode}) {
    final lang = localeCode ?? PlatformDispatcher.instance.locale.languageCode;
    final langKey = lang == 'id' ? 'id' : 'en';
    final translationMap = translations[langKey] ?? translations['id']!;
    return translationMap[key] ?? key;
  }
}

// --- STATE CLASS ---
@immutable
class GeneratorGambarThumbnailState {
  final bool isLoading;
  final String generatedImageUrl; // Sekarang bisa berisi URL atau Base64
  final String? errorMessage;
  final String? successMessage;
  final String loadingText;
  final String selectedStyle;
  final String selectedRatio;

  const GeneratorGambarThumbnailState({
    this.isLoading = false,
    this.generatedImageUrl = '',
    this.errorMessage,
    this.successMessage,
    this.loadingText = '',
    this.selectedStyle = "Hyperrealistic Style",
    this.selectedRatio = "16:9",
  });

  GeneratorGambarThumbnailState copyWith({
    bool? isLoading,
    String? generatedImageUrl,
    String? errorMessage,
    String? successMessage,
    String? loadingText,
    bool clearError = false,
    bool clearSuccess = false,
    String? selectedStyle,
    String? selectedRatio,
  }) {
    return GeneratorGambarThumbnailState(
      isLoading: isLoading ?? this.isLoading,
      generatedImageUrl: generatedImageUrl ?? this.generatedImageUrl,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      successMessage: clearSuccess ? null : successMessage ?? this.successMessage,
      loadingText: loadingText ?? this.loadingText,
      selectedStyle: selectedStyle ?? this.selectedStyle,
      selectedRatio: selectedRatio ?? this.selectedRatio,
    );
  }
}

// --- VIEW MODEL ---
class GeneratorGambarThumbnailViewModel
    extends StateNotifier<GeneratorGambarThumbnailState> {
  final TextEditingController narrativeController = TextEditingController();
  final Ref _ref;

  GeneratorGambarThumbnailViewModel(this._ref)
      : super(const GeneratorGambarThumbnailState());

  // URL ENGINE BARU (SD 3.5 LARGE)
  final String _engineUrl = "https://majiku-sd35-engine-595802795623.asia-southeast1.run.app/generate";
  final String _engineApiKey = "031284";

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

    if (narrative.isEmpty) {
      state = state.copyWith(
          errorMessage: GambarThumbnailLocalizationHelper.get('alertNoInput'),
          clearError: false);
      return;
    }

    state = state.copyWith(
        isLoading: true, clearError: true, clearSuccess: true, loadingText: 'GENERATING');

    try {
      // Prompt engineering sederhana: menggabungkan narasi dan gaya pilihan user
      final combinedPrompt = "$narrative, ${state.selectedStyle}, 8k resolution, cinematic lighting";

      final body = jsonEncode({
        'prompt': combinedPrompt,
        'aspectRatio': state.selectedRatio,
      });

      final response = await http
          .post(
            Uri.parse(_engineUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_engineApiKey',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 300)); // SD 3.5 butuh waktu lebih lama

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        
        // Mengambil data Base64 dari response engine
        final base64String = responseBody['predictions'][0]['bytesBase64Encoded'];

        if (base64String != null) {
          state = state.copyWith(
            isLoading: false,
            generatedImageUrl: base64String, // Kita simpan Base64 di sini
            loadingText: '',
          );
        } else {
          throw Exception("Gagal mendapatkan data gambar dari mesin.");
        }
      } else {
        throw Exception("Mesin SD 3.5 Error (${response.statusCode}): ${response.body}");
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: GambarThumbnailLocalizationHelper.get('alertApiError')
            .replaceFirst('{message}', e.toString()),
        loadingText: '',
      );
    }
  }

  Future<void> downloadImage() async {
    if (state.generatedImageUrl.isEmpty) return;

    try {
      Uint8List bytes;
      
      // LOGIKA HYBRID: Cek apakah data ini Base64 (Engine Baru) atau URL (Legacy)
      if (!state.generatedImageUrl.startsWith('http')) {
        // Ini adalah Base64 dari SD 3.5
        bytes = base64Decode(state.generatedImageUrl);
      } else {
        // Ini adalah URL lama (jika ada sisa-sisa Imagen)
        final response = await http.get(Uri.parse(state.generatedImageUrl));
        if (response.statusCode != 200) throw Exception('Gagal ambil URL');
        bytes = response.bodyBytes;
      }

      final String fileName = 'majiku_sd35_${DateTime.now().millisecondsSinceEpoch}.png';

      if (kIsWeb) {
        final blob = html.Blob([bytes], 'image/png');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchorElement = html.AnchorElement(href: url);
        anchorElement.download = fileName;
        anchorElement.click();
        html.Url.revokeObjectUrl(url);
        
        state = state.copyWith(
          successMessage: GambarThumbnailLocalizationHelper.get('statusDownloadSuccess')
              .replaceFirst('{path}', 'Downloads folder'),
          clearError: true
        );
      } else if (Platform.isAndroid) {
        final directory = await getApplicationDocumentsDirectory();
        final String filePath = '${directory.path}/$fileName';
        final File file = File(filePath);
        await file.writeAsBytes(bytes);

        state = state.copyWith(
          successMessage: GambarThumbnailLocalizationHelper.get('statusDownloadSuccess')
              .replaceFirst('{path}', filePath),
          clearError: true
        );
      }
    } catch (e) {
      state = state.copyWith(
          errorMessage: GambarThumbnailLocalizationHelper.get('statusDownloadFailed') + " ${e.toString()}",
          clearError: false);
    }
  }

  void clearAll() {
    narrativeController.clear();
    state = state.copyWith(
      generatedImageUrl: '',
      clearError: true,
      clearSuccess: true,
      selectedStyle: "Hyperrealistic Style",
      selectedRatio: "16:9",
    );
  }

  @override
  void dispose() {
    narrativeController.dispose();
    super.dispose();
  }
}

final generatorGambarThumbnailViewModelProvider = StateNotifierProvider.autoDispose<
    GeneratorGambarThumbnailViewModel, GeneratorGambarThumbnailState>(
  (ref) => GeneratorGambarThumbnailViewModel(ref),
);