//================================================================//
// NAMA FILE: PROJECT_LOADING_NARACINEMA_PLUS_SCREEN.DART         //
// DIREKTORI: LIB/SCREENS_NARACINEMA_PLUS/                        //
// DESKRIPSI: LAYAR LOADING MONOTONIK (ANTI-MUNDUR) NARACINEMA    //
//================================================================//

// No ke-1: IMPORT DEPENDENSI                                     //
//----------------------------------------------------------------//
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models_naracinema_plus/video_project_naracinema_plus.dart';
import '../providers_naracinema_plus/firestore_naracinema_plus_provider.dart';
import '../providers_naracinema_plus/timeline_naracinema_plus_providers.dart'; 
import '../screens_naracinema_plus/timeline_review_naracinema_plus_screen.dart';
import '../screens_naracinema_plus/character_upload_naracinema_plus_screen.dart';
import '../providers/config_provider.dart';
//----------------------------------------------------------------//

// No ke-2: MODEL LOADING STAGE DAN KONFIGURASI STATUS LENGKAP    //
//----------------------------------------------------------------//
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

// [4 TAHAP UTAMA SINKRON BACKEND]
final List<_LoadingStage> _loadingStages = [
  _LoadingStage(
    titleEn: "Stage 1: Script & Character Analysis",
    titleId: "Tahap 1: Analisis Naskah & Karakter",
    descriptionEn: "Analyzing story consistency and extracting character details.",
    descriptionId: "Menganalisis naskah, konsistensi cerita, dan mengekstrak karakter.",
    icon: Icons.auto_stories_outlined,
    technicalStatuses: {
      "PROCESSING_SCENE",
      "PENDING_REFINEMENT", 
      "WAITING_USER_IMAGE",
      "READY_FOR_IMAGE_GEN",
      "PROCESSING_IMAGES_IN_PROGRESS",
    },
  ),
  _LoadingStage(
    titleEn: "Stage 2: Voiceover & Audio Generation",
    titleId: "Tahap 2: Generasi Suara & Audio",
    descriptionEn: "Synthesizing voiceovers and calculating audio durations.",
    descriptionId: "Menghasilkan suara narasi dan mengalkulasi durasi audio.",
    icon: Icons.record_voice_over_outlined,
    technicalStatuses: {
      "AUDIO_GENERATION",
      "QUEUED_FOR_AUDIO",
      "IS_GENERATING_AUDIO",
    },
  ),
  _LoadingStage(
    titleEn: "Stage 3: Video AI Generation",
    titleId: "Tahap 3: Pembuatan Video AI (Veo)",
    descriptionEn: "Generating high-definition cinematic video scenes.",
    descriptionId: "Membuat adegan video AI sinematik beresolusi tinggi.",
    icon: Icons.movie_creation_outlined,
    technicalStatuses: {
      "VIDEO_GENERATION",
      "QUEUED_FOR_VIDEO",
      "GENERATING_VIDEO",
      "WAITING_AUDIO",
    },
  ),
  _LoadingStage(
    titleEn: "Stage 4: Asset Verification & Packaging",
    titleId: "Tahap 4: Verifikasi Aset & Perakitan",
    descriptionEn: "Verifying completed video assets and assembling the render package.",
    descriptionId: "Memverifikasi aset video yang selesai dan merakit paket render.",
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

  // Jika status sudah masuk tahap Render atau Selesai
  if (status == "ASSETS_COMPLETE" || 
      status == "CREATE_RENDER_PACKET" || 
      status == "RENDER_READY" || 
      status == "RENDER_START" || 
      status == "RENDERING" || 
      status == "RENDER_COMPLETED") {
    return _loadingStages.length;
  }

  if (status.startsWith("ERROR_")) {
    return -2; 
  }
  
  return 0; 
}
//----------------------------------------------------------------//


// No ke-3: CLASS UTAMA PROJECT LOADING SCREEN (MONOTONIC STEP)   //
//----------------------------------------------------------------//
class ProjectLoadingNaracinemaPlusScreen extends ConsumerStatefulWidget {
  final String projectId;

  const ProjectLoadingNaracinemaPlusScreen({
    super.key,
    required this.projectId,
  });

  @override
  ConsumerState<ProjectLoadingNaracinemaPlusScreen> createState() => _ProjectLoadingNaracinemaPlusScreenState();
}

class _ProjectLoadingNaracinemaPlusScreenState extends ConsumerState<ProjectLoadingNaracinemaPlusScreen> {
  bool _isMounted = false;
  bool _hasRedirected = false; 
  bool _isDialogOpenOrNavigating = false; // Guard mencegah dialog ganda atau tumpukan navigasi

  // [PENGUNCI MONOTONIK]: Menjamin stepper HANYA BISA MAJU, TIDAK BISA MUNDUR
  int _highestStageIndex = 0;

  String _t(bool isIndo, String en, String id) => isIndo ? id : en;

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

  /// Fungsi Navigasi Otomatis ke Timeline Review
  void _triggerAutoRedirect() {
    if (_isMounted && !_hasRedirected) {
      _hasRedirected = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => TimelineReviewNaracinemaPlusScreen(projectId: widget.projectId),
          ),
        );
      });
    }
  }

  /// Menangani pilihan pembuatan karakter otomatis oleh AI via Firestore Service
  Future<void> _handleAutoGenerateWithAI() async {
    try {
      await ref.read(firestoreNaracinemaPlusServiceProvider).updateProject(
        widget.projectId,
        {'status': 'READY_FOR_IMAGE_GEN'},
      );
    } catch (e) {
      debugPrint("[ProjectLoadingNaracinemaPlus] Error updating status for AI auto-gen: $e");
    }
  }

  /// Dialog Konfirmasi Pembuatan Karakter (AI vs Upload Manual)
  void _showCharacterCreationDialog(VideoProjectNaracinemaPlus project) {
    if (!_isMounted || _isDialogOpenOrNavigating) return;
    _isDialogOpenOrNavigating = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isMounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E222A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Colors.white12),
            ),
            title: const Text(
              "How would you like to create your character?",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
              textAlign: TextAlign.center,
            ),
            content: const Text(
              "You can choose to let AI generate consistent character portraits automatically, or upload your own reference photos.",
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            actions: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Opsi 1: Generate Otomatis dengan AI
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      _isDialogOpenOrNavigating = false;
                      _handleAutoGenerateWithAI();
                    },
                    icon: const Icon(Icons.auto_awesome, color: Colors.white),
                    label: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        "Generate Automatically with AI",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Opsi 2: Unggah Foto Sendiri
                  OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.of(dialogContext).pop();
                      // Buka halaman upload karakter
                      final result = await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => CharacterUploadNaracinemaPlusScreen(
                            projectId: widget.projectId,
                            project: project,
                          ),
                        ),
                      );

                      _isDialogOpenOrNavigating = false;

                      // Jika user membatalkan (Cancel) di halaman upload, munculkan kembali dialog
                      if (result == 'cancelled' && mounted) {
                        _showCharacterCreationDialog(project);
                      }
                    },
                    icon: const Icon(Icons.cloud_upload_outlined, color: Colors.blueAccent),
                    label: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        "Upload My Own File",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.blueAccent,
                        ),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.blueAccent),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final projectAsync = ref.watch(projectNaracinemaPlusStreamProvider(widget.projectId));
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
              Text(_t(isIndo, "Connecting to Naracinema Plus...", "Menghubungkan ke sistem Naracinema Plus..."), style: const TextStyle(fontSize: 16)),
            ],
          ),
        ),
      ),
      error: (error, stack) {
        _triggerAutoRedirect();
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
      data: (project) { 
        if (project == null) return const Scaffold(body: Center(child: Text("Project not found")));

        final String? currentStatus = project.status;
        final int calculatedStageIndex = _getStageIndexFromStatus(currentStatus);

        // [LOGIKA MONOTONIK ANTI-MUNDUR]: Hanya perbarui jika langkah baru lebih besar
        if (calculatedStageIndex > _highestStageIndex && calculatedStageIndex >= 0) {
          _highestStageIndex = calculatedStageIndex;
        }

        final int displayStepIndex = _highestStageIndex;

        // [DETEKSI JEDA UPLOAD KARAKTER]: Tampilkan dialog pilihan AI vs Upload Sendiri
        if (currentStatus == "WAITING_USER_IMAGE") {
          _showCharacterCreationDialog(project);
        }

        // LOGIKA AUTO-REDIRECT: Aset Selesai / Render Berjalan / Error
        final bool isReadyToProceed = currentStatus == "ASSETS_COMPLETE" || 
                                      currentStatus == "CREATE_RENDER_PACKET" || 
                                      currentStatus == "RENDER_READY" || 
                                      currentStatus == "RENDER_START" || 
                                      currentStatus == "RENDERING" || 
                                      currentStatus == "RENDER_COMPLETED";

        final bool isErrorDetected = currentStatus?.startsWith("ERROR_") ?? false;

        if (isReadyToProceed || isErrorDetected) {
          _triggerAutoRedirect();
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
                    _t(isIndo, "Your video is being processed", "Video Anda sedang diproses"), 
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _t(isIndo, 
                    "This process may take a few minutes. You will be redirected automatically once assets are ready.",
                    "Proses ini memakan waktu beberapa menit. Anda akan dialihkan otomatis saat video siap."
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
                  child: Stepper(
                    physics: const NeverScrollableScrollPhysics(),
                    controlsBuilder: (context, details) => const SizedBox.shrink(),
                    currentStep: displayStepIndex >= _loadingStages.length 
                        ? _loadingStages.length - 1 
                        : displayStepIndex,
                    steps: List.generate(_loadingStages.length, (index) {
                      final stage = _loadingStages[index];
                      StepState state = StepState.disabled;

                      if (index < displayStepIndex) {
                        state = StepState.complete;
                      } else if (index == displayStepIndex) {
                        state = StepState.indexed;
                      }

                      if (displayStepIndex >= _loadingStages.length) {
                        state = StepState.complete;
                      }

                      return Step(
                        title: Text(
                          _t(isIndo, stage.titleEn, stage.titleId),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          _t(isIndo, stage.descriptionEn, stage.descriptionId), 
                          style: const TextStyle(fontSize: 14)
                        ),
                        content: const SizedBox.shrink(),
                        isActive: index == displayStepIndex || index < displayStepIndex,
                        state: state,
                      );
                    }),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(_t(isIndo, "Back to Dashboard", "Kembali ke Dashboard")),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }
}
//----------------------------------------------------------------//