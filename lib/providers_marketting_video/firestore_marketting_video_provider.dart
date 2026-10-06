//================================================================//
// NAMA FILE: FIRESTORE_MARKETTING_VIDEO_PROVIDER.DART             //
// DIREKTORI: LIB/PROVIDERS_MARKETTING_VIDEO/                      //
// DESKRIPSI: PROVIDER UNTUK FIRESTORE MARKETTING VIDEO SERVICE    //
//================================================================//

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services_marketting_video/firestore_marketting_video_service.dart';

// No ke-1: PROVIDER INSTANCE                                     //
//----------------------------------------------------------------//
// MENYEDIAKAN AKSES GLOBAL KE FIRESTORE MARKETTING VIDEO SERVICE
final firestoreMarkettingVideoServiceProvider = Provider<FirestoreMarkettingVideoService>((ref) {
  return FirestoreMarkettingVideoService();
});
//----------------------------------------------------------------//