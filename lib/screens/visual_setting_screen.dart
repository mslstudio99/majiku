// KATEGORI_PENYESUAIAN_TEMA NO_URUT_02
// NAMA FILE: lib/screens/visual_setting_screen.dart
// TUJUAN: Menyesuaikan file agar mematuhi AppTheme "Dark Modern"
// dengan menghapus gaya hardcode yang bertentangan.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

// Import model dan provider
import '../providers/visual_settings_provider.dart'; // Pastikan path ini benar

// --- KATEGORI_REFAKTOR_UI NO_URUT_01: Konversi ke StatefulWidget ---
class VisualSettingScreen extends ConsumerStatefulWidget { // <-- Diubah
  final String projectId;
  const VisualSettingScreen({super.key, required this.projectId});

  // --- Opsi tetap di sini (static const) ---
  static const Map<String, String> _transitionOptions = {
    'Fade': 'fade',
    'Wipe Left': 'wipeleft',
    'Wipe Right': 'wiperight',
    'Wipe Up': 'wipeup',
    'Wipe Down': 'wipedown',
    'Slide Left': 'slideleft',
    'Slide Right': 'slideright',
    'Slide Up': 'slideup',
    'Slide Down': 'slidedown',
  };

  static const Map<String, String> _introMotionOptions = {
    'None': 'none',
    'Zoom In Center': 'zoom_in_center',
    'Zoom Out Center': 'zoom_out_center',
    'Pan Right (Zoom)': 'pan_right',
    'Zoom In Top': 'zoom_in_top',
    'Pan Left (Zoom)': 'pan_left',
    'Zoom In Bottom': 'zoom_in_bottom',
  };

  // --- KATEGORI_MODIFIKASI: Hapus "Option 3" (NO_URUT_01) ---
  static const Map<String, String> _sceneMotionBehaviorOptions = {
    'Default (Sequence)': 'default',
    'Random': 'random',
    // 'Option 3 (Linear 100%)': 'option_3', // <-- MODIFIKASI DIHAPUS
    // 'None': 'none', // Opsional
  };
  // --- AKHIR MODIFIKASI ---

  @override
  ConsumerState<VisualSettingScreen> createState() => _VisualSettingScreenState();
}
// --- KATEGORI_PERBAIKAN_UI: Refaktor Controller ---
class _VisualSettingScreenState extends ConsumerState<VisualSettingScreen> {
  int _openPanelIndex = 0; // State untuk Accordion

  // --- KUNCI PERBAIKAN: Definisikan SEMUA controller di sini ---
  // (Controller ini akan dibuat 1x di initState)
  late TextEditingController _titleTextController;
  late TextEditingController _titleStartTimeController;
  late TextEditingController _titleDurationController;

  late TextEditingController _descTextController;
  late TextEditingController _descStartTimeController;
  late TextEditingController _descDurationController;

  late TextEditingController _transitionDurationController;

  // --- INISIALISASI CONTROLLER ---
  @override
  void initState() {
    super.initState();
    // Baca state AWAL (menggunakan ref.read) untuk mengisi controller
    final initialSettings =
        ref.read(visualSettingsProvider(widget.projectId));

    // Inisialisasi controller Judul
    _titleTextController =
        TextEditingController(text: initialSettings.titleSettings.text);
    _titleStartTimeController = TextEditingController(
        text: initialSettings.titleSettings.startTime.toStringAsFixed(1));
    _titleDurationController = TextEditingController(
        text: initialSettings.titleSettings.duration.toStringAsFixed(1));

    // Inisialisasi controller Deskripsi
    _descTextController =
        TextEditingController(text: initialSettings.descriptionSettings.text);
    _descStartTimeController = TextEditingController(
        text: initialSettings.descriptionSettings.startTime.toStringAsFixed(1));
    _descDurationController = TextEditingController(
        text: initialSettings.descriptionSettings.duration.toStringAsFixed(1));

    // Inisialisasi controller Transisi
    _transitionDurationController = TextEditingController(
        text: initialSettings.transitionDuration.toStringAsFixed(1));
  }

  // --- SINKRONISASI CONTROLLER ---
  // (Jika data berubah dari luar, update controller tanpa kehilangan fokus)
  @override
  void didUpdateWidget(covariant VisualSettingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Cek apakah projectId berubah (seharusnya tidak, tapi ini praktik baik)
    if (oldWidget.projectId != widget.projectId) {
      _syncControllers();
    }
  }

  // Panggil ini saat data eksternal (misal 'Reset') mengubah state
  void _syncControllers() {
    final settings = ref.read(visualSettingsProvider(widget.projectId));

    // Judul
    _tryUpdateController(_titleTextController, settings.titleSettings.text);
    _tryUpdateController(_titleStartTimeController,
        settings.titleSettings.startTime.toStringAsFixed(1));
    _tryUpdateController(_titleDurationController,
        settings.titleSettings.duration.toStringAsFixed(1));

    // Deskripsi
    _tryUpdateController(
        _descTextController, settings.descriptionSettings.text);
    _tryUpdateController(_descStartTimeController,
        settings.descriptionSettings.startTime.toStringAsFixed(1));
    _tryUpdateController(_descDurationController,
        settings.descriptionSettings.duration.toStringAsFixed(1));

    // Transisi
    _tryUpdateController(_transitionDurationController,
        settings.transitionDuration.toStringAsFixed(1));
  }

  // Helper untuk update controller dengan aman
  void _tryUpdateController(TextEditingController controller, String newValue) {
    if (controller.text != newValue) {
      controller.text = newValue;
      // Pindahkan kursor ke akhir
      try {
        controller.selection =
            TextSelection.fromPosition(TextPosition(offset: newValue.length));
      } catch (e) {
        debugPrint("Error setting cursor (aman diabaikan): $e");
      }
    }
  }

  // --- HAPUS CONTROLLER SAAT KELUAR ---
  @override
  void dispose() {
    _titleTextController.dispose();
    _titleStartTimeController.dispose();
    _titleDurationController.dispose();
    _descTextController.dispose();
    _descStartTimeController.dispose();
    _descDurationController.dispose();
    _transitionDurationController.dispose();
    super.dispose();
  }

  // --- METHOD BUILD UTAMA ---
  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(visualSettingsProvider(widget.projectId));
    final settingsNotifier =
        ref.read(visualSettingsProvider(widget.projectId).notifier);

    // --- KUNCI PERBAIKAN: Hapus inisialisasi controller dari sini ---
    // (Kita hanya memastikan sinkronisasi jika state di-reset)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Jika state provider tidak cocok dengan controller (misal: setelah reset)
      if (_transitionDurationController.text !=
          settings.transitionDuration.toStringAsFixed(1)) {
        _syncControllers();
      }
    });

    return Scaffold(
      // KATEGORI_PENYESUAIAN_TEMA: Latar belakang Scaffold
      // kini akan diwarisi dari AppTheme (scaffoldBackgroundColor / Hitam)
      appBar: AppBar(
        // KATEGORI_PENYESUAIAN_TEMA: AppBar
        // kini akan diwarisi dari AppTheme (appBarTheme / appBarBg)
        title: const Text('Visual Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset to Defaults',
            onPressed: () {
              _showResetDialog(context, settingsNotifier);
            },
          ),
          // --- BLOK SAVE (Sudah Diperbaiki) ---
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Save Settings',
            onPressed: () async {
              // --- KATEGORI_PERBAIKAN_BUG (Perbaikan Bug 1: Data-Loss on Save) ---
              // Paksa semua text field untuk melepaskan fokus.
              // Ini memicu 'onEditingComplete' atau 'onTapOutside'
              // sehingga state Riverpod di-update SEBELUM kita menyimpan.
              FocusScope.of(context).unfocus();
              // --- AKHIR PERBAIKAN ---

              final scaffold = ScaffoldMessenger.of(context);
              scaffold.showSnackBar(
                const SnackBar(
                  content: Text('Saving visual settings...'),
                  duration: Duration(seconds: 2),
                ),
              );

              try {
                await settingsNotifier.saveSettingsToFirestore();
                scaffold.hideCurrentSnackBar();
                scaffold.showSnackBar(
                  SnackBar(
                    content: const Text('✅ Settings saved successfully!'),
                    // --- KATEGORI_PENYESUAIAN_TEMA (2) ---
                    // Menggunakan warna Aksen (Emas) dari tema
                    backgroundColor: Theme.of(context).colorScheme.secondary,
                    // backgroundColor: Colors.green,
                    // --- AKHIR PENYESUAIAN_TEMA ---
                    duration: const Duration(seconds: 2),
                  ),
                );
                if (context.mounted) Navigator.pop(context);
              } catch (e) {
                scaffold.hideCurrentSnackBar();
                scaffold.showSnackBar(
                  SnackBar(
                    content: Text('❌ Failed to save settings: $e'),
                    // --- KATEGORI_PENYESUAIAN_TEMA (1) ---
                    // Menggunakan warna Error (MerahAksen) dari tema
                    backgroundColor: Theme.of(context).colorScheme.error,
                    // backgroundColor: Colors.red,
                    // --- AKHIR PENYESUAIAN_TEMA ---
                    duration: const Duration(seconds: 3),
                  ),
                );
                debugPrint('Error while saving settings: $e');
              }
            },
          ),
          // --- AKHIR BLOK SAVE ---
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: ExpansionPanelList.radio(
            // KATEGORI_PENYESUAIAN_TEMA: ExpansionPanel
            // kini akan diwarisi dari AppTheme (cardTheme / cardBg)
            initialOpenPanelValue: _openPanelIndex,
            animationDuration: const Duration(milliseconds: 300),
            elevation: 1, // Sesuai AppTheme (meskipun cardTheme elevation 4)
            expansionCallback: (int index, bool isExpanded) {
              setState(() {
                _openPanelIndex = _openPanelIndex == index ? -1 : index;
              });
            },
            children: [
              // --- Panel 1: Title Settings ---
              ExpansionPanelRadio(
                value: 0,
                headerBuilder: (BuildContext context, bool isExpanded) {
                  return ListTile(
                    title: Text('Title Settings',
                        style: Theme.of(context).textTheme.titleLarge),
                  );
                },
                body: Padding(
                  padding:
                      const EdgeInsets.all(16.0).copyWith(top: 0, bottom: 24),
                  child: _buildSettingsSection(
                    context,
                    settings.titleSettings,
                    // --- KUNCI PERBAIKAN: Berikan controller dari state ---
                    textController: _titleTextController,
                    startTimeController: _titleStartTimeController,
                    durationController: _titleDurationController,
                    // ---
                    onTextChanged: settingsNotifier.updateTitleText,
                    onEffectChanged: settingsNotifier.updateTitleEffect,
                    onBaseFontSizeChanged:
                        settingsNotifier.updateTitleBaseFontSize,
                    onColorChanged: settingsNotifier.updateTitleColor,
                    onStartTimeChanged: settingsNotifier.updateTitleStartTime,
                    onDurationChanged: settingsNotifier.updateTitleDuration,
                    onBlockWidthFactorChanged:
                        settingsNotifier.updateTitleBlockWidthFactor,
                    // --- KATEGORI_FITUR_VALIDASI NO_URUT_03: Terapkan aturan Title ---
                    textMaxLength: 40,
                    textCapitalization: TextCapitalization.characters,
                    textInputFormatters: null,
                    // --- AKHIR FITUR ---
                  ),
                ),
              ),

              // --- Panel 2: Description Settings ---
              ExpansionPanelRadio(
                value: 1,
                headerBuilder: (BuildContext context, bool isExpanded) {
                  return ListTile(
                    title: Text('Description Settings',
                        style: Theme.of(context).textTheme.titleLarge),
                  );
                },
                body: Padding(
                  padding:
                      const EdgeInsets.all(16.0).copyWith(top: 0, bottom: 24),
                  child: _buildSettingsSection(
                    context,
                    settings.descriptionSettings,
                    // --- KUNCI PERBAIKAN: Berikan controller dari state ---
                    textController: _descTextController,
                    startTimeController: _descStartTimeController,
                    durationController: _descDurationController,
                    // ---
                    onTextChanged: settingsNotifier.updateDescriptionText,
                    onEffectChanged: settingsNotifier.updateDescriptionEffect,
                    onBaseFontSizeChanged:
                        settingsNotifier.updateDescriptionBaseFontSize,
                    onColorChanged: settingsNotifier.updateDescriptionColor,
                    onStartTimeChanged:
                        settingsNotifier.updateDescriptionStartTime,
                    onDurationChanged:
                        settingsNotifier.updateDescriptionDuration,
                    onBlockWidthFactorChanged:
                        settingsNotifier.updateDescriptionBlockWidthFactor,
                    // --- KATEGORI_FITUR_VALIDASI NO_URUT_04: Terapkan aturan Description ---
                    textMaxLength: 50,
                    textCapitalization: TextCapitalization.none, // Sesuai 'huruf bebas'
                    textInputFormatters: null,
                    // --- AKHIR FITUR ---
                  ),
                ),
              ),

              // --- Panel 3: Subtitle Settings ---
              ExpansionPanelRadio(
                value: 2,
                headerBuilder: (BuildContext context, bool isExpanded) {
                  return ListTile(
                    title: Text('Subtitle Settings',
                        style: Theme.of(context).textTheme.titleLarge),
                  );
                },
                body: Padding(
                  padding:
                      const EdgeInsets.all(16.0).copyWith(top: 0, bottom: 24),
                  child: Column(
                    children: [
                      SwitchListTile(
                        // KATEGORI_PENYESUAIAN_TEMA: Switch
                        // kini akan diwarisi dari AppTheme (colorScheme.primary)
                        title: const Text('Show Subtitles'),
                        subtitle: const Text(
                            'Display text from each segment as subtitles.'),
                        value: settings.showSubtitles,
                        onChanged: settingsNotifier.updateShowSubtitles,
                        secondary: Icon(settings.showSubtitles
                            ? Icons.subtitles
                            : Icons.subtitles_off),
                        contentPadding: EdgeInsets.zero,
                      ),
                      const SizedBox(height: 16),
                      // Helper ini (buildNumericInput) sudah OK,
                      // karena controllernya bersifat sementara (onEditingComplete)
                      _buildNumericInput(
                        context: context,
                        label: 'Subtitle Base Size',
                        value: settings.subtitleBaseFontSize,
                        onChanged: settingsNotifier.updateSubtitleBaseFontSize,
                      ),
                      const SizedBox(height: 16),
                      _buildFactorInput(
                        context: context,
                        label: 'Subtitle Block Width',
                        value: settings.subtitleBlockWidthFactor,
                        onChanged:
                            settingsNotifier.updateSubtitleBlockWidthFactor,
                      ),
                    ],
                  ),
                ),
              ),

              // --- Panel 4: Transition & Motion Setting ---
              ExpansionPanelRadio(
                value: 3,
                headerBuilder: (BuildContext context, bool isExpanded) {
                  return ListTile(
                    title: Text(
                      'Transition & Motion Setting',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  );
                },
                body: Padding(
                  padding:
                      const EdgeInsets.all(16.0).copyWith(top: 0, bottom: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              // KATEGORI_PENYESUAIAN_TEMA: Dropdown/Input
                              // kini akan diwarisi dari AppTheme (inputDecorationTheme)
                              decoration: const InputDecoration(
                                labelText: 'Transition Type',
                                // border: OutlineInputBorder(), // Diwarisi dari tema
                              ),
                              value: settings.transitionType,
                              items: VisualSettingScreen
                                  ._transitionOptions.entries
                                  .map((entry) {
                                return DropdownMenuItem(
                                  value: entry.value,
                                  child: Text(entry.key),
                                );
                              }).toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  settingsNotifier.updateTransitionType(value);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextField(
                              // --- KUNCI PERBAIKAN: Gunakan controller dari state ---
                              controller: _transitionDurationController,
                              // ---
                              decoration: const InputDecoration(
                                labelText: 'Duration (sec)',
                                // border: OutlineInputBorder(), // Diwarisi dari tema
                                suffixText: 's',
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'^\d+\.?\d{0,1}')),
                              ],
                              onChanged: (value) {
                                final double? seconds = double.tryParse(value);
                                if (seconds != null && seconds > 0) {
                                  settingsNotifier
                                      .updateTransitionDuration(seconds);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Intro Motion Type',
                          // border: OutlineInputBorder(), // Diwarisi dari tema
                          hintText: 'Select motion for the first image',
                        ),
                        value: settings.introMotionType,
                        items: VisualSettingScreen._introMotionOptions.entries
                            .map((entry) {
                          return DropdownMenuItem(
                            value: entry.value,
                            child: Text(entry.key),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            settingsNotifier.updateIntroMotionType(value);
                          }
                        },
                      ),
                      const SizedBox(height: 24),
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Scene Motion Behavior',
                          // border: OutlineInputBorder(), // Diwarisi dari tema
                          hintText: 'Select how motion is applied to scenes',
                        ),
                        value: (settings.sceneMotionBehavior.isNotEmpty)
                            ? settings.sceneMotionBehavior
                            : 'default',
                        items: VisualSettingScreen
                            ._sceneMotionBehaviorOptions.entries
                            .map((entry) {
                          return DropdownMenuItem(
                            value: entry.value,
                            child: Text(entry.key),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            ref
                                .read(visualSettingsProvider(widget.projectId)
                                    .notifier)
                                .updateSceneMotionBehavior(value);
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Current Motion Mode: ${settings.sceneMotionBehavior.isNotEmpty ? settings.sceneMotionBehavior.toUpperCase() : 'DEFAULT'}',
                        // --- KATEGORI_PENYESUAIAN_TEMA (3) ---
                        // Menggunakan bodySmall (textSecondary/Abu-abu) dari tema
                        style: Theme.of(context).textTheme.bodySmall,
                        // style:
                        //     const TextStyle(fontSize: 12, color: Colors.grey),
                        // --- AKHIR PENYESUAIAN_TEMA ---
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- KUNCI PERBAIKAN: Helper _buildSettingsSection dimodifikasi ---
  // (Sekarang menerima controller, tidak lagi membuat sendiri)
  Widget _buildSettingsSection(
    BuildContext context,
    TextOverlaySettings currentSettings, {
    // Controller dari State
    required TextEditingController textController,
    required TextEditingController startTimeController,
    required TextEditingController durationController,
    // Callback Notifier
    required ValueChanged<String> onTextChanged,
    required ValueChanged<TextEffect> onEffectChanged,
    required ValueChanged<double> onBaseFontSizeChanged,
    required ValueChanged<Color> onColorChanged,
    required ValueChanged<double> onStartTimeChanged,
    required ValueChanged<double> onDurationChanged,
    required ValueChanged<double> onBlockWidthFactorChanged,
    // --- KATEGORI_FITUR_VALIDASI NO_URUT_01: Tambah parameter validasi ---
    required int textMaxLength,
    required TextCapitalization textCapitalization,
    List<TextInputFormatter>? textInputFormatters,
    // --- AKHIR FITUR ---
  }) {
    // HAPUS: Logika addPostFrameCallback (sudah ditangani di initState/didUpdateWidget)

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- KATEGORI_FITUR_VALIDASI NO_URUT_02: Terapkan validasi ke TextField ---
        TextField(
          controller: textController, // <-- Gunakan controller dari state
          decoration: const InputDecoration(
            labelText: 'Text',
            // border: OutlineInputBorder(), // Diwarisi dari tema
          ),
          onChanged: onTextChanged, // <-- Ini aman sekarang
          maxLines: 3,
          // Terapkan properti baru
          maxLength: textMaxLength,
          textCapitalization: textCapitalization,
          inputFormatters: textInputFormatters,
          maxLengthEnforcement: MaxLengthEnforcement.enforced,
        ),
        // --- AKHIR FITUR ---
        const SizedBox(height: 16),
        DropdownButtonFormField<TextEffect>(
          decoration: const InputDecoration(
              labelText: 'Effect', 
              // border: OutlineInputBorder() // Diwarisi dari tema
          ),
          value: currentSettings.effect,
          items: TextEffect.values
              .map((effect) => DropdownMenuItem(
                    value: effect,
                    child: Text(textEffectToString(effect)),
                  ))
              .toList(),
          onChanged: (value) {
            if (value != null) onEffectChanged(value);
          },
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: _buildNumericInput(
                context: context,
                label: 'Base Size',
                value: currentSettings.baseFontSize,
                onChanged: onBaseFontSizeChanged,
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Color',
                    style: Theme.of(context).textTheme.bodySmall ??
                        const TextStyle()),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () => _showColorPicker(
                      context, currentSettings.color, onColorChanged),
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: currentSettings.color,
                      // KATEGORI_PENYESUAIAN_TEMA: Gunakan textSecondary
                      // untuk border agar terlihat di mode gelap
                      border: Border.all(color: Theme.of(context).textTheme.bodySmall!.color!),
                      // border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildFactorInput(
          context: context,
          label: 'Block Width',
          value: currentSettings.textBlockWidthFactor,
          onChanged: onBlockWidthFactorChanged,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller:
                    startTimeController, // <-- Gunakan controller dari state
                decoration: const InputDecoration(
                    labelText: 'Start Time (sec)',
                    // border: OutlineInputBorder(), // Diwarisi dari tema
                    suffixText: 's'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}'))
                ],
                onChanged: (value) {
                  final double? seconds = double.tryParse(value);
                  if (seconds != null && seconds >= 0) onStartTimeChanged(seconds);
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                controller:
                    durationController, // <-- Gunakan controller dari state
                decoration: const InputDecoration(
                    labelText: 'Duration (sec)',
                    // border: OutlineInputBorder(), // Diwarisi dari tema
                    suffixText: 's'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}'))
                ],
                onChanged: (value) {
                  final double? seconds = double.tryParse(value);
                  if (seconds != null && seconds > 0) onDurationChanged(seconds);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  // --- HELPER _buildNumericInput (Tidak Berubah) ---
  // (Controller di sini aman karena dibuat ulang saat build,
  // tapi hanya di-submit saat 'onEditingComplete' atau 'onTapOutside')
  Widget _buildNumericInput({
    required BuildContext context,
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    final controller = TextEditingController(text: value.toStringAsFixed(1));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (controller.hasListeners &&
          controller.text == value.toStringAsFixed(1)) {
        try {
          controller.selection = TextSelection.fromPosition(
              TextPosition(offset: controller.text.length));
        } catch (e) {
          debugPrint("Error setting cursor (aman diabaikan): $e");
        }
      }
    });

    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        // border: const OutlineInputBorder(), // Diwarisi dari tema
        suffixText: 'pt',
        prefixIcon: const Icon(Icons.format_size),
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d{1,2}(\.\d{0,1})?$')),
      ],
      onEditingComplete: () {
        final double? parsedValue = double.tryParse(controller.text);
        if (parsedValue != null) {
          onChanged(parsedValue);
        } else {
          controller.text = value.toStringAsFixed(1);
        }
        FocusScope.of(context).unfocus();
      },
      onTapOutside: (_) {
        final double? parsedValue = double.tryParse(controller.text);
        if (parsedValue != null) {
          onChanged(parsedValue);
        } else {
          controller.text = value.toStringAsFixed(1);
        }
        FocusScope.of(context).unfocus();
      },
    );
  }

  // --- HELPER _buildFactorInput (Tidak Berubah) ---
  Widget _buildFactorInput({
    required BuildContext context,
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    final controller = TextEditingController(text: value.toStringAsFixed(2));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (controller.hasListeners &&
          controller.text == value.toStringAsFixed(2)) {
        try {
          controller.selection = TextSelection.fromPosition(
              TextPosition(offset: controller.text.length));
        } catch (e) {
          debugPrint("Error setting cursor (aman diabaikan): $e");
        }
      }
    });

    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        // border: const OutlineInputBorder(), // Diwarisi dari tema
        suffixText: '% (e.g., 0.85)',
        prefixIcon: const Icon(Icons.width_normal),
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^(0\.\d{0,2}|1(\.0{0,2})?)$')),
      ],
      onEditingComplete: () {
        final double? parsedValue = double.tryParse(controller.text);
        if (parsedValue != null) {
          onChanged(parsedValue);
        } else {
          controller.text = value.toStringAsFixed(2);
        }
        FocusScope.of(context).unfocus();
      },
      onTapOutside: (_) {
        final double? parsedValue = double.tryParse(controller.text);
        if (parsedValue != null) {
          onChanged(parsedValue);
        } else {
          controller.text = value.toStringAsFixed(2);
        }
        FocusScope.of(context).unfocus();
      },
    );
  }

  // --- DIALOG PEMILIH WARNA (Tidak Berubah) ---
  void _showColorPicker(
      BuildContext context, Color currentColor, ValueChanged<Color> onColorChanged) {
    showDialog(
      context: context,
      builder: (context) {
        Color pickerColor = currentColor;
        return AlertDialog(
          // KATEGORI_PENYESUAIAN_TEMA: AlertDialog
          // kini akan diwarisi dari AppTheme (cardBg)
          title: const Text('Pick a color'),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: pickerColor,
              onColorChanged: (color) => pickerColor = color,
            ),
          ),
          actions: <Widget>[
            TextButton(
              // KATEGORI_PENYESUAIAN_TEMA: Tombol
              // kini akan diwarisi dari AppTheme (colorScheme.primary)
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Select'),
              onPressed: () {
                onColorChanged(pickerColor);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // --- DIALOG RESET (Tidak Berubah, tapi sekarang aman) ---
  void _showResetDialog(
      BuildContext context, VisualSettingsNotifier notifier) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reset to Defaults?'),
          content: const Text(
              'Are you sure you want to reset all visual settings to their default values? This cannot be undone.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              // --- KATEGORI_PENYESUAIAN_TEMA (4) ---
              // Menggunakan warna Error (MerahAksen) dari tema
              child: Text('RESET', style: TextStyle(color: Theme.of(context).colorScheme.error)),
              // child: const Text('RESET', style: TextStyle(color: Colors.red)),
              // --- AKHIR PENYESUAIAN_TEMA ---
              onPressed: () {
                // Panggil method reset dari notifier
                notifier.resetToDefaults();
                // Sinkronisasi controller akan ditangani oleh 'addPostFrameCallback' di 'build'
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Settings have been reset to default.'),
                    // --- KATEGORI_PENYESUAIAN_TEMA (5) ---
                    // Menggunakan warna Primary (Ungu) dari tema
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    // backgroundColor: Colors.blueAccent,
                    // --- AKHIR PENYESUAIAN_TEMA ---
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
} // --- AKHIR BLOK REFAKTOR (Pagar Penutup yang Benar) ---