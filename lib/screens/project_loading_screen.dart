//====================================================================================================//
// NAMA FILE: LIB/SCREENS/PROJECT_LOADING_SCREEN.DART                                                 //
// DESKRIPSI: RUANG TUNGGU GENERASI ASET (HANYA MENGAWASI HINGGA ASSETS_COMPLETE / REFINEMENT)        //
//====================================================================================================//

//No ke-1: IMPORTS & DEPENDENCIES //
//Deklarasi pustaka, provider, dan layar tujuan. //
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:majiku/providers/timeline_providers.dart';
import 'package:majiku/services/firestore_service.dart';
import 'package:majiku/view_model/timeline_view_model.dart' hide firestoreServiceProvider, projectStreamProvider;
import 'package:majiku/providers/visual_settings_provider.dart' hide firestoreServiceProvider, projectStreamProvider;

import 'package:majiku/screens/timeline_review_screen.dart';
import 'package:majiku/models/video_project.dart';
//----------------------------------------------------------------------------------------------------//

//No ke-2: LOADING STAGES MODEL & DATA //
//Mendefinisikan tahapan loading HANYA untuk fase aset. //
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

// Menghapus Stage 5 (Rendering) karena proses rendering terjadi di Timeline Screen
final List<_LoadingStage> _loadingStages = [
  _LoadingStage(
    title: "Analysis & Blueprint",
    description: "The application is processing your text input and preparing a content blueprint.",
    icon: Icons.auto_stories_outlined,
    technicalStatuses: {
      "PROCESSING_GENERATION",
      "PENDING_REFINEMENT",
      "PROCESSING_REFINEMENT"
    },
  ),
  _LoadingStage(
    title: "Visual Asset Generating",
    description: "Generation and adjustment of content narrative images/clips.",
    icon: Icons.image_search_outlined,
    technicalStatuses: {"ASSETS_READY", "GENERATING_VISUALS"},
  ),
  _LoadingStage(
    title: "Audio Synthesis",
    description: "Creating voiceovers (narration).",
    icon: Icons.mic_external_on_outlined,
    technicalStatuses: {
      "PENDING_AUDIO_GENERATION",
      "GENERATING_AUDIO",
      "PENDING_AUTO_RETRY",
      "PROCESSING_AUTO_RETRY"
    },
  ),
  _LoadingStage(
    title: "Finalizing Assets",
    description: "Combine visual and audio elements, and preparing timeline.",
    icon: Icons.inventory_2_outlined,
    technicalStatuses: {
      "PENDING_THUMBNAIL",
      "GENERATING_THUMBNAIL",
      "ASSETS_COMPLETE", 
      "CREATE_RENDER_PACKET" 
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
  
  if (status == "ASSETS_COMPLETE" || status == "CREATE_RENDER_PACKET") return _loadingStages.length; 
  if (status != null && (status.startsWith("ERROR_") || status == "ASSETS_NEED_REFINEMENT")) return -1; 
  
  return 0; 
}
//----------------------------------------------------------------------------------------------------//

//No ke-3: MAIN CLASS & STATE INITIALIZATION //
//Deklarasi stateful widget dan pengunci navigasi ganda. //
class ProjectLoadingScreen extends ConsumerStatefulWidget {
  final String projectId;

  const ProjectLoadingScreen({
    super.key,
    required this.projectId,
  });

  @override
  ConsumerState<ProjectLoadingScreen> createState() => _ProjectLoadingScreenState();
}

class _ProjectLoadingScreenState extends ConsumerState<ProjectLoadingScreen> {
  bool _isMounted = false;
  
  // Flag ini digunakan agar pushReplacement hanya dipanggil satu kali
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
//----------------------------------------------------------------------------------------------------//

//No ke-4: BUILD METHOD & GATEKEEPER ROUTING LOGIC //
//Memantau stream, mengeksekusi perpindahan layar saat aset selesai atau bermasalah. //
  @override
  Widget build(BuildContext context) {
    final projectAsync = ref.watch(projectStreamProvider(widget.projectId));

    return projectAsync.when(
      loading: () => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              CircularProgressIndicator(), 
              SizedBox(height: 16),
              Text("Memuat status proyek..."),
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
                Icon(
                  Icons.error_outline,
                  color: Theme.of(context).colorScheme.error, 
                  size: 60
                ),
                const SizedBox(height: 16),
                Text(
                  "Gagal memuat proyek",
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
                  "Error: Project data stream returned null. Cannot load project.",
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        final String? currentStatus = project.status; 
        final int currentStageIndex = _getStageIndexFromStatus(currentStatus);

        // --- SKENARIO 1: HAPPY PATH (SEMUA ASET SELESAI) ---
        // Jika status mencapai ASSETS_COMPLETE atau CREATE_RENDER_PACKET, lempar ke Timeline.
        // Timeline yang akan memutuskan dan mengeksekusi Auto-Render.
        if ((currentStatus == "ASSETS_COMPLETE" || currentStatus == "CREATE_RENDER_PACKET" || currentStatus == "RENDER_START" || currentStatus == "RENDERING" || currentStatus == "RENDER_COMPLETED") && !_hasNavigated) {
          _hasNavigated = true; 
          
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_isMounted) {
              debugPrint("🚀 [Loading Gatekeeper] Aset Selesai. Meneruskan ke Timeline...");
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => TimelineReviewScreen(projectId: widget.projectId),
                ),
              );
            }
          });
        }
		
        // --- SKENARIO 2: ERROR/FALLBACK PATH (MANUAL REFINEMENT) ---
        // Jika ada aset yang gagal (ASSETS_NEED_REFINEMENT atau status ERROR)
        if ((currentStatus == "ASSETS_NEED_REFINEMENT" || (currentStatus != null && currentStatus.startsWith("ERROR_"))) && !_hasNavigated) {
          _hasNavigated = true; 
          
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_isMounted) {
              debugPrint("⚠️ [Loading Gatekeeper] Masalah aset terdeteksi. Melempar ke Timeline untuk Manual Fallback.");
              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Terdapat aset yang gagal diproses. Silakan perbaiki secara manual di Timeline.'),
                  backgroundColor: Colors.redAccent,
                  duration: Duration(seconds: 5),
                ),
              );
              
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => TimelineReviewScreen(projectId: widget.projectId),
                ),
              );
            }
          });
        }
        
        // Tampilkan UI Error bawaan jika status fatal dan belum ter-routing
        if (currentStageIndex == -1 && !_hasNavigated) {
          return _buildErrorUI(context, project); 
        }

        // Tampilan UI Stepper selama aset masih di-generate (menunggu)
        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false, 
            title: const Text("Mempersiapkan Proyek..."),
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
                Text(
                  "This process may take a few minutes. Keep this page open until rendering begins.",
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
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

                        if (currentStageIndex >= _loadingStages.length && index == _loadingStages.length - 1) {
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
                          subtitle: Text(stage.description, style: const TextStyle(fontSize: 14)), 
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
//----------------------------------------------------------------------------------------------------//

//No ke-5: ERROR UI HELPER //
//Fungsi pembangunan UI jika terjadi error fatal sebelum masuk ke Timeline. //
  Widget _buildErrorUI(BuildContext context, VideoProject project) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                color: Theme.of(context).colorScheme.error, 
                size: 60
              ),
              const SizedBox(height: 16),
              Text(
                "Proses Gagal",
                style: Theme.of(context).textTheme.headlineSmall, 
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                "Terjadi kesalahan pada tahap: ${project.status ?? 'Unknown'}",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.error, 
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
                      builder: (context) => TimelineReviewScreen(projectId: widget.projectId),
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
//----------------------------------------------------------------------------------------------------//