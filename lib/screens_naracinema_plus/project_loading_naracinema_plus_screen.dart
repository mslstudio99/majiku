//================================================================//
// NAMA FILE: PROJECT_LOADING_NARACINEMA_PLUS_SCREEN.DART         //
// DIREKTORI: LIB/SCREENS_NARACINEMA_PLUS/                        //
// DESKRIPSI: LAYAR LOADING OTOMATIS (AUTO-REDIRECT) NARACINEMA   //
//================================================================//

// No ke-1: IMPORT DEPENDENSI                                     //
//----------------------------------------------------------------//
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models_naracinema_plus/video_project_naracinema_plus.dart';
import '../providers_naracinema_plus/timeline_naracinema_plus_providers.dart'; 
import '../screens_naracinema_plus/timeline_review_naracinema_plus_screen.dart';
//----------------------------------------------------------------//

// No ke-2: MODEL LOADING STAGE DAN KONFIGURASI                   //
//----------------------------------------------------------------//
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
    description: "Processing the visual scene plan.",
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

  if (status == "ASSETS_COMPLETE" || 
      status == "CREATE_RENDER_PACKET" || 
      status == "RENDER_READY" || 
      status == "RENDER_START" || 
      status == "RENDERING" || 
      status == "RENDER_COMPLETED") {
    return _loadingStages.length;
  }

  if (status.startsWith("ERROR_")) {
    return -2; // Indikator khusus untuk trigger redirect pada error
  }
  
  return 0; 
}
//----------------------------------------------------------------//

// No ke-3: CLASS UTAMA PROJECT LOADING SCREEN (AUTO-REDIRECT)    //
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
            builder: (context) => TimelineReviewNaracinemaPlusScreen(projectId: widget.projectId),
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final projectAsync = ref.watch(projectNaracinemaPlusStreamProvider(widget.projectId));

    return projectAsync.when(
      loading: () => const Scaffold( 
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text("Menghubungkan ke sistem Naracinema Plus...", style: TextStyle(fontSize: 16)),
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

        // LOGIKA AUTO-REDIRECT 1: Aset Lengkap atau sedang proses render lanjutan
        final bool isReadyToProceed = currentStatus == "ASSETS_COMPLETE" || 
                                      currentStatus == "CREATE_RENDER_PACKET" || 
                                      currentStatus == "RENDER_READY" || 
                                      currentStatus == "RENDER_START" || 
                                      currentStatus == "RENDERING" || 
                                      currentStatus == "RENDER_COMPLETED";

        // LOGIKA AUTO-REDIRECT 2: Terjadi Error (Directly to Timeline Review)
        final bool isErrorDetected = currentStatus?.startsWith("ERROR_") ?? false;

        if (isReadyToProceed || isErrorDetected) {
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
//----------------------------------------------------------------//