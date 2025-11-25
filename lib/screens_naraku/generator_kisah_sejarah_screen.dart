// [RILIS FINAL - UI DRAWER FIX]
// KATEGORI_UI_TWEAK NO_URUT_05
// Lokasi: lib/screens_naraku/generator_kisah_sejarah_screen.dart
// TUJUAN:
// 1. Memperbaiki layout Drawer (Mengganti DrawerHeader dengan Container) agar rapi.
// 2. Mempertahankan tema Dark Modern yang sudah ada.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// [IMPORT NAVIGASI]
import '../screens/input_script_screen.dart';
import '../screens_veo/input_script_veo_screen.dart';
import '../screens/project_dashboard_screen.dart';

// [IMPORT GENERATOR LAIN]
import './konsultan_ide_konten_screen.dart';
// import './generator_kisah_sejarah_screen.dart'; // Halaman ini
import './generator_konten_umum_screen.dart';
import './generator_kisah_legenda_screen.dart';
import './generator_kisah_islami_screen.dart';
import './generator_kisah_horor_screen.dart';
import './generator_kisah_custom_screen.dart';
import './generator_gambar_thumbnail_screen.dart';
import './generator_konten_short_screen.dart';

// [IMPORT VM & MODELS]
import '../view_model_naraku/generator_kisah_sejarah_view_model.dart';
import '../providers/user_provider.dart';
import '../providers/config_provider.dart';
import '../models/app_user.dart';
import '../models/app_config.dart';

class GeneratorKisahSejarahScreen extends ConsumerWidget {
  const GeneratorKisahSejarahScreen({super.key});

  final int _maxPromptLength = 200;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(generatorKisahSejarahViewModelProvider);
    final viewModel = ref.read(generatorKisahSejarahViewModelProvider.notifier);
    final AsyncValue<AppUser> userState = ref.watch(firestoreUserProvider);
    final AsyncValue<AppConfig> configState = ref.watch(appConfigProvider);

    final String generatorTitle = KisahSejarahLocalizationHelper.get('generatorTitle');
    
    // [THEME SHORTCUT]
    final theme = Theme.of(context);

    ref.listen<GeneratorKisahSejarahState>(
        generatorKisahSejarahViewModelProvider, (previous, next) {
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
    GeneratorKisahSejarahViewModel viewModel,
    GeneratorKisahSejarahState state,
    AsyncValue<AppUser> userState,
    AsyncValue<AppConfig> configState,
  ) {
    final theme = Theme.of(context);
    final charCounter = ValueNotifier<int>(viewModel.promptController.text.length);
    viewModel.promptController.addListener(() {
      charCounter.value = viewModel.promptController.text.length;
    });

    // --- [LOGIKA TOMBOL] ---
    final bool vmIsLoading = state.isLoading;
    final bool providersAreLoading = userState.isLoading || configState.isLoading;
    final bool providersHaveError = userState.hasError || configState.hasError;
    final int currentBalance = userState.valueOrNull?.tokenBalance ?? 0;
    final int actionCost = configState.valueOrNull?.costs.kisahSejarahPerClick ??
        Costs.fallback().kisahSejarahPerClick;
    final bool canAfford = currentBalance >= actionCost;

    final String buttonLabel;
    if (vmIsLoading) {
      buttonLabel = KisahSejarahLocalizationHelper.get('btnProcessing');
    } else if (providersAreLoading) {
      buttonLabel = "Memuat...";
    } else if (providersHaveError) {
      buttonLabel = "Error";
    } else if (!canAfford) {
      buttonLabel = "Token Tidak Cukup";
    } else {
      // Label normal
      buttonLabel = KisahSejarahLocalizationHelper.get('btnGenerate');
    }

    final bool isButtonDisabled = vmIsLoading || providersAreLoading || providersHaveError || !canAfford;
    
    // [THEME] Warna Tombol Primary (Deep Purple)
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
              KisahSejarahLocalizationHelper.get('generatorTitle'),
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  KisahSejarahLocalizationHelper.get('promptLabel'),
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
            
            // [THEME] Input Field (Black Inset)
            TextField(
              controller: viewModel.promptController,
              maxLines: 3,
              maxLength: _maxPromptLength,
              enabled: !state.isLoading,
              decoration: InputDecoration(
                hintText: KisahSejarahLocalizationHelper.get('promptPlaceholder'),
                counterText: '',
                filled: true,
                // Fill warna Hitam (Scaffold BG)
                fillColor: theme.scaffoldBackgroundColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  // Border warna Amber (Secondary)
                  borderSide: BorderSide(color: theme.colorScheme.secondary),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              KisahSejarahLocalizationHelper.get('tipLanguage'),
              style: theme.textTheme.bodySmall,
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
              onPressed: isButtonDisabled ? null : () => viewModel.generateStory(),
            ),
          ],
        ),
      ),
    );
  }

  // --- Helper Kartu Output ---
  Widget _buildOutputCard(
    BuildContext context,
    WidgetRef ref,
    GeneratorKisahSejarahViewModel viewModel,
    GeneratorKisahSejarahState state,
  ) {
    final theme = Theme.of(context);
    final bool hasOutput = state.generatedStory.isNotEmpty;
    
    // [THEME] Warna Aksi
    final Color copyColor = hasOutput ? theme.colorScheme.secondary : theme.disabledColor;
    final Color clearColor = hasOutput ? theme.colorScheme.error : theme.disabledColor;

    String outputContent = hasOutput
        ? state.generatedStory
        : KisahSejarahLocalizationHelper.get('outputPlaceholder');

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              KisahSejarahLocalizationHelper.get('outputTitle'),
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              constraints: const BoxConstraints(minHeight: 150),
              decoration: BoxDecoration(
                // Warna Box Output Hitam (Scaffold BG)
                color: theme.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.dividerColor),
              ),
              child: state.isLoading
                  ? Center(
                      child: Text(
                          KisahSejarahLocalizationHelper.get('apiLoading'),
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
            
            // --- [HEADER & KONTROL OUTPUT] ---
            Row(
              children: [
                // 1. TOMBOL COPY
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Copy'),
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
                                ClipboardData(text: state.generatedStory));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    KisahSejarahLocalizationHelper.get('btnCopied')),
                                backgroundColor: Colors.green,
                              ),
                            );
                          },
                  ),
                ),
                const SizedBox(width: 16),
                
                // 2. TOMBOL SEND
                _buildSendToProjectButton(context, state),

                const SizedBox(width: 16),
                
                // 3. TOMBOL CLEAR
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: Text(KisahSejarahLocalizationHelper.get('btnClear')),
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

  // --- Helper: Parsing Hasil Narasi Kasar ---
  Map<String, String> _parseGeneratedContent(String rawContent) {
    if (rawContent.isEmpty) return {'title': '', 'script': ''};
    
    final lines = rawContent.split('\n');
    int startLine = -1;
    String rawTitle = '';
    
    for (int i = 0; i < lines.length; i++) {
      String line = lines[i].trim();
      if (line.toLowerCase().startsWith('source:')) continue; 
      if (line.isNotEmpty) {
        rawTitle = line;
        startLine = i;
        break; 
      }
    }
    
    String script = '';
    if (startLine != -1) {
      script = lines.sublist(startLine + 1).join('\n').trim();
    }
    
    String defaultTitle = "Kisah Sejarah";
    
    if (rawTitle.isEmpty && script.isNotEmpty) rawTitle = defaultTitle;
    else if (rawTitle.isEmpty && script.isEmpty) return {'title': '', 'script': ''};
    
    String cleanedScript = script.replaceAll(RegExp(r'\n\s*\n', multiLine: true), '\n\n').trim();
    return {'title': rawTitle, 'script': cleanedScript};
  }

  // --- Helper: Dropdown Tombol Send (Themed) ---
  Widget _buildSendToProjectButton(
      BuildContext context, GeneratorKisahSejarahState state) {
    
    final theme = Theme.of(context);
    final bool hasOutput = state.generatedStory.isNotEmpty; 

    // Jika Kosong: Tombol Disabled
    if (!hasOutput) {
      return Expanded(
        child: OutlinedButton.icon(
          icon: const Icon(Icons.send_to_mobile, size: 18),
          label: const Text("Send"),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12), 
            foregroundColor: theme.disabledColor,
            side: BorderSide(color: theme.disabledColor), 
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
          onPressed: null,
        ),
      );
    }
    
    final Map<String, String> parsedData = _parseGeneratedContent(state.generatedStory);
    final String cleanTitle = parsedData['title']!;
    final String cleanScript = parsedData['script']!;

    // [THEME] Warna Aktif
    final Color activeFillColor = theme.primaryColor;
    final Color activeBorderColor = theme.colorScheme.secondary;

    return Expanded(
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<String>(
          decoration: InputDecoration(
            isDense: true, 
            contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            filled: true,
            fillColor: activeFillColor,
            // Border menyala dengan warna Secondary (Amber)
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: BorderSide(color: activeBorderColor, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: BorderSide(color: activeBorderColor, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: const BorderSide(color: Colors.white, width: 2.0),
            ),
          ),
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
          hint: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.send_to_mobile, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text("Send", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          items: <DropdownMenuItem<String>>[
            DropdownMenuItem<String>(
              value: 'motion',
              child: Row(
                children: [
                  Icon(Icons.image_search, size: 16, color: activeFillColor),
                  const SizedBox(width: 8),
                  const Text('To VMotion', style: TextStyle(fontSize: 14)),
                ],
              ),
            ),
            DropdownMenuItem<String>(
              value: 'veo',
              child: Row(
                children: [
                  Icon(Icons.movie_filter, size: 16, color: activeFillColor),
                  const SizedBox(width: 8),
                  const Text('To VFootage', style: TextStyle(fontSize: 14)),
                ],
              ),
            ),
          ],
          onChanged: (String? value) {
            if (value == null) return;

            final Widget targetScreen = value == 'motion'
                ? InputScriptScreen(initialTitle: cleanTitle, initialScript: cleanScript)
                : InputScriptVeoScreen(initialTitle: cleanTitle, initialScript: cleanScript);

            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => targetScreen),
            );
          },
          selectedItemBuilder: (context) {
             return [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.send_to_mobile, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text("Send", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.send_to_mobile, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text("Send", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
             ];
          },
        ),
      ),
    );
  }

  // --- Drawer (Dark Modern - Layout Fix) ---
  Widget _buildNarakuDrawer(BuildContext context) {
    final theme = Theme.of(context);

    void _goToKonsultan() {
      Navigator.pop(context);
      Navigator.of(context).push(MaterialPageRoute(builder: (context) => const KonsultanIdeKontenScreen()));
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
    void _goToGambarThumbnail() {
      Navigator.pop(context);
      Navigator.of(context).push(MaterialPageRoute(builder: (context) => const GeneratorGambarThumbnailScreen()));
    }

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
          // [PERBAIKAN LAYOUT] Mengganti DrawerHeader dengan Container agar rapi
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
          _menuItem('Generator Kisah Sejarah', Icons.account_balance_outlined, () {}, isDisabled: true), // Halaman Ini
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
          
          _menuItem('Create Thumbnail', Icons.aspect_ratio_outlined, _goToGambarThumbnail),
        ],
      ),
    );
  }
}