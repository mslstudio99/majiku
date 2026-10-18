//................................................................//
// NAMA FILE: GENERATOR_KISAH_HOROR_VIEW_MODEL.DART               //
// PATH: LIB/VIEW_MODEL_NARAKU/GENERATOR_KISAH_HOROR_VIEW_MODEL.DART //
//................................................................//

//No ke-1.........................................................//
//IMPORT MODULE & DEPENDENCIES....................................//
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

// Import Auth
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../view_model/auth_view_model.dart';
//................................................................//

//No ke-2.........................................................//
//LOCALIZATION HELPER.............................................//
class KisahHororLocalizationHelper {
  static const Map<String, Map<String, String>> translations = {
    'id': {
      'generatorTitle': "Generator Kisah Horor",
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
      'generatorTitle': "Horror Story Generator",
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
//................................................................//

//No ke-3.........................................................//
//STATE MODEL (GENERATOR KISAH HOROR STATE).......................//
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
//................................................................//

//No ke-4.........................................................//
//VIEW MODEL & GENERATION LOGIC (ROBUST NETWORK CLIENT)...........//
class GeneratorKisahHororViewModel
    extends StateNotifier<GeneratorKisahHororState> {
  final TextEditingController promptController = TextEditingController();
  final Ref _ref;

  // Endpoint Cloud Function
  final String _cloudFunctionUrl =
      "https://asia-southeast2-majiku-5b07e.cloudfunctions.net/generatorKisahHoror";

  GeneratorKisahHororViewModel(this._ref)
      : super(const GeneratorKisahHororState());

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
      // 1. Dapatkan user saat ini dari provider auth
      final authUser = _ref.read(authStateChangesProvider).value;
      if (authUser == null) {
        throw Exception("Sesi pengguna tidak ditemukan. Harap login ulang.");
      }

      // 2. Dapatkan ID Token (JWT) pengguna
      final idToken = await authUser.getIdToken(true);

      // 3. Siapkan body dengan kunci 'userInput' (Sesuai kontrak backend)
      final body = jsonEncode({
        'data': {
          'userInput': prompt,
        }
      });

      // 4. Header dengan Connection: close untuk mencegah Socket Reuse Error (Errno 104)
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $idToken',
        'Connection': 'close',
      };

      // 5. Eksekusi pemanggilan dengan client mandiri & auto-retry 1x khusus socket reset
      http.Response? response;
      int attempts = 0;
      const int maxAttempts = 2;

      while (attempts < maxAttempts) {
        attempts++;
        final client = http.Client();
        try {
          response = await client.post(
            Uri.parse(_cloudFunctionUrl),
            headers: headers,
            body: body,
          ).timeout(const Duration(seconds: 300)); // 5 menit timeout
          break; // Berhasil terkirim dan menerima respons
        } on SocketException catch (socketErr) {
          if (attempts < maxAttempts) {
            print("--- [KISAH_HOROR] Socket reset terdeteksi, mencoba ulang koneksi (attempt $attempts): $socketErr ---");
            await Future.delayed(const Duration(milliseconds: 600));
            continue;
          }
          rethrow;
        } on http.ClientException catch (clientErr) {
          final isConnectionReset = clientErr.message.toLowerCase().contains('connection reset') ||
              clientErr.message.toLowerCase().contains('socketexception');
          if (isConnectionReset && attempts < maxAttempts) {
            print("--- [KISAH_HOROR] ClientException reset, mencoba ulang koneksi (attempt $attempts): $clientErr ---");
            await Future.delayed(const Duration(milliseconds: 600));
            continue;
          }
          rethrow;
        } finally {
          client.close();
        }
      }

      if (response != null) {
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
          // Safe JSON error decoding
          String errorMessage = 'Error HTTP ${response.statusCode}';
          try {
            final errorBody = jsonDecode(response.body);
            if (errorBody is Map && errorBody.containsKey('error')) {
              final err = errorBody['error'];
              if (err is Map && err.containsKey('message')) {
                errorMessage = err['message'];
              } else if (err is String) {
                errorMessage = err;
              }
            }
          } catch (_) {
            if (response.body.isNotEmpty) {
              errorMessage = response.body;
            }
          }

          if (response.statusCode == 402) {
            throw Exception(errorMessage); // Menampilkan pesan Token Tidak Cukup
          }
          throw Exception(errorMessage);
        }
      } else {
        throw Exception("Gagal mendapatkan respons dari server.");
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

  void clearAll() {
    promptController.clear();
    state = state.copyWith(generatedStory: '', clearError: true);
  }

  @override
  void dispose() {
    promptController.dispose();
    super.dispose();
  }
}
//................................................................//

//No ke-5.........................................................//
//PROVIDER DECLARATION............................................//
final generatorKisahHororViewModelProvider = StateNotifierProvider.autoDispose<
    GeneratorKisahHororViewModel, GeneratorKisahHororState>(
  (ref) {
    return GeneratorKisahHororViewModel(ref);
  },
);
//................................................................//