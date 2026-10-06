//====================================================================================================//
// NAMA FILE: CHARACTER_UPLOAD_VEO_SCREEN.DART                                                        //
// DIREKTORI: lib/screens_veo/character_upload_veo_screen.dart                                        //
//====================================================================================================//

//No ke-1: IMPORTS & DEPENDENCIES.........................................//
//Sub-judul: Modul Flutter, Firebase, dan dependensi lokal................//
import 'dart:typed_data'; // [PERBAIKAN WEB]: Mengganti dart:io dengan typed_data (Byte)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models_veo/video_project_veo.dart';
import '../theme/app_theme.dart';
import '../providers/config_provider.dart'; // [BILINGUAL]: Import provider bahasa
//Akhir Blok 1............................................................//


//No ke-2: STATEFUL WIDGET UTAMA (SCREEN).................................//
//Sub-judul: Inisialisasi layar dan state penampung karakter..............//
class CharacterUploadVeoScreen extends ConsumerStatefulWidget {
  final String projectId;
  final VideoProjectVeo project;

  const CharacterUploadVeoScreen({
    super.key,
    required this.projectId,
    required this.project,
  });

  @override
  ConsumerState<CharacterUploadVeoScreen> createState() => _CharacterUploadVeoScreenState();
}

class _CharacterUploadVeoScreenState extends ConsumerState<CharacterUploadVeoScreen> {
  final ImagePicker _picker = ImagePicker();
  
  // [PERBAIKAN WEB]: Menyimpan gambar dalam bentuk Bytes (Uint8List) agar support 100% di Web
  List<Uint8List?> _localFileBytes = [];
  List<String?> _localFileMimeTypes = [];
  List<dynamic> _characters = [];
  
  bool _isSubmitting = false;
  double _uploadProgress = 0.0;

  // [BILINGUAL]: Helper sederhana untuk menerjemahkan teks
  String _t(bool isIndo, String en, String id) {
    return isIndo ? id : en;
  }

  @override
  void initState() {
    super.initState();
    // Duplikasi identitas karakter dari project agar aman dari modifikasi destruktif
    _characters = List.from(widget.project.identifiedCharacters ?? []);
    _localFileBytes = List<Uint8List?>.filled(_characters.length, null);
    _localFileMimeTypes = List<String?>.filled(_characters.length, null);
  }
//Akhir Blok 2............................................................//


//No ke-3: LOGIKA SELECT IMAGE, UPLOAD STORAGE & FIREBASE UPDATE..........//
//Sub-judul: Fungsi pengunggahan gambar ke Cloud Storage versi VEO online.//

  /// Memicu Image Picker Galeri Ponsel / Web
  Future<void> _pickImage(int index) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile != null && mounted) {
        // [PERBAIKAN WEB]: Langsung baca sebagai Bytes
        final Uint8List bytes = await pickedFile.readAsBytes();
        
        setState(() {
          _localFileBytes[index] = bytes;
          _localFileMimeTypes[index] = pickedFile.mimeType ?? 'image/png';
        });
      }
    } catch (e) {
      debugPrint("[CharacterUpload] Error picking image: $e");
    }
  }

  /// Menghapus Pilihan File Gambar pada Index tertentu
  void _clearImage(int index) {
    if (mounted) {
      setState(() {
        _localFileBytes[index] = null;
        _localFileMimeTypes[index] = null;
      });
    }
  }

  /// Proses Utama: Mengunggah Aset Pengguna ke Storage & Mengunci Firebase
  Future<void> _submitAndUpload() async {
    setState(() {
      _isSubmitting = true;
      _uploadProgress = 0.0;
    });

    // Ambil status bahasa saat ini untuk terjemahan SnackBar
    final isIndo = ref.read(appLanguageProvider).languageCode == 'id';

    try {
      final FirebaseStorage storage = FirebaseStorage.instance;
      final String bucketName = storage.ref().bucket;

      // Hitung total file yang wajib diupload untuk melacak kalkulasi progress bar
      int totalFilesToUpload = _localFileBytes.where((bytes) => bytes != null).length;
      int uploadedCount = 0;

      for (int i = 0; i < _characters.length; i++) {
        final Uint8List? fileBytes = _localFileBytes[i];
        if (fileBytes == null) continue; // Jika user mengosongkan (melewati)

        final String charName = _characters[i]['name'] ?? 'char_$i';
        final String charFileName = charName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').toLowerCase();
        
        // [PERBAIKAN BUG]: Menambahkan index _$i untuk mencegah penimpaan file bernama sama
        final String storagePath = "projects_veo/${widget.projectId}/characters/${charFileName}_$i.png";
        final Reference storageRef = storage.ref().child(storagePath);

        debugPrint("[CharacterUpload] Memulai upload untuk: $charName");
        
        // [PERBAIKAN WEB]: Gunakan putData alih-alih putFile
        final UploadTask uploadTask = storageRef.putData(
          fileBytes,
          SettableMetadata(contentType: _localFileMimeTypes[i] ?? 'image/png'),
        );

        // Pantau real-time progress untuk satu file ini
        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          double fileProgress = snapshot.bytesTransferred / snapshot.totalBytes;
          if (mounted && totalFilesToUpload > 0) {
            setState(() {
              _uploadProgress = (uploadedCount + fileProgress) / totalFilesToUpload;
            });
          }
        });

        // Tunggu hingga proses upload ke Storage selesai
        await uploadTask;
        
        final String downloadUrl = await storageRef.getDownloadURL();
        final String gcsUri = "gs://$bucketName/$storagePath";

        // [PERBAIKAN BUG]: Buat salinan map baru agar tidak memutasi state sumber secara langsung (Deep update)
        _characters[i] = Map<String, dynamic>.from(_characters[i]);
        _characters[i]['imageUri'] = downloadUrl;
        _characters[i]['gcsUri'] = gcsUri;

        uploadedCount++;
      }

      await FirebaseFirestore.instance
          .collection('projects_veo')
          .doc(widget.projectId)
          .update({
            'identifiedCharacters': _characters,
            'status': 'READY_FOR_IMAGE_GEN', // Sinyal untuk men-trigger backend Tahap 1B
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _t(isIndo, 
                "Character images successfully uploaded! The system is processing the scenes.", 
                "Gambar karakter berhasil diunggah! Sistem sedang memproses adegan."
              )
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(); // Kembali ke loading screen secara aman
      }
    } catch (e) {
      debugPrint("[CharacterUpload] Kesalahan Kritis Saat Unggah: $e");
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _t(isIndo, 
                "An upload error occurred: $e", 
                "Terjadi kesalahan pengunggahan: $e"
              )
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
//Akhir Blok 3............................................................//


//No ke-4: BUILD LAYOUT DENGAN THEME DARK KHAS VEO........................//
//Sub-judul: Desain antarmuka pengguna, list karakter, dan tombol aksi....//
  @override
  Widget build(BuildContext context) {
    // [BILINGUAL]: Membaca state bahasa dari provider
    final currentLocale = ref.watch(appLanguageProvider);
    final isIndo = currentLocale.languageCode == 'id';

    return Theme(
      data: AppTheme.darkTheme,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_t(isIndo, "Manual Character Reference", "Referensi Karakter Manual")),
          centerTitle: true,
          automaticallyImplyLeading: !_isSubmitting, 
        ),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Deskripsi Header
              Text(
                _t(isIndo, "Upload Reference Images", "Unggah Gambar Referensi"),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _t(isIndo, 
                  "Choose a half body portrait facing forward for consistent results. Characters without an uploaded image will be automatically generated by AI.", 
                  "Pilih gambar berformat setengah badan/portrait tampak depan lurus (half body portrait facing forward) untuk hasil yang konsisten. Karakter yang tidak diupload akan otomatis dibuat oleh AI."
                ),
                style: const TextStyle(fontSize: 13, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Daftar Karakter Dinamis
              Expanded(
                child: ListView.separated(
                  itemCount: _characters.length,
                  separatorBuilder: (context, index) => const Divider(color: Colors.white10),
                  itemBuilder: (context, index) {
                    final char = _characters[index];
                    final Uint8List? fileBytes = _localFileBytes[index];
                    // Penamaan default fallback juga disesuaikan dengan bahasa
                    final String defaultCharName = _t(isIndo, 'Character ${index + 1}', 'Karakter ${index + 1}');
                    final String charName = char['name'] ?? defaultCharName;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        children: [
                          // Kolom Nomor & Nama Karakter
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "${index + 1}. $charName",
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _t(isIndo, "Manual upload slot", "Slot unggah manual"),
                                  style: const TextStyle(fontSize: 12, color: Colors.purpleAccent),
                                ),
                              ],
                            ),
                          ),
                          
                          // [PERBAIKAN AREA KLIK SANGAT KRUSIAL]: Seluruh area 80x80 dibungkus InkWell
                          // Agar sekali sentuh di bagian mana saja pada kotak, galeri langsung terbuka!
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _isSubmitting ? null : () => _pickImage(index),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: fileBytes != null ? Colors.purpleAccent : Colors.white24,
                                    width: 1.5,
                                  ),
                                ),
                                child: fileBytes != null
                                    ? Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(9),
                                            child: Image.memory(
                                              fileBytes,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                          Positioned(
                                            top: 2,
                                            right: 2,
                                            child: GestureDetector(
                                              onTap: () => _clearImage(index),
                                              child: Container(
                                                padding: const EdgeInsets.all(2),
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
                                    : Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                            Icons.add_photo_alternate_outlined, 
                                            color: Colors.purpleAccent, 
                                            size: 26
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _t(isIndo, "Pick Photo", "Pilih Foto"),
                                            style: const TextStyle(
                                              fontSize: 10, 
                                              color: Colors.purpleAccent, 
                                              fontWeight: FontWeight.bold
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

              // Indikator Progress Unggahan 
              if (_isSubmitting)
                Column(
                  children: [
                    LinearProgressIndicator(
                      value: _uploadProgress,
                      backgroundColor: Colors.grey.shade800,
                      color: Colors.purpleAccent,
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "${_t(isIndo, 'Uploading Assets:', 'Mengunggah Aset:')} ${(_uploadProgress * 100).toStringAsFixed(0)}%",
                      style: const TextStyle(fontSize: 13, color: Colors.purpleAccent, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),

              // Tombol Submit / Unggah
              ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submitAndUpload,
                icon: const Icon(Icons.cloud_upload_outlined),
                label: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Text(
                    _t(isIndo, "CONCLUDE & SUBMIT", "SELESAI & UNGGAH"),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey[800],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
//Akhir Blok 4............................................................//