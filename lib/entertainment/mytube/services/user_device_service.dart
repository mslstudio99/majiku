//======================================================================//
// DIRECTORY: MAJIKU/LIB/ENTERTAINMENT/MYTUBE/SERVICES/                  //
// FILE: USER_DEVICE_SERVICE.DART                                       //
//======================================================================//

//No ke-1...............................................................//
//INISIALISASI DEPENDENSI DAN SINGLETON INSTANCE                        //
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class UserDeviceService {
  UserDeviceService._internal();
  static final UserDeviceService instance = UserDeviceService._internal();

  bool _isWakeLockActive = false;
  VideoPlayerController? _attachedController;
  VoidCallback? _activeControllerListener;

  bool get isWakeLockActive => _isWakeLockActive;
//----------------------------------------------------------------------//

//No ke-2...............................................................//
//SCREEN WAKE LOCK ENGINE & CONTROLLER ATTACHMENT                       //
  void attachPlayer(VideoPlayerController? controller) {
    if (_attachedController == controller) {
      _syncWakeLockWithCurrentState();
      return;
    }

    detachPlayer(keepWakeLock: false);

    if (controller == null) return;

    _attachedController = controller;
    _activeControllerListener = () {
      _syncWakeLockWithCurrentState();
    };

    _attachedController!.addListener(_activeControllerListener!);
    _syncWakeLockWithCurrentState();
  }

  void _syncWakeLockWithCurrentState() {
    if (_attachedController == null) {
      if (_isWakeLockActive) {
        setWakeLock(false);
      }
      return;
    }

    final bool isInitialized = _attachedController!.value.isInitialized;
    final bool isPlaying = _attachedController!.value.isPlaying;

    final bool shouldKeepScreenOn = isInitialized && isPlaying;

    if (shouldKeepScreenOn != _isWakeLockActive) {
      setWakeLock(shouldKeepScreenOn);
    }
  }

  Future<void> setWakeLock(bool enable) async {
    if (_isWakeLockActive == enable) return;
    _isWakeLockActive = enable;

    try {
      if (enable) {
        await WakelockPlus.enable();
      } else {
        await WakelockPlus.disable();
      }
    } catch (e) {
      debugPrint('[UserDeviceService] Wakelock error: $e');
    }
  }

  void detachPlayer({bool keepWakeLock = false}) {
    if (_attachedController != null && _activeControllerListener != null) {
      _attachedController!.removeListener(_activeControllerListener!);
    }
    _attachedController = null;
    _activeControllerListener = null;

    if (!keepWakeLock) {
      setWakeLock(false);
    }
  }
//----------------------------------------------------------------------//

//No ke-3...............................................................//
//APP LIFECYCLE MANAGEMENT & BACKGROUND BATTERY SAFE-GUARD              //
  void handleAppLifecycle(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      if (_isWakeLockActive) {
        setWakeLock(false);
      }
    } else if (state == AppLifecycleState.resumed) {
      _syncWakeLockWithCurrentState();
    }
  }
//----------------------------------------------------------------------//

//No ke-4...............................................................//
//EXTENSIBLE DEVICE CONTROLS (FUTURE EXPANSION HOOKS)                   //
  Future<void> setScreenOrientation(List<DeviceOrientation> orientations) async {
    try {
      await SystemChrome.setPreferredOrientations(orientations);
    } catch (e) {
      debugPrint('[UserDeviceService] SetOrientation error: $e');
    }
  }

  Future<void> resetScreenOrientation() async {
    try {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } catch (e) {
      debugPrint('[UserDeviceService] ResetOrientation error: $e');
    }
  }

  Future<void> configureAudioFocusDucking() async {
    // Siap diaktifkan kapan saja jika keluhan video call ingin dibuka kembali
  }
}
//----------------------------------------------------------------------//