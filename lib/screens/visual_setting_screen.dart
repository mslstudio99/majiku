//================================================================//
// NAMA FILE: VISUAL_SETTING_SCREEN.DART                          //
// PATH/DIREKTORI: lib/screens/visual_setting_screen.dart         //
// FUNGSI UTAMA: EDITOR PENGATURAN VISUAL OVERLAY & TRANSISI VIDEO//
//================================================================//

//No ke-1.........................................................//
// IMPORT DEPENDENSI & LAYAR UTAMA (STATEFUL WIDGET)              //
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

// Import model dan provider
import '../providers/visual_settings_provider.dart';

class VisualSettingScreen extends ConsumerStatefulWidget {
  final String projectId;
  const VisualSettingScreen({super.key, required this.projectId});

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

  static const Map<String, String> _sceneMotionBehaviorOptions = {
    'Default (Sequence)': 'default',
    'Random': 'random',
  };

  @override
  ConsumerState<VisualSettingScreen> createState() => _VisualSettingScreenState();
}
//................................................................//

//No ke-2.........................................................//
// INSTANSI STATE, INISIALISASI, SINKRONISASI & DESTRUKSI         //
class _VisualSettingScreenState extends ConsumerState<VisualSettingScreen> {
  int _openPanelIndex = 0; // State untuk Accordion

  late TextEditingController _titleTextController;
  late TextEditingController _titleStartTimeController;
  late TextEditingController _titleDurationController;

  late TextEditingController _descTextController;
  late TextEditingController _descStartTimeController;
  late TextEditingController _descDurationController;

  late TextEditingController _transitionDurationController;

  @override
  void initState() {
    super.initState();
    final initialSettings =
        ref.read(visualSettingsProvider(widget.projectId));

    _titleTextController =
        TextEditingController(text: initialSettings.titleSettings.text);
    _titleStartTimeController = TextEditingController(
        text: initialSettings.titleSettings.startTime.toStringAsFixed(1));
    _titleDurationController = TextEditingController(
        text: initialSettings.titleSettings.duration.toStringAsFixed(1));

    _descTextController =
        TextEditingController(text: initialSettings.descriptionSettings.text);
    _descStartTimeController = TextEditingController(
        text: initialSettings.descriptionSettings.startTime.toStringAsFixed(1));
    _descDurationController = TextEditingController(
        text: initialSettings.descriptionSettings.duration.toStringAsFixed(1));

    _transitionDurationController = TextEditingController(
        text: initialSettings.transitionDuration.toStringAsFixed(1));
  }

  @override
  void didUpdateWidget(covariant VisualSettingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.projectId != widget.projectId) {
      _syncControllers();
    }
  }

  void _syncControllers() {
    final settings = ref.read(visualSettingsProvider(widget.projectId));

    _tryUpdateController(_titleTextController, settings.titleSettings.text);
    _tryUpdateController(_titleStartTimeController,
        settings.titleSettings.startTime.toStringAsFixed(1));
    _tryUpdateController(_titleDurationController,
        settings.titleSettings.duration.toStringAsFixed(1));

    _tryUpdateController(
        _descTextController, settings.descriptionSettings.text);
    _tryUpdateController(_descStartTimeController,
        settings.descriptionSettings.startTime.toStringAsFixed(1));
    _tryUpdateController(_descDurationController,
        settings.descriptionSettings.duration.toStringAsFixed(1));

    _tryUpdateController(_transitionDurationController,
        settings.transitionDuration.toStringAsFixed(1));
  }

  void _tryUpdateController(TextEditingController controller, String newValue) {
    if (controller.text != newValue) {
      controller.text = newValue;
      try {
        controller.selection =
            TextSelection.fromPosition(TextPosition(offset: newValue.length));
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
    _transitionDurationController.dispose();
    super.dispose();
  }
//................................................................//

//No ke-3.........................................................//
// MERAKIT UI UTAMA & DAFTAR AKORDION (EXPANSION PANEL LIST)       //
  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(visualSettingsProvider(widget.projectId));
    final settingsNotifier =
        ref.read(visualSettingsProvider(widget.projectId).notifier);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_transitionDurationController.text !=
          settings.transitionDuration.toStringAsFixed(1)) {
        _syncControllers();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Visual Settings'),
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
                    backgroundColor: Theme.of(context).colorScheme.secondary,
                    duration: const Duration(seconds: 2),
                  ),
                );
                if (context.mounted) Navigator.pop(context);
              } catch (e) {
                scaffold.hideCurrentSnackBar();
                scaffold.showSnackBar(
                  SnackBar(
                    content: Text('❌ Failed to save settings: $e'),
                    backgroundColor: Theme.of(context).colorScheme.error,
                    duration: const Duration(seconds: 3),
                  ),
                );
                debugPrint('Error while saving settings: $e');
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
                  padding:
                      const EdgeInsets.all(16.0).copyWith(top: 0, bottom: 24),
                  child: _buildSettingsSection(
                    context,
                    settings.titleSettings,
                    textController: _titleTextController,
                    startTimeController: _titleStartTimeController,
                    durationController: _titleDurationController,
                    onTextChanged: settingsNotifier.updateTitleText,
                    onEffectChanged: settingsNotifier.updateTitleEffect,
                    onBaseFontSizeChanged:
                        settingsNotifier.updateTitleBaseFontSize,
                    onColorChanged: settingsNotifier.updateTitleColor,
                    onStartTimeChanged: settingsNotifier.updateTitleStartTime,
                    onDurationChanged: settingsNotifier.updateTitleDuration,
                    onBlockWidthFactorChanged:
                        settingsNotifier.updateTitleBlockWidthFactor,
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
                  padding:
                      const EdgeInsets.all(16.0).copyWith(top: 0, bottom: 24),
                  child: _buildSettingsSection(
                    context,
                    settings.descriptionSettings,
                    textController: _descTextController,
                    startTimeController: _descStartTimeController,
                    durationController: _descDurationController,
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
                    // --- SINKRONISASI BATAS: Teks maksimal disesuaikan ke 80 karakter ---
                    textMaxLength: 80,
                    textCapitalization: TextCapitalization.none,
                    textInputFormatters: null,
                  ),
                ),
              ),

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
                              decoration: const InputDecoration(
                                labelText: 'Transition Type',
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
                              controller: _transitionDurationController,
                              decoration: const InputDecoration(
                                labelText: 'Duration (sec)',
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
                        style: Theme.of(context).textTheme.bodySmall,
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
//................................................................//

//No ke-4.........................................................//
// METODE PEMBANTU BAGIAN PENGATURAN (SECTION BUILDERS) & DIALOG  //
  Widget _buildSettingsSection(
    BuildContext context,
    TextOverlaySettings currentSettings, {
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
              labelText: 'Effect', 
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
                      border: Border.all(color: Theme.of(context).textTheme.bodySmall!.color!),
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
              child: Text('RESET', style: TextStyle(color: Theme.of(context).colorScheme.error)),
              onPressed: () {
                notifier.resetToDefaults();
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Settings have been reset to default.'),
                    backgroundColor: Theme.of(context).colorScheme.primary,
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
//................................................................//