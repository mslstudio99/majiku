// NAMA FILE: lib/screens_veo/visual_setting_veo_screen.dart
// TUJUAN: Versi "Isolasi Total" (Veo) - HANYA Menyimpan Overlay (Title & Description).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

// --- KATEGORI_ISOLASI_VEO (Aturan #1 & #2): Path Impor Disesuaikan ---
import '../providers_veo/visual_settings_veo_provider.dart';
// --- AKHIR ISOLASI VEO ---

// --- KATEGORI_REFAKTOR_UI NO_URUT_01: Konversi ke StatefulWidget ---
// --- KATEGORI_ISOLASI_VEO (Aturan #3): Nama Class Disesuaikan ---
class VisualSettingVeoScreen extends ConsumerStatefulWidget {
// --- AKHIR ISOLASI VEO ---
  final String projectId;
  // --- KATEGORI_ISOLASI_VEO (Aturan #3): Nama Class Disesuaikan ---
  const VisualSettingVeoScreen({super.key, required this.projectId});
  // --- AKHIR ISOLASI VEO ---

  // --- KATEGORI_PENYESUAIAN_VEO (NO_URUT_01): Hapus Opsi Motion & Transisi ---
  // (Semua static const Maps DIHAPUS)
  // --- AKHIR PENYESUAIAN VEO ---

  @override
  // --- KATEGORI_ISOLASI_VEO (Aturan #3): Nama Class Disesuaikan ---
  ConsumerState<VisualSettingVeoScreen> createState() => _VisualSettingVeoScreenState();
}
// --- KATEGORI_PERBAIKAN_UI: Refaktor Controller ---
class _VisualSettingVeoScreenState extends ConsumerState<VisualSettingVeoScreen> {
// --- AKHIR ISOLASI VEO ---
  int _openPanelIndex = 0; // State untuk Accordion

  // --- KUNCI PERBAIKAN: Definisikan SEMUA controller di sini ---
  late TextEditingController _titleTextController;
  late TextEditingController _titleStartTimeController;
  late TextEditingController _titleDurationController;

  late TextEditingController _descTextController;
  late TextEditingController _descStartTimeController;
  late TextEditingController _descDurationController;

  // --- KATEGORI_PENYESUAIAN_VEO (NO_URUT_02): Hapus Controller Transisi ---
  // (Hapus _transitionDurationController)
  // --- AKHIR PENYESUAIAN VEO ---

  // --- INISIALISASI CONTROLLER ---
  @override
  void initState() {
    super.initState();
    // Baca state AWAL (menggunakan ref.read) untuk mengisi controller
    // --- KATEGORI_ISOLASI_VEO (Aturan #3): Ref Provider Disesuaikan ---
    final initialSettings =
        ref.read(visualSettingsVeoProvider(widget.projectId));
    // --- AKHIR ISOLASI VEO ---

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

    // --- KATEGORI_PENYESUAIAN_VEO (NO_URUT_03): Hapus Controller Transisi ---
    // --- AKHIR PENYESUAIAN VEO ---
  }

  // --- SINKRONISASI CONTROLLER ---
  @override
  // --- KATEGORI_ISOLASI_VEO (Aturan #3): Nama Class Disesuaikan ---
  void didUpdateWidget(covariant VisualSettingVeoScreen oldWidget) {
  // --- AKHIR ISOLASI VEO ---
    super.didUpdateWidget(oldWidget);
    // Cek apakah projectId berubah (seharusnya tidak, tapi ini praktik baik)
    if (oldWidget.projectId != widget.projectId) {
      _syncControllers();
    }
  }

  // Panggil ini saat data eksternal (misal 'Reset') mengubah state
  void _syncControllers() {
    // --- KATEGORI_ISOLASI_VEO (Aturan #3): Ref Provider Disesuaikan ---
    final settings = ref.read(visualSettingsVeoProvider(widget.projectId));
    // --- AKHIR ISOLASI VEO ---

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

    // --- KATEGORI_PENYESUAIAN_VEO (NO_URUT_04): Hapus Controller Transisi ---
    // --- AKHIR PENYESUAIAN VEO ---
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
    // --- KATEGORI_PENYESUAIAN_VEO (NO_URUT_05): Hapus Controller Transisi ---
    // --- AKHIR PENYESUAIAN VEO ---
    super.dispose();
  }

  // --- METHOD BUILD UTAMA ---
  @override
  Widget build(BuildContext context) {
    // --- KATEGORI_ISOLASI_VEO (Aturan #3): Ref Provider Disesuaikan ---
    final settings = ref.watch(visualSettingsVeoProvider(widget.projectId));
    final settingsNotifier =
        ref.read(visualSettingsVeoProvider(widget.projectId).notifier);
    // --- AKHIR ISOLASI VEO ---

    // --- KATEGORI_PENYESUAIAN_VEO (NO_URUT_06): Hapus Sinkronisasi Transisi ---
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Karena kita hanya membandingkan Título dan Deskripsi, perbandingan ini tidak diperlukan
      // jika kita sudah sinkron di didUpdateWidget, tapi jaga untuk jaga-jaga.
      if (_titleTextController.text != settings.titleSettings.text) {
         _syncControllers();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Visual Settings (Veo)'), // Label diubah
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset to Defaults',
            onPressed: () {
              _showResetDialog(context, settingsNotifier);
            },
          ),
          // --- BLOK SAVE (Dipertahankan) ---
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Save Settings',
            onPressed: () async {
              FocusScope.of(context).unfocus();

              final scaffold = ScaffoldMessenger.of(context);
              scaffold.showSnackBar(
                const SnackBar(
                  content: Text('Saving visual settings (Veo)...'),
                  duration: Duration(seconds: 2),
                ),
              );

              try {
                await settingsNotifier.saveSettingsToFirestore();
                scaffold.hideCurrentSnackBar();
                scaffold.showSnackBar(
                  const SnackBar(
                    content: Text('✅ Settings saved successfully!'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 2),
                  ),
                );
                if (context.mounted) Navigator.pop(context);
              } catch (e) {
                scaffold.hideCurrentSnackBar();
                scaffold.showSnackBar(
                  SnackBar(
                    content: Text('❌ Failed to save settings: $e'),
                    backgroundColor: Colors.red,
                    duration: const Duration(seconds: 3),
                  ),
                );
                debugPrint('Error while saving settings (Veo): $e');
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
            initialOpenPanelValue: _openPanelIndex,
            animationDuration: const Duration(milliseconds: 300),
            elevation: 1,
            expansionCallback: (int index, bool isExpanded) {
              setState(() {
                _openPanelIndex = _openPanelIndex == index ? -1 : index;
              });
            },
            children: [
              // --- Panel 1: Title Settings (Value 0) ---
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

              // --- Panel 2: Description Settings (Value 1) ---
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
              // --- KATEGORI_PENGHAPUSAN_VEO (NO_URUT_07): Hapus Panel Subtitle ---
              // --- KATEGORI_PENGHAPUSAN_VEO (NO_URUT_08): Hapus Panel Motion/Transisi ---
              // (Semua panel lain telah dihapus)
            ],
          ),
        ),
      ),
    );
  }

  // --- KUNCI PERBAIKAN: Helper _buildSettingsSection dimodifikasi ---
  // (Hapus semua referensi subtitle/motion/transisi)
  Widget _buildSettingsSection(
    BuildContext context,
    // --- KATEGORI_ISOLASI_VEO (Aturan #3): Tipe Model Disesuaikan ---
    TextOverlaySettingsVeo currentSettings, {
    // --- AKHIR ISOLASI VEO ---
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- KATEGORI_FITUR_VALIDASI NO_URUT_02: Terapkan validasi ke TextField ---
        TextField(
          controller: textController, // <-- Gunakan controller dari state
          decoration: const InputDecoration(
            labelText: 'Text',
            border: OutlineInputBorder(),
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
              labelText: 'Effect', border: OutlineInputBorder()),
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
                      border: Border.all(color: Colors.grey.shade400),
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
                    border: OutlineInputBorder(),
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
                    border: OutlineInputBorder(),
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

  // --- HELPER _buildNumericInput (Dipertahankan) ---
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
        border: const OutlineInputBorder(),
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

  // --- HELPER _buildFactorInput (Dipertahankan) ---
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
        border: const OutlineInputBorder(),
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

  // --- DIALOG PEMILIH WARNA (Dipertahankan) ---
  void _showColorPicker(
      BuildContext context, Color currentColor, ValueChanged<Color> onColorChanged) {
    showDialog(
      context: context,
      builder: (context) {
        Color pickerColor = currentColor;
        return AlertDialog(
          title: const Text('Pick a color'),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: pickerColor,
              onColorChanged: (color) => pickerColor = color,
            ),
          ),
          actions: <Widget>[
            TextButton(
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

  // --- DIALOG RESET (Dipertahankan) ---
  // --- KATEGORI_ISOLASI_VEO (Aturan #3): Tipe Notifier Disesuaikan ---
  void _showResetDialog(
      BuildContext context, VisualSettingsVeoNotifier notifier) {
  // --- AKHIR ISOLASI VEO ---
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
              child: const Text('RESET', style: TextStyle(color: Colors.red)),
              onPressed: () {
                // Panggil method reset dari notifier
                notifier.resetToDefaults();
                // Sinkronisasi controller akan ditangani oleh '_syncControllers'
                // yang dipanggil secara otomatis oleh logic di 'build'
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Settings have been reset to default.'),
                    backgroundColor: Colors.blueAccent,
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