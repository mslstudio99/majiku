// No ke-1: IMPORTS, MODELS & STATE CLASS               //
//......................................................//
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb; // Deteksi platform
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:universal_html/html.dart' as html; // Utilitas download Web

import '../services_daily_free/firestore_free_t2speech_service.dart';

class VoiceModel {
  final String id; 
  final String name; 
  final String gender; 

  VoiceModel({required this.id, required this.name, required this.gender});
}

class FreeT2SpeechState {
  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;
  
  final String? selectedLanguage;
  final String? selectedVoice;
  
  final List<String> availableLanguages;
  final List<VoiceModel> availableVoices;
  
  final String? generatedAudioBase64;

  FreeT2SpeechState({
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
    this.selectedLanguage,
    this.selectedVoice,
    this.availableLanguages = const [],
    this.availableVoices = const [],
    this.generatedAudioBase64,
  });

  FreeT2SpeechState copyWith({
    bool? isLoading,
    String? errorMessage,
    String? successMessage,
    String? selectedLanguage,
    String? selectedVoice,
    List<String>? availableLanguages,
    List<VoiceModel>? availableVoices,
    String? generatedAudioBase64,
    bool clearMessages = false,
    bool resetVoice = false, 
  }) {
    return FreeT2SpeechState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearMessages ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearMessages ? null : (successMessage ?? this.successMessage),
      selectedLanguage: selectedLanguage ?? this.selectedLanguage,
      selectedVoice: resetVoice ? null : (selectedVoice ?? this.selectedVoice), 
      availableLanguages: availableLanguages ?? this.availableLanguages,
      availableVoices: availableVoices ?? this.availableVoices,
      generatedAudioBase64: generatedAudioBase64 ?? this.generatedAudioBase64,
    );
  }
}
// Penutup Blok //


// No ke-2: DATASET WAVENET GOOGLE CLOUD TTS            //
//......................................................//
const Map<String, List<Map<String, String>>> rawVoiceDatabase = {
  'Arabic': [
    {'id': 'ar-XA-Wavenet-A', 'gender': 'FEMALE'}, {'id': 'ar-XA-Wavenet-B', 'gender': 'MALE'},
    {'id': 'ar-XA-Wavenet-C', 'gender': 'MALE'}, {'id': 'ar-XA-Wavenet-D', 'gender': 'FEMALE'},
  ],
  'Bengali (India)': [
    {'id': 'bn-IN-Wavenet-A', 'gender': 'FEMALE'}, {'id': 'bn-IN-Wavenet-B', 'gender': 'MALE'},
    {'id': 'bn-IN-Wavenet-C', 'gender': 'FEMALE'}, {'id': 'bn-IN-Wavenet-D', 'gender': 'MALE'},
  ],
  'Czech': [{'id': 'cs-CZ-Wavenet-B', 'gender': 'FEMALE'}],
  'Danish': [{'id': 'da-DK-Wavenet-F', 'gender': 'FEMALE'}, {'id': 'da-DK-Wavenet-G', 'gender': 'MALE'}],
  'Dutch (Belgium)': [{'id': 'nl-BE-Wavenet-C', 'gender': 'FEMALE'}, {'id': 'nl-BE-Wavenet-D', 'gender': 'MALE'}],
  'Dutch (Netherlands)': [{'id': 'nl-NL-Wavenet-F', 'gender': 'FEMALE'}, {'id': 'nl-NL-Wavenet-G', 'gender': 'MALE'}],
  'English (Australia)': [
    {'id': 'en-AU-Wavenet-A', 'gender': 'FEMALE'}, {'id': 'en-AU-Wavenet-B', 'gender': 'MALE'},
    {'id': 'en-AU-Wavenet-C', 'gender': 'FEMALE'}, {'id': 'en-AU-Wavenet-D', 'gender': 'MALE'},
  ],
  'English (India)': [
    {'id': 'en-IN-Wavenet-A', 'gender': 'FEMALE'}, {'id': 'en-IN-Wavenet-B', 'gender': 'MALE'},
    {'id': 'en-IN-Wavenet-C', 'gender': 'MALE'}, {'id': 'en-IN-Wavenet-D', 'gender': 'FEMALE'},
    {'id': 'en-IN-Wavenet-E', 'gender': 'FEMALE'}, {'id': 'en-IN-Wavenet-F', 'gender': 'MALE'},
  ],
  'English (UK)': [
    {'id': 'en-GB-Wavenet-A', 'gender': 'FEMALE'}, {'id': 'en-GB-Wavenet-B', 'gender': 'MALE'},
    {'id': 'en-GB-Wavenet-C', 'gender': 'FEMALE'}, {'id': 'en-GB-Wavenet-D', 'gender': 'MALE'},
    {'id': 'en-GB-Wavenet-F', 'gender': 'FEMALE'}, {'id': 'en-GB-Wavenet-N', 'gender': 'FEMALE'},
    {'id': 'en-GB-Wavenet-O', 'gender': 'MALE'},
  ],
  'English (US)': [
    {'id': 'en-US-Wavenet-A', 'gender': 'MALE'}, {'id': 'en-US-Wavenet-B', 'gender': 'MALE'},
    {'id': 'en-US-Wavenet-C', 'gender': 'FEMALE'}, {'id': 'en-US-Wavenet-D', 'gender': 'MALE'},
    {'id': 'en-US-Wavenet-E', 'gender': 'FEMALE'}, {'id': 'en-US-Wavenet-F', 'gender': 'FEMALE'},
    {'id': 'en-US-Wavenet-G', 'gender': 'FEMALE'}, {'id': 'en-US-Wavenet-H', 'gender': 'FEMALE'},
    {'id': 'en-US-Wavenet-I', 'gender': 'MALE'}, {'id': 'en-US-Wavenet-J', 'gender': 'MALE'},
  ],
  'Filipino': [
    {'id': 'fil-PH-Wavenet-A', 'gender': 'FEMALE'}, {'id': 'fil-PH-Wavenet-B', 'gender': 'FEMALE'},
    {'id': 'fil-PH-Wavenet-C', 'gender': 'MALE'}, {'id': 'fil-PH-Wavenet-D', 'gender': 'MALE'},
  ],
  'Finnish': [{'id': 'fi-FI-Wavenet-B', 'gender': 'FEMALE'}],
  'French (Canada)': [
    {'id': 'fr-CA-Wavenet-A', 'gender': 'FEMALE'}, {'id': 'fr-CA-Wavenet-B', 'gender': 'MALE'},
    {'id': 'fr-CA-Wavenet-C', 'gender': 'FEMALE'}, {'id': 'fr-CA-Wavenet-D', 'gender': 'MALE'},
  ],
  'French (France)': [{'id': 'fr-FR-Wavenet-F', 'gender': 'FEMALE'}, {'id': 'fr-FR-Wavenet-G', 'gender': 'MALE'}],
  'German': [{'id': 'de-DE-Wavenet-G', 'gender': 'FEMALE'}, {'id': 'de-DE-Wavenet-H', 'gender': 'MALE'}],
  'Greek': [{'id': 'el-GR-Wavenet-B', 'gender': 'FEMALE'}],
  'Gujarati': [
    {'id': 'gu-IN-Wavenet-A', 'gender': 'FEMALE'}, {'id': 'gu-IN-Wavenet-B', 'gender': 'MALE'},
    {'id': 'gu-IN-Wavenet-C', 'gender': 'FEMALE'}, {'id': 'gu-IN-Wavenet-D', 'gender': 'MALE'},
  ],
  'Hebrew': [
    {'id': 'he-IL-Wavenet-A', 'gender': 'FEMALE'}, {'id': 'he-IL-Wavenet-B', 'gender': 'MALE'},
    {'id': 'he-IL-Wavenet-C', 'gender': 'FEMALE'}, {'id': 'he-IL-Wavenet-D', 'gender': 'MALE'},
  ],
  'Hindi': [
    {'id': 'hi-IN-Wavenet-A', 'gender': 'FEMALE'}, {'id': 'hi-IN-Wavenet-B', 'gender': 'MALE'},
    {'id': 'hi-IN-Wavenet-C', 'gender': 'MALE'}, {'id': 'hi-IN-Wavenet-D', 'gender': 'FEMALE'},
    {'id': 'hi-IN-Wavenet-E', 'gender': 'FEMALE'}, {'id': 'hi-IN-Wavenet-F', 'gender': 'MALE'},
  ],
  'Hungarian': [{'id': 'hu-HU-Wavenet-B', 'gender': 'FEMALE'}],
  'Indonesian': [
    {'id': 'id-ID-Wavenet-A', 'gender': 'FEMALE'}, {'id': 'id-ID-Wavenet-B', 'gender': 'MALE'},
    {'id': 'id-ID-Wavenet-C', 'gender': 'MALE'}, {'id': 'id-ID-Wavenet-D', 'gender': 'FEMALE'},
  ],
  'Italian': [{'id': 'it-IT-Wavenet-E', 'gender': 'FEMALE'}, {'id': 'it-IT-Wavenet-F', 'gender': 'MALE'}],
  'Japanese': [
    {'id': 'ja-JP-Wavenet-A', 'gender': 'FEMALE'}, {'id': 'ja-JP-Wavenet-B', 'gender': 'FEMALE'},
    {'id': 'ja-JP-Wavenet-C', 'gender': 'MALE'}, {'id': 'ja-JP-Wavenet-D', 'gender': 'MALE'},
  ],
  'Kannada': [
    {'id': 'kn-IN-Wavenet-A', 'gender': 'FEMALE'}, {'id': 'kn-IN-Wavenet-B', 'gender': 'MALE'},
    {'id': 'kn-IN-Wavenet-C', 'gender': 'FEMALE'}, {'id': 'kn-IN-Wavenet-D', 'gender': 'MALE'},
  ],
  'Korean': [
    {'id': 'ko-KR-Wavenet-A', 'gender': 'FEMALE'}, {'id': 'ko-KR-Wavenet-B', 'gender': 'FEMALE'},
    {'id': 'ko-KR-Wavenet-C', 'gender': 'MALE'}, {'id': 'ko-KR-Wavenet-D', 'gender': 'MALE'},
  ],
  'Malay': [
    {'id': 'ms-MY-Wavenet-A', 'gender': 'FEMALE'}, {'id': 'ms-MY-Wavenet-B', 'gender': 'MALE'},
    {'id': 'ms-MY-Wavenet-C', 'gender': 'FEMALE'}, {'id': 'ms-MY-Wavenet-D', 'gender': 'MALE'},
  ],
  'Malayalam': [
    {'id': 'ml-IN-Wavenet-A', 'gender': 'FEMALE'}, {'id': 'ml-IN-Wavenet-B', 'gender': 'MALE'},
    {'id': 'ml-IN-Wavenet-C', 'gender': 'FEMALE'}, {'id': 'ml-IN-Wavenet-D', 'gender': 'MALE'},
  ],
  'Mandarin (China)': [
    {'id': 'cmn-CN-Wavenet-A', 'gender': 'FEMALE'}, {'id': 'cmn-CN-Wavenet-B', 'gender': 'MALE'},
    {'id': 'cmn-CN-Wavenet-C', 'gender': 'MALE'}, {'id': 'cmn-CN-Wavenet-D', 'gender': 'FEMALE'},
  ],
  'Mandarin (Taiwan)': [
    {'id': 'cmn-TW-Wavenet-A', 'gender': 'FEMALE'}, {'id': 'cmn-TW-Wavenet-B', 'gender': 'MALE'},
    {'id': 'cmn-TW-Wavenet-C', 'gender': 'MALE'},
  ],
  'Marathi': [
    {'id': 'mr-IN-Wavenet-A', 'gender': 'FEMALE'}, {'id': 'mr-IN-Wavenet-B', 'gender': 'MALE'},
    {'id': 'mr-IN-Wavenet-C', 'gender': 'FEMALE'},
  ],
  'Norwegian': [{'id': 'nb-NO-Wavenet-F', 'gender': 'FEMALE'}, {'id': 'nb-NO-Wavenet-G', 'gender': 'MALE'}],
  'Polish': [{'id': 'pl-PL-Wavenet-F', 'gender': 'FEMALE'}, {'id': 'pl-PL-Wavenet-G', 'gender': 'MALE'}],
  'Portuguese (Brazil)': [
    {'id': 'pt-BR-Wavenet-A', 'gender': 'FEMALE'}, {'id': 'pt-BR-Wavenet-B', 'gender': 'MALE'},
    {'id': 'pt-BR-Wavenet-C', 'gender': 'FEMALE'}, {'id': 'pt-BR-Wavenet-D', 'gender': 'FEMALE'},
    {'id': 'pt-BR-Wavenet-E', 'gender': 'MALE'},
  ],
  'Portuguese (Portugal)': [{'id': 'pt-PT-Wavenet-E', 'gender': 'FEMALE'}, {'id': 'pt-PT-Wavenet-F', 'gender': 'MALE'}],
  'Punjabi': [
    {'id': 'pa-IN-Wavenet-A', 'gender': 'FEMALE'}, {'id': 'pa-IN-Wavenet-B', 'gender': 'MALE'},
    {'id': 'pa-IN-Wavenet-C', 'gender': 'FEMALE'}, {'id': 'pa-IN-Wavenet-D', 'gender': 'MALE'},
  ],
  'Romanian': [{'id': 'ro-RO-Wavenet-B', 'gender': 'FEMALE'}],
  'Russian': [
    {'id': 'ru-RU-Wavenet-A', 'gender': 'FEMALE'}, {'id': 'ru-RU-Wavenet-B', 'gender': 'MALE'},
    {'id': 'ru-RU-Wavenet-C', 'gender': 'FEMALE'}, {'id': 'ru-RU-Wavenet-D', 'gender': 'MALE'},
    {'id': 'ru-RU-Wavenet-E', 'gender': 'FEMALE'},
  ],
  'Slovak': [{'id': 'sk-SK-Wavenet-B', 'gender': 'FEMALE'}],
  'Spanish (Spain)': [
    {'id': 'es-ES-Wavenet-E', 'gender': 'MALE'}, {'id': 'es-ES-Wavenet-F', 'gender': 'FEMALE'},
    {'id': 'es-ES-Wavenet-G', 'gender': 'MALE'}, {'id': 'es-ES-Wavenet-H', 'gender': 'FEMALE'},
  ],
  'Spanish (US)': [
    {'id': 'es-US-Wavenet-A', 'gender': 'FEMALE'}, {'id': 'es-US-Wavenet-B', 'gender': 'MALE'},
    {'id': 'es-US-Wavenet-C', 'gender': 'MALE'},
  ],
  'Swedish': [
    {'id': 'sv-SE-Wavenet-A', 'gender': 'FEMALE'}, {'id': 'sv-SE-Wavenet-B', 'gender': 'FEMALE'},
    {'id': 'sv-SE-Wavenet-C', 'gender': 'MALE'}, {'id': 'sv-SE-Wavenet-D', 'gender': 'FEMALE'},
    {'id': 'sv-SE-Wavenet-E', 'gender': 'MALE'}, {'id': 'sv-SE-Wavenet-F', 'gender': 'FEMALE'},
    {'id': 'sv-SE-Wavenet-G', 'gender': 'MALE'},
  ],
  'Tamil': [
    {'id': 'ta-IN-Wavenet-A', 'gender': 'FEMALE'}, {'id': 'ta-IN-Wavenet-B', 'gender': 'MALE'},
    {'id': 'ta-IN-Wavenet-C', 'gender': 'FEMALE'}, {'id': 'ta-IN-Wavenet-D', 'gender': 'MALE'},
  ],
  'Ukrainian': [{'id': 'uk-UA-Wavenet-B', 'gender': 'FEMALE'}],
  'Urdu': [{'id': 'ur-IN-Wavenet-A', 'gender': 'FEMALE'}, {'id': 'ur-IN-Wavenet-B', 'gender': 'MALE'}],
  'Vietnamese': [
    {'id': 'vi-VN-Wavenet-A', 'gender': 'FEMALE'}, {'id': 'vi-VN-Wavenet-B', 'gender': 'MALE'},
    {'id': 'vi-VN-Wavenet-C', 'gender': 'FEMALE'}, {'id': 'vi-VN-Wavenet-D', 'gender': 'MALE'},
  ],
};
// Penutup Blok //


// No ke-3 & 4: CORE VIEW MODEL, LOGIC & AUDIO HANDLERS //
//......................................................//
class FreeT2SpeechViewModel extends StateNotifier<FreeT2SpeechState> {
  final Ref ref;
  final TextEditingController textController = TextEditingController();

  FreeT2SpeechViewModel(this.ref) : super(FreeT2SpeechState()) {
    _initializeData();
  }

  void _initializeData() {
    final langs = rawVoiceDatabase.keys.toList()..sort();
    state = state.copyWith(availableLanguages: langs);
  }

  @override
  void dispose() {
    textController.dispose();
    super.dispose();
  }

  void setLanguage(String language) {
    if (language == state.selectedLanguage) return;

    final rawVoices = rawVoiceDatabase[language] ?? [];
    final mappedVoices = rawVoices.map((v) {
      final id = v['id']!;
      final parts = id.split('-');
      
      final shortName = parts.length >= 2 ? "W-${parts.last}" : id;
      
      final rawGender = v['gender']!;
      final displayGender = rawGender.length > 1 
          ? rawGender.substring(0, 1).toUpperCase() + rawGender.substring(1).toLowerCase() 
          : rawGender;

      return VoiceModel(id: id, name: shortName, gender: displayGender);
    }).toList();

    state = state.copyWith(
      selectedLanguage: language,
      availableVoices: mappedVoices,
      resetVoice: true, 
      clearMessages: true,
    );
  }

  void setVoice(String voiceId) {
    state = state.copyWith(selectedVoice: voiceId, clearMessages: true);
  }

  void clearAll() {
    textController.clear();
    state = FreeT2SpeechState();
    _initializeData(); 
  }

  Future<void> generateAudio() async {
    final text = textController.text.trim();
    if (text.isEmpty || state.selectedLanguage == null || state.selectedVoice == null) {
      state = state.copyWith(errorMessage: "Lengkapi form sebelum generate.", clearMessages: false);
      return;
    }

    state = state.copyWith(isLoading: true, clearMessages: true);

    try {
      final service = ref.read(freeT2SpeechServiceProvider);
      
      final parts = state.selectedVoice!.split('-');
      final langCode = "${parts[0]}-${parts[1]}";

      final result = await service.generateFreeSpeech(
        text: text,
        languageCode: langCode,
        voiceName: state.selectedVoice!,
      );

      final String audioBase64 = result['audioBase64'] ?? '';

      state = state.copyWith(
        isLoading: false,
        successMessage: "Sintesis suara berhasil! Silakan dengarkan.",
        generatedAudioBase64: audioBase64,
      );

    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll("Exception:", "").trim(),
      );
    }
  }

  // --- AUDIO HANDLERS (LOGIKA PLAY & DOWNLOAD) ---

  Future<void> playAudio(AudioPlayer player) async {
    if (state.generatedAudioBase64 == null || state.generatedAudioBase64!.isEmpty) return;

    try {
      Uint8List audioBytes = base64Decode(state.generatedAudioBase64!);
      await player.play(BytesSource(audioBytes));
    } catch (e) {
      state = state.copyWith(
        errorMessage: "Gagal memutar audio: ${e.toString()}",
        clearMessages: false,
      );
    }
  }

  // ✅ PERBAIKAN FATAL: Membuka gembok Scoped Storage dan merilis akses penuh direktori
  Future<void> downloadAudio() async {
    if (state.generatedAudioBase64 == null || state.generatedAudioBase64!.isEmpty) {
       state = state.copyWith(errorMessage: "Tidak ada audio untuk diunduh.", clearMessages: false);
       return;
    }

    try {
      Uint8List audioBytes = base64Decode(state.generatedAudioBase64!);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'majiku_speech_$timestamp.mp3';

      if (kIsWeb) {
        // [LOGIKA WEB]: Download utuh menggunakan Blob Browser
        final blob = html.Blob([audioBytes], 'audio/mpeg');
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: url)
          ..setAttribute("download", fileName)
          ..click();
        
        html.Url.revokeObjectUrl(url);

        state = state.copyWith(
          successMessage: "Audio berhasil diunduh ke folder Downloads Anda.",
          clearMessages: false,
        );
      } else {
        // [LOGIKA MOBILE]: Eksekusi penetrasi Scoped Storage pada Android Publik
        String savePath = '';
        
        if (Platform.isAndroid) {
          // Akses langsung ke root sistem penyimpanan file Downloads publik
          final downloadDir = Directory('/storage/emulated/0/Download');
          if (!await downloadDir.exists()) {
             await downloadDir.create(recursive: true);
          }
          savePath = '${downloadDir.path}/$fileName';
        } else {
          // Logika iOS murni (membutuhkan UIFileSharingEnabled pada Info.plist)
          final directory = await getApplicationDocumentsDirectory();
          savePath = '${directory.path}/$fileName';
        }
        
        final file = File(savePath);
        await file.writeAsBytes(audioBytes);
        
        final targetFolder = Platform.isAndroid ? "Downloads" : "Dokumen Aplikasi";
        state = state.copyWith(
          successMessage: "Audio berhasil disimpan di folder $targetFolder HP Anda.",
          clearMessages: false,
        );
      }
    } catch (e) {
      state = state.copyWith(
        errorMessage: "Gagal mengunduh audio: ${e.toString()}",
        clearMessages: false,
      );
    }
  }
} 
// Penutup Blok //


// No ke-5: PROVIDER                                    //
//......................................................//
final freeT2SpeechViewModelProvider = StateNotifierProvider<FreeT2SpeechViewModel, FreeT2SpeechState>((ref) {
  return FreeT2SpeechViewModel(ref);
});
// Penutup Blok //