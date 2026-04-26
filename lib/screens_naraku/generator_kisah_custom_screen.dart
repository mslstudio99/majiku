//................................................................//
// NAMA FILE: GENERATOR_KISAH_CUSTOM_SCREEN.DART                  //
// DIREKTORI: LIB/SCREENS_NARAKU/GENERATOR_KISAH_CUSTOM_SCREEN.DART//
//................................................................//

//No ke-1.........................................................//
//IMPORT MODULE & DEPENDENCIES                                    //
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 

import '../screens/input_script_screen.dart'; // VMotion
import '../screens_veo/input_script_veo_screen.dart'; // VFootage
import '../screens_storinema/input_script_storinema_screen.dart'; // [BARU] Storinema
import '../screens_naracinema_plus/input_script_naracinema_plus_screen.dart'; // [BARU] NaraCinema Plus
import '../screens/project_dashboard_screen.dart';

import './konsultan_ide_konten_screen.dart';
import './generator_kisah_sejarah_screen.dart';
import './generator_konten_umum_screen.dart';
import './generator_kisah_legenda_screen.dart';
import './generator_kisah_islami_screen.dart';
import './generator_kisah_horor_screen.dart';
import './generator_gambar_thumbnail_screen.dart';
import './generator_konten_short_screen.dart';

import '../view_model_naraku/generator_kisah_custom_view_model.dart';
import '../providers/user_provider.dart';
import '../providers/config_provider.dart'; 
import '../models/app_user.dart';
import '../models/app_config.dart';
//................................................................//

//No ke-2.........................................................//
//MAIN CLASS DECLARATION                                          //
class GeneratorKisahCustomScreen extends ConsumerWidget {
  const GeneratorKisahCustomScreen({super.key});

  final int _maxPromptLength = 200;
//................................................................//

//No ke-3.........................................................//
//MAIN BUILD METHOD & SCAFFOLD                                    //
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(generatorKisahCustomViewModelProvider);
    final viewModel = ref.read(generatorKisahCustomViewModelProvider.notifier);
    final AsyncValue<AppUser> userState = ref.watch(firestoreUserProvider);
    final AsyncValue<AppConfig> configState = ref.watch(appConfigProvider);

    final currentLocale = ref.watch(appLanguageProvider);
    final isIndo = currentLocale.languageCode == 'id';
    String t(String en, String id) => isIndo ? id : en;

    final theme = Theme.of(context);

    ref.listen<GeneratorKisahCustomState>(generatorKisahCustomViewModelProvider,
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
  void _showReportDialog(BuildContext context, WidgetRef ref, String content) {
    final TextEditingController reasonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Lapor Konten / Report"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Bantu kami menjaga keamanan. Mengapa konten ini tidak pantas?",
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: "Alasan (SARA, Kekerasan, dll)...",
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
                'content': content,
                'reason': reasonController.text.isEmpty ? 'No reason provided' : reasonController.text,
                'reportedAt': FieldValue.serverTimestamp(),
                'userId': userId,
                'feature': 'Generator Kisah Custom', 
              }).then((_) {
                if (context.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Laporan berhasil dikirim. Terima kasih."),
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
//UI HELPERS (INPUT, AI TOGGLES, STYLES & OUTPUT CARD)            //
  Widget _buildInputCard(
    BuildContext context,
    WidgetRef ref,
    GeneratorKisahCustomViewModel viewModel,
    GeneratorKisahCustomState state,
    AsyncValue<AppUser> userState,
    AsyncValue<AppConfig> configState,
    String Function(String, String) t,
  ) {
    final theme = Theme.of(context);
    final bool vmIsLoading = state.isLoading;
    final bool providersAreLoading = userState.isLoading || configState.isLoading;
    final bool providersHaveError = userState.hasError || configState.hasError;
    final int currentBalance = userState.valueOrNull?.tokenBalance ?? 0;
    final int actionCost = configState.valueOrNull?.costs.kisahCustomPerClick ??
        Costs.fallback().kisahCustomPerClick;
    final bool canAfford = currentBalance >= actionCost;

    final String buttonLabel;
    if (vmIsLoading) {
      buttonLabel = t('Crafting Story...', 'Merangkai Cerita...');
    } else if (providersAreLoading) {
      buttonLabel = t('Loading...', 'Memuat...');
    } else if (providersHaveError) {
      buttonLabel = "Error";
    } else if (!canAfford) {
      buttonLabel = t('Insufficient Tokens', 'Token Tidak Cukup');
    } else {
      buttonLabel = t('GENERATE STORY', 'BUAT KISAH CUSTOM');
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
              t('Custom Story Generator', 'Generator Kisah Custom'),
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            
            Text(
              t('Step 1: The Core', 'Langkah 1: Inti Cerita'),
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.secondary),
            ),
            const SizedBox(height: 12),

            _buildTextField(
              context,
              label: t('Story Title', 'Judul Cerita'),
              hint: t('e.g., The Last Guardian', 'Cth: Sang Penjaga Terakhir'),
              controller: viewModel.judulController,
              maxLength: _maxPromptLength,
              isEnabled: !state.isLoading,
              hintText: t('Language will be auto-detected from your input.', 'Bahasa akan dideteksi otomatis.'),
              t: t,
            ),
            const SizedBox(height: 16),
            
            _buildGenreDropdown(context, viewModel, state, t),
            const SizedBox(height: 16),
            
            _buildAiAssistedField(
              context,
              label: t('Premise / Plot Idea', 'Premis / Ide Plot'),
              hint: t('e.g., A robot discovers emotions...', 'Cth: Robot yang menemukan emosi...'),
              controller: viewModel.premisController,
              maxLength: _maxPromptLength,
              isAiMode: state.isPremisAi,
              isEnabled: !state.isLoading,
              onAiToggle: () => viewModel.toggleAiAssist('premis'),
              t: t,
            ),
            const SizedBox(height: 24),
            
            Text(
              t('Step 2: The Details', 'Langkah 2: Detail Cerita'),
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.secondary),
            ),
            const SizedBox(height: 12),
            
            _buildAiAssistedField(
              context,
              label: t('Characters', 'Karakter'),
              hint: t('e.g., Sarah (Brave), John (Wise)', 'Cth: Sarah (Pemberani), Budi (Bijak)'),
              controller: viewModel.karakterController,
              maxLength: _maxPromptLength,
              isAiMode: state.isKarakterAi,
              isEnabled: !state.isLoading,
              onAiToggle: () => viewModel.toggleAiAssist('karakter'),
              t: t,
            ),
            const SizedBox(height: 16),
            
            _buildAiAssistedField(
              context,
              label: t('Setting / World', 'Latar / Dunia'),
              hint: t('e.g., Cyberpunk City, year 2077', 'Cth: Kota Cyberpunk, tahun 2077'),
              controller: viewModel.settingController,
              maxLength: _maxPromptLength,
              isAiMode: state.isSettingAi,
              isEnabled: !state.isLoading,
              onAiToggle: () => viewModel.toggleAiAssist('setting'),
              t: t,
            ),
            const SizedBox(height: 24),
            
            Text(
              t('Step 3: The Style', 'Langkah 3: Gaya Bahasa'),
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.secondary),
            ),
            const SizedBox(height: 12),
            
            _buildStyleSelector(context, viewModel, state, t),
            const SizedBox(height: 24),
            
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

  Widget _buildTextField(BuildContext context,
      {required String label,
      required String hint,
      required TextEditingController controller,
      required int maxLength,
      required bool isEnabled,
      String? hintText,
      required String Function(String, String) t}) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 10),
        TextField(
          controller: controller,
          maxLines: 1,
          maxLength: maxLength,
          enabled: isEnabled,
          style: theme.textTheme.bodyLarge,
          decoration: InputDecoration(
            hintText: hint,
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
        if (hintText != null) ...[
          const SizedBox(height: 8),
          Text(hintText, style: theme.textTheme.bodySmall)
        ]
      ],
    );
  }

  Widget _buildAiAssistedField(BuildContext context,
      {required String label,
      required String hint,
      required TextEditingController controller,
      required int maxLength,
      required bool isAiMode,
      required bool isEnabled,
      required VoidCallback onAiToggle,
      required String Function(String, String) t}) {
    
    final theme = Theme.of(context);
    final String currentHint = isAiMode
        ? t('AI will decide based on context...', 'AI akan menentukan berdasarkan konteks...')
        : hint;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: theme.textTheme.bodyMedium),
            TextButton(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                backgroundColor: isAiMode
                    ? theme.primaryColor.withOpacity(0.3)
                    : Colors.transparent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                        color: isAiMode
                            ? theme.primaryColor
                            : theme.disabledColor)),
              ),
              onPressed: isEnabled ? onAiToggle : null,
              child: Text(
                isAiMode
                    ? t('AI ACTIVE', 'AI AKTIF')
                    : t('Let AI Decide', 'Biarkan AI Menentukan'),
                style: TextStyle(
                  color: isAiMode
                      ? theme.colorScheme.secondary
                      : theme.disabledColor,
                  fontSize: 12,
                ),
              ),
            )
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: controller,
          maxLines: 3,
          maxLength: maxLength,
          enabled: isEnabled,
          readOnly: isAiMode,
          style: TextStyle(
              color: isAiMode
                  ? theme.disabledColor
                  : theme.textTheme.bodyLarge?.color),
          decoration: InputDecoration(
            hintText: currentHint,
            fillColor: isAiMode
                ? theme.cardTheme.color
                : theme.scaffoldBackgroundColor,
            filled: true,
            counterText: '',
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: theme.colorScheme.secondary),
            ),
          ),
        )
      ],
    );
  }

  Widget _buildGenreDropdown(BuildContext context,
      GeneratorKisahCustomViewModel viewModel, GeneratorKisahCustomState state, String Function(String, String) t) {
    final theme = Theme.of(context);
    
    final List<Map<String, String>> genres = [
      {'key': 'Fantasi', 'name': t('Fantasy', 'Fantasi')},
      {'key': 'Scifi', 'name': t('Sci-Fi', 'Fiksi Ilmiah')},
      {'key': 'Thriller', 'name': t('Thriller', 'Thriller')},
      {'key': 'Romansa', 'name': t('Romance', 'Romansa')},
      {'key': 'Horor', 'name': t('Horror', 'Horor')},
      {'key': 'Misteri', 'name': t('Mystery', 'Misteri')},
      {'key': 'Drama', 'name': t('Drama', 'Drama')},
      {'key': 'Petualangan', 'name': t('Adventure', 'Petualangan')}
    ];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t('Genre', 'Genre'),
            style: theme.textTheme.bodyMedium),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: state.selectedGenre.isEmpty ? null : state.selectedGenre,
          hint: Text(t('Select Genre', 'Pilih Genre'),
              style: TextStyle(color: theme.hintColor)),
          dropdownColor: theme.cardTheme.color,
          style: theme.textTheme.bodyLarge,
          decoration: InputDecoration(
              fillColor: theme.scaffoldBackgroundColor, 
              filled: true,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none)),
          isExpanded: true,
          items: genres
              .map((genre) => DropdownMenuItem<String>(
                  value: genre['key']!,
                  child: Text(genre['name']!, overflow: TextOverflow.ellipsis)))
              .toList(),
          onChanged:
              state.isLoading ? null : (value) => viewModel.setGenre(value),
        )
      ],
    );
  }

  Widget _buildStyleSelector(BuildContext context,
      GeneratorKisahCustomViewModel viewModel, GeneratorKisahCustomState state, String Function(String, String) t) {
    final theme = Theme.of(context);
    
    final List<Map<String, String>> styles = [
      {'key': 'Legenda', 'icon': '📜', 'name': t('Legendary', 'Legenda Klasik')},
      {'key': 'Puitis', 'icon': '✒️', 'name': t('Poetic', 'Puitis')},
      {'key': 'Modern', 'icon': '🏙️', 'name': t('Modern', 'Modern')},
      {'key': 'Gaul', 'icon': '😎', 'name': t('Slang / Casual', 'Bahasa Gaul')}
    ];
    
    return DropdownButtonFormField<String>(
        value: state.selectedStyle,
        dropdownColor: theme.cardTheme.color,
        style: theme.textTheme.bodyLarge,
        decoration: InputDecoration(
            labelText: t('Narrative Style', 'Gaya Penceritaan'),
            fillColor: theme.scaffoldBackgroundColor, 
            filled: true,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none)),
        isExpanded: true,
        items: styles
            .map((style) => DropdownMenuItem<String>(
                value: style['key']!,
                child: Row(children: [
                  Text(style['icon']!, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 12),
                  Text(style['name']!)
                ])))
            .toList(),
        onChanged:
            state.isLoading ? null : (value) => viewModel.setStyle(value));
  }

  Widget _buildOutputCard(
    BuildContext context,
    WidgetRef ref,
    GeneratorKisahCustomViewModel viewModel,
    GeneratorKisahCustomState state,
    String Function(String, String) t,
  ) {
    final theme = Theme.of(context);
    final bool hasOutput = state.generatedStory.isNotEmpty;
    
    final Color copyColor = hasOutput ? theme.colorScheme.secondary : theme.disabledColor;
    
    final bool canClear = hasOutput || viewModel.judulController.text.isNotEmpty;
    final Color clearColor = canClear ? theme.colorScheme.error : theme.disabledColor;

    final String outputContent = hasOutput
        ? state.generatedStory
        : t('Result will appear here...', 'Hasil akan muncul di sini...');

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
                  t('Generated Story', 'Kisah Hasil Generasi'),
                  style: theme.textTheme.headlineSmall,
                ),
                if (hasOutput)
                  IconButton(
                    icon: const Icon(Icons.flag_outlined, color: Colors.redAccent),
                    tooltip: t('Report offensive content', 'Laporkan konten'),
                    onPressed: () => _showReportDialog(context, ref, outputContent),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            
            Container(
              padding: const EdgeInsets.all(16),
              constraints: const BoxConstraints(minHeight: 150),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.dividerColor),
              ),
              child: state.isLoading
                  ? Center(
                      child: Text(
                          t('Weaving destiny...', 'Merajut takdir...'),
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
                  child: OutlinedButton(
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
                                    t('Copied to clipboard!', 'Disalin ke papan klip!')),
                                backgroundColor: Colors.green,
                              ),
                            );
                          },
                    child: Text(t('Copy', 'Salin')),
                  ),
                ),
                const SizedBox(width: 8), 

                _buildSendToProjectButton(context, state, t),

                const SizedBox(width: 8),
                
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      foregroundColor: clearColor,
                      side: BorderSide(color: clearColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    onPressed: (!canClear) ? null : viewModel.clearAll,
                    child: Text(t('Clear', 'Hapus')),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Map<String, String> _parseGeneratedContent(String rawContent, String defaultTitle) {
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
    
    if (rawTitle.isEmpty && script.isNotEmpty) rawTitle = defaultTitle;
    else if (rawTitle.isEmpty && script.isEmpty) return {'title': '', 'script': ''};
    
    String cleanedScript = script.replaceAll(RegExp(r'\n\s*\n', multiLine: true), '\n\n').trim();
    return {'title': rawTitle, 'script': cleanedScript};
  }
//................................................................//

//No ke-6.........................................................//
//POPUP MENU SEND TO PROJECT (UPDATED LOGIC)                      //
  Widget _buildSendToProjectButton(
      BuildContext context, GeneratorKisahCustomState state, String Function(String, String) t) {
    
    final theme = Theme.of(context);
    final bool hasOutput = state.generatedStory.isNotEmpty;

    if (!hasOutput) {
      return Expanded(
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
            foregroundColor: theme.disabledColor,
            side: BorderSide(color: theme.disabledColor),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
          onPressed: null,
          child: Text(t('Send', 'Kirim')),
        ),
      );
    }
    
    final Map<String, String> parsedData = _parseGeneratedContent(
        state.generatedStory,
        t('Custom Story', 'Kisah Custom')
    );
    final String cleanTitle = parsedData['title']!;
    final String cleanScript = parsedData['script']!;

    return Expanded(
      child: Material(
        color: theme.primaryColor,
        borderRadius: BorderRadius.circular(30),
        child: PopupMenuButton<String>(
          offset: const Offset(40, -210), // Disesuaikan lebih tinggi untuk 4 opsi
          elevation: 6,
          color: theme.cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          onSelected: (String value) {
            Widget targetScreen;
            
            // Logika Penentuan Layar Tujuan (4 Opsi)
            if (value == 'storinema') {
              targetScreen = InputScriptStorinemaScreen(initialTitle: cleanTitle, initialScript: cleanScript);
            } else if (value == 'naracinema_plus') {
              targetScreen = InputScriptNaracinemaPlusScreen(initialTitle: cleanTitle, initialScript: cleanScript);
            } else if (value == 'motion') {
              targetScreen = InputScriptScreen(initialTitle: cleanTitle, initialScript: cleanScript);
            } else {
              targetScreen = InputScriptVeoScreen(initialTitle: cleanTitle, initialScript: cleanScript);
            }

            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => targetScreen),
            );
          },
          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
            const PopupMenuItem<String>(
              value: 'storinema',
              child: Text('Auto NaraCinema', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.redAccent)),
            ),
            const PopupMenuItem<String>(
              value: 'naracinema_plus',
              child: Text('Auto NaraCinema Plus', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.lightBlueAccent)),
            ),
            const PopupMenuItem<String>(
              value: 'motion',
              child: Text('Auto NaraMotion', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.yellowAccent)),
            ),
            const PopupMenuItem<String>(
              value: 'veo',
              child: Text('Auto Movie', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.pinkAccent)),
            ),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            alignment: Alignment.center,
            child: Text(
              t('Send', 'Kirim'),
              style: const TextStyle(
                color: Colors.white, 
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }
//................................................................//

//No ke-7.........................................................//
//DRAWER BUILDER (UPDATED LOGIC)                                  //
  Widget _buildNarakuDrawer(BuildContext context, String Function(String, String) t) {
    final theme = Theme.of(context);

    void _navigate(Widget screen) {
      Navigator.pop(context);
      Navigator.of(context).push(MaterialPageRoute(builder: (c) => screen));
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
                  Text(
                  t('Product List', 'Daftar Produk'),
                  style: const TextStyle(
                    color: Colors.white, 
                    fontSize: 22, 
                    fontWeight: FontWeight.bold
                  ),
                ),
              ],
            ),
          ),
          
          _menuItem(t('Idea Consultant', 'Konsultan Ide Konten'), Icons.lightbulb_outline, () => _navigate(const KonsultanIdeKontenScreen())),
          _menuItem(t('General Content', 'Generator Konten Umum'), Icons.rate_review_outlined, () => _navigate(const GeneratorKontenUmumScreen())),
          _menuItem(t('Short Content', 'Generator Konten Short'), Icons.movie_creation_outlined, () => _navigate(const GeneratorKontenShortScreen())),
          _menuItem(t('History Story', 'Generator Kisah Sejarah'), Icons.account_balance_outlined, () => _navigate(const GeneratorKisahSejarahScreen())),
          _menuItem(t('Legend Story', 'Generator Kisah Legenda'), Icons.auto_stories_outlined, () => _navigate(const GeneratorKisahLegendaScreen())),
          _menuItem(t('Islamic Story', 'Generator Kisah Islami'), Icons.mosque_outlined, () => _navigate(const GeneratorKisahIslamiScreen())),
          _menuItem(t('Horror Story', 'Generator Kisah Horor'), Icons.help_outline, () => _navigate(const GeneratorKisahHororScreen())),
          _menuItem(t('Custom Story', 'Generator Kisah Custom'), Icons.theater_comedy_outlined, () {}, isDisabled: true),
          
          Divider(color: theme.dividerColor, height: 30),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0), 
            child: Text(
              t('Create', 'Buat'), 
              style: TextStyle(color: theme.disabledColor, fontSize: 14, fontWeight: FontWeight.w600)
            )
          ),
          
          // --- [SUNTIKAN PEMBARUAN 4 APLIKASI (MENGGUNAKAN _navigate)] ---
          ListTile(
            leading: const Icon(Icons.movie_creation, color: Colors.redAccent),
            title: const Text('Auto NaraCinema', style: TextStyle(color: Colors.white)),
            onTap: () => _navigate(InputScriptStorinemaScreen()),
          ),
          ListTile(
            leading: const Icon(Icons.slow_motion_video, color: Colors.lightBlueAccent), // Ikon Biru Langit
            title: const Text('Auto NaraCinema Plus', style: TextStyle(color: Colors.white)),
            onTap: () => _navigate(InputScriptNaracinemaPlusScreen()),
          ),
          ListTile(
            leading: const Icon(Icons.image_search, color: Colors.yellowAccent),
            title: const Text('Auto NaraMotion', style: TextStyle(color: Colors.white)),
            onTap: () => _navigate(InputScriptScreen()),
          ),
          ListTile(
            leading: const Icon(Icons.movie_filter, color: Colors.pinkAccent),
            title: const Text('Auto Movie', style: TextStyle(color: Colors.white)),
            onTap: () => _navigate(InputScriptVeoScreen()),
          ),
          // ---------------------------------------------------------------
          
          _menuItem(t('Create Thumbnail', 'Buat Thumbnail'), Icons.aspect_ratio_outlined, () => _navigate(const GeneratorGambarThumbnailScreen())),
        ],
      ),
    );
  }
}
//................................................................//