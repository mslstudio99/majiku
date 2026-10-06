//================================================================//
// LIB/VIEW_MODEL_NARAKU/T2SPEECH_VIEW_MODEL.DART                 //
// VIEW MODEL TEKS KE SUARA PREMIUM (T2SPEECH)                    //
// MENGELOLA STATE, VOICES CHIRP3-HD, API ENGINE, AUDIO & HISTORY //
//================================================================//

//No ke-1: IMPORTS, HELPER LOKALISASI & STATE CLASS               //
//DEFINISI DEPENDENSI, LOKALISASI MULTIBAHASA & MODEL STATE       //
import 'dart:async'; // [BARU] Penanganan StreamSubscription audio player
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:audioplayers/audioplayers.dart';

import '../models_naraku/audio_project_t2speech.dart';
import '../services_naraku/firestore_t2speech_service.dart';

class T2SpeechLocalizationHelper {
  static const Map<String, Map<String, String>> translations = {
    'id': {
      'alertNoInput': "Silakan masukkan teks narasi terlebih dahulu.",
      'alertExceedLimit': "Teks melebihi batas maksimal karakter.",
      'alertNoAuth': "Anda belum login. Silakan login kembali.",
      'statusGenerating': "Mensintesis Suara Premium HD...",
      'statusSuccess': "Sintesis suara berhasil! Silakan dengarkan atau unduh.",
      'statusDownloadSuccess': "Audio sedang diunduh melalui browser/sistem...",
      'statusDownloadFailed': "Gagal mengunduh audio: {error}",
      'alertApiError': "Terjadi kesalahan mesin sintesis: {message}",
    },
    'en': {
      'alertNoInput': "Please enter narration text first.",
      'alertExceedLimit': "Text exceeds maximum limit characters.",
      'alertNoAuth': "You are not logged in. Please sign in again.",
      'statusGenerating': "Synthesizing Premium HD Speech...",
      'statusSuccess': "Speech synthesis successful! Listen or download.",
      'statusDownloadSuccess': "Audio is downloading via browser/system...",
      'statusDownloadFailed': "Failed to download audio: {error}",
      'alertApiError': "Synthesis Engine Error: {message}",
    }
  };

  static String get(String key, {String? localeCode}) {
    final lang = localeCode ?? PlatformDispatcher.instance.locale.languageCode;
    final langKey = lang == 'id' ? 'id' : 'en';
    final translationMap = translations[langKey] ?? translations['id']!;
    return translationMap[key] ?? key;
  }
}

@immutable
class T2SpeechState {
  final bool isLoading;
  final String generatedAudioUrl;
  final String? errorMessage;
  final String? successMessage;
  final String loadingText;

  final String selectedLanguage;
  final String selectedVoice;
  final List<String> availableLanguages;
  final Map<String, String> currentVoiceOptions;

  final bool isPlaying;

  const T2SpeechState({
    this.isLoading = false,
    this.generatedAudioUrl = '',
    this.errorMessage,
    this.successMessage,
    this.loadingText = '',
    this.selectedLanguage = 'Indonesian',
    this.selectedVoice = 'id-ID-Chirp3-HD-Achernar',
    this.availableLanguages = const [],
    this.currentVoiceOptions = const {},
    this.isPlaying = false,
  });

  T2SpeechState copyWith({
    bool? isLoading,
    String? generatedAudioUrl,
    String? errorMessage,
    String? successMessage,
    String? loadingText,
    String? selectedLanguage,
    String? selectedVoice,
    List<String>? availableLanguages,
    Map<String, String>? currentVoiceOptions,
    bool? isPlaying,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return T2SpeechState(
      isLoading: isLoading ?? this.isLoading,
      generatedAudioUrl: generatedAudioUrl ?? this.generatedAudioUrl,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
      loadingText: loadingText ?? this.loadingText,
      selectedLanguage: selectedLanguage ?? this.selectedLanguage,
      selectedVoice: selectedVoice ?? this.selectedVoice,
      availableLanguages: availableLanguages ?? this.availableLanguages,
      currentVoiceOptions: currentVoiceOptions ?? this.currentVoiceOptions,
      isPlaying: isPlaying ?? this.isPlaying,
    );
  }
}
// END OF BLOK 1 //
//================================================================//

//No ke-2: DATASET VOKAL PREMIUM CHIRP3-HD (NARACINEMA PLUS)      //
//MAPPING LENGKAP 37 BAHASA DAN RATUSAN VARIAN SUARA GOOGLE HD    //
class T2SpeechVoiceDatabase {
  static const List<String> languageList = [
    'Indonesian', 'English (US)', 'English (UK)', 'English (Australia)',
    'English (India)', 'Arabic', 'Bengali (India)', 'Danish',
    'Dutch (Netherlands)', 'Dutch (Belgium)', 'Finnish', 'French (France)',
    'French (Canada)', 'German', 'Gujarati', 'Hindi', 'Italian', 'Japanese',
    'Kannada', 'Korean', 'Malayalam', 'Mandarin Chinese', 'Marathi',
    'Norwegian', 'Polish', 'Portuguese (Brazil)', 'Russian', 'Spanish (Spain)',
    'Spanish (US)', 'Swedish', 'Tamil', 'Telugu', 'Thai', 'Turkish',
    'Ukrainian', 'Urdu', 'Vietnamese',
  ];

  static const Map<String, String> indonesianVoices = {
    'Achernar (ID)': 'id-ID-Chirp3-HD-Achernar', 'Achird (ID)': 'id-ID-Chirp3-HD-Achird',
    'Algenib (ID)': 'id-ID-Chirp3-HD-Algenib', 'Algieba (ID)': 'id-ID-Chirp3-HD-Algieba',
    'Alnilam (ID)': 'id-ID-Chirp3-HD-Alnilam', 'Aoede (ID)': 'id-ID-Chirp3-HD-Aoede',
    'Autonoe (ID)': 'id-ID-Chirp3-HD-Autonoe', 'Callirrhoe (ID)': 'id-ID-Chirp3-HD-Callirrhoe',
    'Charon (ID)': 'id-ID-Chirp3-HD-Charon', 'Despina (ID)': 'id-ID-Chirp3-HD-Despina',
    'Enceladus (ID)': 'id-ID-Chirp3-HD-Enceladus', 'Erinome (ID)': 'id-ID-Chirp3-HD-Erinome',
    'Fenrir (ID)': 'id-ID-Chirp3-HD-Fenrir', 'Gacrux (ID)': 'id-ID-Chirp3-HD-Gacrux',
    'Iapetus (ID)': 'id-ID-Chirp3-HD-Iapetus', 'Kore (ID)': 'id-ID-Chirp3-HD-Kore',
    'Laomedeia (ID)': 'id-ID-Chirp3-HD-Laomedeia', 'Leda (ID)': 'id-ID-Chirp3-HD-Leda',
    'Orus (ID)': 'id-ID-Chirp3-HD-Orus', 'Puck (ID)': 'id-ID-Chirp3-HD-Puck',
    'Pulcherrima (ID)': 'id-ID-Chirp3-HD-Pulcherrima', 'Rasalgethi (ID)': 'id-ID-Chirp3-HD-Rasalgethi',
    'Sadachbia (ID)': 'id-ID-Chirp3-HD-Sadachbia', 'Sadaltager (ID)': 'id-ID-Chirp3-HD-Sadaltager',
    'Schedar (ID)': 'id-ID-Chirp3-HD-Schedar', 'Sulafat (ID)': 'id-ID-Chirp3-HD-Sulafat',
    'Umbriel (ID)': 'id-ID-Chirp3-HD-Umbriel', 'Vindemiatrix (ID)': 'id-ID-Chirp3-HD-Vindemiatrix',
    'Zephyr (ID)': 'id-ID-Chirp3-HD-Zephyr', 'Zubenelgenubi (ID)': 'id-ID-Chirp3-HD-Zubenelgenubi',
  };

  static const Map<String, String> englishUSVoices = {
    'Alnilam (EN)': 'en-US-Chirp3-HD-Alnilam', 'Aoede (EN)': 'en-US-Chirp3-HD-Aoede',
    'Autonoe (EN)': 'en-US-Chirp3-HD-Autonoe', 'Callirrhoe (EN)': 'en-US-Chirp3-HD-Callirrhoe',
    'Charon (EN)': 'en-US-Chirp3-HD-Charon', 'Despina (EN)': 'en-US-Chirp3-HD-Despina',
    'Enceladus (EN)': 'en-US-Chirp3-HD-Enceladus', 'Erinome (EN)': 'en-US-Chirp3-HD-Erinome',
    'Fenrir (EN)': 'en-US-Chirp3-HD-Fenrir', 'Gacrux (EN)': 'en-US-Chirp3-HD-Gacrux',
    'Iapetus (EN)': 'en-US-Chirp3-HD-Iapetus', 'Kore (EN)': 'en-US-Chirp3-HD-Kore',
    'Laomedeia (EN)': 'en-US-Chirp3-HD-Laomedeia', 'Leda (EN)': 'en-US-Chirp3-HD-Leda',
    'Orus (EN)': 'en-US-Chirp3-HD-Orus', 'Puck (EN)': 'en-US-Chirp3-HD-Puck',
    'Pulcherrima (EN)': 'en-US-Chirp3-HD-Pulcherrima', 'Rasalgethi (EN)': 'en-US-Chirp3-HD-Rasalgethi',
    'Sadachbia (EN)': 'en-US-Chirp3-HD-Sadachbia', 'Sadaltager (EN)': 'en-US-Chirp3-HD-Sadaltager',
    'Schedar (EN)': 'en-US-Chirp3-HD-Schedar', 'Sulafat (EN)': 'en-US-Chirp3-HD-Sulafat',
    'Umbriel (EN)': 'en-US-Chirp3-HD-Umbriel', 'Vindemiatrix (EN)': 'en-US-Chirp3-HD-Vindemiatrix',
    'Zephyr (EN)': 'en-US-Chirp3-HD-Zephyr', 'Zubenelgenubi (EN)': 'en-US-Chirp3-HD-Zubenelgenubi',
  };

  static const Map<String, String> englishUKVoices = {
    'Achernar (en-GB)': 'en-GB-Chirp3-HD-Achernar', 'Aoede (en-GB)': 'en-GB-Chirp3-HD-Aoede',
    'Autonoe (en-GB)': 'en-GB-Chirp3-HD-Autonoe', 'Callirrhoe (en-GB)': 'en-GB-Chirp3-HD-Callirrhoe',
    'Despina (en-GB)': 'en-GB-Chirp3-HD-Despina', 'Achird (en-GB)': 'en-GB-Chirp3-HD-Achird',
    'Algenib (en-GB)': 'en-GB-Chirp3-HD-Algenib', 'Algieba (en-GB)': 'en-GB-Chirp3-HD-Algieba',
    'Alnilam (en-GB)': 'en-GB-Chirp3-HD-Alnilam', 'Charon (en-GB)': 'en-GB-Chirp3-HD-Charon',
  };

  static const Map<String, String> englishAustraliaVoices = {
    'Achernar (en-AU)': 'en-AU-Chirp3-HD-Achernar', 'Aoede (en-AU)': 'en-AU-Chirp3-HD-Aoede',
    'Autonoe (en-AU)': 'en-AU-Chirp3-HD-Autonoe', 'Callirrhoe (en-AU)': 'en-AU-Chirp3-HD-Callirrhoe',
    'Despina (en-AU)': 'en-AU-Chirp3-HD-Despina', 'Achird (en-AU)': 'en-AU-Chirp3-HD-Achird',
    'Algenib (en-AU)': 'en-AU-Chirp3-HD-Algenib', 'Algieba (en-AU)': 'en-AU-Chirp3-HD-Algieba',
    'Alnilam (en-AU)': 'en-AU-Chirp3-HD-Alnilam', 'Charon (en-AU)': 'en-AU-Chirp3-HD-Charon',
  };

  static const Map<String, String> englishIndiaVoices = {
    'Achernar (en-IN)': 'en-IN-Chirp3-HD-Achernar', 'Aoede (en-IN)': 'en-IN-Chirp3-HD-Aoede',
    'Autonoe (en-IN)': 'en-IN-Chirp3-HD-Autonoe', 'Callirrhoe (en-IN)': 'en-IN-Chirp3-HD-Callirrhoe',
    'Despina (en-IN)': 'en-IN-Chirp3-HD-Despina', 'Achird (en-IN)': 'en-IN-Chirp3-HD-Achird',
    'Algenib (en-IN)': 'en-IN-Chirp3-HD-Algenib', 'Algieba (en-IN)': 'en-IN-Chirp3-HD-Algieba',
    'Alnilam (en-IN)': 'en-IN-Chirp3-HD-Alnilam', 'Charon (en-IN)': 'en-IN-Chirp3-HD-Charon',
  };

  static const Map<String, String> arabicVoices = {
    'Achernar (ar-XA)': 'ar-XA-Chirp3-HD-Achernar', 'Aoede (ar-XA)': 'ar-XA-Chirp3-HD-Aoede',
    'Autonoe (ar-XA)': 'ar-XA-Chirp3-HD-Autonoe', 'Callirrhoe (ar-XA)': 'ar-XA-Chirp3-HD-Callirrhoe',
    'Despina (ar-XA)': 'ar-XA-Chirp3-HD-Despina', 'Achird (ar-XA)': 'ar-XA-Chirp3-HD-Achird',
    'Algenib (ar-XA)': 'ar-XA-Chirp3-HD-Algenib', 'Algieba (ar-XA)': 'ar-XA-Chirp3-HD-Algieba',
    'Alnilam (ar-XA)': 'ar-XA-Chirp3-HD-Alnilam', 'Charon (ar-XA)': 'ar-XA-Chirp3-HD-Charon',
  };

  static const Map<String, String> bengaliVoices = {
    'Achernar (bn-IN)': 'bn-IN-Chirp3-HD-Achernar', 'Aoede (bn-IN)': 'bn-IN-Chirp3-HD-Aoede',
    'Autonoe (bn-IN)': 'bn-IN-Chirp3-HD-Autonoe', 'Callirrhoe (bn-IN)': 'bn-IN-Chirp3-HD-Callirrhoe',
    'Despina (bn-IN)': 'bn-IN-Chirp3-HD-Despina', 'Achird (bn-IN)': 'bn-IN-Chirp3-HD-Achird',
    'Algenib (bn-IN)': 'bn-IN-Chirp3-HD-Algenib', 'Algieba (bn-IN)': 'bn-IN-Chirp3-HD-Algieba',
    'Alnilam (bn-IN)': 'bn-IN-Chirp3-HD-Alnilam', 'Charon (bn-IN)': 'bn-IN-Chirp3-HD-Charon',
  };

  static const Map<String, String> danishVoices = {
    'Achernar (da-DK)': 'da-DK-Chirp3-HD-Achernar', 'Aoede (da-DK)': 'da-DK-Chirp3-HD-Aoede',
    'Autonoe (da-DK)': 'da-DK-Chirp3-HD-Autonoe', 'Callirrhoe (da-DK)': 'da-DK-Chirp3-HD-Callirrhoe',
    'Despina (da-DK)': 'da-DK-Chirp3-HD-Despina', 'Achird (da-DK)': 'da-DK-Chirp3-HD-Achird',
    'Algenib (da-DK)': 'da-DK-Chirp3-HD-Algenib', 'Algieba (da-DK)': 'da-DK-Chirp3-HD-Algieba',
    'Alnilam (da-DK)': 'da-DK-Chirp3-HD-Alnilam', 'Charon (da-DK)': 'da-DK-Chirp3-HD-Charon',
  };

  static const Map<String, String> dutchNetherlandsVoices = {
    'Achernar (nl-NL)': 'nl-NL-Chirp3-HD-Achernar', 'Aoede (nl-NL)': 'nl-NL-Chirp3-HD-Aoede',
    'Autonoe (nl-NL)': 'nl-NL-Chirp3-HD-Autonoe', 'Callirrhoe (nl-NL)': 'nl-NL-Chirp3-HD-Callirrhoe',
    'Despina (nl-NL)': 'nl-NL-Chirp3-HD-Despina', 'Achird (nl-NL)': 'nl-NL-Chirp3-HD-Achird',
    'Algenib (nl-NL)': 'nl-NL-Chirp3-HD-Algenib', 'Algieba (nl-NL)': 'nl-NL-Chirp3-HD-Algieba',
    'Alnilam (nl-NL)': 'nl-NL-Chirp3-HD-Alnilam', 'Charon (nl-NL)': 'nl-NL-Chirp3-HD-Charon',
  };

  static const Map<String, String> dutchBelgiumVoices = {
    'Achernar (nl-BE)': 'nl-BE-Chirp3-HD-Achernar', 'Aoede (nl-BE)': 'nl-BE-Chirp3-HD-Aoede',
    'Autonoe (nl-BE)': 'nl-BE-Chirp3-HD-Autonoe', 'Callirrhoe (nl-BE)': 'nl-BE-Chirp3-HD-Callirrhoe',
    'Despina (nl-BE)': 'nl-BE-Chirp3-HD-Despina', 'Achird (nl-BE)': 'nl-BE-Chirp3-HD-Achird',
    'Algenib (nl-BE)': 'nl-BE-Chirp3-HD-Algenib', 'Algieba (nl-BE)': 'nl-BE-Chirp3-HD-Algieba',
    'Alnilam (nl-BE)': 'nl-BE-Chirp3-HD-Alnilam', 'Charon (nl-BE)': 'nl-BE-Chirp3-HD-Charon',
  };

  static const Map<String, String> finnishVoices = {
    'Achernar (fi-FI)': 'fi-FI-Chirp3-HD-Achernar', 'Aoede (fi-FI)': 'fi-FI-Chirp3-HD-Aoede',
    'Autonoe (fi-FI)': 'fi-FI-Chirp3-HD-Autonoe', 'Callirrhoe (fi-FI)': 'fi-FI-Chirp3-HD-Callirrhoe',
    'Despina (fi-FI)': 'fi-FI-Chirp3-HD-Despina', 'Achird (fi-FI)': 'fi-FI-Chirp3-HD-Achird',
    'Algenib (fi-FI)': 'fi-FI-Chirp3-HD-Algenib', 'Algieba (fi-FI)': 'fi-FI-Chirp3-HD-Algieba',
    'Alnilam (fi-FI)': 'fi-FI-Chirp3-HD-Alnilam', 'Charon (fi-FI)': 'fi-FI-Chirp3-HD-Charon',
  };

  static const Map<String, String> frenchFranceVoices = {
    'Achernar (fr-FR)': 'fr-FR-Chirp3-HD-Achernar', 'Aoede (fr-FR)': 'fr-FR-Chirp3-HD-Aoede',
    'Autonoe (fr-FR)': 'fr-FR-Chirp3-HD-Autonoe', 'Callirrhoe (fr-FR)': 'fr-FR-Chirp3-HD-Callirrhoe',
    'Despina (fr-FR)': 'fr-FR-Chirp3-HD-Despina', 'Achird (fr-FR)': 'fr-FR-Chirp3-HD-Achird',
    'Algenib (fr-FR)': 'fr-FR-Chirp3-HD-Algenib', 'Algieba (fr-FR)': 'fr-FR-Chirp3-HD-Algieba',
    'Alnilam (fr-FR)': 'fr-FR-Chirp3-HD-Alnilam', 'Charon (fr-FR)': 'fr-FR-Chirp3-HD-Charon',
  };

  static const Map<String, String> frenchCanadaVoices = {
    'Achernar (fr-CA)': 'fr-CA-Chirp3-HD-Achernar', 'Aoede (fr-CA)': 'fr-CA-Chirp3-HD-Aoede',
    'Autonoe (fr-CA)': 'fr-CA-Chirp3-HD-Autonoe', 'Callirrhoe (fr-CA)': 'fr-CA-Chirp3-HD-Callirrhoe',
    'Despina (fr-CA)': 'fr-CA-Chirp3-HD-Despina', 'Achird (fr-CA)': 'fr-CA-Chirp3-HD-Achird',
    'Algenib (fr-CA)': 'fr-CA-Chirp3-HD-Algenib', 'Algieba (fr-CA)': 'fr-CA-Chirp3-HD-Algieba',
    'Alnilam (fr-CA)': 'fr-CA-Chirp3-HD-Alnilam', 'Charon (fr-CA)': 'fr-CA-Chirp3-HD-Charon',
  };

  static const Map<String, String> germanVoices = {
    'Achernar (de-DE)': 'de-DE-Chirp3-HD-Achernar', 'Aoede (de-DE)': 'de-DE-Chirp3-HD-Aoede',
    'Autonoe (de-DE)': 'de-DE-Chirp3-HD-Autonoe', 'Callirrhoe (de-DE)': 'de-DE-Chirp3-HD-Callirrhoe',
    'Despina (de-DE)': 'de-DE-Chirp3-HD-Despina', 'Achird (de-DE)': 'de-DE-Chirp3-HD-Achird',
    'Algenib (de-DE)': 'de-DE-Chirp3-HD-Algenib', 'Algieba (de-DE)': 'de-DE-Chirp3-HD-Algieba',
    'Alnilam (de-DE)': 'de-DE-Chirp3-HD-Alnilam', 'Charon (de-DE)': 'de-DE-Chirp3-HD-Charon',
  };

  static const Map<String, String> gujaratiVoices = {
    'Achernar (gu-IN)': 'gu-IN-Chirp3-HD-Achernar', 'Aoede (gu-IN)': 'gu-IN-Chirp3-HD-Aoede',
    'Autonoe (gu-IN)': 'gu-IN-Chirp3-HD-Autonoe', 'Callirrhoe (gu-IN)': 'gu-IN-Chirp3-HD-Callirrhoe',
    'Despina (gu-IN)': 'gu-IN-Chirp3-HD-Despina', 'Achird (gu-IN)': 'gu-IN-Chirp3-HD-Achird',
    'Algenib (gu-IN)': 'gu-IN-Chirp3-HD-Algenib', 'Algieba (gu-IN)': 'gu-IN-Chirp3-HD-Algieba',
    'Alnilam (gu-IN)': 'gu-IN-Chirp3-HD-Alnilam', 'Charon (gu-IN)': 'gu-IN-Chirp3-HD-Charon',
  };

  static const Map<String, String> hindiVoices = {
    'Achernar (hi-IN)': 'hi-IN-Chirp3-HD-Achernar', 'Aoede (hi-IN)': 'hi-IN-Chirp3-HD-Aoede',
    'Autonoe (hi-IN)': 'hi-IN-Chirp3-HD-Autonoe', 'Callirrhoe (hi-IN)': 'hi-IN-Chirp3-HD-Callirrhoe',
    'Despina (hi-IN)': 'hi-IN-Chirp3-HD-Despina', 'Achird (hi-IN)': 'hi-IN-Chirp3-HD-Achird',
    'Algenib (hi-IN)': 'hi-IN-Chirp3-HD-Algenib', 'Algieba (hi-IN)': 'hi-IN-Chirp3-HD-Algieba',
    'Alnilam (hi-IN)': 'hi-IN-Chirp3-HD-Alnilam', 'Charon (hi-IN)': 'hi-IN-Chirp3-HD-Charon',
  };

  static const Map<String, String> italianVoices = {
    'Achernar (it-IT)': 'it-IT-Chirp3-HD-Achernar', 'Aoede (it-IT)': 'it-IT-Chirp3-HD-Aoede',
    'Autonoe (it-IT)': 'it-IT-Chirp3-HD-Autonoe', 'Callirrhoe (it-IT)': 'it-IT-Chirp3-HD-Callirrhoe',
    'Despina (it-IT)': 'it-IT-Chirp3-HD-Despina', 'Achird (it-IT)': 'it-IT-Chirp3-HD-Achird',
    'Algenib (it-IT)': 'it-IT-Chirp3-HD-Algenib', 'Algieba (it-IT)': 'it-IT-Chirp3-HD-Algieba',
    'Alnilam (it-IT)': 'it-IT-Chirp3-HD-Alnilam', 'Charon (it-IT)': 'it-IT-Chirp3-HD-Charon',
  };

  static const Map<String, String> japaneseVoices = {
    'Achernar (ja-JP)': 'ja-JP-Chirp3-HD-Achernar', 'Aoede (ja-JP)': 'ja-JP-Chirp3-HD-Aoede',
    'Autonoe (ja-JP)': 'ja-JP-Chirp3-HD-Autonoe', 'Callirrhoe (ja-JP)': 'ja-JP-Chirp3-HD-Callirrhoe',
    'Despina (ja-JP)': 'ja-JP-Chirp3-HD-Despina', 'Achird (ja-JP)': 'ja-JP-Chirp3-HD-Achird',
    'Algenib (ja-JP)': 'ja-JP-Chirp3-HD-Algenib', 'Algieba (ja-JP)': 'ja-JP-Chirp3-HD-Algieba',
    'Alnilam (ja-JP)': 'ja-JP-Chirp3-HD-Alnilam', 'Charon (ja-JP)': 'ja-JP-Chirp3-HD-Charon',
  };

  static const Map<String, String> kannadaVoices = {
    'Achernar (kn-IN)': 'kn-IN-Chirp3-HD-Achernar', 'Aoede (kn-IN)': 'kn-IN-Chirp3-HD-Aoede',
    'Autonoe (kn-IN)': 'kn-IN-Chirp3-HD-Autonoe', 'Callirrhoe (kn-IN)': 'kn-IN-Chirp3-HD-Callirrhoe',
    'Despina (kn-IN)': 'kn-IN-Chirp3-HD-Despina', 'Achird (kn-IN)': 'kn-IN-Chirp3-HD-Achird',
    'Algenib (kn-IN)': 'kn-IN-Chirp3-HD-Algenib', 'Algieba (kn-IN)': 'kn-IN-Chirp3-HD-Algieba',
    'Alnilam (kn-IN)': 'kn-IN-Chirp3-HD-Alnilam', 'Charon (kn-IN)': 'kn-IN-Chirp3-HD-Charon',
  };

  static const Map<String, String> koreanVoices = {
    'Achernar (ko-KR)': 'ko-KR-Chirp3-HD-Achernar', 'Aoede (ko-KR)': 'ko-KR-Chirp3-HD-Aoede',
    'Autonoe (ko-KR)': 'ko-KR-Chirp3-HD-Autonoe', 'Callirrhoe (ko-KR)': 'ko-KR-Chirp3-HD-Callirrhoe',
    'Despina (ko-KR)': 'ko-KR-Chirp3-HD-Despina', 'Achird (ko-KR)': 'ko-KR-Chirp3-HD-Achird',
    'Algenib (ko-KR)': 'ko-KR-Chirp3-HD-Algenib', 'Algieba (ko-KR)': 'ko-KR-Chirp3-HD-Algieba',
    'Alnilam (ko-KR)': 'ko-KR-Chirp3-HD-Alnilam', 'Charon (ko-KR)': 'ko-KR-Chirp3-HD-Charon',
  };

  static const Map<String, String> malayalamVoices = {
    'Achernar (ml-IN)': 'ml-IN-Chirp3-HD-Achernar', 'Aoede (ml-IN)': 'ml-IN-Chirp3-HD-Aoede',
    'Autonoe (ml-IN)': 'ml-IN-Chirp3-HD-Autonoe', 'Callirrhoe (ml-IN)': 'ml-IN-Chirp3-HD-Callirrhoe',
    'Despina (ml-IN)': 'ml-IN-Chirp3-HD-Despina', 'Achird (ml-IN)': 'ml-IN-Chirp3-HD-Achird',
    'Algenib (ml-IN)': 'ml-IN-Chirp3-HD-Algenib', 'Algieba (ml-IN)': 'ml-IN-Chirp3-HD-Algieba',
    'Alnilam (ml-IN)': 'ml-IN-Chirp3-HD-Alnilam', 'Charon (ml-IN)': 'ml-IN-Chirp3-HD-Charon',
  };

  static const Map<String, String> mandarinVoices = {
    'Achernar (cmn-CN)': 'cmn-CN-Chirp3-HD-Achernar', 'Aoede (cmn-CN)': 'cmn-CN-Chirp3-HD-Aoede',
    'Autonoe (cmn-CN)': 'cmn-CN-Chirp3-HD-Autonoe', 'Callirrhoe (cmn-CN)': 'cmn-CN-Chirp3-HD-Callirrhoe',
    'Despina (cmn-CN)': 'cmn-CN-Chirp3-HD-Despina', 'Achird (cmn-CN)': 'cmn-CN-Chirp3-HD-Achird',
    'Algenib (cmn-CN)': 'cmn-CN-Chirp3-HD-Algenib', 'Algieba (cmn-CN)': 'cmn-CN-Chirp3-HD-Algieba',
    'Alnilam (cmn-CN)': 'cmn-CN-Chirp3-HD-Alnilam', 'Charon (cmn-CN)': 'cmn-CN-Chirp3-HD-Charon',
  };

  static const Map<String, String> marathiVoices = {
    'Achernar (mr-IN)': 'mr-IN-Chirp3-HD-Achernar', 'Aoede (mr-IN)': 'mr-IN-Chirp3-HD-Aoede',
    'Autonoe (mr-IN)': 'mr-IN-Chirp3-HD-Autonoe', 'Callirrhoe (mr-IN)': 'mr-IN-Chirp3-HD-Callirrhoe',
    'Despina (mr-IN)': 'mr-IN-Chirp3-HD-Despina', 'Achird (mr-IN)': 'mr-IN-Chirp3-HD-Achird',
    'Algenib (mr-IN)': 'mr-IN-Chirp3-HD-Algenib', 'Algieba (mr-IN)': 'mr-IN-Chirp3-HD-Algieba',
    'Alnilam (mr-IN)': 'mr-IN-Chirp3-HD-Alnilam', 'Charon (mr-IN)': 'mr-IN-Chirp3-HD-Charon',
  };

  static const Map<String, String> norwegianVoices = {
    'Achernar (nb-NO)': 'nb-NO-Chirp3-HD-Achernar', 'Aoede (nb-NO)': 'nb-NO-Chirp3-HD-Aoede',
    'Autonoe (nb-NO)': 'nb-NO-Chirp3-HD-Autonoe', 'Callirrhoe (nb-NO)': 'nb-NO-Chirp3-HD-Callirrhoe',
    'Despina (nb-NO)': 'nb-NO-Chirp3-HD-Despina', 'Achird (nb-NO)': 'nb-NO-Chirp3-HD-Achird',
    'Algenib (nb-NO)': 'nb-NO-Chirp3-HD-Algenib', 'Algieba (nb-NO)': 'nb-NO-Chirp3-HD-Algieba',
    'Alnilam (nb-NO)': 'nb-NO-Chirp3-HD-Alnilam', 'Charon (nb-NO)': 'nb-NO-Chirp3-HD-Charon',
  };

  static const Map<String, String> polishVoices = {
    'Achernar (pl-PL)': 'pl-PL-Chirp3-HD-Achernar', 'Aoede (pl-PL)': 'pl-PL-Chirp3-HD-Aoede',
    'Autonoe (pl-PL)': 'pl-PL-Chirp3-HD-Autonoe', 'Callirrhoe (pl-PL)': 'pl-PL-Chirp3-HD-Callirrhoe',
    'Despina (pl-PL)': 'pl-PL-Chirp3-HD-Despina', 'Achird (pl-PL)': 'pl-PL-Chirp3-HD-Achird',
    'Algenib (pl-PL)': 'pl-PL-Chirp3-HD-Algenib', 'Algieba (pl-PL)': 'pl-PL-Chirp3-HD-Algieba',
    'Alnilam (pl-PL)': 'pl-PL-Chirp3-HD-Alnilam', 'Charon (pl-PL)': 'pl-PL-Chirp3-HD-Charon',
  };

  static const Map<String, String> portugueseBrazilVoices = {
    'Achernar (pt-BR)': 'pt-BR-Chirp3-HD-Achernar', 'Aoede (pt-BR)': 'pt-BR-Chirp3-HD-Aoede',
    'Autonoe (pt-BR)': 'pt-BR-Chirp3-HD-Autonoe', 'Callirrhoe (pt-BR)': 'pt-BR-Chirp3-HD-Callirrhoe',
    'Despina (pt-BR)': 'pt-BR-Chirp3-HD-Despina', 'Achird (pt-BR)': 'pt-BR-Chirp3-HD-Achird',
    'Algenib (pt-BR)': 'pt-BR-Chirp3-HD-Algenib', 'Algieba (pt-BR)': 'pt-BR-Chirp3-HD-Algieba',
    'Alnilam (pt-BR)': 'pt-BR-Chirp3-HD-Alnilam', 'Charon (pt-BR)': 'pt-BR-Chirp3-HD-Charon',
  };

  static const Map<String, String> russianVoices = {
    'Aoede (ru-RU)': 'ru-RU-Chirp3-HD-Aoede', 'Kore (ru-RU)': 'ru-RU-Chirp3-HD-Kore',
    'Leda (ru-RU)': 'ru-RU-Chirp3-HD-Leda', 'Zephyr (ru-RU)': 'ru-RU-Chirp3-HD-Zephyr',
    'Achernar (ru-RU)': 'ru-RU-Chirp3-HD-Achernar', 'Charon (ru-RU)': 'ru-RU-Chirp3-HD-Charon',
    'Fenrir (ru-RU)': 'ru-RU-Chirp3-HD-Fenrir', 'Orus (ru-RU)': 'ru-RU-Chirp3-HD-Orus',
    'Puck (ru-RU)': 'ru-RU-Chirp3-HD-Puck', 'Achird (ru-RU)': 'ru-RU-Chirp3-HD-Achird',
  };

  static const Map<String, String> spanishSpainVoices = {
    'Achernar (es-ES)': 'es-ES-Chirp3-HD-Achernar', 'Aoede (es-ES)': 'es-ES-Chirp3-HD-Aoede',
    'Autonoe (es-ES)': 'es-ES-Chirp3-HD-Autonoe', 'Callirrhoe (es-ES)': 'es-ES-Chirp3-HD-Callirrhoe',
    'Despina (es-ES)': 'es-ES-Chirp3-HD-Despina', 'Achird (es-ES)': 'es-ES-Chirp3-HD-Achird',
    'Algenib (es-ES)': 'es-ES-Chirp3-HD-Algenib', 'Algieba (es-ES)': 'es-ES-Chirp3-HD-Algieba',
    'Alnilam (es-ES)': 'es-ES-Chirp3-HD-Alnilam', 'Charon (es-ES)': 'es-ES-Chirp3-HD-Charon',
  };

  static const Map<String, String> spanishUSVoices = {
    'Achernar (es-US)': 'es-US-Chirp3-HD-Achernar', 'Aoede (es-US)': 'es-US-Chirp3-HD-Aoede',
    'Autonoe (es-US)': 'es-US-Chirp3-HD-Autonoe', 'Callirrhoe (es-US)': 'es-US-Chirp3-HD-Callirrhoe',
    'Despina (es-US)': 'es-US-Chirp3-HD-Despina', 'Achird (es-US)': 'es-US-Chirp3-HD-Achird',
    'Algenib (es-US)': 'es-US-Chirp3-HD-Algenib', 'Algieba (es-US)': 'es-US-Chirp3-HD-Algieba',
    'Alnilam (es-US)': 'es-US-Chirp3-HD-Alnilam', 'Charon (es-US)': 'es-US-Chirp3-HD-Charon',
  };

  static const Map<String, String> swedishVoices = {
    'Achernar (sv-SE)': 'sv-SE-Chirp3-HD-Achernar', 'Aoede (sv-SE)': 'sv-SE-Chirp3-HD-Aoede',
    'Autonoe (sv-SE)': 'sv-SE-Chirp3-HD-Autonoe', 'Callirrhoe (sv-SE)': 'sv-SE-Chirp3-HD-Callirrhoe',
    'Despina (sv-SE)': 'sv-SE-Chirp3-HD-Despina', 'Achird (sv-SE)': 'sv-SE-Chirp3-HD-Achird',
    'Algenib (sv-SE)': 'sv-SE-Chirp3-HD-Algenib', 'Algieba (sv-SE)': 'sv-SE-Chirp3-HD-Algieba',
    'Alnilam (sv-SE)': 'sv-SE-Chirp3-HD-Alnilam', 'Charon (sv-SE)': 'sv-SE-Chirp3-HD-Charon',
  };

  static const Map<String, String> tamilVoices = {
    'Achernar (ta-IN)': 'ta-IN-Chirp3-HD-Achernar', 'Aoede (ta-IN)': 'ta-IN-Chirp3-HD-Aoede',
    'Autonoe (ta-IN)': 'ta-IN-Chirp3-HD-Autonoe', 'Callirrhoe (ta-IN)': 'ta-IN-Chirp3-HD-Callirrhoe',
    'Despina (ta-IN)': 'ta-IN-Chirp3-HD-Despina', 'Achird (ta-IN)': 'ta-IN-Chirp3-HD-Achird',
    'Algenib (ta-IN)': 'ta-IN-Chirp3-HD-Algenib', 'Algieba (ta-IN)': 'ta-IN-Chirp3-HD-Algieba',
    'Alnilam (ta-IN)': 'ta-IN-Chirp3-HD-Alnilam', 'Charon (ta-IN)': 'ta-IN-Chirp3-HD-Charon',
  };

  static const Map<String, String> teluguVoices = {
    'Achernar (te-IN)': 'te-IN-Chirp3-HD-Achernar', 'Aoede (te-IN)': 'te-IN-Chirp3-HD-Aoede',
    'Autonoe (te-IN)': 'te-IN-Chirp3-HD-Autonoe', 'Callirrhoe (te-IN)': 'te-IN-Chirp3-HD-Callirrhoe',
    'Despina (te-IN)': 'te-IN-Chirp3-HD-Despina', 'Achird (te-IN)': 'te-IN-Chirp3-HD-Achird',
    'Algenib (te-IN)': 'te-IN-Chirp3-HD-Algenib', 'Algieba (te-IN)': 'te-IN-Chirp3-HD-Algieba',
    'Alnilam (te-IN)': 'te-IN-Chirp3-HD-Alnilam', 'Charon (te-IN)': 'te-IN-Chirp3-HD-Charon',
  };

  static const Map<String, String> thaiVoices = {
    'Achernar (th-TH)': 'th-TH-Chirp3-HD-Achernar', 'Aoede (th-TH)': 'th-TH-Chirp3-HD-Aoede',
    'Autonoe (th-TH)': 'th-TH-Chirp3-HD-Autonoe', 'Callirrhoe (th-TH)': 'th-TH-Chirp3-HD-Callirrhoe',
    'Despina (th-TH)': 'th-TH-Chirp3-HD-Despina', 'Achird (th-TH)': 'th-TH-Chirp3-HD-Achird',
    'Algenib (th-TH)': 'th-TH-Chirp3-HD-Algenib', 'Algieba (th-TH)': 'th-TH-Chirp3-HD-Algieba',
    'Alnilam (th-TH)': 'th-TH-Chirp3-HD-Alnilam', 'Charon (th-TH)': 'th-TH-Chirp3-HD-Charon',
  };

  static const Map<String, String> turkishVoices = {
    'Achernar (tr-TR)': 'tr-TR-Chirp3-HD-Achernar', 'Aoede (tr-TR)': 'tr-TR-Chirp3-HD-Aoede',
    'Autonoe (tr-TR)': 'tr-TR-Chirp3-HD-Autonoe', 'Callirrhoe (tr-TR)': 'tr-TR-Chirp3-HD-Callirrhoe',
    'Despina (tr-TR)': 'tr-TR-Chirp3-HD-Despina', 'Achird (tr-TR)': 'tr-TR-Chirp3-HD-Achird',
    'Algenib (tr-TR)': 'tr-TR-Chirp3-HD-Algenib', 'Algieba (tr-TR)': 'tr-TR-Chirp3-HD-Algieba',
    'Alnilam (tr-TR)': 'tr-TR-Chirp3-HD-Alnilam', 'Charon (tr-TR)': 'tr-TR-Chirp3-HD-Charon',
  };

  static const Map<String, String> ukrainianVoices = {
    'Achernar (uk-UA)': 'uk-UA-Chirp3-HD-Achernar', 'Aoede (uk-UA)': 'uk-UA-Chirp3-HD-Aoede',
    'Autonoe (uk-UA)': 'uk-UA-Chirp3-HD-Autonoe', 'Callirrhoe (uk-UA)': 'uk-UA-Chirp3-HD-Callirrhoe',
    'Despina (uk-UA)': 'uk-UA-Chirp3-HD-Despina', 'Achird (uk-UA)': 'uk-UA-Chirp3-HD-Achird',
    'Algenib (uk-UA)': 'uk-UA-Chirp3-HD-Algenib', 'Algieba (uk-UA)': 'uk-UA-Chirp3-HD-Algieba',
    'Alnilam (uk-UA)': 'uk-UA-Chirp3-HD-Alnilam', 'Charon (uk-UA)': 'uk-UA-Chirp3-HD-Charon',
  };

  static const Map<String, String> urduIndiaVoices = {
    'Achernar (ur-IN)': 'ur-IN-Chirp3-HD-Achernar', 'Aoede (ur-IN)': 'ur-IN-Chirp3-HD-Aoede',
    'Autonoe (ur-IN)': 'ur-IN-Chirp3-HD-Autonoe', 'Callirrhoe (ur-IN)': 'ur-IN-Chirp3-HD-Callirrhoe',
    'Despina (ur-IN)': 'ur-IN-Chirp3-HD-Despina', 'Achird (ur-IN)': 'ur-IN-Chirp3-HD-Achird',
    'Algenib (ur-IN)': 'ur-IN-Chirp3-HD-Algenib', 'Algieba (ur-IN)': 'ur-IN-Chirp3-HD-Algieba',
    'Alnilam (ur-IN)': 'ur-IN-Chirp3-HD-Alnilam', 'Charon (ur-IN)': 'ur-IN-Chirp3-HD-Charon',
  };

  static const Map<String, String> vietnameseVoices = {
    'Achernar (vi-VN)': 'vi-VN-Chirp3-HD-Achernar', 'Aoede (vi-VN)': 'vi-VN-Chirp3-HD-Aoede',
    'Autonoe (vi-VN)': 'vi-VN-Chirp3-HD-Autonoe', 'Callirrhoe (vi-VN)': 'vi-VN-Chirp3-HD-Callirrhoe',
    'Despina (vi-VN)': 'vi-VN-Chirp3-HD-Despina', 'Achird (vi-VN)': 'vi-VN-Chirp3-HD-Achird',
    'Algenib (vi-VN)': 'vi-VN-Chirp3-HD-Algenib', 'Algieba (vi-VN)': 'vi-VN-Chirp3-HD-Algieba',
    'Alnilam (vi-VN)': 'vi-VN-Chirp3-HD-Alnilam', 'Charon (vi-VN)': 'vi-VN-Chirp3-HD-Charon',
  };

  static Map<String, String> getVoicesForLanguage(String language) {
    switch (language) {
      case 'Indonesian': return indonesianVoices;
      case 'English (US)': return englishUSVoices;
      case 'English (UK)': return englishUKVoices;
      case 'English (Australia)': return englishAustraliaVoices;
      case 'English (India)': return englishIndiaVoices;
      case 'Arabic': return arabicVoices;
      case 'Bengali (India)': return bengaliVoices;
      case 'Danish': return danishVoices;
      case 'Dutch (Netherlands)': return dutchNetherlandsVoices;
      case 'Dutch (Belgium)': return dutchBelgiumVoices;
      case 'Finnish': return finnishVoices;
      case 'French (France)': return frenchFranceVoices;
      case 'French (Canada)': return frenchCanadaVoices;
      case 'German': return germanVoices;
      case 'Gujarati': return gujaratiVoices;
      case 'Hindi': return hindiVoices;
      case 'Italian': return italianVoices;
      case 'Japanese': return japaneseVoices;
      case 'Kannada': return kannadaVoices;
      case 'Korean': return koreanVoices;
      case 'Malayalam': return malayalamVoices;
      case 'Mandarin Chinese': return mandarinVoices;
      case 'Marathi': return marathiVoices;
      case 'Norwegian': return norwegianVoices;
      case 'Polish': return polishVoices;
      case 'Portuguese (Brazil)': return portugueseBrazilVoices;
      case 'Russian': return russianVoices;
      case 'Spanish (Spain)': return spanishSpainVoices;
      case 'Spanish (US)': return spanishUSVoices;
      case 'Swedish': return swedishVoices;
      case 'Tamil': return tamilVoices;
      case 'Telugu': return teluguVoices;
      case 'Thai': return thaiVoices;
      case 'Turkish': return turkishVoices;
      case 'Ukrainian': return ukrainianVoices;
      case 'Urdu': return urduIndiaVoices;
      case 'Vietnamese': return vietnameseVoices;
      default: return indonesianVoices;
    }
  }
}
// END OF BLOK 2 //
//================================================================//

//No ke-3: CORE VIEW MODEL LOGIC, ENGINE API & AUDIO HANDLER      //
//VALIDASI 20.000 CHAR, CALL FUNCTION JAKARTA, FIRESTORE & AUDIO  //
class T2SpeechViewModel extends StateNotifier<T2SpeechState> {
  final TextEditingController textController = TextEditingController();
  final AudioPlayer audioPlayer = AudioPlayer();
  final Ref _ref;

  // Stream subscription untuk audio player agar bisa di-cancel saat dispose
  StreamSubscription<PlayerState>? _playerStateSubscription;

  // Endpoint Cloud Function Gen 2 Jakarta
  final String _engineUrl = "https://asia-southeast2-majiku-5b07e.cloudfunctions.net/generatorT2Speech";

  T2SpeechViewModel(this._ref) : super(const T2SpeechState()) {
    _initializeData();
    _setupAudioPlayerListeners();
  }

  void _initializeData() {
    final defaultLanguage = 'Indonesian';
    final initialVoices = T2SpeechVoiceDatabase.getVoicesForLanguage(defaultLanguage);
    final defaultVoice = initialVoices.values.first;

    state = state.copyWith(
      availableLanguages: T2SpeechVoiceDatabase.languageList,
      selectedLanguage: defaultLanguage,
      currentVoiceOptions: initialVoices,
      selectedVoice: defaultVoice,
    );
  }

  void _setupAudioPlayerListeners() {
    _playerStateSubscription = audioPlayer.onPlayerStateChanged.listen((playerState) {
      // Proteksi anti-crash: pastikan ViewModel masih mounted sebelum update state
      if (!mounted) return;
      state = state.copyWith(isPlaying: playerState == PlayerState.playing);
    });
  }

  void setLanguage(String? language) {
    if (language == null || language == state.selectedLanguage) return;

    final voices = T2SpeechVoiceDatabase.getVoicesForLanguage(language);
    final defaultVoice = voices.isNotEmpty ? voices.values.first : '';

    if (!mounted) return;
    state = state.copyWith(
      selectedLanguage: language,
      currentVoiceOptions: voices,
      selectedVoice: defaultVoice,
      clearError: true,
      clearSuccess: true,
    );
  }

  void setVoice(String? voice) {
    if (voice == null || voice == state.selectedVoice) return;
    if (!mounted) return;
    state = state.copyWith(selectedVoice: voice, clearError: true, clearSuccess: true);
  }

  // --- CORE GENERATOR DENGAN VALIDASI 20.000 KARAKTER & BEARER TOKEN ---
  Future<void> generateSpeech() async {
    if (state.isLoading) return;
    final text = textController.text.trim();

    if (text.isEmpty) {
      if (!mounted) return;
      state = state.copyWith(
        errorMessage: T2SpeechLocalizationHelper.get('alertNoInput'),
        clearError: false,
      );
      return;
    }

    if (text.length > 10000) {
      if (!mounted) return;
      state = state.copyWith(
        errorMessage: T2SpeechLocalizationHelper.get('alertExceedLimit'),
        clearError: false,
      );
      return;
    }

    if (!mounted) return;
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearSuccess: true,
      loadingText: T2SpeechLocalizationHelper.get('statusGenerating'),
    );

    try {
      // 1. Validasi Token Keamanan Firebase Auth
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception(T2SpeechLocalizationHelper.get('alertNoAuth'));
      }
      final String? idToken = await user.getIdToken();

      // 2. Ekstraksi kode bahasa dari voice ID (cth: id-ID dari id-ID-Chirp3-HD-Achernar)
      final voiceParts = state.selectedVoice.split('-');
      final languageCode = voiceParts.length >= 2 ? "${voiceParts[0]}-${voiceParts[1]}" : "id-ID";

      // 3. Menyusun Payload JSON
      final body = jsonEncode({
        'data': {
          'text': text,
          'voice': state.selectedVoice,
          'language': state.selectedLanguage,
          'languageCode': languageCode,
        }
      });

      // 4. Eksekusi Request HTTP ke Cloud Function Gen 2 Jakarta
      final response = await http.post(
        Uri.parse(_engineUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: body,
      ).timeout(const Duration(minutes: 5));

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        final audioUrl = responseBody['data'];

        if (audioUrl != null && audioUrl.toString().isNotEmpty) {
          // 5. Simpan Proyek ke Firestore Riwayat T2Speech
          try {
            final firestoreService = FirestoreT2SpeechService();
            final projectData = AudioProjectT2Speech(
              id: '',
              userId: user.uid,
              text: text,
              audioUrl: audioUrl.toString(),
              voice: state.selectedVoice,
              language: state.selectedLanguage,
              createdAt: DateTime.now(),
            );
            await firestoreService.saveProject(projectData);
          } catch (dbError) {
            debugPrint("Peringatan: Gagal menyimpan riwayat T2Speech: $dbError");
          }

          if (!mounted) return;
          state = state.copyWith(
            isLoading: false,
            generatedAudioUrl: audioUrl.toString(),
            loadingText: '',
            successMessage: T2SpeechLocalizationHelper.get('statusSuccess'),
          );
        } else {
          throw Exception("URL audio tidak ditemukan dalam respon server.");
        }
      } else {
        final errorResp = jsonDecode(response.body);
        final errorMsg = errorResp['error']?['message'] ?? response.body;
        throw Exception("Server Error (${response.statusCode}): $errorMsg");
      }
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        errorMessage: T2SpeechLocalizationHelper.get('alertApiError')
            .replaceFirst('{message}', e.toString().replaceAll("Exception:", "").trim()),
        loadingText: '',
      );
    }
  }

  // --- AUDIO PLAYBACK CONTROLS ---
  Future<void> playAudio() async {
    if (state.generatedAudioUrl.isEmpty) return;

    try {
      if (state.isPlaying) {
        await audioPlayer.pause();
      } else {
        await audioPlayer.play(UrlSource(state.generatedAudioUrl));
      }
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        errorMessage: "Gagal memutar audio: ${e.toString()}",
        clearError: false,
      );
    }
  }

  Future<void> stopAudio() async {
    try {
      await audioPlayer.stop();
    } catch (_) {}
  }

  // --- DOWNLOAD DELEGATION (NATIVE & WEB SAFE) ---
  Future<void> downloadAudio() async {
    if (state.generatedAudioUrl.isEmpty) return;

    try {
      final Uri url = Uri.parse(state.generatedAudioUrl);
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw Exception('Sistem menolak membuka tautan unduhan.');
      }

      if (!mounted) return;
      state = state.copyWith(
        successMessage: T2SpeechLocalizationHelper.get('statusDownloadSuccess'),
        clearError: true,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        errorMessage: T2SpeechLocalizationHelper.get('statusDownloadFailed')
            .replaceFirst('{error}', e.toString()),
        clearError: false,
      );
    }
  }

  // --- RESET STATE ---
  void clearAll() {
    textController.clear();
    stopAudio();
    _initializeData();
    if (!mounted) return;
    state = state.copyWith(
      generatedAudioUrl: '',
      clearError: true,
      clearSuccess: true,
      isLoading: false,
      isPlaying: false,
    );
  }

  @override
  void dispose() {
    // 1. Batalkan listener audio player agar tidak mentrigger state saat unmounted
    _playerStateSubscription?.cancel();
    textController.dispose();
    audioPlayer.dispose();
    super.dispose();
  }
}
// END OF BLOK 3 //
//================================================================//

//No ke-4: RIVERPOD PROVIDER REGISTRATION                         //
//PENYEDIA INSTANCE STATE NOTIFIER T2SPEECH UNTUK UI              //
final t2SpeechViewModelProvider = StateNotifierProvider.autoDispose<
    T2SpeechViewModel, T2SpeechState>(
  (ref) => T2SpeechViewModel(ref),
);
// END OF BLOK 4 //
//================================================================//