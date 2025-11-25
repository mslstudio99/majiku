// [RILIS BERSIH - TOP UP SCREEN FINAL (FIX 400 & QUANTITY)]
// KATEGORI_UI_UPDATE NO_URUT_02
// Tujuan:
// - [FIX 400] Mengirim 'packageId' yang valid ke backend.
// - [LOGIC] Mengirim 'quantity' agar user bisa beli kelipatan.
// - [DATA] Menggunakan harga dinamis dari config.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Untuk InputFormatter
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:url_launcher/url_launcher.dart';

// Impor provider
import '../providers/user_provider.dart';
import '../providers/config_provider.dart'; // Provider Config yang BENAR
import '../models/app_config.dart'; // Model Config

class TopUpScreen extends ConsumerStatefulWidget {
  const TopUpScreen({super.key});

  @override
  ConsumerState<TopUpScreen> createState() => _TopUpScreenState();
}

class _TopUpScreenState extends ConsumerState<TopUpScreen> {
  bool _isLoading = false;

  // State untuk Quantity (Stepper)
  int _quantity = 1; 
  final TextEditingController _quantityController =
      TextEditingController(text: '1');

  final Map<String, String> paymentOptions = {
    'BC': 'BCA Virtual Account',
    'M2': 'Mandiri Virtual Account (HP)',
    'I1': 'BNI Virtual Account',
    'BR': 'BRIVA (BRI)',
    'BV': 'BSI Virtual Account',
    'SP': 'ShopeePay (QRIS)',
    'VC': 'Kartu Kredit (Visa/Master/JCB)',
  };

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  // [LOGIKA UTAMA] Mengirim data ke Backend (Fix Error 400)
  Future<void> _handlePayment(
      String paymentMethod, String packageId, int quantity) async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final functions =
          FirebaseFunctions.instanceFor(region: "asia-southeast2");
      final callable = functions.httpsCallable('createDuitkuTransaction');

      // [FIX] Kirim packageId & quantity. Backend akan hitung totalnya.
      final result = await callable.call<Map<String, dynamic>>({
        'packageId': packageId, 
        'paymentMethod': paymentMethod,
        'quantity': quantity, 
      });

      final paymentUrl = result.data['paymentUrl'] as String?;
      if (paymentUrl == null) {
        throw Exception("Payment URL tidak diterima dari server.");
      }

      if (mounted) Navigator.of(context).pop(); 

      final uri = Uri.parse(paymentUrl);

      if (!await launchUrl(
        uri,
        webOnlyWindowName: '_blank',
      )) {
        throw Exception('Tidak dapat membuka URL: $paymentUrl');
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error Server: ${e.message ?? e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        if (Navigator.of(context).canPop()) Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showPaymentMethods(String packageTitle, String packageId) async {
    await showModalBottomSheet(
      context: context,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      isScrollControlled: true,
      builder: (BuildContext bContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
                child: Text(
                  'Pilih Pembayaran ($packageTitle)',
                  style: Theme.of(bContext).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 12.0),
                child: Text(
                  'Silakan pilih metode pembayaran yang Anda inginkan.',
                  style: Theme.of(bContext).textTheme.bodyMedium,
                ),
              ),
              const Divider(height: 1, thickness: 1),
              Expanded(
                child: ListView.builder(
                  itemCount: paymentOptions.length,
                  itemBuilder: (context, index) {
                    final key = paymentOptions.keys.elementAt(index);
                    final value = paymentOptions[key]!;
                    return ListTile(
                      leading: const Icon(Icons.payment_outlined),
                      title: Text(value),
                      onTap: () {
                        Navigator.of(bContext).pop();
                        // Eksekusi dengan parameter lengkap
                        _handlePayment(key, packageId, _quantity);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  // --- Helper Stepper ---
  void _incrementQuantity() {
    setState(() {
      _quantity++;
      _quantityController.text = _quantity.toString();
    });
  }

  void _decrementQuantity() {
    if (_quantity > 1) {
      setState(() {
        _quantity--;
        _quantityController.text = _quantity.toString();
      });
    }
  }

  void _onQuantityChanged(String value) {
    int newQty = int.tryParse(value) ?? 1;
    if (newQty < 1) newQty = 1;
    setState(() {
      _quantity = newQty;
    });
  }

  @override
  Widget build(BuildContext context) {
    final userAsyncValue = ref.watch(firestoreUserProvider);
    final appConfigAsyncValue = ref.watch(appConfigProvider);

    final currencyFormat = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    final numberFormat = NumberFormat.decimalPattern('id_ID');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tambah Token Majiku'),
      ),
      body: userAsyncValue.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(
            child: Text('Gagal memuat data pengguna: ${e.toString()}')),
        data: (user) {
          return appConfigAsyncValue.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) =>
                Center(child: Text('Gagal memuat data harga: ${e.toString()}')),
            data: (config) {
              
              // 1. Tentukan ID Paket berdasarkan Tier User
              // Logika: Firestore punya key 'topup_basic', 'topup_standard', 'topup_pro'
              String pricePackageId; 
              String currentTierName;

              if (user.userTier == 'basic') {
                pricePackageId = 'topup_basic';
                currentTierName = "Basic";
              } else if (user.userTier == 'standard') {
                pricePackageId = 'topup_standard';
                currentTierName = "Standard";
              } else if (user.userTier == 'professional') {
                pricePackageId = 'topup_pro';
                currentTierName = "Professional";
              } else {
                pricePackageId = 'topup_basic'; // Fallback
                currentTierName = "Basic (Default)";
              }

              // 2. Ambil Harga dari Config (Single Source of Truth)
              // Menggunakan helper getPackage dari model baru
              final packageConfig = config.getPackage(pricePackageId);
              
              final unitPrice = packageConfig?.amount ?? 95000;
              final unitTokens = packageConfig?.tokens ?? 10000;

              // 3. Hitung Total (Hanya untuk Tampilan)
              final int totalTokens = unitTokens * _quantity;
              final int totalPrice = unitPrice * _quantity;

              return SingleChildScrollView(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.token_outlined,
                            size: 80, color: Colors.deepPurple),
                        const SizedBox(height: 24),
                        
                        // Judul Tier
                        Text(
                          'Top-Up Khusus $currentTierName',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold
                          ),
                        ),
                         Text(
                          'Harga Satuan: ${currencyFormat.format(unitPrice)} / ${numberFormat.format(unitTokens)} TM',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.grey[600]
                          ),
                        ),
                        const SizedBox(height: 32),

                        // INPUT QUANTITY (STEPPER)
                        Text(
                          'JUMLAH TOKEN (Kelipatan ${numberFormat.format(unitTokens)} TM)',
                          style: Theme.of(context).textTheme.labelLarge
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              iconSize: 40,
                              color: _quantity > 1 ? Colors.deepPurple : Colors.grey,
                              onPressed: _decrementQuantity,
                            ),
                            SizedBox(
                              width: 120,
                              child: TextFormField(
                                controller: _quantityController,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.bold
                                ),
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly
                                ],
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.all(12),
                                ),
                                onChanged: _onQuantityChanged,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              iconSize: 40,
                              color: Colors.deepPurple,
                              onPressed: _incrementQuantity,
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),

                        // TOTAL HARGA & TOMBOL BAYAR
                        Text(
                          'TOTAL TAGIHAN:',
                          style: Theme.of(context).textTheme.labelLarge
                        ),
                        Text(
                          currencyFormat.format(totalPrice),
                          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple,
                          ),
                        ),
                        Text(
                          'Total: ${numberFormat.format(totalTokens)} TM',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.payment_outlined),
                            label: Text(
                              'Bayar ${currencyFormat.format(totalPrice)}',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: Colors.deepPurple,
                              foregroundColor: Colors.white,
                            ),
                            // Tombol hanya aktif jika tidak loading
                            onPressed: _isLoading
                                ? null
                                : () => _showPaymentMethods(
                                      'Top-Up ${numberFormat.format(totalTokens)} TM',
                                      pricePackageId, // Mengirim ID Paket (topup_basic, dll)
                                    ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}