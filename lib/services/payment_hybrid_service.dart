// [RILIS BERSIH - PAYMENT HYBRID SERVICE FINAL v3.1]
// KATEGORI_BUG_FIX NO_URUT_01
// Perbaikan: 
// 1. [FIX] Membuka import 'package:flutter/foundation.dart' agar 'debugPrint' terbaca.
// 2. Logika Fetch & IAP tetap sama dengan v3.

import 'dart:async';
import 'dart:io';

// [FIX] Hapus 'show kIsWeb' agar debugPrint dan utility lain bisa dipakai
import 'package:flutter/foundation.dart'; 

import 'package:cloud_functions/cloud_functions.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class PaymentHybridService {
  // Singleton instance
  static final PaymentHybridService _instance = PaymentHybridService._internal();
  factory PaymentHybridService() => _instance;
  
  final InAppPurchase _iap = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;
  
  // Cache harga Google agar UI tidak loading berulang kali
  final Map<String, ProductDetails> _productCache = {};

  // Constructor Internal
  PaymentHybridService._internal() {
    // Cek platform logic
    if (!kIsWeb && Platform.isAndroid) {
      final purchaseUpdated = _iap.purchaseStream;
      _subscription = purchaseUpdated.listen(
        _listenToPurchaseUpdated,
        onDone: () {
          _subscription.cancel();
        },
        onError: (error) {
          // Sekarang debugPrint sudah dikenali
          debugPrint("[IAP Error] Stream error: $error");
        },
      );
    }
  }

  bool get isAndroidIAP => !kIsWeb && Platform.isAndroid;

  // --- 1. FITUR BARU: FETCH HARGA ASLI (SOLUSI KEBIJAKAN GOOGLE) ---
  
  /// Mengambil detail produk (Harga, Deskripsi) langsung dari Google Play.
  /// Wajib dipanggil saat Screen dimuat (initState).
  Future<void> fetchProductDetails(Set<String> productIds) async {
    if (!isAndroidIAP) return;

    final bool available = await _iap.isAvailable();
    if (!available) {
      debugPrint("[IAP] Google Play Store tidak tersedia/tidak terhubung.");
      return;
    }

    // Hanya fetch ID yang belum ada di cache untuk efisiensi
    final idsToFetch = productIds.where((id) => !_productCache.containsKey(id)).toSet();

    if (idsToFetch.isEmpty) return; // Semua sudah ada di cache

    try {
      final ProductDetailsResponse response = await _iap.queryProductDetails(idsToFetch);
      
      if (response.notFoundIDs.isNotEmpty) {
        debugPrint("[IAP Warning] ID tidak ditemukan di Console: ${response.notFoundIDs}");
      }

      if (response.error != null) {
        debugPrint("[IAP Error] Query failed: ${response.error!.message}");
      }

      // Simpan hasil ke Cache Memory
      for (var product in response.productDetails) {
        _productCache[product.id] = product;
        // Debugging: Pastikan harga yang diambil benar
        // debugPrint("[IAP] Fetched: ${product.id} -> ${product.price}");
      }
    } catch (e) {
      debugPrint("[IAP Error] Exception saat fetch produk: $e");
    }
  }

  /// Mengambil harga terformat (misal: "Rp 129.000,00") dari Cache.
  /// Jika belum ada, return null (Screen harus handle loading state).
  String? getPriceFromCache(String productId) {
    return _productCache[productId]?.price;
  }

  /// Helper: Generate list SKU untuk Top-Up beserta variasinya
  /// Input: baseId='topup_basic', quantities=[1, 3, 5] 
  /// Output: {'topup_basic', 'topup_basic_x3', 'topup_basic_x5'}
  Set<String> generateVariantIds(String baseId, List<int> quantities) {
    final Set<String> ids = {}; 
    for (var qty in quantities) {
      if (qty == 1) {
        ids.add(baseId);
      } else if (qty > 1) {
        ids.add("${baseId}_x$qty"); // Format Suffix sesuai Backend
      }
    }
    return ids;
  }

  // --- 2. JALUR PEMBAYARAN: DUITKU (WEB) ---
  
  Future<void> payWithDuitku({
    required String packageId,
    required String paymentMethod,
    required int quantity,
  }) async {
    final functions = FirebaseFunctions.instanceFor(region: "asia-southeast2");
    final callable = functions.httpsCallable('createDuitkuTransaction');

    final result = await callable.call<Map<String, dynamic>>({
      'packageId': packageId,
      'paymentMethod': paymentMethod,
      'quantity': quantity,
    });

    final paymentUrl = result.data['paymentUrl'] as String?;
    if (paymentUrl == null) {
      throw Exception("Payment URL tidak diterima dari server.");
    }

    final uri = Uri.parse(paymentUrl);
    if (!await launchUrl(uri, webOnlyWindowName: '_blank')) {
      throw Exception('Tidak dapat membuka URL: $paymentUrl');
    }
  }

  // --- 3. JALUR PEMBAYARAN: GOOGLE PLAY (ANDROID) ---
  
  Future<void> payWithGooglePlay({
    required String productId, 
  }) async {
    if (!isAndroidIAP) return;

    // Cek Cache dulu.
    ProductDetails? product = _productCache[productId];

    if (product == null) {
      // Emergency fetch (Fallback)
      final ProductDetailsResponse response = await _iap.queryProductDetails({productId});
      if (response.productDetails.isEmpty) {
         throw Exception("Produk $productId tidak tersedia di Google Play Store saat ini.");
      }
      product = response.productDetails.first;
      _productCache[productId] = product; // Update cache
    }

    final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
    
    // Logika Langganan vs Beli Putus (Consumable)
    if (productId.contains("monthly")) {
      // Subscription (Non-Consumable)
      await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    } else {
      // Top-Up & Varian _x (Consumable)
      await _iap.buyConsumable(purchaseParam: purchaseParam);
    }
  }

  // --- 4. LISTENER HASIL PEMBAYARAN ---
  
  Future<void> _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) async {
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      
      if (purchaseDetails.status == PurchaseStatus.pending) {
        // Transaksi sedang diproses...
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          debugPrint("[IAP] Error: ${purchaseDetails.error}");
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
                   purchaseDetails.status == PurchaseStatus.restored) {
          
          // SUKSES BAYAR -> Validasi ke Backend
          final bool valid = await _verifyPurchase(purchaseDetails);
          
          if (valid) {
             debugPrint("[IAP] Verifikasi Backend Sukses. Token/Tier ditambahkan.");
          } else {
             debugPrint("[IAP] Verifikasi Backend Gagal/Invalid.");
          }
        }

        // [WAJIB] Selesaikan Transaksi
        if (purchaseDetails.pendingCompletePurchase) {
          await _iap.completePurchase(purchaseDetails);
        }
      }
    }
  }

  // --- 5. VERIFIKASI KE CLOUD FUNCTIONS ---
  
  Future<bool> _verifyPurchase(PurchaseDetails purchaseDetails) async {
    try {
      final functions = FirebaseFunctions.instanceFor(region: "asia-southeast2");
      final callable = functions.httpsCallable('verifyGooglePlayPurchase');

      await callable.call({
        'productId': purchaseDetails.productID, 
        'purchaseToken': purchaseDetails.verificationData.serverVerificationData,
      });

      return true;
    } catch (e) {
      debugPrint("[Verify Error] $e");
      return false;
    }
  }
  
  // Cleanup
  void dispose() {
    _subscription.cancel();
  }
}