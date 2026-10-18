// [NAMA FILE: lib/view_model_naraku/t2video_view_model.dart] //
// [KATEGORI: VIEW MODEL] //
// [TUJUAN: Mengelola state dan logika generator T2Video menggunakan Seedance 1.5 Pro] //

// No ke-1: IMPORT & HELPER LOKALISASI //
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
import 'package:url_launcher/url_launcher.dart'; // [BARU] Import untuk Native Download Delegation
import 'dart:html' if (dart.library.io) '../utils/html_stub.dart' as html;

// [PERBAIKAN] Impor Model dan Service Firestore untuk T2Video
import '../models_naraku/video_project_t2video.dart';
import '../services_naraku/firestore_t2video_service.dart';

class T2VideoLocalizationHelper {
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
//.......................................................//

// No ke-2: STATE CLASS UNTUK T2VIDEO //
@immutable
class T2VideoState {
  final bool isLoading;
  final String generatedVideoUrl; 
  final String? errorMessage;
  final String? successMessage;
  final String loadingText;
  
  // Parameter spesifik video
  final String selectedStyle; // [BARU] Opsi Gaya Visual (Realistic, Kartun 3D, Kartun 2D)
  final String selectedRatio;
  final String selectedResolution;
  final int selectedDuration;
  final bool isAudioEnabled;

  const T2VideoState({
    this.isLoading = false,
    this.generatedVideoUrl = '',
    this.errorMessage,
    this.successMessage,
    this.loadingText = '',
    this.selectedStyle = "Realistic", // [BARU] Default Style
    this.selectedRatio = "9:16", // Default Potrait
    this.selectedResolution = "480", // Default 480p
    this.selectedDuration = 5, // Default 5 Detik
    this.isAudioEnabled = false, // Default Tanpa Audio
  });

  T2VideoState copyWith({
    bool? isLoading,
    String? generatedVideoUrl,
    String? errorMessage,
    String? successMessage,
    String? loadingText,
    bool clearError = false,
    bool clearSuccess = false,
    String? selectedStyle, // [BARU]
    String? selectedRatio,
    String? selectedResolution,
    int? selectedDuration,
    bool? isAudioEnabled,
  }) {
    return T2VideoState(
      isLoading: isLoading ?? this.isLoading,
      generatedVideoUrl: generatedVideoUrl ?? this.generatedVideoUrl,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      successMessage: clearSuccess ? null : successMessage ?? this.successMessage,
      loadingText: loadingText ?? this.loadingText,
      selectedStyle: selectedStyle ?? this.selectedStyle, // [BARU]
      selectedRatio: selectedRatio ?? this.selectedRatio,
      selectedResolution: selectedResolution ?? this.selectedResolution,
      selectedDuration: selectedDuration ?? this.selectedDuration,
      isAudioEnabled: isAudioEnabled ?? this.isAudioEnabled,
    );
  }
}
// ------------------------------------------------------------------------- //

// No ke-3: VIEW MODEL LOGIC //
// Mengatur State, Panggilan HTTP ke Cloud Run generatorT2Video, & Penyimpanan Firestore //
//.......................................................//
class T2VideoViewModel extends StateNotifier<T2VideoState> {
  final TextEditingController narrativeController = TextEditingController();
  final Ref _ref;

  T2VideoViewModel(this._ref) : super(const T2VideoState());

  // [PERBAIKAN KRITIS]: Menggunakan URL Resmi Cloud Run Gen 2 (Bebas 302 Redirect & Bebas Connection Reset)
  final String _engineUrl = "https://generatort2video-l2jn5d37pa-et.a.run.app";

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
          errorMessage: T2VideoLocalizationHelper.get('alertNoInput'),
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

      // [PERBAIKAN TIMEOUT]: Disesuaikan ke 9 menit agar selaras dengan timeout server Cloud Functions / Cloud Run
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
        
        // Parsing URL Video
        final videoUrl = responseBody['data'];

        if (videoUrl != null && videoUrl.toString().isNotEmpty) {
          
          // [SIMPAN DATA KE FIRESTORE]
          try {
            final firestoreService = FirestoreT2VideoService();
            final projectData = VideoProjectT2Video(
              id: '', // Biarkan di-generate otomatis oleh service
              userId: user.uid,
              prompt: narrative,
              videoUrl: videoUrl.toString(),
              style: state.selectedStyle,
              aspectRatio: state.selectedRatio,
              resolution: state.selectedResolution,
              duration: state.selectedDuration,
              createdAt: DateTime.now(),
            );
            await firestoreService.saveProject(projectData);
            debugPrint("Sukses menyimpan History T2Video ke Firestore.");
          } catch (dbError) {
            // Dibungkus try-catch tersendiri agar jika database gagal, video tetap tampil di UI
            debugPrint("Peringatan: Gagal menyimpan riwayat ke Firestore: $dbError");
          }

          // Perbarui UI ke kondisi berhasil
          state = state.copyWith(
            isLoading: false,
            generatedVideoUrl: videoUrl.toString(), 
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
        errorMessage: T2VideoLocalizationHelper.get('alertApiError')
            .replaceFirst('{message}', e.toString()),
        loadingText: '',
      );
    }
  }

  // --- Pengunduhan (Refaktor ke Native Delegation) ---
  Future<void> downloadVideo() async {
    if (state.generatedVideoUrl.isEmpty) return;

    try {
      // Menggunakan arsitektur Native Delegation yang aman untuk Android 11+ & Web
      final Uri url = Uri.parse(state.generatedVideoUrl);
      
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw Exception('Sistem menolak atau gagal membuka tautan unduhan.');
      }

      state = state.copyWith(
        successMessage: T2VideoLocalizationHelper.get('statusDownloadSuccess')
            .replaceFirst('{path}', 'Sistem/Browser'),
        clearError: true
      );
    } catch (e) {
      state = state.copyWith(
          errorMessage: T2VideoLocalizationHelper.get('statusDownloadFailed') + " ${e.toString()}",
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

// No ke-4: PROVIDER //
final t2VideoViewModelProvider = StateNotifierProvider.autoDispose<
    T2VideoViewModel, T2VideoState>(
  (ref) => T2VideoViewModel(ref),
);
// ------------------------------------------------------------------------- //