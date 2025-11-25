// [RILIS BERSIH - UPGRADE SCREEN: NEW TAB PAYMENT & CONSISTENT UI]
// KATEGORI_UX_IMPROVEMENT NO_URUT_08 (FIX 8.1 - OPEN NEW TAB)
// Tujuan:
// - [UX] Mengubah behavior launchUrl ke '_blank' agar halaman pembayaran terbuka di tab baru.
// - [UI] Mempertahankan konsistensi warna tombol sesuai tier paket.
// - [ANTI-REGRESI] Mempertahankan seluruh logika integrasi Duitku & Cloud Functions.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Helper Class (Tidak Berubah)
class PackageConfig {
  final int amount;
  final int tokens;
  final String tier;

  PackageConfig({
    required this.amount,
    required this.tokens,
    required this.tier,
  });

  factory PackageConfig.fromMap(Map<String, dynamic> map) {
    return PackageConfig(
      amount: (map['amount'] ?? 0).toInt(),
      tokens: (map['tokens'] ?? 0).toInt(),
      tier: map['tier'] ?? '',
    );
  }
}

class AppConfig {
  final Map<String, PackageConfig> packages;

  AppConfig({required this.packages});

  factory AppConfig.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final packagesData = data['packages'] as Map<String, dynamic>? ?? {};

    final packages = packagesData.map(
      (key, value) => MapEntry(
        key,
        PackageConfig.fromMap(value as Map<String, dynamic>),
      ),
    );
    return AppConfig(packages: packages);
  }

  PackageConfig? getPackage(String key) {
    return packages[key];
  }
}

final appConfigProvider = StreamProvider<AppConfig>((ref) {
  final firestore = FirebaseFirestore.instance;
  final docStream = firestore.doc('config/token_settings').snapshots();

  return docStream.map((doc) => AppConfig.fromFirestore(doc));
});

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
  
  final Map<String, String> paymentOptions = {
    'BC': 'BCA Virtual Account',
    'M2': 'Mandiri Virtual Account (HP)',
    'I1': 'BNI Virtual Account',
    'BR': 'BRIVA (BRI)',
    'BV': 'BSI Virtual Account',
    'SP': 'ShopeePay (QRIS)',
    'VC': 'Kartu Kredit (Visa/Master/JCB)',
  };

  Future<void> _handlePayment(String packageId, String paymentMethod) async {
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

      // [MODIFIKASI PENTING] Menggunakan '_blank' untuk membuka tab baru
      if (!await launchUrl(
          uri, 
          webOnlyWindowName: '_blank', // Diubah dari '_self' ke '_blank'
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

  Future<void> _showPaymentMethods(String packageId, String packageTitle) async {
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
                        _handlePayment(packageId, key); 
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
    required String price,
    required String period,
    required String initialTokens,
    required String topUpPrice,
    required IconData icon,
    required Color iconColor,
    bool isRecommended = false,
  }) {
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
                Text(
                  price,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.bold,
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
              text: 'Token Awal: $initialTokens',
            ),
            _buildFeatureRow(
              context,
              icon: Icons.add_shopping_cart_outlined,
              text: 'Harga Top-Up: $topUpPrice / 10.000 TM',
            ),
            const SizedBox(height: 24),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: iconColor, 
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                onPressed: _isLoading 
                    ? null 
                    : () => _showPaymentMethods(packageId, title), 
                child: _isLoading
                    ? const SizedBox( 
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                      )
                    : Text( 
                        'Pilih Paket $title',
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
    final appConfigAsync = ref.watch(appConfigProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Upgrade Membership'),
      ),
      body: appConfigAsync.when(
        data: (config) {
          final currencyFormat = NumberFormat.currency(
            locale: 'id_ID',
            symbol: 'Rp ',
            decimalDigits: 0,
          );
          
          final numberFormat = NumberFormat.decimalPattern('id_ID');

          final basic = config.getPackage('basic_monthly');
          final standard = config.getPackage('standard_monthly');
          final pro = config.getPackage('pro_monthly');
          
          final topupBasic = config.getPackage('topup_basic');
          final topupStandard = config.getPackage('topup_standard');
          final topupPro = config.getPackage('topup_pro');

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                
                // Kartu Basic (Tombol Biru)
                _buildPlanCard(
                  context,
                  packageId: 'basic_monthly',
                  title: 'Basic',
                  price: currencyFormat.format(basic?.amount ?? 95000),
                  period: '/ bulan',
                  initialTokens: '${numberFormat.format(basic?.tokens ?? 10000)} TM',
                  topUpPrice: currencyFormat.format(topupBasic?.amount ?? 95000),
                  icon: Icons.looks_3_outlined,
                  iconColor: Colors.blue.shade700,
                ),
                const SizedBox(height: 20),

                // Kartu Standard (Tombol Ungu)
                _buildPlanCard(
                  context,
                  packageId: 'standard_monthly',
                  title: 'Standard',
                  price: currencyFormat.format(standard?.amount ?? 279000),
                  period: '/ bulan',
                  initialTokens: '${numberFormat.format(standard?.tokens ?? 30000)} TM',
                  topUpPrice: currencyFormat.format(topupStandard?.amount ?? 93000),
                  icon: Icons.looks_two_outlined,
                  iconColor: Colors.purple.shade700,
                  isRecommended: true,
                ),
                const SizedBox(height: 20),

                // Kartu Professional (Tombol Amber)
                _buildPlanCard(
                  context,
                  packageId: 'pro_monthly',
                  title: 'Professional',
                  price: currencyFormat.format(pro?.amount ?? 2700000),
                  period: '/ bulan',
                  initialTokens: '${numberFormat.format(pro?.tokens ?? 300000)} TM',
                  topUpPrice: currencyFormat.format(topupPro?.amount ?? 90000),
                  icon: Icons.workspace_premium_outlined,
                  iconColor: Colors.amber.shade800,
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
              'Gagal memuat data harga.\nError: ${err.toString()}',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red.shade700),
            ),
          ),
        ),
      ),
    );
  }
}