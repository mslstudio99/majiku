//................................................................//
// NAMA FILE: GENERATOR_KONTEN_SHORT_VIEW_MODEL.DART              //
// PATH: LIB/VIEW_MODEL_NARAKU/GENERATOR_KONTEN_SHORT_VIEW_MODEL.DART //
//................................................................//

//No ke-1.........................................................//
//IMPORT MODULE & DEPENDENCIES....................................//
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Import SDK Resmi Cloud Functions
import 'package:cloud_functions/cloud_functions.dart';

// Import Auth Provider
import '../view_model/auth_view_model.dart';
//................................................................//

//No ke-2.........................................................//
//LOCALIZATION HELPER.............................................//
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
//................................................................//

//No ke-3.........................................................//
//STATE MODEL (GENERATOR KONTEN SHORT STATE)......................//
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
//................................................................//

//No ke-4.........................................................//
//VIEW MODEL & GENERATION LOGIC (OFFICIAL FIREBASE SDK)...........//
class GeneratorKontenShortViewModel
    extends StateNotifier<GeneratorKontenShortState> {
  final TextEditingController promptController = TextEditingController();
  final Ref _ref;

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

      // Handle Title Kosong (Mencegah Error 400 di Backend)
      String safeTitle = currentTitle ?? "";
      if (safeTitle.trim().isEmpty) {
        safeTitle = prompt.length > 20 ? prompt.substring(0, 20) : "Konten Baru";
      }

      // Payload Murni
      final Map<String, dynamic> payload = {
        'promptValue': prompt,
        'currentTitle': safeTitle,
        'lengthOption': state.lengthOption,
      };

      // ============================================================
      // JALUR TUNGGAL RESMI (WEB & HP ANDROID/IOS)
      // Menggunakan SDK Resmi Firebase Functions dengan Native OkHttp
      // Bebas dari SocketException / Connection reset by peer (errno 104)
      // ============================================================
      final functions = FirebaseFunctions.instanceFor(region: "asia-southeast2");
      final callable = functions.httpsCallable(
        'generateKontenShort',
        options: HttpsCallableOptions(timeout: const Duration(minutes: 3)),
      );

      final result = await callable.call(payload);

      final data = result.data;
      if (data is Map && data.containsKey('data')) {
        finalText = data['data'];
      } else if (data is String) {
        finalText = data;
      } else if (data != null) {
        finalText = data.toString();
      }

      if (finalText != null && finalText.isNotEmpty) {
        state = state.copyWith(
          isLoading: false,
          generatedNarrative: finalText,
          loadingText: '',
        );
      } else {
        throw Exception("Hasil generasi kosong.");
      }
    } on FirebaseFunctionsException catch (fe) {
      print("--- [KONTEN_SHORT] FirebaseFunctionsException: ${fe.code} - ${fe.message} ---");
      final errorMsg = fe.message ?? fe.code;
      state = state.copyWith(
        isLoading: false,
        errorMessage: NarakuLocalizationHelper.get('alertApiError')
            .replaceFirst('{message}', errorMsg),
        loadingText: '',
      );
    } catch (e) {
      print("--- [KONTEN_SHORT] Exception: $e ---");
      state = state.copyWith(
        isLoading: false,
        errorMessage: NarakuLocalizationHelper.get('alertApiError')
            .replaceFirst('{message}', e.toString().replaceFirst('Exception: ', '')),
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
//................................................................//

//No ke-5.........................................................//
//PROVIDER DECLARATION............................................//
final generatorKontenShortViewModelProvider = StateNotifierProvider.autoDispose<
    GeneratorKontenShortViewModel, GeneratorKontenShortState>(
  (ref) {
    return GeneratorKontenShortViewModel(ref);
  },
);
//................................................................//