//......................................................//
// LIB/SERVICES_DAILY_FREE/FIRESTORE_FREE_T2IMAGE_SERVICE.DART //
//......................................................//

// No ke-1: IMPORT & SERVICE PROVIDER                     //
//......................................................//
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Provider global agar Service ini mudah diakses secara aman oleh View Model
final freeT2ImageServiceProvider = Provider<FirestoreFreeT2ImageService>((ref) {
  return FirestoreFreeT2ImageService();
});
// Penutup Blok //

// No ke-2: CLOUD FUNCTION CALLER LOGIC                 //
//......................................................//
class FirestoreFreeT2ImageService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Memanggil Cloud Function untuk mengenerate gambar gratis.
  /// CATATAN KEAMANAN: Logika validasi kuota 1x user/hari dan 100x global/hari 
  /// tidak diletakkan di sini untuk mencegah eksploitasi sisi client. 
  /// Semuanya diatur dan divalidasi langsung oleh Backend Cloud Functions.
  Future<Map<String, dynamic>> generateFreeImage({
    required String prompt,
    required String style,
    required String aspectRatio,
  }) async {
    try {
      // Nama endpoint function yang akan kita buat nanti di backend
      final callable = FirebaseFunctions.instanceFor(region: 'asia-southeast2')
    .httpsCallable('generateFreeT2Image');
      
      final response = await callable.call(<String, dynamic>{
        'prompt': prompt,
        'style': style,
        'aspectRatio': aspectRatio,
      });

      // Validasi struktur kembalian data dari backend
      if (response.data != null && response.data is Map) {
        return Map<String, dynamic>.from(response.data as Map);
      } else {
        throw Exception("Format respons dari server tidak valid atau kosong.");
      }
      
    } on FirebaseFunctionsException catch (e) {
      // Menangkap lemparan error spesifik dari backend 
      // (Contoh: "Jatah harian sistem habis!" atau "Anda sudah menggunakan jatah hari ini!")
      throw Exception(e.message ?? "Terjadi kesalahan sistem dari server.");
    } catch (e) {
      // Menangkap error umum seperti masalah jaringan
      throw Exception("Gagal terhubung ke layanan generator gambar: $e");
    }
  }
}
// Penutup Blok //