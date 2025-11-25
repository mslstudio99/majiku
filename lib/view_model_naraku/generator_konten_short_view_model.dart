// [RILIS UTUH - INTEGRASI AUTH TOKEN & OPSI PANJANG NARASI]
// KATEGORI_NARAKU_TOKEN NO_URUT_04 (REVISI 2.0)
// Lokasi: lib/view_model_naraku/generator_konten_short_view_model.dart
// TUJUAN:
// - [FITUR] Mengirimkan Firebase Auth ID Token (JWT).
// - [FITUR] Mendukung opsi panjang narasi (lengthOption).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui';

// --- [IMPOR BARU UNTUK OTENTIKASI] ---
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../view_model/auth_view_model.dart'; // Untuk authStateChangesProvider
// --- [AKHIR IMPOR BARU] ---

// --- KATEGORI_INTEGRASI_KONTEN_SHORT NO_URUT_01: Data Localization Digabung ---
// (Tidak Berubah)
class NarakuLocalizationHelper {
  static const Map<String, Map<String, String>> translations = {
    'id': {
      'generatorTitle': "Generator Konten Short",
      'promptLabel': "Masukkan Judul atau Kata Kunci Anda:",
      'promptPlaceholder': "contoh : Fakta Unik Gajah",
      'languageHint':
          "💡 Tips: Anda bisa menentukan bahasa output di akhir, contoh: ', dalam bahasa Inggris'",
      'btnGenerate': "Buat Narasi",
      'outputTitle': "Narasi yang Dibuat",
      'outputPlaceholder': "Hasil Generasi Akan Muncul Disini...",
      'btnCopy': "Salin Narasi",
      'btnClear': "Hapus",
      'alertNoInput':
          "Silakan masukkan judul atau kata kunci terlebih dahulu.",
      'statusGenerating': "Memproses...",
      'statusLoading': "Sedang membuat narasi, mohon tunggu",
      'statusCopySuccess': "Berhasil Disalin!",
      'alertApiError': "Terjadi kesalahan: {message}",
    },
    'en': {
      'generatorTitle': "Short Content Generator",
      'promptLabel': "Enter Your Title or Keyword:",
      'promptPlaceholder': "Example: Unique Elephant Facts",
      'languageHint':
          "💡 Tip: You can specify the output language at the end, e.g., ', in English'",
      'btnGenerate': "Create Narrative",
      'outputTitle': "Generated Narrative",
      'outputPlaceholder': "Generated Results Will Appear Here...",
      'btnCopy': "Copy Narrative",
      'btnClear': "Clear",
      'alertNoInput': "Please enter a title or keyword first.",
      'statusGenerating': "Processing...",
      'statusLoading': "Generating narrative, please wait",
      'statusCopySuccess': "Copied Successfully!",
      'alertApiError': "An error occurred: {message}",
    },
  };

  static String get(String key, {String? localeCode}) {
    final lang = localeCode ?? PlatformDispatcher.instance.locale.languageCode;
    final langKey = lang == 'id' ? 'id' : 'en';
    final translationMap = translations[langKey] ?? translations['id']!;
    return translationMap[key] ?? key;
  }
}
// --- AKHIR DATA LOKALISASI DIGABUNG ---

/// KATEGORI_INTEGRASI_KONTEN_SHORT NO_URUT_02
@immutable
class GeneratorKontenShortState {
  final bool isLoading;
  final String generatedNarrative;
  final String? errorMessage;
  final String loadingText;
  // [BARU] Opsi Panjang Narasi (Default 1000)
  final int lengthOption;

  const GeneratorKontenShortState({
    this.isLoading = false,
    this.generatedNarrative = '',
    this.errorMessage,
    this.loadingText = '',
    this.lengthOption = 1000, // Default 1000
  });

  GeneratorKontenShortState copyWith({
    bool? isLoading,
    String? generatedNarrative,
    String? errorMessage,
    String? loadingText,
    int? lengthOption,
    bool clearError = false,
  }) {
    return GeneratorKontenShortState(
      isLoading: isLoading ?? this.isLoading,
      generatedNarrative: generatedNarrative ?? this.generatedNarrative,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      loadingText: loadingText ?? this.loadingText,
      lengthOption: lengthOption ?? this.lengthOption,
    );
  }
}

/// KATEGORI_INTEGRASI_KONTEN_SHORT NO_URUT_03 (DIMODIFIKASI)
class GeneratorKontenShortViewModel
    extends StateNotifier<GeneratorKontenShortState> {
  final TextEditingController promptController = TextEditingController();

  // [BARU] Tambahkan Ref untuk mengakses provider lain
  final Ref _ref;

  // [MODIFIKASI] Terima Ref di constructor
  GeneratorKontenShortViewModel(this._ref)
      : super(const GeneratorKontenShortState());

  // (URL Cloud Function Tidak Berubah)
  final String _cloudFunctionUrl =
      "https://asia-southeast2-majiku-5b07e.cloudfunctions.net/generateKontenShort";

  // [BARU] Metode untuk mengubah panjang narasi
  void setLengthOption(int length) {
    state = state.copyWith(lengthOption: length);
  }

  /// [MODIFIKASI] - Mengirimkan Token Otentikasi & lengthOption
  Future<void> generateNarrative(String currentTitle) async {
    if (state.isLoading) return;
    final prompt = promptController.text.trim();
    if (prompt.isEmpty) {
      state = state.copyWith(
          errorMessage: NarakuLocalizationHelper.get('alertNoInput'),
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

      // 1. Siapkan body (DITAMBAHKAN lengthOption)
      final body = jsonEncode({
        'data': {
          'promptValue': prompt,
          'currentTitle': currentTitle,
          'lengthOption': state.lengthOption, // <-- Mengirim opsi panjang ke Backend
        }
      });

      // 2. Lakukan panggilan HTTP POST
      final response = await http.post(
        Uri.parse(_cloudFunctionUrl),
        headers: {
          'Content-Type': 'application/json',
          // [MODIFIKASI] Kirim token otentikasi
          'Authorization': 'Bearer $idToken',
        },
        body: body,
      ).timeout(const Duration(seconds: 120)); // Timeout 2 menit

      // 3. Tangani respons (tidak berubah)
      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        final resultText = responseBody['data'];

        if (resultText != null) {
          // Sukses
          state = state.copyWith(
            isLoading: false,
            generatedNarrative: resultText as String,
            loadingText: '',
          );
        } else {
          throw Exception(
              "Respons sukses, namun 'data' tidak ditemukan di body.");
        }
      } else {
        // Tangani error dari server (misal: 400, 500)
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
      // Menangkap error koneksi, timeout, atau parsing
      state = state.copyWith(
        isLoading: false,
        errorMessage: NarakuLocalizationHelper.get('alertApiError')
            .replaceFirst(
                '{message}', e.toString().replaceFirst('Exception: ', '')),
        loadingText: '',
      );
    }
  }

  // (Metode clearNarrative & clearAll Tidak Berubah)
  void clearNarrative() {
    state = state.copyWith(generatedNarrative: '', clearError: true);
  }

  void clearAll() {
    promptController.clear();
    state = state.copyWith(generatedNarrative: '', clearError: true);
  }

  // (Metode dispose Tidak Berubah)
  @override
  void dispose() {
    promptController.dispose();
    super.dispose();
  }
}

/// KATEGORI_INTEGRASI_KONTEN_SHORT NO_URUT_04 (DIMODIFIKASI)
final generatorKontenShortViewModelProvider = StateNotifierProvider.autoDispose<
    GeneratorKontenShortViewModel, GeneratorKontenShortState>(
  (ref) {
    // [MODIFIKASI] Suntikkan 'ref' ke ViewModel
    return GeneratorKontenShortViewModel(ref);
  },
);