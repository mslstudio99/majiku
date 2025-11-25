// [RILIS FINAL - ANTI REGRESI]
// Lokasi: lib/screens_veo/input_script_veo_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Service & Models
import '../services_veo/firestore_veo_service.dart';
import '../models/app_config.dart'; 
import '../models/app_user.dart'; 

// Providers (Pastikan path sesuai tree)
import '../providers/user_provider.dart';
import '../providers/config_provider.dart';
// [CRITICAL FIX] Impor provider yang baru dibuat di Langkah 1
import '../providers_veo/firestore_veo_provider.dart'; 

// Screens / Theme
import 'project_loading_veo_screen.dart';
import '../theme/app_theme.dart';

class InputScriptVeoScreen extends ConsumerStatefulWidget {
  final String initialTitle;
  final String initialScript;

  // Constructor tidak boleh const karena ada parameter default
  InputScriptVeoScreen({
    super.key,
    this.initialTitle = '',
    this.initialScript = '',
  });

  @override
  ConsumerState<InputScriptVeoScreen> createState() =>
      _InputScriptVeoScreenState();
}

class _InputScriptVeoScreenState extends ConsumerState<InputScriptVeoScreen> {
  final _scriptController = TextEditingController();
  final _titleController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String _selectedStyle = 'Realistic';
  String _selectedAspectRatio = '16:9';
  String _selectedLanguage = 'Indonesian';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    
    // Mengisi data dari parameter kiriman (Fitur Send)
    if (widget.initialTitle.isNotEmpty) {
      _titleController.text = widget.initialTitle;
    }
    if (widget.initialScript.isNotEmpty) {
      _scriptController.text = widget.initialScript;
    }

    _scriptController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _scriptController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _submitData() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      // Membaca provider VEO
      final firestoreService = ref.read(firestoreVeoServiceProvider);
      try {
        final String? newProjectId = await firestoreService.addProject(
          title: _titleController.text,
          rawScript: _scriptController.text,
          imageStyle: _selectedStyle, 
          aspectRatio: _selectedAspectRatio,
          language: _selectedLanguage,
        );

        if (mounted) {
          if (newProjectId != null && newProjectId.isNotEmpty) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => ProjectLoadingVeoScreen(
                  projectId: newProjectId,
                ),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text(
                      'Error: Failed to create project ID (VEO). Please try again.'),
                  backgroundColor: Colors.red),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Error adding project (VEO): $e'),
                backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(firestoreUserProvider);
    final configAsync = ref.watch(appConfigProvider);

    final int textLength = _scriptController.text.trim().length;
    int estimatedScenes = (textLength / 150).ceil();
    if (estimatedScenes == 0 && textLength > 0) estimatedScenes = 1;

    int currentBalance = 0;
    int costPerScene = 0;
    bool configReady = false;
    bool userReady = false;

    userAsync.whenData((user) {
      currentBalance = user.tokenBalance;
      userReady = true;
    });

    configAsync.whenData((config) {
      costPerScene = config.costs.footagePerScene; 
      configReady = true;
    });

    final int requiredTokens = estimatedScenes * costPerScene;
    final bool hasSufficientFunds = currentBalance >= requiredTokens;
    final bool hasInput = textLength > 0;

    final bool canSubmit = hasInput && hasSufficientFunds && !_isLoading && userReady && configReady;

    return Theme(
      data: AppTheme.darkTheme,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('VFootage'),
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
                      color: hasInput && !hasSufficientFunds ? Colors.redAccent : Colors.white24,
                      width: 1
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.token, 
                        size: 16, 
                        color: hasInput && !hasSufficientFunds ? Colors.redAccent : Colors.amber
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "$requiredTokens / $currentBalance", 
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: hasInput && !hasSufficientFunds ? Colors.redAccent : Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _titleController,
                  maxLength: 40,
                  decoration: const InputDecoration(
                    labelText: 'Project Title',
                    hintText: 'e.g., "My First Veo Video"',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a project title.';
                    }
                    if (value.length > 40) {
                      return 'Title cannot exceed 40 characters.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                TextFormField(
                  controller: _scriptController,
                  maxLines: 10,
                  maxLength: 18000,
                  decoration: const InputDecoration(
                    labelText: 'Narration',
                    hintText: 'Paste or type your full video narration here...',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a script for your video.';
                    }
                    if (value.length > 18000) {
                      return 'Script cannot exceed 18,000 characters.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                DropdownButtonFormField<String>(
                  value: _selectedStyle,
                  decoration: const InputDecoration(
                    labelText: 'Visual Style (Veo)',
                  ),
                  items: ['Realistic', 'Cartoon_3D', 'Cartoon_2D']
                      .map((style) => DropdownMenuItem(
                            value: style,
                            child: Text(style.replaceAll('_', ' ')),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _selectedStyle = value);
                  },
                ),
                const SizedBox(height: 24),

                DropdownButtonFormField<String>(
                    value: _selectedLanguage,
                    decoration: const InputDecoration(
                      labelText: 'Language (for Veo Dialogue)',
                    ),
                    items: ['Indonesian', 'English']
                        .map((lang) => DropdownMenuItem(
                              value: lang,
                              child: Text(lang),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null && value != _selectedLanguage) {
                        setState(() {
                          _selectedLanguage = value;
                        });
                      }
                    },
                ),
                const SizedBox(height: 24),

                DropdownButtonFormField<String>(
                  value: _selectedAspectRatio,
                  decoration: const InputDecoration(
                    labelText: 'Aspect Ratio',
                  ),
                  items: const {
                    'Landscape (16:9)': '16:9',
                    'Potrait (9:16)': '9:16',
                    'Square (1:1)': '1:1',
                  }
                      .entries
                      .map((entry) => DropdownMenuItem(
                            value: entry.value,
                            child: Text(entry.key),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedAspectRatio = value);
                    }
                  },
                ),
                const SizedBox(height: 32),

                ElevatedButton.icon(
                  onPressed: canSubmit ? _submitData : null,
                  icon: _isLoading ? const SizedBox.shrink() : const Icon(Icons.auto_awesome),
                  label: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: _isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          )
                        : const Text('PROCESS'),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[800],
                    disabledForegroundColor: Colors.grey[500],
                  ),
                ),
                if (hasInput && !hasSufficientFunds)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Center(
                      child: Text(
                        "Insufficient balance. You need ${requiredTokens - currentBalance} more tokens.",
                        style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}