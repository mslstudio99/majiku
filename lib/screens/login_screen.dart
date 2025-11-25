// [RILIS BERSIH - LOGIN SCREEN UPDATE]
// KATEGORI_AUTH_UPDATE_01
// Lokasi: lib/screens/login_screen.dart
// TUJUAN:
// - [HAPUS] Menghapus tombol Sign In with Google.
// - [FITUR] Menambahkan tombol Lupa Password (Reset via Email).
// - [UI] Merapikan tata letak tombol.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../view_model/auth_view_model.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // --- [BARU] Logika Handler Lupa Password ---
  void _handleForgotPassword() {
    final email = _emailController.text.trim();
    
    if (email.isEmpty) {
      // Validasi UI: Email harus diisi
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mohon masukkan email Anda untuk mereset password.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Memanggil fungsi reset password di ViewModel
    // Pastikan method 'sendPasswordResetEmail' sudah ada di AuthViewModel Anda
    ref.read(authViewModelProvider.notifier).sendPasswordResetEmail(email);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Link reset password telah dikirim ke $email (jika terdaftar).'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watch the loading state from the view model
    final isLoading = ref.watch(authViewModelProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Majiku - Welcome'),
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
                  'Sign In or Create Account',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                
                // --- Email Text Field ---
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                
                // --- Password Text Field ---
                TextField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  ),
                  obscureText: true,
                ),
                
                // --- [BARU] Tombol Lupa Password ---
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: isLoading ? null : _handleForgotPassword,
                    child: const Text(
                      'Lupa Password?',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // --- Sign In Button ---
                ElevatedButton(
                  onPressed: isLoading
                      ? null // Disable button when loading
                      : () {
                          ref.read(authViewModelProvider.notifier).signInWithEmail(
                                _emailController.text,
                                _passwordController.text,
                              );
                        },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white, 
                  ),
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white, 
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Sign In'),
                ),
                
                const SizedBox(height: 12),
                
                // --- Register Button ---
                OutlinedButton(
                  onPressed: isLoading
                      ? null // Disable button when loading
                      : () {
                          ref.read(authViewModelProvider.notifier).createUserWithEmail(
                                _emailController.text,
                                _passwordController.text,
                              );
                        },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Create Account'),
                ),
                
                // [DIHAPUS] Bagian Google Sign In & Divider dihapus sesuai permintaan
              ],
            ),
          ),
        ),
      ),
    );
  }
}