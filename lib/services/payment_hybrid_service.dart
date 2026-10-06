//====================================================================================================//
// NAMA FILE: PAYMENT_HYBRID_SERVICE.DART                                                             //
// DIREKTORI: lib/services/payment_hybrid_service.dart                                                //
//====================================================================================================//

//No ke-1: IMPOR & PROVIDER GLOBAL....................................................................//
//Sub-judul: Memuat dependensi IAP, Cloud Functions, URL Launcher, dan Platform utils................//
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart'; 
import 'package:cloud_functions/cloud_functions.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
//Akhir Blok 1........................................................................................//

//No ke-2: KELAS UTAMA & INISIALISASI SINGLETON........................................................//
//Sub-judul: Service Singleton, Stream Subscription, dan Product Cache................................//
class PaymentHybridService {
  // Singleton instance
  static final PaymentHybridService _instance = PaymentHybridService._internal();
  factory PaymentHybridService() => _instance;
  
  final InAppPurchase _iap = InAppPurchase.instance;
  
  // [PERBAIKAN BUG]: Mengubah dari 'late' menjadi Nullable untuk mencegah LateInitializationError di iOS/Web
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  
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
          _subscription?.cancel();
        },
        onError: (error) {
          debugPrint("[IAP Error] Stream error: $error");
        },
      );
    }
  }

  bool get isAndroidIAP => !kIsWeb && Platform.isAndroid;
//Akhir Blok 2........................................................................................//

//No ke-3: FETCH PRODUCT DETAILS & CACHING............................................................//
//Sub-judul: Mengambil harga asli produk langsung dari Google Play Store..............................//
  
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
      }
    } catch (e) {
      debugPrint("[IAP Error] Exception saat fetch produk: $e");
    }
  }

  /// Mengambil harga terformat (misal: "Rp 129.000,00") dari Cache.
  String? getPriceFromCache(String productId) {
    return _productCache[productId]?.price;
  }

  /// Helper: Generate list SKU untuk Top-Up beserta variasinya
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
//Akhir Blok 3........................................................................................//

//No ke-4: EKSEKUSI PEMBAYARAN (DUITKU & GOOGLE PLAY).................................................//
//Sub-judul: Alur pemicu transaksi Web (Duitku) dan Android dengan standar IAP terbaru................//
  
  // --- JALUR PEMBAYARAN: DUITKU (WEB) ---
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

  // --- JALUR PEMBAYARAN: GOOGLE PLAY (ANDROID) ---
  Future<void> payWithGooglePlay({
    required String productId, 
  }) async {
    if (!isAndroidIAP) return;

    // Cek Cache dulu
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

    // [PERBAIKAN]: Mengamankan inisialisasi PurchaseParam untuk kompatibilitas Billing v8/v9
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
    
    // Logika Langganan vs Beli Putus (Consumable)
    if (productId.contains("monthly")) {
      // Subscription (Non-Consumable). Play Billing API terbaru mengharuskan handling BasePlan jika ada,
      // namun Plugin in_app_purchase akan otomatis menangani pemetaan ini menggunakan productDetails dasar.
      await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    } else {
      // Top-Up & Varian _x (Consumable)
      await _iap.buyConsumable(purchaseParam: purchaseParam);
    }
  }
//Akhir Blok 4........................................................................................//

//No ke-5: LISTENER TRANSAKSI & VERIFIKASI BACKEND...................................................//
//Sub-judul: Menangani stream update pembelian, verifikasi Cloud Function, dan penyelesaian transaksi.//
  
  Future<void> _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) async {
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      
      if (purchaseDetails.status == PurchaseStatus.pending) {
        // Transaksi sedang diproses...
        debugPrint("[IAP] Transaksi ${purchaseDetails.productID} sedang pending...");
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          debugPrint("[IAP] Error Transaksi: ${purchaseDetails.error?.message} (Code: ${purchaseDetails.error?.code})");
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

        // [WAJIB] Selesaikan Transaksi (Acknowledge / Consume ke Google Play v8/v9)
        if (purchaseDetails.pendingCompletePurchase) {
          await _iap.completePurchase(purchaseDetails);
        }
      }
    }
  }

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
  
  // Cleanup Resources
  void dispose() {
    _subscription?.cancel();
  }
}
//Akhir Blok 5........................................................................................//