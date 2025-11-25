// [RILIS UTUH - INTEGRASI AUTH TOKEN]
// KATEGORI_NARAKU_TOKEN NO_URUT_02
// Lokasi: lib/view_model_naraku/konsultan_ide_konten_view_model.dart
// TUJUAN:
// - [FITUR] Mengirimkan Firebase Auth ID Token (JWT) di header
// - panggilan http.post ke Cloud Function.
// - [REFAKTOR] Menyuntikkan 'Ref' ke ViewModel untuk mengakses provider auth.
// - [KEAMANAN] Backend sekarang dapat mengidentifikasi user
// - yang melakukan panggilan.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui';

// --- [IMPOR BARU UNTUK OTENTIKASI] ---
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../view_model/auth_view_model.dart'; // Untuk authStateChangesProvider
// --- [AKHIR IMPOR BARU] ---

// --- KATEGORI_INTEGRASI_KONSULTAN NO_URUT_01: Data Localization ---
// (Tidak Berubah)
class KonsultanLocalizationHelper {
  static const Map<String, Map<String, String>> translations = {
    'id': {
      'generatorTitle': "Konsultan Ide Konten",
      'promptLabel': "Masukkan Kategori atau Kata Kunci Ide Konten Anda:",
      'promptPlaceholder':
          "Contoh: 'Ide Konten TikTok Edukasi', 'Kategori: Tren Kecantikan 2025'",
      'btnGenerate': "Dapatkan Ide",
      'btnProcessing': "Memproses...",
      'outputTitle': "Ide Konten Terbaik",
      'outputPlaceholder': "Ide Konten Akan Muncul Disini...",
      'btnCopy': "Salin Ide",
      'btnCopied': "Berhasil Disalin!",
      'btnClear': "Hapus",
      'alertNoInput':
          "Silakan masukkan kategori atau kata kunci terlebih dahulu.",
      'alertApiError': "Terjadi kesalahan: {message}",
      'apiLoading': "Sedang membuat ide, mohon tunggu",
    },
    'en': {
      'generatorTitle': "Content Idea Consultant",
      'promptLabel': "Enter Your Content Category or Keywords:",
      'promptPlaceholder':
          "Example: 'Educational TikTok Ideas', 'Category: 2025 Beauty Trends'",
      'btnGenerate': "Get Ideas",
      'btnProcessing': "Processing...",
      'outputTitle': "Best Content Ideas",
      'outputPlaceholder': "Content Ideas Will Appear Here...",
      'btnCopy': "Copy Ideas",
      'btnCopied': "Copied Successfully!",
      'btnClear': "Clear",
      'alertNoInput': "Please enter a category or keyword first.",
      'alertApiError': "An error occurred: {message}",
      'apiLoading': "Generating ideas, please wait",
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

/// KATEGORI_INTEGRASI_KONSULTAN NO_URUT_02
// (State Class Tidak Berubah)
@immutable
class KonsultanIdeKontenState {
  final bool isLoading;
  final String generatedIdeas;
  final String? errorMessage;
  final String loadingText;

  const KonsultanIdeKontenState({
    this.isLoading = false,
    this.generatedIdeas = '',
    this.errorMessage,
    this.loadingText = '',
  });

  KonsultanIdeKontenState copyWith({
    bool? isLoading,
    String? generatedIdeas,
    String? errorMessage,
    String? loadingText,
    bool clearError = false,
  }) {
    return KonsultanIdeKontenState(
      isLoading: isLoading ?? this.isLoading,
      generatedIdeas: generatedIdeas ?? this.generatedIdeas,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      loadingText: loadingText ?? this.loadingText,
    );
  }
}

/// KATEGORI_INTEGRASI_KONSULTAN NO_URUT_03 (DIMODIFIKASI)
class KonsultanIdeKontenViewModel
    extends StateNotifier<KonsultanIdeKontenState> {
  final TextEditingController promptController = TextEditingController();

  // [BARU] Tambahkan Ref untuk mengakses provider lain
  final Ref _ref;

  // [MODIFIKASI] Terima Ref di constructor
  KonsultanIdeKontenViewModel(this._ref) : super(const KonsultanIdeKontenState());

  // (URL Cloud Function Tidak Berubah)
  final String _cloudFunctionUrl =
      "https://asia-southeast2-majiku-5b07e.cloudfunctions.net/konsultanIdeKonten";

  Future<void> generateIdeas() async {
    if (state.isLoading) return;
    final prompt = promptController.text.trim();
    if (prompt.isEmpty) {
      state = state.copyWith(
          errorMessage: KonsultanLocalizationHelper.get('alertNoInput'),
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
        // Harusnya dicegah oleh UI (tombol disable), tapi ini jaring pengaman
        throw Exception("Sesi pengguna tidak ditemukan. Harap login ulang.");
      }

      // 2. Dapatkan ID Token (JWT) pengguna.
      // (true) = paksa refresh jika token kedaluwarsa.
      final idToken = await authUser.getIdToken(true);
      // --- [AKHIR LOGIKA TOKEN BARU] ---

      // Siapkan body (tidak berubah)
      final body = jsonEncode({
        'data': {
          'promptInput': prompt, // Kunci harus 'promptInput'
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
      ).timeout(const Duration(seconds: 120));

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        final resultText = responseBody['data'];

        if (resultText != null) {
          state = state.copyWith(
            isLoading: false,
            generatedIdeas: resultText as String,
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
        throw Exception(errorMessage);
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: KonsultanLocalizationHelper.get('alertApiError')
            .replaceFirst(
                '{message}', e.toString().replaceFirst('Exception: ', '')),
        loadingText: '',
      );
    }
  }

  // (Metode clearAll Tidak Berubah)
  void clearAll() {
    promptController.clear();
    state = state.copyWith(generatedIdeas: '', clearError: true);
  }

  // (Metode dispose Tidak Berubah)
  @override
  void dispose() {
    promptController.dispose();
    super.dispose();
  }
}

/// KATEGORI_INTEGRASI_KONSULTAN NO_URUT_04 (DIMODIFIKASI)
final konsultanIdeKontenViewModelProvider = StateNotifierProvider.autoDispose<
    KonsultanIdeKontenViewModel, KonsultanIdeKontenState>(
  (ref) {
    // [MODIFIKASI] Suntikkan 'ref' ke ViewModel
    return KonsultanIdeKontenViewModel(ref);
  },
);