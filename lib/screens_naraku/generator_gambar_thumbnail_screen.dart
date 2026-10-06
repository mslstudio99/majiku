//================================================================//
// NAMA FILE: GENERATOR_GAMBAR_THUMBNAIL_SCREEN.DART              //
// DIREKTORI: lib/screens_naraku/generator_gambar_thumbnail_screen.dart //
//================================================================//
//No ke-1.........................................................//
//IMPORT MODULE & DEPENDENCIES                                    //
import 'dart:convert'; 
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 

// [IMPORT SERVICE LOGGING USER CENTER]
import '../services/firestore_service.dart';

import '../screens/input_script_screen.dart';
import '../screens_veo/input_script_veo_screen.dart';
import '../screens/project_dashboard_screen.dart';

import './konsultan_ide_konten_screen.dart';
import './generator_kisah_sejarah_screen.dart';
import './generator_konten_umum_screen.dart';
import './generator_kisah_legenda_screen.dart';
import './generator_kisah_islami_screen.dart';
import './generator_kisah_horor_screen.dart';
import './generator_kisah_custom_screen.dart';
import './generator_konten_short_screen.dart';

import '../view_model_naraku/generator_gambar_thumbnail_view_model.dart';
import '../providers/user_provider.dart';
import '../providers/config_provider.dart'; 
import '../models/app_user.dart';
import '../models/app_config.dart';
//................................................................//

//No ke-2.........................................................//
//MAIN CLASS & STATE DECLARATION (STATEFUL CONVERSION)             //
class GeneratorGambarThumbnailScreen extends ConsumerStatefulWidget {
  const GeneratorGambarThumbnailScreen({super.key});

  @override
  ConsumerState<GeneratorGambarThumbnailScreen> createState() =>
      _GeneratorGambarThumbnailScreenState();
}

class _GeneratorGambarThumbnailScreenState
    extends ConsumerState<GeneratorGambarThumbnailScreen> {
  final int _maxPromptLength = 15000;

  @override
  void initState() {
    super.initState();
    // --- [LOG AKTIVITAS: KUNJUNGAN OTHER TOOLS -> THUMBNAIL] ---
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(firestoreServiceProvider).logFeatureActivity(
          featureKey: 'other_tools',
          subFeatureKey: 'thumbnail',
          eventType: 'visit',
        );
      }
    });
    // -----------------------------------------------------------
  }
//................................................................//

//No ke-3.........................................................//
//MAIN BUILD METHOD & SCAFFOLD                                    //
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(generatorGambarThumbnailViewModelProvider);
    final viewModel = ref.read(generatorGambarThumbnailViewModelProvider.notifier);
    final AsyncValue<AppUser> userState = ref.watch(firestoreUserProvider);
    final AsyncValue<AppConfig> configState = ref.watch(appConfigProvider);

    final currentLocale = ref.watch(appLanguageProvider);
    final isIndo = currentLocale.languageCode == 'id';
    String t(String en, String id) => isIndo ? id : en;

    final theme = Theme.of(context);

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

      // --- [LOG AKTIVITAS: KONVERSI SUKSES GENERATE THUMBNAIL] ---
      if (previous?.isLoading == true && !next.isLoading && next.generatedImageUrl.isNotEmpty) {
        ref.read(firestoreServiceProvider).logFeatureActivity(
          featureKey: 'other_tools',
          subFeatureKey: 'thumbnail',
          eventType: 'conversion',
        );
      }
      // -----------------------------------------------------------
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
//................................................................//

//No ke-4.........................................................//
//ACTION LOGIC (FIRESTORE REPORT)                                 //
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
              final user = ref.read(firestoreUserProvider).valueOrNull;
              final userId = user?.uid ?? 'anonymous'; 

              FirebaseFirestore.instance.collection('reports').add({
                'content_preview': imageUrl.length > 100 ? imageUrl.substring(0, 100) : imageUrl, 
                'contentType': 'image_imagen4_url', 
                'reason': reasonController.text.isEmpty ? 'No reason provided' : reasonController.text,
                'reportedAt': FieldValue.serverTimestamp(),
                'userId': userId,
                'feature': 'Generator Thumbnail Imagen 4.0', 
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
//................................................................//

//No ke-5.........................................................//
//UI HELPERS (INPUT CARD & MODERN DROPDOWNS)                      //
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

    final Map<String, String> styleOptions = {
      'Hyperrealistic Style': t('Realistic', 'Realistis'),
      '3D Render Style': t('3D Render', 'Render 3D'),
      '2D Cartoon Style': t('2D Flat', 'Kartun 2D'),
    };

    final Map<String, String> ratioOptions = {
      '16:9': 'Landscape (16:9)',
      '9:16': 'Portrait (9:16)',
      '1:1': 'Square (1:1)',
    };

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
            const SizedBox(height: 24),
            
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: styleOptions.containsKey(state.selectedStyle) ? state.selectedStyle : 'Hyperrealistic Style',
                    isExpanded: true,
                    dropdownColor: theme.cardTheme.color,
                    decoration: InputDecoration(
                      labelText: t('Visual Style', 'Gaya Visual'),
                      filled: true,
                      fillColor: theme.scaffoldBackgroundColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: styleOptions.entries
                        .map((entry) => DropdownMenuItem(
                              value: entry.key,
                              child: Text(entry.value, overflow: TextOverflow.ellipsis),
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
                    value: ratioOptions.containsKey(state.selectedRatio) ? state.selectedRatio : '16:9',
                    isExpanded: true,
                    dropdownColor: theme.cardTheme.color,
                    decoration: InputDecoration(
                      labelText: t('Aspect Ratio', 'Rasio Aspek'),
                      filled: true,
                      fillColor: theme.scaffoldBackgroundColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: ratioOptions.entries.map((entry) => DropdownMenuItem(
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
            const SizedBox(height: 32),
            
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
//................................................................//

//No ke-6.........................................................//
//MODERN OUTPUT CARD (SESUAI DENGAN IMAGEN 4.0 URL)               //
  Widget _buildOutputCard(
    BuildContext context,
    WidgetRef ref,
    GeneratorGambarThumbnailViewModel viewModel,
    GeneratorGambarThumbnailState state,
    String Function(String, String) t,
  ) {
    final theme = Theme.of(context);
    final bool hasImageUrl = state.generatedImageUrl.isNotEmpty;
    final screenSize = MediaQuery.of(context).size;

    double getAspectRatio(String ratio) {
      try {
        final parts = ratio.split(':');
        if (parts.length == 2) {
          return double.parse(parts[0]) / double.parse(parts[1]);
        }
      } catch (_) {}
      return 16 / 9; 
    }

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor.withOpacity(0.5), width: 1),
      ),
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  t('Generated Result', 'Hasil Gambar Majiku AI'),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (hasImageUrl)
                  IconButton(
                    icon: const Icon(Icons.flag_outlined, color: Colors.redAccent),
                    onPressed: () => _showReportDialog(context, ref, state.generatedImageUrl),
                    tooltip: t('Report Image', 'Lapor Gambar'),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            
            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
              constraints: BoxConstraints(
                minHeight: 200,
                maxHeight: screenSize.height * 0.5,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: state.isLoading 
                  ? LinearGradient(
                      colors: [theme.primaryColor.withOpacity(0.3), theme.colorScheme.secondary.withOpacity(0.3)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
                color: state.isLoading ? null : theme.scaffoldBackgroundColor,
                border: Border.all(
                  color: state.isLoading ? theme.colorScheme.secondary.withOpacity(0.5) : theme.dividerColor
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: state.isLoading
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            height: 50,
                            width: 50,
                            child: CircularProgressIndicator(color: theme.colorScheme.secondary, strokeWidth: 3),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            t('AI is painting your vision...', 'AI sedang melukis visimu...'),
                            style: TextStyle(
                              color: theme.colorScheme.secondary, 
                              fontWeight: FontWeight.bold, 
                              letterSpacing: 1.2
                            ),
                          ),
                        ],
                      )
                    : hasImageUrl
                        ? Center(
                            child: AspectRatio(
                              aspectRatio: getAspectRatio(state.selectedRatio),
                              child: Image.network(
                                state.generatedImageUrl,
                                fit: BoxFit.contain,
                                loadingBuilder: (ctx, child, progress) =>
                                    progress == null ? child : const Center(child: CircularProgressIndicator()),
                              ),
                            ),
                          )
                        : Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.image_outlined, size: 48, color: theme.disabledColor),
                                const SizedBox(height: 16),
                                Text(
                                  t('Your masterpiece will appear here...', 'Mahakarya Anda akan muncul di sini...'),
                                  style: TextStyle(fontStyle: FontStyle.italic, color: theme.disabledColor, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
              ),
            ),
            const SizedBox(height: 20),
            
            if (hasImageUrl)
              Column(
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.download_rounded, size: 22),
                    label: Text(
                      t('Save Image', 'Simpan Gambar'),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      minimumSize: const Size(double.infinity, 50),
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      elevation: 5,
                      shadowColor: Colors.greenAccent.withOpacity(0.4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      viewModel.downloadImage();
                    },
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
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
                            t('Clear / Create New', 'Hapus / Buat Baru'),
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
//................................................................//

//No ke-7.........................................................//
//DRAWER BUILDER                                                  //
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
//................................................................//