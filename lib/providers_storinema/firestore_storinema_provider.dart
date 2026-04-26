//PROVIDERS_STORINEMA//
//FIRESTORE_STORINEMA_PROVIDER.DART//
//PROVIDER UNTUK FIRESTORE STORINEMA SERVICE//

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services_storinema/firestore_storinema_service.dart';

//No ke-1 PROVIDER INSTANCE//
//MENYEDIAKAN AKSES GLOBAL KE FIRESTORE STORINEMA SERVICE//
final firestoreStorinemaServiceProvider = Provider<FirestoreStorinemaService>((ref) {
  return FirestoreStorinemaService();
});
//........//