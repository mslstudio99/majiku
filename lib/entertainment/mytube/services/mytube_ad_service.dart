//============================================================================//
// DIREKTORI: lib/entertainment/mytube/services/                             //
// FILE: MYTUBE_AD_SERVICE.DART                                              //
// ORKESTRATOR IKLAN MYTUBE (NATURAL BREAK 1 MENIT AWAL & 7 MENIT BERKALA)   //
//============================================================================//

//No ke-1....................................................................//
//IMPORTS & DEPENDENCIES                                                     //
import 'package:flutter/foundation.dart';
import '../../../services/ad_service.dart';
import '../../../services/firestore_service.dart';
//............................................................................//

//No ke-2....................................................................//
//SINGLETON CLASS DECLARATION & AD TIMING LOGIC                              //
class MytubeAdService {
  MytubeAdService._privateConstructor();
  static final MytubeAdService instance = MytubeAdService._privateConstructor();

  // Waktu tayang berikutnya (1 menit pertama sejak masuk, lalu 7 menit berkala)
  DateTime? _nextAdEligibleTime;

  // Syarat wajib: Minimal pernah menyetel/menonton setidaknya 1 video
  bool _hasPlayedAtLeastOneVideo = false;

  // Mutex flag untuk mencegah iklan ganda tampil serentak
  bool _isAdShowing = false;

  /// Memulai stopwatch sesi MyTube sejak pertama kali dibuka (Home atau Feed)
  void startSessionTimerIfNeeded() {
    if (!kIsWeb) {
      // Pastikan AdService mulai memuat iklan interstitial di latar belakang
      AdService().loadInterstitial();
    }

    if (_nextAdEligibleTime == null) {
      // Kunci 1 menit pertama sejak pengguna pertama kali masuk ke MyTube
      _nextAdEligibleTime = DateTime.now().add(const Duration(minutes: 1));
      debugPrint('[MYTUBE AD] Stopwatch MyTube dimulai. Iklan pertama eligible setelah 1 menit.');
    }
  }

  /// Menandai bahwa minimal 1 video sudah pernah diputar
  void recordVideoPlayed() {
    if (!_hasPlayedAtLeastOneVideo) {
      _hasPlayedAtLeastOneVideo = true;
      debugPrint('[MYTUBE AD] Syarat "Minimal menyetel 1 video" terpenuhi.');
    }
  }

  /// Mengecek apakah semua syarat iklan terpenuhi (Platform, Waktu, Video Terputar & Kesiapan AdMob)
  bool get isAdEligible {
    if (kIsWeb) return false;
    if (_isAdShowing) return false;
    if (!_hasPlayedAtLeastOneVideo) return false;
    if (_nextAdEligibleTime == null) return false;

    final now = DateTime.now();
    final bool isTimePassed = now.isAfter(_nextAdEligibleTime!);

    // [AUTO-HEAL PRELOAD]: Jika waktu sudah jatuh tempo namun iklan belum ready, picu load di latar belakang
    if (isTimePassed && !AdService().isAdReady) {
      AdService().loadInterstitial();
      return false;
    }

    return isTimePassed && AdService().isAdReady;
  }

  /// [EKSEKUTOR IKLAN NATURAL BREAK]:
  /// Menjalankan iklan interstitial saat jeda alami (klik video di Home atau ganti video di Feed).
  /// [onBeforeAd]: Callback untuk mematikan suara/pause video lama sebelum iklan muncul.
  /// [onActionProceed]: Aksi utama yang akan dilanjutkan (misal: navigasi atau play video baru).
  void showAdIfEligible({
    VoidCallback? onBeforeAd,
    required VoidCallback onActionProceed,
  }) {
    if (isAdEligible) {
      _isAdShowing = true;
      debugPrint('[MYTUBE AD] Menayangkan iklan interstitial (Natural Break)...');

      // 1. Matikan suara & pause video lama seketika agar tidak bocor ke iklan
      onBeforeAd?.call();

      // [PELACAKAN KONVERSI TERPADU]:
      // Catat konversi tayangan iklan langsung ke subFeatureKey 'feed' (ShoVi / MyTube)
      FirestoreService().logFeatureActivity(
        featureKey: 'mytube',
        subFeatureKey: 'feed',
        eventType: 'conversion',
      );

      // [FAIL-SAFE GUARD]: Menjamin onActionProceed dieksekusi tepat 1 kali tanpa risiko freeze
      bool hasProceeded = false;
      void proceedSafely() {
        if (!hasProceeded) {
          hasProceeded = true;
          onActionProceed();
        }
      }

      // 2. Tayangkan Iklan Interstitial via AdService dengan Pelindung Error
      try {
        AdService().showInterstitial(
          onAdClicked: () {
            debugPrint('[MYTUBE AD] Iklan diklik oleh pengguna.');
          },
          onAdDismissed: () {
            _isAdShowing = false;
            // Kunci interval berikutnya tepat 7 menit setelah iklan ditutup
            _nextAdEligibleTime = DateTime.now().add(const Duration(minutes: 7));
            debugPrint('[MYTUBE AD] Iklan ditutup. Iklan berikutnya eligible setelah 7 menit.');

            // [PRELOAD SIKLUS BERIKUTNYA]: Segera muat iklan baru di background untuk 7 menit mendatang
            if (!kIsWeb) {
              AdService().loadInterstitial();
            }

            // Lanjutkan aksi pengguna (navigasi / play video baru)
            proceedSafely();
          },
        );
      } catch (e) {
        debugPrint('[MYTUBE AD ERROR] Kendala penayangan iklan AdMob: $e');
        _isAdShowing = false;
        _nextAdEligibleTime = DateTime.now().add(const Duration(minutes: 2));
        if (!kIsWeb) {
          AdService().loadInterstitial();
        }
        proceedSafely();
      }
    } else {
      // Jika syarat belum terpenuhi, langsung jalankan aksi pengguna tanpa jeda iklan
      onActionProceed();
    }
  }
}
//............................................................................//