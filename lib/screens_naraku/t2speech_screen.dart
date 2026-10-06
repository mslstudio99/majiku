//================================================================//
// LIB/SCREENS_NARAKU/T2SPEECH_SCREEN.DART                        //
// LAYAR UTAMA GENERATOR TEXT TO SPEECH PREMIUM (T2SPEECH)        //
// INPUT TEKS, PILIHAN BAHASA & VOKAL CHIRP3-HD, AUDIO PLAYER     //
//================================================================//

//No ke-1: IMPORT DEPENDENSI & SERVICE                            //
//IMPORT FLUTTER, RIVERPOD, LOGGING USER CENTER, THEME & PROVIDER //
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/firestore_service.dart';
import '../view_model_naraku/t2speech_view_model.dart';
import '../providers/user_provider.dart';
import '../providers/config_provider.dart';
import '../theme/app_theme.dart';
// END OF BLOK 1 //
//================================================================//

//No ke-2: STATEFUL WIDGET, SETUP & LIFECYCLE                     //
//INISIALISASI FORM, CONTROLLER LISTENER, & LOGGING AKTIVITAS     //
class T2SpeechScreen extends ConsumerStatefulWidget {
  const T2SpeechScreen({super.key});

  @override
  ConsumerState<T2SpeechScreen> createState() => _T2SpeechScreenState();
}

class _T2SpeechScreenState extends ConsumerState<T2SpeechScreen> {
  final int _maxTextLength = 20000;
  final _formKey = GlobalKey<FormState>();
  bool _isDownloaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final viewModel = ref.read(t2SpeechViewModelProvider.notifier);
        viewModel.textController.addListener(() => setState(() {}));

        // --- [LOG AKTIVITAS: KUNJUNGAN FITUR T2SPEECH PREMIUM] ---
        ref.read(firestoreServiceProvider).logFeatureActivity(
          featureKey: 't2speech',
          eventType: 'visit',
        );
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
  }
// END OF BLOK 2 //
//================================================================//

//No ke-3: LOGIKA REPORT, PLAYBACK & AUDIO CONTROLS               //
//DIALOG LAPORAN PELANGGARAN AUDIO, PLAY/PAUSE & DOWNLOAD         //
  void _showReportDialog(BuildContext context, WidgetRef ref, String audioUrl) {
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
                hintText: "Alasan error / masalah audio...",
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
                'contentReference': audioUrl,
                'contentType': 'audio_chirp3_tts',
                'reason': reasonController.text.isEmpty ? 'No reason provided' : reasonController.text,
                'reportedAt': FieldValue.serverTimestamp(),
                'userId': userId,
                'feature': 'Generator T2Speech Premium',
              }).then((_) {
                if (context.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Laporan dikirim.", style: TextStyle(color: Colors.white)),
                      backgroundColor: Colors.green,
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
// END OF BLOK 3 //
//================================================================//

//No ke-4: FORM INPUT TEKS, PILIHAN BAHASA & SUARA CHIRP3-HD      //
//APPBAR DENGAN BADGE TOKEN, TEXTAREA 10.000 CHAR, DROPDOWN SUARA //
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(t2SpeechViewModelProvider);
    final viewModel = ref.read(t2SpeechViewModelProvider.notifier);
    final currentLocale = ref.watch(appLanguageProvider);
    final isIndo = currentLocale.languageCode == 'id';
    String t(String en, String id) => isIndo ? id : en;

    // 1. Data Pengguna & Konfigurasi Token Dinamis
    final userAsync = ref.watch(firestoreUserProvider);
    final configAsync = ref.watch(appConfigProvider);

    int currentBalance = 0;
    int costPer100Chars = 15;
    int minTokens = 15;

    userAsync.whenData((user) {
      currentBalance = user.tokenBalance;
    });

    configAsync.whenData((config) {
      costPer100Chars = config.costs.t2speechCosts.costPer100Chars;
      minTokens = config.costs.t2speechCosts.minTokens;
    });

    // 2. Kalkulasi Kebutuhan Token Secara Realtime Berbasis Karakter
    final int textLength = viewModel.textController.text.trim().length;
    final int units = textLength == 0 ? 0 : (textLength / 100).ceil();
    final int calculatedCost = units * costPer100Chars;
    final int requiredTokens = textLength == 0 ? 0 : (calculatedCost < minTokens ? minTokens : calculatedCost);

    final bool hasSufficientFunds = currentBalance >= requiredTokens;
    final bool hasInput = textLength > 0 && textLength <= _maxTextLength;
    final bool isOutOfTokens = hasInput && !hasSufficientFunds;
    final bool canSubmit = hasInput && hasSufficientFunds && !state.isLoading && state.selectedVoice.isNotEmpty;

    ref.listen<T2SpeechState>(t2SpeechViewModelProvider, (previous, next) {
      if (next.generatedAudioUrl != previous?.generatedAudioUrl) {
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

      // --- [LOG AKTIVITAS: KONVERSI SUKSES T2SPEECH] ---
      if (previous?.isLoading == true && !next.isLoading && next.generatedAudioUrl.isNotEmpty) {
        ref.read(firestoreServiceProvider).logFeatureActivity(
          featureKey: 't2speech',
          eventType: 'conversion',
        );
      }
    });

    return Theme(
      data: AppTheme.darkTheme.copyWith(
        scaffoldBackgroundColor: const Color(0xFF0D0D14),
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF0D0D14), elevation: 0),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            t('Text to Speech HD', 'Teks ke Suara HD'),
            style: TextStyle(color: Colors.amber.shade400, fontWeight: FontWeight.bold),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black38,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isOutOfTokens ? Colors.redAccent : Colors.white24,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.token, 
                        size: 16, 
                        color: isOutOfTokens ? Colors.redAccent : Colors.amber,
                      ),
                      const SizedBox(width: 6),
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: viewModel.textController,
                    maxLines: 8,
                    maxLength: _maxTextLength,
                    enabled: !state.isLoading,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    decoration: InputDecoration(
                      labelText: t('Text to Synthesize', 'Teks untuk Disuarakan'),
                      labelStyle: TextStyle(color: Colors.purple.shade200),
                      hintText: t('Enter your narration text here (up to 20,000 characters)...', 'Masukkan teks narasi Anda di sini (hingga 20.000 karakter)...'),
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
                          onChanged: state.isLoading ? null : (value) => viewModel.setLanguage(value),
                        ),
                        const Divider(color: Colors.white10, height: 24),
                        DropdownButtonFormField<String>(
                          value: state.selectedVoice,
                          isExpanded: true,
                          dropdownColor: const Color(0xFF23233E),
                          decoration: InputDecoration(
                            labelText: "${t('Select Voice Type', 'Pilih Jenis Vokal')} (${state.currentVoiceOptions.length})",
                            labelStyle: TextStyle(color: Colors.amber.shade200),
                            border: InputBorder.none,
                            prefixIcon: Icon(Icons.record_voice_over, color: Colors.purple.shade300),
                          ),
                          style: const TextStyle(color: Colors.white),
                          items: state.currentVoiceOptions.entries
                              .map((entry) => DropdownMenuItem(
                                    value: entry.value,
                                    child: Text(entry.key, overflow: TextOverflow.ellipsis),
                                  ))
                              .toList(),
                          onChanged: state.isLoading || state.currentVoiceOptions.isEmpty
                              ? null
                              : (value) => viewModel.setVoice(value),
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
                                viewModel.generateSpeech();
                              }
                            }
                          : null,
                      icon: state.isLoading
                          ? const SizedBox.shrink()
                          : Icon(Icons.multitrack_audio_rounded, color: Colors.amber.shade400),
                      label: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        child: state.isLoading
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.amber.shade400,
                                      strokeWidth: 2.5,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    state.loadingText.isNotEmpty ? state.loadingText : t('PROCESSING...', 'MEMPROSES...'),
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              )
                            : Text(
                                t('GENERATE SPEECH', 'BUAT SUARA'),
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
                  
                  if (isOutOfTokens)
                    Padding(
                      padding: const EdgeInsets.only(top: 10.0),
                      child: Center(
                        child: Text(
                          t(
                            "Insufficient balance. You need ${requiredTokens - currentBalance} more tokens.",
                            "Saldo tidak cukup. Anda butuh ${requiredTokens - currentBalance} token lagi.",
                          ),
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
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
// END OF BLOK 4 //
//================================================================//

//No ke-5: KARTU OUTPUT AUDIO PLAYER & DOWNLOAD                   //
//KONTROL AUDIO PLAYER URL, ANIMASI GELOMBANG, UNDUH NATIVE       //
  Widget _buildAudioOutputCard(
    BuildContext context,
    WidgetRef ref,
    T2SpeechViewModel viewModel,
    T2SpeechState state,
    String Function(String, String) t,
  ) {
    final bool hasAudio = state.generatedAudioUrl.isNotEmpty;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutQuart,
      margin: EdgeInsets.zero,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasAudio ? Colors.amber.shade600 : Colors.white10,
          width: hasAudio ? 1.5 : 1,
        ),
        gradient: LinearGradient(
          colors: hasAudio
              ? [const Color(0xFF1E103C), const Color(0xFF0F0B1E)]
              : [const Color(0xFF161622), const Color(0xFF12121C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: hasAudio
            ? [BoxShadow(color: Colors.purple.withOpacity(0.2), blurRadius: 20, spreadRadius: 2)]
            : [],
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
                    onPressed: () => _showReportDialog(context, ref, state.generatedAudioUrl),
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
                      t('Synthesizing your premium voice...', 'Mensintesis vokal premium Anda...'),
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
                    onTap: () => viewModel.playAudio(),
                    child: Container(
                      height: 80,
                      width: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.amber.shade400,
                        boxShadow: [
                          BoxShadow(color: Colors.amber.withOpacity(0.3), blurRadius: 15, spreadRadius: 5),
                        ],
                      ),
                      child: Icon(
                        state.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
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
                        height: state.isPlaying ? (20.0 + (index % 4) * 10) : 5.0,
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

                            if (_isDownloaded) {
                              showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  backgroundColor: const Color(0xFF1E1E2C),
                                  title: Text(
                                    t('Already Saved', 'Sudah Tersimpan'),
                                    style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
                                  ),
                                  content: Text(
                                    t(
                                      'This audio has already been saved. Do you want to save it again?',
                                      'File ini sudah Anda simpan sebelumnya. Apakah Anda ingin menyimpannya lagi?',
                                    ),
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
                            _isDownloaded = false;
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
// END OF BLOK 5 //
//================================================================//