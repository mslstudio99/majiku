//================================================================//
// NAMA FILE: CHARACTER_UPLOAD_NARACINEMA_PLUS_SCREEN.DART       //
// DIREKTORI: LIB/SCREENS_NARACINEMA_PLUS/                        //
// DESKRIPSI: LAYAR UNGGAH REFERENSI KARAKTER (VEO CONSISTENCY)   //
//================================================================//

// No ke-1: IMPORTS & DEPENDENCIES                                //
//----------------------------------------------------------------//
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models_naracinema_plus/video_project_naracinema_plus.dart';
import '../theme/app_theme.dart';
import '../providers/config_provider.dart';
//----------------------------------------------------------------//

// No ke-2: STATEFUL WIDGET UTAMA & STATE INITIALIZATION          //
//----------------------------------------------------------------//
class CharacterUploadNaracinemaPlusScreen extends ConsumerStatefulWidget {
  final String projectId;
  final VideoProjectNaracinemaPlus project;

  const CharacterUploadNaracinemaPlusScreen({
    super.key,
    required this.projectId,
    required this.project,
  });

  @override
  ConsumerState<CharacterUploadNaracinemaPlusScreen> createState() => _CharacterUploadNaracinemaPlusScreenState();
}

class _CharacterUploadNaracinemaPlusScreenState extends ConsumerState<CharacterUploadNaracinemaPlusScreen> {
  final ImagePicker _picker = ImagePicker();
  
  List<Uint8List?> _localFileBytes = [];
  List<String?> _localFileMimeTypes = [];
  List<dynamic> _characters = [];
  
  bool _isSubmitting = false;
  bool _isLoadingCharacters = false;
  double _uploadProgress = 0.0;

  String _t(bool isIndo, String en, String id) => isIndo ? id : en;

  @override
  void initState() {
    super.initState();
    try {
      _characters = List.from((widget.project as dynamic).identifiedCharacters ?? []);
    } catch (_) {
      _characters = [];
    }

    _localFileBytes = List<Uint8List?>.filled(_characters.length, null);
    _localFileMimeTypes = List<String?>.filled(_characters.length, null);

    // [SAFETY NET]: Jika field model kosong, ambil langsung dari dokumen Firestore
    if (_characters.isEmpty) {
      _fetchCharactersFromFirestore();
    }
  }

  Future<void> _fetchCharactersFromFirestore() async {
    setState(() => _isLoadingCharacters = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('projects_naracinema_plus')
          .doc(widget.projectId)
          .get();
      
      final data = doc.data() ?? {};
      final List<dynamic> chars = List.from(data['identifiedCharacters'] ?? []);
      
      if (mounted) {
        setState(() {
          _characters = chars;
          _localFileBytes = List<Uint8List?>.filled(_characters.length, null);
          _localFileMimeTypes = List<String?>.filled(_characters.length, null);
          _isLoadingCharacters = false;
        });
      }
    } catch (e) {
      debugPrint("[CharacterUploadNaracinemaPlus] Error fetching characters: $e");
      if (mounted) setState(() => _isLoadingCharacters = false);
    }
  }
//----------------------------------------------------------------//

// No ke-3: LOGIKA SELECT IMAGE, STORAGE UPLOAD & FIREBASE UPDATE //
//----------------------------------------------------------------//
  Future<void> _pickImage(int index) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile != null && mounted) {
        final Uint8List bytes = await pickedFile.readAsBytes();
        setState(() {
          _localFileBytes[index] = bytes;
          _localFileMimeTypes[index] = pickedFile.mimeType ?? 'image/png';
        });
      }
    } catch (e) {
      debugPrint("[CharacterUploadNaracinemaPlus] Error picking image: $e");
    }
  }

  void _clearImage(int index) {
    if (mounted) {
      setState(() {
        _localFileBytes[index] = null;
        _localFileMimeTypes[index] = null;
      });
    }
  }

  Future<void> _submitAndUpload() async {
    setState(() {
      _isSubmitting = true;
      _uploadProgress = 0.0;
    });

    final isIndo = ref.read(appLanguageProvider).languageCode == 'id';

    try {
      final FirebaseStorage storage = FirebaseStorage.instance;
      final String bucketName = storage.ref().bucket;

      int totalFilesToUpload = _localFileBytes.where((bytes) => bytes != null).length;
      int uploadedCount = 0;

      for (int i = 0; i < _characters.length; i++) {
        final Uint8List? fileBytes = _localFileBytes[i];
        if (fileBytes == null) continue; // Jika user melewati (AI yang membuat)

        final String charName = _characters[i]['name'] ?? 'char_$i';
        final String charFileName = charName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').toLowerCase();
        
        final String storagePath = "projects_naracinema_plus/${widget.projectId}/characters/${charFileName}_$i.png";
        final Reference storageRef = storage.ref().child(storagePath);

        debugPrint("[CharacterUploadNaracinemaPlus] Uploading character asset: $charName");
        
        final UploadTask uploadTask = storageRef.putData(
          fileBytes,
          SettableMetadata(contentType: _localFileMimeTypes[i] ?? 'image/png'),
        );

        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          double fileProgress = snapshot.bytesTransferred / snapshot.totalBytes;
          if (mounted && totalFilesToUpload > 0) {
            setState(() {
              _uploadProgress = (uploadedCount + fileProgress) / totalFilesToUpload;
            });
          }
        });

        await uploadTask;
        
        final String downloadUrl = await storageRef.getDownloadURL();
        final String gcsUri = "gs://$bucketName/$storagePath";

        _characters[i] = Map<String, dynamic>.from(_characters[i]);
        _characters[i]['imageUri'] = downloadUrl;
        _characters[i]['gcsUri'] = gcsUri;

        uploadedCount++;
      }

      // Sinyal siap ke Backend Cloud Functions (Tahap 1B)
      await FirebaseFirestore.instance
          .collection('projects_naracinema_plus')
          .doc(widget.projectId)
          .update({
            'identifiedCharacters': _characters,
            'status': 'READY_FOR_IMAGE_GEN',
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _t(isIndo, 
                "Character references confirmed! Generating video scenes...", 
                "Referensi karakter terkonfirmasi! Sistem memproses adegan video..."
              )
            ),
            backgroundColor: Colors.blueAccent,
          ),
        );
        Navigator.of(context).pop(); // Kembali ke loading screen
      }
    } catch (e) {
      debugPrint("[CharacterUploadNaracinemaPlus] Upload Error: $e");
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _t(isIndo, 
                "An upload error occurred: $e", 
                "Terjadi kesalahan saat mengunggah: $e"
              )
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
//----------------------------------------------------------------//

// No ke-4: BUILD LAYOUT DENGAN TEMA MODERN PROFESIONAL           //
//----------------------------------------------------------------//
  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.darkTheme,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            "Upload Character References",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: "Back to Options",
            onPressed: _isSubmitting ? null : () => Navigator.of(context).pop('cancelled'),
          ),
        ),
        body: _isLoadingCharacters
            ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
            : Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Title & Instructions (In English)
                    const Text(
                      "Lock Character Consistency",
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Upload your own image (half-body portrait facing forward) for each character below to ensure visual consistency across all video scenes.",
                      style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.4),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

                    // Daftar Karakter Dinamis
                    Expanded(
                      child: _characters.isEmpty
                          ? const Center(
                              child: Text(
                                "No characters detected for manual reference.",
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                          : ListView.separated(
                              itemCount: _characters.length,
                              separatorBuilder: (context, index) => const Divider(color: Colors.white10),
                              itemBuilder: (context, index) {
                                final char = _characters[index];
                                final Uint8List? fileBytes = _localFileBytes[index];
                                final String defaultCharName = 'Character ${index + 1}';
                                final String charName = char['name'] ?? defaultCharName;
                                final String charDetail = char['detail']?.toString().replaceAll(RegExp(r'[()]'), '') ?? '';

                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.03),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: fileBytes != null ? Colors.blueAccent.withOpacity(0.6) : Colors.white10,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      // Nomor & Detail Karakter
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                CircleAvatar(
                                                  radius: 12,
                                                  backgroundColor: Colors.blueAccent.withOpacity(0.2),
                                                  child: Text(
                                                    "${index + 1}",
                                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    charName,
                                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              charDetail.isNotEmpty 
                                                  ? charDetail 
                                                  : "Tap to upload your image file",
                                              style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 16),

                                      // Kotak Slot Upload Gambar (84x84)
                                      Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: _isSubmitting ? null : () => _pickImage(index),
                                          borderRadius: BorderRadius.circular(10),
                                          child: Container(
                                            width: 84,
                                            height: 84,
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(0.04),
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(
                                                color: fileBytes != null ? Colors.blueAccent : Colors.white24,
                                                width: 1.5,
                                              ),
                                            ),
                                            child: fileBytes != null
                                                ? Stack(
                                                    fit: StackFit.expand,
                                                    children: [
                                                      ClipRRect(
                                                        borderRadius: BorderRadius.circular(9),
                                                        child: Image.memory(fileBytes, fit: BoxFit.cover),
                                                      ),
                                                      Positioned(
                                                        top: 3,
                                                        right: 3,
                                                        child: GestureDetector(
                                                          onTap: () => _clearImage(index),
                                                          child: Container(
                                                            padding: const EdgeInsets.all(3),
                                                            decoration: const BoxDecoration(
                                                              color: Colors.black87,
                                                              shape: BoxShape.circle,
                                                            ),
                                                            child: const Icon(Icons.close, size: 14, color: Colors.white),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  )
                                                : const Column(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: [
                                                      Icon(
                                                        Icons.add_photo_alternate_outlined, 
                                                        color: Colors.blueAccent, 
                                                        size: 26,
                                                      ),
                                                      SizedBox(height: 4),
                                                      Text(
                                                        "Upload File",
                                                        style: TextStyle(
                                                          fontSize: 10, 
                                                          color: Colors.blueAccent, 
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),

                    const SizedBox(height: 16),

                    // Progress Bar saat proses unggah berlangsung
                    if (_isSubmitting)
                      Column(
                        children: [
                          LinearProgressIndicator(
                            value: _uploadProgress,
                            backgroundColor: Colors.grey.shade800,
                            color: Colors.blueAccent,
                            minHeight: 6,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Uploading References: ${(_uploadProgress * 100).toStringAsFixed(0)}%",
                            style: const TextStyle(fontSize: 13, color: Colors.blueAccent, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),

                    // Baris Tombol Aksi: Cancel & Confirm
                    Row(
                      children: [
                        // Tombol Cancel (Kembali ke dialog konfirmasi)
                        Expanded(
                          flex: 2,
                          child: OutlinedButton(
                            onPressed: _isSubmitting ? null : () => Navigator.of(context).pop('cancelled'),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.white24),
                              foregroundColor: Colors.white70,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 16.0),
                            ),
                            child: const Text(
                              "CANCEL",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Tombol Confirm & Upload
                        Expanded(
                          flex: 3,
                          child: ElevatedButton.icon(
                            onPressed: _isSubmitting ? null : _submitAndUpload,
                            icon: const Icon(Icons.check_circle_outline),
                            label: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16.0),
                              child: Text(
                                "CONFIRM & UPLOAD",
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.grey[800],
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }
  }
//----------------------------------------------------------------//