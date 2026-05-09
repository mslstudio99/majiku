//......................................................//
// LIB/SERVICES_DAILY_FREE/FIRESTORE_FREE_T2SPEECH_SERVICE.DART //
//......................................................//

// No ke-1: IMPORT & SERVICE PROVIDER                     //
//......................................................//
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Provider global agar Service ini mudah diakses secara aman oleh View Model
final freeT2SpeechServiceProvider = Provider<FirestoreFreeT2SpeechService>((ref) {
  return FirestoreFreeT2SpeechService();
});
// Penutup Blok //

// No ke-2: CLOUD FUNCTION CALLER LOGIC                 //
//......................................................//
class FirestoreFreeT2SpeechService {
  // Region disesuaikan dengan inisialisasi pada backend index.ts
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'asia-southeast2');

  /// Memanggil Cloud Function untuk mengenerate audio gratis.
  /// CATATAN KEAMANAN: Logika validasi kuota 1x user/hari dan 200x global/hari 
  /// tidak diletakkan di sini untuk mencegah eksploitasi sisi client. 
  /// Semuanya diatur dan divalidasi langsung oleh Backend Cloud Functions.
  Future<Map<String, dynamic>> generateFreeSpeech({
    required String text,
    required String languageCode,
    required String voiceName,
  }) async {
    try {
      // Nama endpoint function yang dipanggil sesuai dengan export di index.ts
      final callable = _functions.httpsCallable('generateFreeT2Speech');
      
      final response = await callable.call(<String, dynamic>{
        'text': text,
        'languageCode': languageCode,
        'voiceName': voiceName,
      });

      // Validasi struktur kembalian data dari backend
      if (response.data != null && response.data is Map) {
        return Map<String, dynamic>.from(response.data as Map);
      } else {
        throw Exception("Format respons dari server tidak valid atau kosong.");
      }
      
    } on FirebaseFunctionsException catch (e) {
      // Menangkap lemparan error spesifik dari backend 
      // (Contoh: "Jatah global fitur Text-to-Speech gratis hari ini sudah habis!")
      throw Exception(e.message ?? "Terjadi kesalahan sistem dari server.");
    } catch (e) {
      // Menangkap error umum seperti masalah jaringan
      throw Exception("Gagal terhubung ke layanan generator suara: $e");
    }
  }
}
// Penutup Blok //