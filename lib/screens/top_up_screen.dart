//.......................................................//
// LIB/SCREENS/TOP_UP_SCREEN.DART                        //
//.......................................................//

// No ke-1: IMPORT & DEPENDENSI                          //
//.......................................................//
import 'dart:io'; 
import 'package:flutter/foundation.dart' show kIsWeb; 
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

// Impor provider & model
import '../providers/user_provider.dart';
import '../providers/config_provider.dart'; 
import '../models/app_config.dart'; 

// Impor Service Pembayaran Hybrid & Firestore
import '../services/payment_hybrid_service.dart';
import '../services/firestore_service.dart';
//.......................................................//

// No ke-2: STATEFUL WIDGET & INISIALISASI               //
//.......................................................//
class TopUpScreen extends ConsumerStatefulWidget {
  const TopUpScreen({super.key});

  @override
  ConsumerState<TopUpScreen> createState() => _TopUpScreenState();
}

class _TopUpScreenState extends ConsumerState<TopUpScreen> {
  bool _isLoading = false;
  
  // State untuk memastikan harga Google sudah diambil
  bool _pricesLoaded = false;

  // --- [LOGIKA PEMBATASAN PAKET] ---
  // Hanya izinkan kelipatan ini agar sesuai dengan produk di Google Console
  final List<int> _allowedQuantities = [1, 3, 5, 10, 30];
  
  // State Quantity (Default index 0 = nilai 1)
  int _quantity = 1; 
  final TextEditingController _quantityController = TextEditingController(text: '1');

  // Opsi Pembayaran Web (Duitku)
  final Map<String, String> paymentOptionsWeb = {
    'M2': 'Mandiri Virtual Account (HP)',
    'I1': 'BNI Virtual Account',
    'BR': 'BRIVA (BRI)',
    'BV': 'BSI Virtual Account',
  };

  // Helper Cek Platform
  bool get _isAndroidNative => !kIsWeb && Platform.isAndroid;

  @override
  void initState() {
    super.initState();
    // Fetch semua kemungkinan harga Google saat layar dimuat
    if (_isAndroidNative) {
      _fetchAllGooglePrices();
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  /// Mengambil harga untuk basic, standard, pro beserta varian quantity-nya
  /// agar saat user klik "+", harga langsung tersedia tanpa loading lagi.
  Future<void> _fetchAllGooglePrices() async {
    final service = PaymentHybridService();
    
    final Set<String> allIds = {};
    final tiers = ['topup_basic', 'topup_standard', 'topup_pro'];
    
    for (var tierId in tiers) {
      allIds.addAll(service.generateVariantIds(tierId, _allowedQuantities));
    }

    await service.fetchProductDetails(allIds);

    if (mounted) {
      setState(() {
        _pricesLoaded = true;
      });
    }
  }
//.......................................................//

// No ke-3: HELPER FORMAT HARGA & TEKS                   //
//.......................................................//
  /// Mengembalikan String harga TOTAL untuk ditampilkan di UI.
  /// Android: Mengambil dari Cache Google (Real-time).
  /// Web: Menghitung dari Database dengan kurs dinamis Firestore.
  String _getDisplayTotalPrice({
    required String basePackageId,
    required int quantity,
    required int unitPriceDb,
    required bool isIndo,
    required double usdRate,
  }) {
    if (_isAndroidNative) {
      String targetSku = basePackageId;
      if (quantity > 1) {
        targetSku = "${basePackageId}_x$quantity";
      }
      
      final googlePrice = PaymentHybridService().getPriceFromCache(targetSku);
      
      if (googlePrice != null) {
        return googlePrice; 
      }
      return isIndo ? "Memuat..." : "Loading...";
    }

    final int totalDbPrice = unitPriceDb * quantity;
    
    if (isIndo) {
      return NumberFormat.currency(
        locale: 'id_ID',
        symbol: 'Rp ',
        decimalDigits: 0,
      ).format(totalDbPrice);
    } else {
      final safeUsdRate = usdRate > 0 ? usdRate : 15500.0;
      double amountInUsd = totalDbPrice / safeUsdRate;
      return NumberFormat.currency(
        locale: 'en_US',
        symbol: '\$',
        decimalDigits: 2,
      ).format(amountInUsd);
    }
  }

  // Helper Format Unit Price (Hanya untuk display info text, bukan tagihan)
  String _formatMoneySimple(int amount, bool isIndo, double usdRate) {
    if (isIndo) {
      return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(amount);
    } else {
      final safeUsdRate = usdRate > 0 ? usdRate : 15500.0;
      return NumberFormat.currency(locale: 'en_US', symbol: '\$', decimalDigits: 2).format(amount / safeUsdRate);
    }
  }
//.......................................................//

// No ke-4: LOGIKA TRANSAKSI & PEMANTAU REALTIME        //
//.......................................................//
  // --- [LOGIKA BACKEND: WEB (DUITKU)] ---
  Future<void> _handlePaymentWeb(String paymentMethod, String packageId, int quantity) async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final functions = FirebaseFunctions.instanceFor(region: "asia-southeast2");
      final callable = functions.httpsCallable('createDuitkuTransaction');

      final result = await callable.call<Map<String, dynamic>>({
        'packageId': packageId, 
        'paymentMethod': paymentMethod,
        'quantity': quantity, 
      });

      final paymentUrl = result.data['paymentUrl'] as String?;
      final merchantOrderId = result.data['merchantOrderId'] as String?;

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

      // [PELACAKAN TRANSAKSI SENTRAL REAL-TIME]
      if (merchantOrderId != null && mounted) {
        _showWaitingPaymentDialog(merchantOrderId);
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

  /// Dialog Realtime Pelacakan Koleksi Sentral 'transactions' di Firestore
  void _showWaitingPaymentDialog(String orderId) {
    final currentLocale = ref.read(appLanguageProvider);
    final isIndo = currentLocale.languageCode == 'id';
    String t(String en, String id) => isIndo ? id : en;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) {
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirestoreService().streamTransactionStatus(orderId),
          builder: (context, snapshot) {
            final data = snapshot.data?.data();
            final status = data?['status'] as String? ?? 'PENDING';

            // 1. Status SUKSES
            if (status == 'SUCCESS') {
              return AlertDialog(
                backgroundColor: const Color(0xFF1E1E1E),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 12),
                    const Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 64),
                    const SizedBox(height: 16),
                    Text(
                      t('Payment Successful!', 'Pembayaran Berhasil!'),
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      t('Your tokens have been credited to your account.', 'Token tambahan telah berhasil masuk ke saldo Anda.'),
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.greenAccent,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.of(dialogCtx).pop(),
                      child: Text(t('Done', 'Selesai'), style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );
            }

            // 2. Status GAGAL
            if (status == 'FAILED') {
              return AlertDialog(
                backgroundColor: const Color(0xFF1E1E1E),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 12),
                    const Icon(Icons.error_outline, color: Colors.redAccent, size: 64),
                    const SizedBox(height: 16),
                    Text(
                      t('Payment Failed or Cancelled', 'Pembayaran Gagal / Dibatalkan'),
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.of(dialogCtx).pop(),
                      child: Text(t('Close', 'Tutup')),
                    ),
                  ],
                ),
              );
            }

            // 3. Status PENDING (Menunggu Pelunasan)
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  const CircularProgressIndicator(color: Colors.deepPurpleAccent),
                  const SizedBox(height: 20),
                  Text(
                    t('Waiting for Payment...', 'Menunggu Pembayaran...'),
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t('Please complete the payment in the opened browser window.', 'Silakan selesaikan pembayaran di jendela browser yang terbuka.'),
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Order ID: $orderId',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: () => Navigator.of(dialogCtx).pop(),
                    child: Text(t('Close Window', 'Tutup Jendela Ini'), style: TextStyle(color: Colors.grey.shade400)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --- [LOGIKA BACKEND: ANDROID (GOOGLE PLAY)] ---
  Future<void> _handlePaymentAndroid(String basePackageId, int quantity) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      String targetSku = basePackageId;
      if (quantity > 1) {
        targetSku = "${basePackageId}_x$quantity";
      }

      await PaymentHybridService().payWithGooglePlay(productId: targetSku);
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Gagal inisialisasi Google Play: ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- [UI BOTTOM SHEET WEB] ---
  Future<void> _showPaymentMethodsWeb(String packageTitle, String packageId, bool isIndo) async {
    String t(String en, String id) => isIndo ? id : en;

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
                  '${t("Select Payment", "Pilih Pembayaran")} ($packageTitle)',
                  style: Theme.of(bContext).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 12.0),
                child: Text(
                  t("Please select your preferred payment method.", "Silakan pilih metode pembayaran yang Anda inginkan."),
                  style: Theme.of(bContext).textTheme.bodyMedium,
                ),
              ),
              const Divider(height: 1, thickness: 1),
              Expanded(
                child: ListView.builder(
                  itemCount: paymentOptionsWeb.length,
                  itemBuilder: (context, index) {
                    final key = paymentOptionsWeb.keys.elementAt(index);
                    final value = paymentOptionsWeb[key]!;
                    return ListTile(
                      leading: const Icon(Icons.payment_outlined),
                      title: Text(value),
                      onTap: () {
                        Navigator.of(bContext).pop();
                        _handlePaymentWeb(key, packageId, _quantity);
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
//.......................................................//

// No ke-5: LOGIKA STEPPER QUANTITY                      //
//.......................................................//
  void _incrementQuantity() {
    int currentIndex = _allowedQuantities.indexOf(_quantity);
    if (currentIndex < _allowedQuantities.length - 1) {
      setState(() {
        _quantity = _allowedQuantities[currentIndex + 1];
        _quantityController.text = _quantity.toString();
      });
    }
  }

  void _decrementQuantity() {
    int currentIndex = _allowedQuantities.indexOf(_quantity);
    if (currentIndex > 0) {
      setState(() {
        _quantity = _allowedQuantities[currentIndex - 1];
        _quantityController.text = _quantity.toString();
      });
    }
  }
//.......................................................//

// No ke-6: BUILDER UTAMA ANTARMUKA PENGGUNA             //
//.......................................................//
  @override
  Widget build(BuildContext context) {
    // 1. Providers
    final userAsyncValue = ref.watch(firestoreUserProvider);
    final appConfigAsyncValue = ref.watch(appConfigProvider);
    
    // 2. Language State
    final currentLocale = ref.watch(appLanguageProvider);
    final isIndo = currentLocale.languageCode == 'id';
    String t(String en, String id) => isIndo ? id : en;

    // 3. Format Angka
    final numberFormat = NumberFormat.decimalPattern(isIndo ? 'id_ID' : 'en_US');

    // Cek batas untuk warna tombol
    final bool canDecrement = _quantity > _allowedQuantities.first;
    final bool canIncrement = _quantity < _allowedQuantities.last;

    return Scaffold(
      appBar: AppBar(
        title: Text(t("Top Up Tokens", "Tambah Token Majiku")),
      ),
      body: userAsyncValue.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(
            child: Text('${t("Failed to load user data", "Gagal memuat data pengguna")}: ${e.toString()}')),
        data: (user) {
          return appConfigAsyncValue.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) =>
                Center(child: Text('${t("Failed to load pricing", "Gagal memuat data harga")}: ${e.toString()}')),
            data: (config) {
              
              // 1. Tentukan ID Paket berdasarkan Tier User
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
                pricePackageId = 'topup_basic';
                currentTierName = "Basic";
              }

              // 2. Ambil Kurs Dinamis dari AppConfig Firestore
              final double liveUsdRate = config.usdRate > 0 ? config.usdRate : 15500.0;

              // 3. Ambil Harga Dasar dari Config (Hanya untuk referensi Web)
              final packageConfig = config.getPackage(pricePackageId);
              
              final int baseUnitPriceDb = packageConfig?.amount ?? 95000;
              final unitTokens = packageConfig?.tokens ?? 10000;

              // 4. Hitung Token Total
              final int totalTokens = unitTokens * _quantity;

              // 5. Hitung Harga Total Display (Hybrid Logic dengan Kurs Firestore)
              final String displayTotalPrice = _getDisplayTotalPrice(
                basePackageId: pricePackageId,
                quantity: _quantity,
                unitPriceDb: baseUnitPriceDb,
                isIndo: isIndo,
                usdRate: liveUsdRate,
              );

              return SingleChildScrollView(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        
                        // Banner Info Google Tax (Hanya muncul di Android)
                        if (_isAndroidNative)
                          Container(
                            margin: const EdgeInsets.only(bottom: 24),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline, color: Colors.orange),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    t("Price includes Google Play service fees.", "Harga sudah termasuk biaya layanan Google Play."),
                                    style: const TextStyle(fontSize: 12, color: Colors.deepOrange),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Info Banner USD (Web Only)
                        if (!isIndo && !_isAndroidNative)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 24.0),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blue.withOpacity(0.3)),
                              ),
                              child: const Text(
                                "Prices shown in USD are estimates. Transactions are processed in IDR.",
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12, color: Colors.blueGrey),
                              ),
                            ),
                          ),

                        const Icon(Icons.token_outlined,
                            size: 80, color: Colors.deepPurple),
                        const SizedBox(height: 24),
                        
                        // Judul Tier
                        Text(
                          '${t("Special Top-Up for", "Top-Up Khusus")} $currentTierName',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold
                          ),
                        ),
                        Text(
                          '${t("Unit Price", "Harga Satuan")}: ${_formatMoneySimple(baseUnitPriceDb, isIndo, liveUsdRate)} / ${numberFormat.format(unitTokens)} TM',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.grey[600]
                          ),
                        ),
                        const SizedBox(height: 32),

                        // INPUT QUANTITY (STEPPER TERBATAS)
                        Text(
                          t("PACKAGE QUANTITY", "JUMLAH PAKET"),
                          style: Theme.of(context).textTheme.labelLarge,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              iconSize: 40,
                              color: canDecrement ? Colors.deepPurple : Colors.grey.shade300,
                              onPressed: canDecrement ? _decrementQuantity : null,
                            ),
                            SizedBox(
                              width: 120,
                              child: TextFormField(
                                controller: _quantityController,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.bold
                                ),
                                readOnly: true, 
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.all(12),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              iconSize: 40,
                              color: canIncrement ? Colors.deepPurple : Colors.grey.shade300,
                              onPressed: canIncrement ? _incrementQuantity : null,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "x$_quantity ${t("Packages", "Paket")}",
                          style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold),
                        ),
                        
                        const SizedBox(height: 32),

                        // TOTAL HARGA (DISPLAY FINAL) & TOMBOL BAYAR
                        Text(
                          t("TOTAL BILL:", "TOTAL TAGIHAN:"),
                          style: Theme.of(context).textTheme.labelLarge
                        ),
                        
                        Text(
                          displayTotalPrice, 
                          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple,
                            fontSize: displayTotalPrice.length > 15 ? 24 : (isIndo ? 36 : 40),
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
                            icon: Icon(_isAndroidNative ? Icons.shop : Icons.payment_outlined),
                            label: Text(
                              _isAndroidNative 
                                ? '${t("Pay with Google Play", "Bayar via Google Play")}' 
                                : '${t("Pay", "Bayar")} $displayTotalPrice',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: _isAndroidNative ? Colors.green[700] : Colors.deepPurple,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: _isLoading 
                                ? null 
                                : () {
                                    if (_isAndroidNative) {
                                      if (displayTotalPrice.contains("Load") || displayTotalPrice.contains("Muat")) {
                                         return;
                                      }
                                      _handlePaymentAndroid(pricePackageId, _quantity);
                                    } else {
                                      _showPaymentMethodsWeb(
                                        'Top-Up ${numberFormat.format(totalTokens)} TM',
                                        pricePackageId,
                                        isIndo
                                      );
                                    }
                                  },
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
//.......................................................//