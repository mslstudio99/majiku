//.......................................................//
// NAMA FILE: AD_SERVICE.DART                            //
// DIREKTORI: LIB/SERVICES/                              //
// DESKRIPSI: PENGELOLA IKLAN GOOGLE ADMOB (INTERSTITIAL)//
//.......................................................//

//No ke-1: IMPOR & SETUP DEPENDENSI......................//
//.......................................................//
import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, VoidCallback, debugPrint;
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  // Pola Singleton
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  InterstitialAd? _interstitialAd;
  bool _isAdLoading = false;
  DateTime? _lastAdShownTime;

  // Manajemen Timer Auto-Retry
  Timer? _retryTimer;
  int _retryAttempt = 0;

  // [PENTING] Ad Unit ID Interstitial Asli (Production)
  final String _interstitialAdUnitId = 'ca-app-pub-9735424824803924/9882867010';
//.......................................................//

//No ke-2: INISIALISASI & PRE-LOAD IKLAN (AUTO-RETRY)....//
//.......................................................//
  /// Memuat iklan Interstitial di latar belakang dengan batas maksimal retry
  void loadInterstitial({VoidCallback? onAdLoadedShow}) {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;
    if (_interstitialAd != null || _isAdLoading) return;

    if (_retryAttempt >= 3) {
      debugPrint("⛔ AdMob: Batas maksimal percobaan (3x) tercapai. Menghentikan auto-retry.");
      return;
    }

    _isAdLoading = true;
    debugPrint("📡 AdMob: Memulai permintaan iklan Interstitial...");

    InterstitialAd.load(
      adUnitId: _interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isAdLoading = false;
          _retryAttempt = 0;
          _retryTimer?.cancel();
          debugPrint("✅ AdMob: Iklan Interstitial berhasil dimuat.");

          // Jika ada permintaan tayang yang tertunda saat iklan baru selesai diunduh
          if (onAdLoadedShow != null) {
            onAdLoadedShow();
          }
        },
        onAdFailedToLoad: (error) {
          _interstitialAd = null;
          _isAdLoading = false;
          debugPrint("⚠️ AdMob Gagal Memuat: [Code: ${error.code}] ${error.message} (Domain: ${error.domain})");

          _retryAttempt++;
          if (_retryAttempt < 3) {
            final int retryDelay = _retryAttempt == 1 ? 10 : 30;
            debugPrint("⏳ AdMob: Mencoba memuat ulang dalam $retryDelay detik...");
            
            _retryTimer?.cancel();
            _retryTimer = Timer(Duration(seconds: retryDelay), () {
              loadInterstitial();
            });
          }
        },
      ),
    );
  }

  void _setFullScreenCallbacks(InterstitialAd ad, {VoidCallback? onAdClicked}) {
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdClicked: (ad) {
        debugPrint("🎯 AdMob: Pengguna mengklik iklan Interstitial.");
        if (onAdClicked != null) {
          onAdClicked();
        }
      },
      onAdDismissedFullScreenContent: (ad) {
        debugPrint("ℹ️ AdMob: Iklan Interstitial ditutup oleh pengguna.");
        ad.dispose();
        _interstitialAd = null;
        _retryAttempt = 0;
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint("❌ AdMob: Gagal menampilkan iklan fullscreen: ${error.message}");
        ad.dispose();
        _interstitialAd = null;
        _retryAttempt = 0;
      },
    );
  }
//.......................................................//

//No ke-3: LOGIKA TAMPILKAN IKLAN........................//
//.......................................................//
  /// Menampilkan iklan Interstitial saat dipanggil dari FreeDailyQuotesScreen
  void showInterstitial({bool force = false, VoidCallback? onAdClicked}) {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;

    final now = DateTime.now();
    const int minCooldownSeconds = 120; // Disesuaikan ke 2 Menit agar responsif di layar quotes

    if (!force && _lastAdShownTime != null) {
      final difference = now.difference(_lastAdShownTime!).inSeconds;
      if (difference < minCooldownSeconds) {
        final remainingSeconds = minCooldownSeconds - difference;
        debugPrint("⏱️ AdMob: Iklan ditahan cooldown. Sisa waktu: ${remainingSeconds}s.");
        return; 
      }
    }

    if (_interstitialAd != null) {
      debugPrint("🚀 AdMob: Menayangkan iklan Interstitial...");
      _setFullScreenCallbacks(_interstitialAd!, onAdClicked: onAdClicked);
      _interstitialAd!.show();
      _lastAdShownTime = now;
      _interstitialAd = null;
    } else {
      debugPrint("ℹ️ AdMob: Iklan belum siap. Mengunduh & menyiapkan penayangan otomatis...");
      loadInterstitial(onAdLoadedShow: () {
        showInterstitial(force: force, onAdClicked: onAdClicked);
      });
    }
  }
}
//.......................................................//