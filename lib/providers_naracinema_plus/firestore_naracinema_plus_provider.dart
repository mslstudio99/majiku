//================================================================//
// NAMA FILE: FIRESTORE_NARACINEMA_PLUS_PROVIDER.DART             //
// DIREKTORI: LIB/PROVIDERS_NARACINEMA_PLUS/                      //
// DESKRIPSI: PROVIDER UNTUK FIRESTORE NARACINEMA PLUS SERVICE    //
//================================================================//

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services_naracinema_plus/firestore_naracinema_plus_service.dart';

// No ke-1: PROVIDER INSTANCE                                     //
//----------------------------------------------------------------//
// MENYEDIAKAN AKSES GLOBAL KE FIRESTORE NARACINEMA PLUS SERVICE
final firestoreNaracinemaPlusServiceProvider = Provider<FirestoreNaracinemaPlusService>((ref) {
  return FirestoreNaracinemaPlusService();
});
//----------------------------------------------------------------//