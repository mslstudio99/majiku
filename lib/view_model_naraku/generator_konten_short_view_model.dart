// [RILIS FINAL - HYBRID SPLIT STRATEGY]
// KATEGORI_NARAKU_TOKEN NO_URUT_14
// TUJUAN:
// - [WEB] Menggunakan 'httpsCallable' (SDK) -> Terbukti SUKSES di Web.
// - [ANDROID] Menggunakan 'http.post' (Manual) -> Solusi anti-macet di Android.
// - [DATA] Memastikan 'currentTitle' terisi default jika kosong (Anti Error 400).

import 'package:flutter/foundation.dart'; // Untuk kIsWeb
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Import HTTP untuk Android
import 'package:http/http.dart' as http; 
import 'dart:convert';

// Import Cloud Functions untuk Web
import 'package:cloud_functions/cloud_functions.dart'; 

// Import Auth
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../view_model/auth_view_model.dart'; 

class NarakuLocalizationHelper {
  static const Map<String, Map<String, String>> translations = {
    'id': {
      'alertNoInput': "Silakan masukkan judul atau kata kunci terlebih dahulu.",
      'alertApiError': "Terjadi kesalahan: {message}",
    },
    'en': {
      'alertNoInput': "Please enter a title or keyword first.",
      'alertApiError': "An error occurred: {message}",
    },
  };

  static String get(String key, {String? localeCode}) {
    final lang = localeCode ?? 'en'; 
    final langKey = lang == 'id' ? 'id' : 'en';
    final translationMap = translations[langKey] ?? translations['id']!;
    return translationMap[key] ?? key;
  }
}

@immutable
class GeneratorKontenShortState {
  final bool isLoading;
  final String generatedNarrative;
  final String? errorMessage;
  final String loadingText;
  final int lengthOption;

  const GeneratorKontenShortState({
    this.isLoading = false,
    this.generatedNarrative = '',
    this.errorMessage,
    this.loadingText = '',
    this.lengthOption = 1000,
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

class GeneratorKontenShortViewModel
    extends StateNotifier<GeneratorKontenShortState> {
  final TextEditingController promptController = TextEditingController();
  final Ref _ref;

  // URL Endpoint (Hanya dipakai Android)
  final String _endpointUrl = 
      "https://asia-southeast2-majiku-5b07e.cloudfunctions.net/generateKontenShort";

  GeneratorKontenShortViewModel(this._ref)
      : super(const GeneratorKontenShortState());

  void setLengthOption(int length) {
    state = state.copyWith(lengthOption: length);
  }

  Future<void> generateNarrative(String? currentTitle) async {
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
      String? finalText;

      // [FIX PENTING] Handle Title Kosong (Penyebab Error 400 di Backend)
      String safeTitle = currentTitle ?? "";
      if (safeTitle.trim().isEmpty) {
        // Jika kosong, gunakan 20 karakter pertama dari prompt atau default
        safeTitle = prompt.length > 20 ? prompt.substring(0, 20) : "Konten Baru";
      }

      // Data Payload Murni
      final Map<String, dynamic> payload = {
        'promptValue': prompt,
        'currentTitle': safeTitle,
        'lengthOption': state.lengthOption,
      };

      // ============================================================
      // PERCABANGAN LOGIKA: WEB vs ANDROID
      // ============================================================

      if (kIsWeb) {
        // [JALUR WEB] Gunakan SDK Resmi (httpsCallable)
        // Ini sama persis dengan "Kode Awal" Anda yang sukses di Web.
        // SDK akan otomatis membungkus payload dalam { data: ... }
        
        print("--- [WEB] Using httpsCallable SDK ---");
        
        final functions = FirebaseFunctions.instanceFor(region: "asia-southeast2");
        final callable = functions.httpsCallable('generateKontenShort');

        final result = await callable.call(payload); // Kirim payload langsung!

        final data = result.data;
        if (data is Map && data.containsKey('data')) {
           finalText = data['data']; 
        } else if (data is String) {
           finalText = data;
        }

      } else {
        // [JALUR ANDROID] Gunakan HTTP Manual
        // Agar tidak macet di Google Play Services.
        
        print("--- [ANDROID] Using HTTP Manual ---");

        // 1. Ambil Token
        final authUser = _ref.read(authStateChangesProvider).value;
        if (authUser == null) throw Exception("User tidak login.");
        final idToken = await authUser.getIdToken(true);

        // 2. Bungkus Payload dengan key "data" (Single Wrap)
        // Ini meniru apa yang dilakukan SDK Web secara manual.
        final body = jsonEncode({
          "data": payload 
        });

        // 3. Kirim
        final response = await http.post(
          Uri.parse(_endpointUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $idToken',
          },
          body: body,
        ).timeout(const Duration(seconds: 120));

        print("Status Code: ${response.statusCode}");

        if (response.statusCode == 200) {
          final responseJson = jsonDecode(response.body);
          // Hasil onCall HTTP ada di 'result' atau 'data'
          final resultData = responseJson['result'] ?? responseJson['data'];
          
          if (resultData != null) {
             if (resultData is String) {
               finalText = resultData;
             } else if (resultData is Map && resultData.containsKey('data')) {
               finalText = resultData['data'];
             } else {
               finalText = resultData.toString();
             }
          } else {
             // Fallback
             final altData = responseJson['data'];
             if (altData != null && altData is String) finalText = altData;
          }
        } else {
           // Handle Error
           final errorBody = jsonDecode(response.body);
           final msg = errorBody['error']?['message'] ?? response.body;
           throw Exception("Server Error (${response.statusCode}): $msg");
        }
      }

      // ============================================================

      if (finalText != null && finalText.isNotEmpty) {
        state = state.copyWith(
          isLoading: false,
          generatedNarrative: finalText,
          loadingText: '',
        );
      } else {
        throw Exception("Hasil generasi kosong.");
      }

    } catch (e) {
      print("--- ERROR: $e ---");
      state = state.copyWith(
        isLoading: false,
        errorMessage: NarakuLocalizationHelper.get('alertApiError')
            .replaceFirst('{message}', e.toString()),
        loadingText: '',
      );
    }
  }

  void clearNarrative() {
    state = state.copyWith(generatedNarrative: '', clearError: true);
  }

  void clearAll() {
    promptController.clear();
    state = state.copyWith(generatedNarrative: '', clearError: true);
  }

  @override
  void dispose() {
    promptController.dispose();
    super.dispose();
  }
}

final generatorKontenShortViewModelProvider = StateNotifierProvider.autoDispose<
    GeneratorKontenShortViewModel, GeneratorKontenShortState>(
  (ref) {
    return GeneratorKontenShortViewModel(ref);
  },
);