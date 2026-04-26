// LIB/SCREENS_NARAKU/IMAGE2VIDEO_SCREEN.DART //
// ....................................................... //
// [KATEGORI: UI SCREEN FRONTEND] //
// [TUJUAN: Antarmuka Image2Video dengan Image Picker, Loading Modern, Fix CORS, & Video Player] //

// No ke-1: IMPORT & SETUP //
// ....................................................... //
import 'dart:io'; 
import 'package:flutter/foundation.dart'; // [BARU] Wajib untuk mendeteksi kIsWeb
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:video_player/video_player.dart'; 
import 'package:image_picker/image_picker.dart'; 

// [IMPORT NAVIGASI MASTER]
import '../screens/project_dashboard_screen.dart';

// [IMPORT VIEWMODEL]
import '../view_model_naraku/image2video_view_model.dart'; 

// [IMPORT PROVIDER & MODELS]
import '../providers/user_provider.dart';
import '../providers/config_provider.dart'; 
import '../theme/app_theme.dart';

class Image2VideoScreen extends ConsumerStatefulWidget {
  const Image2VideoScreen({super.key});

  @override
  ConsumerState<Image2VideoScreen> createState() => _Image2VideoScreenState();
}
// ....................................................... //

// No ke-2: STATE & INITIALIZATION //
// ....................................................... //
class _Image2VideoScreenState extends ConsumerState<Image2VideoScreen> {
  final int _maxPromptLength = 2000;
  final _formKey = GlobalKey<FormState>();
  
  // [PERBAIKAN] Menggunakan XFile untuk dukungan mutlak Web & Mobile
  XFile? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final viewModel = ref.read(image2VideoViewModelProvider.notifier);
      viewModel.narrativeController.addListener(_onTextChanged);
    });
  }

  void _onTextChanged() {
    setState(() {}); 
  }

  // [PERBAIKAN] Fungsi untuk memilih gambar dari galeri (mendukung Web/Mobile)
  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85, // Kompresi ringan agar efisien
      );
      if (pickedFile != null) {
        setState(() {
          _selectedImage = pickedFile; // [PERBAIKAN] Langsung menyimpan XFile
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Gagal mengambil gambar: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
// ....................................................... //

// No ke-3: LOGIC & REPORT FUNCTION //
// ....................................................... //
  void _showReportDialog(BuildContext context, WidgetRef ref, String videoUrl) {
    final TextEditingController reasonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Lapor Video / Report Video"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Apakah video ini melanggar kebijakan? Berikan alasan Anda.",
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: "Alasan (NSFW, Kekerasan, dll)...",
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              final user = ref.read(firestoreUserProvider).valueOrNull;
              final userId = user?.uid ?? 'anonymous'; 

              FirebaseFirestore.instance.collection('reports').add({
                'contentUrl': videoUrl,
                'contentType': 'video_image2video', // [SESUAIKAN]
                'reason': reasonController.text.isEmpty ? 'No reason provided' : reasonController.text,
                'reportedAt': FieldValue.serverTimestamp(),
                'userId': userId,
                'feature': 'Generator Image2Video', // [SESUAIKAN]
              }).then((_) {
                if (context.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Laporan dikirim. Terima kasih."),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              }).catchError((error) {
                if (context.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Gagal mengirim laporan: $error"),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              });
            },
            child: const Text("Kirim Laporan", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
// ....................................................... //

// No ke-4: MAIN BUILDER & FORM UI //
// ....................................................... //
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(image2VideoViewModelProvider);
    final viewModel = ref.read(image2VideoViewModelProvider.notifier);
    final userAsync = ref.watch(firestoreUserProvider);
    final configAsync = ref.watch(appConfigProvider);
    final currentLocale = ref.watch(appLanguageProvider);
    final isIndo = currentLocale.languageCode == 'id';
    String t(String en, String id) => isIndo ? id : en;

    ref.listen<Image2VideoState>(image2VideoViewModelProvider, (previous, next) {
      if (next.errorMessage != null && previous?.errorMessage == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    });

    // Validasi input bergantung pada Gambar, Teks opsional
    final bool hasImage = _selectedImage != null;
    
    int currentBalance = 0;
    int requiredTokens = 0; 
    bool configReady = false;
    bool userReady = false;

    userAsync.whenData((user) {
      currentBalance = user.tokenBalance;
      userReady = true;
    });

    configAsync.whenData((config) {
      // Kalkulasi Harga Dinamis menggunakan image2videoCosts
      final i2vCosts = config.costs.image2videoCosts; 
      int costPerSecond = 0;

      if (state.selectedResolution == '480') {
        costPerSecond = state.isAudioEnabled ? i2vCosts.res480WithAudio : i2vCosts.res480NoAudio;
      } else if (state.selectedResolution == '720') {
        costPerSecond = state.isAudioEnabled ? i2vCosts.res720WithAudio : i2vCosts.res720NoAudio;
      } else if (state.selectedResolution == '1080') {
        costPerSecond = state.isAudioEnabled ? i2vCosts.res1080WithAudio : i2vCosts.res1080NoAudio;
      } else {
        costPerSecond = i2vCosts.res480NoAudio; 
      }

      requiredTokens = costPerSecond * state.selectedDuration;
      configReady = true;
    });

    final bool hasSufficientFunds = currentBalance >= requiredTokens;
    final bool isOutOfTokens = hasImage && !hasSufficientFunds; // Peringatan muncul jika sudah ada gambar tapi saldo kurang
    final bool providersLoading = userAsync.isLoading || configAsync.isLoading;
    // canSubmit diizinkan jika sudah ada gambar (teks tidak wajib)
    final bool canSubmit = hasImage && hasSufficientFunds && !state.isLoading && userReady && configReady;

    return Theme(
      data: AppTheme.darkTheme,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Image2Video'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 20.0),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isOutOfTokens ? Colors.redAccent : Colors.white24,
                      width: 1
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.token, 
                        size: 16, 
                        color: isOutOfTokens ? Colors.redAccent : Colors.amber
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "$requiredTokens / $currentBalance", 
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isOutOfTokens ? Colors.redAccent : Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Layout Row untuk Image Upload (25%) & Text Prompt (75%)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 25% AREA UPLOAD GAMBAR
                            Expanded(
                              flex: 1,
                              child: GestureDetector(
                                onTap: state.isLoading ? null : _pickImage,
                                child: Container(
                                  height: 200, // Menyamakan dengan perkiraan tinggi teks 8 baris
                                  decoration: BoxDecoration(
                                    color: Colors.black26,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _selectedImage != null ? Colors.blueAccent : Colors.white30,
                                      width: _selectedImage != null ? 2 : 1,
                                    ),
                                  ),
                                  child: _selectedImage != null
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(10),
                                          child: Stack(
                                            fit: StackFit.expand,
                                            children: [
                                              // [PERBAIKAN] Deteksi Platform Rendering Gambar (Aman untuk Web)
                                              kIsWeb 
                                                ? Image.network(
                                                    _selectedImage!.path,
                                                    fit: BoxFit.cover,
                                                  )
                                                : Image.file(
                                                    File(_selectedImage!.path),
                                                    fit: BoxFit.cover,
                                                  ),
                                              const Positioned(
                                                bottom: 8,
                                                right: 8,
                                                child: CircleAvatar(
                                                  radius: 14,
                                                  backgroundColor: Colors.black54,
                                                  child: Icon(Icons.edit, size: 16, color: Colors.white),
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      : Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Icon(Icons.add_photo_alternate_rounded, size: 40, color: Colors.white54),
                                            const SizedBox(height: 8),
                                            Text(
                                              t('Upload Image\n(Required)', 'Unggah Gambar\n(Wajib)'),
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(fontSize: 12, color: Colors.white70),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            // 75% AREA TEXT PROMPT
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: viewModel.narrativeController,
                                maxLines: 8, // Dipertahankan agar konsisten dengan tinggi gambar
                                maxLength: _maxPromptLength,
                                enabled: !state.isLoading,
                                decoration: InputDecoration(
                                  labelText: t('Video Prompt (Optional)', 'Prompt Video (Opsional)'),
                                  hintText: t('Add specific instructions or let the AI animate your image naturally.', 'Tambahkan instruksi spesifik atau biarkan AI menganimasikan gambar Anda secara alami.'),
                                  alignLabelWithHint: true,
                                ),
                                validator: (value) {
                                  return null; 
                                },
                              ),
                            ),
                          ],
                        ),
                        
                        // Error validasi manual jika form disubmit tanpa gambar
                        if (!hasImage && viewModel.narrativeController.text.isNotEmpty)
                           Padding(
                             padding: const EdgeInsets.only(top: 8.0),
                             child: Text(
                               t('An image is required to generate video.', 'Gambar wajib diunggah untuk membuat video.'),
                               style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
                             ),
                           ),

                        const SizedBox(height: 24),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: state.selectedStyle,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  labelText: t('Visual Style', 'Gaya Visual'),
                                ),
                                items: ['Realistic', 'Kartun 3D', 'Kartun 2D']
                                    .map((style) => DropdownMenuItem(
                                          value: style,
                                          child: Text(style, overflow: TextOverflow.ellipsis),
                                        ))
                                    .toList(),
                                onChanged: state.isLoading ? null : (value) {
                                  if (value != null) viewModel.setStyle(value);
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: state.selectedRatio,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  labelText: t('Aspect Ratio', 'Rasio Aspek'),
                                ),
                                items: const {
                                  '16:9': 'Landscape (16:9)',
                                  '9:16': 'Portrait (9:16)',
                                  '1:1': 'Square (1:1)',
                                }.entries.map((entry) => DropdownMenuItem(
                                      value: entry.key,
                                      child: Text(entry.value, overflow: TextOverflow.ellipsis),
                                    )).toList(),
                                onChanged: state.isLoading ? null : (value) {
                                  if (value != null) viewModel.setRatio(value);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: state.selectedResolution,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  labelText: t('Resolution', 'Resolusi'),
                                ),
                                items: ['480', '720', '1080']
                                    .map((res) => DropdownMenuItem(
                                          value: res,
                                          child: Text('${res}p', overflow: TextOverflow.ellipsis),
                                        ))
                                    .toList(),
                                onChanged: state.isLoading ? null : (value) {
                                  if (value != null) viewModel.setResolution(value);
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                value: state.selectedDuration,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  labelText: t('Duration', 'Durasi'),
                                ),
                                items: [5, 8, 10, 12]
                                    .map((dur) => DropdownMenuItem(
                                          value: dur,
                                          child: Text('$dur ${t('Seconds', 'Detik')}', overflow: TextOverflow.ellipsis),
                                        ))
                                    .toList(),
                                onChanged: state.isLoading ? null : (value) {
                                  if (value != null) viewModel.setDuration(value);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black12,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white24, width: 1),
                          ),
                          child: SwitchListTile(
                            title: Text(
                              t('Include Audio', 'Sertakan Audio'),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            subtitle: Text(
                              t('Generate sync audio: dialog, background sound/music', 'Buat dialog, suara/musik latar belakang otomatis'),
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            value: state.isAudioEnabled,
                            activeColor: Colors.blue,
                            onChanged: state.isLoading ? null : (bool value) {
                              viewModel.toggleAudio(value);
                            },
                          ),
                        ),
                        const SizedBox(height: 32),
                        ElevatedButton.icon(
                          onPressed: canSubmit 
                              ? () {
                                  if (_formKey.currentState!.validate() && _selectedImage != null) {
                                    viewModel.generateVideo(imageFile: _selectedImage);
                                  }
                                } 
                              : null,
                          icon: state.isLoading || providersLoading
                              ? const SizedBox.shrink()
                              : const Icon(Icons.auto_awesome),
                          label: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: state.isLoading || providersLoading
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 3,
                                    ),
                                  )
                                : Text(t('GENERATE VIDEO', 'BUAT VIDEO')),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.grey[800],
                            disabledForegroundColor: Colors.grey[500],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30)
                            )
                          ),
                        ),
                        if (isOutOfTokens)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Center(
                              child: Text(
                                t(
                                  "Insufficient balance. You need ${requiredTokens - currentBalance} more tokens.",
                                  "Saldo tidak cukup. Anda butuh ${requiredTokens - currentBalance} token lagi."
                                ),
                                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                              ),
                            ),
                          ),
                        const SizedBox(height: 32),
                        _buildOutputCard(context, ref, viewModel, state, t),
                      ],
                    ),
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutBack,
                top: isOutOfTokens ? 16.0 : -100.0, 
                left: 16.0,
                right: 16.0,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: isOutOfTokens ? 1.0 : 0.0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade600,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black45, 
                          blurRadius: 10, 
                          offset: Offset(0, 4)
                        )
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            t(
                              "Out of tokens. Upgrade or add more via the dashboard!",
                              "Token habis. Upgrade atau isi ulang via dashboard!"
                            ),
                            style: const TextStyle(
                              color: Colors.white, 
                              fontWeight: FontWeight.bold, 
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
// ....................................................... //

// No ke-5: MODERN OUTPUT KARTU & FIX CORS //
// ....................................................... //
  Widget _buildOutputCard(
    BuildContext context,
    WidgetRef ref,
    Image2VideoViewModel viewModel, // [SESUAIKAN] ViewModel untuk Image2Video
    Image2VideoState state, // [SESUAIKAN] State untuk Image2Video
    String Function(String, String) t,
  ) {
    final theme = Theme.of(context);
    final bool hasVideoUrl = state.generatedVideoUrl.isNotEmpty;

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Colors.white10, width: 1),
      ),
      color: const Color(0xFF1A1A2E), 
      elevation: 8,
      shadowColor: Colors.black54,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  t('Generated Video', 'Hasil Render Video'),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                if (hasVideoUrl)
                  IconButton(
                    icon: const Icon(Icons.flag_outlined, color: Colors.redAccent),
                    onPressed: () => _showReportDialog(context, ref, state.generatedVideoUrl),
                    tooltip: t('Report Video', 'Lapor Video'),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            
            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
              constraints: const BoxConstraints(minHeight: 250),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: state.isLoading 
                  ? LinearGradient(
                      colors: [Colors.blue.shade900.withOpacity(0.3), Colors.purple.shade900.withOpacity(0.3)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
                color: state.isLoading ? null : Colors.black,
                border: Border.all(color: state.isLoading ? Colors.blueAccent.withOpacity(0.5) : Colors.white12),
                boxShadow: state.isLoading 
                  ? [BoxShadow(color: Colors.blueAccent.withOpacity(0.2), blurRadius: 20, spreadRadius: 2)]
                  : [],
              ),
              child: state.isLoading
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          height: 50,
                          width: 50,
                          child: CircularProgressIndicator(color: Colors.cyanAccent, strokeWidth: 3),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          t('AI is dreaming your video...', 'AI sedang merangkai videomu...'),
                          style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          t('This magnificent render takes about 3-5 minutes.', 'Render megah ini butuh waktu 3-5 menit.'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white60, fontSize: 12),
                        ),
                      ],
                    )
                  : hasVideoUrl
                      ? Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              height: 250,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                gradient: RadialGradient(
                                  colors: [Colors.blue.shade900.withOpacity(0.5), Colors.black87],
                                  center: Alignment.center,
                                  radius: 0.8,
                                ),
                              ),
                              child: const ClipRRect(
                                borderRadius: BorderRadius.all(Radius.circular(12)),
                                child: GridPaper(
                                  color: Colors.white10,
                                  divisions: 2,
                                  subdivisions: 2,
                                ),
                              ),
                            ),
                            Container(
                              height: 250,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                gradient: LinearGradient(
                                  colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.blueAccent.withOpacity(0.9),
                                boxShadow: [
                                  BoxShadow(color: Colors.blueAccent.withOpacity(0.6), blurRadius: 20, spreadRadius: 5)
                                ],
                              ),
                              child: IconButton(
                                iconSize: 50,
                                icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => VideoPlayerDialog(videoUrl: state.generatedVideoUrl),
                                  );
                                },
                              ),
                            ),
                            Positioned(
                              bottom: 12,
                              left: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.white24),
                                ),
                                child: const Text(
                                  "AI GENERATED • MAJIKU",
                                  style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        )
                      : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.video_library_rounded, size: 48, color: Colors.grey.shade800),
                              const SizedBox(height: 16),
                              Text(
                                t('Your cinematic masterpiece will appear here', 'Karya sinematik Anda akan muncul di sini'),
                                style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey.shade600, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
            ),
            const SizedBox(height: 20),
            
            if (hasVideoUrl)
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.download_rounded, size: 22),
                          label: Text(
                            t('Download Video', 'Unduh Video MP4'),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: Colors.green.shade600,
                            foregroundColor: Colors.white,
                            elevation: 5,
                            shadowColor: Colors.greenAccent.withOpacity(0.4),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            viewModel.downloadVideo();
                            ScaffoldMessenger.of(context).clearSnackBars();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                elevation: 0,
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: Colors.transparent,
                                content: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E1E2E).withOpacity(0.95), 
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.greenAccent.withOpacity(0.5), width: 1.5), 
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.greenAccent.withOpacity(0.2),
                                        blurRadius: 10,
                                        spreadRadius: 2,
                                        offset: const Offset(0, 4),
                                      )
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withOpacity(0.2),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.file_download_done_rounded, color: Colors.greenAccent, size: 24),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              t('Download Started', 'Unduhan Dimulai'),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              t('Check your notification or gallery soon.', 'Cek notifikasi atau galeri Anda segera.'),
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                duration: const Duration(seconds: 4),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact(); 
                      setState(() {
                         _selectedImage = null; // Reset image
                      });
                      viewModel.clearAll();
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.refresh_rounded, size: 18, color: Colors.white54),
                          const SizedBox(width: 6),
                          Text(
                            t('Create New Video', 'Buat Video Baru'),
                            style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              )
          ],
        ),
      ),
    );
  }
}
// ....................................................... //

// No ke-6: WIDGET VIDEO PLAYER DIALOG [TANPA REGRESI] //
// ....................................................... //
class VideoPlayerDialog extends StatefulWidget {
  final String videoUrl;
  
  const VideoPlayerDialog({super.key, required this.videoUrl});

  @override
  State<VideoPlayerDialog> createState() => _VideoPlayerDialogState();
}

class _VideoPlayerDialogState extends State<VideoPlayerDialog> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        if (mounted) {
          setState(() {
            _isInitialized = true;
          });
          _controller.play();
          _controller.setLooping(true);
        }
      }).catchError((error) {
        if (mounted) {
          setState(() {
            _hasError = true;
          });
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 600, maxWidth: 800),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (_hasError)
                const Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text(
                    "Video tidak dapat diputar. Silakan gunakan tombol Download.",
                    style: TextStyle(color: Colors.redAccent),
                    textAlign: TextAlign.center,
                  ),
                )
              else if (_isInitialized)
                AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _controller.value.isPlaying ? _controller.pause() : _controller.play();
                      });
                    },
                    child: VideoPlayer(_controller),
                  ),
                )
              else
                const CircularProgressIndicator(color: Colors.blueAccent),
                
              if (_isInitialized && !_controller.value.isPlaying)
                const Icon(Icons.pause_circle_filled_rounded, size: 80, color: Colors.white54),

              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  style: IconButton.styleFrom(backgroundColor: Colors.black54),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
// ....................................................... //