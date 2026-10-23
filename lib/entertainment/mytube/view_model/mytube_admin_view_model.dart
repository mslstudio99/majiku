//============================================================================//
// DIREKTORI: lib/entertainment/mytube/view_model/                           //
// FILE: MYTUBE_ADMIN_VIEW_MODEL.DART                                        //
// VIEW MODEL PORTAL ADMIN DENGAN DUKUNGAN UNIVERSAL (WEB & MOBILE)          //
//============================================================================//

//No ke-1....................................................................//
//IMPORTS & DEPENDENCIES                                                     //
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/video_mytube_model.dart';
import '../services/firestore_mytube_service.dart';
//............................................................................//

//No ke-2....................................................................//
//STATE PROPERTIES & CONSTRUCTOR                                             //
class MytubeAdminViewModel extends ChangeNotifier {
  final FirestoreMytubeService _service;
  final FirebaseStorage _storage;

  MytubeAdminViewModel({
    FirestoreMytubeService? service,
    FirebaseStorage? storage,
  })  : _service = service ?? FirestoreMytubeService(),
        _storage = storage ?? FirebaseStorage.instance;

  bool _isAdminVerified = false;
  bool get isAdminVerified => _isAdminVerified;

  bool _isCheckingAuth = true;
  bool get isCheckingAuth => _isCheckingAuth;

  bool _isUploading = false;
  bool get isUploading => _isUploading;

  double _uploadProgress = 0.0;
  double get uploadProgress => _uploadProgress;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  XFile? _selectedVideoFile;
  XFile? get selectedVideoFile => _selectedVideoFile;

  // [ANTI-FREEZE WEB]: Menyimpan byte video & thumbnail siap pakai di awal
  Uint8List? _videoBytes;
  Uint8List? get videoBytes => _videoBytes;

  XFile? _selectedThumbnailFile;
  XFile? get selectedThumbnailFile => _selectedThumbnailFile;

  Uint8List? _thumbnailBytes;
  Uint8List? get thumbnailBytes => _thumbnailBytes;

  int _videoDurationSeconds = 0;
  int get videoDurationSeconds => _videoDurationSeconds;
//............................................................................//

//No ke-3....................................................................//
//ADMIN ACCESS VERIFICATION                                                  //
  Future<void> verifyAdminAccess(String userId) async {
    _isCheckingAuth = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // [PENYESUAIAN RBAC]: Memvalidasi apakah akun adalah 'creator' atau 'admin'
      _isAdminVerified = await _service.checkIsCreatorOrAdmin(userId);
    } catch (e) {
      _isAdminVerified = false;
      _errorMessage = 'Gagal memverifikasi status keanggotaan kreator: $e';
    } finally {
      _isCheckingAuth = false;
      notifyListeners();
    }
  }
//............................................................................//

//No ke-4....................................................................//
//VIDEO SELECTION & DURATION VALIDATION (UNIVERSAL XFILE & PRELOADED BYTES)  //
  bool setVideoFile({
    required XFile file,
    Uint8List? bytes,
    required int durationInSeconds,
    int maxDurationSeconds = 180, // Default 3 menit untuk Shorts, fleksibel untuk Longs
  }) {
    _errorMessage = null;

    if (durationInSeconds <= 0) {
      _errorMessage = 'Durasi video tidak valid.';
      notifyListeners();
      return false;
    }

    if (durationInSeconds > maxDurationSeconds) {
      final maxMin = maxDurationSeconds ~/ 60;
      _errorMessage = 'Durasi video maksimal $maxMin menit ($durationInSeconds detik terdeteksi).';
      notifyListeners();
      return false;
    }

    _selectedVideoFile = file;
    _videoBytes = bytes;
    _videoDurationSeconds = durationInSeconds;
    notifyListeners();
    return true;
  }

  void setThumbnailFile(XFile file, {Uint8List? bytes}) {
    _selectedThumbnailFile = file;
    _thumbnailBytes = bytes;
    notifyListeners();
  }

  void clearSelectedFiles() {
    _selectedVideoFile = null;
    _videoBytes = null;
    _selectedThumbnailFile = null;
    _thumbnailBytes = null;
    _videoDurationSeconds = 0;
    _errorMessage = null;
    notifyListeners();
  }
//............................................................................//

//No ke-5....................................................................//
//STORAGE UPLOAD & PUBLISHING PIPELINE (HYBRID WEB & MOBILE)                 //
  String _slugify(String input) {
    final trimmed = input.trim().toLowerCase();
    final sanitized = trimmed
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .replaceAll(RegExp(r'[\s_]+'), '-')
        .replaceAll(RegExp(r'-+'), '-');
    final clean = sanitized.replaceAll(RegExp(r'^-+|-+$'), '');
    return clean.isEmpty ? 'video' : clean;
  }

  Future<bool> uploadAndPublishVideo({
    required String uploaderId,
    required String uploaderEmail,
    String? channelId,
    required String channelName,
    required String channelAvatarUrl,
    required String title,
    required String description,
    bool isLandscape = false,
    String category = 'Comedy & Funny',
    String language = 'English (US)',
    String videoType = 'SHORT',
    List<String> targetLocations = const ['Global'], // [BARU]: Menerima array lokasi target topik
    String? actionButtonText,
    String? actionButtonRoute,
  }) async {
    if (!_isAdminVerified) {
      _errorMessage = 'Akses ditolak: Akun belum disetujui sebagai admin Mytube.';
      notifyListeners();
      return false;
    }

    if (_selectedVideoFile == null) {
      _errorMessage = 'Silakan pilih file video terlebih dahulu.';
      notifyListeners();
      return false;
    }

    if (title.trim().isEmpty) {
      _errorMessage = 'Judul video wajib diisi.';
      notifyListeners();
      return false;
    }

    _isUploading = true;
    _uploadProgress = 0.0;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. [STRICT NEW WRITE]: Mengunci direktori penyimpanan Cloud Storage ke channelId resmi
      String targetFolderKey = (channelId != null && channelId.trim().isNotEmpty)
          ? channelId.trim()
          : '';

      // Auto-Resolver cerdas: Jika channelId belum dioper dari UI, ambil otomatis dari profil creator
      if (targetFolderKey.isEmpty) {
        try {
          final profile = await _service.getCreatorProfile(uploaderEmail, userId: uploaderId);
          if (profile != null && profile.channelId.isNotEmpty) {
            targetFolderKey = profile.channelId;
          }
        } catch (_) {}
      }

      // Fallback darurat jika akun lama belum memiliki channelId
      if (targetFolderKey.isEmpty) {
        targetFolderKey = uploaderEmail.trim().toLowerCase().isNotEmpty
            ? uploaderEmail.trim().toLowerCase()
            : uploaderId;
      }

      final titleSlug = _slugify(title);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final uniqueSuffix = timestamp.toString().substring(timestamp.toString().length - 6);

      // Document ID & Nama Folder 100% SINKRON
      final videoDocId = '$titleSlug-$uniqueSuffix';
      final typeFolder = videoType.toUpperCase() == 'LONG' ? 'long_video' : 'short_video';

      // Path Target di Cloud Storage: mytube/{channelId}/{typeFolder}/{titleSlug-uniqueSuffix}/
      final baseFolderPath = 'mytube/$targetFolderKey/$typeFolder/$videoDocId';
      debugPrint('🚀 [MYTUBE] Target Folder: $baseFolderPath');

      // 2. Upload File Video Master (master.mp4) dengan Telemetri Lengkap
      final videoStorageRef = _storage.ref().child('$baseFolderPath/master.mp4');
      final videoMetadata = SettableMetadata(contentType: 'video/mp4');

      final UploadTask uploadTask;
      if (kIsWeb) {
        debugPrint('⏳ [MYTUBE] Mempersiapkan byte video untuk Web...');
        // [ANTI-FREEZE]: Gunakan byte yang sudah preloaded saat pickVideo agar tidak membeku
        final Uint8List bytes = _videoBytes ?? await _selectedVideoFile!.readAsBytes();
        final sizeMb = (bytes.lengthInBytes / (1024 * 1024)).toStringAsFixed(2);
        debugPrint('📦 [MYTUBE] Byte video siap ($sizeMb MB / ${bytes.lengthInBytes} bytes). Memulai putData...');
        uploadTask = videoStorageRef.putData(bytes, videoMetadata);
      } else {
        debugPrint('⏳ [MYTUBE] Memulai upload file video di Mobile...');
        uploadTask = videoStorageRef.putFile(File(_selectedVideoFile!.path), videoMetadata);
      }

      // [MONITOR LIVE & ERROR TRAP]: Mengalirkan progres secara transparan detik demi detik
      uploadTask.snapshotEvents.listen(
        (TaskSnapshot snapshot) {
          if (snapshot.totalBytes > 0) {
            final double ratio = snapshot.bytesTransferred / snapshot.totalBytes;
            _uploadProgress = ratio * 0.85;
            final sentMb = (snapshot.bytesTransferred / (1024 * 1024)).toStringAsFixed(2);
            final totalMb = (snapshot.totalBytes / (1024 * 1024)).toStringAsFixed(2);
            debugPrint('📤 [MYTUBE PROGRESS]: ${(ratio * 100).toStringAsFixed(1)}% ($sentMb MB / $totalMb MB)');
            notifyListeners();
          }
        },
        onError: (dynamic error) {
          debugPrint('❌ [MYTUBE STORAGE STREAM ERROR]: $error');
          _errorMessage = 'Cloud Storage menolak izin upload: $error';
          _isUploading = false;
          notifyListeners();
        },
      );

      final videoSnapshot = await uploadTask;
      debugPrint('✅ [MYTUBE] Video master.mp4 berhasil diunggah! Mengambil Download URL...');
      final videoDownloadUrl = await videoSnapshot.ref.getDownloadURL();
      debugPrint('🔗 [MYTUBE] Download URL: $videoDownloadUrl');

      // 3. Upload File Thumbnail (thumbnail.jpg)
      String thumbnailDownloadUrl = '';
      if (_selectedThumbnailFile != null) {
        debugPrint('🖼️ [MYTUBE] Mengunggah thumbnail pilihan user...');
        final thumbStorageRef = _storage.ref().child('$baseFolderPath/thumbnail.jpg');
        final thumbMetadata = SettableMetadata(contentType: 'image/jpeg');

        final UploadTask thumbTask;
        if (kIsWeb) {
          final Uint8List thumbBytes = _thumbnailBytes ?? await _selectedThumbnailFile!.readAsBytes();
          thumbTask = thumbStorageRef.putData(thumbBytes, thumbMetadata);
        } else {
          thumbTask = thumbStorageRef.putFile(File(_selectedThumbnailFile!.path), thumbMetadata);
        }

        final thumbSnapshot = await thumbTask;
        thumbnailDownloadUrl = await thumbSnapshot.ref.getDownloadURL();
        debugPrint('✅ [MYTUBE] Thumbnail berhasil diunggah: $thumbnailDownloadUrl');
      }

      _uploadProgress = 0.95;
      notifyListeners();

      // 4. Catat Dokumen Postingan ke Firestore dengan channelId resmi & Target Lokasi
      debugPrint('📝 [MYTUBE] Menyimpan dokumen video ke Firestore di saluran $targetFolderKey...');
      final newVideoPost = VideoMytubeModel(
        id: videoDocId,
        channelId: targetFolderKey,
        title: title.trim(),
        description: description.trim(),
        videoUrl: videoDownloadUrl,
        thumbnailUrl: thumbnailDownloadUrl,
        durationSeconds: _videoDurationSeconds,
        isLandscape: isLandscape,
        uploaderId: uploaderId,
        uploaderEmail: uploaderEmail.trim().toLowerCase(),
        channelName: channelName,
        channelAvatarUrl: channelAvatarUrl,
        isVerifiedAdmin: true,
        category: category,
        language: language,
        videoType: videoType,
        targetLocations: targetLocations.isNotEmpty ? targetLocations : const ['Global'], // [BARU]: Tersimpan rapi
        createdAt: DateTime.now(),
        actionButtonText: actionButtonText?.trim().isNotEmpty == true ? actionButtonText!.trim() : null,
        actionButtonRoute: actionButtonRoute?.trim().isNotEmpty == true ? actionButtonRoute!.trim() : null,
      );

      await _service.createVideoPost(newVideoPost);
      debugPrint('🎉 [MYTUBE] Video berhasil terdaftar di Firestore dengan ID: $videoDocId pada Channel ID: $targetFolderKey');

      _uploadProgress = 1.0;
      _isUploading = false;
      clearSelectedFiles();
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ [MYTUBE ERROR] Gagal mengunggah video: $e\n$stackTrace');
      _errorMessage = '$e';
      _isUploading = false;
      notifyListeners();
      return false;
    }
  }
//............................................................................//

//No ke-6....................................................................//
//FORM RESET & STATE CLEANUP                                                 //
  void resetForm() {
    _selectedVideoFile = null;
    _selectedThumbnailFile = null;
    _videoDurationSeconds = 0;
    _isUploading = false;
    _uploadProgress = 0.0;
    _errorMessage = null;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
//............................................................................//