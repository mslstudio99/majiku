// Lokasi: lib/providers_veo/firestore_veo_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services_veo/firestore_veo_service.dart';

// Provider ini menyediakan akses global ke FirestoreVeoService
final firestoreVeoServiceProvider = Provider<FirestoreVeoService>((ref) {
  return FirestoreVeoService();
});