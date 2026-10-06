//................................................................//
// NAMA FILE: VERIFY_EMAIL_SCREEN.DART                            //
// PATH/DIREKTORI: lib/screens/verify_email_screen.dart           //
// FUNGSI UTAMA: LAYAR VERIFIKASI EMAIL PENDAFTAR BARU & KLAIM   //
//................................................................//

//No ke-1.........................................................//
// IMPORT DAN SETUP AWAL                                          //
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Dependensi Majiku
import '../providers/config_provider.dart';
import '../providers/user_provider.dart';
import '../view_model/auth_view_model.dart';

/*
KATEGORI_AUTH_UPDATE_06 (REVISI PERDANA - HALAMAN VERIFIKASI MANDIRI)
Nama File: lib/screens/verify_email_screen.dart
Tujuan:
- [ZERO FLICKER] Menjadi dermaga pendaftar baru tanpa pernah menyentuh Dashboard.
- [AUTO POLLING] Mendeteksi klik tautan verifikasi di email secara otomatis di latar belakang.
- [COOLDOWN ANTI SPAM] Pembatas pengiriman ulang tautan verifikasi setiap 60 detik.
- [AUTO CLAIM BONUS] Memanggil pencairan bonus selamat datang setelah verifikasi terkonfirmasi.
*/
//................................................................//

//No ke-2.........................................................//
// STATE, LOGIKA VERIFIKASI, POLLING TIMER & ANIMASI              //
class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  Timer? _pollingTimer;
  Timer? _resendCooldownTimer;
  int _cooldownSeconds = 0;
  bool _isCheckingManual = false;
  
  // State untuk menampilkan UI transisi sukses
  bool _isVerificationSuccessful = false;

  @override
  void initState() {
    super.initState();
    // Memulai polling otomatis berkala setiap 5 detik
    _startPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _resendCooldownTimer?.cancel();
    super.dispose();
  }

  // Polling otomatis untuk mendeteksi klik tautan di background
  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      await _checkEmailVerifiedSilently();
    });
  }

  // Pengecekan senyap tanpa pop-up pesan
  Future<void> _checkEmailVerifiedSilently() async {
    if (_isVerificationSuccessful) return; // Jika sudah sukses, hentikan pengecekan

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await user.reload();
      final refreshedUser = FirebaseAuth.instance.currentUser;

      if (refreshedUser != null && refreshedUser.emailVerified) {
        _pollingTimer?.cancel();
        await _onVerificationSuccess();
      }
    } catch (e) {
      debugPrint("[VerifyEmailScreen] Polling check error: $e");
    }
  }

  // Eksekusi sukses verifikasi & transisi animasi UX mewah
  Future<void> _onVerificationSuccess() async {
    if (!mounted) return;
    
    // 1. Ubah state untuk menampilkan animasi centang hijau di UI
    setState(() {
      _isVerificationSuccessful = true;
    });

    try {
      final authService = ref.read(authServiceProvider);
      // 2. Cairkan bonus di backend (Background process)
      await authService.claimWelcomeBonus();
      
      // 3. Tahan layar selama 3 detik agar pengguna sempat menikmati pesan sukses
      await Future.delayed(const Duration(seconds: 3));

      // 4. Refresh routing utama agar otomatis terbang ke Dashboard
      ref.invalidate(firestoreUserProvider);
    } catch (e) {
      debugPrint("[VerifyEmailScreen] Gagal mencairkan bonus: $e");
      // Failsafe: Tetap arahkan ke dashboard meski bonus telat cair
      await Future.delayed(const Duration(seconds: 3));
      ref.invalidate(firestoreUserProvider);
    }
  }

  // Pengecekan manual saat tombol "Saya Sudah Verifikasi" ditekan
  Future<void> _handleManualCheck() async {
    if (_isCheckingManual || _isVerificationSuccessful) return;
    setState(() => _isCheckingManual = true);

    final isIndo = ref.read(appLanguageProvider).languageCode == 'id';

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.reload();
        final refreshedUser = FirebaseAuth.instance.currentUser;

        if (refreshedUser != null && refreshedUser.emailVerified) {
          _pollingTimer?.cancel();
          await _onVerificationSuccess();
          return;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isIndo 
                ? 'Email belum terverifikasi. Silakan klik tautan di kotak masuk atau folder spam Anda.'
                : 'Email is not verified yet. Please click the link in your inbox or spam folder.',
            ),
            backgroundColor: Colors.orangeAccent.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isIndo ? 'Gagal memeriksa status: $e' : 'Check failed: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted && !_isVerificationSuccessful) {
        setState(() => _isCheckingManual = false);
      }
    }
  }

  // Mengirim ulang email verifikasi dengan timer cooldown 60 detik
  Future<void> _handleResendEmail() async {
    if (_cooldownSeconds > 0 || _isVerificationSuccessful) return;

    final isIndo = ref.read(appLanguageProvider).languageCode == 'id';
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    try {
      await user.sendEmailVerification();

      setState(() => _cooldownSeconds = 60);
      _resendCooldownTimer?.cancel();
      _resendCooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_cooldownSeconds > 0) {
          setState(() => _cooldownSeconds--);
        } else {
          timer.cancel();
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isIndo
                ? 'Tautan verifikasi baru berhasil dikirim ke ${user.email}!'
                : 'A new verification link has been sent to ${user.email}!',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isIndo ? 'Gagal mengirim email: $e' : 'Failed to send email: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }
//................................................................//

//No ke-3.........................................................//
// BUILD UI & WIDGET LAYOUT                                       //
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? '';
    final isIndo = ref.watch(appLanguageProvider).languageCode == 'id';
    String t(String en, String id) => isIndo ? id : en;

    return Scaffold(
      backgroundColor: const Color(0xFF12121A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(t('Majiku - Verification', 'Majiku - Verifikasi Email')),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            // Jika sukses, tampilkan UI Transisi Sukses. Jika belum, tampilkan UI Normal.
            child: _isVerificationSuccessful 
              ? _buildSuccessView(t) 
              : _buildVerificationView(t, email),
          ),
        ),
      ),
    );
  }

  // --- UI Transisi Verifikasi Sukses (UX Bintang 5) ---
  Widget _buildSuccessView(String Function(String, String) t) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 800),
          curve: Curves.elasticOut,
          builder: (context, value, child) {
            return Transform.scale(
              scale: value,
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.green.withOpacity(0.15),
                ),
                child: const Icon(
                  Icons.check_circle_outline_rounded,
                  size: 96,
                  color: Colors.greenAccent,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 32),
        Text(
          t('Verification Successful!', 'Verifikasi Sukses!'),
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          t(
            'We are preparing your welcome bonus tokens.\nYou will be redirected to the dashboard shortly...',
            'Menyiapkan bonus token selamat datang Anda.\nAnda akan dialihkan ke dashboard sesaat lagi...',
          ),
          style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.5),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
          ),
        ),
      ],
    );
  }

  // --- UI Verifikasi Normal ---
  Widget _buildVerificationView(String Function(String, String) t, String email) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFFFD700).withOpacity(0.1),
            border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.3), width: 2),
          ),
          child: const Icon(
            Icons.mark_email_unread_outlined,
            size: 72,
            color: Color(0xFFFFD700),
          ),
        ),
        const SizedBox(height: 32),
        Text(
          t('Verify Your Email Address', 'Verifikasi Alamat Email Anda'),
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          t(
            'We have sent a verification link to:',
            'Kami telah mengirimkan tautan verifikasi ke:',
          ),
          style: const TextStyle(color: Colors.white70, fontSize: 14),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2C),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white12),
          ),
          child: Text(
            email,
            style: const TextStyle(
              color: Color(0xFFFFD700),
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.amberAccent, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  t(
                    'Please check your inbox or Spam/Promotions folder, then click the link to activate your account.',
                    'Periksa kotak masuk atau folder Spam/Promosi, lalu klik tautan untuk mengaktifkan akun dan jatah token gratis Anda.',
                  ),
                  style: const TextStyle(color: Colors.white60, fontSize: 12, height: 1.4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: _isCheckingManual ? null : _handleManualCheck,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _isCheckingManual
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Text(
                t('I Have Verified My Email', 'Saya Sudah Klik Verifikasi'),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
              ),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: _cooldownSeconds > 0 ? null : _handleResendEmail,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            side: BorderSide(
              color: _cooldownSeconds > 0 ? Colors.white24 : const Color(0xFFFFD700),
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(
            _cooldownSeconds > 0
              ? t('Resend in ${_cooldownSeconds}s', 'Kirim Ulang (${_cooldownSeconds}s)')
              : t('Resend Verification Link', 'Kirim Ulang Tautan Verifikasi'),
            style: TextStyle(
              color: _cooldownSeconds > 0 ? Colors.white38 : const Color(0xFFFFD700),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 24),
        TextButton.icon(
          onPressed: () async {
            _pollingTimer?.cancel();
            _resendCooldownTimer?.cancel();
            await ref.read(authViewModelProvider.notifier).signOut();
          },
          icon: const Icon(Icons.logout, color: Colors.white54, size: 18),
          label: Text(
            t('Wrong email? Sign Out', 'Salah email? Keluar / Ganti Akun'),
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
        ),
      ],
    );
  }
}
//................................................................//