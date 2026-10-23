//============================================================================//
// DIREKTORI: lib/entertainment/mytube/screens/                              //
// FILE: MYTUBE_ADMIN_PROFILE_SCREEN.DART                                    //
// LAYAR PENGATURAN PROFIL CREATOR / ADMIN MYTUBE (CHANNEL ID & CREATED AT)  //
//============================================================================//

//No ke-1....................................................................//
//IMPORTS & DEPENDENCIES                                                     //
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../providers/config_provider.dart';
import '../models/creator_mytube_model.dart';
import '../services/firestore_mytube_service.dart';
import 'mytube_followers_screen.dart';
//............................................................................//

//No ke-2....................................................................//
//WIDGET DECLARATION & STATE SETUP                                           //
class MytubeAdminProfileScreen extends ConsumerStatefulWidget {
  const MytubeAdminProfileScreen({super.key});

  @override
  ConsumerState<MytubeAdminProfileScreen> createState() => _MytubeAdminProfileScreenState();
}

class _MytubeAdminProfileScreenState extends ConsumerState<MytubeAdminProfileScreen> {
  final FirestoreMytubeService _service = FirestoreMytubeService();
  final ImagePicker _picker = ImagePicker();

  User? _currentUser;
  bool _isLoading = true;
  bool _isSaving = false;

  // [IDENTITAS UTAMA CHANNEL]: Channel ID Abadi, Tanggal Registrasi & Peran Akun
  String _channelId = '';
  DateTime? _createdAt;
  String _accountRole = 'creator'; // 'admin' atau 'creator'

  // Checkbox: Pemilik Rekening Bank Sama dengan Nama Legal
  bool _isSameAsLegalName = false;

  // Controllers Identitas Channel
  final TextEditingController _channelNameController = TextEditingController();
  final TextEditingController _handleController = TextEditingController();
  final TextEditingController _legalNameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  // Controllers Payout Rekening Bank
  final TextEditingController _bankNameController = TextEditingController();
  final TextEditingController _bankHolderController = TextEditingController();
  final TextEditingController _bankNumberController = TextEditingController();

  // Controllers Tautan Medsos Resmi (YouTube, FB, TikTok, Other)
  final TextEditingController _youtubeController = TextEditingController();
  final TextEditingController _facebookController = TextEditingController();
  final TextEditingController _tiktokController = TextEditingController();
  final TextEditingController _otherLinkController = TextEditingController();

  String _selectedCountry = 'Indonesia 🇮🇩';
  String _avatarUrl = '';
  CreatorMytubeModel? _existingProfile;
//............................................................................//

//No ke-3....................................................................//
//LIFECYCLE & INITIAL PROFILE LOADING                                        //
  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    _loadProfileData();

    // Listener otomatis menyinkronkan nama pemilik rekening jika centang aktif
    _legalNameController.addListener(() {
      if (_isSameAsLegalName) {
        _bankHolderController.text = _legalNameController.text;
      }
    });
  }

  Future<void> _loadProfileData() async {
    final uid = _currentUser?.uid ?? '';
    final email = _currentUser?.email ?? '';

    if (uid.isEmpty && email.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    // 1. [AMBIL ROLE RESMI AKUN DARI FIRESTORE]: Cek apakah Admin atau Creator
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data();
        final rawRole = userData?['userTier']?.toString().toLowerCase() ??
            userData?['role']?.toString().toLowerCase() ??
            'creator';
        _accountRole = rawRole;
      }
    } catch (_) {}

    // 2. Ambil data profil kreator
    final profile = await _service.getCreatorProfile(email, userId: uid);

    if (mounted) {
      if (profile != null) {
        _existingProfile = profile;
        _channelId = profile.channelId;
        _createdAt = profile.createdAt;

        _channelNameController.text = profile.channelName;
        _handleController.text = profile.handle;
        _legalNameController.text = profile.creatorLegalName;
        _addressController.text = profile.address;
        _selectedCountry = profile.country.isNotEmpty ? profile.country : 'Indonesia 🇮🇩';
        _cityController.text = profile.city;
        _phoneController.text = profile.phoneNumber;
        _avatarUrl = profile.avatarUrl;

        _bankNameController.text = profile.bankName;
        _bankHolderController.text = profile.bankAccountHolder;
        _bankNumberController.text = profile.bankAccountNumber;

        _youtubeController.text = profile.youtubeHandle;
        _facebookController.text = profile.facebookUrl;
        _tiktokController.text = profile.tiktokUrl;
        _otherLinkController.text = profile.otherUrl;

        if (profile.bankAccountHolder.isNotEmpty &&
            profile.bankAccountHolder == profile.creatorLegalName) {
          _isSameAsLegalName = true;
        }
      } else {
        _channelId = '';
        _createdAt = null;
        _channelNameController.text = '';
        _handleController.text = '';
        _legalNameController.text = '';
        _bankHolderController.text = '';
        _avatarUrl = _currentUser?.photoURL ?? '';
      }
      setState(() => _isLoading = false);
    }
  }

  void _updateAutoHandle(String channelName) {
    String clean = channelName
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[^a-z0-9_]'), '');
    if (clean.length > 25) {
      clean = clean.substring(0, 25);
    }
    _handleController.text = clean.isNotEmpty ? '@$clean' : '';
  }

  @override
  void dispose() {
    _channelNameController.dispose();
    _handleController.dispose();
    _legalNameController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _phoneController.dispose();
    _bankNameController.dispose();
    _bankHolderController.dispose();
    _bankNumberController.dispose();
    _youtubeController.dispose();
    _facebookController.dispose();
    _tiktokController.dispose();
    _otherLinkController.dispose();
    super.dispose();
  }
//............................................................................//

//No ke-4....................................................................//
//AVATAR PICKER & CLOUD STORAGE UPLOADER                                     //
  Future<void> _pickAndUploadAvatar(bool isIndo) async {
    final uid = _currentUser?.uid;
    if (uid == null) return;

    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (picked == null) return;

      final String extension = picked.name.split('.').last.toLowerCase();
      const allowedExtensions = ['jpg', 'jpeg', 'png', 'webp'];
      if (!allowedExtensions.contains(extension)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isIndo
                    ? 'Format file tidak didukung. Harap pilih gambar JPG, PNG, atau WEBP.'
                    : 'Unsupported file format. Please select a JPG, PNG, or WEBP image.',
                style: const TextStyle(fontSize: 14),
              ),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }

      final bytes = await picked.readAsBytes();

      const int maxBytes = 3 * 1024 * 1024; // 3 MB
      if (bytes.lengthInBytes > maxBytes) {
        if (mounted) {
          final double sizeMb = bytes.lengthInBytes / (1024 * 1024);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isIndo
                    ? 'Ukuran foto terlalu besar (${sizeMb.toStringAsFixed(1)} MB). Maksimal 3 MB.'
                    : 'Photo size is too large (${sizeMb.toStringAsFixed(1)} MB). Maximum 3 MB allowed.',
                style: const TextStyle(fontSize: 14),
              ),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }

      setState(() => _isSaving = true);

      // [KUNCI STORAGE CHANNEL ID]: Folder foto profil diikat langsung ke Channel ID abadi
      final cleanEmail = _currentUser?.email?.trim().toLowerCase();
      final folderKey = _channelId.isNotEmpty
          ? _channelId
          : ((cleanEmail != null && cleanEmail.isNotEmpty) ? cleanEmail : uid);

      final refStorage = FirebaseStorage.instance
          .ref()
          .child('mytube')
          .child(folderKey)
          .child('profil')
          .child('avatar.jpg');

      final uploadTask = await refStorage.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      if (mounted) {
        setState(() {
          _avatarUrl = downloadUrl;
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isIndo ? 'Foto avatar berhasil diperbarui!' : 'Avatar photo updated successfully!',
              style: const TextStyle(fontSize: 14),
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isIndo ? 'Gagal mengunggah avatar: $e' : 'Failed to upload avatar: $e',
              style: const TextStyle(fontSize: 14),
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }
//............................................................................//

//No ke-5....................................................................//
//SAVE PROFILE TO FIRESTORE WITH IMMUTABLE CHANNEL ID ANCHOR                 //
  Future<void> _saveProfile(bool isIndo) async {
    final uid = _currentUser?.uid ?? '';
    if (uid.isEmpty) return;

    final channelName = _channelNameController.text.trim();
    if (channelName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isIndo ? 'Nama Channel tidak boleh kosong.' : 'Channel Name cannot be empty.',
            style: const TextStyle(fontSize: 14),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      String finalHandle = _handleController.text.trim();
      if (finalHandle.isNotEmpty && !finalHandle.startsWith('@')) {
        finalHandle = '@$finalHandle';
      }

      // [KUNCI ABADI CHANNEL ID]: Mempertahankan ID saluran asli sekalipun email/nama diubah
      final resolvedChannelId = _channelId.isNotEmpty
          ? _channelId
          : (_existingProfile?.channelId.isNotEmpty == true
              ? _existingProfile!.channelId
              : uid);

      final updatedModel = CreatorMytubeModel(
        id: resolvedChannelId,
        creatorId: uid, // UID Akun Pemilik (Bisa dialihkan kepemilikannya)
        email: _currentUser?.email ?? '',
        channelName: channelName,
        handle: finalHandle,
        creatorLegalName: _legalNameController.text.trim(),
        address: _addressController.text.trim(),
        country: _selectedCountry,
        city: _cityController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        avatarUrl: _avatarUrl,
        bankName: _bankNameController.text.trim(),
        bankAccountHolder: _bankHolderController.text.trim(),
        bankAccountNumber: _bankNumberController.text.trim(),
        youtubeHandle: _youtubeController.text.trim(),
        facebookUrl: _facebookController.text.trim(),
        tiktokUrl: _tiktokController.text.trim(),
        otherUrl: _otherLinkController.text.trim(),
        isVerified: true,
        totalVideos: _existingProfile?.totalVideos ?? 0,
        totalViews: _existingProfile?.totalViews ?? 0,
        createdAt: _createdAt ?? _existingProfile?.createdAt ?? DateTime.now(),
      );

      await _service.saveCreatorProfile(updatedModel);

      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isIndo
                  ? 'Profil Creator Mytube berhasil disimpan!'
                  : 'Mytube Creator Profile saved successfully!',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isIndo ? 'Gagal menyimpan profil: $e' : 'Failed to save profile: $e',
              style: const TextStyle(fontSize: 14),
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }
//............................................................................//

//No ke-6....................................................................//
//UI BUILD & ENLARGED CONTRAST FORM RENDER                                   //
  @override
  Widget build(BuildContext context) {
    final currentLocale = ref.watch(appLanguageProvider);
    final isIndo = currentLocale.languageCode == 'id';
    String t(String en, String id) => isIndo ? id : en;

    return Scaffold(
      backgroundColor: const Color(0xFF121214),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E24),
        elevation: 0,
        title: Text(
          t('Admin / Creator Profile', 'Profil Admin / Creator'),
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: TextButton.icon(
              onPressed: _isSaving ? null : () => _saveProfile(isIndo),
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amberAccent),
                    )
                  : const Icon(Icons.check, color: Colors.amberAccent, size: 22),
              label: Text(
                t('Save', 'Simpan'),
                style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.amberAccent))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- SEKSI 1: AVATAR & AKUN OTOMATIS RATA SEJAJAR ---
                  Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.amberAccent.withOpacity(0.2),
                          backgroundImage: _avatarUrl.isNotEmpty ? NetworkImage(_avatarUrl) : null,
                          child: _avatarUrl.isEmpty
                              ? const Icon(Icons.person, color: Colors.amberAccent, size: 54)
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _isSaving ? null : () => _pickAndUploadAvatar(isIndo),
                            child: Container(
                              padding: const EdgeInsets.all(9),
                              decoration: const BoxDecoration(
                                color: Colors.amberAccent,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.camera_alt, color: Colors.black, size: 20),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // [KARTU IDENTITAS RESMI]: Channel ID, Status Akun (ADMIN/CREATOR), Created At, UID & Email
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E24),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amberAccent.withOpacity(0.35), width: 1.2),
                    ),
                    child: Column(
                      children: [
                        // 1. Channel ID Utama (Dilengkapi Tombol Salin Cepat)
                        _buildAlignedAccountRowWithAction(
                          label: 'Channel ID',
                          value: _channelId.isNotEmpty ? _channelId : t('Auto-Generated on Save', 'Dibuat Otomatis saat Simpan'),
                          icon: Icons.tag_rounded,
                          trailingAction: _channelId.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.copy_rounded, color: Colors.amberAccent, size: 18),
                                  tooltip: t('Copy Channel ID', 'Salin Channel ID'),
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(text: _channelId));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(isIndo ? 'Channel ID berhasil disalin!' : 'Channel ID copied to clipboard!'),
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                )
                              : null,
                        ),
                        const Divider(color: Colors.white12, height: 18),

                        // 2. [BARU]: Status Peran Akun Resmi (ADMIN vs CREATOR Lencana Menyala)
                        _buildAlignedAccountRowWithAction(
                          label: t('Account Role', 'Status Akun'),
                          value: _accountRole.toUpperCase(),
                          icon: _accountRole == 'admin' ? Icons.shield_rounded : Icons.verified_user_rounded,
                          trailingAction: _buildRoleBadge(_accountRole),
                        ),
                        const Divider(color: Colors.white12, height: 18),

                        // 3. Tanggal Pembuatan Saluran (Created At)
                        _buildAlignedAccountRow(
                          label: t('Created At', 'Dibuat Pada'),
                          value: _formatDateBilingual(_createdAt, t),
                          icon: Icons.calendar_today_rounded,
                        ),
                        const Divider(color: Colors.white12, height: 18),

                        // 4. User ID Akun Pemilik (UID)
                        _buildAlignedAccountRow(
                          label: 'Owner UID',
                          value: _currentUser?.uid ?? '-',
                          icon: Icons.vpn_key_outlined,
                        ),
                        const Divider(color: Colors.white12, height: 18),

                        // 5. Email Akun
                        _buildAlignedAccountRow(
                          label: 'Email',
                          value: _currentUser?.email ?? '-',
                          icon: Icons.email_outlined,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // KARTU PERFORMA CHANNEL & TOTAL PENGIKUT REAL-TIME
                  _buildChannelStatsCard(t, isIndo),
                  const SizedBox(height: 26),

                  // --- SEKSI 2: IDENTITAS CHANNEL & CREATOR ---
                  _buildSectionHeader(t('CHANNEL & CREATOR IDENTITY', 'IDENTITAS CHANNEL & CREATOR')),
                  const SizedBox(height: 14),

                  _buildTextField(
                    label: t('Channel Name (Max 30 Chars)', 'Nama Channel (Maks 30 Karakter)'),
                    controller: _channelNameController,
                    hint: t('Enter your channel name...', 'Masukkan nama channel Anda...'),
                    maxLength: 30,
                    onChanged: (val) {
                      _updateAutoHandle(val);
                    },
                  ),
                  const SizedBox(height: 14),

                  _buildTextField(
                    label: t('Channel Handle (Auto-Generated)', 'ID Unik Handle (Otomatis)'),
                    controller: _handleController,
                    hint: '@channel_handle',
                    readOnly: true,
                    prefixIcon: const Icon(Icons.alternate_email, color: Colors.amberAccent, size: 20),
                  ),
                  const SizedBox(height: 14),

                  _buildTextField(
                    label: t('Creator Legal Name (ID Card / Passport)', 'Nama Lengkap Creator (Sesuai KTP)'),
                    controller: _legalNameController,
                    hint: t('Your full legal name', 'Nama lengkap sesuai kartu identitas'),
                  ),
                  const SizedBox(height: 14),

                  _buildTextField(
                    label: t('Address (Max 100 Chars)', 'Alamat Domisili (Maks 100 Karakter)'),
                    controller: _addressController,
                    hint: t('Enter complete address...', 'Masukkan alamat lengkap...'),
                    maxLines: 3,
                    maxLength: 100,
                  ),
                  const SizedBox(height: 14),

                  _buildCountryPickerTile(t),
                  const SizedBox(height: 14),

                  _buildTextField(
                    label: t('City', 'Kota'),
                    controller: _cityController,
                    hint: t('e.g. Jakarta / Bandung / Surabaya', 'Misal: Jakarta / Bandung / Surabaya'),
                  ),
                  const SizedBox(height: 14),

                  _buildTextField(
                    label: t('WhatsApp / Phone Number', 'Nomor WhatsApp / Ponsel'),
                    controller: _phoneController,
                    hint: '+628xxxxxxxxxx',
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 28),

                  // --- SEKSI 3: REKENING BANK & PAYOUT ---
                  _buildSectionHeader(t('PAYOUT & BANK ACCOUNT DETAILS', 'DATA REKENING BANK & PENCAIRAN')),
                  const SizedBox(height: 14),

                  _buildTextField(
                    label: t('Bank Name', 'Nama Bank'),
                    controller: _bankNameController,
                    hint: t('e.g. BCA / Mandiri / BNI / BRI', 'Misal: BCA / Mandiri / BNI / BRI'),
                  ),
                  const SizedBox(height: 14),

                  _buildTextField(
                    label: t('Bank Account Holder Name', 'Nama Pemilik Rekening Bank'),
                    controller: _bankHolderController,
                    hint: t('Account holder name as in bank book', 'Nama pemilik sesuai buku tabungan'),
                    readOnly: _isSameAsLegalName,
                  ),
                  const SizedBox(height: 6),

                  Theme(
                    data: ThemeData(unselectedWidgetColor: Colors.white54),
                    child: CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      activeColor: Colors.amberAccent,
                      checkColor: Colors.black,
                      value: _isSameAsLegalName,
                      title: Text(
                        t('Same as Creator Legal Name', 'Sama dengan Nama Lengkap / KTP'),
                        style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w500),
                      ),
                      onChanged: (val) {
                        setState(() {
                          _isSameAsLegalName = val ?? false;
                          if (_isSameAsLegalName) {
                            _bankHolderController.text = _legalNameController.text.trim();
                          }
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 8),

                  _buildTextField(
                    label: t('Bank Account Number', 'Nomor Rekening Bank'),
                    controller: _bankNumberController,
                    hint: '1234567890',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 28),

                  // --- SEKSI 4: MEDIA SOSIAL RESMI ---
                  _buildSectionHeader(t('OFFICIAL SOCIAL MEDIA LINKS', 'TAUTAN MEDIA SOSIAL RESMI')),
                  const SizedBox(height: 14),

                  _buildTextField(
                    label: 'YouTube Channel',
                    controller: _youtubeController,
                    hint: 'youtube.com/@channel',
                    prefixIcon: const Icon(Icons.play_circle_fill_rounded, color: Colors.redAccent, size: 22),
                  ),
                  const SizedBox(height: 14),

                  _buildTextField(
                    label: 'Facebook (FB)',
                    controller: _facebookController,
                    hint: 'facebook.com/profile',
                    prefixIcon: const Icon(Icons.facebook, color: Colors.blueAccent, size: 22),
                  ),
                  const SizedBox(height: 14),

                  _buildTextField(
                    label: 'TikTok',
                    controller: _tiktokController,
                    hint: 'tiktok.com/@username',
                    prefixIcon: const Icon(Icons.music_note_rounded, color: Colors.cyanAccent, size: 22),
                  ),
                  const SizedBox(height: 14),

                  _buildTextField(
                    label: t('Other Link', 'Tautan Lainnya (Bebas)'),
                    controller: _otherLinkController,
                    hint: 'https://...',
                    prefixIcon: const Icon(Icons.link_rounded, color: Colors.amberAccent, size: 22),
                  ),
                  const SizedBox(height: 36),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amberAccent,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isSaving ? null : () => _saveProfile(isIndo),
                      child: _isSaving
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
                            )
                          : Text(
                              t('Save Creator Profile', 'Simpan Profil Creator'),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  // [HELPER BADGE STATUS PERAN RESMI]: Tampilan Kontras Elegan
  Widget _buildRoleBadge(String role) {
    final isAdmin = role.toLowerCase() == 'admin';
    final color = isAdmin ? const Color(0xFF6366F1) : const Color(0xFF10B981);
    final label = isAdmin ? 'ADMIN' : 'CREATOR';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isAdmin ? Icons.shield_rounded : Icons.verified_rounded,
            color: color,
            size: 13,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 10.5,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
//............................................................................//

//No ke-7....................................................................//
//HELPER WIDGETS & SEARCHABLE COUNTRY PICKER MODAL                           //
  Widget _buildChannelStatsCard(String Function(String, String) t, bool isIndo) {
    final cleanEmail = _currentUser?.email?.trim().toLowerCase() ?? '';
    final uid = _currentUser?.uid ?? '';
    final docKey = _channelId.isNotEmpty ? _channelId : (cleanEmail.isNotEmpty ? cleanEmail : uid);

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('mytube').doc(docKey).snapshots(),
      builder: (context, snapshot) {
        int totalFollowers = 0;
        int totalViews = _existingProfile?.totalViews ?? 0;
        int totalVideos = _existingProfile?.totalVideos ?? 0;

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          totalFollowers = (data['total_followers'] as num?)?.toInt() ?? 0;
          totalViews = (data['total_views'] as num?)?.toInt() ?? totalViews;
          final totalShorts = (data['total_shorts'] as num?)?.toInt() ?? 0;
          final totalLongs = (data['total_longs'] as num?)?.toInt() ?? 0;
          totalVideos = (totalShorts + totalLongs) > 0 ? (totalShorts + totalLongs) : ((data['total_videos'] as num?)?.toInt() ?? totalVideos);
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E1E24), Color(0xFF262630)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.amberAccent.withOpacity(0.35), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    t('CHANNEL PERFORMANCE', 'PERFORMA CHANNEL'),
                    style: const TextStyle(
                      color: Colors.amberAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.amberAccent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      t('Live Stats', 'Statistik Langsung'),
                      style: const TextStyle(color: Colors.amberAccent, fontSize: 10.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const Divider(color: Colors.white12, height: 18),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => MytubeFollowersScreen(
                              creatorEmail: docKey,
                              channelName: _channelNameController.text.trim(),
                            ),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.amberAccent.withOpacity(0.35)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.people_alt_rounded, color: Colors.amberAccent, size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  _formatCompactNumber(totalFollowers),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  t('Followers', 'Pengikut'),
                                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                                ),
                                const SizedBox(width: 2),
                                const Icon(Icons.chevron_right, color: Colors.amberAccent, size: 12),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.visibility_rounded, color: Colors.blueAccent, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                _formatCompactNumber(totalViews),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            t('Views', 'Tayangan'),
                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.video_library_rounded, color: Colors.orangeAccent, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                _formatCompactNumber(totalVideos),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            t('Videos', 'Video'),
                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatCompactNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return '$number';
  }

  String _formatDateBilingual(DateTime? dt, String Function(String, String) t) {
    if (dt == null) return t('Not set yet', 'Belum tercatat');
    const monthsEn = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const monthsId = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    final m = t(monthsEn[dt.month - 1], monthsId[dt.month - 1]);
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} $m ${dt.year}, $h:$min';
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.amberAccent,
        fontSize: 13.5,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.1,
      ),
    );
  }

  Widget _buildAlignedAccountRow({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return _buildAlignedAccountRowWithAction(
      label: label,
      value: value,
      icon: icon,
      trailingAction: null,
    );
  }

  Widget _buildAlignedAccountRowWithAction({
    required String label,
    required String value,
    required IconData icon,
    Widget? trailingAction,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, color: Colors.amberAccent, size: 20),
        const SizedBox(width: 12),
        SizedBox(
          width: 105,
          child: Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
        const Text(':', style: TextStyle(color: Colors.white38, fontSize: 13)),
        const SizedBox(width: 8),
        Expanded(
          child: SelectableText(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
            ),
          ),
        ),
        if (trailingAction != null) trailingAction,
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    int? maxLength,
    bool readOnly = false,
    Widget? prefixIcon,
    TextInputType? keyboardType,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 13.5, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          maxLength: maxLength,
          readOnly: readOnly,
          keyboardType: keyboardType,
          onChanged: onChanged,
          style: TextStyle(
            color: readOnly ? Colors.white60 : Colors.white,
            fontSize: 14.5,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white24, fontSize: 14),
            prefixIcon: prefixIcon,
            filled: true,
            fillColor: readOnly ? const Color(0xFF16161A) : const Color(0xFF1E1E24),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            counterStyle: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ),
      ],
    );
  }

  Widget _buildCountryPickerTile(String Function(String, String) t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t('Country (Worldwide Selection)', 'Negara (Pilihan Seluruh Dunia)'),
          style: const TextStyle(color: Colors.white70, fontSize: 13.5, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: () => _showCountrySearchDialog(t),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E24),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.public, color: Colors.amberAccent, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _selectedCountry,
                    style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w500),
                  ),
                ),
                const Icon(Icons.arrow_drop_down, color: Colors.white54, size: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showCountrySearchDialog(String Function(String, String) t) {
    final searchController = TextEditingController();
    List<String> filteredCountries = List.from(_allCountries);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    t('Select Country', 'Pilih Negara'),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
                  ),
                  const SizedBox(height: 14),

                  TextField(
                    controller: searchController,
                    style: const TextStyle(color: Colors.white, fontSize: 14.5),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search, color: Colors.white54, size: 22),
                      hintText: t('Search country name...', 'Cari nama negara...'),
                      hintStyle: const TextStyle(color: Colors.white24, fontSize: 14),
                      filled: true,
                      fillColor: const Color(0xFF141418),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    onChanged: (query) {
                      setModalState(() {
                        filteredCountries = _allCountries
                            .where((c) => c.toLowerCase().contains(query.toLowerCase()))
                            .toList();
                      });
                    },
                  ),
                  const SizedBox(height: 12),

                  Expanded(
                    child: ListView.separated(
                      itemCount: filteredCountries.length,
                      separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
                      itemBuilder: (_, index) {
                        final country = filteredCountries[index];
                        final isSelected = country == _selectedCountry;

                        return ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          title: Text(
                            country,
                            style: TextStyle(
                              color: isSelected ? Colors.amberAccent : Colors.white,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 14.5,
                            ),
                          ),
                          trailing: isSelected ? const Icon(Icons.check, color: Colors.amberAccent, size: 20) : null,
                          onTap: () {
                            setState(() => _selectedCountry = country);
                            Navigator.of(ctx).pop();
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  static const List<String> _allCountries = [
    'Indonesia 🇮🇩',
    'United States 🇺🇸',
    'United Kingdom 🇬🇧',
    'Australia 🇦🇺',
    'India 🇮🇳',
    'Saudi Arabia 🇸🇦',
    'United Arab Emirates 🇦🇪',
    'Egypt 🇪🇬',
    'Bangladesh 🇧🇩',
    'Denmark 🇩🇰',
    'Netherlands 🇳🇱',
    'Belgium 🇧🇪',
    'Finland 🇫🇮',
    'France 🇫🇷',
    'Canada 🇨🇦',
    'Germany 🇩🇪',
    'Italy 🇮🇹',
    'Japan 🇯🇵',
    'South Korea 🇰🇷',
    'China 🇨🇳',
    'Taiwan 🇹🇼',
    'Norway 🇳🇴',
    'Poland 🇵🇱',
    'Brazil 🇧🇷',
    'Portugal 🇵🇹',
    'Russia 🇷🇺',
    'Spain 🇪🇸',
    'Mexico 🇲🇽',
    'Sweden 🇸🇪',
    'Thailand 🇹🇭',
    'Turkey 🇹🇷',
    'Ukraine 🇺🇦',
    'Pakistan 🇵🇰',
    'Vietnam 🇻🇳',
    'Malaysia 🇲🇾',
    'Singapore 🇸🇬',
    'Philippines 🇵🇭',
    'Switzerland 🇨🇭',
    'Austria 🇦🇹',
    'Qatar 🇶🇦',
  ];
}
//............................................................................//