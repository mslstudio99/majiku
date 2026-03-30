// [RILIS FINAL - THUMBNAIL: SD 3.5 INTEGRATION & POLICY COMPLIANCE]
// KATEGORI_POLICY_UPDATE NO_URUT_04
// Lokasi: lib/screens_naraku/generator_gambar_thumbnail_screen.dart

import 'dart:convert'; // [PENTING] Untuk mendecode Base64 dari SD 3.5
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 

// [IMPORT NAVIGASI MASTER]
import '../screens/input_script_screen.dart';
import '../screens_veo/input_script_veo_screen.dart';
import '../screens/project_dashboard_screen.dart';

// [IMPORT GENERATOR LAIN]
import './konsultan_ide_konten_screen.dart';
import './generator_kisah_sejarah_screen.dart';
import './generator_konten_umum_screen.dart';
import './generator_kisah_legenda_screen.dart';
import './generator_kisah_islami_screen.dart';
import './generator_kisah_horor_screen.dart';
import './generator_kisah_custom_screen.dart';
import './generator_konten_short_screen.dart';

// [IMPORT VIEWMODEL]
import '../view_model_naraku/generator_gambar_thumbnail_view_model.dart';

// [IMPORT PROVIDER & MODELS]
import '../providers/user_provider.dart';
import '../providers/config_provider.dart'; 
import '../models/app_user.dart';
import '../models/app_config.dart';

class GeneratorGambarThumbnailScreen extends ConsumerWidget {
  const GeneratorGambarThumbnailScreen({super.key});

  final int _maxPromptLength = 15000; // SD 3.5 Large mampu memproses prompt yang lebih detail

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // [STATE MANAGEMENT]
    final state = ref.watch(generatorGambarThumbnailViewModelProvider);
    final viewModel = ref.read(generatorGambarThumbnailViewModelProvider.notifier);

    // [USER & CONFIG STATE]
    final AsyncValue<AppUser> userState = ref.watch(firestoreUserProvider);
    final AsyncValue<AppConfig> configState = ref.watch(appConfigProvider);

    // [BAHASA]
    final currentLocale = ref.watch(appLanguageProvider);
    final isIndo = currentLocale.languageCode == 'id';
    String t(String en, String id) => isIndo ? id : en;

    // [THEME SHORTCUT]
    final theme = Theme.of(context);

    // [ERROR LISTENER]
    ref.listen<GeneratorGambarThumbnailState>(
        generatorGambarThumbnailViewModelProvider, (previous, next) {
      if (next.errorMessage != null && previous?.errorMessage == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: theme.colorScheme.error,
          ),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: null,
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.dashboard_outlined),
            label: const Text('Dashboard'),
            style: TextButton.styleFrom(
              foregroundColor: theme.textTheme.bodyMedium?.color,
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
            ),
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (context) => const ProjectDashboardScreen(),
                ),
                (Route<dynamic> route) => false,
              );
            },
          ),
        ],
      ),
      drawer: _buildNarakuDrawer(context, t),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildInputCard(
              context,
              ref,
              viewModel,
              state,
              userState,
              configState,
              t,
            ),
            const SizedBox(height: 24),
            _buildOutputCard(context, ref, viewModel, state, t),
          ],
        ),
      ),
    );
  }

  // --- [LOGIC REAL] LAPOR KONTEN KE FIRESTORE (MENDUKUNG BASE64) ---
  void _showReportDialog(BuildContext context, WidgetRef ref, String imageUrl) {
    final TextEditingController reasonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Lapor Gambar / Report Image"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Apakah gambar ini melanggar kebijakan? Berikan alasan Anda.",
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
              // [FIREBASE LOGIC FIX] Menggunakan .uid pelapor
              final user = ref.read(firestoreUserProvider).valueOrNull;
              final userId = user?.uid ?? 'anonymous'; 

              FirebaseFirestore.instance.collection('reports').add({
                // Jika base64 terlalu panjang, kita simpan cuplikannya saja untuk metadata Firestore
                'content_preview': imageUrl.length > 100 ? imageUrl.substring(0, 100) : imageUrl, 
                'contentType': 'image_sd35_base64', 
                'reason': reasonController.text.isEmpty ? 'No reason provided' : reasonController.text,
                'reportedAt': FieldValue.serverTimestamp(),
                'userId': userId,
                'feature': 'Generator Thumbnail SD 3.5', 
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

  // --- Helper Kartu Input ---
  Widget _buildInputCard(
    BuildContext context,
    WidgetRef ref,
    GeneratorGambarThumbnailViewModel viewModel,
    GeneratorGambarThumbnailState state,
    AsyncValue<AppUser> userState,
    AsyncValue<AppConfig> configState,
    String Function(String, String) t,
  ) {
    final theme = Theme.of(context);
    
    final charCounter = ValueNotifier<int>(viewModel.narrativeController.text.length);
    viewModel.narrativeController.addListener(() {
      charCounter.value = viewModel.narrativeController.text.length;
    });

    final bool vmIsLoading = state.isLoading;
    final bool providersAreLoading = userState.isLoading || configState.isLoading;
    final bool providersHaveError = userState.hasError || configState.hasError;
    final int currentBalance = userState.valueOrNull?.tokenBalance ?? 0;
    final int actionCost = configState.valueOrNull?.costs.createThumbnailPerClick ??
            Costs.fallback().createThumbnailPerClick;
    final bool canAfford = currentBalance >= actionCost;

    final String buttonLabel;
    if (vmIsLoading) {
      buttonLabel = t('Generating...', 'Membuat Gambar...');
    } else if (providersAreLoading) {
      buttonLabel = t('Loading...', 'Memuat...');
    } else if (providersHaveError) {
      buttonLabel = "Error";
    } else if (!canAfford) {
      buttonLabel = t('Insufficient Tokens', 'Token Tidak Cukup');
    } else {
      buttonLabel = t('GENERATE IMAGE', 'BUAT GAMBAR');
    }

    final bool isButtonDisabled = vmIsLoading || providersAreLoading || providersHaveError || !canAfford;
    final Color buttonColor = (isButtonDisabled && !vmIsLoading && !providersAreLoading)
        ? theme.disabledColor
        : theme.primaryColor;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              t('Thumbnail Generator', 'Generator Thumbnail'),
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  t('Image Description / Prompt', 'Deskripsi Gambar / Prompt'),
                  style: theme.textTheme.bodyMedium,
                ),
                ValueListenableBuilder<int>(
                  valueListenable: charCounter,
                  builder: (context, count, child) {
                    final bool isLimit = count > _maxPromptLength;
                    return Text(
                      '$count / $_maxPromptLength',
                      style: TextStyle(
                        color: isLimit ? theme.colorScheme.error : theme.textTheme.bodySmall?.color,
                        fontSize: 13,
                        fontWeight: isLimit ? FontWeight.bold : FontWeight.normal,
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: viewModel.narrativeController,
              maxLines: 4,
              maxLength: _maxPromptLength,
              enabled: !state.isLoading,
              style: theme.textTheme.bodyLarge,
              decoration: InputDecoration(
                hintText: t('e.g., A majestic Javanese palace in the clouds...', 'Cth: Istana Jawa megah di atas awan...'),
                counterText: '',
                filled: true,
                fillColor: theme.scaffoldBackgroundColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: theme.colorScheme.secondary),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              t('Visual Style', 'Gaya Visual'),
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            _buildStyleOptions(context, viewModel, state, t),
            const SizedBox(height: 20),
            Text(
              t('Aspect Ratio', 'Rasio Aspek'),
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            _buildRatioOptions(context, viewModel, state),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: vmIsLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.auto_awesome, size: 20),
              label: Text(
                buttonLabel,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: buttonColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              onPressed: isButtonDisabled ? null : viewModel.generateStory,
            ),
          ],
        ),
      ),
    );
  }

  // --- Pilihan Style (HORIZONTAL SCROLL) ---
  Widget _buildStyleOptions(
      BuildContext context,
      GeneratorGambarThumbnailViewModel viewModel,
      GeneratorGambarThumbnailState state,
      String Function(String, String) t) {
    
    final options = {
      'Hyperrealistic Style': t('Realistic', 'Realistis'),
      '3D Render Style': t('3D Render', 'Render 3D'),
      '2D Cartoon Style': t('2D Flat', 'Kartun 2D'),
    };

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: options.entries.map((entry) {
          return SizedBox(
            width: 130,
            child: RadioListTile<String>(
              title: Text(entry.value, style: const TextStyle(fontSize: 11)),
              value: entry.key,
              groupValue: state.selectedStyle,
              onChanged: state.isLoading ? null : (val) => viewModel.setStyle(val),
              activeColor: Theme.of(context).colorScheme.secondary,
              contentPadding: EdgeInsets.zero,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRatioOptions(
      BuildContext context,
      GeneratorGambarThumbnailViewModel viewModel,
      GeneratorGambarThumbnailState state) {
    final options = ["16:9", "9:16", "1:1"];
    return Row(
      children: options.map((value) {
        return Expanded(
          child: RadioListTile<String>(
            title: Text(value, style: const TextStyle(fontSize: 14)),
            value: value,
            groupValue: state.selectedRatio,
            onChanged: state.isLoading ? null : (val) => viewModel.setRatio(val),
            activeColor: Theme.of(context).colorScheme.secondary,
            contentPadding: EdgeInsets.zero,
          ),
        );
      }).toList(),
    );
  }

  // --- [CRITICAL UPDATE] KARTU OUTPUT UNTUK SD 3.5 BASE64 ---
  Widget _buildOutputCard(
    BuildContext context,
    WidgetRef ref,
    GeneratorGambarThumbnailViewModel viewModel,
    GeneratorGambarThumbnailState state,
    String Function(String, String) t,
  ) {
    final theme = Theme.of(context);
    final bool hasImageUrl = state.generatedImageUrl.isNotEmpty;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  t('Generated Result', 'Hasil Karya SD 3.5'),
                  style: theme.textTheme.headlineSmall,
                ),
                if (hasImageUrl)
                  IconButton(
                    icon: const Icon(Icons.flag_outlined, color: Colors.redAccent),
                    onPressed: () => _showReportDialog(context, ref, state.generatedImageUrl),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              constraints: const BoxConstraints(minHeight: 250),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.dividerColor),
              ),
              child: state.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : hasImageUrl
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: AspectRatio(
                            aspectRatio: _parseRatio(state.selectedRatio),
                            // [LOGIKA DUAL: BASE64 & URL]
                            child: !state.generatedImageUrl.startsWith('http')
                                ? Image.memory(
                                    base64Decode(state.generatedImageUrl),
                                    fit: BoxFit.contain,
                                  )
                                : Image.network(
                                    state.generatedImageUrl,
                                    fit: BoxFit.contain,
                                    loadingBuilder: (ctx, child, progress) =>
                                        progress == null ? child : const Center(child: CircularProgressIndicator()),
                                  ),
                          ),
                        )
                      : Center(
                          child: Text(
                            t('Your masterpiece will appear here...', 'Karya Anda akan muncul di sini...'),
                            style: const TextStyle(fontStyle: FontStyle.italic),
                          ),
                        ),
            ),
            const SizedBox(height: 20),
            if (hasImageUrl)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.save_alt),
                      label: Text(t('Save', 'Simpan')),
                      onPressed: viewModel.downloadImage,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: Text(t('Clear', 'Hapus')),
                      onPressed: viewModel.clearAll,
                    ),
                  ),
                ],
              )
          ],
        ),
      ),
    );
  }

  double _parseRatio(String ratio) {
    final parts = ratio.split(':');
    if (parts.length == 2) {
      final w = double.tryParse(parts[0]) ?? 16;
      final h = double.tryParse(parts[1]) ?? 9;
      return w / h;
    }
    return 16 / 9;
  }

  Widget _buildNarakuDrawer(BuildContext context, String Function(String, String) t) {
    final theme = Theme.of(context);
    void navigate(Widget s) {
      Navigator.pop(context);
      Navigator.of(context).push(MaterialPageRoute(builder: (c) => s));
    }

    return Drawer(
      backgroundColor: theme.scaffoldBackgroundColor,
      child: ListView(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 50, 16, 20),
            color: theme.appBarTheme.backgroundColor,
            child: Row(
              children: [
                Icon(Icons.auto_awesome, color: theme.colorScheme.secondary),
                const SizedBox(width: 12),
                const Text('Majiku Naraku', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          ListTile(leading: const Icon(Icons.lightbulb_outline), title: Text(t('Idea', 'Ide')), onTap: () => navigate(const KonsultanIdeKontenScreen())),
          ListTile(leading: const Icon(Icons.history_edu), title: Text(t('History', 'Sejarah')), onTap: () => navigate(const GeneratorKisahSejarahScreen())),
          ListTile(leading: const Icon(Icons.image_outlined), title: Text(t('Thumbnail', 'Thumbnail')), enabled: false),
          const Divider(),
          ListTile(leading: const Icon(Icons.arrow_back), title: Text(t('Back to Dashboard', 'Kembali ke Dashboard')), onTap: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const ProjectDashboardScreen()))),
        ],
      ),
    );
  }
}