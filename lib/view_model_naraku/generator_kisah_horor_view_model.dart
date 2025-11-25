// [RILIS UTUH - INTEGRASI AUTH TOKEN]
// KATEGORI_NARAKU_TOKEN NO_URUT_13
// Lokasi: lib/view_model_naraku/generator_kisah_horor_view_model.dart
// TUJUAN:
// - [FITUR] Mengirimkan Firebase Auth ID Token (JWT) di header
// - panggilan http.post ke Cloud Function 'generatorKisahHoror'.
// - [REFAKTOR] Menyuntikkan 'Ref' ke ViewModel untuk mengakses provider auth.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui';

// --- [IMPOR BARU UNTUK OTENTIKASI] ---
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../view_model/auth_view_model.dart'; // Untuk authStateChangesProvider
// --- [AKHIR IMPOR BARU] ---

// --- KATEGORI_INTEGRASI_KISAH_HOROR NO_URUT_01: Data Localization ---
// (Tidak Berubah)
class KisahHororLocalizationHelper {
  static const Map<String, Map<String, String>> translations = {
    'id': {
      'generatorTitle': "Generator Kisah Horor", // <-- JUDUL DIPERBAIKI
      'promptLabel': "Masukkan Judul atau Kata Kunci Anda:",
      'promptPlaceholder': "Contoh: Kisah horor di rumah tua, motif balas dendam",
      'languageHint':
          "💡 Tips: Anda bisa menentukan bahasa output di akhir, contoh: ', dalam bahasa Inggris'",
      'btnGenerate': "Buat Narasi",
      'btnProcessing': "Memproses...",
      'outputTitle': "Narasi yang Dibuat",
      'outputPlaceholder': "Hasil Generasi Akan Muncul Disini...",
      'btnCopy': "Salin Narasi",
      'btnCopied': "Berhasil Disalin!",
      'btnClear': "Hapus",
      'alertNoInput': "Silakan masukkan judul atau kata kunci terlebih dahulu.",
      'alertApiError': "Terjadi kesalahan: {message}",
      'apiLoading': "Sedang membuat narasi, mohon tunggu",
    },
    'en': {
      'generatorTitle': "Horror Story Generator", // <-- JUDUL DIPERBAIKI
      'promptLabel': "Enter Your Title or Keyword:",
      'promptPlaceholder':
          "Example: Horror story in an old house, revenge motive",
      'languageHint':
          "💡 Tip: You can specify the output language at the end, e.g., ', in English'",
      'btnGenerate': "Create Narrative",
      'btnProcessing': "Processing...",
      'outputTitle': "Generated Narrative",
      'outputPlaceholder': "Generated Results Will Appear Here...",
      'btnCopy': "Copy Narrative",
      'btnCopied': "Copied Successfully!",
      'btnClear': "Clear",
      'alertNoInput': "Please enter a title or keyword first.",
      'alertApiError': "An error occurred: {message}",
      'apiLoading': "Generating narrative, please wait",
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

/// KATEGORI_INTEGRASI_KISAH_HOROR NO_URUT_02
// (State Class Tidak Berubah)
@immutable
class GeneratorKisahHororState {
  final bool isLoading;
  final String generatedStory;
  final String? errorMessage;
  final String loadingText;

  const GeneratorKisahHororState({
    this.isLoading = false,
    this.generatedStory = '',
    this.errorMessage,
    this.loadingText = '',
  });

  GeneratorKisahHororState copyWith({
    bool? isLoading,
    String? generatedStory,
    String? errorMessage,
    String? loadingText,
    bool clearError = false,
  }) {
    return GeneratorKisahHororState(
      isLoading: isLoading ?? this.isLoading,
      generatedStory: generatedStory ?? this.generatedStory,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      loadingText: loadingText ?? this.loadingText,
    );
  }
}

/// KATEGORI_INTEGRASI_KISAH_HOROR NO_URUT_03 (DIMODIFIKASI)
class GeneratorKisahHororViewModel
    extends StateNotifier<GeneratorKisahHororState> {
  final TextEditingController promptController = TextEditingController();

  // [BARU] Tambahkan Ref untuk mengakses provider lain
  final Ref _ref;

  // [MODIFIKASI] Terima Ref di constructor
  GeneratorKisahHororViewModel(this._ref)
      : super(const GeneratorKisahHororState());

  // (URL Cloud Function Tidak Berubah)
  final String _cloudFunctionUrl =
      "https://asia-southeast2-majiku-5b07e.cloudfunctions.net/generatorKisahHoror";

  Future<void> generateStory() async {
    if (state.isLoading) return;
    final prompt = promptController.text.trim();
    if (prompt.isEmpty) {
      state = state.copyWith(
          errorMessage: KisahHororLocalizationHelper.get('alertNoInput'),
          clearError: false);
      return;
    }

    state = state.copyWith(
        isLoading: true, clearError: true, loadingText: 'GENERATING');

    try {
      // --- [LOGIKA TOKEN BARU - LANGKAH 2A] ---
      // 1. Dapatkan user saat ini dari provider auth
      final authUser = _ref.read(authStateChangesProvider).value;

      if (authUser == null) {
        throw Exception("Sesi pengguna tidak ditemukan. Harap login ulang.");
      }

      // 2. Dapatkan ID Token (JWT) pengguna.
      final idToken = await authUser.getIdToken(true);
      // --- [AKHIR LOGIKA TOKEN BARU] ---

      // [PERBAIKAN PAYLOAD] Sesuai JS/PHP, menggunakan 'userInput'
      final body = jsonEncode({
        'data': {
          'userInput': prompt,
        }
      });

      final response = await http.post(
        Uri.parse(_cloudFunctionUrl),
        headers: {
          'Content-Type': 'application/json',
          // [MODIFIKASI] Kirim token otentikasi
          'Authorization': 'Bearer $idToken',
        },
        body: body,
      ).timeout(const Duration(seconds: 300)); // 5 menit timeout

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        final resultText = responseBody['data'];

        if (resultText != null) {
          state = state.copyWith(
            isLoading: false,
            generatedStory: resultText as String,
            loadingText: '',
          );
        } else {
          throw Exception(
              "Respons sukses, namun 'data' tidak ditemukan di body.");
        }
      } else {
        final errorBody = jsonDecode(response.body);
        final errorMessage =
            errorBody['error']?['message'] ?? 'Error HTTP ${response.statusCode}';
        // [PERBAIKAN] Jika token tidak cukup (402), tampilkan pesan
        if (response.statusCode == 402) {
          throw Exception(errorMessage); // Tampilkan pesan dari server (misal: "Token Tidak Cukup")
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: KisahHororLocalizationHelper.get('alertApiError')
            .replaceFirst(
                '{message}', e.toString().replaceFirst('Exception: ', '')),
        loadingText: '',
      );
    }
  }

  // (Metode clearAll Tidak Berubah)
  void clearAll() {
    promptController.clear();
    state = state.copyWith(generatedStory: '', clearError: true);
  }

  // (Metode dispose Tidak Berubah)
  @override
  void dispose() {
    promptController.dispose();
    super.dispose();
  }
}

/// KATEGORI_INTEGRASI_KISAH_HOROR NO_URUT_04 (DIMODIFIKASI)
final generatorKisahHororViewModelProvider = StateNotifierProvider.autoDispose<
    GeneratorKisahHororViewModel, GeneratorKisahHororState>(
  (ref) {
    // [MODIFIKASI] Suntikkan 'ref' ke ViewModel
    return GeneratorKisahHororViewModel(ref);
  },
);