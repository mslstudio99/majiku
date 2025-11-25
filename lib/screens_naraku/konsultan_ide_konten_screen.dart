// [RILIS REVISI - FIX LAYOUT DRAWER]
// KATEGORI_UI_TWEAK NO_URUT_04
// Lokasi: lib/screens_naraku/konsultan_ide_konten_screen.dart
// TUJUAN:
// 1. Mengganti DrawerHeader dengan Container agar jarak teks "Daftar Produk" lebih rapi dan presisi.
// 2. Menghapus label biaya pada tombol Generate (sesuai file sebelumnya).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// [IMPORT NAVIGASI MASTER]
import '../screens/input_script_screen.dart';
import '../screens_veo/input_script_veo_screen.dart';
import '../screens/project_dashboard_screen.dart';
// import './konsultan_ide_konten_screen.dart'; // Hapus self-import
import './generator_kisah_sejarah_screen.dart';
import './generator_konten_umum_screen.dart';
import './generator_kisah_legenda_screen.dart';
import './generator_kisah_islami_screen.dart';
import './generator_kisah_horor_screen.dart';
import './generator_kisah_custom_screen.dart';
import './generator_gambar_thumbnail_screen.dart';
import './generator_konten_short_screen.dart'; 

// [IMPORT NARAKU VM]
import '../view_model_naraku/konsultan_ide_konten_view_model.dart';

// [IMPORT PROVIDER]
import '../providers/user_provider.dart';
import '../providers/config_provider.dart';
import '../models/app_user.dart';
import '../models/app_config.dart';

class KonsultanIdeKontenScreen extends ConsumerWidget {
  const KonsultanIdeKontenScreen({super.key});

  final int _maxPromptLength = 200;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // [STATE & LOGIC]
    final state = ref.watch(konsultanIdeKontenViewModelProvider);
    final viewModel = ref.read(konsultanIdeKontenViewModelProvider.notifier);
    final AsyncValue<AppUser> userState = ref.watch(firestoreUserProvider);
    final AsyncValue<AppConfig> configState = ref.watch(appConfigProvider);
    
    final String generatorTitle = KonsultanLocalizationHelper.get('generatorTitle');
    
    // [THEME SHORTCUT]
    final theme = Theme.of(context);

    // [LISTENER]
    ref.listen<KonsultanIdeKontenState>(konsultanIdeKontenViewModelProvider,
        (previous, next) {
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
        // Warna AppBar otomatis dari Theme
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

  // --- Input Card ---
  Widget _buildInputCard(
    BuildContext context,
    WidgetRef ref,
    KonsultanIdeKontenViewModel viewModel,
    KonsultanIdeKontenState state,
    AsyncValue<AppUser> userState,
    AsyncValue<AppConfig> configState,
  ) {
    final theme = Theme.of(context);
    
    final charCounter =
        ValueNotifier<int>(viewModel.promptController.text.length);
    viewModel.promptController.addListener(() {
      charCounter.value = viewModel.promptController.text.length;
    });

    // --- Logika Tombol ---
    final bool vmIsLoading = state.isLoading;
    final bool providersAreLoading =
        userState.isLoading || configState.isLoading;
    final bool providersHaveError = userState.hasError || configState.hasError;
    final int currentBalance = userState.valueOrNull?.tokenBalance ?? 0;
    final int actionCost = configState.valueOrNull?.costs.ideKontenPerClick ??
        Costs.fallback().ideKontenPerClick;
    final bool canAfford = currentBalance >= actionCost;
    
    final String buttonLabel;
    if (vmIsLoading) {
      buttonLabel = KonsultanLocalizationHelper.get('btnProcessing');
    } else if (providersAreLoading) {
      buttonLabel = "Memuat Saldo...";
    } else if (providersHaveError) {
      buttonLabel = "Error Konfigurasi";
    } else if (!canAfford) {
      buttonLabel = "Token Tidak Cukup ($actionCost TM)";
    } else {
      // [MODIFIKASI] Menghapus tampilan biaya ($actionCost TM)
      buttonLabel = KonsultanLocalizationHelper.get('btnGenerate');
    }
    
    final bool isButtonDisabled =
        vmIsLoading || providersAreLoading || providersHaveError || !canAfford;
    
    // [THEME] Warna Tombol: Primary (Deep Purple) atau Disabled
    final Color buttonColor =
        (isButtonDisabled && !vmIsLoading && !providersAreLoading)
            ? theme.disabledColor
            : theme.primaryColor;

    return Card(
      // Warna Card otomatis dari Theme
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              KonsultanLocalizationHelper.get('generatorTitle'),
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  KonsultanLocalizationHelper.get('promptLabel'),
                  style: theme.textTheme.bodyMedium,
                ),
                ValueListenableBuilder<int>(
                  valueListenable: charCounter,
                  builder: (context, count, child) {
                    return Text(
                      '$count / $_maxPromptLength',
                      style: TextStyle(
                        color: count > _maxPromptLength
                            ? theme.colorScheme.error
                            : theme.textTheme.bodySmall?.color,
                        fontSize: 13,
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            
            // [THEME] Input Field
            TextField(
              controller: viewModel.promptController,
              maxLines: 3,
              maxLength: _maxPromptLength,
              enabled: !state.isLoading,
              decoration: InputDecoration(
                hintText: KonsultanLocalizationHelper.get('promptPlaceholder'),
                counterText: '',
                filled: true,
                // Warna Fill HITAM (Scaffold Background) agar elegan inset
                fillColor: theme.scaffoldBackgroundColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  // Warna Border Fokus: AMBER (Secondary)
                  borderSide: BorderSide(color: theme.colorScheme.secondary),
                ),
              ),
            ),
            const SizedBox(height: 20),
            
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
              onPressed: isButtonDisabled
                  ? null
                  : () => viewModel.generateIdeas(),
            ),
          ],
        ),
      ),
    );
  }

  // --- Output Card ---
  Widget _buildOutputCard(
    BuildContext context,
    WidgetRef ref,
    KonsultanIdeKontenViewModel viewModel,
    KonsultanIdeKontenState state,
  ) {
    final theme = Theme.of(context);
    final bool hasOutput = state.generatedIdeas.isNotEmpty;

    // [THEME] Warna Aksi
    final Color copyColor = hasOutput ? theme.colorScheme.secondary : theme.disabledColor;
    final Color clearColor = hasOutput ? theme.colorScheme.error : theme.disabledColor;

    String outputContent = hasOutput
        ? state.generatedIdeas
        : KonsultanLocalizationHelper.get('outputPlaceholder');

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              KonsultanLocalizationHelper.get('outputTitle'),
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              constraints: const BoxConstraints(minHeight: 150),
              decoration: BoxDecoration(
                // Warna Latar Output: HITAM (Scaffold Background)
                color: theme.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.dividerColor),
              ),
              child: state.isLoading
                  ? Center(
                      child: Text(
                          KonsultanLocalizationHelper.get('apiLoading'),
                          style: TextStyle(
                              color: theme.textTheme.bodySmall?.color,
                              fontStyle: FontStyle.italic)))
                  : SelectableText(
                      outputContent,
                      style: TextStyle(
                        color: hasOutput ? theme.textTheme.bodyMedium?.color : theme.textTheme.bodySmall?.color,
                        fontStyle:
                            hasOutput ? FontStyle.normal : FontStyle.italic,
                        height: 1.6,
                      ),
                    ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.copy, size: 18),
                    label: Text(KonsultanLocalizationHelper.get('btnCopy')),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      foregroundColor: copyColor,
                      side: BorderSide(color: copyColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    onPressed: !hasOutput
                        ? null
                        : () {
                            Clipboard.setData(
                                ClipboardData(text: state.generatedIdeas));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(KonsultanLocalizationHelper.get(
                                    'btnCopied')),
                                backgroundColor: Colors.green,
                              ),
                            );
                          },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: Text(KonsultanLocalizationHelper.get('btnClear')),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      foregroundColor: clearColor,
                      side: BorderSide(color: clearColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    onPressed: !hasOutput ? null : viewModel.clearAll,
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  // --- Drawer Master (Themed) ---
  Widget _buildNarakuDrawer(BuildContext context) {
    final theme = Theme.of(context);

    // --- [AWAL] Helper Navigasi ---
    void _goToKonsultan() {
      Navigator.pop(context);
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const KonsultanIdeKontenScreen(),
        ),
      );
    }

    void _goToKisahSejarah() {
      Navigator.pop(context);
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const GeneratorKisahSejarahScreen(),
        ),
      );
    }

    void _goToKontenUmum() {
      Navigator.pop(context);
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const GeneratorKontenUmumScreen(),
        ),
      );
    }

    void _goToKisahLegenda() {
      Navigator.pop(context);
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const GeneratorKisahLegendaScreen(),
        ),
      );
    }

    void _goToKisahIslami() {
      Navigator.pop(context);
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const GeneratorKisahIslamiScreen(),
        ),
      );
    }

    void _goToKisahHoror() {
      Navigator.pop(context);
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const GeneratorKisahHororScreen(),
        ),
      );
    }

    void _goToKisahCustom() {
      Navigator.pop(context);
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const GeneratorKisahCustomScreen(),
        ),
      );
    }

    void _goToGambarThumbnail() {
      Navigator.pop(context);
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const GeneratorGambarThumbnailScreen(),
        ),
      );
    }

    void _goToNaraku() {
      Navigator.pop(context);
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const GeneratorKontenShortScreen(),
        ),
      );
    }

    Widget _menuItem(String title, IconData icon, Function() onTap,
        {bool isDisabled = false}) {
      return ListTile(
        leading:
            Icon(icon, color: isDisabled ? theme.disabledColor : Colors.white70),
        title: Text(
          title,
          style: TextStyle(color: isDisabled ? theme.disabledColor : Colors.white),
        ),
        enabled: !isDisabled,
        onTap: isDisabled ? null : onTap,
      );
    }
    // --- [AKHIR] Helper Navigasi ---

    return Drawer(
      // Background Drawer mengikuti Theme (Black)
      backgroundColor: theme.scaffoldBackgroundColor,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // [PERBAIKAN LAYOUT] Mengganti DrawerHeader dengan Container
          Container(
            padding: const EdgeInsets.fromLTRB(16, 50, 16, 20), // Jarak atas dan bawah diatur manual
            color: theme.appBarTheme.backgroundColor, // Warna Header sama dengan AppBar
            child: Row(
              children: [
                 // Ikon Header Drawer (Aksen Amber)
                 Icon(Icons.lightbulb_outline, color: theme.colorScheme.secondary, size: 32),
                 const SizedBox(width: 12),
                 const Text(
                  'Daftar Produk',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // --- Daftar Produk ---
          _menuItem(
              'Konsultan Ide Konten', Icons.lightbulb_outline, () {}, isDisabled: true),
          _menuItem('Generator Konten Umum', Icons.rate_review_outlined,
              _goToKontenUmum),
          _menuItem('Generator Konten Short', Icons.movie_creation_outlined,
              _goToNaraku),
          _menuItem('Generator Kisah Sejarah', Icons.account_balance_outlined,
              _goToKisahSejarah),
          _menuItem('Generator Kisah Legenda', Icons.auto_stories_outlined,
              _goToKisahLegenda),
          _menuItem(
              'Generator Kisah Islami', Icons.mosque_outlined, _goToKisahIslami),
          _menuItem(
              'Generator Kisah Horor', Icons.help_outline, _goToKisahHoror),
          _menuItem('Generator Kisah Custom', Icons.theater_comedy_outlined,
              _goToKisahCustom),

          Divider(color: theme.dividerColor),

          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
            child: Text(
              'Create',
              style: TextStyle(
                color: theme.disabledColor,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          ListTile(
            leading: const Icon(Icons.image_search, color: Colors.blueAccent),
            title: const Text('Create Video Motion',
                style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => InputScriptScreen(),
                ),
              );
            },
          ),

          ListTile(
            leading: Icon(Icons.movie_filter, color: theme.primaryColor),
            title: const Text('Create Video Footage',
                style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => InputScriptVeoScreen(),
                ),
              );
            },
          ),
          
          _menuItem(
            'Create Thumbnail',
            Icons.aspect_ratio_outlined,
            _goToGambarThumbnail,
          ),
        ],
      ),
    );
  }
}