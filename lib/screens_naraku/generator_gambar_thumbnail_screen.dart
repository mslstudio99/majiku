// [RILIS FINAL - STYLE OPTION HORIZONTAL]
// KATEGORI_UI_TWEAK NO_URUT_20
// Lokasi: lib/screens_naraku/generator_gambar_thumbnail_screen.dart
// TUJUAN:
// 1. Mengubah layout pilihan 'Visual Style' menjadi Horizontal (Row) agar rapi.
// 2. Memastikan teks label style muat (Expanded & Font Size disesuaikan).
// 3. Mempertahankan tema Dark Modern dan semua logika ViewModel.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// [IMPORT NAVIGASI MASTER]
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
// import './generator_gambar_thumbnail_screen.dart'; // Halaman ini
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

  final int _maxPromptLength = 24000;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // [STATE MANAGEMENT]
    final state = ref.watch(generatorGambarThumbnailViewModelProvider);
    final viewModel = ref.read(generatorGambarThumbnailViewModelProvider.notifier);

    // [USER & CONFIG STATE]
    final AsyncValue<AppUser> userState = ref.watch(firestoreUserProvider);
    final AsyncValue<AppConfig> configState = ref.watch(appConfigProvider);

    final String generatorTitle = GambarThumbnailLocalizationHelper.get('generatorTitle');
    
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
      // Background otomatis hitam dari Theme
      appBar: AppBar(
        title: Text(generatorTitle),
        // Style AppBar otomatis dari Theme
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
      drawer: _buildNarakuDrawer(context),
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
            ),
            const SizedBox(height: 24),
            _buildOutputCard(context, ref, viewModel, state),
          ],
        ),
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
  ) {
    final theme = Theme.of(context);
    
    // Penghitung Karakter
    final charCounter = ValueNotifier<int>(viewModel.narrativeController.text.length);
    viewModel.narrativeController.addListener(() {
      charCounter.value = viewModel.narrativeController.text.length;
    });

    // --- [LOGIKA TOKEN & BIAYA] ---
    final bool vmIsLoading = state.isLoading;
    final bool providersAreLoading = userState.isLoading || configState.isLoading;
    final bool providersHaveError = userState.hasError || configState.hasError;
    final int currentBalance = userState.valueOrNull?.tokenBalance ?? 0;
    final int actionCost = configState.valueOrNull?.costs.createThumbnailPerClick ??
            Costs.fallback().createThumbnailPerClick;
    final bool canAfford = currentBalance >= actionCost;

    final String buttonLabel;
    if (vmIsLoading) {
      buttonLabel = GambarThumbnailLocalizationHelper.get('statusGenerating');
    } else if (providersAreLoading) {
      buttonLabel = "Memuat...";
    } else if (providersHaveError) {
      buttonLabel = "Error";
    } else if (!canAfford) {
      buttonLabel = "Token Tidak Cukup";
    } else {
      buttonLabel = GambarThumbnailLocalizationHelper.get('btnGenerate');
    }

    final bool isButtonDisabled = vmIsLoading || providersAreLoading || providersHaveError || !canAfford;
    
    // Warna Tombol: Primary (Ungu) atau Disabled
    final Color buttonColor = (isButtonDisabled && !vmIsLoading && !providersAreLoading)
        ? theme.disabledColor
        : theme.primaryColor;

    return Card(
      margin: EdgeInsets.zero,
      // Card mengikuti tema (Abu Gelap)
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              GambarThumbnailLocalizationHelper.get('generatorTitle'),
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            
            // Header Label & Counter
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  GambarThumbnailLocalizationHelper.get('promptLabel'),
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
            
            // [ELEGANT BLACK INPUT]
            TextField(
              controller: viewModel.narrativeController,
              maxLines: 6,
              maxLength: _maxPromptLength,
              enabled: !state.isLoading,
              style: theme.textTheme.bodyLarge,
              decoration: InputDecoration(
                hintText: GambarThumbnailLocalizationHelper.get('promptPlaceholder'),
                counterText: '',
                filled: true,
                // Warna Fill HITAM (Menyatu dengan background)
                fillColor: theme.scaffoldBackgroundColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  // Border Fokus EMAS
                  borderSide: BorderSide(color: theme.colorScheme.secondary),
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // Opsi Gaya Gambar (Style)
            Text(
              GambarThumbnailLocalizationHelper.get('labelStyle'),
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            _buildStyleOptions(context, viewModel, state),
            
            const SizedBox(height: 20),
            
            // Opsi Rasio Gambar (Ratio)
            Text(
              GambarThumbnailLocalizationHelper.get('labelRatio'),
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            _buildRatioOptions(context, viewModel, state),
            
            const SizedBox(height: 24),
            
            // Tombol Eksekusi
            ElevatedButton.icon(
              icon: vmIsLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                disabledBackgroundColor: buttonColor,
                disabledForegroundColor: Colors.white.withOpacity(0.7),
              ),
              onPressed: isButtonDisabled ? null : viewModel.generateStory,
            ),
          ],
        ),
      ),
    );
  }

  // --- Pilihan Style (DIPERBAIKI: HORIZONTAL / ROW) ---
  Widget _buildStyleOptions(
      BuildContext context,
      GeneratorGambarThumbnailViewModel viewModel,
      GeneratorGambarThumbnailState state) {
    final theme = Theme.of(context);
    final options = {
      "Hyperrealistic Style": 'styleRealistic',
      "3D Pixar Render Style": 'styleCartoon3d',
      "Flat 2D Cartoon Style": 'styleCartoon2d',
    };

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: options.entries.map((entry) {
        final value = entry.key;
        final label = GambarThumbnailLocalizationHelper.get(entry.value);
        return Expanded(
          child: RadioListTile<String>(
            title: Text(
              label, 
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 11), // Font diperkecil agar muat
              maxLines: 2, 
              overflow: TextOverflow.ellipsis,
            ),
            value: value,
            groupValue: state.selectedStyle,
            onChanged: state.isLoading ? null : (val) => viewModel.setStyle(val),
            // Warna Seleksi EMAS
            activeColor: theme.colorScheme.secondary,
            contentPadding: EdgeInsets.zero,
            dense: true,
            visualDensity: VisualDensity.compact,
          ),
        );
      }).toList(),
    );
  }

  // --- Pilihan Rasio (Radio Row) ---
  Widget _buildRatioOptions(
      BuildContext context,
      GeneratorGambarThumbnailViewModel viewModel,
      GeneratorGambarThumbnailState state) {
    final theme = Theme.of(context);
    final options = {
      "16:9": "16:9",
      "9:16": "9:16",
      "1:1": "1:1",
    };

    return Row(
      children: options.entries.map((entry) {
        final value = entry.key;
        final label = entry.value;
        return Expanded(
          child: RadioListTile<String>(
            title: Text(label, style: theme.textTheme.bodySmall?.copyWith(fontSize: 14)),
            value: value,
            groupValue: state.selectedRatio,
            onChanged: state.isLoading ? null : (val) => viewModel.setRatio(val),
            // Warna Seleksi EMAS
            activeColor: theme.colorScheme.secondary,
            contentPadding: EdgeInsets.zero,
            dense: true,
            visualDensity: VisualDensity.compact,
          ),
        );
      }).toList(),
    );
  }

  // --- Helper Kartu Output ---
  Widget _buildOutputCard(
    BuildContext context,
    WidgetRef ref,
    GeneratorGambarThumbnailViewModel viewModel,
    GeneratorGambarThumbnailState state,
  ) {
    final theme = Theme.of(context);
    final bool hasImageUrl = state.generatedImageUrl.isNotEmpty;
    final String outputPlaceholderText = GambarThumbnailLocalizationHelper.get('outputPlaceholder');

    // Warna Aksi: Emas (Secondary) & Merah (Error)
    final Color actionColor = theme.colorScheme.secondary;
    final Color errorColor = theme.colorScheme.error;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              GambarThumbnailLocalizationHelper.get('outputTitle'),
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            
            // Area Tampilan Gambar
            Container(
              padding: const EdgeInsets.all(16),
              constraints: const BoxConstraints(minHeight: 150),
              decoration: BoxDecoration(
                // Warna Latar Hitam
                color: theme.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.dividerColor),
              ),
              child: state.isLoading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.secondary),
                          const SizedBox(height: 16),
                          Text(
                            GambarThumbnailLocalizationHelper.get('statusLoading'),
                            style: TextStyle(
                                color: theme.textTheme.bodySmall?.color,
                                fontStyle: FontStyle.italic),
                          ),
                        ],
                      ),
                    )
                  : hasImageUrl
                      ? Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 600),
                            child: AspectRatio(
                              aspectRatio: _parseRatio(state.selectedRatio),
                              child: Image.network(
                                state.generatedImageUrl,
                                fit: BoxFit.contain,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Center(
                                    child: CircularProgressIndicator(
                                      value: loadingProgress.expectedTotalBytes != null
                                          ? loadingProgress.cumulativeBytesLoaded /
                                              loadingProgress.expectedTotalBytes!
                                          : null,
                                      color: theme.colorScheme.secondary,
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  return Center(
                                    child: Text(
                                      'Gagal memuat gambar: $error',
                                      style: TextStyle(color: theme.colorScheme.error),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        )
                      : Center(
                          child: Text(
                            outputPlaceholderText,
                            style: TextStyle(
                                color: theme.textTheme.bodySmall?.color,
                                fontStyle: FontStyle.italic,
                                height: 1.6),
                          ),
                        ),
            ),
            const SizedBox(height: 20),
            
            // Tombol Aksi (Download & Clear)
            Row(
              children: [
                // Tombol Download
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.download, size: 18),
                    label: Text(GambarThumbnailLocalizationHelper.get('btnDownload')),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      foregroundColor: actionColor,
                      side: BorderSide(color: actionColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    onPressed: !hasImageUrl
                        ? null
                        : () async {
                            await viewModel.downloadImage();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(GambarThumbnailLocalizationHelper.get(
                                    'statusDownloadSuccess')),
                                backgroundColor: Colors.green,
                              ),
                            );
                          },
                  ),
                ),
                const SizedBox(width: 16),
                
                // Tombol Clear
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: Text(GambarThumbnailLocalizationHelper.get('btnClear')),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      foregroundColor: errorColor,
                      side: BorderSide(color: errorColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    onPressed: (!hasImageUrl && viewModel.narrativeController.text.isEmpty)
                        ? null
                        : viewModel.clearAll,
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
      final width = double.tryParse(parts[0]);
      final height = double.tryParse(parts[1]);
      if (width != null && height != null && height != 0) {
        return width / height;
      }
    }
    return 16 / 9;
  }

  // --- Drawer (Layout Fix & Container) ---
  Widget _buildNarakuDrawer(BuildContext context) {
    final theme = Theme.of(context);

    void _goToKonsultan() {
      Navigator.pop(context);
      Navigator.of(context).push(MaterialPageRoute(builder: (context) => const KonsultanIdeKontenScreen()));
    }
    void _goToKisahSejarah() {
      Navigator.pop(context);
      Navigator.of(context).push(MaterialPageRoute(builder: (context) => const GeneratorKisahSejarahScreen()));
    }
    void _goToKontenUmum() {
      Navigator.pop(context);
      Navigator.of(context).push(MaterialPageRoute(builder: (context) => const GeneratorKontenUmumScreen()));
    }
    void _goToNaraku() {
      Navigator.pop(context);
      Navigator.of(context).push(MaterialPageRoute(builder: (context) => const GeneratorKontenShortScreen()));
    }
    void _goToKisahLegenda() {
      Navigator.pop(context);
      Navigator.of(context).push(MaterialPageRoute(builder: (context) => const GeneratorKisahLegendaScreen()));
    }
    void _goToKisahIslami() {
      Navigator.pop(context);
      Navigator.of(context).push(MaterialPageRoute(builder: (context) => const GeneratorKisahIslamiScreen()));
    }
    void _goToKisahHoror() {
      Navigator.pop(context);
      Navigator.of(context).push(MaterialPageRoute(builder: (context) => const GeneratorKisahHororScreen()));
    }
    void _goToKisahCustom() {
      Navigator.pop(context);
      Navigator.of(context).push(MaterialPageRoute(builder: (context) => const GeneratorKisahCustomScreen()));
    }
    // void _goToGambarThumbnail() { Navigator.pop(context); } // Halaman ini

    Widget _menuItem(String title, IconData icon, Function() onTap, {bool isDisabled = false}) {
      return ListTile(
        leading: Icon(icon, color: isDisabled ? theme.disabledColor : Colors.white70),
        title: Text(title, style: TextStyle(color: isDisabled ? theme.disabledColor : Colors.white)),
        enabled: !isDisabled,
        onTap: isDisabled ? null : onTap,
      );
    }

    return Drawer(
      // Background Drawer Hitam (Theme)
      backgroundColor: theme.scaffoldBackgroundColor,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // [PERBAIKAN LAYOUT] Mengganti DrawerHeader dengan Container manual
          Container(
            padding: const EdgeInsets.fromLTRB(16, 50, 16, 20), 
            color: theme.appBarTheme.backgroundColor, 
            child: Row(
              children: [
                 Icon(Icons.movie_creation_outlined, color: theme.colorScheme.secondary, size: 32),
                 const SizedBox(width: 12),
                 const Text(
                  'Daftar Produk',
                  style: TextStyle(
                    color: Colors.white, 
                    fontSize: 22, 
                    fontWeight: FontWeight.bold
                  ),
                ),
              ],
            ),
          ),
          
          _menuItem('Konsultan Ide Konten', Icons.lightbulb_outline, _goToKonsultan),
          _menuItem('Generator Konten Umum', Icons.rate_review_outlined, _goToKontenUmum),
          _menuItem('Generator Konten Short', Icons.movie_creation_outlined, _goToNaraku),
          _menuItem('Generator Kisah Sejarah', Icons.account_balance_outlined, _goToKisahSejarah),
          _menuItem('Generator Kisah Legenda', Icons.auto_stories_outlined, _goToKisahLegenda),
          _menuItem('Generator Kisah Islami', Icons.mosque_outlined, _goToKisahIslami),
          _menuItem('Generator Kisah Horor', Icons.help_outline, _goToKisahHoror),
          _menuItem('Generator Kisah Custom', Icons.theater_comedy_outlined, _goToKisahCustom),
          
          Divider(color: theme.dividerColor, height: 30),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0), 
            child: Text(
              'Create', 
              style: TextStyle(color: theme.disabledColor, fontSize: 14, fontWeight: FontWeight.w600)
            )
          ),
          
          ListTile(
            leading: const Icon(Icons.image_search, color: Colors.blueAccent),
            title: const Text('Create Video Motion', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(MaterialPageRoute(builder: (context) => InputScriptScreen())); 
            },
          ),
          ListTile(
            leading: Icon(Icons.movie_filter, color: theme.primaryColor),
            title: const Text('Create Video Footage', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(MaterialPageRoute(builder: (context) => InputScriptVeoScreen())); 
            },
          ),
          
          _menuItem('Create Thumbnail', Icons.aspect_ratio_outlined, () {}, isDisabled: true), // Halaman Ini
        ],
      ),
    );
  }
}