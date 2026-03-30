//................................................................//
// NAMA FILE: INPUT_SCRIPT_VEO_SCREEN.DART                        //
// PATH: LIB/SCREENS_VEO/INPUT_SCRIPT_VEO_SCREEN.DART             //
//................................................................//

//No ke-1.........................................................//
// IMPORT DEPENDENSI & SETUP AWAL                                 //
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Service & Models
import '../services_veo/firestore_veo_service.dart';
import '../models/app_config.dart'; 
import '../models/app_user.dart'; 

// Providers
import '../providers/user_provider.dart';
import '../providers/config_provider.dart'; // Akses Config & Bahasa
import '../providers_veo/firestore_veo_provider.dart'; 

// Screens / Theme
import 'project_loading_veo_screen.dart';
import '../theme/app_theme.dart';

/*
[RILIS BERSIH - INPUT SCRIPT VEO: EXPANDED LANGUAGES]
KATEGORI_FITUR_UTAMA NO_URUT_07
Tujuan:
- [DATA] Menerima data lemparan (Title/Script).
- [LOGIC] Menggunakan Provider VEO (Footage).
- [UI] Mendukung 37 Bahasa/Dialek Spesifik untuk Veo Prompting.
- [NEW FEATURE] Pop up animasi peringatan token habis bergaya modern (Hijau/Putih).
- [ANTI-REGRESI] Menjaga seluruh kalkulasi token Veo (footagePerScene) dan fungsi database.
*/
//................................................................//

//No ke-2.........................................................//
// SETUP STATE DAN MAPS OPSI BAHASA VEO                           //
class InputScriptVeoScreen extends ConsumerStatefulWidget {
  final String initialTitle;
  final String initialScript;

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
  
  // Default tetap Indonesian
  String _selectedLanguage = 'Indonesian'; 
  bool _isLoading = false;

  // [DATA BARU] Daftar Bahasa Lengkap (37 Opsi)
  static const List<String> _supportedLanguages = [
    'Indonesian',
    'English (US)',
    'English (UK)',
    'English (Australia)',
    'English (India)',
    'Arabic',
    'Bengali (India)',
    'Danish',
    'Dutch (Netherlands)',
    'Dutch (Belgium)',
    'Finnish',
    'French (France)',
    'French (Canada)',
    'German',
    'Gujarati',
    'Hindi',
    'Italian',
    'Japanese',
    'Kannada',
    'Korean',
    'Malayalam',
    'Mandarin Chinese',
    'Marathi',
    'Norwegian',
    'Polish',
    'Portuguese (Brazil)',
    'Russian',
    'Spanish (Spain)',
    'Spanish (US)',
    'Swedish',
    'Tamil',
    'Telugu',
    'Thai',
    'Turkish',
    'Ukrainian',
    'Urdu',
    'Vietnamese',
  ];
//................................................................//

//No ke-3.........................................................//
// INIT, DISPOSE, & LOGIC (SUBMIT VEO)                            //
  @override
  void initState() {
    super.initState();
    
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
                  content: Text('Error: Failed to create project ID (VEO). Please try again.'),
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
//................................................................//

//No ke-4.........................................................//
// BUILD UI & FORM LAYOUT                                         //
  @override
  Widget build(BuildContext context) {
    final currentLocale = ref.watch(appLanguageProvider);
    final isIndo = currentLocale.languageCode == 'id';
    String t(String en, String id) => isIndo ? id : en;

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
      costPerScene = config.costs.footagePerScene; // Spesifik VEO
      configReady = true;
    });

    final int requiredTokens = estimatedScenes * costPerScene;
    final bool hasSufficientFunds = currentBalance >= requiredTokens;
    final bool hasInput = textLength > 0;

    // [FITUR BARU] Logika validasi pop up peringatan token
    final bool isOutOfTokens = hasInput && !hasSufficientFunds;
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
        // [FITUR BARU] Stack UI untuk animasi Pop Up melayang
        body: SafeArea(
          child: Stack(
            children: [
              // --- FORM UTAMA KONTEN ---
              Positioned.fill(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _titleController,
                          maxLength: 40,
                          decoration: InputDecoration(
                            labelText: t('Project Title', 'Judul Proyek'),
                            hintText: t('e.g., "My First Veo Video"', 'Cth: "Video Veo Pertamaku"'),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return t('Please enter a project title.', 'Mohon isi judul proyek.');
                            }
                            if (value.length > 40) {
                              return t('Title cannot exceed 40 characters.', 'Judul maksimal 40 karakter.');
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),

                        TextFormField(
                          controller: _scriptController,
                          maxLines: 10,
                          maxLength: 15000,
                          decoration: InputDecoration(
                            labelText: t('Paste or send your narration here..', 'Paste atau kirim narasi mu disini'),
                            hintText: t('Paste or type your full video narration here...', 'Tempel atau ketik narasi lengkap di sini...'),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return t('Please enter a script for your video.', 'Mohon isi narasi video.');
                            }
                            if (value.length > 15000) {
                              return t('Script cannot exceed 18,000 characters.', 'Narasi maksimal 18.000 karakter.');
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),

                        DropdownButtonFormField<String>(
                          value: _selectedStyle,
                          decoration: InputDecoration(
                            labelText: t('Visual Style (Veo)', 'Gaya Visual (Veo)'),
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
                            decoration: InputDecoration(
                              labelText: t('Language (for Veo Dialogue)', 'Bahasa (Dialog Veo)'),
                            ),
                            menuMaxHeight: 400, 
                            items: _supportedLanguages
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
                          decoration: InputDecoration(
                            labelText: t('Aspect Ratio', 'Rasio Aspek'),
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
                                : Text(t('PROCESS VIDEO', 'PROSES VIDEO')),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple, 
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.grey[800],
                            disabledForegroundColor: Colors.grey[500],
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
                      ],
                    ),
                  ),
                ),
              ),

              // --- [FITUR BARU] POP UP ANIMASI TOKEN HABIS ---
              AnimatedPositioned(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutBack,
                top: isOutOfTokens ? 16.0 : -100.0, 
                left: 16.0,
                right: 16.0,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: isOutOfTokens ? 1.0 : 0.0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade600, // Background Hijau
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black45, 
                          blurRadius: 10, 
                          offset: Offset(0, 4)
                        )
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, color: Colors.white, size: 24),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            "Out of tokens. Upgrade or add more via the dashboard!",
                            style: TextStyle(
                              color: Colors.white, // Teks Putih
                              fontWeight: FontWeight.bold, 
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
//................................................................//