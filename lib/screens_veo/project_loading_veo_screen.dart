// --- KATEGORI_ISOLASI_VEO: Path file: screens_veo/project_loading_veo_screen.dart ---

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// --- KATEGORI_ISOLASI_VEO: Impor diubah ke _veo ---
import 'package:majiku/models_veo/video_project_veo.dart';
import 'package:majiku/view_model_veo/timeline_veo_view_model.dart'; // <-- Mengimpor projectVeoStreamProvider
import 'package:majiku/screens_veo/timeline_review_veo_screen.dart';
// --- AKHIR MODIFIKASI ---


// --- KATEGORI_SINKRONISASI_VEO: Model Data untuk Tampilan Loading (Disesuaikan) ---
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

// --- KATEGORI_SINKRONISASI_VEO: Daftar tahapan disesuaikan dengan 4 Tahap Backend (v1.7) ---
final List<_LoadingStage> _loadingStages = [
  // [REFAKTOR v1.7] Tahap 1
  _LoadingStage(
    title: "Tahap 1: Script Analysis",
    description: "Analyzing scripts and creating scenes.",
    icon: Icons.auto_stories_outlined,
    technicalStatuses: {
      "PROCESSING_SCENE",
      // Pemicu regenerasi manual dipetakan ke tahap ini
      "PENDING_REFINEMENT", 
    },
  ),
  // [REFAKTOR v1.7] Tahap 2
  _LoadingStage(
    title: "Tahap 2: Contextual Refining",
    description: "Refining the visual scene plan.",
    icon: Icons.spellcheck_outlined,
    technicalStatuses: {
      "PROCESSING_REFINEMENT",
    },
  ),
  // [REFAKTOR v1.7] Tahap 3
  _LoadingStage(
    title: "Tahap 3: Generating Video",
    description: "Starting the video generation process.",
    icon: Icons.movie_creation_outlined,
    technicalStatuses: {
      "VIDEO_GENERATION",
    },
  ),
  // [REFAKTOR v1.7] Tahap 4
  _LoadingStage(
    title: "Tahap 4: Awaiting Final Assets",
    description: "Collect and verify all completed video assets.",
    icon: Icons.inventory_2_outlined,
    technicalStatuses: {
      "COMPLETING_ASSETS",
    },
  ),
];
// --- AKHIR SINKRONISASI VEO ---

int _getStageIndexFromStatus(String? status) {
  if (status == null) return 0;
  for (int i = 0; i < _loadingStages.length; i++) {
    if (_loadingStages[i].technicalStatuses.contains(status)) {
      return i;
    }
  }

  // --- SINKRONISASI VEO: Status akhir (untuk layar ini) adalah ASSETS_COMPLETE ---
  // [REFAKTOR v1.7] PENDING_REFINEMENT kini ditangani oleh loop di atas.

  if (status == "ASSETS_COMPLETE") return _loadingStages.length; // Selesai (untuk layar ini)
  
  // Status yang terjadi setelah ASSETS_COMPLETE, tapi tidak relevan di layar loading ini
  if (status == "RENDER_READY" || status == "RENDER_START" || status == "RENDERING" || status == "RENDER_COMPLETED") {
    // Jika render terlanjur berjalan (karena backend otomatis), anggap saja selesai di layar ini
    return _loadingStages.length;
  }
  // --- AKHIR SINKRONISASI ---

  // [REFAKTOR v1.7] Error status harus menyertakan semua error baru
  if (status.startsWith("ERROR_")) {
    // ERROR_SCENE, ERROR_REFINEMENT, ERROR_VIDEO, ERROR_COMPLETING_ASSETS, ERROR_CONFIG, ERROR_TRIGGER, ERROR_RENDER
    return -1;
  }
  return 0; // Default ke tahap pertama jika status tidak dikenal
}
// --- AKHIR KATEGORI_ARSITEKTUR ---

// --- KATEGORI_ISOLASI_VEO: Nama Class diubah ---
class ProjectLoadingVeoScreen extends ConsumerStatefulWidget {
// --- AKHIR MODIFIKASI ---
  final String projectId;

  // --- KATEGORI_ISOLASI_VEO: Konstruktor diubah ---
  const ProjectLoadingVeoScreen({
  // --- AKHIR MODIFIKASI ---
    super.key,
    required this.projectId,
  });

  @override
  // --- KATEGORI_ISOLASI_VEO: State diubah ---
  ConsumerState<ProjectLoadingVeoScreen> createState() => _ProjectLoadingVeoScreenState();
}

class _ProjectLoadingVeoScreenState extends ConsumerState<ProjectLoadingVeoScreen> {
// --- AKHIR MODIFIKASI ---

  bool _isMounted = false;
  bool _isDialogShown = false;

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

  // --- KATEGORI_ISOLASI_VEO: Tipe data diubah ---
  void _showCompletionDialog(BuildContext context, WidgetRef ref, VideoProjectVeo project) {
  // --- AKHIR MODIFIKASI ---
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          // --- SINKRONISASI VEO: Teks disesuaikan dengan alur Anda ---
          title: const Text("Assets are Ready"), // [REFAKTOR v1.7] Judul diubah
          content: const Text("The media preparation process is now complete. You can now proceed to the timeline and settings."),
          // --- AKHIR SINKRONISASI ---
          actions: <Widget>[
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                if (_isMounted) {
                  // --- KATEGORI_ISOLASI_VEO: Navigasi diubah ---
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => TimelineReviewVeoScreen(projectId: widget.projectId),
                    ),
                  );
                  // --- AKHIR MODIFIKASI ---
                }
              },
              // [REFAKTOR v1.7] Teks Tombol Diubah Sesuai Permintaan
              child: const Text(
                "TIMELINE & SETTING",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // --- KATEGORI_ISOLASI_VEO: Provider sudah benar ---
    final projectAsync = ref.watch(projectVeoStreamProvider(widget.projectId));
    // --- AKHIR MODIFIKASI ---

    return projectAsync.when(
      loading: () => const Scaffold( // Added const here
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                "Memuat status proyek Veo...", // Teks diubah
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
                  "Gagal memuat proyek Veo", // Teks diubah
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
      data: (project) { // Tipe: VideoProjectVeo
        // --- KATEGORI_ISOLASI_VEO: Tipe data diubah ---
        if (project == null) {
        // --- AKHIR MODIFIKASI ---
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

        // --- KATEGORI_SINKRONISASI_VEO: Logika pemicu dialog DIKEMBALIKAN ke ASSETS_COMPLETE (sesuai permintaan) ---
        if (currentStatus == "ASSETS_COMPLETE" && !_isDialogShown) {
        // --- AKHIR SINKRONISASI ---
          _isDialogShown = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_isMounted) {
              debugPrint("[ProjectLoadingScreen (VEO)] Status '$currentStatus' terdeteksi. Menampilkan dialog pilihan...");
              _showCompletionDialog(context, ref, project);
            }
          });
        }

        if (currentStageIndex == -1) {
          return _buildErrorUI(context, project); // Tipe: VideoProjectVeo
        }

        // Bangun UI Stepper (jika masih dalam proses)
        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            automaticallyImplyLeading: false,
            title: const Text(
              "Preparing the Project...", // Teks diubah
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
                    "Your video is being processed", // Teks diubah
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "This process may take a few minutes. You will be redirected once the assets are ready.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: Colors.grey),
                ),
                const SizedBox(height: 32),
                const Center(
                  child: CircularProgressIndicator(),
                ),
                const SizedBox(height: 32),

                // --- KATEGORI_SINKRONISASI_VEO: Logika Stepper disesuaikan untuk 4 tahap ---
                Stepper(
                  controlsBuilder: (context, details) => const SizedBox.shrink(),
                  // Logika currentStep sekarang akan menangani 4 tahap
                  currentStep: currentStageIndex >= _loadingStages.length ? _loadingStages.length - 1 : currentStageIndex,
                  steps: List.generate(_loadingStages.length, (index) {
                    final stage = _loadingStages[index];
                    StepState state = StepState.disabled;

                    if (index < currentStageIndex) {
                      state = StepState.complete;
                    } else if (index == currentStageIndex) {
                      state = StepState.indexed;
                    }

                    // Jika sudah selesai (ASSETS_COMPLETE), set semua langkah ke complete
                    if (currentStageIndex >= _loadingStages.length) {
                      state = StepState.complete;
                    }
                    // --- AKHIR SINKRONISASI ---

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
                      isActive: index == currentStageIndex,
                      state: state,
                    );
                  }),
                ),
                const Spacer(),
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

  /// Helper untuk membangun UI jika status proyek VEO adalah ERROR
  // --- KATEGORI_ISOLASI_VEO: Tipe data diubah ---
  Widget _buildErrorUI(BuildContext context, VideoProjectVeo project) {
  // --- AKHIR MODIFIKASI ---
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
                "Proses Veo Gagal", // Teks diubah
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
                  // --- KATEGORI_ISOLASI_VEO: Navigasi diubah ---
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => TimelineReviewVeoScreen(projectId: widget.projectId),
                    ),
                  );
                  // --- AKHIR MODIFIKASI ---
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