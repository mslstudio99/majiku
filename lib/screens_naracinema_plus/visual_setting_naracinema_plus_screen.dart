//================================================================//
// NAMA FILE: VISUAL_SETTING_NARACINEMA_PLUS_SCREEN.DART          //
// DIREKTORI: LIB/SCREENS_NARACINEMA_PLUS/                        //
// DESKRIPSI: LAYAR PENGATURAN VISUAL OVERLAY NARACINEMA PLUS     //
//================================================================//

// No ke-1: IMPORT DEPENDENSI & SETUP AWAL                        //
//----------------------------------------------------------------//
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import '../providers_naracinema_plus/visual_settings_naracinema_plus_provider.dart';
//----------------------------------------------------------------//

// No ke-2: KELAS UTAMA VISUAL SETTING                            //
//----------------------------------------------------------------//
class VisualSettingNaracinemaPlusScreen extends ConsumerStatefulWidget {
  final String projectId;
  
  const VisualSettingNaracinemaPlusScreen({super.key, required this.projectId});

  @override
  ConsumerState<VisualSettingNaracinemaPlusScreen> createState() => _VisualSettingNaracinemaPlusScreenState();
}

class _VisualSettingNaracinemaPlusScreenState extends ConsumerState<VisualSettingNaracinemaPlusScreen> {
  int _openPanelIndex = 0; 

  late TextEditingController _titleTextController;
  late TextEditingController _titleStartTimeController;
  late TextEditingController _titleDurationController;

  late TextEditingController _descTextController;
  late TextEditingController _descStartTimeController;
  late TextEditingController _descDurationController;
//----------------------------------------------------------------//

// No ke-3: SIKLUS HIDUP DAN SINKRONISASI KONTROLER               //
//----------------------------------------------------------------//
  @override
  void initState() {
    super.initState();
    final initialSettings = ref.read(visualSettingsNaracinemaPlusProvider(widget.projectId));

    _titleTextController = TextEditingController(text: initialSettings.titleSettings.text);
    _titleStartTimeController = TextEditingController(text: initialSettings.titleSettings.startTime.toStringAsFixed(1));
    _titleDurationController = TextEditingController(text: initialSettings.titleSettings.duration.toStringAsFixed(1));

    _descTextController = TextEditingController(text: initialSettings.descriptionSettings.text);
    _descStartTimeController = TextEditingController(text: initialSettings.descriptionSettings.startTime.toStringAsFixed(1));
    _descDurationController = TextEditingController(text: initialSettings.descriptionSettings.duration.toStringAsFixed(1));
  }

  @override
  void didUpdateWidget(covariant VisualSettingNaracinemaPlusScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.projectId != widget.projectId) {
      _syncControllers();
    }
  }

  void _syncControllers() {
    final settings = ref.read(visualSettingsNaracinemaPlusProvider(widget.projectId));

    _tryUpdateController(_titleTextController, settings.titleSettings.text);
    _tryUpdateController(_titleStartTimeController, settings.titleSettings.startTime.toStringAsFixed(1));
    _tryUpdateController(_titleDurationController, settings.titleSettings.duration.toStringAsFixed(1));

    _tryUpdateController(_descTextController, settings.descriptionSettings.text);
    _tryUpdateController(_descStartTimeController, settings.descriptionSettings.startTime.toStringAsFixed(1));
    _tryUpdateController(_descDurationController, settings.descriptionSettings.duration.toStringAsFixed(1));
  }

  void _tryUpdateController(TextEditingController controller, String newValue) {
    if (controller.text != newValue) {
      controller.text = newValue;
      try {
        controller.selection = TextSelection.fromPosition(TextPosition(offset: newValue.length));
      } catch (e) {
        debugPrint("Error setting cursor (aman diabaikan): $e");
      }
    }
  }

  @override
  void dispose() {
    _titleTextController.dispose();
    _titleStartTimeController.dispose();
    _titleDurationController.dispose();
    _descTextController.dispose();
    _descStartTimeController.dispose();
    _descDurationController.dispose();
    super.dispose();
  }
//----------------------------------------------------------------//

// No ke-4: ANTARMUKA PENGGUNA (BUILD METHOD)                     //
//----------------------------------------------------------------//
  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(visualSettingsNaracinemaPlusProvider(widget.projectId));
    final settingsNotifier = ref.read(visualSettingsNaracinemaPlusProvider(widget.projectId).notifier);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_titleTextController.text != settings.titleSettings.text) {
         _syncControllers();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Visual Settings (Naracinema Plus)'), 
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset to Defaults',
            onPressed: () {
              _showResetDialog(context, settingsNotifier);
            },
          ),
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Save Settings',
            onPressed: () async {
              FocusScope.of(context).unfocus();

              final scaffold = ScaffoldMessenger.of(context);
              scaffold.showSnackBar(
                const SnackBar(
                  content: Text('Saving visual settings (Naracinema Plus)...'),
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
                debugPrint('Error while saving settings (Naracinema Plus): $e');
              }
            },
          ),
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
              ExpansionPanelRadio(
                value: 0,
                headerBuilder: (BuildContext context, bool isExpanded) {
                  return ListTile(
                    title: Text('Title Settings',
                        style: Theme.of(context).textTheme.titleLarge),
                  );
                },
                body: Padding(
                  padding: const EdgeInsets.all(16.0).copyWith(top: 0, bottom: 24),
                  child: _buildSettingsSection(
                    context,
                    settings.titleSettings,
                    textController: _titleTextController,
                    startTimeController: _titleStartTimeController,
                    durationController: _titleDurationController,
                    onTextChanged: settingsNotifier.updateTitleText,
                    onEffectChanged: settingsNotifier.updateTitleEffect,
                    onBaseFontSizeChanged: settingsNotifier.updateTitleBaseFontSize,
                    onColorChanged: settingsNotifier.updateTitleColor,
                    onStartTimeChanged: settingsNotifier.updateTitleStartTime,
                    onDurationChanged: settingsNotifier.updateTitleDuration,
                    onBlockWidthFactorChanged: settingsNotifier.updateTitleBlockWidthFactor,
                    textMaxLength: 40,
                    textCapitalization: TextCapitalization.characters,
                    textInputFormatters: null,
                  ),
                ),
              ),

              ExpansionPanelRadio(
                value: 1,
                headerBuilder: (BuildContext context, bool isExpanded) {
                  return ListTile(
                    title: Text('Description Settings',
                        style: Theme.of(context).textTheme.titleLarge),
                  );
                },
                body: Padding(
                  padding: const EdgeInsets.all(16.0).copyWith(top: 0, bottom: 24),
                  child: _buildSettingsSection(
                    context,
                    settings.descriptionSettings,
                    textController: _descTextController,
                    startTimeController: _descStartTimeController,
                    durationController: _descDurationController,
                    onTextChanged: settingsNotifier.updateDescriptionText,
                    onEffectChanged: settingsNotifier.updateDescriptionEffect,
                    onBaseFontSizeChanged: settingsNotifier.updateDescriptionBaseFontSize,
                    onColorChanged: settingsNotifier.updateDescriptionColor,
                    onStartTimeChanged: settingsNotifier.updateDescriptionStartTime,
                    onDurationChanged: settingsNotifier.updateDescriptionDuration,
                    onBlockWidthFactorChanged: settingsNotifier.updateDescriptionBlockWidthFactor,
                    textMaxLength: 80, // [SUNTIKAN BARU] Diselaraskan menjadi 80 karakter agar sinkron dengan form input
                    textCapitalization: TextCapitalization.none, 
                    textInputFormatters: null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
//----------------------------------------------------------------//

// No ke-5: WIDGET PEMBANTU DAN DIALOG                            //
//----------------------------------------------------------------//
  Widget _buildSettingsSection(
    BuildContext context,
    TextOverlayNaracinemaPlusSettings currentSettings, {
    required TextEditingController textController,
    required TextEditingController startTimeController,
    required TextEditingController durationController,
    required ValueChanged<String> onTextChanged,
    required ValueChanged<TextEffect> onEffectChanged,
    required ValueChanged<double> onBaseFontSizeChanged,
    required ValueChanged<Color> onColorChanged,
    required ValueChanged<double> onStartTimeChanged,
    required ValueChanged<double> onDurationChanged,
    required ValueChanged<double> onBlockWidthFactorChanged,
    required int textMaxLength,
    required TextCapitalization textCapitalization,
    List<TextInputFormatter>? textInputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: textController, 
          decoration: const InputDecoration(
            labelText: 'Text',
            border: OutlineInputBorder(),
          ),
          onChanged: onTextChanged, 
          maxLines: 3,
          maxLength: textMaxLength,
          textCapitalization: textCapitalization,
          inputFormatters: textInputFormatters,
          maxLengthEnforcement: MaxLengthEnforcement.enforced,
        ),
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
                controller: startTimeController, 
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
                controller: durationController, 
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

  void _showResetDialog(
      BuildContext context, VisualSettingsNaracinemaPlusNotifier notifier) {
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
                notifier.resetToDefaults();
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
}
//----------------------------------------------------------------//