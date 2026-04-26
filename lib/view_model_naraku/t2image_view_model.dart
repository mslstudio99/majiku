//......................................................//
// LIB/VIEW_MODEL_NARAKU/T2IMAGE_VIEW_MODEL.DART        //
//......................................................//

// No ke-1: IMPORT & HELPER LOKALISASI //
//......................................................//
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
// ✅ IMPORT BARU: Menggunakan 'gal' yang kompatibel dengan Gradle terbaru
import 'package:gal/gal.dart';
import 'dart:html' if (dart.library.io) '../utils/html_stub.dart' as html;

import '../models_naraku/image_project_t2image.dart';
import '../services_naraku/firestore_t2image_service.dart';

class T2ImageLocalizationHelper {
  static const Map<String, Map<String, String>> translations = {
    'id': {
      'alertNoInput': "Silakan masukkan prompt gambar terlebih dahulu.",
      'statusGenerating': "Mesin Imagen Berpikir...",
      'statusLoading': "Sedang merender gambar, mohon tunggu...",
      'statusDownloadSuccess': "Gambar disimpan di: {path}",
      'statusDownloadFailed': "Gagal mengunduh gambar.",
      'alertApiError': "Terjadi kesalahan mesin rendering: {message}",
    },
    'en': {
      'alertNoInput': "Please enter an image prompt first.",
      'statusGenerating': "Imagen Engine is Thinking...",
      'statusLoading': "Rendering image, please wait...",
      'statusDownloadSuccess': "Image saved to: {path}",
      'statusDownloadFailed': "Failed to download image.",
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
//......................................................//

// No ke-2: STATE CLASS UNTUK T2IMAGE //
//......................................................//
@immutable
class T2ImageState {
  final bool isLoading;
  final String generatedImageUrl;
  final Uint8List? generatedImageData;
  final String? errorMessage;
  final String? successMessage;
  final String loadingText;
  
  final String selectedStyle;
  final String selectedRatio;
  final int numberOfImages;

  const T2ImageState({
    this.isLoading = false,
    this.generatedImageUrl = '',
    this.generatedImageData,
    this.errorMessage,
    this.successMessage,
    this.loadingText = '',
    this.selectedStyle = "photorealistic",
    this.selectedRatio = "9:16",
    this.numberOfImages = 1,
  });

  T2ImageState copyWith({
    bool? isLoading,
    String? generatedImageUrl,
    Uint8List? generatedImageData,
    bool clearImageData = false,
    String? errorMessage,
    String? successMessage,
    String? loadingText,
    bool clearError = false,
    bool clearSuccess = false,
    String? selectedStyle,
    String? selectedRatio,
    int? numberOfImages,
  }) {
    return T2ImageState(
      isLoading: isLoading ?? this.isLoading,
      generatedImageUrl: generatedImageUrl ?? this.generatedImageUrl,
      generatedImageData: clearImageData ? null : generatedImageData ?? this.generatedImageData,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      successMessage: clearSuccess ? null : successMessage ?? this.successMessage,
      loadingText: loadingText ?? this.loadingText,
      selectedStyle: selectedStyle ?? this.selectedStyle,
      selectedRatio: selectedRatio ?? this.selectedRatio,
      numberOfImages: numberOfImages ?? this.numberOfImages,
    );
  }
}
//......................................................//

// No ke-3: VIEW MODEL LOGIC & REVISI DOWNLOAD //
//......................................................//
class T2ImageViewModel extends StateNotifier<T2ImageState> {
  final TextEditingController promptController = TextEditingController();
  final Ref _ref;

  T2ImageViewModel(this._ref) : super(const T2ImageState());

  final String _functionUrl = "https://asia-southeast2-majiku-5b07e.cloudfunctions.net/generatorT2Image";

  void setStyle(String? value) {
    if (value == null) return;
    state = state.copyWith(selectedStyle: value);
  }

  void setRatio(String? value) {
    if (value == null) return;
    state = state.copyWith(selectedRatio: value);
  }

  Future<void> generateImage() async {
    if (state.isLoading) return;
    final prompt = promptController.text.trim();

    if (prompt.isEmpty) {
      state = state.copyWith(
          errorMessage: T2ImageLocalizationHelper.get('alertNoInput'),
          clearError: false);
      return;
    }

    state = state.copyWith(
        isLoading: true, 
        clearError: true, 
        clearSuccess: true, 
        loadingText: 'RENDERING', 
        clearImageData: true
    );

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("Sesi berakhir. Silakan login kembali.");
      
      final String? idToken = await user.getIdToken();

      final response = await http.post(
        Uri.parse(_functionUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({
          'data': {
            'prompt': prompt,
            'style': state.selectedStyle,
            'aspectRatio': state.selectedRatio,
          }
        }),
      ).timeout(const Duration(minutes: 5));

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseBody = jsonDecode(response.body);
        final String downloadUrl = responseBody['data'];

        final imageResponse = await http.get(Uri.parse(downloadUrl));
        final Uint8List imageBytes = imageResponse.bodyBytes;

        try {
          final firestoreService = FirestoreT2ImageService();
          final newProject = ImageProjectT2Image(
            id: '', 
            userId: user.uid,
            prompt: prompt, 
            imageUrl: downloadUrl, 
            style: state.selectedStyle,
            aspectRatio: state.selectedRatio,
            createdAt: DateTime.now(),
          );

          await firestoreService.saveProject(newProject);
          debugPrint("✅ Berhasil menyimpan histori T2Image ke Firestore!");
        } catch (dbError) {
          debugPrint("⚠️ Gambar berhasil dibuat, tapi gagal menyimpan histori: $dbError");
        }

        state = state.copyWith(
          isLoading: false,
          generatedImageUrl: downloadUrl,
          generatedImageData: imageBytes,
          loadingText: '',
        );
      } else {
        final errorData = jsonDecode(response.body);
        final errorMsg = errorData['error']?['message'] ?? "Gagal merender gambar.";
        throw Exception(errorMsg);
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: T2ImageLocalizationHelper.get('alertApiError')
            .replaceFirst('{message}', e.toString()),
        loadingText: '',
      );
    }
  }

  // ✅ SOLUSI MODERN: Menggunakan package 'gal' 
  Future<void> downloadImage() async {
    if (state.generatedImageData == null) return;
    final bytes = state.generatedImageData!;

    try {
      final String baseName = 'Majiku_AI_${DateTime.now().millisecondsSinceEpoch}';
      final String fileName = '$baseName.png';
      String finalPath = '';

      if (kIsWeb) {
        final blob = html.Blob([bytes], 'image/png');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)..download = fileName..click();
        html.Url.revokeObjectUrl(url);
        finalPath = 'Folder Downloads Browser';
      } else {
        if (Platform.isAndroid || Platform.isIOS) {
          
          // 1. Cek dan Minta Izin Galeri (Otomatis ditangani)
          final hasAccess = await Gal.hasAccess();
          if (!hasAccess) {
            await Gal.requestAccess();
          }

          // 2. Simpan gambar secara Native dan Aman
          await Gal.putImageBytes(bytes);
          
          finalPath = 'Galeri Foto Perangkat Anda';
        } else {
          final directory = await getDownloadsDirectory();
          final String filePath = '${directory!.path}/$fileName';
          final File file = File(filePath);
          await file.writeAsBytes(bytes);
          finalPath = filePath;
        }
      }
      
      state = state.copyWith(
        successMessage: "Gambar berhasil disimpan di:\n$finalPath", 
        clearError: true
      );
    } catch (e) {
      state = state.copyWith(
        errorMessage: "Gagal menyimpan gambar: $e", 
        clearSuccess: true
      );
    }
  }

  void clearAll() {
    promptController.clear();
    state = const T2ImageState();
  }

  @override
  void dispose() {
    promptController.dispose();
    super.dispose();
  }
}
//......................................................//

// No ke-4: PROVIDER //
//......................................................//
final t2ImageViewModelProvider = StateNotifierProvider.autoDispose<
    T2ImageViewModel, T2ImageState>(
  (ref) => T2ImageViewModel(ref),
);
//......................................................//