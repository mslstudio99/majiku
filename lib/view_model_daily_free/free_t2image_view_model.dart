// No ke-1: IMPORTS & STATE CLASS                       //
//......................................................//
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:universal_html/html.dart' as html;

// Import Service yang baru kita buat
import '../services_daily_free/firestore_free_t2image_service.dart';

class FreeT2ImageState {
  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;
  final String selectedStyle;
  final String selectedRatio;
  final String generatedImageUrl;
  final Uint8List? generatedImageData;

  FreeT2ImageState({
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
    this.selectedStyle = 'Realistic',
    this.selectedRatio = '16:9',
    this.generatedImageUrl = '',
    this.generatedImageData,
  });

  FreeT2ImageState copyWith({
    bool? isLoading,
    String? errorMessage,
    String? successMessage,
    String? selectedStyle,
    String? selectedRatio,
    String? generatedImageUrl,
    Uint8List? generatedImageData,
    bool clearMessages = false,
  }) {
    return FreeT2ImageState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearMessages ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearMessages ? null : (successMessage ?? this.successMessage),
      selectedStyle: selectedStyle ?? this.selectedStyle,
      selectedRatio: selectedRatio ?? this.selectedRatio,
      generatedImageUrl: generatedImageUrl ?? this.generatedImageUrl,
      generatedImageData: generatedImageData ?? this.generatedImageData,
    );
  }
}
// Penutup Blok //

// No ke-2: VIEW MODEL & PROVIDER                       //
//......................................................//
class FreeT2ImageViewModel extends StateNotifier<FreeT2ImageState> {
  final Ref ref;
  final TextEditingController promptController = TextEditingController();

  FreeT2ImageViewModel(this.ref) : super(FreeT2ImageState());

  @override
  void dispose() {
    promptController.dispose();
    super.dispose();
  }

  void setStyle(String style) {
    state = state.copyWith(selectedStyle: style, clearMessages: true);
  }

  void setRatio(String ratio) {
    state = state.copyWith(selectedRatio: ratio, clearMessages: true);
  }

  void clearAll() {
    promptController.clear();
    state = FreeT2ImageState(); // Reset form ke kondisi awal
  }

  Future<void> generateImage() async {
    final prompt = promptController.text.trim();
    if (prompt.isEmpty) {
      state = state.copyWith(errorMessage: "Prompt tidak boleh kosong.", clearMessages: false);
      return;
    }

    state = state.copyWith(isLoading: true, clearMessages: true);

    try {
      final service = ref.read(freeT2ImageServiceProvider);
      
      final result = await service.generateFreeImage(
        prompt: prompt,
        style: state.selectedStyle,
        aspectRatio: state.selectedRatio,
      );

      final String imageUrl = result['imageUrl'] ?? '';
      final String imageBase64 = result['imageBase64'] ?? '';
      
      Uint8List? imageBytes;
      if (imageBase64.isNotEmpty) {
        imageBytes = base64Decode(imageBase64);
      }

      state = state.copyWith(
        isLoading: false,
        successMessage: "Berhasil! Keberuntungan ada di pihakmu hari ini.",
        generatedImageUrl: imageUrl,
        generatedImageData: imageBytes,
      );

    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll("Exception:", "").trim(),
      );
    }
  }

  // ✅ SOLUSI FINAL ANTI-REGRESI: Download Hybrid (Web & Native)
  Future<void> downloadImage() async {
    if (state.generatedImageData == null && state.generatedImageUrl.isEmpty) {
      state = state.copyWith(
        errorMessage: "Tidak ada gambar yang tersedia untuk diunduh.",
        clearMessages: false
      );
      return;
    }

    state = state.copyWith(isLoading: true, clearMessages: true);

    try {
      if (kIsWeb) {
        // --- LOGIKA UNTUK FLUTTER WEB ---
        if (state.generatedImageData != null) {
          final blob = html.Blob([state.generatedImageData!], 'image/jpeg');
          final url = html.Url.createObjectUrlFromBlob(blob);
          final anchor = html.AnchorElement(href: url)
            ..setAttribute("download", "majiku_free_${DateTime.now().millisecondsSinceEpoch}.jpg")
            ..click();
          html.Url.revokeObjectUrl(url);

          state = state.copyWith(
            isLoading: false,
            successMessage: "Unduhan dimulai di browser Anda.",
          );
        } else {
          throw Exception("Data gambar tidak ditemukan untuk unduhan Web.");
        }
      } else {
        // --- LOGIKA UNTUK NATIVE (ANDROID/IOS) ---
        if (state.generatedImageData != null) {
          final tempDir = await getTemporaryDirectory();
          final filePath = '${tempDir.path}/majiku_free_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final file = await File(filePath).writeAsBytes(state.generatedImageData!);

          await Gal.putImage(file.path);

          state = state.copyWith(
            isLoading: false,
            successMessage: "Gambar berhasil disimpan ke galeri perangkat!",
          );
        } else if (state.generatedImageUrl.isNotEmpty) {
          final uri = Uri.parse(state.generatedImageUrl);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
            state = state.copyWith(
              isLoading: false,
              successMessage: "Tautan unduhan dibuka di browser eksternal.",
            );
          } else {
            throw Exception("Gagal meluncurkan tautan unduhan.");
          }
        }
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: "Gagal mengunduh gambar: ${e.toString().replaceAll('Exception:', '').trim()}",
      );
    }
  }
}

final freeT2ImageViewModelProvider = StateNotifierProvider<FreeT2ImageViewModel, FreeT2ImageState>((ref) {
  return FreeT2ImageViewModel(ref);
});
// Penutup Blok //