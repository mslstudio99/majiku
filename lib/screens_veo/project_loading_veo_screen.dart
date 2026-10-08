//====================================================================================================//
// NAMA FILE: PROJECT_LOADING_VEO_SCREEN.DART                                                         //
// DIREKTORI: lib/screens_veo/project_loading_veo_screen.dart                                         //
//====================================================================================================//

//No ke-1: IMPORTS & DEPENDENCIES.....................................................................//
//Sub-judul: Deklarasi pustaka, provider, dan layar tujuan (Isolasi Veo)..............................//
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 

import '../models_veo/video_project_veo.dart';
import '../view_model_veo/timeline_veo_view_model.dart'; 
import 'timeline_review_veo_screen.dart';
import 'character_upload_veo_screen.dart';
import '../providers/config_provider.dart'; // [BILINGUAL]: Import provider bahasa
//Akhir Blok 1........................................................................................//


//No ke-2: LOADING STAGES MODEL & DATA................................................................//
//Sub-judul: Mendefinisikan tahapan loading untuk fase aset Veo (TERMASUK GAMBAR).....................//
class _LoadingStage {
  final String titleEn;
  final String titleId;
  final String descriptionEn;
  final String descriptionId;
  final IconData icon;
  final Set<String> technicalStatuses;

  const _LoadingStage({
    required this.titleEn,
    required this.titleId,
    required this.descriptionEn,
    required this.descriptionId,
    required this.icon,
    required this.technicalStatuses,
  });
}

// [BILINGUAL]: Data tahapan dipisahkan menjadi versi EN dan ID
final List<_LoadingStage> _loadingStages = [
  _LoadingStage(
    titleEn: "Stage 1: Script & Character Analysis",
    titleId: "Tahap 1: Analisis Naskah & Karakter",
    descriptionEn: "Analyzing scripts and extracting characters.",
    descriptionId: "Menganalisis naskah dan mengekstrak karakter.",
    icon: Icons.auto_stories_outlined,
    technicalStatuses: {
      "PROCESSING_SCENE",
      "WAITING_USER_IMAGE", 
      "READY_FOR_IMAGE_GEN", 
      "PROCESSING_IMAGES_IN_PROGRESS", 
      "PENDING_REFINEMENT", 
    },
  ),
  _LoadingStage(
    titleEn: "Stage 2: Visual Imagination",
    titleId: "Tahap 2: Imajinasi Visual",
    descriptionEn: "Creating the visual scene plan.",
    descriptionId: "Membuat rencana adegan visual.",
    icon: Icons.spellcheck_outlined,
    technicalStatuses: {
      "PROCESSING_REFINEMENT",
    },
  ),
  _LoadingStage(
    titleEn: "Stage 3: Generating Video",
    titleId: "Tahap 3: Pembuatan Video",
    descriptionEn: "Starting the video generation process.",
    descriptionId: "Memulai proses pembuatan video.",
    icon: Icons.movie_creation_outlined,
    technicalStatuses: {
      "VIDEO_GENERATION",
    },
  ),
  _LoadingStage(
    titleEn: "Stage 4: Awaiting Final Assets",
    titleId: "Tahap 4: Menunggu Aset Final",
    descriptionEn: "Collect and verify all completed video assets.",
    descriptionId: "Mengumpulkan dan memverifikasi semua aset video yang selesai.",
    icon: Icons.inventory_2_outlined,
    technicalStatuses: {
      "COMPLETING_ASSETS",
    },
  ),
];

int _getStageIndexFromStatus(String? status) {
  if (status == null) return 0;
  for (int i = 0; i < _loadingStages.length; i++) {
    if (_loadingStages[i].technicalStatuses.contains(status)) {
      return i;
    }
  }

  // [ANTI-STUCK]: Menambahkan ASSETS_NEED_REFINEMENT agar dianggap tahap selesai
  if (status == "ASSETS_COMPLETE" || 
      status == "ASSETS_NEED_REFINEMENT" || 
      status == "RENDER_READY" || 
      status == "RENDER_START" || 
      status == "RENDERING" || 
      status == "RENDER_COMPLETED") {
    return _loadingStages.length;
  }
  
  if (status.startsWith("ERROR_")) return -1;
  return 0; 
}
//Akhir Blok 2........................................................................................//


//No ke-3: MAIN CLASS & STATE INITIALIZATION..........................................................//
//Sub-judul: Deklarasi stateful widget dan pengunci navigasi independen...............................//
class ProjectLoadingVeoScreen extends ConsumerStatefulWidget {
  final String projectId;

  const ProjectLoadingVeoScreen({
    super.key,
    required this.projectId,
  });

  @override
  ConsumerState<ProjectLoadingVeoScreen> createState() => _ProjectLoadingVeoScreenState();
}

class _ProjectLoadingVeoScreenState extends ConsumerState<ProjectLoadingVeoScreen> {
  bool _isMounted = false;
  
  // [PERBAIKAN KUNCI]: Memisahkan flag dialog dan flag navigasi timeline agar tidak saling mengunci
  bool _hasShownUploadDialog = false;
  bool _hasNavigatedToTimeline = false;

  // [BILINGUAL]: Helper penerjemah
  String _t(bool isIndo, String en, String id) {
    return isIndo ? id : en;
  }

  @override
  void initState() {
    super.initState();
    _isMounted = true;
  }

  @override
  void dispose() {
    _isMounted = false;
    super.dispose();
  }
//Akhir Blok 3........................................................................................//

//No ke-4: BUILD METHOD & GATEKEEPER ROUTING LOGIC....................................................//
//Sub-judul: Memantau stream, mengeksekusi perpindahan layar saat aset selesai atau bermasalah........//
  @override
  Widget build(BuildContext context) {
    final projectAsync = ref.watch(projectVeoStreamProvider(widget.projectId));
    
    // [BILINGUAL]: Mendapatkan bahasa saat ini
    final currentLocale = ref.watch(appLanguageProvider);
    final isIndo = currentLocale.languageCode == 'id';

    return projectAsync.when(
      loading: () => Scaffold( 
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                _t(isIndo, "Loading Veo project status...", "Memuat status proyek Veo..."),
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      ),
      error: (error, stack) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 60),
                const SizedBox(height: 16),
                Text(
                  _t(isIndo, "Failed to load Veo project", "Gagal memuat proyek Veo"), 
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                Text(
                  error.toString(),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(_t(isIndo, "Back", "Kembali")),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (project) { 
        if (project == null) {
          return Scaffold(
            appBar: AppBar(title: const Text("Error")),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  _t(isIndo, "Error: Project data stream (VEO) returned null.", "Error: Data stream proyek (VEO) kosong."),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        final String? currentStatus = project.status;
        final int currentStageIndex = _getStageIndexFromStatus(currentStatus);

        // --- [SKENARIO 0: JEDA WAITING_USER_IMAGE] ---
        if (currentStatus == "WAITING_USER_IMAGE" && !_hasShownUploadDialog) {
          _hasShownUploadDialog = true; 
          
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_isMounted) {
              debugPrint("🛑 [Loading Gatekeeper VEO] Jeda Ekstraksi Selesai. Menampilkan Jendela Upload Karakter...");
              
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (BuildContext dialogContext) {
                  return AlertDialog(
                    backgroundColor: const Color(0xFF1E1C2A), 
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: Colors.purpleAccent, width: 1),
                    ),
                    title: Text(
                      _t(isIndo, "Character Extraction Complete", "Ekstraksi Karakter Selesai"), 
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white, 
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    content: Text(
                      _t(isIndo, 
                        "We have identified the characters from your narrative.\n\nWould you like to manually upload their face images, or let our AI design them automatically?", 
                        "Kami telah mengidentifikasi karakter dari narasi Anda.\n\nApakah Anda ingin mengunggah gambar wajah mereka secara manual, atau biarkan AI kami yang mendesainnya secara otomatis?"
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70, 
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                    actionsAlignment: MainAxisAlignment.center,
                    actions: [
                      // Tombol 1: Unggah Sendiri
                      OutlinedButton(
                        onPressed: () async {
                          Navigator.of(dialogContext, rootNavigator: true).pop();
                          
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => CharacterUploadVeoScreen(
                                projectId: widget.projectId,
                                project: project,
                              ),
                            ),
                          );

                          if (_isMounted) {
                            setState(() { _hasShownUploadDialog = false; });
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.purpleAccent),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          _t(isIndo, "Upload Manually", "Unggah Sendiri"),
                          style: const TextStyle(
                            color: Colors.white, 
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Tombol 2: Auto AI
                      ElevatedButton(
                        onPressed: () async {
                          Navigator.of(dialogContext, rootNavigator: true).pop(); 
                          
                          try {
                            await FirebaseFirestore.instance
                                .collection('projects_veo')
                                .doc(widget.projectId)
                                .update({'status': 'READY_FOR_IMAGE_GEN'});
                          } catch (e) {
                            debugPrint("Gagal update status: $e");
                            if (_isMounted) setState(() { _hasShownUploadDialog = false; });
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          _t(isIndo, "Auto AI (Generate)", "Auto AI (Generate)"),
                          style: const TextStyle(
                            color: Colors.white, 
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            }
          });
        }

        // --- SKENARIO 1: HAPPY PATH (SEMUA ASET SELESAI / REGENERATE SELESAI / RENDER SELESAI) ---
        // [ANTI-STUCK]: Menambahkan ASSETS_NEED_REFINEMENT agar langsung meluncur ke Timeline
        if ((currentStatus == "ASSETS_COMPLETE" || 
             currentStatus == "ASSETS_NEED_REFINEMENT" || 
             currentStatus == "RENDER_READY" || 
             currentStatus == "RENDER_START" || 
             currentStatus == "RENDERING" || 
             currentStatus == "RENDER_COMPLETED") && !_hasNavigatedToTimeline) {
          _hasNavigatedToTimeline = true; 
          
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_isMounted) {
              debugPrint("🚀 [Loading Gatekeeper VEO] Aset Siap ($currentStatus). Meneruskan ke Timeline...");
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => TimelineReviewVeoScreen(projectId: widget.projectId),
                ),
              );
            }
          });
        }
        
        // --- SKENARIO 2: ERROR/FALLBACK PATH (MANUAL REFINEMENT) ---
        if ((currentStatus != null && currentStatus.startsWith("ERROR_")) && !_hasNavigatedToTimeline) {
          _hasNavigatedToTimeline = true; 
          
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_isMounted) {
              debugPrint("⚠️ [Loading Gatekeeper VEO] Masalah aset terdeteksi. Melempar ke Timeline untuk Manual Fallback.");
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    _t(isIndo, 
                      "Some assets failed to process. Please fix them manually in the Timeline.", 
                      "Terdapat aset yang gagal diproses. Silakan perbaiki secara manual di Timeline."
                    )
                  ),
                  backgroundColor: Colors.redAccent,
                  duration: const Duration(seconds: 5),
                ),
              );
              
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => TimelineReviewVeoScreen(projectId: widget.projectId),
                ),
              );
            }
          });
        }
        
        if (currentStageIndex == -1 && !_hasNavigatedToTimeline) {
          return _buildErrorUI(context, project, isIndo); 
        }

        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            automaticallyImplyLeading: false,
            title: Text(
              _t(isIndo, "Preparing the Project...", "Mempersiapkan Proyek..."), 
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            centerTitle: true,
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Center(
                  child: Text(
                    _t(isIndo, "Your video is being processed, please wait...", "Video Anda sedang diproses, mohon tunggu..."), 
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _t(isIndo, 
                    "This process may take a few minutes. Keep this page open until rendering begins.", 
                    "Proses ini mungkin memakan waktu beberapa menit. Tetap buka halaman ini hingga rendering dimulai."
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15, color: Colors.grey),
                ),
                const SizedBox(height: 32),
                const Center(
                  child: CircularProgressIndicator(),
                ),
                const SizedBox(height: 32),

                Expanded(
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      canvasColor: Colors.transparent,
                    ),
                    child: Stepper(
                      controlsBuilder: (context, details) => const SizedBox.shrink(),
                      currentStep: currentStageIndex >= _loadingStages.length ? _loadingStages.length - 1 : currentStageIndex,
                      steps: List.generate(_loadingStages.length, (index) {
                        final stage = _loadingStages[index];
                        StepState state = StepState.disabled;

                        if (index < currentStageIndex) {
                          state = StepState.complete;
                        } else if (index == currentStageIndex) {
                          state = StepState.indexed;
                        }

                        if (currentStageIndex >= _loadingStages.length) {
                          state = StepState.complete;
                        }

                        return Step(
                          title: Text(
                            _t(isIndo, stage.titleEn, stage.titleId),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            (currentStatus == "PROCESSING_IMAGES_IN_PROGRESS" && index == 0) 
                              ? _t(isIndo, "Generating AI characters...", "Membuat karakter AI...")
                              : _t(isIndo, stage.descriptionEn, stage.descriptionId), 
                            style: const TextStyle(fontSize: 14)
                          ),
                          content: const SizedBox.shrink(),
                          isActive: index == currentStageIndex || index < currentStageIndex,
                          state: state,
                        );
                      }),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text(_t(isIndo, "Back to Dashboard", "Kembali ke Dashboard")),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
//Akhir Blok 4........................................................................................//

//No ke-5: ERROR UI HELPER............................................................................//
//Sub-judul: Fungsi pembangunan UI jika terjadi error fatal sebelum masuk ke Timeline...................//
  Widget _buildErrorUI(BuildContext context, VideoProjectVeo project, bool isIndo) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 60),
              const SizedBox(height: 16),
              Text(
                _t(isIndo, "Veo Process Failed", "Proses Veo Gagal"), 
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                "${_t(isIndo, 'An error occurred at stage: ', 'Terjadi kesalahan pada tahap: ')}${project.status ?? 'Unknown'}",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                project.errorDetail ?? _t(isIndo, "No error details available.", "Tidak ada detail error."),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => TimelineReviewVeoScreen(projectId: widget.projectId),
                    ),
                  );
                },
                child: Text(_t(isIndo, "Go to Project", "Pergi ke Proyek")),
              ),
            ],
          ),
        ),
      ),
    );
  }
}   
//Akhir Blok 5........................................................................................//