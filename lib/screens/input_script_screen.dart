// [RILIS BERSIH - UI RINGKAS HEADER TOKEN]
// KATEGORI_TEMA_BARU NO_URUT_04 (REVISI DATA PASSING)
// Lokasi: lib/screens/input_script_screen.dart
// TUJUAN:
// - [DATA] Menerima initialTitle dan initialScript dari screen lain.
// - [DATA] Mengisi TextEditingController dengan data awal (jika ada).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/firestore_service.dart';

// --- KATEGORI_REFAKTORISASI_STRUKTUR (Anti-Regresi) ---
import '../providers/visual_settings_provider.dart';
import '../providers/user_provider.dart'; // Mengimpor firestoreUserProvider
import '../providers/config_provider.dart'; // Mengimpor appConfigProvider
// --- AKHIR REFAKTORISASI ---

import 'project_loading_screen.dart';
import '../theme/app_theme.dart';

class InputScriptScreen extends ConsumerStatefulWidget {
  // [PERUBAHAN KRITIS] Tambahkan parameter untuk passing data
  final String initialTitle;
  final String initialScript;

  // Hapus 'const' dan tambahkan parameter ke constructor
  const InputScriptScreen({
    super.key,
    this.initialTitle = '',
    this.initialScript = '',
  });

  @override
  ConsumerState<InputScriptScreen> createState() => _InputScriptScreenState();
}

class _InputScriptScreenState extends ConsumerState<InputScriptScreen> {
  // (State internal)
  final _scriptController = TextEditingController();
  final _titleController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  String _selectedStyle = 'Realistic';
  String _selectedAspectRatio = '16:9';
  String _selectedLanguage = 'Indonesian';
  static const String _defaultIndonesianVoice = 'id-ID-Chirp3-HD-Achernar';
  static const String _defaultEnglishVoice = 'en-US-Studio-M';
  String _selectedVoice = _defaultIndonesianVoice;
  bool _isLoading = false;

  final Map<String, String> _indonesianVoiceOptions = {
    'Achernar (ID)': 'id-ID-Chirp3-HD-Achernar',
    'Achird (ID)': 'id-ID-Chirp3-HD-Achird',
    'Algenib (ID)': 'id-ID-Chirp3-HD-Algenib',
    'Algieba (ID)': 'id-ID-Chirp3-HD-Algieba',
    'Alnilam (ID)': 'id-ID-Chirp3-HD-Alnilam',
    'Aoede (ID)': 'id-ID-Chirp3-HD-Aoede',
    'Autonoe (ID)': 'id-ID-Chirp3-HD-Autonoe',
    'Callirrhoe (ID)': 'id-ID-Chirp3-HD-Callirrhoe',
    'Charon (ID)': 'id-ID-Chirp3-HD-Charon',
    'Despina (ID)': 'id-ID-Chirp3-HD-Despina',
    'Enceladus (ID)': 'id-ID-Chirp3-HD-Enceladus',
    'Erinome (ID)': 'id-ID-Chirp3-HD-Erinome',
    'Fenrir (ID)': 'id-ID-Chirp3-HD-Fenrir',
    'Gacrux (ID)': 'id-ID-Chirp3-HD-Gacrux',
    'Iapetus (ID)': 'id-ID-Chirp3-HD-Iapetus',
    'Kore (ID)': 'id-ID-Chirp3-HD-Kore',
    'Laomedeia (ID)': 'id-ID-Chirp3-HD-Laomedeia',
    'Leda (ID)': 'id-ID-Chirp3-HD-Leda',
    'Orus (ID)': 'id-ID-Chirp3-HD-Orus',
    'Puck (ID)': 'id-ID-Chirp3-HD-Puck',
    'Pulcherrima (ID)': 'id-ID-Chirp3-HD-Pulcherrima',
    'Rasalgethi (ID)': 'id-ID-Chirp3-HD-Rasalgethi',
    'Sadachbia (ID)': 'id-ID-Chirp3-HD-Sadachbia',
    'Sadaltager (ID)': 'id-ID-Chirp3-HD-Sadaltager',
    'Schedar (ID)': 'id-ID-Chirp3-HD-Schedar',
    'Sulafat (ID)': 'id-ID-Chirp3-HD-Sulafat',
    'Umbriel (ID)': 'id-ID-Chirp3-HD-Umbriel',
    'Vindemiatrix (ID)': 'id-ID-Chirp3-HD-Vindemiatrix',
    'Zephyr (ID)': 'id-ID-Chirp3-HD-Zephyr',
    'Zubenelgenubi (ID)': 'id-ID-Chirp3-HD-Zubenelgenubi',
  };
  final Map<String, String> _englishVoiceOptions = {
    'Alnilam (EN)': 'en-US-Chirp3-HD-Alnilam',
    'Aoede (EN)': 'en-US-Chirp3-HD-Aoede',
    'Autonoe (EN)': 'en-US-Chirp3-HD-Autonoe',
    'Callirrhoe (EN)': 'en-US-Chirp3-HD-Callirrhoe',
    'Charon (EN)': 'en-US-Chirp3-HD-Charon',
    'Despina (EN)': 'en-US-Chirp3-HD-Despina',
    'Enceladus (EN)': 'en-US-Chirp3-HD-Enceladus',
    'Erinome (EN)': 'en-US-Chirp3-HD-Erinome',
    'Fenrir (EN)': 'en-US-Chirp3-HD-Fenrir',
    'Gacrux (EN)': 'en-US-Chirp3-HD-Gacrux',
    'Iapetus (EN)': 'en-US-Chirp3-HD-Iapetus',
    'Kore (EN)': 'en-US-Chirp3-HD-Kore',
    'Laomedeia (EN)': 'en-US-Chirp3-HD-Laomedeia',
    'Leda (EN)': 'en-US-Chirp3-HD-Leda',
    'Orus (EN)': 'en-US-Chirp3-HD-Orus',
    'Puck (EN)': 'en-US-Chirp3-HD-Puck',
    'Pulcherrima (EN)': 'en-US-Chirp3-HD-Pulcherrima',
    'Rasalgethi (EN)': 'en-US-Chirp3-HD-Rasalgethi',
    'Sadachbia (EN)': 'en-US-Chirp3-HD-Sadachbia',
    'Sadaltager (EN)': 'en-US-Chirp3-HD-Sadaltager',
    'Schedar (EN)': 'en-US-Chirp3-HD-Schedar',
    'Sulafat (EN)': 'en-US-Chirp3-HD-Sulafat',
    'Umbriel (EN)': 'en-US-Chirp3-HD-Umbriel',
    'Vindemiatrix (EN)': 'en-US-Chirp3-HD-Vindemiatrix',
    'Zephyr (EN)': 'en-US-Chirp3-HD-Zephyr',
    'Zubenelgenubi (EN)': 'en-US-Chirp3-HD-Zubenelgenubi',
  };

  Map<String, String> get _currentVoiceOptions {
    return _selectedLanguage == 'Indonesian'
        ? _indonesianVoiceOptions
        : _englishVoiceOptions;
  }

  @override
  void initState() {
    super.initState();
    // [LOGIKA BARU] Isi controller dengan data awal jika ada
    if (widget.initialTitle.isNotEmpty) {
      _titleController.text = widget.initialTitle;
    }
    if (widget.initialScript.isNotEmpty) {
      _scriptController.text = widget.initialScript;
    }

    _scriptController.addListener(() {
      setState(() {});
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

      final firestoreService = ref.read(firestoreServiceProvider);
      try {
        final String? newProjectId = await firestoreService.addProject(
          title: _titleController.text,
          rawScript: _scriptController.text,
          imageStyle: _selectedStyle,
          aspectRatio: _selectedAspectRatio,
          language: _selectedLanguage,
          voice: _selectedVoice,
        );

        if (mounted) {
          if (newProjectId != null && newProjectId.isNotEmpty) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => ProjectLoadingScreen(
                  projectId: newProjectId,
                ),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text(
                      'Error: Failed to create project ID. Please try again.'),
                  backgroundColor: Colors.red),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Error adding project: $e'),
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
    final currentVoiceOptions = _currentVoiceOptions;

    // [KATEGORI_KEAMANAN] Ambil data User & Config dari Provider
    final userAsync = ref.watch(firestoreUserProvider);
    final configAsync = ref.watch(appConfigProvider);

    // [KATEGORI_KEAMANAN] Kalkulasi Biaya & Validasi
    final int textLength = _scriptController.text.trim().length;
    // Asumsi 150 karakter = 1 scene
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
      costPerScene = config.costs.motion_per_scene;
      configReady = true;
    });

    final int requiredTokens = estimatedScenes * costPerScene;
    final bool hasSufficientFunds = currentBalance >= requiredTokens;
    final bool hasInput = textLength > 0;
    
    // Tombol aktif jika: Ada input, Saldo Cukup, Tidak Loading, Data Siap
    final bool canSubmit = hasInput && hasSufficientFunds && !_isLoading && userReady && configReady;

    return Theme(
      data: AppTheme.darkTheme,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('VMotion'),
          // [BARU] Tampilan Token di Header Kanan Atas
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
                      // Merah jika saldo kurang, Putih transparan jika cukup
                      color: hasInput && !hasSufficientFunds 
                          ? Colors.redAccent 
                          : Colors.white24,
                      width: 1
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.token, 
                        size: 16, 
                        color: hasInput && !hasSufficientFunds 
                            ? Colors.redAccent 
                            : Colors.amber
                      ),
                      const SizedBox(width: 8),
                      Text(
                        // Format: Required / Balance (Misal: 100 / 5000)
                        "$requiredTokens / $currentBalance", 
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: hasInput && !hasSufficientFunds 
                              ? Colors.redAccent 
                              : Colors.white,
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
                // --- Input Judul Proyek ---
                TextFormField(
                  controller: _titleController,
                  maxLength: 40,
                  decoration: const InputDecoration(
                    labelText: 'Project Title',
                    hintText: 'e.g., "My First Explainer Video"',
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

                // --- Input Narration ---
                TextFormField(
                  controller: _scriptController,
                  maxLines: 10,
                  maxLength: 18000,
                  decoration: const InputDecoration(
                    labelText: 'Narration',
                    hintText: 'Paste or type your full video Narration here...',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a Narration for your video.';
                    }
                    if (value.length > 18000) {
                      return 'Narration cannot exceed 18,000 characters.';
                    }
                    return null;
                  },
                ),
                
                // [DIHAPUS] Panel Informasi Token yang lama sudah dihilangkan.

                const SizedBox(height: 24),

                // --- Dropdown Visual Style ---
                DropdownButtonFormField<String>(
                  value: _selectedStyle,
                  decoration: const InputDecoration(
                    labelText: 'Visual Style',
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

                // --- Baris Bahasa & Tipe Vokal ---
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedLanguage,
                        decoration: const InputDecoration(
                          labelText: 'Language',
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
                              _selectedVoice =
                                  (_selectedLanguage == 'Indonesian')
                                      ? _defaultIndonesianVoice
                                      : _defaultEnglishVoice;
                              if (!_currentVoiceOptions
                                  .containsValue(_selectedVoice)) {
                                _selectedVoice =
                                    _currentVoiceOptions.values.first;
                              }
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedVoice,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Voice Type (${currentVoiceOptions.length})',
                        ),
                        items: currentVoiceOptions.entries.map((entry) {
                          return DropdownMenuItem<String>(
                            value: entry.value,
                            child: Text(entry.key, overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedVoice = value);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // --- Aspect Ratio ---
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

                // --- Tombol Submit (Process) ---
                ElevatedButton.icon(
                  onPressed: canSubmit ? _submitData : null,
                  icon: _isLoading
                      ? const SizedBox.shrink()
                      : const Icon(Icons.auto_awesome),
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
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[800],
                    disabledForegroundColor: Colors.grey[500],
                  ),
                ),
                // Pesan Error Kecil di Bawah Tombol jika saldo kurang
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