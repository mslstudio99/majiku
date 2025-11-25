// KATEGORI_PENYESUAIAN_TEMA NO_URUT_01
// NAMA FILE: lib/screens/project_loading_screen.dart
// TUJUAN: Menyesuaikan file agar mematuhi AppTheme "Dark Modern"
// dengan menghapus gaya hardcode yang bertentangan.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// --- KATEGORI_MODIFIKASI: Perbaikan Impor Ambigue & Penambahan Dependensi ---
// (Impor Anda sudah benar dan dipertahankan)
import 'package:majiku/providers/timeline_providers.dart';
import 'package:majiku/services/firestore_service.dart';
import 'package:majiku/view_model/timeline_view_model.dart' hide firestoreServiceProvider, projectStreamProvider;
import 'package:majiku/providers/visual_settings_provider.dart' hide firestoreServiceProvider, projectStreamProvider;
// --- AKHIR MODIFIKASI ---

import 'package:majiku/screens/timeline_review_screen.dart';
import 'package:majiku/models/video_project.dart';

// --- KATEGORI_ARSITEKTUR: Model Data untuk Tampilan Loading ---
/// Model data internal untuk mendefinisikan setiap langkah di layar loading.
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

/// Definisi 5 tahapan sesuai tabel yang Anda berikan.
final List<_LoadingStage> _loadingStages = [
  // Tahap 1: Analysis & Blueprint
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
  // Tahap 2: Visual Asset Generating
  _LoadingStage(
    title: "Visual Asset Generating",
    description: "Generation and adjustment of content narrative images/clips.",
    icon: Icons.image_search_outlined,
    technicalStatuses: {"ASSETS_READY", "GENERATING_VISUALS"},
  ),
  // Tahap 3: Audio Synthesis
  _LoadingStage(
    title: "Audio Synthesis",
    description: "Creating voiceovers (narration) and adding intro music.",
    icon: Icons.mic_external_on_outlined,
    technicalStatuses: {
      "PENDING_AUDIO_GENERATION",
      "GENERATING_AUDIO",
      "PENDING_AUTO_RETRY",
      "PROCESSING_AUTO_RETRY"
    },
  ),
  // Tahap 4: Finalizing & Packaging (Hard Stop untuk "Settings")
  _LoadingStage(
    title: "Finalizing & Packaging",
    description: "Combine visual and audio elements, and create complementary thumbnails.",
    icon: Icons.inventory_2_outlined,
    // --- PERBAIKAN V6 (TAHAP 3) ---
    technicalStatuses: {
      "PENDING_THUMBNAIL",
      "GENERATING_THUMBNAIL",
      "ASSETS_COMPLETE" // <-- PERBAIKAN V6: Ini adalah status "Jeda" baru kita
    },
    // --- AKHIR PERBAIKAN ---
  ),
  // Tahap 5: Video Rendering (Hanya untuk "Directly" atau setelah pemicu manual)
  _LoadingStage(
    title: "Video Rendering",
    description: "The process of merging all assets into a complete video file (final output stage).",
    icon: Icons.movie_creation_outlined,
    // --- PERBAIKAN V6 (TAHAP 5) ---
    technicalStatuses: {"RENDER_START", "RENDERING"}, // <-- Menggunakan RENDER_START
    // --- AKHIR PERBAIKAN ---
  ),
];

/// Helper 'Mapper' untuk mengubah Status Teknis menjadi Indeks Tahap (0-4)
int _getStageIndexFromStatus(String? status) {
  if (status == null) return 0;
  for (int i = 0; i < _loadingStages.length; i++) {
    if (_loadingStages[i].technicalStatuses.contains(status)) {
      return i; // Mengembalikan indeks 0-4
    }
  }
  
  // Menangani status yang tidak ada di map (Selesai, Error, atau Awal)
  // --- PERBAIKAN V6: Tambahkan status selesai baru ---
  if (status == "ASSETS_COMPLETE") return _loadingStages.length; // Selesai Fase 1
  if (status == "RENDER_COMPLETED") return _loadingStages.length; // Selesai Fase 2 (Ganti dari COMPLETED)
  // --- AKHIR PERBAIKAN ---
  if (status.startsWith("ERROR_")) return -1; // Flag untuk Error
  
  return 0; // Default ke tahap pertama jika status tidak dikenal
}
// --- AKHIR KATEGORI_ARSITEKTUR ---

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
  
  // --- KATEGORI_FITUR_DIALOG NO_URUT_01: State untuk mencegah dialog ganda ---
  bool _isDialogShown = false;
  // --- AKHIR FITUR ---

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

  // --- KATEGORI_FITUR_DIALOG NO_URUT_02: Fungsi untuk menampilkan dialog ---
  /// Menampilkan dialog konfirmasi saat Fase 1 selesai (ASSETS_COMPLETE)
  void _showCompletionDialog(BuildContext context, WidgetRef ref, VideoProject project) {
    showDialog(
      context: context,
      // Mencegah dialog ditutup dengan klik di luar
      barrierDismissible: false, 
      builder: (dialogContext) {
        
        // --- KATEGORI_PENYEDERHANAAN: Hapus StatefulBuilder ---
        // (Tidak perlu lagi karena tombol Render dihapus)
        return AlertDialog(
          // KATEGORI_PENYESUAIAN_TEMA: Gaya AlertDialog (title, content)
          // kini akan diwarisi dari AppTheme (colorScheme.surface / cardBg)
          title: const Text("Proses Selesai"),
          content: const Text("The media preparation process is now complete. You can now proceed to the settings and timeline."),
          actions: <Widget>[
            // --- KATEGORI_PENYEDERHANAAN: Hanya Tombol Timeline ---
            // Tombol 1: Pengaturan & Timeline
            ElevatedButton( 
              // --- KATEGORI_PENYESUAIAN_TEMA ---
              // MENGHAPUS style hardcode (Colors.blueAccent).
              // Tombol ini sekarang akan otomatis menggunakan
              // elevatedButtonTheme (PrimaryColor/Ungu) dari AppTheme.
              // style: ElevatedButton.styleFrom(
              //   backgroundColor: Colors.blueAccent,
              //   foregroundColor: Colors.white,
              // ),
              // --- AKHIR PENYESUAIAN_TEMA ---
              onPressed: () {
                // 1. Tutup dialog
                Navigator.of(dialogContext).pop();
                // 2. Navigasi ke TimelineReviewScreen
                if (_isMounted) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => TimelineReviewScreen(projectId: widget.projectId),
                    ),
                  );
                }
              },
              child: const Text(
                "Pengaturan & Timeline",
                // KATEGORI_PENYESUAIAN_TEMA: TextStyle di dalam tombol
                // kini akan diwarisi dari AppTheme (elevatedButtonTheme.textStyle)
                // style: TextStyle(fontWeight: FontWeight.bold), 
              ),
            ),
            
            // Tombol 2: Render (Merah)
            // --- KATEGORI_PENYEDERHANAAN: Tombol Render DIHAPUS ---
            // --- AKHIR PENYEDERHANAAN ---
          ],
        );
        // --- AKHIR PENYEDERHANAAN ---
      },
    );
  }
  // --- AKHIR FITUR ---

  @override
  Widget build(BuildContext context) {
    // Tonton (watch) status proyek secara real-time
    final projectAsync = ref.watch(projectStreamProvider(widget.projectId));

    return projectAsync.when(
      loading: () => Scaffold(
        // KATEGORI_PENYESUAIAN_TEMA: Latar belakang Scaffold
        // kini akan diwarisi dari AppTheme (scaffoldBackgroundColor / Hitam)
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(), // Akan menggunakan colorScheme.primary (Ungu)
              SizedBox(height: 16),
              Text(
                "Memuat status proyek...",
                // KATEGORI_PENYESUAIAN_TEMA: Gaya teks
                // kini akan diwarisi dari AppTheme (textTheme.bodyMedium / Putih)
                // style: TextStyle(fontSize: 16),
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
                Icon(
                  Icons.error_outline,
                  // --- KATEGORI_PENYESUAIAN_TEMA ---
                  color: Theme.of(context).colorScheme.error, // Menggunakan warna error tema
                  // --- AKHIR PENYESUAIAN_TEMA ---
                  size: 60
                ),
                const SizedBox(height: 16),
                Text(
                  "Gagal memuat proyek",
                  style: Theme.of(context).textTheme.headlineSmall, // Mewarisi dari tema
                  textAlign: TextAlign.center,
                ),
                Text(
                  error.toString(),
                  textAlign: TextAlign.center, // Mewarisi bodyMedium dari tema
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  // KATEGORI_PENYESUAIAN_TEMA: Tombol akan otomatis
                  // menggunakan elevatedButtonTheme (Ungu)
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text("Kembali"),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (project) {
        // --- KATEGORI_PERBAIKAN_NULL_SAFETY NO_URUT_01 ---
        // Tangani kasus di mana stream mengembalikan data null
        if (project == null) {
          return Scaffold(
            appBar: AppBar(title: const Text("Error")), // Akan menggunakan appBarTheme
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
        // Mulai dari sini, 'project' dijamin non-nullable.
        // --- AKHIR PERBAIKAN ---

        // --- KATEGORI_LOGIKA_NAVIGASI (PASIF & DIALOG) ---
        final String? currentStatus = project.status; // <-- Aman
        final int currentStageIndex = _getStageIndexFromStatus(currentStatus);

        // --- KATEGORI_FITUR_DIALOG NO_URUT_03: Pemicu Dialog ---
        // --- PERBAIKAN V6: Pemicu dialog HANYA saat Fase 1 selesai ---
        // Aturan: Jika Fase 1 Selesai (ASSETS_COMPLETE)
        // DAN dialog belum pernah ditampilkan
        if (currentStatus == "ASSETS_COMPLETE" && !_isDialogShown) {
        // --- AKHIR PERBAIKAN V6 ---
          // 1. Set flag agar dialog tidak muncul lagi jika build ulang
          _isDialogShown = true;
          
          // 2. Panggil dialog setelah frame selesai di-build
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_isMounted) {
              debugPrint("[ProjectLoadingScreen] Status '$currentStatus' terdeteksi. Menampilkan dialog pilihan...");
              _showCompletionDialog(context, ref, project); // <-- Aman
            }
          });
        }
        // --- AKHIR FITUR ---
        
        // Tampilkan UI Error jika status error
        if (currentStageIndex == -1) {
          return _buildErrorUI(context, project); // <-- Aman
        }

        // Bangun UI Stepper (jika masih dalam proses)
        return Scaffold(
          appBar: AppBar(
            // --- KATEGORI_PENYESUAIAN_TEMA ---
            // MENGHAPUS backgroundColor: Colors.transparent dan elevation: 0.
            // AppBar sekarang akan otomatis menggunakan appBarTheme
            // (appBarBg / Abu-abu Gelap) dari AppTheme.
            // backgroundColor: Colors.transparent,
            // elevation: 0,
            // --- AKHIR PENYESUAIAN_TEMA ---
            automaticallyImplyLeading: false, 
            title: const Text(
              "Mempersiapkan Proyek...",
              // KATEGORI_PENYESUAIAN_TEMA: Gaya teks
              // kini akan diwarisi dari AppTheme (appBarTheme.titleTextStyle)
              // style: TextStyle(fontWeight: FontWeight.bold),
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
                Text(
                  "This process may take a few minutes. You will be automatically redirected once the assets are ready.",
                  textAlign: TextAlign.center,
                  // --- KATEGORI_PENYESUAIAN_TEMA ---
                  // Menggunakan textTheme.bodyMedium (textSecondary) dari AppTheme
                  // untuk konsistensi, menggantikan Colors.grey hardcode.
                  style: Theme.of(context).textTheme.bodyMedium,
                  // style: TextStyle(fontSize: 15, color: Colors.grey),
                  // --- AKHIR PENYESUAIAN_TEMA ---
                ),
                const SizedBox(height: 32),
                const Center(
                  child: CircularProgressIndicator(), // Akan menggunakan colorScheme.primary (Ungu)
                ),
                const SizedBox(height: 32), 

                // --- KATEGORI_UI: Stepper Modern ---
                Stepper(
                  // KATEGORI_PENYESUAIAN_TEMA: Stepper akan otomatis
                  // menggunakan warna tema (primary, background, surface)
                  // dari AppTheme.
                  controlsBuilder: (context, details) => const SizedBox.shrink(),
                  currentStep: currentStageIndex > 4 ? 4 : currentStageIndex, 
                  steps: List.generate(_loadingStages.length, (index) {
                    final stage = _loadingStages[index];
                    StepState state = StepState.disabled; 
                    
                    if (index < currentStageIndex) {
                      state = StepState.complete; // Selesai
                    } else if (index == currentStageIndex) {
                      state = StepState.indexed; // Sedang berlangsung (aktif)
                    }

                    if (currentStageIndex > 4 && index == 4) {
                      state = StepState.complete;
                    }

                    return Step(
                      title: Text(
                        stage.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ), // Gaya Stepper Title tetap di-hardcode agar menonjol
                      ),
                      subtitle: Text(stage.description, style: const TextStyle(fontSize: 14),), // Gaya Stepper Subtitle tetap
                      content: const SizedBox.shrink(), 
                      isActive: index == currentStageIndex,
                      state: state,
                    );
                  }),
                ),
                // --- AKHIR KATEGORI_UI ---
                const Spacer(),
                TextButton(
                  // KATEGORI_PENYESUAIAN_TEMA: TextButton akan otomatis
                  // menggunakan colorScheme.primary (Ungu) untuk teksnya.
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

  /// Helper untuk membangun UI jika status proyek adalah ERROR
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
                // --- KATEGORI_PENYESUAIAN_TEMA ---
                color: Theme.of(context).colorScheme.error, // Menggunakan warna error tema
                // --- AKHIR PENYESUAIAN_TEMA ---
                size: 60
              ),
              const SizedBox(height: 16),
              Text(
                "Proses Gagal",
                style: Theme.of(context).textTheme.headlineSmall, // Mewarisi dari tema
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                "Terjadi kesalahan pada tahap: ${project.status ?? 'Unknown'}",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  // --- KATEGORI_PENYESUAIAN_TEMA ---
                  color: Theme.of(context).colorScheme.error, // Menggunakan warna error tema
                  // --- AKHIR PENYESUAIAN_TEMA ---
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                project.errorDetail ?? "Tidak ada detail error.",
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14), // Mewarisi bodyMedium dari tema
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                // KATEGORI_PENYESUAIAN_TEMA: Tombol akan otomatis
                // menggunakan elevatedButtonTheme (Ungu)
                onPressed: () {
                  // Arahkan ke TimelineReviewScreen agar pengguna bisa melihat
                  // scene yang error (jika ada) atau mencoba render ulang.
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