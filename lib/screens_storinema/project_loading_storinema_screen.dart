//................................................................//
// NAMA FILE: PROJECT_LOADING_STORINEMA_SCREEN.DART               //
// PATH: LIB/SCREENS_STORINEMA/PROJECT_LOADING_STORINEMA_SCREEN.DART//
// DESKRIPSI: LAYAR LOADING OTOMATIS (AUTO-REDIRECT) STORINEMA    //
//................................................................//

//No ke-1: IMPORT DEPENDENSI .....................................//
//................................................................//
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models_storinema/video_project_storinema.dart';
import '../providers_storinema/timeline_storinema_providers.dart'; 
import '../screens_storinema/timeline_review_storinema_screen.dart';
//................................................................//

//No ke-2: MODEL LOADING STAGE DAN KONFIGURASI ...................//
//................................................................//
class _LoadingStage {
  final String title;
  final String description;
  final IconData icon;
  final Set<String> technicalStatuses;

  const _LoadingStage({
    required this.title,
    required this.description,
    required this.icon,
    required this.technicalStatuses,
  });
}

final List<_LoadingStage> _loadingStages = [
  _LoadingStage(
    title: "Tahap 1: Script Analysis",
    description: "Analyzing scripts and creating scenes.",
    icon: Icons.auto_stories_outlined,
    technicalStatuses: {
      "PROCESSING_SCENE",
      "PENDING_REFINEMENT", 
    },
  ),
  _LoadingStage(
    title: "Tahap 2: Visual Imagination",
    description: "Creating the visual scene plan.",
    icon: Icons.spellcheck_outlined,
    technicalStatuses: {
      "PROCESSING_REFINEMENT",
    },
  ),
  _LoadingStage(
    title: "Tahap 3: Generating Video",
    description: "Starting the video generation process.",
    icon: Icons.movie_creation_outlined,
    technicalStatuses: {
      "VIDEO_GENERATION",
      "QUEUED_FOR_VIDEO",
      "WAITING_AUDIO",
    },
  ),
  _LoadingStage(
    title: "Tahap 4: Awaiting Final Assets",
    description: "Collect and verify all completed video assets.",
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

  // [PERBAIKAN ANTI-REGRESI UI]: Menambahkan ASSETS_NEED_REFINEMENT agar animasi Stepper 
  // langsung melompat ke garis finish 100% sebelum pindah layar, sehingga user tidak merasa nyangkut.
  if (status == "ASSETS_COMPLETE" || 
      status == "ASSETS_NEED_REFINEMENT" || 
      status == "CREATE_RENDER_PACKET" || 
      status == "RENDER_READY" || 
      status == "RENDER_START" || 
      status == "RENDERING" || 
      status == "RENDER_COMPLETED") {
    return _loadingStages.length;
  }

  if (status.startsWith("ERROR_")) {
    return -2; // Indikator khusus untuk trigger redirect pada error fatal
  }
  
  return 0; 
}
//................................................................//

//No ke-3: CLASS UTAMA PROJECT LOADING SCREEN (AUTO-REDIRECT) ....//
//................................................................//
class ProjectLoadingStorinemaScreen extends ConsumerStatefulWidget {
  final String projectId;

  const ProjectLoadingStorinemaScreen({
    super.key,
    required this.projectId,
  });

  @override
  ConsumerState<ProjectLoadingStorinemaScreen> createState() => _ProjectLoadingStorinemaScreenState();
}

class _ProjectLoadingStorinemaScreenState extends ConsumerState<ProjectLoadingStorinemaScreen> {
  bool _isMounted = false;
  bool _hasRedirected = false; // Mencegah navigasi ganda

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

  /// Fungsi Mandor Navigasi Otomatis
  void _triggerAutoRedirect() {
    if (_isMounted && !_hasRedirected) {
      _hasRedirected = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => TimelineReviewStorinemaScreen(projectId: widget.projectId),
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final projectAsync = ref.watch(projectStorinemaStreamProvider(widget.projectId));

    return projectAsync.when(
      loading: () => const Scaffold( 
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text("Menghubungkan ke sistem Storinema...", style: TextStyle(fontSize: 16)),
            ],
          ),
        ),
      ),
      error: (error, stack) {
        // Jika terjadi error koneksi stream, tetap redirect ke timeline agar user bisa me-refresh di sana
        _triggerAutoRedirect();
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
      data: (project) { 
        if (project == null) return const Scaffold(body: Center(child: Text("Project not found")));

        final String? currentStatus = project.status;
        final int currentStageIndex = _getStageIndexFromStatus(currentStatus);

        // [PERBAIKAN LOGIKA] LOGIKA AUTO-REDIRECT 1: Aset Lengkap atau Butuh Regenerasi Manual
        final bool isReadyToProceed = currentStatus == "ASSETS_COMPLETE" || 
                                      currentStatus == "ASSETS_NEED_REFINEMENT" || // [SUNTIKAN PENGAMAN BARU]
                                      currentStatus == "CREATE_RENDER_PACKET" || 
                                      currentStatus == "RENDER_READY" || 
                                      currentStatus == "RENDER_START" || 
                                      currentStatus == "RENDERING" || 
                                      currentStatus == "RENDER_COMPLETED";

        // [PERBAIKAN LOGIKA] LOGIKA AUTO-REDIRECT 2: Terjadi Error Fatal Proyek (Misal: Ekstraksi LLM Gagal total)
        // Kita tidak lagi menggunakan startsWith("ERROR_") agar tidak bocor saat proses video Bytedance.
        final bool isFatalError = currentStatus == "ERROR_SCENE" || 
                                  currentStatus == "ERROR_TRIGGER";

        if (isReadyToProceed || isFatalError) {
          _triggerAutoRedirect();
        }

        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            automaticallyImplyLeading: false,
            title: const Text(
              "Preparing the Project...", 
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            centerTitle: true,
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Center(
                  child: Text(
                    "Your video is being processed", 
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "This process may take a few minutes. You will be redirected automatically once the assets are ready.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: Colors.grey),
                ),
                const SizedBox(height: 32),
                const Center(
                  child: CircularProgressIndicator(),
                ),
                const SizedBox(height: 32),

                Stepper(
                  physics: const NeverScrollableScrollPhysics(), // User tidak perlu scroll stepper
                  controlsBuilder: (context, details) => const SizedBox.shrink(),
                  currentStep: currentStageIndex >= _loadingStages.length 
                      ? _loadingStages.length - 1 
                      : (currentStageIndex < 0 ? 0 : currentStageIndex),
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
                        stage.title,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(stage.description, style: const TextStyle(fontSize: 14)),
                      content: const SizedBox.shrink(),
                      isActive: index == currentStageIndex,
                      state: state,
                    );
                  }),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text("Batal & Kembali ke Dashboard"),
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
//................................................................//