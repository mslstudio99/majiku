//====================================================================================================//
// NAMA FILE: PROJECT_LOADING_VEO_SCREEN.DART                                                         //
// DIREKTORI: lib/screens_veo/project_loading_veo_screen.dart                                         //
//====================================================================================================//

//No ke-1: IMPORTS & DEPENDENCIES.....................................................................//
//Sub-judul: Deklarasi pustaka, provider, dan layar tujuan (Isolasi Veo)..............................//
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models_veo/video_project_veo.dart';
import '../view_model_veo/timeline_veo_view_model.dart'; 
import 'timeline_review_veo_screen.dart';
//Akhir Blok 1........................................................................................//


//No ke-2: LOADING STAGES MODEL & DATA................................................................//
//Sub-judul: Mendefinisikan 4 tahapan loading untuk fase aset Veo.....................................//
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

  if (status == "ASSETS_COMPLETE" || status == "RENDER_READY" || status == "RENDER_START" || status == "RENDERING" || status == "RENDER_COMPLETED") {
    return _loadingStages.length;
  }
  
  if (status.startsWith("ERROR_")) return -1;
  return 0; 
}
//Akhir Blok 2........................................................................................//


//No ke-3: MAIN CLASS & STATE INITIALIZATION..........................................................//
//Sub-judul: Deklarasi stateful widget dan pengunci navigasi ganda....................................//
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
  bool _hasNavigated = false;

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

    return projectAsync.when(
      loading: () => const Scaffold( 
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                "Memuat status proyek Veo...",
                style: TextStyle(fontSize: 16),
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
                  "Gagal memuat proyek Veo", 
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
                  child: const Text("Kembali"),
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
            body: const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  "Error: Project data stream (VEO) returned null.",
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        final String? currentStatus = project.status;
        final int currentStageIndex = _getStageIndexFromStatus(currentStatus);

        // --- SKENARIO 1: HAPPY PATH (SEMUA ASET SELESAI) ---
        if ((currentStatus == "ASSETS_COMPLETE" || currentStatus == "RENDER_READY" || currentStatus == "RENDER_START" || currentStatus == "RENDERING" || currentStatus == "RENDER_COMPLETED") && !_hasNavigated) {
          _hasNavigated = true; 
          
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_isMounted) {
              debugPrint("🚀 [Loading Gatekeeper VEO] Aset Selesai. Meneruskan ke Timeline...");
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => TimelineReviewVeoScreen(projectId: widget.projectId),
                ),
              );
            }
          });
        }
		
        // --- SKENARIO 2: ERROR/FALLBACK PATH (MANUAL REFINEMENT) ---
        if ((currentStatus != null && currentStatus.startsWith("ERROR_")) && !_hasNavigated) {
          _hasNavigated = true; 
          
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_isMounted) {
              debugPrint("⚠️ [Loading Gatekeeper VEO] Masalah aset terdeteksi. Melempar ke Timeline untuk Manual Fallback.");
              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Terdapat aset yang gagal diproses. Silakan perbaiki secara manual di Timeline.'),
                  backgroundColor: Colors.redAccent,
                  duration: Duration(seconds: 5),
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
        
        if (currentStageIndex == -1 && !_hasNavigated) {
          return _buildErrorUI(context, project); 
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
                    "Your video is being processed, wait a minutes..", 
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "This process may take a few minutes. Keep this page open until rendering begins.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: Colors.grey),
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
                            stage.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(stage.description, style: const TextStyle(fontSize: 14),),
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
                  child: const Text("Kembali ke Dashboard"),
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
  Widget _buildErrorUI(BuildContext context, VideoProjectVeo project) {
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
                "Proses Veo Gagal", 
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                "Terjadi kesalahan pada tahap: ${project.status ?? 'Unknown'}",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                project.errorDetail ?? "Tidak ada detail error.",
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
                child: const Text("Pergi ke Proyek"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}   
//Akhir Blok 5........................................................................................//