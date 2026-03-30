// [RILIS FINAL - KISAH HOROR: POLICY COMPLIANCE & BUGFIX]
// KATEGORI_POLICY_UPDATE NO_URUT_01
// Lokasi: lib/screens_naraku/generator_kisah_horor_screen.dart
// TUJUAN:
// 1. [POLICY] Menambahkan fitur Lapor Konten (Flag) terintegrasi Firestore.
// 2. [CRITICAL] Menggunakan user.uid untuk identifikasi pelapor.
// 3. [MAINTENANCE] Mempertahankan UI Text-Only yang sudah responsif.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // [WAJIB] Untuk lapor konten

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
import './generator_kisah_custom_screen.dart';
import './generator_gambar_thumbnail_screen.dart';
import './generator_konten_short_screen.dart';

// [IMPORT VM & MODELS]
import '../view_model_naraku/generator_kisah_horor_view_model.dart';
import '../providers/user_provider.dart';
import '../providers/config_provider.dart'; // Akses Bahasa
import '../models/app_user.dart';
import '../models/app_config.dart';

class GeneratorKisahHororScreen extends ConsumerWidget {
  const GeneratorKisahHororScreen({super.key});

  final int _maxPromptLength = 200;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // [STATE & LOGIC]
    final state = ref.watch(generatorKisahHororViewModelProvider);
    final viewModel = ref.read(generatorKisahHororViewModelProvider.notifier);
    final AsyncValue<AppUser> userState = ref.watch(firestoreUserProvider);
    final AsyncValue<AppConfig> configState = ref.watch(appConfigProvider);

    // [BAHASA]
    final currentLocale = ref.watch(appLanguageProvider);
    final isIndo = currentLocale.languageCode == 'id';
    String t(String en, String id) => isIndo ? id : en;

    // [THEME SHORTCUT]
    final theme = Theme.of(context);

    // [LISTENER ERROR]
    ref.listen<GeneratorKisahHororState>(generatorKisahHororViewModelProvider,
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
        // [UI BERSIH] Judul dihapus di AppBar
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

  // --- [LOGIC REAL] LAPOR KONTEN KE FIRESTORE ---
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
              // [FIREBASE LOGIC FIX] Gunakan .uid bukan .id
              final user = ref.read(firestoreUserProvider).valueOrNull;
              final userId = user?.uid ?? 'anonymous'; // <-- SUDAH DIPERBAIKI

              FirebaseFirestore.instance.collection('reports').add({
                'content': content,
                'reason': reasonController.text.isEmpty ? 'No reason provided' : reasonController.text,
                'reportedAt': FieldValue.serverTimestamp(),
                'userId': userId,
                'feature': 'Generator Kisah Horor', 
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

  // --- Helper Kartu Input ---
  Widget _buildInputCard(
    BuildContext context,
    WidgetRef ref,
    GeneratorKisahHororViewModel viewModel,
    GeneratorKisahHororState state,
    AsyncValue<AppUser> userState,
    AsyncValue<AppConfig> configState,
    String Function(String, String) t,
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
    final int actionCost = configState.valueOrNull?.costs.kisahHororPerClick ??
        Costs.fallback().kisahHororPerClick;
    final bool canAfford = currentBalance >= actionCost;

    final String buttonLabel;
    if (vmIsLoading) {
      buttonLabel = t('Summoning Horror...', 'Memanggil Horor...');
    } else if (providersAreLoading) {
      buttonLabel = t('Loading...', 'Memuat...');
    } else if (providersHaveError) {
      buttonLabel = "Error";
    } else if (!canAfford) {
      buttonLabel = t('Insufficient Tokens', 'Token Tidak Cukup');
    } else {
      buttonLabel = t('GENERATE HORROR', 'BUAT KISAH HOROR');
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
            // [JUDUL FITUR DI SINI]
            Text(
              t('Horror Story Generator', 'Generator Kisah Horor'),
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  t('Topic / Ghost Type', 'Topik / Jenis Hantu'),
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
              // Style teks mengikuti theme
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
              decoration: InputDecoration(
                hintText: t('e.g., The haunted old house', 'Cth: Rumah tua yang angker'),
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
              t('Language will be auto-detected from your input.', 'Bahasa akan dideteksi otomatis dari input Anda.'),
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
              // [MAINTENANCE] Tetap tanpa argumen sesuai fix sebelumnya
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
    GeneratorKisahHororViewModel viewModel,
    GeneratorKisahHororState state,
    String Function(String, String) t,
  ) {
    final theme = Theme.of(context);
    final bool hasOutput = state.generatedStory.isNotEmpty;
    
    // [THEME] Warna Aksi
    final Color copyColor = hasOutput ? theme.colorScheme.secondary : theme.disabledColor;
    final Color clearColor = hasOutput ? theme.colorScheme.error : theme.disabledColor;

    String outputContent = hasOutput
        ? state.generatedStory
        : t('Result will appear here...', 'Hasil akan muncul di sini...');

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // [UI FIX] Header Row dengan Tombol Flag
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  t('Generated Horror', 'Kisah Hasil Generasi'),
                  style: theme.textTheme.headlineSmall,
                ),
                // Tombol Lapor (Hanya muncul jika ada konten)
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
                // Warna Box Output Hitam (Scaffold BG)
                color: theme.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.dividerColor),
              ),
              child: state.isLoading
                  ? Center(
                      child: Text(
                          t('Summoning spirits...', 'Memanggil arwah...'),
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
                // 1. TOMBOL COPY (Text Only)
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
                const SizedBox(width: 8), // Spasi diperkecil (16 -> 8)
                
                // 2. TOMBOL SEND (Text Only)
                _buildSendToProjectButton(context, state, t),

                const SizedBox(width: 8),
                
                // 3. TOMBOL CLEAR (Text Only)
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
                    onPressed: !hasOutput ? null : viewModel.clearAll,
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

  // --- Helper: Parsing Hasil Narasi Kasar ---
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

  // --- Helper: Dropdown Tombol Send (Themed - Text Only) ---
  Widget _buildSendToProjectButton(
      BuildContext context, GeneratorKisahHororState state, String Function(String, String) t) {
    
    final theme = Theme.of(context);
    final bool hasOutput = state.generatedStory.isNotEmpty;

    // Jika Kosong: Tombol Disabled (Text Only)
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
        t('Horror Story', 'Kisah Horor')
    );
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
            // Padding Horizontal dikurangi (12)
            contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
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
          // Hint: Center Text (No Icon)
          hint: Center(
            child: Text(
              t('Send', 'Kirim'), 
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
            )
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
              Center(
                child: Text(
                  t('Send', 'Kirim'), 
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
                ),
              ),
              Center(
                child: Text(
                  t('Send', 'Kirim'), 
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
                ),
              ),
             ];
          },
        ),
      ),
    );
  }

  // --- Drawer (Dark Modern - Layout Fix) ---
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
          _menuItem(t('Horror Story', 'Generator Kisah Horor'), Icons.help_outline, () {}, isDisabled: true), // Halaman Ini
          _menuItem(t('Custom Story', 'Generator Kisah Custom'), Icons.theater_comedy_outlined, () => _navigate(const GeneratorKisahCustomScreen())),
          
          Divider(color: theme.dividerColor, height: 30),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0), 
            child: Text(
              t('Create', 'Buat'), 
              style: TextStyle(color: theme.disabledColor, fontSize: 14, fontWeight: FontWeight.w600)
            )
          ),
          
          ListTile(
            leading: const Icon(Icons.image_search, color: Colors.blueAccent),
            title: const Text('Create Video Motion', style: TextStyle(color: Colors.white)),
            onTap: () => _navigate(const InputScriptScreen()),
          ),
          ListTile(
            leading: Icon(Icons.movie_filter, color: theme.primaryColor),
            title: const Text('Create Video Footage', style: TextStyle(color: Colors.white)),
            onTap: () => _navigate(InputScriptVeoScreen()),
          ),
          
          _menuItem(t('Create Thumbnail', 'Buat Thumbnail'), Icons.aspect_ratio_outlined, () => _navigate(const GeneratorGambarThumbnailScreen())),
        ],
      ),
    );
  }
}