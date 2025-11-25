// [RILIS UTUH - INTEGRASI AUTH TOKEN]
// KATEGORI_NARAKU_TOKEN NO_URUT_15
// Lokasi: lib/view_model_naraku/generator_kisah_custom_view_model.dart
// TUJUAN:
// - [FITUR] Mengirimkan Firebase Auth ID Token (JWT) di header
// - panggilan http.post ke Cloud Function 'generatorKisahCustom'.
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

// --- KATEGORI_INTEGRASI_KISAH_CUSTOM NO_URUT_01: Data Localization ---
// (Tidak Berubah)
class KisahCustomLocalizationHelper {
  // [ANTI-REGRESI] Dipindahkan dari JS
  static const Map<String, Map<String, String>> translations = {
    'id': {
      'generatorTitle': "Generator Kisah Custom",
      'btnGenerate': "Buat Narasi",
      'outputTitle': "Narasi yang Dibuat",
      'outputPlaceholder': "Hasil Generasi Akan Muncul Disini...",
      'btnCopy': "Salin Narasi",
      'btnClear': "Hapus",
      'alertNoInput': "Silakan masukkan setidaknya Judul atau Genre cerita.",
      'statusGenerating': "Memproses...",
      'statusLoading': "Sedang membuat narasi, mohon tunggu",
      'statusCopySuccess': "Berhasil Disalin!",
      'alertApiError': "Terjadi kesalahan: {message}",
      'step1Title': "Ide Pokok",
      'judulLabel': "Judul Cerita:",
      'judulPlaceholder': "Contoh: Sang Penjaga Hutan Terakhir",
      'genreLabel': "Genre/Topik:",
      'genrePlaceholder': "Pilih genre...",
      'step2Title': "Dunia & Karakter",
      'karakterLabel': "Karakter Utama:",
      'karakterPlaceholder': "Deskripsikan karakter utama Anda...",
      'settingLabel': "Setting/Latar:",
      'settingPlaceholder': "Jelaskan latar tempat dan waktu...",
      'premisLabel': "Konflik Awal/Premis:",
      'premisPlaceholder': "Contoh: Sebuah naskah kuno ditemukan...",
      'step3Title': "Gaya Bahasa",
      'btnAIAssist': "✨ Serahkan pada AI",
      'btnAIActive': "✨ Mode AI Aktif",
      'gayaLegenda': "Legenda",
      'gayaPuitis': "Puitis",
      'gayaModern': "Modern",
      'gayaGaul': "Gaul",
      'aiAssistPlaceholder': "AI akan menciptakan bagian ini untuk Anda.",
      'languageHint':
          "💡 Tips: Anda bisa menentukan bahasa output di akhir judul, contoh: ', dalam bahasa Inggris'",
      'genreFantasiName': "Fantasi",
      'genreFantasiDesc': "Sihir, makhluk mitos, dan petualangan epik.",
      'genreScifiName': "Fiksi Ilmiah (Sci-Fi)",
      'genreScifiDesc':
          "Teknologi canggih, perjalanan waktu, dan luar angkasa.",
      'genreThrillerName': "Thriller",
      'genreThrillerDesc':
          "Ketegangan, kegembiraan, dan kejutan, seringkali intrik kriminal.",
      'genreRomansaName': "Romansa",
      'genreRomansaDesc':
          "Berfokus pada hubungan cinta antara karakter utama.",
      'genreHororName': "Horor",
      'genreHororDesc':
          "Menakut-nakuti dan memancing rasa takut, bisa supernatural/psikologis.",
      'genreMisteriName': "Misteri",
      'genreMisteriDesc':
          "Fokus utama adalah memecahkan teka-teki atau kejahatan.",
      'genreDramaName': "Drama",
      'genreDramaDesc':
          "Berfokus pada konflik emosional dan hubungan antar karakter.",
      'genrePetualanganName': "Petualangan",
      'genrePetualanganDesc':
          "Melibatkan perjalanan, eksplorasi, dan bahaya yang harus diatasi.",
    },
    'en': {
      'generatorTitle': "Custom Story Generator",
      'btnGenerate': "Create Narrative",
      'outputTitle': "Generated Narrative",
      'outputPlaceholder': "Generated Results Will Appear Here...",
      'btnCopy': "Copy Narrative",
      'btnClear': "Clear",
      'alertNoInput': "Please enter at least the Story Title or Genre.",
      'statusGenerating': "Processing...",
      'statusLoading': "Generating narrative, please wait",
      'statusCopySuccess': "Copied Successfully!",
      'alertApiError': "An error occurred: {message}",
      'step1Title': "Core Idea",
      'judulLabel': "Story Title:",
      'judulPlaceholder': "Example: The Last Forest Guardian",
      'genreLabel': "Genre/Topic:",
      'genrePlaceholder': "Select a genre...",
      'step2Title': "World & Characters",
      'karakterLabel': "Main Character:",
      'karakterPlaceholder': "Describe your main character...",
      'settingLabel': "Setting/Background:",
      'settingPlaceholder': "Describe the time and place...",
      'premisLabel': "Initial Conflict/Premise:",
      'premisPlaceholder': "Example: An ancient manuscript is discovered...",
      'step3Title': "Writing Style",
      'btnAIAssist': "✨ Let AI Decide",
      'btnAIActive': "✨ AI Mode Active",
      'gayaLegenda': "Legend",
      'gayaPuitis': "Poetic",
      'gayaModern': "Modern",
      'gayaGaul': "Casual",
      'aiAssistPlaceholder': "AI will create this part for you.",
      'languageHint':
          "💡 Tip: You can specify the output language at the end of the title, e.g., ', in English'",
      'genreFantasiName': "Fantasy",
      'genreFantasiDesc': "Magic, mythical creatures, and epic adventures.",
      'genreScifiName': "Science Fiction (Sci-Fi)",
      'genreScifiDesc': "Advanced tech, time travel, and outer space.",
      'genreThrillerName': "Thriller",
      'genreThrillerDesc':
          "Tension, excitement, and surprise, often criminal intrigue.",
      'genreRomansaName': "Romance",
      'genreRomansaDesc':
          "Focuses on the love relationship between main characters.",
      'genreHororName': "Horror",
      'genreHororDesc':
          "Aims to frighten, can be supernatural or psychological.",
      'genreMisteriName': "Mystery",
      'genreMisteriDesc': "The main focus is on solving a puzzle or crime.",
      'genreDramaName': "Drama",
      'genreDramaDesc':
          "Focuses on emotional conflicts and character relationships.",
      'genrePetualanganName': "Adventure",
      'genrePetualanganDesc':
          "Involves journeys, exploration, and dangers to overcome.",
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

/// KATEGORI_INTEGRASI_KISAH_CUSTOM NO_URUT_02
// (State Class Tidak Berubah)
@immutable
class GeneratorKisahCustomState {
  final bool isLoading;
  final String generatedStory;
  final String? errorMessage;
  final String loadingText;

  // State untuk form kustom
  final String selectedGenre;
  final String selectedStyle;
  final bool isPremisAi;
  final bool isKarakterAi;
  final bool isSettingAi;

  const GeneratorKisahCustomState({
    this.isLoading = false,
    this.generatedStory = '',
    this.errorMessage,
    this.loadingText = '',
    this.selectedGenre = '',
    this.selectedStyle = 'Legenda', // Default sesuai HTML
    this.isPremisAi = false,
    this.isKarakterAi = false,
    this.isSettingAi = false,
  });

  GeneratorKisahCustomState copyWith({
    bool? isLoading,
    String? generatedStory,
    String? errorMessage,
    String? loadingText,
    bool clearError = false,
    String? selectedGenre,
    String? selectedStyle,
    bool? isPremisAi,
    bool? isKarakterAi,
    bool? isSettingAi,
  }) {
    return GeneratorKisahCustomState(
      isLoading: isLoading ?? this.isLoading,
      generatedStory: generatedStory ?? this.generatedStory,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      loadingText: loadingText ?? this.loadingText,
      selectedGenre: selectedGenre ?? this.selectedGenre,
      selectedStyle: selectedStyle ?? this.selectedStyle,
      isPremisAi: isPremisAi ?? this.isPremisAi,
      isKarakterAi: isKarakterAi ?? this.isKarakterAi,
      isSettingAi: isSettingAi ?? this.isSettingAi,
    );
  }
}

/// KATEGORI_INTEGRASI_KISAH_CUSTOM NO_URUT_03 (DIMODIFIKASI)
class GeneratorKisahCustomViewModel
    extends StateNotifier<GeneratorKisahCustomState> {
  // Controller untuk input teks
  final TextEditingController judulController = TextEditingController();
  final TextEditingController premisController = TextEditingController();
  final TextEditingController karakterController = TextEditingController();
  final TextEditingController settingController = TextEditingController();

  // [BARU] Tambahkan Ref untuk mengakses provider lain
  final Ref _ref;

  // [MODIFIKASI] Terima Ref di constructor
  GeneratorKisahCustomViewModel(this._ref)
      : super(const GeneratorKisahCustomState());

  // (URL Cloud Function Tidak Berubah)
  final String _cloudFunctionUrl =
      "https://asia-southeast2-majiku-5b07e.cloudfunctions.net/generatorKisahCustom";

  // (Metode setGenre, setStyle, toggleAiAssist Tidak Berubah)
  void setGenre(String? genre) {
    if (genre == null) return;
    state = state.copyWith(selectedGenre: genre);
  }

  void setStyle(String? style) {
    if (style == null) return;
    state = state.copyWith(selectedStyle: style);
  }

  void toggleAiAssist(String fieldName) {
    switch (fieldName) {
      case 'premis':
        final bool newStatus = !state.isPremisAi;
        if (newStatus) premisController.clear(); // Hapus teks jika AI diaktifkan
        state = state.copyWith(isPremisAi: newStatus);
        break;
      case 'karakter':
        final bool newStatus = !state.isKarakterAi;
        if (newStatus) karakterController.clear();
        state = state.copyWith(isKarakterAi: newStatus);
        break;
      case 'setting':
        final bool newStatus = !state.isSettingAi;
        if (newStatus) settingController.clear();
        state = state.copyWith(isSettingAi: newStatus);
        break;
    }
  }

  Future<void> generateStory() async {
    if (state.isLoading) return;
    final judul = judulController.text.trim();
    final genre = state.selectedGenre;

    // (Validasi Tidak Berubah)
    if (judul.isEmpty && genre.isEmpty) {
      state = state.copyWith(
          errorMessage: KisahCustomLocalizationHelper.get('alertNoInput'),
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

      // [KONTRAK API] (Tidak Berubah)
      final body = jsonEncode({
        'data': {
          'judul': judul,
          'genre': genre,
          'premis': state.isPremisAi
              ? "AI_ASSIST"
              : premisController.text.trim(),
          'karakter': state.isKarakterAi
              ? "AI_ASSIST"
              : karakterController.text.trim(),
          'setting': state.isSettingAi
              ? "AI_ASSIST"
              : settingController.text.trim(),
          'gayaTerpilih': state.selectedStyle,
        }
      });

      final response = await http
          .post(
            Uri.parse(_cloudFunctionUrl),
            headers: {
              'Content-Type': 'application/json',
              // [MODIFIKASI] Kirim token otentikasi
              'Authorization': 'Bearer $idToken',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 300)); // 5 menit timeout

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
        errorMessage: KisahCustomLocalizationHelper.get('alertApiError')
            .replaceFirst(
                '{message}', e.toString().replaceFirst('Exception: ', '')),
        loadingText: '',
      );
    }
  }

  // (Metode clearAll Tidak Berubah)
  void clearAll() {
    judulController.clear();
    premisController.clear();
    karakterController.clear();
    settingController.clear();
    state = state.copyWith(
      generatedStory: '',
      clearError: true,
      selectedGenre: '',
      selectedStyle: 'Legenda', // Reset ke default
      isPremisAi: false,
      isKarakterAi: false,
      isSettingAi: false,
    );
  }

  // (Metode dispose Tidak Berubah)
  @override
  void dispose() {
    judulController.dispose();
    premisController.dispose();
    karakterController.dispose();
    settingController.dispose();
    super.dispose();
  }
}

/// KATEGORI_INTEGRASI_KISAH_CUSTOM NO_URUT_04 (DIMODIFIKASI)
final generatorKisahCustomViewModelProvider = StateNotifierProvider.autoDispose<
    GeneratorKisahCustomViewModel, GeneratorKisahCustomState>(
  (ref) {
    // [MODIFIKASI] Suntikkan 'ref' ke ViewModel
    return GeneratorKisahCustomViewModel(ref);
  },
);