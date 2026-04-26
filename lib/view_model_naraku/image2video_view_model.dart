// [NAMA FILE: lib/view_model_naraku/image2video_view_model.dart] //
// [KATEGORI: VIEW MODEL] //
// [TUJUAN: Mengelola state dan logika generator Image2Video] //

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

import 'package:image_picker/image_picker.dart'; // [BARU] Import tipe data XFile

// [PERBAIKAN] Impor Model dan Service Firestore untuk Image2Video
import '../models_naraku/video_project_image2video.dart';
import '../services_naraku/firestore_image2video_service.dart';

class Image2VideoLocalizationHelper {
  static const Map<String, Map<String, String>> translations = {
    'id': {
      'alertNoInput': "Silakan unggah gambar terlebih dahulu.",
      'statusGenerating': "Mesin Seedance Berputar...",
      'statusLoading': "Sedang merender video, mohon tunggu beberapa menit...",
      'statusDownloadSuccess': "Video sedang diunduh melalui {path}...",
      'statusDownloadFailed': "Gagal mengunduh video.",
      'alertApiError': "Terjadi kesalahan mesin rendering: {message}",
    },
    'en': {
      'alertNoInput': "Please upload an image first.", 
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

// No ke-2: STATE CLASS UNTUK IMAGE2VIDEO //
@immutable
class Image2VideoState {
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

  const Image2VideoState({
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

  Image2VideoState copyWith({
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
    return Image2VideoState(
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
// ------------------------------------------------------------------------- //

// No ke-3: VIEW MODEL LOGIC //
//.......................................................//
class Image2VideoViewModel extends StateNotifier<Image2VideoState> {
  final TextEditingController narrativeController = TextEditingController();
  final Ref _ref;

  Image2VideoViewModel(this._ref) : super(const Image2VideoState());

  // URL Resmi Firebase Function Gen 2 Jakarta untuk Image2Video
  final String _engineUrl = "https://asia-southeast2-majiku-5b07e.cloudfunctions.net/generatorImage2Video";

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

  // --- Core Generasi (Menerima Parameter XFile dari UI Web/Mobile) ---
  // [PERBAIKAN] Parameter imageFile sekarang adalah XFile? agar cocok dengan UI
  Future<void> generateVideo({XFile? imageFile}) async {
    if (state.isLoading) return;
    
    // Validasi Gambar Wajib Ada
    if (imageFile == null) {
      state = state.copyWith(
          errorMessage: Image2VideoLocalizationHelper.get('alertNoInput'),
          clearError: false);
      return;
    }

    final narrative = narrativeController.text.trim(); // Opsional

    state = state.copyWith(
        isLoading: true, clearError: true, clearSuccess: true, loadingText: 'RENDERING');

    try {
      // 1. Ambil Token Keamanan
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("Anda belum login. Silakan login kembali.");
      final String? idToken = await user.getIdToken();

      // 2. Encode Gambar ke Base64 menggunakan XFile (Mendukung Web & Mobile)
      final imageBytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(imageBytes);

      // [BARU & FLEKSIBEL] Deteksi Ekstensi File dari nama XFile
      String mimeType = 'image/jpeg'; // Fallback default
      final String fileNameLower = imageFile.name.toLowerCase();
      if (fileNameLower.endsWith('.png')) {
        mimeType = 'image/png';
      } else if (fileNameLower.endsWith('.webp')) {
        mimeType = 'image/webp';
      } else if (fileNameLower.endsWith('.gif')) {
        mimeType = 'image/gif';
      }

      // 3. Menyusun payload dengan Mime Type Dinamis
      final body = jsonEncode({
        'data': {
          'image_base64': base64Image, 
          'mime_type': mimeType, 
          'prompt': narrative, 
          'style': state.selectedStyle,
          'aspectRatio': state.selectedRatio,
          'resolution': state.selectedResolution,
          'duration': state.selectedDuration,
          'audio': state.isAudioEnabled,
        }
      });

      final response = await http.post(
        Uri.parse(_engineUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken', 
        },
        body: body,
      ).timeout(const Duration(minutes: 6)); 

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        
        // Parsing URL Video
        final videoUrl = responseBody['data'];

        if (videoUrl != null && videoUrl.toString().isNotEmpty) {
          
          // [SIMPAN DATA KE FIRESTORE]
          try {
            final firestoreService = FirestoreImage2VideoService();
            final projectData = VideoProjectImage2Video(
              id: '', 
              userId: user.uid,
              imageUrl: '', 
              prompt: narrative,
              videoUrl: videoUrl.toString(),
              style: state.selectedStyle,
              aspectRatio: state.selectedRatio,
              resolution: state.selectedResolution,
              duration: state.selectedDuration,
              createdAt: DateTime.now(),
            );
            await firestoreService.saveProject(projectData);
            debugPrint("Sukses menyimpan History Image2Video ke Firestore.");
          } catch (dbError) {
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
        errorMessage: Image2VideoLocalizationHelper.get('alertApiError')
            .replaceFirst('{message}', e.toString()),
        loadingText: '',
      );
    }
  }

  // --- Pengunduhan ---
  Future<void> downloadVideo() async {
    if (state.generatedVideoUrl.isEmpty) return;

    try {
      // [PERBAIKAN] Menggunakan arsitektur Native Delegation yang aman untuk Android 11+ & Web
      final Uri url = Uri.parse(state.generatedVideoUrl);
      
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw Exception('Sistem menolak atau gagal membuka tautan unduhan.');
      }

      state = state.copyWith(
        successMessage: Image2VideoLocalizationHelper.get('statusDownloadSuccess')
            .replaceFirst('{path}', 'Sistem/Browser'),
        clearError: true
      );
    } catch (e) {
      state = state.copyWith(
          errorMessage: Image2VideoLocalizationHelper.get('statusDownloadFailed') + " ${e.toString()}",
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
final image2VideoViewModelProvider = StateNotifierProvider.autoDispose<
    Image2VideoViewModel, Image2VideoState>(
  (ref) => Image2VideoViewModel(ref),
);
// ------------------------------------------------------------------------- //