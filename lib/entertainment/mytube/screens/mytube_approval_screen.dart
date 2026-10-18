//============================================================================//
// DIREKTORI: lib/entertainment/mytube/screens/                              //
// FILE: MYTUBE_APPROVAL_SCREEN.DART                                         //
// LAYAR MODERASI, PERSETUJUAN KONTEN & PUSAT DIAGNOSTIK MULTI-HLS (ADMIN)   //
//============================================================================//

//No ke-1....................................................................//
//IMPORTS & DEPENDENCIES                                                     //
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:video_player/video_player.dart';

import '../../../providers/config_provider.dart';
import '../models/request_mytube_model.dart';
import '../models/video_mytube_model.dart';
import '../services/firestore_mytube_service.dart';
//............................................................................//

//No ke-2....................................................................//
//WIDGET DECLARATION & STATE SETUP                                           //
class MytubeApprovalScreen extends ConsumerStatefulWidget {
  const MytubeApprovalScreen({super.key});

  @override
  ConsumerState<MytubeApprovalScreen> createState() => _MytubeApprovalScreenState();
}

class _MytubeApprovalScreenState extends ConsumerState<MytubeApprovalScreen>
    with SingleTickerProviderStateMixin {
  final FirestoreMytubeService _service = FirestoreMytubeService();
  late final TabController _tabController;
  User? _currentUser;

  // [DIAGNOSTIK & OPTIMASI KONTEN HLS/THUMBNAIL]
  bool _isScanning = false;
  bool _isOptimizing = false;
  bool _hasScanned = false;
  List<VideoMytubeModel> _unoptimizedVideos = [];
  String? _optimizationStatusMessage;

  // [SMART AUTO-POLLING & LIVE MONITORING]
  Timer? _liveMonitorTimer;
  bool _isServerWorking = false;
//............................................................................//

//No ke-3....................................................................//
//LIFECYCLE, SCANNER, LIVE MONITOR & ACTION HANDLERS                         //
  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _stopLiveMonitor();
    _tabController.dispose();
    super.dispose();
  }

  // --- SMART AUTO-POLLING ENGINE ---
  void _startLiveMonitor(bool isIndo) {
    if (_liveMonitorTimer != null && _liveMonitorTimer!.isActive) return;
    _liveMonitorTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _scanContentHealth(isIndo, silent: true);
    });
  }

  void _stopLiveMonitor() {
    _liveMonitorTimer?.cancel();
    _liveMonitorTimer = null;
  }

  // --- PEMINDAI KONTEN (SCAN & UPDATE REAL-TIME) ---
  Future<void> _scanContentHealth(bool isIndo, {bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isScanning = true;
        _optimizationStatusMessage = null;
      });
    }

    try {
      final legacyShorts = await _service.getLegacyVideosForMigration(videoType: 'SHORT', limit: 50);
      final legacyLongs = await _service.getLegacyVideosForMigration(videoType: 'LONG', limit: 50);

      final combined = [...legacyShorts, ...legacyLongs];

      final unoptimized = combined.where((v) {
        final needsHls = v.hlsVersion < 2 || v.availableResolutions.isEmpty;
        final needsThumb = v.thumbnailUrl.trim().isEmpty;
        final isPending = v.hlsStatus == 'PENDING';
        final isProcessing = v.hlsStatus == 'PROCESSING';
        final isError = v.hlsStatus == 'ERROR_TRANSCODING';

        return needsHls || needsThumb || isPending || isProcessing || isError;
      }).toList();

      if (!mounted) return;

      setState(() {
        _unoptimizedVideos = unoptimized;
        _hasScanned = true;
        if (!silent) _isScanning = false;

        // Cek apakah ada video yang sedang dikerjakan server
        final hasActiveProcess = unoptimized.any((v) => v.hlsStatus == 'PENDING' || v.hlsStatus == 'PROCESSING');
        
        if (hasActiveProcess) {
          _isServerWorking = true;
          _startLiveMonitor(isIndo);
        } else {
          _isServerWorking = false;
          _stopLiveMonitor();

          // Jika sebelumnya mengoptimasi dan sekarang sudah kosong, selebrasi!
          if (silent && unoptimized.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  isIndo ? '🎉 Seluruh video berhasil dioptimasi ke Multi-HLS!' : '🎉 All videos successfully optimized to Multi-HLS!',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      });
    } catch (e) {
      if (!mounted) return;
      if (!silent) {
        setState(() => _isScanning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isIndo ? 'Gagal memindai video: $e' : 'Failed to scan videos: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  // --- EKSEKUSI OPTIMASI BERURUTAN (SATU PER SATU / ANTI-CRASH) ---
  Future<void> _executeBatchOptimization(bool isIndo) async {
    if (_unoptimizedVideos.isEmpty || _isServerWorking) return;

    setState(() {
      _isOptimizing = true;
      _optimizationStatusMessage = isIndo
          ? 'Memasukkan video ke antrean...'
          : 'Queueing videos for processing...';
    });

    int queuedCount = 0;
    
    // Hanya masukkan ke antrean video yang belum berstatus PENDING/PROCESSING
    final targetVideos = _unoptimizedVideos.where((v) => v.hlsStatus != 'PENDING' && v.hlsStatus != 'PROCESSING').toList();
    final total = targetVideos.length;

    for (int i = 0; i < total; i++) {
      final video = targetVideos[i];

      if (mounted) {
        setState(() {
          _optimizationStatusMessage = isIndo
              ? 'Menyiapkan [${i + 1}/$total]: ${video.title}...'
              : 'Queueing [${i + 1}/$total]: ${video.title}...';
        });
      }

      final success = await _service.requestVideoRetranscode(
        videoId: video.id,
        uploaderEmail: video.uploaderEmail,
        uploaderId: video.uploaderId,
        videoType: video.videoType,
      );

      if (success) queuedCount++;
      await Future.delayed(const Duration(milliseconds: 300));
    }

    if (mounted) {
      setState(() {
        _isOptimizing = false;
        _optimizationStatusMessage = null;
      });

      if (queuedCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isIndo
                  ? '$queuedCount video masuk antrean. Server sedang bekerja!'
                  : '$queuedCount video(s) queued. Server is working!',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.blueAccent,
          ),
        );
      }

      // Pindai status terkini (Akan memicu Live Monitor otomatis)
      await _scanContentHealth(isIndo);
    }
  }

  // --- APPROVE & REJECT HANDLERS (ORIGINAL INTACT) ---
  Future<void> _handleApprove(RequestMytubeModel request, bool isIndo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isIndo ? 'Setujui Permohonan?' : 'Approve Request?',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          request.requestType == 'EDIT'
              ? (isIndo
                  ? 'Perubahan judul, kategori, dan bahasa akan langsung diterapkan ke video di database.'
                  : 'Changes to title, category, and language will be applied to the video immediately.')
              : (isIndo
                  ? 'Video ini akan dihapus secara permanen dari saluran kreator dan database.'
                  : 'This video will be permanently deleted from the creator channel and database.'),
          style: const TextStyle(color: Colors.white70, fontSize: 13.5, height: 1.4),
        ),
        actions: [
          TextButton(
            child: Text(isIndo ? 'Batal' : 'Cancel', style: const TextStyle(color: Colors.white54)),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: Text(isIndo ? 'Ya, Setujui' : 'Yes, Approve', style: const TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final adminEmail = _currentUser?.email ?? 'admin@majiku.net';
      await _service.approveRequest(request, adminEmail: adminEmail);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isIndo
                  ? 'Permohonan ${request.requestType} berhasil disetujui!'
                  : '${request.requestType} request approved successfully!',
              style: const TextStyle(fontSize: 14),
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _handleReject(RequestMytubeModel request, bool isIndo) async {
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.cancel_rounded, color: Colors.redAccent, size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isIndo ? 'Tolak Permohonan?' : 'Reject Request?',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isIndo
                  ? 'Permohonan akan ditolak dan video tidak akan diubah/dihapus.'
                  : 'The request will be rejected and the video will not be changed or deleted.',
              style: const TextStyle(color: Colors.white70, fontSize: 13.5),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: reasonController,
              style: const TextStyle(color: Colors.white, fontSize: 13.5),
              decoration: InputDecoration(
                hintText: isIndo ? 'Alasan penolakan (opsional)...' : 'Reason for rejection (optional)...',
                hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
                filled: true,
                fillColor: const Color(0xFF141418),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: Text(isIndo ? 'Batal' : 'Cancel', style: const TextStyle(color: Colors.white54)),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: Text(isIndo ? 'Tolak Permohonan' : 'Reject Request', style: const TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final adminEmail = _currentUser?.email ?? 'admin@majiku.net';
      await _service.rejectRequest(
        request.id,
        adminEmail: adminEmail,
        rejectReason: reasonController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isIndo ? 'Permohonan berhasil ditolak.' : 'Request rejected.',
              style: const TextStyle(fontSize: 14),
            ),
            backgroundColor: Colors.blueGrey,
          ),
        );
      }
    }
  }
//............................................................................//

//No ke-4....................................................................//
//MAIN BUILD, DIAGNOSTIC CARD & TABBAR HEADER                                //
  @override
  Widget build(BuildContext context) {
    final currentLocale = ref.watch(appLanguageProvider);
    final isIndo = currentLocale.languageCode == 'id';
    String t(String en, String id) => isIndo ? id : en;

    return Scaffold(
      backgroundColor: const Color(0xFF121214),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E24),
        elevation: 0,
        title: Text(
          t('Mytube Content Approval', 'Pusat Persetujuan Mytube'),
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amberAccent,
          indicatorWeight: 3,
          labelColor: Colors.amberAccent,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          tabs: [
            Tab(
              icon: const Icon(Icons.pending_actions_rounded, size: 20),
              text: t('Pending Requests', 'Menunggu Persetujuan'),
            ),
            Tab(
              icon: const Icon(Icons.history_toggle_off_rounded, size: 20),
              text: t('Reviewed History', 'Riwayat Selesai'),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // [PANEL DIAGNOSTIK & OPTIMASI KONTEN MULTI-HLS / THUMBNAIL]
          _buildOptimizationDiagnosticCard(t, isIndo),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildRequestListStream(statusFilter: 'PENDING', t: t, isIndo: isIndo),
                _buildRequestListStream(statusFilter: null, isHistoryTab: true, t: t, isIndo: isIndo),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET CARD DIAGNOSTIK DENGAN LIVE REAL-TIME BADGE ---
  Widget _buildOptimizationDiagnosticCard(String Function(String, String) t, bool isIndo) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E24),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _isServerWorking
              ? Colors.blueAccent.withOpacity(0.5)
              : (_unoptimizedVideos.isNotEmpty ? Colors.amberAccent.withOpacity(0.5) : Colors.white12),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_fix_high_rounded,
                color: _isServerWorking ? Colors.blueAccent : (_unoptimizedVideos.isNotEmpty ? Colors.amberAccent : Colors.lightBlueAccent),
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  t('Content Health & Multi-HLS Optimizer', 'Diagnostik & Optimasi Konten Multi-HLS'),
                  style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold),
                ),
              ),
              if (_isScanning && !_isServerWorking)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amberAccent),
                )
              else
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.amberAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: Text(t('Scan', 'Pindai'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: (_isOptimizing || _isServerWorking) ? null : () => _scanContentHealth(isIndo),
                ),
            ],
          ),

          if (_optimizationStatusMessage != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.8, color: Colors.blueAccent)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _optimizationStatusMessage!,
                      style: const TextStyle(color: Colors.white70, fontSize: 11.5),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (!_hasScanned) ...[
            const SizedBox(height: 6),
            Text(
              t(
                'Scan your database to detect videos missing Multi-Bitrate HLS (360p/480p/720p) or thumbnails.',
                'Pindai database untuk mendeteksi video yang belum memiliki Multi-Bitrate HLS (360p/480p/720p) atau thumbnail.',
              ),
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ] else if (_unoptimizedVideos.isEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    t(
                      'All MyTube content is healthy! (Multi-HLS & Thumbnails ready)',
                      'Semua konten MyTube optimal! (Multi-HLS & Thumbnail lengkap)',
                    ),
                    style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 10),
            Text(
              t(
                'Found ${_unoptimizedVideos.length} video(s) requiring optimization:',
                'Ditemukan ${_unoptimizedVideos.length} video yang memerlukan optimasi:',
              ),
              style: const TextStyle(color: Colors.amberAccent, fontSize: 12.5, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),

            // [LIVE REAL-TIME LIST]: Daftar video dengan badge status live
            Container(
              constraints: const BoxConstraints(maxHeight: 140),
              decoration: BoxDecoration(
                color: const Color(0xFF141418),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.all(8),
                itemCount: _unoptimizedVideos.length,
                separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 8),
                itemBuilder: (context, idx) {
                  final v = _unoptimizedVideos[idx];
                  
                  // Evaluasi status dinamis
                  final isProcessing = v.hlsStatus == 'PROCESSING';
                  final isQueued = v.hlsStatus == 'PENDING';
                  final isError = v.hlsStatus == 'ERROR_TRANSCODING';
                  final needsHls = v.hlsVersion < 2 || v.availableResolutions.isEmpty;
                  final needsThumb = v.thumbnailUrl.trim().isEmpty;

                  return Row(
                    children: [
                      Icon(v.videoType == 'LONG' ? Icons.tv_rounded : Icons.bolt,
                          color: v.videoType == 'LONG' ? Colors.orangeAccent : Colors.amberAccent, size: 15),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          v.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isProcessing ? Colors.blueAccent : Colors.white,
                            fontSize: 12, 
                            fontWeight: isProcessing ? FontWeight.bold : FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Tampilan Lencana (Badge) Live Status
                      if (isProcessing)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.blueAccent, width: 0.5)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(width: 8, height: 8, child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.blueAccent)),
                              const SizedBox(width: 4),
                              Text(t('Encoding...', 'Diproses...'), style: const TextStyle(color: Colors.blueAccent, fontSize: 9.5, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        )
                      else if (isQueued)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(color: Colors.orangeAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.hourglass_top_rounded, color: Colors.orangeAccent, size: 10),
                              const SizedBox(width: 3),
                              Text(t('Queued', 'Antre'), style: const TextStyle(color: Colors.orangeAccent, fontSize: 9.5, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        )
                      else if (isError)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                          child: Text(t('Error', 'Gagal'), style: const TextStyle(color: Colors.redAccent, fontSize: 9.5, fontWeight: FontWeight.bold)),
                        )
                      else ...[
                        if (needsHls)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(4)),
                            child: Text(t('Missing HLS', 'Kurang HLS'), style: const TextStyle(color: Colors.white60, fontSize: 9.5)),
                          ),
                        if (needsThumb) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(4)),
                            child: Text(t('No Thumb', 'Tanpa Cover'), style: const TextStyle(color: Colors.white60, fontSize: 9.5)),
                          ),
                        ],
                      ]
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 10),

            // Tombol Eksekusi Terkunci Pintar
            SizedBox(
              width: double.infinity,
              height: 38,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isServerWorking ? const Color(0xFF2A2A38) : const Color(0xFF2563EB),
                  foregroundColor: _isServerWorking ? Colors.white54 : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                icon: _isServerWorking
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blueAccent))
                    : const Icon(Icons.play_arrow_rounded, size: 20),
                label: Text(
                  _isServerWorking
                      ? t('Server Transcoding in Progress...', 'Server Sedang Memproses...')
                      : t('Optimize All Sequentially', 'Mulai Optimasi Bertahap'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                ),
                onPressed: (_isOptimizing || _isServerWorking) ? null : () => _executeBatchOptimization(isIndo),
              ),
            ),
          ],
        ],
      ),
    );
  }
//............................................................................//

//No ke-5....................................................................//
//REQUEST LIST VIEW STREAMBUILDER                                            //
  Widget _buildRequestListStream({
    String? statusFilter,
    bool isHistoryTab = false,
    required String Function(String, String) t,
    required bool isIndo,
  }) {
    return StreamBuilder<List<RequestMytubeModel>>(
      stream: _service.streamRequests(statusFilter: statusFilter),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.amberAccent));
        }

        var list = snapshot.data ?? [];

        // Jika Tab Riwayat, filter hanya yang sudah bukan PENDING lagi
        if (isHistoryTab) {
          list = list.where((r) => r.status != 'PENDING').toList();
        }

        if (list.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isHistoryTab ? Icons.check_circle_outline : Icons.inbox_rounded,
                    color: Colors.white24,
                    size: 60,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    isHistoryTab
                        ? t('No Reviewed Requests Yet', 'Belum Ada Riwayat Ditinjau')
                        : t('No Pending Requests', 'Tidak Ada Permohonan Tertunda'),
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isHistoryTab
                        ? t('Approved and rejected requests will appear here.', 'Permohonan yang disetujui atau ditolak akan tersimpan di sini.')
                        : t('All creator edit and delete submissions will appear here for review.', 'Seluruh permohonan edit atau hapus dari kreator akan masuk ke sini untuk ditinjau.'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 14),
          itemBuilder: (context, index) {
            final request = list[index];
            return _buildRequestCard(request, t, isIndo);
          },
        );
      },
    );
  }
//............................................................................//

//No ke-6....................................................................//
//REQUEST CARD COMPONENT (DATA COMPARISON & VIDEO WATCH LINK)                //
  Widget _buildRequestCard(RequestMytubeModel req, String Function(String, String) t, bool isIndo) {
    final isEdit = req.requestType == 'EDIT';
    final isPending = req.status == 'PENDING';

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E24),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isPending
              ? (isEdit ? Colors.blueAccent.withOpacity(0.5) : Colors.redAccent.withOpacity(0.5))
              : Colors.white12,
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Kartu: Tipe Permohonan & Status
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Badge Tipe Permohonan (EDIT / DELETE)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isEdit ? Colors.blueAccent.withOpacity(0.2) : Colors.redAccent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: isEdit ? Colors.blueAccent : Colors.redAccent, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(isEdit ? Icons.edit_note_rounded : Icons.delete_outline_rounded,
                          color: isEdit ? Colors.blueAccent : Colors.redAccent, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        isEdit ? t('EDIT REQUEST', 'PERMOHONAN EDIT') : t('DELETE REQUEST', 'PERMOHONAN HAPUS'),
                        style: TextStyle(
                          color: isEdit ? Colors.blueAccent : Colors.redAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Badge Format Video (SHORT 9:16 vs LONG 16:9)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    req.videoType == 'LONG' ? '16:9 Long' : '9:16 Short',
                    style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
                const Spacer(),

                // Status Badge
                _buildStatusBadge(req.status),
              ],
            ),
          ),
          const Divider(color: Colors.white10, height: 1),

          // Badan Kartu: Info Video & Tautan Pemutaran Video Aktif
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail Video
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: req.videoType == 'LONG' ? 100 : 70,
                    height: req.videoType == 'LONG' ? 56 : 100,
                    color: Colors.black38,
                    child: req.thumbnailUrl.isNotEmpty
                        ? Image.network(req.thumbnailUrl, fit: BoxFit.cover)
                        : const Icon(Icons.video_library, color: Colors.white24, size: 28),
                  ),
                ),
                const SizedBox(width: 14),

                // Detail Judul & Info Kreator
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        req.videoTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '@${req.channelName} • ${req.creatorEmail}',
                        style: const TextStyle(color: Colors.amberAccent, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),

                      // Tombol Putar & Pastikan Video oleh Admin Pusat
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.play_circle_fill_rounded, size: 18),
                        label: Text(
                          t('Watch / Verify Video', 'Tonton / Cek Video'),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () {
                          _showVideoPlayerDialog(context, req.videoUrl, req.videoTitle);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Detail Perubahan Data (Khusus EDIT)
          if (isEdit) ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF141418),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t('PROPOSED CHANGES (NEW VS OLD)', 'USULAN PERUBAHAN (BARU VS LAMA)'),
                    style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  _buildDiffRow('Judul', req.oldTitle ?? '-', req.newTitle ?? '-'),
                  const SizedBox(height: 6),
                  _buildDiffRow('Kategori', req.oldCategory ?? '-', req.newCategory ?? '-'),
                  const SizedBox(height: 6),
                  _buildDiffRow('Bahasa', req.oldLanguage ?? '-', req.newLanguage ?? '-'),
                ],
              ),
            ),
          ],

          // Alasan Penghapusan (Khusus DELETE)
          if (!isEdit && req.deleteReason != null && req.deleteReason!.isNotEmpty) ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF141418),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t('CREATOR DELETION REASON', 'ALASAN PENGHAPUSAN OLEH KREATOR'),
                    style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    req.deleteReason!,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],

          // Tombol Aksi Admin (Khusus Status PENDING)
          if (isPending) ...[
            const Divider(color: Colors.white10, height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent, width: 1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                      ),
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: Text(t('Reject', 'Tolak'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      onPressed: () => _handleReject(req, isIndo),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: Text(t('Approve', 'Setujui'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      onPressed: () => _handleApprove(req, isIndo),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Catatan Riwayat jika sudah selesai ditinjau
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                '${t('Reviewed by', 'Ditinjau oleh')}: ${req.reviewedBy ?? 'Admin'}',
                style: const TextStyle(color: Colors.white38, fontSize: 11.5, fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDiffRow(String label, String oldVal, String newVal) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 65,
          child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ),
        const Text(': ', style: TextStyle(color: Colors.white30, fontSize: 12)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(oldVal, style: const TextStyle(color: Colors.redAccent, fontSize: 12, decoration: TextDecoration.lineThrough)),
              Text(newVal, style: const TextStyle(color: Colors.greenAccent, fontSize: 12.5, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg = Colors.orangeAccent;
    if (status == 'APPROVED') bg = Colors.green;
    if (status == 'REJECTED') bg = Colors.redAccent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
      child: Text(
        status,
        style: TextStyle(color: bg, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
//............................................................................//

//No ke-7....................................................................//
//VIDEO PREVIEW PLAYER DIALOG                                                //
  void _showVideoPlayerDialog(BuildContext context, String videoUrl, String title) {
    if (videoUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tautan video tidak valid.'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => _VerificationPlayerDialog(videoUrl: videoUrl, title: title),
    );
  }
}

// Widget Pemutar Video Khusus Verifikasi Admin
class _VerificationPlayerDialog extends StatefulWidget {
  final String videoUrl;
  final String title;

  const _VerificationPlayerDialog({required this.videoUrl, required this.title});

  @override
  State<_VerificationPlayerDialog> createState() => _VerificationPlayerDialogState();
}

class _VerificationPlayerDialogState extends State<_VerificationPlayerDialog> {
  VideoPlayerController? _controller;
  bool _isInit = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _isInit = true);
          _controller?.setLooping(true);
          try {
            _controller?.play();
          } catch (_) {
            if (kIsWeb) {
              _controller?.setVolume(0.0);
              _controller?.play();
            }
          }
        }
      }).catchError((e) {
        if (mounted) setState(() => _hasError = true);
      });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: const Color(0xFF1E1E24),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.65),
            child: _hasError
                ? const Padding(
                    padding: EdgeInsets.all(32),
                    child: Text('Gagal memuat video pemutar.', style: TextStyle(color: Colors.redAccent)),
                  )
                : (_controller != null && _isInit)
                    ? AspectRatio(
                        aspectRatio: _controller!.value.aspectRatio,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _controller!.value.isPlaying ? _controller!.pause() : _controller!.play();
                            });
                          },
                          child: VideoPlayer(_controller!),
                        ),
                      )
                    : const Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(color: Colors.amberAccent),
                      ),
          ),
        ],
      ),
    );
  }
}
//............................................................................//