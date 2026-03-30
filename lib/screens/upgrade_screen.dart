// [RILIS BERSIH - UPGRADE SCREEN HYBRID FINAL v3]
// KATEGORI_UX_IMPROVEMENT NO_URUT_12
// Perbaikan: 
// 1. Menampilkan harga REAL-TIME dari Google Play (Android) untuk kepatuhan kebijakan.
// 2. Tetap menggunakan Duitku untuk Web.
// 3. Menggunakan data Token/Tier dari AppConfig Provider.

import 'dart:io'; 
import 'package:flutter/foundation.dart' show kIsWeb; 
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

// [PENTING] Import Model & Provider Pusat
import '../models/app_config.dart';
import '../providers/config_provider.dart';
import '../providers/user_provider.dart'; 

// [PENTING] Import Service Pembayaran Hybrid (Versi 3 - Support Fetch)
import '../services/payment_hybrid_service.dart';

// ==========================================================
// WIDGET SCREEN
// ==========================================================

class UpgradeScreen extends ConsumerStatefulWidget {
  const UpgradeScreen({super.key});

  @override
  ConsumerState<UpgradeScreen> createState() => _UpgradeScreenState();
}

class _UpgradeScreenState extends ConsumerState<UpgradeScreen> {
  bool _isLoading = false;
  
  // Cache lokal untuk memicu rebuild saat harga Google selesai diload
  bool _priceLoaded = false;
  
  final Map<String, String> paymentOptionsWeb = {
    'BC': 'BCA Virtual Account',
    'M2': 'Mandiri Virtual Account (HP)',
    'I1': 'BNI Virtual Account',
    'BR': 'BRIVA (BRI)',
    'BV': 'BSI Virtual Account',
    'SP': 'ShopeePay (QRIS)',
    'VC': 'Kartu Kredit (Visa/Master/JCB)',
  };

  // Helper Cek Platform
  bool get _isAndroidNative => !kIsWeb && Platform.isAndroid;

  @override
  void initState() {
    super.initState();
    // [ANTI-REGRESI] Fetch harga Google saat layar dimuat (Khusus Android)
    if (_isAndroidNative) {
      _fetchGooglePrices();
    }
  }

  /// Mengambil harga asli dari Google Play agar sesuai kebijakan "No Misleading Price"
  Future<void> _fetchGooglePrices() async {
    // Daftar ID Paket yang ada di Google Console
    // Pastikan ID ini SAMA PERSIS dengan yang ada di Config/Database
    final Set<String> productIds = {
      'basic_monthly',
      'standard_monthly',
      'pro_monthly',
    };

    await PaymentHybridService().fetchProductDetails(productIds);

    // Refresh UI setelah data terambil
    if (mounted) {
      setState(() {
        _priceLoaded = true;
      });
    }
  }

  // --- [LOGIKA PEMBAYARAN: WEB (DUITKU)] ---
  Future<void> _handlePaymentWeb(String packageId, String paymentMethod) async {
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
      });

      final paymentUrl = result.data['paymentUrl'] as String?;
      if (paymentUrl == null) {
        throw Exception("Payment URL tidak diterima dari server.");
      }
      
      if (mounted) Navigator.of(context).pop(); 
      
      final uri = Uri.parse(paymentUrl);

      // Membuka di Tab Baru
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

  // --- [LOGIKA PEMBAYARAN: ANDROID (GOOGLE PLAY SUBSCRIPTION)] ---
  Future<void> _handlePaymentAndroid(String packageId) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      // Panggil Service Hybrid V3
      await PaymentHybridService().payWithGooglePlay(productId: packageId);
      
      // Feedback UI
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Menghubungkan ke Google Play Store...'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat Google Billing: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- [UI BOTTOM SHEET WEB] ---
  Future<void> _showPaymentMethodsWeb(String packageId, String packageTitle, bool isIndo) async {
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
                        _handlePaymentWeb(packageId, key); 
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

  // --- [HELPER FORMAT HARGA & TEKS] ---
  
  /// Helper Display Harga:
  /// - Jika Android: Prioritaskan Cache Google Play.
  /// - Jika Web: Gunakan Config Database + Formatter.
  String _getDisplayPrice({
    required String packageId, 
    required int dbAmount, 
    required bool isIndo
  }) {
    if (_isAndroidNative) {
      // Coba ambil string harga resmi dari Google (cth: "Rp 129.000,00")
      final googlePrice = PaymentHybridService().getPriceFromCache(packageId);
      if (googlePrice != null) {
        return googlePrice;
      }
      // Jika belum load, return placeholder (jangan return harga tebakan)
      return isIndo ? "Memuat..." : "Loading...";
    }

    // Fallback Web / Logic Lama
    if (isIndo) {
      return NumberFormat.currency(
        locale: 'id_ID',
        symbol: 'Rp ',
        decimalDigits: 0,
      ).format(dbAmount);
    } else {
      double amountInUsd = dbAmount / 15500;
      return NumberFormat.currency(
        locale: 'en_US',
        symbol: '\$',
        decimalDigits: 2, 
      ).format(amountInUsd);
    }
  }

  Widget _buildFeatureRow(BuildContext context, {required IconData icon, required String text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard(
    BuildContext context, {
    required String packageId, 
    required String title,
    required int dbAmount, // Harga database (untuk Web)
    required String period,
    required String initialTokens,
    required String topUpPrice,
    required IconData icon,
    required Color iconColor,
    required bool isIndo, 
    bool isRecommended = false,
  }) {
    String t(String en, String id) => isIndo ? id : en;
    
    // Ambil harga yang BENAR (Google vs Web)
    final displayPrice = _getDisplayPrice(
      packageId: packageId, 
      dbAmount: dbAmount, 
      isIndo: isIndo
    );

    return Card(
      elevation: isRecommended ? 8.0 : 2.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: isRecommended
            ? BorderSide(color: iconColor, width: 2.0)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 32, color: iconColor),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: iconColor,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                // Tampilan Harga
                Text(
                  displayPrice,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        // Jika teks "Memuat..." kecilkan font sedikit
                        fontSize: displayPrice.length > 15 ? 24 : (isIndo ? 32 : 36), 
                      ),
                ),
                const SizedBox(width: 4),
                Text(
                  period,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                ),
              ],
            ),
            const Divider(height: 24, thickness: 1),
            _buildFeatureRow(
              context,
              icon: Icons.token_outlined,
              text: '${t("Initial Tokens", "Token Awal")}: $initialTokens',
            ),
            _buildFeatureRow(
              context,
              icon: Icons.add_shopping_cart_outlined,
              text: '${t("Top-Up Price", "Harga Top-Up")}: $topUpPrice / 10.000 TM',
            ),
            const SizedBox(height: 24),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: Icon(_isAndroidNative ? Icons.subscriptions : Icons.check_circle_outline, size: 18),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: _isAndroidNative ? Colors.green[700] : iconColor, 
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                onPressed: _isLoading 
                    ? null 
                    : () {
                        if (_isAndroidNative) {
                          _handlePaymentAndroid(packageId);
                        } else {
                          _showPaymentMethodsWeb(packageId, title, isIndo); 
                        }
                      },
                label: _isLoading
                    ? const SizedBox( 
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                      )
                    : Text( 
                        _isAndroidNative 
                           ? t("Subscribe with Google Play", "Langganan via Google Play")
                           : '${t("Select", "Pilih Paket")} $title',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1. [PENTING] Gunakan Provider Pusat (Global)
    final appConfigAsync = ref.watch(appConfigProvider);
    
    // 2. Watch Language State
    final currentLocale = ref.watch(appLanguageProvider);
    final isIndo = currentLocale.languageCode == 'id';

    String t(String en, String id) => isIndo ? id : en;

    return Scaffold(
      appBar: AppBar(
        title: Text(t("Membership Upgrade", "Upgrade Membership")),
      ),
      body: appConfigAsync.when(
        data: (config) {
          final numberFormat = NumberFormat.decimalPattern(isIndo ? 'id_ID' : 'en_US');

          // Ambil data paket dari config (untuk Token & Tier)
          final basic = config.getPackage('basic_monthly');
          final standard = config.getPackage('standard_monthly');
          final pro = config.getPackage('pro_monthly');
          
          final topupBasic = config.getPackage('topup_basic');
          final topupStandard = config.getPackage('topup_standard');
          final topupPro = config.getPackage('topup_pro');

          // [FIX] Ambil harga DB untuk Web saja (Android pakai Fetch)
          int basicAmount = basic?.amount ?? 95000;
          int stdAmount = standard?.amount ?? 279000;
          int proAmount = pro?.amount ?? 2700000;

          // Harga TopUp Display (Hanya info teks, bisa pakai estimasi/logic lama untuk display web)
          // Untuk display "Top-Up Price" di dalam kartu, kita gunakan format web dulu sebagai indikasi.
          int basicTopup = topupBasic?.amount ?? 95000;
          int stdTopup = topupStandard?.amount ?? 93000;
          int proTopup = topupPro?.amount ?? 90000;

          // Helper format uang lokal untuk info teks
          String fmt(int val) {
             if(isIndo) return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(val);
             return NumberFormat.currency(locale: 'en_US', symbol: '\$', decimalDigits: 2).format(val/15500);
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                
                // Banner Google Tax (Android Only)
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
                            t("Price includes Google Play subscription fees.", "Harga sudah termasuk biaya langganan Google Play."),
                            style: const TextStyle(fontSize: 12, color: Colors.deepOrange),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Info Banner USD (Web Only)
                if (!isIndo && !_isAndroidNative)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.info_outline, size: 20, color: Colors.blue),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "Prices are shown in USD for reference. Transaction will be processed in IDR.",
                              style: TextStyle(fontSize: 12, color: Colors.blueGrey),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // PLAN CARDS
                _buildPlanCard(
                  context,
                  packageId: 'basic_monthly',
                  title: 'Basic',
                  dbAmount: basicAmount, // Web Only
                  period: t('/ month', '/ bulan'),
                  initialTokens: '${numberFormat.format(basic?.tokens ?? 10000)} TM',
                  topUpPrice: fmt(basicTopup), 
                  icon: Icons.looks_3_outlined,
                  iconColor: Colors.blue.shade700,
                  isIndo: isIndo,
                ),
                const SizedBox(height: 20),

                _buildPlanCard(
                  context,
                  packageId: 'standard_monthly',
                  title: 'Standard',
                  dbAmount: stdAmount, // Web Only
                  period: t('/ month', '/ bulan'),
                  initialTokens: '${numberFormat.format(standard?.tokens ?? 30000)} TM',
                  topUpPrice: fmt(stdTopup),
                  icon: Icons.looks_two_outlined,
                  iconColor: Colors.purple.shade700,
                  isRecommended: true,
                  isIndo: isIndo,
                ),
                const SizedBox(height: 20),

                _buildPlanCard(
                  context,
                  packageId: 'pro_monthly',
                  title: 'Professional',
                  dbAmount: proAmount, // Web Only
                  period: t('/ month', '/ bulan'),
                  initialTokens: '${numberFormat.format(pro?.tokens ?? 300000)} TM',
                  topUpPrice: fmt(proTopup),
                  icon: Icons.workspace_premium_outlined,
                  iconColor: Colors.amber.shade800,
                  isIndo: isIndo,
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              t(
                'Failed to load pricing data.\nError: ${err.toString()}',
                'Gagal memuat data harga.\nError: ${err.toString()}',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red.shade700),
            ),
          ),
        ),
      ),
    );
  }
}