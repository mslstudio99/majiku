//......................................................//
// LIB/SCREENS_NARAKU/T2IMAGE_SCREEN.DART               //
//......................................................//

// No ke-1: IMPORT & SETUP                              //
//......................................................//
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart'; // Untuk delegasi download ke OS

// [IMPORT SERVICE LOGGING USER CENTER]
import '../services/firestore_service.dart';

import '../view_model_naraku/t2image_view_model.dart';
import '../providers/user_provider.dart';
import '../providers/config_provider.dart';
import '../theme/app_theme.dart';
//......................................................//

// No ke-2: STATEFUL WIDGET & INITIALIZATION            //
//......................................................//
class T2ImageScreen extends ConsumerStatefulWidget {
  const T2ImageScreen({super.key});

  @override
  ConsumerState<T2ImageScreen> createState() => _T2ImageScreenState();
}

class _T2ImageScreenState extends ConsumerState<T2ImageScreen> {
  final int _maxPromptLength = 1000;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final viewModel = ref.read(t2ImageViewModelProvider.notifier);
        viewModel.promptController.addListener(() => setState(() {}));

        // --- [LOG AKTIVITAS: KUNJUNGAN OTHER TOOLS -> T2IMAGE] ---
        ref.read(firestoreServiceProvider).logFeatureActivity(
          featureKey: 'other_tools',
          subFeatureKey: 't2image',
          eventType: 'visit',
        );
        // ---------------------------------------------------------
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
  }
//......................................................//

// No ke-3: LOGIC & REPORT FUNCTION                     //
//......................................................//
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
                'contentUrl': imageUrl,
                'contentType': 'image_imagen_vertex', 
                'reason': reasonController.text.isEmpty ? 'No reason provided' : reasonController.text,
                'reportedAt': FieldValue.serverTimestamp(),
                'userId': userId,
                'feature': 'Generator T2Image', 
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
//......................................................//

// No ke-4: MAIN BUILDER & FORM UI                      //
//......................................................//
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(t2ImageViewModelProvider);
    final viewModel = ref.read(t2ImageViewModelProvider.notifier);
    final userAsync = ref.watch(firestoreUserProvider);
    final configAsync = ref.watch(appConfigProvider);
    final currentLocale = ref.watch(appLanguageProvider);
    final isIndo = currentLocale.languageCode == 'id';
    String t(String en, String id) => isIndo ? id : en;

    ref.listen<T2ImageState>(t2ImageViewModelProvider, (previous, next) {
      if (next.errorMessage != null && previous?.errorMessage == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      if (next.successMessage != null && previous?.successMessage == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.successMessage!),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }

      // --- [LOG AKTIVITAS: KONVERSI SUKSES GENERATE T2IMAGE] ---
      if (previous?.isLoading == true && !next.isLoading && next.generatedImageData != null) {
        ref.read(firestoreServiceProvider).logFeatureActivity(
          featureKey: 'other_tools',
          subFeatureKey: 't2image',
          eventType: 'conversion',
        );
      }
      // ---------------------------------------------------------
    });

    final int textLength = viewModel.promptController.text.trim().length;
    final bool hasInput = textLength > 0;
    
    int currentBalance = 0;
    int requiredTokens = 0;
    bool configReady = false;
    bool userReady = false;

    userAsync.whenData((user) {
      currentBalance = user.tokenBalance;
      userReady = true;
    });

    configAsync.whenData((config) {
      requiredTokens = config.costs.t2imageCost;
      configReady = true;
    });

    final bool hasSufficientFunds = currentBalance >= requiredTokens;
    final bool isOutOfTokens = hasInput && !hasSufficientFunds;
    final bool providersLoading = userAsync.isLoading || configAsync.isLoading;
    final bool canSubmit = hasInput && hasSufficientFunds && !state.isLoading && userReady && configReady;

    final List<String> availableStyles = ['Realistic', 'Kartun 3D', 'Kartun 2D', 'Cinematic', 'Digital Art'];
    final String currentStyleSafeguard = availableStyles.contains(state.selectedStyle) 
        ? state.selectedStyle 
        : 'Realistic';

    return Theme(
      data: AppTheme.darkTheme,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('T2Image'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 20.0),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isOutOfTokens ? Colors.redAccent : Colors.white24,
                      width: 1
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.token, 
                        size: 16, 
                        color: isOutOfTokens ? Colors.redAccent : Colors.amber
                      ),
                      const SizedBox(width: 8),
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
                    controller: viewModel.promptController,
                    maxLines: 5,
                    maxLength: _maxPromptLength,
                    enabled: !state.isLoading,
                    decoration: InputDecoration(
                      labelText: t('Image Prompt', 'Prompt Gambar'),
                      hintText: t('A majestic lion wearing a futuristic armor...', 'Seekor singa gagah memakai zirah futuristik...'),
                      alignLabelWithHint: true,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return t('Please enter a prompt for your image.', 'Mohon isi prompt gambar.');
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: currentStyleSafeguard,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: t('Visual Style', 'Gaya Visual'),
                          ),
                          items: availableStyles
                              .map((style) => DropdownMenuItem(
                                    value: style,
                                    child: Text(style, overflow: TextOverflow.ellipsis),
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
                          value: state.selectedRatio,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: t('Aspect Ratio', 'Rasio Aspek'),
                          ),
                          items: const {
                            '16:9': 'Landscape (16:9)',
                            '9:16': 'Portrait (9:16)',
                            '1:1': 'Square (1:1)',
                            '4:3': 'Standard (4:3)',
                          }.entries.map((entry) => DropdownMenuItem(
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
                    onPressed: canSubmit 
                        ? () {
                            if (_formKey.currentState!.validate()) {
                              viewModel.generateImage();
                            }
                          } 
                        : null,
                    icon: state.isLoading || providersLoading
                        ? const SizedBox.shrink()
                        : const Icon(Icons.auto_awesome),
                    label: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: state.isLoading || providersLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 3,
                              ),
                            )
                          : Text(t('GENERATE IMAGE', 'BUAT GAMBAR')),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey[800],
                      disabledForegroundColor: Colors.grey[500],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)
                      )
                    ),
                  ),
                  if (isOutOfTokens)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Center(
                        child: Text(
                          t(
                            "Insufficient balance. You need ${requiredTokens - currentBalance} more tokens.",
                            "Saldo tidak cukup. Anda butuh ${requiredTokens - currentBalance} token lagi."
                          ),
                          style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                        ),
                      ),
                    ),
                  const SizedBox(height: 32),
                  _buildOutputCard(context, ref, viewModel, state, t),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
//......................................................//

// No ke-5: MODERN OUTPUT KARTU                         //
//......................................................//
  Widget _buildOutputCard(
    BuildContext context,
    WidgetRef ref,
    T2ImageViewModel viewModel,
    T2ImageState state,
    String Function(String, String) t,
  ) {
    final theme = Theme.of(context);
    final bool hasImage = state.generatedImageData != null;
    final screenSize = MediaQuery.of(context).size;

    double getAspectRatio(String ratio) {
      try {
        final parts = ratio.split(':');
        if (parts.length == 2) {
          return double.parse(parts[0]) / double.parse(parts[1]);
        }
      } catch (_) {}
      return 1.0; 
    }

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Colors.white10, width: 1),
      ),
      color: const Color(0xFF1A1A2E), 
      elevation: 8,
      shadowColor: Colors.black54,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  t('Generated Image', 'Hasil Gambar'),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                if (state.generatedImageUrl.isNotEmpty)
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
                      colors: [Colors.blue.shade900.withOpacity(0.3), Colors.purple.shade900.withOpacity(0.3)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
                color: state.isLoading ? null : Colors.black,
                border: Border.all(color: state.isLoading ? Colors.blueAccent.withOpacity(0.5) : Colors.white12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: state.isLoading
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            height: 50,
                            width: 50,
                            child: CircularProgressIndicator(color: Colors.cyanAccent, strokeWidth: 3),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            t('AI is painting your vision...', 'AI sedang melukis visimu...'),
                            style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                          ),
                        ],
                      )
                    : hasImage
                        ? Center(
                            child: AspectRatio(
                              aspectRatio: getAspectRatio(state.selectedRatio),
                              child: Image.memory(
                                state.generatedImageData!,
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.high,
                              ),
                            ),
                          )
                        : Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.image_outlined, size: 48, color: Colors.grey.shade800),
                                const SizedBox(height: 16),
                                Text(
                                  t('Your masterpiece will appear here', 'Mahakarya Anda akan muncul di sini'),
                                  style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey.shade600, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
              ),
            ),
            const SizedBox(height: 20),
            
            if (hasImage)
              Column(
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.download_rounded, size: 22),
                    label: Text(
                      t('Download Image', 'Unduh Gambar'),
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
                    onPressed: () async {
                      HapticFeedback.mediumImpact();
                      
                      // [PERBAIKAN] Menggunakan delegasi Native URL Launcher seperti di History
                      if (state.generatedImageUrl.isNotEmpty) {
                        try {
                          final Uri url = Uri.parse(state.generatedImageUrl);
                          if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(t('Could not open download link.', 'Gagal membuka tautan unduhan.')),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                            );
                          }
                        }
                      } else {
                        // Fallback ke ViewModel jika URL kosong tapi bytes ada (failsafe)
                        viewModel.downloadImage();
                      }
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
                            t('Create New Image', 'Buat Gambar Baru'),
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
}
//......................................................//