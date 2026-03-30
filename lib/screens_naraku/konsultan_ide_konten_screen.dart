// [RILIS FINAL - KONSULTAN IDE: POLICY COMPLIANT & FIRESTORE LOGIC]
// KATEGORI_POLICY_UPDATE NO_URUT_04
// Lokasi: lib/screens_naraku/konsultan_ide_konten_screen.dart
// TUJUAN:
// 1. [FIX] Menggunakan user.uid untuk mencegah error.
// 2. Menambahkan fitur Lapor (Flag) untuk kepatuhan Google Play.
// 3. UI Bersih (Judul di Card) & Tombol Responsif.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // [WAJIB]

// [IMPORT NAVIGASI MASTER]
import '../screens/input_script_screen.dart';
import '../screens_veo/input_script_veo_screen.dart';
import '../screens/project_dashboard_screen.dart';

// [IMPORT GENERATOR LAIN]
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
import '../providers/config_provider.dart'; // Akses Bahasa
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

    // [BAHASA]
    final currentLocale = ref.watch(appLanguageProvider);
    final isIndo = currentLocale.languageCode == 'id';
    String t(String en, String id) => isIndo ? id : en;

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
              // [FIREBASE LOGIC] Simpan Laporan
              final user = ref.read(firestoreUserProvider).valueOrNull;
              
              // [BUGFIX] Menggunakan .uid bukan .id
              final userId = user?.uid ?? 'anonymous'; 

              FirebaseFirestore.instance.collection('reports').add({
                'content': content, 
                'reason': reasonController.text.isEmpty ? 'No reason provided' : reasonController.text,
                'reportedAt': FieldValue.serverTimestamp(),
                'userId': userId,
                'feature': 'Konsultan Ide Konten', // Penanda fitur
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

  // --- Input Card ---
  Widget _buildInputCard(
    BuildContext context,
    WidgetRef ref,
    KonsultanIdeKontenViewModel viewModel,
    KonsultanIdeKontenState state,
    AsyncValue<AppUser> userState,
    AsyncValue<AppConfig> configState,
    String Function(String, String) t,
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
      buttonLabel = t('Thinking...', 'Sedang Berpikir...');
    } else if (providersAreLoading) {
      buttonLabel = t('Loading...', 'Memuat...');
    } else if (providersHaveError) {
      buttonLabel = "Error";
    } else if (!canAfford) {
      buttonLabel = t('Insufficient Tokens', 'Token Tidak Cukup');
    } else {
      buttonLabel = t('GENERATE IDEAS', 'CARI IDE KONTEN');
    }
    
    final bool isButtonDisabled =
        vmIsLoading || providersAreLoading || providersHaveError || !canAfford;
    
    // [THEME] Warna Tombol: Primary (Deep Purple) atau Disabled
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
            // [JUDUL FITUR DI SINI]
            Text(
              t('Content Idea Consultant', 'Konsultan Ide Konten'),
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  t('Topic / Niche', 'Topik / Niche'),
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
            
            // [ELEGANT BLACK INPUT]
            TextField(
              controller: viewModel.promptController,
              maxLines: 3,
              maxLength: _maxPromptLength,
              enabled: !state.isLoading,
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
              decoration: InputDecoration(
                hintText: t('e.g., Technology, Healthy Diet', 'Cth: Teknologi, Diet Sehat'),
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
                  : const Icon(Icons.lightbulb, size: 20), // Icon Bulb
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
    String Function(String, String) t,
  ) {
    final theme = Theme.of(context);
    final bool hasOutput = state.generatedIdeas.isNotEmpty;

    final Color copyColor = hasOutput ? theme.colorScheme.secondary : theme.disabledColor;
    final Color clearColor = hasOutput ? theme.colorScheme.error : theme.disabledColor;

    String outputContent = hasOutput
        ? state.generatedIdeas
        : t('Ideas will appear here...', 'Ide akan muncul di sini...');

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // [REVISI UI] Header dengan Tombol Lapor (Flag)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  t('Recommended Ideas', 'Ide Rekomendasi'),
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
                color: theme.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.dividerColor),
              ),
              child: state.isLoading
                  ? Center(
                      child: Text(
                          t('Consulting AI...', 'Sedang konsultasi AI...'),
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
                                ClipboardData(text: state.generatedIdeas));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(t('Copied to clipboard!', 'Disalin ke papan klip!')),
                                backgroundColor: Colors.green,
                              ),
                            );
                          },
                    child: Text(t('Copy', 'Salin')),
                  ),
                ),
                const SizedBox(width: 16),
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

  // --- Drawer Master (Themed) ---
  Widget _buildNarakuDrawer(BuildContext context, String Function(String, String) t) {
    final theme = Theme.of(context);

    // Helper Navigasi
    void _navigate(Widget screen) {
      Navigator.pop(context);
      Navigator.of(context).push(MaterialPageRoute(builder: (c) => screen));
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

    return Drawer(
      backgroundColor: theme.scaffoldBackgroundColor,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // [UI DRAWER HEADER RAPI]
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
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          _menuItem(t('Idea Consultant', 'Konsultan Ide Konten'), Icons.lightbulb_outline, () {}, isDisabled: true), // Halaman Ini
          _menuItem(t('General Content', 'Generator Konten Umum'), Icons.rate_review_outlined, () => _navigate(const GeneratorKontenUmumScreen())),
          _menuItem(t('Short Content', 'Generator Konten Short'), Icons.movie_creation_outlined, () => _navigate(const GeneratorKontenShortScreen())),
          _menuItem(t('History Story', 'Generator Kisah Sejarah'), Icons.account_balance_outlined, () => _navigate(const GeneratorKisahSejarahScreen())),
          _menuItem(t('Legend Story', 'Generator Kisah Legenda'), Icons.auto_stories_outlined, () => _navigate(const GeneratorKisahLegendaScreen())),
          _menuItem(t('Islamic Story', 'Generator Kisah Islami'), Icons.mosque_outlined, () => _navigate(const GeneratorKisahIslamiScreen())),
          _menuItem(t('Horror Story', 'Generator Kisah Horor'), Icons.help_outline, () => _navigate(const GeneratorKisahHororScreen())),
          _menuItem(t('Custom Story', 'Generator Kisah Custom'), Icons.theater_comedy_outlined, () => _navigate(const GeneratorKisahCustomScreen())),

          Divider(color: theme.dividerColor, height: 30),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(
              t('Create', 'Buat'),
              style: TextStyle(color: theme.disabledColor, fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),

          ListTile(
            leading: const Icon(Icons.image_search, color: Colors.blueAccent),
            title: const Text('Create Video Motion', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(MaterialPageRoute(builder: (context) => const InputScriptScreen())); 
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

          _menuItem(t('Create Thumbnail', 'Buat Thumbnail'), Icons.aspect_ratio_outlined, () => _navigate(const GeneratorGambarThumbnailScreen())),
        ],
      ),
    );
  }
}