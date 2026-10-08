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
import '../services/firestore_service.dart'; // [BARU] Akses logging Firestore User Center
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
- [USER CENTER] Logging aktivitas fitur (visit & conversion) untuk 'auto_movie'.
*/
//................................................................//

//No ke-2.........................................................//
// SETUP STATE DAN MAPS OPSI VEO                                  //
class InputScriptVeoScreen extends ConsumerStatefulWidget {
  final String initialTitle;
  final String initialScript;

  const InputScriptVeoScreen({
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
  
  // [DATA RESOLUSI & KUALITAS MODEL VEO 3.1]
  String _selectedResolution = '720p'; 
  String _selectedQuality = 'Standard'; // Standard (Fast) vs High (Quality)
  bool _isLoading = false;

  // [BARU]: State Tombol ON/OFF Project Title Overlay (Secara Default ON)
  bool _showTitle = true;
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

    // --- [LOG AKTIVITAS FITUR: KUNJUNGAN HALAMAN (VISIT)] ---
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(firestoreServiceProvider).logFeatureActivity(
          featureKey: 'auto_movie',
          eventType: 'visit',
        );
      }
    });
    // --------------------------------------------------------
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
      final isIndo = ref.read(appLanguageProvider).languageCode == 'id';

      // Jika toggle _showTitle bernilai false, gunakan input yang ada atau default judul proyek
      final String effectiveTitle = _showTitle 
          ? _titleController.text.trim() 
          : (_titleController.text.trim().isNotEmpty 
              ? _titleController.text.trim() 
              : 'VMovie Project');

      try {
        final String? newProjectId = await firestoreService.addProject(
          title: effectiveTitle,
          rawScript: _scriptController.text,
          imageStyle: _selectedStyle, 
          aspectRatio: _selectedAspectRatio,
          resolution: _selectedResolution, 
          quality: _selectedQuality, // Meneruskan Quality (Standard/High)
          showTitle: _showTitle, // [BARU] Meneruskan status ON/OFF Title Overlay
        );

        if (mounted) {
          if (newProjectId != null && newProjectId.isNotEmpty) {
            // --- [LOG AKTIVITAS FITUR: KONVERSI SUKSES (CONVERSION)] ---
            ref.read(firestoreServiceProvider).logFeatureActivity(
              featureKey: 'auto_movie',
              eventType: 'conversion',
            );
            // -----------------------------------------------------------

            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => ProjectLoadingVeoScreen(
                  projectId: newProjectId,
                ),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  isIndo
                      ? 'Error: Gagal membuat ID proyek (VEO). Silakan coba lagi.'
                      : 'Error: Failed to create project ID (VEO). Please try again.',
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isIndo
                    ? 'Terjadi kesalahan saat menambah proyek (VEO): $e'
                    : 'Error adding project (VEO): $e',
              ),
              backgroundColor: Colors.red,
            ),
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

    // [PERBAIKAN PRESISI SEGMEN: 1 KALIMAT = 1 ADEGAN (SINKRON DENGAN BACKEND)]
    final String textInput = _scriptController.text.trim();
    final int textLength = textInput.length;
    
    // 1. Hitung jumlah kalimat berdasarkan tanda baca (. ! ?)
    final int sentenceCount = RegExp(r'[.!?]+').allMatches(textInput).length;
    
    // 2. Estimasi presisi AI (1 Kalimat = 1 Adegan / Segmen sesuai Backend)
    int estimatedScenes = sentenceCount;
    
    // 3. Fallback: Jika pengguna mengetik tanpa tanda baca, gunakan rasio 100 karakter/segmen
    if (estimatedScenes == 0 && textLength > 0) {
      estimatedScenes = (textLength / 100).ceil();
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

    // [KALKULASI HARGA DINAMIS VEO PER-SEGMEN (STANDARD & HIGH)]
    configAsync.whenData((config) {
      final veoCosts = config.costs.veoCosts;
      
      if (_selectedQuality == 'High') {
        if (_selectedResolution == '1080p') {
          costPerScene = veoCosts.highPerSegment1080p; // High 1080p (Fallback: 7500)
        } else {
          costPerScene = veoCosts.highPerSegment720p;  // High 720p (Fallback: 7200)
        }
      } else {
        // Standard Quality (Default)
        if (_selectedResolution == '1080p') {
          costPerScene = veoCosts.standardPerSegment1080p; // Standard 1080p (Fallback: 3000)
        } else {
          costPerScene = veoCosts.standardPerSegment720p;  // Standard 720p (Fallback: 2700)
        }
      }
      
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
          title: const Text('VMovie'),
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
                        // --- [1. TOGGLE ON/OFF PROJECT TITLE OVERLAY (DI ATAS BOX JUDUL)] ---
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _showTitle ? Colors.purple.withOpacity(0.5) : Colors.white12,
                            ),
                          ),
                          child: SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              t('Project Title Overlay', 'Judul Overlay Proyek'),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            subtitle: Text(
                              _showTitle
                                  ? t('Overlay title is ON (Default)', 'Judul overlay AKTIF (Default)')
                                  : t('Overlay title is OFF', 'Judul overlay NONAKTIF'),
                              style: TextStyle(
                                color: _showTitle ? Colors.purpleAccent : Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                            value: _showTitle,
                            activeColor: Colors.purpleAccent,
                            onChanged: (val) {
                              setState(() => _showTitle = val);
                            },
                          ),
                        ),

                        // Input judul hanya aktif dan wajib diisi jika toggle ON (Menghilang jika OFF)
                        if (_showTitle) ...[
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _titleController,
                            maxLength: 40,
                            decoration: InputDecoration(
                              labelText: t('Project Title', 'Judul Proyek'),
                              hintText: t('e.g., "My First Veo Video"', 'Cth: "Video Veo Pertamaku"'),
                            ),
                            validator: (value) {
                              if (_showTitle && (value == null || value.trim().isEmpty)) {
                                return t('Please enter a project title.', 'Mohon isi judul proyek.');
                              }
                              if (value != null && value.length > 40) {
                                return t('Title cannot exceed 40 characters.', 'Judul maksimal 40 karakter.');
                              }
                              return null;
                            },
                          ),
                        ],
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

                        // Row untuk Visual Style & Aspect Ratio sejajar
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

                        // Row untuk Video Resolution & Quality sejajar
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _selectedResolution,
                                decoration: InputDecoration(
                                  labelText: t('Video Resolution', 'Resolusi Video'),
                                ),
                                items: const {
                                  '720p': '720p',
                                  '1080p': '1080p',
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
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _selectedQuality,
                                decoration: InputDecoration(
                                  labelText: t('Quality', 'Kualitas Model'),
                                ),
                                items: const {
                                  'Standard': 'Standard',
                                  'High': 'High',
                                }
                                    .entries
                                    .map((entry) => DropdownMenuItem(
                                          value: entry.value,
                                          child: Text(entry.key),
                                        ))
                                    .toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() => _selectedQuality = value);
                                  }
                                },
                              ),
                            ),
                          ],
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

              // --- POP UP ANIMASI TOKEN HABIS (BILINGUAL) ---
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
                        Expanded(
                          child: Text(
                            t(
                              "Out of tokens. Upgrade or add more via the dashboard!",
                              "Token habis. Isi ulang atau tingkatkan via dashboard!"
                            ),
                            style: const TextStyle(
                              color: Colors.white, 
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