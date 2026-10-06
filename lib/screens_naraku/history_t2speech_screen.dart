//================================================================//
// LIB/SCREENS_NARAKU/HISTORY_T2SPEECH_SCREEN.DART                //
// LAYAR RIWAYAT AUDIO GENERATOR TEXT TO SPEECH (T2SPEECH)        //
// STREAM DAFTAR AUDIO, PREVIEW PLAYBACK, DOWNLOAD & HAPUS DATA   //
//================================================================//

//No ke-1: IMPORTS & DEPENDENSI                                   //
//DEPENDENSI FLUTTER, RIVERPOD, AUDIOPLAYER, MODEL & SERVICE      //
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:audioplayers/audioplayers.dart';

import '../providers/config_provider.dart';
import '../models_naraku/audio_project_t2speech.dart';
import '../services_naraku/firestore_t2speech_service.dart';
import '../theme/app_theme.dart';
// END OF BLOK 1 //
//================================================================//

//No ke-2: PROVIDERS & LOGIKA STREAM                              //
//STREAM PROVIDER FIRESTORE USER PROJECTS T2SPEECH                //
final firestoreT2SpeechServiceProvider = Provider<FirestoreT2SpeechService>((ref) {
  return FirestoreT2SpeechService();
});

final historyT2SpeechStreamProvider = StreamProvider.autoDispose<List<AudioProjectT2Speech>>((ref) {
  final user = FirebaseAuth.instance.currentUser;

  if (user == null) {
    return Stream.value([]);
  }

  return ref.watch(firestoreT2SpeechServiceProvider).streamUserProjects(user.uid);
});
// END OF BLOK 2 //
//================================================================//

//No ke-3: STATEFUL WIDGET & DIALOG DETAIL AUDIO                  //
//POPUP MODAL DETAIL TEKS, INFO VOKAL, PLAYBACK & DOWNLOAD NATIVE //
class HistoryT2SpeechScreen extends ConsumerStatefulWidget {
  const HistoryT2SpeechScreen({super.key});

  @override
  ConsumerState<HistoryT2SpeechScreen> createState() => _HistoryT2SpeechScreenState();
}

class _HistoryT2SpeechScreenState extends ConsumerState<HistoryT2SpeechScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _currentlyPlayingUrl;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() => _isPlaying = state == PlayerState.playing);
      }
    });

    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _currentlyPlayingUrl = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _toggleAudio(String url) async {
    if (_currentlyPlayingUrl == url && _isPlaying) {
      await _audioPlayer.pause();
    } else {
      _currentlyPlayingUrl = url;
      await _audioPlayer.stop();
      await _audioPlayer.play(UrlSource(url));
    }
  }

  void _showAudioDetailDialog(BuildContext context, AudioProjectT2Speech project, bool isIndo) {
    String t(String en, String id) => isIndo ? id : en;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          final bool isThisPlaying = _currentlyPlayingUrl == project.audioUrl && _isPlaying;

          return AlertDialog(
            backgroundColor: const Color(0xFF1E1E2C),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.record_voice_over, color: Colors.amber, size: 22),
                const SizedBox(width: 8),
                Text(
                  t('Speech Details', 'Detail Suara'),
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF12121E),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: () async {
                            await _toggleAudio(project.audioUrl);
                            setStateDialog(() {});
                          },
                          child: Container(
                            height: 60,
                            width: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.amber.shade400,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.amber.withOpacity(0.3),
                                  blurRadius: 10,
                                  spreadRadius: 3,
                                )
                              ],
                            ),
                            child: Icon(
                              isThisPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              color: Colors.black87,
                              size: 34,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          isThisPlaying
                              ? t('Playing audio...', 'Memutar suara...')
                              : t('Tap to preview', 'Ketuk untuk dengarkan'),
                          style: TextStyle(color: Colors.amber.shade200, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text("${t('Voice', 'Jenis Vokal')}: ${project.voice}",
                      style: const TextStyle(color: Colors.amber, fontSize: 13, fontWeight: FontWeight.bold)),
                  Text("${t('Language', 'Bahasa')}: ${project.language}",
                      style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 12),
                  Text("${t('Narration Text', 'Teks Narasi')}:",
                      style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 4),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 180),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        project.text,
                        style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton.icon(
                icon: const Icon(Icons.download_rounded, color: Colors.greenAccent),
                label: Text(
                  t('Download', 'Unduh'),
                  style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold),
                ),
                onPressed: () async {
                  try {
                    final Uri url = Uri.parse(project.audioUrl);
                    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(t('Could not open download link', 'Gagal membuka tautan unduh')),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                      );
                    }
                  }
                },
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(t('Close', 'Tutup'), style: const TextStyle(color: Colors.white54)),
              ),
            ],
          );
        },
      ),
    );
  }
// END OF BLOK 3 //
//================================================================//

//No ke-4: BUILD METHOD UTAMA & APPBAR                            //
//SCAFFOLD, THEME DARK, CUSTOM SCROLL VIEW & APPBAR DENGAN BADGE  //
  @override
  Widget build(BuildContext context) {
    final projectsAsyncValue = ref.watch(historyT2SpeechStreamProvider);
    final currentLocale = ref.watch(appLanguageProvider);
    final isIndo = currentLocale.languageCode == 'id';
    String t(String en, String id) => isIndo ? id : en;

    return Theme(
      data: AppTheme.darkTheme,
      child: Scaffold(
        appBar: AppBar(
          title: Text(t('T2Speech History', 'Histori T2Speech')),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: CustomScrollView(
          slivers: [
            _buildProjectList(context, ref, projectsAsyncValue, isIndo),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
// END OF BLOK 4 //
//================================================================//

//No ke-5: LIST BUILDER RIWAYAT & PENANGANAN ERROR INDEX          //
//RENDER ITEM AUDIO, TOMBOL PLAY PREVIEW, DOWNLOAD, HAPUS & ERROR //
  Widget _buildProjectList(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<AudioProjectT2Speech>> asyncValue,
    bool isIndo,
  ) {
    String t(String en, String id) => isIndo ? id : en;

    return asyncValue.when(
      loading: () => const SliverToBoxAdapter(
        child: Center(
          child: Padding(padding: EdgeInsets.all(32.0), child: CircularProgressIndicator()),
        ),
      ),
      error: (error, stack) {
        final errorStr = error.toString();
        final hasIndexError = errorStr.contains('https://console.firebase.google.com');
        String? indexUrl;

        if (hasIndexError) {
          final regExp = RegExp(r'https://console\.firebase\.google\.com/[^\s]+');
          indexUrl = regExp.stringMatch(errorStr);
        }

        return SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                const Icon(Icons.analytics_outlined, color: Colors.redAccent, size: 40),
                const SizedBox(height: 16),
                Text(
                  hasIndexError
                      ? t('Database Index Required', 'Butuh Index Database')
                      : t('System Error', 'Kesalahan Sistem'),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  hasIndexError
                      ? t(
                          'Firebase needs a composite index to show your history.',
                          'Firebase butuh index khusus untuk menampilkan histori Anda.',
                        )
                      : errorStr,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                if (hasIndexError && indexUrl != null) ...[
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: Text(t('BUILD INDEX NOW', 'BUAT INDEX SEKARANG')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    onPressed: () async {
                      Clipboard.setData(ClipboardData(text: indexUrl!));
                      final Uri url = Uri.parse(indexUrl);
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url, mode: LaunchMode.externalApplication);
                      }
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              t('Link opened & copied to clipboard!', 'Link dibuka & disalin ke clipboard!'),
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
      data: (projects) {
        if (projects.isEmpty) {
          return SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  children: [
                    const Icon(Icons.mic_off_outlined, color: Colors.white24, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      t('No generated audio yet.', 'Belum ada audio yang dihasilkan.'),
                      style: const TextStyle(color: Colors.white38),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final project = projects[index];
              final bool isCurrentItemPlaying = _currentlyPlayingUrl == project.audioUrl && _isPlaying;

              return Card(
                elevation: 2,
                color: Colors.grey[900],
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _showAudioDetailDialog(context, project, isIndo),
                  child: ListTile(
                    leading: IconButton(
                      icon: Icon(
                        isCurrentItemPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                        color: Colors.amber,
                        size: 36,
                      ),
                      onPressed: () => _toggleAudio(project.audioUrl),
                    ),
                    title: Text(
                      project.text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      "${project.voice} • ${project.language}",
                      style: TextStyle(color: Colors.green.shade400, fontSize: 12),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.download_for_offline, color: Colors.greenAccent),
                          tooltip: t('Download', 'Unduh'),
                          onPressed: () async {
                            try {
                              final Uri url = Uri.parse(project.audioUrl);
                              if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Could not open link: ${project.audioUrl}'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                                );
                              }
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          tooltip: t('Delete', 'Hapus'),
                          onPressed: () async {
                            try {
                              if (_currentlyPlayingUrl == project.audioUrl) {
                                await _audioPlayer.stop();
                              }
                              await ref.read(firestoreT2SpeechServiceProvider).deleteProject(project.id);
                            } catch (e) {
                              debugPrint("Delete error: $e");
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
            childCount: projects.length,
          ),
        );
      },
    );
  }
}
// END OF BLOK 5 //
//================================================================//