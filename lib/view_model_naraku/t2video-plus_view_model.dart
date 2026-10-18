// T2VIDEO-PLUS_VIEW_MODEL.DART //
// LIB/VIEW_MODEL_NARAKU/T2VIDEO-PLUS_VIEW_MODEL.DART //
// MENGELOLA STATE DAN LOGIKA GENERATOR T2VIDEO-PLUS //

// No ke-1 - IMPORT & HELPER LOKALISASI //
//.......................................................//
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';

// [WAJIB] Ditambahkan untuk sistem keamanan Bearer Token
import 'package:firebase_auth/firebase_auth.dart'; 
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart'; 
import 'dart:html' if (dart.library.io) '../utils/html_stub.dart' as html;

// Impor Model dan Service Firestore untuk T2Video-Plus
import '../models_naraku/video_project_t2video-plus.dart';
import '../services_naraku/firestore_t2video-plus_service.dart';

class T2videoPlusLocalizationHelper {
  static const Map<String, Map<String, String>> translations = {
    'id': {
      'alertNoInput': "Silakan masukkan narasi video terlebih dahulu.",
      'statusGenerating': "Mesin Seedance Berputar...",
      'statusLoading': "Sedang merender video, mohon tunggu beberapa menit...",
      'statusDownloadSuccess': "Video sedang diunduh melalui {path}...",
      'statusDownloadFailed': "Gagal mengunduh video.",
      'alertApiError': "Terjadi kesalahan mesin rendering: {message}",
    },
    'en': {
      'alertNoInput': "Please enter a video narrative first.",
      'statusGenerating': "Seedance Engine Spinning...",
      'statusLoading': "Rendering video, please wait a few minutes...",
      'statusDownloadSuccess': "Video is downloading via {path}...",
      'statusDownloadFailed': "Failed to download video.",
      'alertApiError': "Rendering Engine Error: {message}",
    }
  };

  static String get(String key, {String? localeCode}) {
    final lang = localeCode ?? PlatformDispatcher.instance.locale.languageCode;
    final langKey = lang == 'id' ? 'id' : 'en';
    final translationMap = translations[langKey] ?? translations['id']!;
    return translationMap[key] ?? key;
  }
}
// Penutup Blok //

// No ke-2 - STATE CLASS UNTUK T2VIDEO-PLUS //
//.......................................................//
@immutable
class T2videoPlusState {
  final bool isLoading;
  final String generatedVideoUrl; 
  final String? errorMessage;
  final String? successMessage;
  final String loadingText;
  
  // Parameter spesifik video
  final String selectedStyle; 
  final String selectedRatio;
  final String selectedResolution;
  final int selectedDuration;
  final bool isAudioEnabled;

  const T2videoPlusState({
    this.isLoading = false,
    this.generatedVideoUrl = '',
    this.errorMessage,
    this.successMessage,
    this.loadingText = '',
    this.selectedStyle = "Realistic", 
    this.selectedRatio = "9:16", 
    this.selectedResolution = "480", 
    this.selectedDuration = 5, 
    this.isAudioEnabled = false, 
  });

  T2videoPlusState copyWith({
    bool? isLoading,
    String? generatedVideoUrl,
    String? errorMessage,
    String? successMessage,
    String? loadingText,
    bool clearError = false,
    bool clearSuccess = false,
    String? selectedStyle, 
    String? selectedRatio,
    String? selectedResolution,
    int? selectedDuration,
    bool? isAudioEnabled,
  }) {
    return T2videoPlusState(
      isLoading: isLoading ?? this.isLoading,
      generatedVideoUrl: generatedVideoUrl ?? this.generatedVideoUrl,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      successMessage: clearSuccess ? null : successMessage ?? this.successMessage,
      loadingText: loadingText ?? this.loadingText,
      selectedStyle: selectedStyle ?? this.selectedStyle, 
      selectedRatio: selectedRatio ?? this.selectedRatio,
      selectedResolution: selectedResolution ?? this.selectedResolution,
      selectedDuration: selectedDuration ?? this.selectedDuration,
      isAudioEnabled: isAudioEnabled ?? this.isAudioEnabled,
    );
  }
}
// Penutup Blok //

// No ke-3 - VIEW MODEL LOGIC //
// Mengatur State, Panggilan HTTP ke Cloud Run generatorT2VideoPlus, & Penyimpanan Dual URL ke Firestore //
//.......................................................//
class T2videoPlusViewModel extends StateNotifier<T2videoPlusState> {
  final TextEditingController narrativeController = TextEditingController();
  final Ref _ref;

  T2videoPlusViewModel(this._ref) : super(const T2videoPlusState());

  // [PERBAIKAN KRITIS]: Menggunakan URL Resmi Cloud Run Gen 2 (Bebas 302 Redirect & Bebas CORS Failed to Fetch)
  final String _engineUrl = "https://generatort2videoplus-l2jn5d37pa-et.a.run.app";

  // --- Setter Parameter ---
  void setStyle(String? value) {
    if (value == null) return;
    state = state.copyWith(selectedStyle: value);
  }

  void setRatio(String? value) {
    if (value == null) return;
    state = state.copyWith(selectedRatio: value);
  }

  void setResolution(String? value) {
    if (value == null) return;
    state = state.copyWith(selectedResolution: value);
  }

  void setDuration(int? value) {
    if (value == null) return;
    state = state.copyWith(selectedDuration: value);
  }

  void toggleAudio(bool value) {
    state = state.copyWith(isAudioEnabled: value);
  }

  // --- Core Generasi ---
  Future<void> generateVideo() async {
    if (state.isLoading) return;
    final narrative = narrativeController.text.trim();

    if (narrative.isEmpty) {
      state = state.copyWith(
          errorMessage: T2videoPlusLocalizationHelper.get('alertNoInput'),
          clearError: false);
      return;
    }

    state = state.copyWith(
        isLoading: true, clearError: true, clearSuccess: true, loadingText: 'RENDERING');

    try {
      // 1. Ambil Token Keamanan
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("Anda belum login. Silakan login kembali.");
      final String? idToken = await user.getIdToken();

      // 2. Menyusun payload
      final body = jsonEncode({
        'data': {
          'prompt': narrative,
          'style': state.selectedStyle,
          'aspectRatio': state.selectedRatio,
          'resolution': state.selectedResolution,
          'duration': state.selectedDuration,
          'audio': state.isAudioEnabled,
        }
      });

      // [TIMEOUT 9 MENIT]: Disesuaikan dengan batas maksimal Cloud Functions / Cloud Run
      final response = await http.post(
        Uri.parse(_engineUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken', 
        },
        body: body,
      ).timeout(const Duration(minutes: 9)); 

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        
        // [PARSING DUAL URL RESPON DEFENSIF]: Mendukung objek { videoUrl, imageUrl } maupun string
        final data = responseBody['data'];
        String? videoUrl;
        String? imageUrl;

        if (data is Map) {
          videoUrl = data['videoUrl']?.toString();
          imageUrl = data['imageUrl']?.toString();
        } else if (data is String) {
          videoUrl = data;
        }

        if (videoUrl != null && videoUrl.isNotEmpty) {
          
          // [SIMPAN DATA KE FIRESTORE: VIDEO + IMAGEURL]
          try {
            final firestoreService = FirestoreT2videoPlusService();
            final projectData = VideoProjectT2videoPlus(
              id: '', // Biarkan di-generate otomatis oleh service
              userid: user.uid,
              prompt: narrative,
              videourl: videoUrl,
              imageurl: imageUrl, // Menyimpan URL gambar referensi ke dokumen Firestore
              style: state.selectedStyle,
              aspectratio: state.selectedRatio,
              resolution: state.selectedResolution,
              duration: state.selectedDuration,
              createdat: DateTime.now(),
            );
            await firestoreService.saveProject(projectData);
            debugPrint("Sukses menyimpan History T2Video-Plus ke Firestore (Video: $videoUrl, Image: $imageUrl).");
          } catch (dbError) {
            // Dibungkus try-catch tersendiri agar jika database gagal, video tetap tampil di UI
            debugPrint("Peringatan: Gagal menyimpan riwayat ke Firestore: $dbError");
          }

          // Perbarui UI ke kondisi berhasil
          state = state.copyWith(
            isLoading: false,
            generatedVideoUrl: videoUrl, 
            loadingText: '',
          );
        } else {
          throw Exception("Gagal mendapatkan URL video dari server.");
        }
      } else {
        final errorResp = jsonDecode(response.body);
        final errorMsg = errorResp['error']?['message'] ?? response.body;
        throw Exception("Server Error (${response.statusCode}): $errorMsg");
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: T2videoPlusLocalizationHelper.get('alertApiError')
            .replaceFirst('{message}', e.toString()),
        loadingText: '',
      );
    }
  }

  // --- Pengunduhan (Refaktor ke Native Delegation) ---
  Future<void> downloadVideo() async {
    if (state.generatedVideoUrl.isEmpty) return;

    try {
      final Uri url = Uri.parse(state.generatedVideoUrl);
      
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw Exception('Sistem menolak atau gagal membuka tautan unduhan.');
      }

      state = state.copyWith(
        successMessage: T2videoPlusLocalizationHelper.get('statusDownloadSuccess')
            .replaceFirst('{path}', 'Sistem/Browser'),
        clearError: true
      );
    } catch (e) {
      state = state.copyWith(
          errorMessage: T2videoPlusLocalizationHelper.get('statusDownloadFailed') + " ${e.toString()}",
          clearError: false);
    }
  }

  // --- Reset State ---
  void clearAll() {
    narrativeController.clear();
    state = state.copyWith(
      generatedVideoUrl: '',
      clearError: true,
      clearSuccess: true,
      selectedStyle: "Realistic",
      selectedRatio: "9:16",
      selectedResolution: "480",
      selectedDuration: 5,
      isAudioEnabled: false,
    );
  }

  @override
  void dispose() {
    narrativeController.dispose();
    super.dispose();
  }
}
//.......................................................//

// No ke-4 - PROVIDER //
//.......................................................//
final t2videoPlusViewModelProvider = StateNotifierProvider.autoDispose<
    T2videoPlusViewModel, T2videoPlusState>(
  (ref) => T2videoPlusViewModel(ref),
);
// Penutup Blok //