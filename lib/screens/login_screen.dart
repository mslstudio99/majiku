//..................................................//
// LIB/SCREENS/LOGIN_SCREEN.DART                    //
//..................................................//

//No ke-1...........................................//
// IMPORT DAN SETUP AWAL                            //
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// 1. Impor Auth ViewModel
import '../view_model/auth_view_model.dart';
// 2. Impor Config Provider (untuk akses bahasa)
import '../providers/config_provider.dart';

/*
KATEGORI_AUTH_UPDATE_04 (REVISI PARIPURNA - UX FORGET PASSWORD)
Nama File: lib/screens/login_screen.dart
Tujuan:
- [FIX] Menghilangkan error bubble pada password saat menekan tombol Lupa Sandi.
- [UI] Floating Error Bubble modern dengan Glassmorphism & Pointer.
- [UX] Validasi instan yang menunjuk langsung ke objek (Visual Cue).
- [ANTI-REGRESI] Mempertahankan semua logic Auth dan Multi-bahasa.
*/
//..................................................//

//No ke-2...........................................//
// LOGIN SCREEN STATE & LOGIC AUTH                  //
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // State untuk kontrol visibilitas error bubble
  String? _emailErrorMsg;
  String? _passwordErrorMsg;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Helper untuk bahasa
  String _getTr(bool isIndo, String en, String id) => isIndo ? id : en;

  // --- Logika Handler Lupa Password ---
  void _handleForgotPassword() {
    final isIndo = ref.read(appLanguageProvider).languageCode == 'id';
    final email = _emailController.text.trim();
    
    // [MODIFIKASI KRITIS]: Menghapus error password yang mungkin tersangkut,
    // karena reset password murni hanya membutuhkan email.
    setState(() {
      _passwordErrorMsg = null; 
      
      if (email.isEmpty) {
        _emailErrorMsg = _getTr(isIndo, 'Enter email to reset!', 'Isi email untuk reset!');
      } else {
        _emailErrorMsg = null;
      }
    });

    if (email.isEmpty) return;

    ref.read(authViewModelProvider.notifier).sendPasswordResetEmail(email);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_getTr(isIndo, 'Reset link sent!', 'Link reset terkirim!')),
        backgroundColor: Colors.green,
      ),
    );
  }
//..................................................//

//No ke-3...........................................//
// BUILD UI & WIDGET LAYOUT                         //
  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authViewModelProvider);
    final isIndo = ref.watch(appLanguageProvider).languageCode == 'id';
    String t(String en, String id) => isIndo ? id : en;

    return Scaffold(
      appBar: AppBar(
        title: Text(t('Majiku - Welcome', 'Majiku - Selamat Datang')),
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  t('Sign In or Create Account', 'Masuk atau Buat Akun'),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                
                // --- Kolom Email + Bubble ---
                _buildModernInput(
                  controller: _emailController,
                  label: 'Email',
                  icon: Icons.email_outlined,
                  errorMsg: _emailErrorMsg,
                  onChanged: (v) => setState(() => _emailErrorMsg = null),
                ),
                
                const SizedBox(height: 24),
                
                // --- Kolom Password + Bubble ---
                _buildModernInput(
                  controller: _passwordController,
                  label: t('Password', 'Kata Sandi'),
                  icon: Icons.lock_outline,
                  isPassword: true,
                  errorMsg: _passwordErrorMsg,
                  onChanged: (v) => setState(() => _passwordErrorMsg = null),
                ),
                
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: isLoading ? null : _handleForgotPassword,
                    child: Text(t('Forgot Password?', 'Lupa Kata Sandi?')),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // --- Sign In Button ---
                ElevatedButton(
                  onPressed: isLoading ? null : () {
                    ref.read(authViewModelProvider.notifier).signInWithEmail(
                      _emailController.text.trim(),
                      _passwordController.text.trim(),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: isLoading 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(t('Sign In', 'Masuk')),
                ),
                
                const SizedBox(height: 12),
                
                // --- Register Button (Trigger Validation) ---
                OutlinedButton(
                  onPressed: isLoading ? null : () {
                    final email = _emailController.text.trim();
                    final pass = _passwordController.text.trim();

                    // Validasi keren diletakkan di sini
                    setState(() {
                      if (email.isEmpty) {
                        _emailErrorMsg = t('Enter active email!', 'Isi email aktif!');
                      }
                      if (pass.isEmpty) {
                        _passwordErrorMsg = t('Enter password!', 'Isi kata sandi!');
                      }
                    });

                    if (email.isNotEmpty && pass.isNotEmpty) {
                      ref.read(authViewModelProvider.notifier).createUserWithEmail(email, pass);
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: Theme.of(context).primaryColor),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(t('Create Account', 'Buat Akun')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Widget Helper untuk Input dengan Floating Bubble di samping kanan
  Widget _buildModernInput({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? errorMsg,
    bool isPassword = false,
    required Function(String) onChanged,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        TextField(
          controller: controller,
          obscureText: isPassword,
          onChanged: onChanged,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Color(0xFFFFD700), width: 2.5),
            ),
          ),
        ),
        // --- THE COOL BUBBLE ---
        if (errorMsg != null)
          Positioned(
            right: -10, // Menempel sedikit ke dalam agar pointer pas
            top: -45,   // Melayang di atas kolom
            child: _ErrorTooltip(message: errorMsg),
          ),
      ],
    );
  }
}
//..................................................//

//No ke-4...........................................//
// CUSTOM TOOLTIP WIDGET & PAINTER                  //
// Widget Kotak Peringatan Custom (Pointer & Bubble)
class _ErrorTooltip extends StatelessWidget {
  final String message;
  const _ErrorTooltip({required this.message});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.redAccent.shade700,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            message,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
        // Pointer (Segitiga kecil menunjuk ke kolom)
        Padding(
          padding: const EdgeInsets.only(right: 20), // [FIXED] Menggunakan EdgeInsets.only
          child: CustomPaint(
            size: const Size(12, 8),
            painter: _TrianglePainter(color: Colors.redAccent.shade700),
          ),
        ),
      ],
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;
  _TrianglePainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width / 2, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
//..................................................//