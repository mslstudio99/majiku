// [RILIS REVISI - ELEGANT BLACK INPUTS]
// KATEGORI_UI_TWEAK NO_URUT_02
// Lokasi: lib/screens_naraku/generator_konten_short_screen.dart
// TUJUAN:
// 1. Menyamakan background kolom Input Prompt dengan kolom Output (Hitam Pekat).
// 2. Meningkatkan kontras dan eleganitas UI.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// [IMPORT NAVIGASI]
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
import './generator_gambar_thumbnail_screen.dart';

// [IMPORT VM & MODELS]
import '../view_model_naraku/generator_konten_short_view_model.dart';
import '../providers/user_provider.dart';
import '../providers/config_provider.dart';
import '../models/app_user.dart';
import '../models/app_config.dart';

class GeneratorKontenShortScreen extends ConsumerWidget {
  const GeneratorKontenShortScreen({super.key});
  final int _maxPromptLength = 200;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // [STATE LOKAL]
    final state = ref.watch(generatorKontenShortViewModelProvider);
    final viewModel = ref.read(generatorKontenShortViewModelProvider.notifier);

    final String generatorTitle = NarakuLocalizationHelper.get('generatorTitle');

    // [STATE GLOBAL]
    final AsyncValue<AppUser> userState = ref.watch(firestoreUserProvider);
    final AsyncValue<AppConfig> configState = ref.watch(appConfigProvider);
    
    // [THEME SHORTCUTS]
    final theme = Theme.of(context);

    // [LISTENER ERROR]
    ref.listen<GeneratorKontenShortState>(generatorKontenShortViewModelProvider,
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
      // Background diambil otomatis dari Theme (Black)
      appBar: AppBar(
        title: Text(generatorTitle),
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
              generatorTitle,
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
      GeneratorKontenShortViewModel viewModel,
      GeneratorKontenShortState state,
      String generatorTitle,
      AsyncValue<AppUser> userState,
      AsyncValue<AppConfig> configState) {
    
    final theme = Theme.of(context);
    final charCounter =
        ValueNotifier<int>(viewModel.promptController.text.length);
    viewModel.promptController.addListener(() {
      charCounter.value = viewModel.promptController.text.length;
    });

    // --- [LOGIKA TOMBOL] ---
    final bool vmIsLoading = state.isLoading;
    final bool providersAreLoading =
        userState.isLoading || configState.isLoading;
    final bool providersHaveError = userState.hasError || configState.hasError;
    final int currentBalance = userState.valueOrNull?.tokenBalance ?? 0;
    final int actionCost = configState.valueOrNull?.costs.kontenShortPerClick ??
        Costs.fallback().kontenShortPerClick;
    final bool canAfford = currentBalance >= actionCost;

    final String buttonLabel;
    if (vmIsLoading) {
      buttonLabel = NarakuLocalizationHelper.get('statusGenerating');
    } else if (providersAreLoading) {
      buttonLabel = "Memuat...";
    } else if (providersHaveError) {
      buttonLabel = "Error";
    } else if (!canAfford) {
      buttonLabel = "Token Tidak Cukup";
    } else {
      buttonLabel = NarakuLocalizationHelper.get('btnGenerate');
    }

    final bool isButtonDisabled =
        vmIsLoading || providersAreLoading || providersHaveError || !canAfford;

    final Color buttonColor =
        (isButtonDisabled && !vmIsLoading && !providersAreLoading)
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
              NarakuLocalizationHelper.get('generatorTitle'),
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  NarakuLocalizationHelper.get('promptLabel'),
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
            
            // INPUT UTAMA - REVISI BACKGROUND HITAM
            TextField(
              controller: viewModel.promptController,
              maxLines: 3,
              maxLength: _maxPromptLength,
              enabled: !state.isLoading,
              decoration: InputDecoration(
                hintText: NarakuLocalizationHelper.get('promptPlaceholder'),
                counterText: '',
                filled: true,
                // [FIX] Memaksa warna hitam (scaffoldBackgroundColor) agar sama dengan output
                fillColor: theme.scaffoldBackgroundColor, 
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: theme.colorScheme.secondary), // Emas saat fokus
                ),
              ),
            ),
            
            // --- Dropdown Panjang Narasi ---
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              value: state.lengthOption,
              // [FIX] Menyamakan style dropdown dengan TextField (Hitam)
              decoration: InputDecoration(
                labelText: 'Target Character Length',
                filled: true,
                fillColor: theme.scaffoldBackgroundColor, // Hitam
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
              dropdownColor: theme.cardTheme.color,
              style: theme.textTheme.bodyLarge,
              items: [500, 1000, 2000, 3000, 4000].map((int value) {
                return DropdownMenuItem<int>(
                  value: value,
                  child: Text('$value Characters'),
                );
              }).toList(),
              onChanged: state.isLoading
                  ? null
                  : (int? newValue) {
                      if (newValue != null) {
                        viewModel.setLengthOption(newValue);
                      }
                    },
            ),

            const SizedBox(height: 8),
            Text(
              NarakuLocalizationHelper.get('languageHint'),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            
            // --- Tombol Generate ---
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
                backgroundColor: buttonColor,
                foregroundColor: Colors.white,
              ),
              onPressed: isButtonDisabled
                  ? null
                  : () => viewModel.generateNarrative(generatorTitle),
            ),
          ],
        ),
      ),
    );
  }

  // --- Helper Kartu Output ---
  Widget _buildOutputCard(BuildContext context, WidgetRef ref,
      GeneratorKontenShortViewModel viewModel, GeneratorKontenShortState state) {
    
    final theme = Theme.of(context);
    final bool hasOutput = state.generatedNarrative.isNotEmpty;
    
    final Color copyColor = hasOutput ? theme.colorScheme.secondary : theme.disabledColor;
    final Color clearColor = hasOutput ? theme.colorScheme.error : theme.disabledColor;

    String outputContent = hasOutput
        ? state.generatedNarrative
        : NarakuLocalizationHelper.get('outputPlaceholder');

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              NarakuLocalizationHelper.get('outputTitle'),
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              constraints: const BoxConstraints(minHeight: 150),
              decoration: BoxDecoration(
                // [FIX] Ini adalah referensi warna yang kita samakan (Hitam)
                color: theme.scaffoldBackgroundColor, 
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.dividerColor),
              ),
              child: state.isLoading
                  ? Center(
                      child: Text(NarakuLocalizationHelper.get('statusLoading'),
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
                                ClipboardData(text: state.generatedNarrative));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(NarakuLocalizationHelper.get(
                                    'statusCopySuccess')),
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
                    label: Text(NarakuLocalizationHelper.get('btnClear')),
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

  // --- Helper: Parsing Hasil Narasi ---
  Map<String, String> _parseGeneratedContent(String rawContent) {
    if (rawContent.isEmpty) {
      return {'title': '', 'script': ''};
    }
    
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
    
    String defaultTitle = NarakuLocalizationHelper.get('defaultProjectTitle');
    
    if (rawTitle.isEmpty && script.isNotEmpty) {
      rawTitle = defaultTitle;
    } else if (rawTitle.isEmpty && script.isEmpty) {
      return {'title': '', 'script': ''};
    }
    
    String cleanedScript = script.replaceAll(RegExp(r'\n\s*\n', multiLine: true), '\n\n').trim();
    return {'title': rawTitle, 'script': cleanedScript};
  }

  // --- Helper: Dropdown Tombol Send ---
  Widget _buildSendToProjectButton(
      BuildContext context, GeneratorKontenShortState state) {
    
    final theme = Theme.of(context);
    final bool hasOutput = state.generatedNarrative.isNotEmpty;

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
    
    final Map<String, String> parsedData = _parseGeneratedContent(state.generatedNarrative);
    final String cleanTitle = parsedData['title']!;
    final String cleanScript = parsedData['script']!;

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


  // --- Drawer ---
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
      backgroundColor: theme.scaffoldBackgroundColor, 
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
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
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          _menuItem('Konsultan Ide Konten', Icons.lightbulb_outline, _goToKonsultan),
          _menuItem('Generator Konten Umum', Icons.rate_review_outlined, _goToKontenUmum),
          _menuItem('Generator Konten Short', Icons.movie_creation_outlined, () {}, isDisabled: true),
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
              style: TextStyle(color: theme.disabledColor, fontSize: 14, fontWeight: FontWeight.w600),
            ),
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