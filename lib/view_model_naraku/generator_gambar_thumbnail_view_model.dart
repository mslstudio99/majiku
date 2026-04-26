//================================================================//
// NAMA FILE: GENERATOR_GAMBAR_THUMBNAIL_VIEW_MODEL.DART          //
// DIREKTORI: lib/view_model_naraku/generator_gambar_thumbnail_view_model.dart //
//================================================================//

//No ke-1.........................................................//
//IMPORT MODULE & DEPENDENCIES                                    //
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'dart:html' if (dart.library.io) '../utils/html_stub.dart' as html;
//................................................................//

//No ke-2.........................................................//
//HELPER LOKALISASI (SINKRONISASI TEKS IMAGEN 4.0)                //
class GambarThumbnailLocalizationHelper {
  static const Map<String, Map<String, String>> translations = {
    'id': {
      'generatorTitle': "Generator Gambar Thumbnail",
      'promptLabel': "Masukkan Narasi Panjang Anda:",
      'promptPlaceholder': "Contoh: Seekor naga emas terbang di atas kerajaan...",
      'labelStyle': "Gaya Visual:",
      'labelRatio': "Rasio Gambar:",
      'btnGenerate': "Buat Gambar Majiku AI",
      'outputTitle': "Hasil Gambar Majiku Engine",
      'outputPlaceholder': "Gambar sedang dilukis oleh Imagen 4.0 Fast...",
      'btnDownload': "Simpan ke Galeri",
      'btnClear': "Hapus Hasil",
      'alertNoInput': "Silakan masukkan narasi terlebih dahulu.",
      'statusGenerating': "Mesin Berputar...",
      'statusLoading': "AI sedang menggambar, mohon tunggu sekitar 30 detik...",
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
      'btnGenerate': "Create Majiku AI Image",
      'outputTitle': "Majiku Engine Result",
      'outputPlaceholder': "Imagen 4.0 Fast is painting your image...",
      'btnDownload': "Download Image",
      'btnClear': "Clear Results",
      'alertNoInput': "Please enter a narrative first.",
      'statusGenerating': "Engine Spinning...",
      'statusLoading': "AI is painting, please wait ~30 seconds...",
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
//................................................................//

//No ke-3.........................................................//
//STATE CLASS                                                     //
@immutable
class GeneratorGambarThumbnailState {
  final bool isLoading;
  final String generatedImageUrl; // URL Publik dari Firebase Storage
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
//................................................................//

//No ke-4.........................................................//
//VIEW MODEL LOGIC (FIREBASE FUNCTIONS CALL & TOKEN HANDLING)     //
class GeneratorGambarThumbnailViewModel
    extends StateNotifier<GeneratorGambarThumbnailState> {
  final TextEditingController narrativeController = TextEditingController();
  final Ref _ref;

  GeneratorGambarThumbnailViewModel(this._ref)
      : super(const GeneratorGambarThumbnailState());

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
      // SINKRONISASI BACKEND: Memanggil fungsi 'generatorGambarThumbnail' Firebase Cloud Functions
      // Payload Disesuaikan dengan Index.ts (narrativeValue, selectedStyle, selectedRatio)
      final callable = FirebaseFunctions.instanceFor(region: 'asia-southeast2')
          .httpsCallable('generatorGambarThumbnail');

      final payload = {
        'narrativeValue': narrative,
        'selectedStyle': state.selectedStyle,
        'selectedRatio': state.selectedRatio,
      };

      // PERBAIKAN 1: Hapus bungkus manual {'data': payload}. Firebase httpsCallable sudah membungkusnya secara otomatis di balik layar.
      final result = await callable.call(payload);

      // PERBAIKAN 2: Tangkap respons. Backend mengembalikan tipe String (URL) secara langsung, bukan Map.
      final String? imageUrl = result.data as String?;

      if (imageUrl != null && imageUrl.isNotEmpty) {
        state = state.copyWith(
          isLoading: false,
          generatedImageUrl: imageUrl,
          loadingText: '',
        );
      } else {
        throw Exception("Gagal mendapatkan URL gambar dari mesin.");
      }
    } on FirebaseFunctionsException catch (e) {
      // Penanganan khusus error Token Habis (Sesuai backend: 402 / insufficient_tokens)
      String errorMsg = e.message ?? "Terjadi kesalahan server.";
      if (e.code == 'insufficient_tokens' || e.code == 'payment-required') {
        errorMsg = "Token Anda tidak mencukupi untuk melakukan tindakan ini.";
      }
      state = state.copyWith(
        isLoading: false,
        errorMessage: errorMsg,
        loadingText: '',
      );
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
      // Karena respons sekarang murni URL, kita gunakan http.get untuk mengunduh byte gambar
      final response = await http.get(Uri.parse(state.generatedImageUrl));
      if (response.statusCode != 200) {
        throw Exception('Gagal mengunduh gambar dari server.');
      }
      final Uint8List bytes = response.bodyBytes;

      final String fileName = 'majiku_thumbnail_${DateTime.now().millisecondsSinceEpoch}.png';

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
//................................................................//