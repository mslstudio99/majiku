//......................................................//
// LIB/SCREENS_DAILY_FREE/FREE_T2SPEECH_SCREEN.DART     //
// FITUR DAILY FREE - GENERATOR T2SPEECH                //
//......................................................//

// No ke-1: IMPORT & SETUP                              //
//......................................................//
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audioplayers/audioplayers.dart'; 

// [IMPORT SERVICE LOGGING USER CENTER]
import '../services/firestore_service.dart';

import '../view_model_daily_free/free_t2speech_view_model.dart';
import '../providers/user_provider.dart';
import '../providers/config_provider.dart';
import '../theme/app_theme.dart';
//......................................................//

// No ke-2: STATEFUL WIDGET & INITIALIZATION            //
//......................................................//
class FreeT2SpeechScreen extends ConsumerStatefulWidget {
  const FreeT2SpeechScreen({super.key});

  @override
  ConsumerState<FreeT2SpeechScreen> createState() => _FreeT2SpeechScreenState();
}

class _FreeT2SpeechScreenState extends ConsumerState<FreeT2SpeechScreen> {
  final int _maxTextLength = 500; 
  final _formKey = GlobalKey<FormState>();
  
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  
  // Tracker untuk mencegah unduhan ganda yang tidak disengaja
  bool _isDownloaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final viewModel = ref.read(freeT2SpeechViewModelProvider.notifier);
        viewModel.textController.addListener(() => setState(() {}));

        // --- [LOG AKTIVITAS: KUNJUNGAN DAILY FREE -> FREE T2SPEECH] ---
        ref.read(firestoreServiceProvider).logFeatureActivity(
          featureKey: 'free_t2speech',
          eventType: 'visit',
        );
        // --------------------------------------------------------------
      }
    });

    _audioPlayer.onPlayerStateChanged.listen((PlayerState s) {
      if (mounted) {
        setState(() => _isPlaying = s == PlayerState.playing);
      }
    });
    _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() => _isPlaying = false);
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
//......................................................//

// No ke-3: LOGIC & REPORT FUNCTION                     //
//......................................................//
  void _showReportDialog(BuildContext context, WidgetRef ref, String audioUrlOrId) {
    final TextEditingController reasonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        title: const Text("Lapor Audio / Report Audio", style: TextStyle(color: Colors.amber)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Apakah audio ini melanggar kebijakan atau mengalami error sistem?",
              style: TextStyle(fontSize: 14, color: Colors.white70),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: reasonController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Alasan error / pelanggaran...",
                hintStyle: const TextStyle(color: Colors.white38),
                enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.purple.shade300)),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Batal", style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () {
              final user = ref.read(firestoreUserProvider).valueOrNull;
              final userId = user?.uid ?? 'anonymous'; 

              FirebaseFirestore.instance.collection('reports').add({
                'contentReference': audioUrlOrId,
                'contentType': 'audio_wavenet_tts', 
                'reason': reasonController.text.isEmpty ? 'No reason provided' : reasonController.text,
                'reportedAt': FieldValue.serverTimestamp(),
                'userId': userId,
                'feature': 'Generator Free T2Speech',
              }).then((_) {
                if (context.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Laporan dikirim.", style: TextStyle(color: Colors.white)), 
                      backgroundColor: Colors.green
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

  void _togglePlayPause(String base64Audio) async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      final viewModel = ref.read(freeT2SpeechViewModelProvider.notifier);
      await viewModel.playAudio(_audioPlayer); 
    }
  }
// Penutup Blok //

// No ke-4: MAIN BUILDER & FORM UI                      //
//......................................................//
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(freeT2SpeechViewModelProvider);
    final viewModel = ref.read(freeT2SpeechViewModelProvider.notifier);
    final currentLocale = ref.watch(appLanguageProvider);
    final isIndo = currentLocale.languageCode == 'id';
    String t(String en, String id) => isIndo ? id : en;

    ref.listen<FreeT2SpeechState>(freeT2SpeechViewModelProvider, (previous, next) {
      if (next.generatedAudioBase64 != previous?.generatedAudioBase64) {
        _isDownloaded = false;
      }

      if (next.errorMessage != null && next.errorMessage != previous?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(child: Text(next.errorMessage!, style: const TextStyle(color: Colors.white))),
              ],
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      
      if (next.successMessage != null && next.successMessage != previous?.successMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(child: Text(next.successMessage!, style: const TextStyle(color: Colors.white))),
              ],
            ),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }

      // --- [LOG AKTIVITAS: KONVERSI SUKSES GENERATE FREE T2SPEECH] ---
      if (previous?.isLoading == true && !next.isLoading && next.generatedAudioBase64 != null && next.generatedAudioBase64!.isNotEmpty) {
        ref.read(firestoreServiceProvider).logFeatureActivity(
          featureKey: 'free_t2speech',
          eventType: 'conversion',
        );
      }
      // ---------------------------------------------------------------
    });

    final int textLength = viewModel.textController.text.length;
    final bool hasInput = textLength > 0 && textLength <= _maxTextLength;
    final bool canSubmit = hasInput && !state.isLoading && state.selectedLanguage != null && state.selectedVoice != null;

    return Theme(
      data: AppTheme.darkTheme.copyWith(
        scaffoldBackgroundColor: const Color(0xFF0D0D14), 
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF0D0D14), elevation: 0),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Free Text-to-Speech',
            style: TextStyle(color: Colors.amber.shade400, fontWeight: FontWeight.bold),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: viewModel.textController,
                    maxLines: 6,
                    maxLength: _maxTextLength,
                    enabled: !state.isLoading,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    decoration: InputDecoration(
                      labelText: t('Text to Synthesize', 'Teks untuk Disuarakan'),
                      labelStyle: TextStyle(color: Colors.purple.shade200),
                      hintText: t('Hello, welcome to Majiku...', 'Halo, selamat datang di Majiku...'),
                      hintStyle: const TextStyle(color: Colors.white24),
                      alignLabelWithHint: true,
                      filled: true,
                      fillColor: const Color(0xFF1A1A2E), 
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.purple.shade400, width: 2),
                      ),
                      counterStyle: TextStyle(
                        color: textLength > _maxTextLength ? Colors.redAccent : Colors.white54,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return t('Please enter some text.', 'Mohon isi teks.');
                      }
                      if (value.length > _maxTextLength) {
                        return t('Text exceeds $_maxTextLength characters.', 'Teks melebihi $_maxTextLength karakter.');
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A2E),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.purple.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        DropdownButtonFormField<String>(
                          value: state.selectedLanguage,
                          isExpanded: true,
                          dropdownColor: const Color(0xFF23233E),
                          decoration: InputDecoration(
                            labelText: t('Select Language', 'Pilih Bahasa'),
                            labelStyle: TextStyle(color: Colors.amber.shade200),
                            border: InputBorder.none,
                            prefixIcon: Icon(Icons.language, color: Colors.amber.shade400),
                          ),
                          style: const TextStyle(color: Colors.white),
                          items: state.availableLanguages
                              .map((lang) => DropdownMenuItem(
                                    value: lang,
                                    child: Text(lang, overflow: TextOverflow.ellipsis),
                                  ))
                              .toList(),
                          onChanged: state.isLoading ? null : (value) {
                            if (value != null) viewModel.setLanguage(value);
                          },
                        ),
                        const Divider(color: Colors.white10, height: 24),
                        DropdownButtonFormField<String>(
                          value: state.selectedVoice,
                          isExpanded: true,
                          dropdownColor: const Color(0xFF23233E),
                          decoration: InputDecoration(
                            labelText: t('Select Voice Type', 'Pilih Jenis Vokal'),
                            labelStyle: TextStyle(color: Colors.amber.shade200),
                            border: InputBorder.none,
                            prefixIcon: Icon(Icons.record_voice_over, color: Colors.purple.shade300),
                          ),
                          style: const TextStyle(color: Colors.white),
                          items: state.availableVoices
                              .map((voice) => DropdownMenuItem(
                                    value: voice.id, 
                                    child: Text("${voice.name} (${voice.gender})", overflow: TextOverflow.ellipsis),
                                  ))
                              .toList(),
                          onChanged: state.isLoading || state.availableVoices.isEmpty ? null : (value) {
                            if (value != null) viewModel.setVoice(value);
                          },
                          hint: Text(
                            state.availableVoices.isEmpty ? t('Select language first', 'Pilih bahasa dulu') : t('Select a voice', 'Pilih vokal'),
                            style: const TextStyle(color: Colors.white38),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.purple.shade900.withOpacity(0.5),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: canSubmit
                          ? () {
                              if (_formKey.currentState!.validate()) {
                                FocusScope.of(context).unfocus();
                                viewModel.generateAudio();
                              }
                            }
                          : null,
                      icon: state.isLoading
                          ? const SizedBox.shrink()
                          : Icon(Icons.multitrack_audio_rounded, color: Colors.amber.shade400),
                      label: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        child: state.isLoading
                            ? SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.amber.shade400,
                                  strokeWidth: 3,
                                ),
                              )
                            : Text(
                                t('GENERATE AUDIO', 'BUAT AUDIO'),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.5),
                              ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple.shade700,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFF2A2A3A),
                        disabledForegroundColor: Colors.white24,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  
                  _buildAudioOutputCard(context, ref, viewModel, state, t),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
//......................................................//

// No ke-5: MODERN OUTPUT KARTU (AUDIO PLAYER)          //
//......................................................//
  Widget _buildAudioOutputCard(
    BuildContext context,
    WidgetRef ref,
    FreeT2SpeechViewModel viewModel,
    FreeT2SpeechState state,
    String Function(String, String) t,
  ) {
    final bool hasAudio = state.generatedAudioBase64 != null && state.generatedAudioBase64!.isNotEmpty;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutQuart,
      margin: EdgeInsets.zero,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: hasAudio ? Colors.amber.shade600 : Colors.white10, width: hasAudio ? 1.5 : 1),
        gradient: LinearGradient(
          colors: hasAudio 
              ? [const Color(0xFF1E103C), const Color(0xFF0F0B1E)] 
              : [const Color(0xFF161622), const Color(0xFF12121C)], 
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: hasAudio ? [
          BoxShadow(color: Colors.purple.withOpacity(0.2), blurRadius: 20, spreadRadius: 2)
        ] : [],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  t('Audio Result', 'Hasil Audio'),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: hasAudio ? Colors.amber.shade400 : Colors.white54,
                  ),
                ),
                if (hasAudio)
                  IconButton(
                    icon: const Icon(Icons.flag_outlined, color: Colors.white38, size: 20),
                    onPressed: () => _showReportDialog(context, ref, 'generated_audio_base64_ref'),
                    tooltip: t('Report Error', 'Lapor Error'),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            
            if (state.isLoading)
              Center(
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    CircularProgressIndicator(color: Colors.purple.shade300),
                    const SizedBox(height: 20),
                    Text(
                      t('Synthesizing your voice...', 'Mensintesis suara Anda...'),
                      style: TextStyle(color: Colors.purple.shade200, fontStyle: FontStyle.italic),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              )
            else if (hasAudio)
              Column(
                children: [
                  GestureDetector(
                    onTap: () => _togglePlayPause(state.generatedAudioBase64!),
                    child: Container(
                      height: 80,
                      width: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.amber.shade400,
                        boxShadow: [
                          BoxShadow(color: Colors.amber.withOpacity(0.3), blurRadius: 15, spreadRadius: 5)
                        ],
                      ),
                      child: Icon(
                        _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: const Color(0xFF121212),
                        size: 40,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      15, 
                      (index) => AnimatedContainer(
                        duration: Duration(milliseconds: 200 + (index * 50)),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        height: _isPlaying ? (20.0 + (index % 4) * 10) : 5.0,
                        width: 4,
                        decoration: BoxDecoration(
                          color: Colors.purple.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.download_rounded, size: 20),
                          label: Text(
                            t('Save MP3', 'Simpan MP3'),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber.shade500,
                            foregroundColor: Colors.black87,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            
                            // ✅ PERBAIKAN: Dialog Peringatan Jika Sudah Diunduh
                            if (_isDownloaded) {
                              showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  backgroundColor: const Color(0xFF1E1E2C),
                                  title: Text(
                                    t('Already Saved', 'Sudah Tersimpan'), 
                                    style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)
                                  ),
                                  content: Text(
                                    t('This audio has already been saved. Do you want to save it again?', 'File ini sudah Anda simpan sebelumnya. Apakah Anda ingin menyimpannya lagi?'),
                                    style: const TextStyle(color: Colors.white70),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: Text(t('Cancel', 'Batal'), style: const TextStyle(color: Colors.white54)),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700),
                                      onPressed: () {
                                        Navigator.pop(ctx);
                                        viewModel.downloadAudio();
                                      },
                                      child: Text(t('Save Again', 'Simpan Lagi'), style: const TextStyle(color: Colors.white)),
                                    ),
                                  ],
                                ),
                              );
                            } else {
                              _isDownloaded = true;
                              viewModel.downloadAudio();
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white24),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            _isDownloaded = false; // Reset tracker
                            _audioPlayer.stop(); 
                            viewModel.clearAll();
                          },
                          tooltip: t('Create New', 'Buat Baru'),
                        ),
                      ),
                    ],
                  ),
                ],
              )
            else
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 30),
                  child: Column(
                    children: [
                      Icon(Icons.graphic_eq_rounded, size: 48, color: Colors.purple.shade900),
                      const SizedBox(height: 16),
                      Text(
                        t('Your synthesized audio will appear here', 'Audio sintesis Anda akan muncul di sini'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white38, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
// Penutup Blok //