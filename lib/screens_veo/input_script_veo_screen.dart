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
[RILIS BERSIH - INPUT SCRIPT VEO: RESOLUTION & COMPACT LAYOUT]
KATEGORI_FITUR_UTAMA NO_URUT_07
Tujuan:
- [DATA] Menerima data lemparan (Title/Script).
- [LOGIC] Menggunakan Provider VEO (Footage). Mengirim parameter resolusi (720p/1080p).
- [UI] Layout Compact: Style & Aspect Ratio sejajar, Resolusi di bawahnya. Bahasa dihapus (Auto-detect di backend).
- [NEW FEATURE] Pop up animasi peringatan token habis bergaya modern (Hijau/Putih).
- [ANTI-REGRESI] Menjaga seluruh kalkulasi token Veo (footagePerScene) dan fungsi database.
*/
//................................................................//

//No ke-2.........................................................//
// SETUP STATE DAN MAPS OPSI VEO                                  //
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
  
  // [DATA BARU] Menggantikan Bahasa dengan Resolusi, Default 720p
  String _selectedResolution = '720p'; 
  bool _isLoading = false;

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
          resolution: _selectedResolution, // [MODIFIKASI] Lempar parameter resolusi
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

    // [PERBAIKAN ESTIMASI SEGMEN] - Kombinasi Tanda Baca & 200 Karakter
    final String textInput = _scriptController.text.trim();
    final int textLength = textInput.length;
    
    // 1. Hitung jumlah kalimat berdasarkan tanda baca (. ! ?)
    final int sentenceCount = RegExp(r'[.!?]+').allMatches(textInput).length;
    
    // 2. Estimasi awal AI (Backend membagi 2 kalimat = 1 Segmen)
    int estimatedScenes = (sentenceCount / 2).ceil();
    
    // 3. Fallback: Jika pengguna mengetik tanpa tanda baca, gunakan rasio 200 karakter/segmen
    if (estimatedScenes == 0 && textLength > 0) {
      estimatedScenes = (textLength / 200).ceil();
    }
    
    // 4. Pastikan minimal selalu 1 adegan selama ada teks
    if (estimatedScenes < 1 && textLength > 0) {
      estimatedScenes = 1;
    }

    int currentBalance = 0;
    int costPerScene = 0;
    bool configReady = false;
    bool userReady = false;

    userAsync.whenData((user) {
      currentBalance = user.tokenBalance;
      userReady = true;
    });

    // [PERBAIKAN ANTI-REGRESI] Kalkulasi Token Veo Dinamis Sesuai Backend
    configAsync.whenData((config) {
      int costPerSecond = config.costs.veoCosts.res720;
      if (_selectedResolution == '1080p') {
        costPerSecond = config.costs.veoCosts.res1080;
      }
      
      // 1 adegan (scene) Veo mutlak berdurasi 8 detik
      costPerScene = costPerSecond * 8;
      configReady = true;
    });

    final int requiredTokens = estimatedScenes * costPerScene;
    final bool hasSufficientFunds = currentBalance >= requiredTokens;
    final bool hasInput = textLength > 0;

    // Logika validasi pop up peringatan token
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
                            hintText: t('Exp: Prophet Sulaiman (Solomon) was the son of Prophet Daud (David), blessed with an unparalleled kingdom on earth. He is renowned as a wise king and a prophet gifted with extraordinary miracles: the ability to speak to animals, command the jinn, and control the wind. The most popular tale is his encounter with Queen Bilqis of the Kingdom of Sheba. It began when the Hud-hud bird reported a land where the people worshiped the sun. Sulaiman sent a letter of faith, carried by the bird. The wonder peaked when Queen Bilqiss throne was transported to Sulaimans palace in the blink of an eye by a man of great knowledge. Upon seeing the magnificence of the palace—with its floor of crystal clear glass over water—the Queen surrendered herself to Allah....', 'Contoh: Nabi Sulaiman AS adalah putra Nabi Daud AS yang dianugerahi kekuasaan tak tertandingi di bumi. Beliau dikenal sebagai raja yang bijaksana dan nabi yang memiliki mukjizat luar biasa: mampu berbicara dengan hewan, memerintah bangsa jin, serta mengendalikan angin. Kisah paling populer adalah pertemuannya dengan Ratu Balqis dari Kerajaan Saba. Berawal dari laporan burung Hud-hud tentang negeri yang menyembah matahari, Sulaiman mengirim surat dakwah yang dibawa oleh burung tersebut. Keajaiban memuncak saat singgasana Ratu Balqis dipindahkan ke istana Sulaiman hanya dalam sekejap mata oleh seorang yang berilmu. Melihat kemegahan istana yang lantainya berupa kaca bening di atas air, sang ratu pun berserah diri kepada Allah....'),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return t('Please enter a script for your video.', 'Mohon isi narasi video.');
                            }
                            if (value.length > 15000) {
                              return t('Script cannot exceed 15,000 characters.', 'Narasi maksimal 15.000 karakter.');
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),

                        // [MODIFIKASI] Row untuk Visual Style & Aspect Ratio sejajar
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _selectedStyle,
                                decoration: InputDecoration(
                                  labelText: t('Visual Style', 'Gaya Visual'),
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
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _selectedAspectRatio,
                                decoration: InputDecoration(
                                  labelText: t('Aspect Ratio', 'Rasio Aspek'),
                                ),
                                items: const {
                                  '16:9': '16:9',
                                  '9:16': '9:16',
                                  '1:1': '1:1',
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
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // [DATA BARU] Dropdown Resolusi di bawahnya
                        DropdownButtonFormField<String>(
                          value: _selectedResolution,
                          decoration: InputDecoration(
                            labelText: t('Video Resolution', 'Resolusi Video'),
                          ),
                          items: const {
                            '720p (Standard)': '720p',
                            '1080p (High)': '1080p',
                          }
                              .entries
                              .map((entry) => DropdownMenuItem(
                                    value: entry.value,
                                    child: Text(entry.key),
                                  ))
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _selectedResolution = value);
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

              // --- POP UP ANIMASI TOKEN HABIS ---
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