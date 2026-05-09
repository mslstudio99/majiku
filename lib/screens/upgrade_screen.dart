//.......................................................//
// LIB/SCREENS/UPGRADE_SCREEN.DART                       //
//.......................................................//
// KATEGORI_UX_IMPROVEMENT NO_URUT_13
// Perbaikan Teks Tombol menjadi Hitam Mutlak

// No ke-1: IMPORT & SETUP                               //
//.......................................................//
import 'dart:io'; 
import 'package:flutter/foundation.dart' show kIsWeb; 
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

import '../models/app_config.dart';
import '../providers/config_provider.dart';
import '../providers/user_provider.dart'; 
import '../services/payment_hybrid_service.dart';
//.......................................................//

// No ke-2: STATEFUL WIDGET & INITIALIZATION             //
//.......................................................//
class UpgradeScreen extends ConsumerStatefulWidget {
  const UpgradeScreen({super.key});

  @override
  ConsumerState<UpgradeScreen> createState() => _UpgradeScreenState();
}

class _UpgradeScreenState extends ConsumerState<UpgradeScreen> {
  bool _isLoading = false;
  bool _priceLoaded = false;
  
  final Map<String, String> paymentOptionsWeb = {
    'M2': 'Mandiri Virtual Account (HP)',
    'I1': 'BNI Virtual Account',
    'BR': 'BRIVA (BRI)',
    'BV': 'BSI Virtual Account',
  };

  bool get _isAndroidNative => !kIsWeb && Platform.isAndroid;

  @override
  void initState() {
    super.initState();
    if (_isAndroidNative) {
      _fetchGooglePrices();
    }
  }

  Future<void> _fetchGooglePrices() async {
    final Set<String> productIds = {
      'basic_monthly',
      'standard_monthly',
      'pro_monthly',
    };

    await PaymentHybridService().fetchProductDetails(productIds);

    if (mounted) {
      setState(() {
        _priceLoaded = true;
      });
    }
  }
//.......................................................//

// No ke-3: LOGIKA PEMBAYARAN & BOTTOM SHEET             //
//.......................................................//
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
          SnackBar(content: Text('Error Server: ${e.message ?? e.toString()}'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        if (Navigator.of(context).canPop()) Navigator.of(context).pop(); 
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handlePaymentAndroid(String packageId) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      await PaymentHybridService().payWithGooglePlay(productId: packageId);
      
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
          SnackBar(content: Text('Gagal memuat Google Billing: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showPaymentMethodsWeb(String packageId, String packageTitle, bool isIndo) async {
    String t(String en, String id) => isIndo ? id : en;

    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
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
                padding: const EdgeInsets.fromLTRB(20.0, 24.0, 20.0, 8.0),
                child: Text(
                  '${t("Select Payment", "Pilih Pembayaran")} ($packageTitle)', 
                  style: Theme.of(bContext).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20.0, 0, 20.0, 16.0),
                child: Text(
                  t("Please select your preferred payment method.", "Silakan pilih metode pembayaran yang Anda inginkan."),
                  style: TextStyle(color: Colors.grey.shade400),
                ),
              ),
              Divider(height: 1, thickness: 1, color: Colors.grey.shade800),

              Expanded(
                child: ListView.builder(
                  itemCount: paymentOptionsWeb.length,
                  itemBuilder: (context, index) {
                    final key = paymentOptionsWeb.keys.elementAt(index);
                    final value = paymentOptionsWeb[key]!;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.payment_outlined, color: Colors.blueAccent),
                      ),
                      title: Text(value, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w500)),
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
//.......................................................//

// No ke-4: HELPER & KARTU UI MODERN                     //
//.......................................................//
  String _getDisplayPrice({
    required String packageId, 
    required int dbAmount, 
    required bool isIndo
  }) {
    if (_isAndroidNative) {
      final googlePrice = PaymentHybridService().getPriceFromCache(packageId);
      if (googlePrice != null) return googlePrice;
      return isIndo ? "Memuat..." : "Loading...";
    }

    if (isIndo) {
      return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(dbAmount);
    } else {
      double amountInUsd = dbAmount / 15500;
      return NumberFormat.currency(locale: 'en_US', symbol: '\$', decimalDigits: 2).format(amountInUsd);
    }
  }

  Widget _buildFeatureRow(BuildContext context, {required IconData icon, required String text, required Color accentColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: accentColor),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernPlanCard(
    BuildContext context, {
    required String packageId, 
    required String title,
    required String subtitle,
    required int dbAmount, 
    required String initialTokens,
    required String topUpPrice,
    required IconData icon,
    required Color primaryColor,
    required Color secondaryColor,
    required Gradient backgroundGradient,
    required bool isIndo, 
    String? badgeText,
  }) {
    String t(String en, String id) => isIndo ? id : en;
    
    final displayPrice = _getDisplayPrice(
      packageId: packageId, 
      dbAmount: dbAmount, 
      isIndo: isIndo
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24.0),
        gradient: backgroundGradient,
        border: Border.all(
          color: primaryColor.withOpacity(badgeText != null ? 0.6 : 0.2), 
          width: badgeText != null ? 2.0 : 1.0
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(badgeText != null ? 0.2 : 0.05),
            blurRadius: badgeText != null ? 20 : 10,
            spreadRadius: badgeText != null ? 2 : 0,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(icon, size: 32, color: primaryColor),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: primaryColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade400,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                
                Text(
                  displayPrice,
                  style: TextStyle(
                    fontSize: displayPrice.length > 15 ? 28 : (isIndo ? 34 : 38), 
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                
                const SizedBox(height: 24),
                Divider(height: 1, thickness: 1, color: Colors.white.withOpacity(0.1)),
                const SizedBox(height: 24),
                
                _buildFeatureRow(
                  context,
                  icon: Icons.auto_awesome,
                  text: '${t("Initial Tokens", "Token Awal")}: $initialTokens',
                  accentColor: primaryColor,
                ),
                _buildFeatureRow(
                  context,
                  icon: Icons.shopping_bag_outlined,
                  text: '${t("Top-Up Price", "Harga Top-Up")}: $topUpPrice / 10.000 TM',
                  accentColor: primaryColor,
                ),
                const SizedBox(height: 32),
                
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor, 
                      foregroundColor: Colors.black, // <-- WARNA DASAR TEKS DIUBAH KE HITAM
                      elevation: badgeText != null ? 8 : 2,
                      shadowColor: primaryColor.withOpacity(0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.0),
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
                    child: _isLoading
                        ? const SizedBox( 
                            height: 24, width: 24,
                            // Warna indikator loading diubah ke Hitam
                            child: CircularProgressIndicator(color: Colors.black, strokeWidth: 3),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _isAndroidNative ? Icons.shop : Icons.verified_rounded, 
                                size: 20, 
                                color: Colors.black // <-- IKON DIBUAT HITAM MUTLAK
                              ),
                              const SizedBox(width: 10),
                              Text( 
                                _isAndroidNative 
                                   ? t("Upgrade via Play Store", "Upgrade via Play Store")
                                   : '${t("Choose", "Pilih")} $title',
                                style: const TextStyle(
                                  fontSize: 16, 
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black // <-- TEKS DIBUAT HITAM MUTLAK
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
          
          if (badgeText != null)
            Positioned(
              top: 0,
              right: 24,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    // Badge Text tetap kondisional karena badge tidak ada masalah kontras warna di awal
                    color: title == 'Professional' ? Colors.black87 : Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
//.......................................................//

// No ke-5: MAIN BUILDER                                 //
//.......................................................//
  @override
  Widget build(BuildContext context) {
    final appConfigAsync = ref.watch(appConfigProvider);
    final currentLocale = ref.watch(appLanguageProvider);
    final isIndo = currentLocale.languageCode == 'id';

    String t(String en, String id) => isIndo ? id : en;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A), 
      appBar: AppBar(
        title: Text(t("Membership", "Upgrade"), style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: appConfigAsync.when(
        data: (config) {
          final numberFormat = NumberFormat.decimalPattern(isIndo ? 'id_ID' : 'en_US');

          final basic = config.getPackage('basic_monthly');
          final standard = config.getPackage('standard_monthly');
          final pro = config.getPackage('pro_monthly');
          
          final topupBasic = config.getPackage('topup_basic');
          final topupStandard = config.getPackage('topup_standard');
          final topupPro = config.getPackage('topup_pro');

          // PERBAIKAN: Fallback amount disesuaikan mutlak dengan Firestore terbaru
          int basicAmount = basic?.amount ?? 55000;
          int stdAmount = standard?.amount ?? 194000;
          int proAmount = pro?.amount ?? 475000;

          int basicTopup = topupBasic?.amount ?? 95000;
          int stdTopup = topupStandard?.amount ?? 93000;
          int proTopup = topupPro?.amount ?? 90000;

          String fmt(int val) {
             if(isIndo) return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(val);
             return NumberFormat.currency(locale: 'en_US', symbol: '\$', decimalDigits: 2).format(val/15500);
          }

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                
                Padding(
                  padding: const EdgeInsets.only(bottom: 32.0, top: 8.0),
                  child: Column(
                    children: [
                      Text(
                        t("Unlock Full Potential", "Buka Potensi Maksimal"),
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        t("Choose the best plan that fits your creative needs.", "Pilih paket terbaik yang sesuai dengan kebutuhan kreatif Anda."),
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade400, height: 1.5),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                if (_isAndroidNative)
                  Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.gpp_good_rounded, color: Colors.grey.shade400, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            t("Secure payment via Google Play Store.", "Pembayaran aman melalui Google Play Store."),
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                          ),
                        ),
                      ],
                    ),
                  ),

                _buildModernPlanCard(
                  context,
                  packageId: 'basic_monthly',
                  title: 'Basic',
                  subtitle: t('Essential features for beginners', 'Fitur esensial untuk pemula'),
                  dbAmount: basicAmount, 
                  // PERBAIKAN: Fallback tokens disesuaikan
                  initialTokens: '${numberFormat.format(basic?.tokens ?? 5000)} TM',
                  topUpPrice: fmt(basicTopup), 
                  icon: Icons.rocket_launch_outlined,
                  primaryColor: const Color(0xFFB0BEC5), 
                  secondaryColor: const Color(0xFF78909C),
                  backgroundGradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF1E1E1E), 
                      Color(0xFF121212), 
                    ],
                  ),
                  isIndo: isIndo,
                ),

                _buildModernPlanCard(
                  context,
                  packageId: 'standard_monthly',
                  title: 'Standard',
                  subtitle: t('Perfect balance for active creators', 'Keseimbangan sempurna kreator aktif'),
                  dbAmount: stdAmount, 
                  // PERBAIKAN: Fallback tokens disesuaikan
                  initialTokens: '${numberFormat.format(standard?.tokens ?? 20000)} TM',
                  topUpPrice: fmt(stdTopup),
                  icon: Icons.bolt_rounded,
                  primaryColor: const Color(0xFF00E5FF), 
                  secondaryColor: const Color(0xFF0083B0), 
                  badgeText: t('MOST POPULAR', 'PALING DIMINATI'),
                  backgroundGradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF00333A), 
                      Color(0xFF0A0A0A), 
                    ],
                  ),
                  isIndo: isIndo,
                ),

                _buildModernPlanCard(
                  context,
                  packageId: 'pro_monthly',
                  title: 'Professional',
                  subtitle: t('Ultimate power for professionals', 'Kekuatan penuh untuk profesional'),
                  dbAmount: proAmount, 
                  // PERBAIKAN: Fallback tokens disesuaikan
                  initialTokens: '${numberFormat.format(pro?.tokens ?? 50000)} TM',
                  topUpPrice: fmt(proTopup),
                  icon: Icons.diamond_outlined,
                  primaryColor: const Color(0xFFFFD700), 
                  secondaryColor: const Color(0xFFFFA000), 
                  badgeText: t('BEST VALUE', 'PILIHAN SULTAN'),
                  backgroundGradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF2A0845), 
                      Color(0xFF0F0518), 
                    ],
                  ),
                  isIndo: isIndo,
                ),
                
                const SizedBox(height: 24),
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
//.......................................................//