//================================================================//
// NAMA FILE: INPUT_SCRIPT_MARKETTING_VIDEO_SCREEN.DART           //
// DIREKTORI: LIB/SCREENS_MARKETTING_VIDEO/                       //
// DESKRIPSI: LAYAR INPUT SCRIPT MARKETTING_VIDEO (VERSI TOGGLE)  //
//================================================================//

//No ke-1.........................................................//
// IMPORT DEPENDENSI & SETUP AWAL                                 //
import 'dart:io' as io;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../services_marketting_video/firestore_marketting_video_service.dart';
import '../services/firestore_service.dart'; // [BARU] Akses logging Firestore User Center
import '../providers_marketting_video/firestore_marketting_video_provider.dart';
import '../providers_marketting_video/visual_settings_marketting_video_provider.dart';
import 'project_loading_marketting_video_screen.dart';

import '../providers/user_provider.dart';
import '../providers/config_provider.dart'; 
import '../theme/app_theme.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
//................................................................//

// No ke-2 - SETUP STATE DAN MAPS OPSI SUARA (VOICES)...//
// Struktur kelas StatefulWidget dan state parameter....//
class InputScriptMarkettingVideoScreen extends ConsumerStatefulWidget {
  final String initialTitle;
  final String initialScript;

  const InputScriptMarkettingVideoScreen({
    super.key,
    this.initialTitle = '',
    this.initialScript = '',
  });

  @override
  ConsumerState<InputScriptMarkettingVideoScreen> createState() => _InputScriptMarkettingVideoScreenState();
}

class _InputScriptMarkettingVideoScreenState extends ConsumerState<InputScriptMarkettingVideoScreen> {
  // [CONTROLLER LAMA: DIPERTAHANKAN]
  final _scriptController = TextEditingController();
  final _descriptionController = TextEditingController(); 
  
  // [CONTROLLER BARU: KONSULTAN PEMASARAN & TARGET BAHASA AI]
  final _productTypeController = TextEditingController();
  final _brandController = TextEditingController();
  final _productDescController = TextEditingController(); 
  final _aiLanguageController = TextEditingController(); // Controller Target Bahasa AI
  final _formKey = GlobalKey<FormState>();
  
  // [DUAL IMAGE: XFile agar ramah Flutter Web & Mobile]
  XFile? _productImage;
  XFile? _logoImage;
  final ImagePicker _imagePicker = ImagePicker();

  // [PERBAIKAN]: Default panjang narasi diatur ke 500 karakter
  int _narrationLength = 500;
  bool _isGeneratingNarration = false;
  
  // [PERBAIKAN TOGGLE OVERLAY]: Default diatur OFF (false)
  bool _showDescription = false; 
  String _descriptionTiming = 'start'; // Pilihan: 'start' (Awal) atau 'end' (Akhir)

  String _selectedStyle = 'Realistic';
  
  // [PERBAIKAN]: Default Aspek Rasio diubah menjadi Potret (9:16)
  String _selectedAspectRatio = '9:16';
  
  String _selectedLanguage = 'English (US)'; 
  static const String _defaultEnglishVoice = 'en-US-Chirp3-HD-Alnilam';
  String _selectedVoice = _defaultEnglishVoice;  
  bool _isLoading = false;
  
  bool _showSubtitles = false; 
  String _selectedResolution = '720p'; 

  // [PERBAIKAN MUTLAK]: Default Kategori Kualitas ke 'Standard' (Veo 3.1 Fast)
  String _selectedCostLevel = 'Standard';

  // ==========================================
  // OPSI SUARA (LENGKAP - TIDAK ADA YANG DIPOTONG)
  // ==========================================
  final Map<String, String> _indonesianVoiceOptions = {
    'Achernar (ID) - F': 'id-ID-Chirp3-HD-Achernar', 'Achird (ID) - M': 'id-ID-Chirp3-HD-Achird',
    'Algenib (ID) - M': 'id-ID-Chirp3-HD-Algenib', 'Algieba (ID) - M': 'id-ID-Chirp3-HD-Algieba',
    'Alnilam (ID) - M': 'id-ID-Chirp3-HD-Alnilam', 'Aoede (ID) - F': 'id-ID-Chirp3-HD-Aoede',
    'Autonoe (ID) - F': 'id-ID-Chirp3-HD-Autonoe', 'Callirrhoe (ID) - F': 'id-ID-Chirp3-HD-Callirrhoe',
    'Charon (ID) - M': 'id-ID-Chirp3-HD-Charon', 'Despina (ID) - F': 'id-ID-Chirp3-HD-Despina',
    'Enceladus (ID) - M': 'id-ID-Chirp3-HD-Enceladus', 'Erinome (ID) - F': 'id-ID-Chirp3-HD-Erinome',
    'Fenrir (ID) - M': 'id-ID-Chirp3-HD-Fenrir', 'Gacrux (ID) - F': 'id-ID-Chirp3-HD-Gacrux',
    'Iapetus (ID) - M': 'id-ID-Chirp3-HD-Iapetus', 'Kore (ID) - F': 'id-ID-Chirp3-HD-Kore',
    'Laomedeia (ID) - F': 'id-ID-Chirp3-HD-Laomedeia', 'Leda (ID) - F': 'id-ID-Chirp3-HD-Leda',
    'Orus (ID) - M': 'id-ID-Chirp3-HD-Orus', 'Puck (ID) - M': 'id-ID-Chirp3-HD-Puck',
    'Pulcherrima (ID) - M': 'id-ID-Chirp3-HD-Pulcherrima', 'Rasalgethi (ID) - M': 'id-ID-Chirp3-HD-Rasalgethi',
    'Sadachbia (ID) - M': 'id-ID-Chirp3-HD-Sadachbia', 'Sadaltager (ID) - M': 'id-ID-Chirp3-HD-Sadaltager',
    'Schedar (ID) - M': 'id-ID-Chirp3-HD-Schedar', 'Sulafat (ID) - F': 'id-ID-Chirp3-HD-Sulafat',
    'Umbriel (ID) - M': 'id-ID-Chirp3-HD-Umbriel', 'Vindemiatrix (ID) - F': 'id-ID-Chirp3-HD-Vindemiatrix',
    'Zephyr (ID) - F': 'id-ID-Chirp3-HD-Zephyr', 'Zubenelgenubi (ID) - M': 'id-ID-Chirp3-HD-Zubenelgenubi',
  };

  final Map<String, String> _englishVoiceOptions = {
    'Alnilam (EN) - M': 'en-US-Chirp3-HD-Alnilam', 'Aoede (EN) - F': 'en-US-Chirp3-HD-Aoede',
    'Autonoe (EN) - F': 'en-US-Chirp3-HD-Aoede', 'Callirrhoe (EN) - F': 'en-US-Chirp3-HD-Callirrhoe',
    'Charon (EN) - M': 'en-US-Chirp3-HD-Charon', 'Despina (EN) - F': 'en-US-Chirp3-HD-Despina',
    'Enceladus (EN) - M': 'en-US-Chirp3-HD-Enceladus', 'Erinome (EN) - F': 'en-US-Chirp3-HD-Erinome',
    'Fenrir (EN) - M': 'en-US-Chirp3-HD-Fenrir', 'Gacrux (EN) - F': 'en-US-Chirp3-HD-Gacrux',
    'Iapetus (EN) - M': 'en-US-Chirp3-HD-Iapetus', 'Kore (EN) - F': 'en-US-Chirp3-HD-Kore',
    'Laomedeia (EN) - F': 'en-US-Chirp3-HD-Laomedeia', 'Leda (EN) - F': 'en-US-Chirp3-HD-Leda',
    'Orus (EN) - M': 'en-US-Chirp3-HD-Orus', 'Puck (EN) - M': 'en-US-Chirp3-HD-Puck',
    'Pulcherrima (EN) - M': 'en-US-Chirp3-HD-Pulcherrima', 'Rasalgethi (EN) - M': 'en-US-Chirp3-HD-Rasalgethi',
    'Sadachbia (EN) - M': 'en-US-Chirp3-HD-Sadachbia', 'Sadaltager (EN) - M': 'en-US-Chirp3-HD-Sadaltager',
    'Schedar (EN) - M': 'en-US-Chirp3-HD-Schedar', 'Sulafat (EN) - F': 'en-US-Chirp3-HD-Sulafat',
    'Umbriel (EN) - M': 'en-US-Chirp3-HD-Umbriel', 'Vindemiatrix (EN) - F': 'en-US-Chirp3-HD-Vindemiatrix',
    'Zephyr (EN) - F': 'en-US-Chirp3-HD-Zephyr', 'Zubenelgenubi (EN) - M': 'en-US-Chirp3-HD-Zubenelgenubi',
  };

  final Map<String, String> _arabicVoiceOptions = {
    'Achernar (ar-XA) - F': 'ar-XA-Chirp3-HD-Achernar', 'Aoede (ar-XA) - F': 'ar-XA-Chirp3-HD-Aoede',
    'Autonoe (ar-XA) - F': 'ar-XA-Chirp3-HD-Autonoe', 'Callirrhoe (ar-XA) - F': 'ar-XA-Chirp3-HD-Callirrhoe',
    'Despina (ar-XA) - F': 'ar-XA-Chirp3-HD-Despina', 'Achird (ar-XA) - M': 'ar-XA-Chirp3-HD-Achird',
    'Algenib (ar-XA) - M': 'ar-XA-Chirp3-HD-Algenib', 'Algieba (ar-XA) - M': 'ar-XA-Chirp3-HD-Algieba',
    'Alnilam (ar-XA) - M': 'ar-XA-Chirp3-HD-Alnilam', 'Charon (ar-XA) - M': 'ar-XA-Chirp3-HD-Charon',
  };

  final Map<String, String> _bengaliVoiceOptions = {
    'Achernar (bn-IN) - F': 'bn-IN-Chirp3-HD-Achernar', 'Aoede (bn-IN) - F': 'bn-IN-Chirp3-HD-Aoede',
    'Autonoe (bn-IN) - F': 'bn-IN-Chirp3-HD-Autonoe', 'Callirrhoe (bn-IN) - F': 'bn-IN-Chirp3-HD-Callirrhoe',
    'Despina (bn-IN) - F': 'bn-IN-Chirp3-HD-Despina', 'Achird (bn-IN) - M': 'bn-IN-Chirp3-HD-Achird',
    'Algenib (bn-IN) - M': 'bn-IN-Chirp3-HD-Algenib', 'Algieba (bn-IN) - M': 'bn-IN-Chirp3-HD-Algieba',
    'Alnilam (bn-IN) - M': 'bn-IN-Chirp3-HD-Alnilam', 'Charon (bn-IN) - M': 'bn-IN-Chirp3-HD-Charon',
  };

  final Map<String, String> _danishVoiceOptions = {
    'Achernar (da-DK) - F': 'da-DK-Chirp3-HD-Achernar', 'Aoede (da-DK) - F': 'da-DK-Chirp3-HD-Aoede',
    'Autonoe (da-DK) - F': 'da-DK-Chirp3-HD-Autonoe', 'Callirrhoe (da-DK) - F': 'da-DK-Chirp3-HD-Callirrhoe',
    'Despina (da-DK) - F': 'da-DK-Chirp3-HD-Despina', 'Achird (da-DK) - M': 'da-DK-Chirp3-HD-Achird',
    'Algenib (da-DK) - M': 'da-DK-Chirp3-HD-Algenib', 'Algieba (da-DK) - M': 'da-DK-Chirp3-HD-Algieba',
    'Alnilam (da-DK) - M': 'da-DK-Chirp3-HD-Alnilam', 'Charon (da-DK) - M': 'da-DK-Chirp3-HD-Charon',
  };

  final Map<String, String> _dutchBelgiumVoiceOptions = {
    'Achernar (nl-BE) - F': 'nl-BE-Chirp3-HD-Achernar', 'Aoede (nl-BE) - F': 'nl-BE-Chirp3-HD-Aoede',
    'Autonoe (nl-BE) - F': 'nl-BE-Chirp3-HD-Autonoe', 'Callirrhoe (nl-BE) - F': 'nl-BE-Chirp3-HD-Callirrhoe',
    'Despina (nl-BE) - F': 'nl-BE-Chirp3-HD-Despina', 'Achird (nl-BE) - M': 'nl-BE-Chirp3-HD-Achird',
    'Algenib (nl-BE) - M': 'nl-BE-Chirp3-HD-Algenib', 'Algieba (nl-BE) - M': 'nl-BE-Chirp3-HD-Algieba',
    'Alnilam (nl-BE) - M': 'nl-BE-Chirp3-HD-Alnilam', 'Charon (nl-BE) - M': 'nl-BE-Chirp3-HD-Charon',
  };

  final Map<String, String> _dutchNetherlandsVoiceOptions = {
    'Achernar (nl-NL) - F': 'nl-NL-Chirp3-HD-Achernar', 'Aoede (nl-NL) - F': 'nl-NL-Chirp3-HD-Aoede',
    'Autonoe (nl-NL) - F': 'nl-NL-Chirp3-HD-Autonoe', 'Callirrhoe (nl-NL) - F': 'nl-NL-Chirp3-HD-Callirrhoe',
    'Despina (nl-NL) - F': 'nl-NL-Chirp3-HD-Despina', 'Achird (nl-NL) - M': 'nl-NL-Chirp3-HD-Achird',
    'Algenib (nl-NL) - M': 'nl-NL-Chirp3-HD-Algenib', 'Algieba (nl-NL) - M': 'nl-NL-Chirp3-HD-Algieba',
    'Alnilam (nl-NL) - M': 'nl-NL-Chirp3-HD-Alnilam', 'Charon (nl-NL) - M': 'nl-NL-Chirp3-HD-Charon',
  };

  final Map<String, String> _englishAustraliaVoiceOptions = {
    'Achernar (en-AU) - F': 'en-AU-Chirp3-HD-Achernar', 'Aoede (en-AU) - F': 'en-AU-Chirp3-HD-Aoede',
    'Autonoe (en-AU) - F': 'en-AU-Chirp3-HD-Autonoe', 'Callirrhoe (en-AU) - F': 'en-AU-Chirp3-HD-Callirrhoe',
    'Despina (en-AU) - F': 'en-AU-Chirp3-HD-Despina', 'Achird (en-AU) - M': 'en-AU-Chirp3-HD-Achird',
    'Algenib (en-AU) - M': 'en-AU-Chirp3-HD-Algenib', 'Algieba (en-AU) - M': 'en-AU-Chirp3-HD-Algieba',
    'Alnilam (en-AU) - M': 'en-AU-Chirp3-HD-Alnilam', 'Charon (en-AU) - M': 'en-AU-Chirp3-HD-Charon',
  };

  final Map<String, String> _englishIndiaVoiceOptions = {
    'Achernar (en-IN) - F': 'en-IN-Chirp3-HD-Achernar', 'Aoede (en-IN) - F': 'en-IN-Chirp3-HD-Aoede',
    'Autonoe (en-IN) - F': 'en-IN-Chirp3-HD-Autonoe', 'Callirrhoe (en-IN) - F': 'en-IN-Chirp3-HD-Callirrhoe',
    'Despina (en-IN) - F': 'en-IN-Chirp3-HD-Despina', 'Achird (en-IN) - M': 'en-IN-Chirp3-HD-Achird',
    'Algenib (en-IN) - M': 'en-IN-Chirp3-HD-Algenib', 'Algieba (en-IN) - M': 'en-IN-Chirp3-HD-Algieba',
    'Alnilam (en-IN) - M': 'en-IN-Chirp3-HD-Alnilam', 'Charon (en-IN) - M': 'en-IN-Chirp3-HD-Charon',
  };

  final Map<String, String> _englishUKVoiceOptions = {
    'Achernar (en-GB) - F': 'en-GB-Chirp3-HD-Achernar', 'Aoede (en-GB) - F': 'en-GB-Chirp3-HD-Aoede',
    'Autonoe (en-GB) - F': 'en-GB-Chirp3-HD-Autonoe', 'Callirrhoe (en-GB) - F': 'en-GB-Chirp3-HD-Callirrhoe',
    'Despina (en-GB) - F': 'en-GB-Chirp3-HD-Despina', 'Achird (en-GB) - M': 'en-GB-Chirp3-HD-Achird',
    'Algenib (en-GB) - M': 'en-GB-Chirp3-HD-Algenib', 'Algieba (en-GB) - M': 'en-GB-Chirp3-HD-Algieba',
    'Alnilam (en-GB) - M': 'en-GB-Chirp3-HD-Alnilam', 'Charon (en-GB) - M': 'en-GB-Chirp3-HD-Charon',
  };

  final Map<String, String> _finnishVoiceOptions = {
    'Achernar (fi-FI) - F': 'fi-FI-Chirp3-HD-Achernar', 'Aoede (fi-FI) - F': 'fi-FI-Chirp3-HD-Aoede',
    'Autonoe (fi-FI) - F': 'fi-FI-Chirp3-HD-Autonoe', 'Callirrhoe (fi-FI) - F': 'fi-FI-Chirp3-HD-Callirrhoe',
    'Despina (fi-FI) - F': 'fi-FI-Chirp3-HD-Despina', 'Achird (fi-FI) - M': 'fi-FI-Chirp3-HD-Achird',
    'Algenib (fi-FI) - M': 'fi-FI-Chirp3-HD-Algenib', 'Algieba (fi-FI) - M': 'fi-FI-Chirp3-HD-Algieba',
    'Alnilam (fi-FI) - M': 'fi-FI-Chirp3-HD-Alnilam', 'Charon (fi-FI) - M': 'fi-FI-Charon',
  };

  final Map<String, String> _frenchCanadaVoiceOptions = {
    'Achernar (fr-CA) - F': 'fr-CA-Chirp3-HD-Achernar', 'Aoede (fr-CA) - F': 'fr-CA-Chirp3-HD-Aoede',
    'Autonoe (fr-CA) - F': 'fr-CA-Chirp3-HD-Autonoe', 'Callirrhoe (fr-CA) - F': 'fr-CA-Chirp3-HD-Callirrhoe',
    'Despina (fr-CA) - F': 'fr-CA-Chirp3-HD-Despina', 'Achird (fr-CA) - M': 'fr-CA-Chirp3-HD-Achird',
    'Algenib (fr-CA) - M': 'fr-CA-Chirp3-HD-Algenib', 'Algieba (fr-CA) - M': 'fr-CA-Chirp3-HD-Algieba',
    'Alnilam (fr-CA) - M': 'fr-CA-Chirp3-HD-Alnilam', 'Charon (fr-CA) - M': 'fr-CA-Chirp3-HD-Charon',
  };

  final Map<String, String> _frenchFranceVoiceOptions = {
    'Achernar (fr-FR) - F': 'fr-FR-Chirp3-HD-Achernar', 'Aoede (fr-FR) - F': 'fr-FR-Chirp3-HD-Aoede',
    'Autonoe (fr-FR) - F': 'fr-FR-Chirp3-HD-Autonoe', 'Callirrhoe (fr-FR) - F': 'fr-FR-Chirp3-HD-Callirrhoe',
    'Despina (fr-FR) - F': 'fr-FR-Chirp3-HD-Despina', 'Achird (fr-FR) - M': 'fr-FR-Chirp3-HD-Achird',
    'Algenib (fr-FR) - M': 'fr-CA-Chirp3-HD-Algenib', 'Algieba (fr-FR) - M': 'fr-FR-Chirp3-HD-Algieba',
    'Alnilam (fr-FR) - M': 'fr-FR-Chirp3-HD-Alnilam', 'Charon (fr-FR) - M': 'fr-FR-Chirp3-HD-Charon',
  };

  final Map<String, String> _germanVoiceOptions = {
    'Achernar (de-DE) - F': 'de-DE-Chirp3-HD-Achernar', 'Aoede (de-DE) - F': 'de-DE-Chirp3-HD-Aoede',
    'Autonoe (de-DE) - F': 'de-DE-Chirp3-HD-Autonoe', 'Callirrhoe (de-DE) - F': 'de-DE-Chirp3-HD-Callirrhoe',
    'Despina (de-DE) - F': 'de-DE-Chirp3-HD-Despina', 'Achird (de-DE) - M': 'de-DE-Chirp3-HD-Achird',
    'Algenib (de-DE) - M': 'de-DE-Chirp3-HD-Algenib', 'Algieba (de-DE) - M': 'de-DE-Chirp3-HD-Algieba',
    'Alnilam (de-DE) - M': 'de-DE-Chirp3-HD-Alnilam', 'Charon (de-DE) - M': 'de-DE-Chirp3-HD-Charon',
  };

  final Map<String, String> _gujaratiVoiceOptions = {
    'Achernar (gu-IN) - F': 'gu-IN-Chirp3-HD-Achernar', 'Aoede (gu-IN) - F': 'gu-IN-Chirp3-HD-Aoede',
    'Autonoe (gu-IN) - F': 'gu-IN-Chirp3-HD-Autonoe', 'Callirrhoe (gu-IN) - F': 'gu-IN-Chirp3-HD-Callirrhoe',
    'Despina (gu-IN) - F': 'gu-IN-Chirp3-HD-Despina', 'Achird (gu-IN) - M': 'gu-IN-Chirp3-HD-Achird',
    'Algenib (gu-IN) - M': 'gu-IN-Chirp3-HD-Algenib', 'Algieba (gu-IN) - M': 'gu-IN-Chirp3-HD-Algieba',
    'Alnilam (gu-IN) - M': 'gu-IN-Chirp3-HD-Alnilam', 'Charon (gu-IN) - M': 'gu-IN-Chirp3-HD-Charon',
  };

  final Map<String, String> _hindiVoiceOptions = {
    'Achernar (hi-IN) - F': 'hi-IN-Chirp3-HD-Achernar', 'Aoede (hi-IN) - F': 'hi-IN-Chirp3-HD-Aoede',
    'Autonoe (hi-IN) - F': 'hi-IN-Chirp3-HD-Autonoe', 'Callirrhoe (hi-IN) - F': 'hi-IN-Chirp3-HD-Callirrhoe',
    'Despina (hi-IN) - F': 'hi-IN-Chirp3-HD-Despina', 'Achird (hi-IN) - M': 'hi-IN-Chirp3-HD-Achird',
    'Algenib (hi-IN) - M': 'hi-IN-Chirp3-HD-Algenib', 'Algieba (hi-IN) - M': 'hi-IN-Chirp3-HD-Algieba',
    'Alnilam (hi-IN) - M': 'hi-IN-Chirp3-HD-Alnilam', 'Charon (hi-IN) - M': 'hi-IN-Chirp3-HD-Charon',
  };

  final Map<String, String> _italianVoiceOptions = {
    'Achernar (it-IT) - F': 'it-IT-Chirp3-HD-Achernar', 'Aoede (it-IT) - F': 'it-IT-Chirp3-HD-Aoede',
    'Autonoe (it-IT) - F': 'it-IT-Chirp3-HD-Autonoe', 'Callirrhoe (it-IT) - F': 'it-IT-Chirp3-HD-Callirrhoe',
    'Despina (it-IT) - F': 'it-IT-Chirp3-HD-Despina', 'Achird (it-IT) - M': 'it-IT-Chirp3-HD-Achird',
    'Algenib (it-IT) - M': 'it-IT-Chirp3-HD-Algenib', 'Algieba (it-IT) - M': 'it-IT-Chirp3-HD-Algieba',
    'Alnilam (it-IT) - M': 'it-IT-Chirp3-HD-Alnilam', 'Charon (it-IT) - M': 'it-IT-Chirp3-HD-Charon',
  };

  final Map<String, String> _japaneseVoiceOptions = {
    'Achernar (ja-JP) - F': 'ja-JP-Chirp3-HD-Achernar', 'Aoede (ja-JP) - F': 'ja-JP-Chirp3-HD-Aoede',
    'Autonoe (ja-JP) - F': 'ja-JP-Chirp3-HD-Autonoe', 'Callirrhoe (ja-JP) - F': 'ja-JP-Chirp3-HD-Callirrhoe',
    'Despina (ja-JP) - F': 'ja-JP-Chirp3-HD-Despina', 'Achird (ja-JP) - M': 'ja-JP-Chirp3-HD-Achird',
    'Algenib (ja-JP) - M': 'ja-JP-Chirp3-HD-Algenib', 'Algieba (ja-JP) - M': 'ja-JP-Chirp3-HD-Algieba',
    'Alnilam (ja-JP) - M': 'ja-JP-Chirp3-HD-Alnilam', 'Charon (ja-JP) - M': 'ja-JP-Chirp3-HD-Charon',
  };

  final Map<String, String> _kannadaVoiceOptions = {
    'Achernar (kn-IN) - F': 'kn-IN-Chirp3-HD-Achernar', 'Aoede (kn-IN) - F': 'kn-IN-Chirp3-HD-Aoede',
    'Autonoe (kn-IN) - F': 'kn-IN-Chirp3-HD-Autonoe', 'Callirrhoe (kn-IN) - F': 'kn-IN-Chirp3-HD-Callirrhoe',
    'Despina (kn-IN) - F': 'kn-IN-Chirp3-HD-Despina', 'Achird (kn-IN) - M': 'kn-IN-Chirp3-HD-Achird',
    'Algenib (kn-IN) - M': 'kn-IN-Chirp3-HD-Algenib', 'Algieba (kn-IN) - M': 'kn-IN-Chirp3-HD-Algieba',
    'Alnilam (kn-IN) - M': 'kn-IN-Chirp3-HD-Alnilam', 'Charon (kn-IN) - M': 'kn-IN-Chirp3-HD-Charon',
  };

  final Map<String, String> _koreanVoiceOptions = {
    'Achernar (ko-KR) - F': 'ko-KR-Chirp3-HD-Achernar', 'Aoede (ko-KR) - F': 'ko-KR-Chirp3-HD-Aoede',
    'Autonoe (ko-KR) - F': 'ko-KR-Chirp3-HD-Autonoe', 'Callirrhoe (ko-KR) - F': 'ko-KR-Chirp3-HD-Callirrhoe',
    'Despina (ko-KR) - F': 'ko-KR-Chirp3-HD-Despina', 'Achird (ko-KR) - M': 'ko-KR-Chirp3-HD-Achird',
    'Algenib (ko-KR) - M': 'ko-KR-Chirp3-HD-Algenib', 'Algieba (ko-KR) - M': 'ko-KR-Chirp3-HD-Algieba',
    'Alnilam (ko-KR) - M': 'ko-KR-Chirp3-HD-Alnilam', 'Charon (ko-KR) - M': 'ko-KR-Chirp3-HD-Charon',
  };

  final Map<String, String> _malayalamVoiceOptions = {
    'Achernar (ml-IN) - F': 'ml-IN-Chirp3-HD-Achernar', 'Aoede (ml-IN) - F': 'ml-IN-Chirp3-HD-Aoede',
    'Autonoe (ml-IN) - F': 'ml-IN-Chirp3-HD-Autonoe', 'Callirrhoe (ml-IN) - F': 'ml-IN-Chirp3-HD-Callirrhoe',
    'Despina (ml-IN) - F': 'ml-IN-Chirp3-HD-Despina', 'Achird (ml-IN) - M': 'ml-IN-Chirp3-HD-Achird',
    'Algenib (ml-IN) - M': 'ml-IN-Chirp3-HD-Algenib', 'Algieba (ml-IN) - M': 'ml-IN-Chirp3-HD-Algieba',
    'Alnilam (ml-IN) - M': 'ml-IN-Chirp3-HD-Alnilam', 'Charon (ml-IN) - M': 'ml-IN-Chirp3-HD-Charon',
  };

  final Map<String, String> _mandarinVoiceOptions = {
    'Achernar (cmn-CN) - F': 'cmn-CN-Chirp3-HD-Achernar', 'Aoede (cmn-CN) - F': 'cmn-CN-Chirp3-HD-Aoede',
    'Autonoe (cmn-CN) - F': 'cmn-CN-Chirp3-HD-Autonoe', 'Callirrhoe (cmn-CN) - F': 'cmn-CN-Chirp3-HD-Callirrhoe',
    'Despina (cmn-CN) - F': 'cmn-CN-Chirp3-HD-Despina', 'Achird (cmn-CN) - M': 'cmn-CN-Chirp3-HD-Achird',
    'Algenib (cmn-CN) - M': 'cmn-CN-Chirp3-HD-Algenib', 'Algieba (cmn-CN) - M': 'cmn-CN-Chirp3-HD-Algieba',
    'Alnilam (cmn-CN) - M': 'cmn-CN-Chirp3-HD-Alnilam', 'Charon (cmn-CN) - M': 'cmn-CN-Chirp3-HD-Charon',
  };

  final Map<String, String> _marathiVoiceOptions = {
    'Achernar (mr-IN) - F': 'mr-IN-Chirp3-HD-Achernar', 'Aoede (mr-IN) - F': 'mr-IN-Chirp3-HD-Aoede',
    'Autonoe (mr-IN) - F': 'mr-IN-Chirp3-HD-Autonoe', 'Callirrhoe (mr-IN) - F': 'mr-IN-Chirp3-HD-Callirrhoe',
    'Despina (mr-IN) - F': 'mr-IN-Chirp3-HD-Despina', 'Achird (mr-IN) - M': 'mr-IN-Chirp3-HD-Achird',
    'Algenib (mr-IN) - M': 'mr-IN-Chirp3-HD-Algenib', 'Algieba (mr-IN) - M': 'mr-IN-Chirp3-HD-Algieba',
    'Alnilam (mr-IN) - M': 'mr-IN-Chirp3-HD-Alnilam', 'Charon (mr-IN) - M': 'mr-IN-Chirp3-HD-Charon',
  };

  final Map<String, String> _norwegianVoiceOptions = {
    'Achernar (nb-NO) - F': 'nb-NO-Chirp3-HD-Achernar', 'Aoede (nb-NO) - F': 'nb-NO-Chirp3-HD-Aoede',
    'Autonoe (nb-NO) - F': 'nb-NO-Chirp3-HD-Autonoe', 'Callirrhoe (nb-NO) - F': 'nb-NO-Chirp3-HD-Callirrhoe',
    'Despina (nb-NO) - F': 'nb-NO-Chirp3-HD-Despina', 'Achird (nb-NO) - M': 'nb-NO-Chirp3-HD-Achird',
    'Algenib (nb-NO) - M': 'nb-NO-Chirp3-HD-Algenib', 'Algieba (nb-NO) - M': 'nb-NO-Chirp3-HD-Algieba',
    'Alnilam (nb-NO) - M': 'nb-NO-Chirp3-HD-Alnilam', 'Charon (nb-NO) - M': 'nb-NO-Chirp3-HD-Charon',
  };

  final Map<String, String> _polishVoiceOptions = {
    'Achernar (pl-PL) - F': 'pl-PL-Chirp3-HD-Achernar', 'Aoede (pl-PL) - F': 'pl-PL-Chirp3-HD-Aoede',
    'Autonoe (pl-PL) - F': 'pl-PL-Chirp3-HD-Autonoe', 'Callirrhoe (pl-PL) - F': 'pl-PL-Chirp3-HD-Callirrhoe',
    'Despina (pl-PL) - F': 'pl-PL-Chirp3-HD-Despina', 'Achird (pl-PL) - M': 'pl-PL-Chirp3-HD-Achird',
    'Algenib (pl-PL) - M': 'pl-PL-Chirp3-HD-Algenib', 'Algieba (pl-PL) - M': 'pl-PL-Chirp3-HD-Algieba',
    'Alnilam (pl-PL) - M': 'pl-PL-Chirp3-HD-Alnilam', 'Charon (pl-PL) - M': 'Charon',
  };

  final Map<String, String> _portugueseBrazilVoiceOptions = {
    'Achernar (pt-BR) - F': 'pt-BR-Chirp3-HD-Achernar', 'Aoede (pt-BR) - F': 'pt-BR-Chirp3-HD-Aoede',
    'Autonoe (pt-BR) - F': 'pt-BR-Chirp3-HD-Autonoe', 'Callirrhoe (pt-BR) - F': 'pt-BR-Chirp3-HD-Callirrhoe',
    'Despina (pt-BR) - F': 'pt-BR-Chirp3-HD-Despina', 'Achird (pt-BR) - M': 'pt-BR-Chirp3-HD-Achird',
    'Algenib (pt-BR) - M': 'pt-BR-Chirp3-HD-Algenib', 'Algieba (pt-BR) - M': 'pt-BR-Chirp3-HD-Algieba',
    'Alnilam (pt-BR) - M': 'pt-BR-Chirp3-HD-Alnilam', 'Charon (pt-BR) - M': 'pt-BR-Chirp3-HD-Charon',
  };

  final Map<String, String> _russianVoiceOptions = {
    'Aoede (ru-RU) - F': 'ru-RU-Chirp3-HD-Aoede', 'Kore (ru-RU) - F': 'ru-RU-Chirp3-HD-Kore',
    'Leda (ru-RU) - F': 'ru-RU-Chirp3-HD-Leda', 'Zephyr (ru-RU) - F': 'ru-RU-Chirp3-HD-Zephyr',
    'Achernar (ru-RU) - F': 'ru-RU-Chirp3-HD-Achernar', 'Charon (ru-RU) - M': 'ru-RU-Chirp3-HD-Charon',
    'Fenrir (ru-RU) - M': 'ru-RU-Chirp3-HD-Fenrir', 'Orus (ru-RU) - M': 'ru-RU-Chirp3-HD-Orus',
    'Puck (ru-RU) - M': 'ru-RU-Chirp3-HD-Puck', 'Achird (ru-RU) - M': 'ru-RU-Chirp3-HD-Achird',
  };

  final Map<String, String> _spanishSpainVoiceOptions = {
    'Achernar (es-ES) - F': 'es-ES-Chirp3-HD-Achernar', 'Aoede (es-ES) - F': 'es-ES-Chirp3-HD-Aoede',
    'Autonoe (es-ES) - F': 'es-ES-Chirp3-HD-Autonoe', 'Callirrhoe (es-ES) - F': 'es-ES-Chirp3-HD-Callirrhoe',
    'Despina (es-ES) - F': 'es-ES-Chirp3-HD-Despina', 'Achird (es-ES) - M': 'es-ES-Chirp3-HD-Achird',
    'Algenib (es-ES) - M': 'es-ES-Chirp3-HD-Algenib', 'Algieba (es-ES) - M': 'es-ES-Chirp3-HD-Algieba',
    'Alnilam (es-ES) - M': 'es-ES-Chirp3-HD-Alnilam', 'Charon (es-ES) - M': 'es-ES-Chirp3-HD-Charon',
  };

  final Map<String, String> _spanishUSVoiceOptions = {
    'Achernar (es-US) - F': 'es-US-Chirp3-HD-Achernar', 'Aoede (es-US) - F': 'es-US-Chirp3-HD-Aoede',
    'Autonoe (es-US) - F': 'es-US-Chirp3-HD-Autonoe', 'Callirrhoe (es-US) - F': 'es-US-Chirp3-HD-Callirrhoe',
    'Despina (es-US) - F': 'es-US-Chirp3-HD-Despina', 'Achird (es-US) - M': 'es-US-Chirp3-HD-Achird',
    'Algenib (es-US) - M': 'es-US-Chirp3-HD-Algenib', 'Algieba (es-US) - M': 'es-US-Chirp3-HD-Algieba',
    'Alnilam (es-US) - M': 'es-US-Chirp3-HD-Alnilam', 'Charon (es-US) - M': 'es-US-Chirp3-HD-Charon',
  };

  final Map<String, String> _swedishVoiceOptions = {
    'Achernar (sv-SE) - F': 'sv-SE-Chirp3-HD-Achernar', 'Aoede (sv-SE) - F': 'sv-SE-Chirp3-HD-Aoede',
    'Autonoe (sv-SE) - F': 'sv-SE-Chirp3-HD-Autonoe', 'Callirrhoe (sv-SE) - F': 'sv-SE-Chirp3-HD-Callirrhoe',
    'Despina (sv-SE) - F': 'sv-SE-Chirp3-HD-Despina', 'Achird (sv-SE) - M': 'sv-SE-Chirp3-HD-Achird',
    'Algenib (sv-SE) - M': 'sv-SE-Chirp3-HD-Algenib', 'Algieba (sv-SE) - M': 'sv-SE-Chirp3-HD-Algieba',
    'Alnilam (sv-SE) - M': 'sv-SE-Chirp3-HD-Alnilam', 'Charon (sv-SE) - M': 'sv-SE-Chirp3-HD-Charon',
  };

  final Map<String, String> _tamilVoiceOptions = {
    'Achernar (ta-IN) - F': 'ta-IN-Chirp3-HD-Achernar', 'Aoede (ta-IN) - F': 'ta-IN-Chirp3-HD-Aoede',
    'Autonoe (ta-IN) - F': 'ta-IN-Chirp3-HD-Autonoe', 'Callirrhoe (ta-IN) - F': 'ta-IN-Chirp3-HD-Callirrhoe',
    'Despina (ta-IN) - F': 'ta-IN-Chirp3-HD-Despina', 'Achird (ta-IN) - M': 'ta-IN-Chirp3-HD-Achird',
    'Algenib (ta-IN) - M': 'ta-IN-Chirp3-HD-Algenib', 'Algieba (ta-IN) - M': 'ta-IN-Chirp3-HD-Algieba',
    'Alnilam (ta-IN) - M': 'ta-IN-Chirp3-HD-Alnilam', 'Charon (ta-IN) - M': 'ta-IN-Chirp3-HD-Charon',
  };

  final Map<String, String> _teluguVoiceOptions = {
    'Achernar (te-IN) - F': 'te-IN-Chirp3-HD-Achernar', 'Aoede (te-IN) - F': 'te-IN-Chirp3-HD-Aoede',
    'Autonoe (te-IN) - F': 'te-IN-Chirp3-HD-Autonoe', 'Callirrhoe (te-IN) - F': 'te-IN-Chirp3-HD-Callirrhoe',
    'Despina (te-IN) - F': 'te-IN-Chirp3-HD-Despina', 'Achird (te-IN) - M': 'te-IN-Chirp3-HD-Achird',
    'Algenib (te-IN) - M': 'te-IN-Chirp3-HD-Algenib', 'Algieba (te-IN) - M': 'te-IN-Chirp3-HD-Algieba',
    'Alnilam (te-IN) - M': 'te-IN-Chirp3-HD-Alnilam', 'Charon (te-IN) - M': 'te-IN-Chirp3-HD-Charon',
  };

  final Map<String, String> _thaiVoiceOptions = {
    'Achernar (th-TH) - F': 'th-TH-Chirp3-HD-Achernar', 'Aoede (th-TH) - F': 'th-TH-Chirp3-HD-Aoede',
    'Autonoe (th-TH) - F': 'th-TH-Chirp3-HD-Autonoe', 'Callirrhoe (th-TH) - F': 'th-TH-Chirp3-HD-Callirrhoe',
    'Despina (th-TH) - F': 'th-TH-Chirp3-HD-Despina', 'Achird (th-TH) - M': 'th-TH-Chirp3-HD-Achird',
    'Algenib (th-TH) - M': 'th-TH-Chirp3-HD-Algenib', 'Algieba (th-TH) - M': 'th-TH-Chirp3-HD-Algieba',
    'Alnilam (th-TH) - M': 'th-TH-Chirp3-HD-Alnilam', 'Charon (th-TH) - M': 'th-TH-Chirp3-HD-Charon',
  };

  final Map<String, String> _turkishVoiceOptions = {
    'Achernar (tr-TR) - F': 'tr-TR-Chirp3-HD-Achernar', 'Aoede (tr-TR) - F': 'tr-TR-Chirp3-HD-Aoede',
    'Autonoe (tr-TR) - F': 'tr-TR-Chirp3-HD-Autonoe', 'Callirrhoe (tr-TR) - F': 'tr-TR-Chirp3-HD-Callirrhoe',
    'Despina (tr-TR) - F': 'tr-TR-Chirp3-HD-Despina', 'Achird (tr-TR) - M': 'tr-TR-Chirp3-HD-Achird',
    'Algenib (tr-TR) - M': 'tr-TR-Chirp3-HD-Algenib', 'Algieba (tr-TR) - M': 'tr-TR-Chirp3-HD-Algieba',
    'Alnilam (tr-TR) - M': 'tr-TR-Chirp3-HD-Alnilam', 'Charon (tr-TR) - M': 'tr-TR-Chirp3-HD-Charon',
  };

  final Map<String, String> _ukrainianVoiceOptions = {
    'Achernar (uk-UA) - F': 'uk-UA-Chirp3-HD-Achernar', 'Aoede (uk-UA) - F': 'uk-UA-Chirp3-HD-Aoede',
    'Autonoe (uk-UA) - F': 'uk-UA-Chirp3-HD-Autonoe', 'Callirrhoe (uk-UA) - F': 'uk-UA-Chirp3-HD-Callirrhoe',
    'Despina (uk-UA) - F': 'uk-UA-Chirp3-HD-Despina', 'Achird (uk-UA) - M': 'uk-UA-Chirp3-HD-Achird',
    'Algenib (uk-UA) - M': 'uk-UA-Chirp3-HD-Algenib', 'Algieba (uk-UA) - M': 'uk-UA-Chirp3-HD-Algieba',
    'Alnilam (uk-UA) - M': 'uk-UA-Chirp3-HD-Alnilam', 'Charon (uk-UA) - M': 'uk-UA-Chirp3-HD-Charon',
  };

  final Map<String, String> _urduIndiaVoiceOptions = {
    'Achernar (ur-IN) - F': 'ur-IN-Chirp3-HD-Achernar', 'Aoede (ur-IN) - F': 'ur-IN-Chirp3-HD-Aoede',
    'Autonoe (ur-IN) - F': 'ur-IN-Chirp3-HD-Autonoe', 'Callirrhoe (ur-IN) - F': 'ur-IN-Chirp3-HD-Callirrhoe',
    'Despina (ur-IN) - F': 'ur-IN-Chirp3-HD-Despina', 'Achird (ur-IN) - M': 'ur-IN-Chirp3-HD-Achird',
    'Algenib (ur-IN) - M': 'ur-IN-Chirp3-HD-Algenib', 'Algieba (ur-IN) - M': 'ur-IN-Chirp3-HD-Algieba',
    'Alnilam (ur-IN) - M': 'ur-IN-Chirp3-HD-Alnilam', 'Charon (ur-IN) - M': 'ur-IN-Chirp3-HD-Charon',
  };

  final Map<String, String> _vietnameseVoiceOptions = {
    'Achernar (vi-VN) - F': 'vi-VN-Chirp3-HD-Achernar', 'Aoede (vi-VN) - F': 'vi-VN-Chirp3-HD-Aoede',
    'Autonoe (vi-VN) - F': 'vi-VN-Chirp3-HD-Autonoe', 'Callirrhoe (vi-VN) - F': 'vi-VN-Chirp3-HD-Callirrhoe',
    'Despina (vi-VN) - F': 'vi-VN-Chirp3-HD-Despina', 'Achird (vi-VN) - M': 'vi-VN-Chirp3-HD-Achird',
    'Algenib (vi-VN) - M': 'vi-VN-Chirp3-HD-Algenib', 'Algieba (vi-VN) - M': 'vi-VN-Chirp3-HD-Algieba',
    'Alnilam (vi-VN) - M': 'vi-VN-Chirp3-HD-Alnilam', 'Charon (vi-VN) - M': 'vi-VN-Chirp3-HD-Charon',
  };

  final List<String> _languageList = [
    'Indonesian', 'English (US)', 'English (UK)', 'English (Australia)',
    'English (India)', 'Arabic', 'Bengali (India)', 'Danish',
    'Dutch (Netherlands)', 'Dutch (Belgium)', 'Finnish', 'French (France)',
    'French (Canada)', 'German', 'Gujarati', 'Hindi', 'Italian', 'Japanese',
    'Kannada', 'Korean', 'Malayalam', 'Mandarin Chinese', 'Marathi',
    'Norwegian', 'Polish', 'Portuguese (Brazil)', 'Russian', 'Spanish (Spain)',
    'Spanish (US)', 'Swedish', 'Tamil', 'Telugu', 'Thai', 'Turkish',
    'Ukrainian', 'Urdu', 'Vietnamese',
  ];

  Map<String, String> get _currentVoiceOptions {
    switch (_selectedLanguage) {
      case 'Indonesian': return _indonesianVoiceOptions;
      case 'English (US)': return _englishVoiceOptions;
      case 'English (UK)': return _englishUKVoiceOptions;
      case 'English (Australia)': return _englishAustraliaVoiceOptions;
      case 'English (India)': return _englishIndiaVoiceOptions;
      case 'Arabic': return _arabicVoiceOptions;
      case 'Bengali (India)': return _bengaliVoiceOptions;
      case 'Danish': return _danishVoiceOptions;
      case 'Dutch (Netherlands)': return _dutchNetherlandsVoiceOptions;
      case 'Dutch (Belgium)': return _dutchBelgiumVoiceOptions;
      case 'Finnish': return _finnishVoiceOptions;
      case 'French (France)': return _frenchFranceVoiceOptions;
      case 'French (Canada)': return _frenchCanadaVoiceOptions;
      case 'German': return _germanVoiceOptions;
      case 'Gujarati': return _gujaratiVoiceOptions;
      case 'Hindi': return _hindiVoiceOptions;
      case 'Italian': return _italianVoiceOptions;
      case 'Japanese': return _japaneseVoiceOptions;
      case 'Kannada': return _kannadaVoiceOptions;
      case 'Korean': return _koreanVoiceOptions;
      case 'Malayalam': return _malayalamVoiceOptions;
      case 'Mandarin Chinese': return _mandarinVoiceOptions;
      case 'Marathi': return _marathiVoiceOptions;
      case 'Norwegian': return _norwegianVoiceOptions;
      case 'Polish': return _polishVoiceOptions;
      case 'Portuguese (Brazil)': return _portugueseBrazilVoiceOptions;
      case 'Russian': return _russianVoiceOptions;
      case 'Spanish (Spain)': return _spanishSpainVoiceOptions;
      case 'Spanish (US)': return _spanishUSVoiceOptions;
      case 'Swedish': return _swedishVoiceOptions;
      case 'Tamil': return _tamilVoiceOptions;
      case 'Telugu': return _teluguVoiceOptions;
      case 'Thai': return _thaiVoiceOptions;
      case 'Turkish': return _turkishVoiceOptions;
      case 'Ukrainian': return _ukrainianVoiceOptions;
      case 'Urdu': return _urduIndiaVoiceOptions;
      case 'Vietnamese': return _vietnameseVoiceOptions;
      default: return _indonesianVoiceOptions;
    }
  }
//......................................................//

//No ke-3.........................................................//
//LIFECYCLE, IMAGE PICKER, NETWORK CLIENT & SUBMIT LOGIC..........//
  @override
  void initState() {
    super.initState();
    if (widget.initialScript.isNotEmpty) {
      _scriptController.text = widget.initialScript;
    }

    _descriptionController.text = "Created @ majiku.net\nAuto Video Content & Film Maker";

    _scriptController.addListener(() {
      setState(() {});
    });

    // --- [LOG AKTIVITAS FITUR: KUNJUNGAN HALAMAN (VISIT)] ---
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(firestoreServiceProvider).logFeatureActivity(
          featureKey: 'auto_marketing_video',
          eventType: 'visit',
        );
      }
    });
    // --------------------------------------------------------
  }

  @override
  void dispose() {
    _scriptController.dispose();
    _descriptionController.dispose(); 
    _productTypeController.dispose();
    _brandController.dispose();
    _productDescController.dispose();
    _aiLanguageController.dispose();
    super.dispose();
  }

  // DUAL IMAGE PICKER RAMAH WEB & MOBILE
  Future<void> _pickProductImage() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (pickedFile != null) setState(() => _productImage = pickedFile);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error picking product image: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _pickLogoImage() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (pickedFile != null) setState(() => _logoImage = pickedFile);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error picking logo image: $e'), backgroundColor: Colors.red));
    }
  }

  void _removeProductImage() => setState(() => _productImage = null);
  void _removeLogoImage() => setState(() => _logoImage = null);

  int _calculateEstimatedScenes(String text) {
    final String cleanText = text.trim();
    if (cleanText.isEmpty) return 0;
    const int divisor = 100;
    return (cleanText.length / divisor).ceil();
  }

  // GENERATOR NARASI AI: ROBUST CLIENT DENGAN AUTO-RETRY SAAT COLD START
  Future<void> _generateNarrationWithGemini() async {
    final isIndo = ref.read(appLanguageProvider).languageCode == 'id';

    if (_productTypeController.text.trim().isEmpty || _brandController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isIndo
                ? 'Mohon isi Jenis Produk dan Merk Dagang terlebih dahulu!'
                : 'Please fill in Product Type and Brand Name first!',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isGeneratingNarration = true);

    try {
      const String cloudFunctionUrl = "https://asia-southeast2-majiku-5b07e.cloudfunctions.net/generateMarketingScriptWorker";
      
      final body = jsonEncode({
        "productType": _productTypeController.text.trim(),
        "brandName": _brandController.text.trim(),
        "productDesc": _productDescController.text.trim(),
        "narrationLength": _narrationLength,
        "targetLanguage": _aiLanguageController.text.trim(),
      });

      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Connection': 'close',
      };

      http.Response? response;
      int attempts = 0;
      const int maxAttempts = 2;

      // Auto-retry 1x untuk mengatasi Cold Start Cloud Functions
      while (attempts < maxAttempts) {
        attempts++;
        final client = http.Client();
        try {
          response = await client.post(
            Uri.parse(cloudFunctionUrl),
            headers: headers,
            body: body,
          ).timeout(const Duration(seconds: 120));
          break;
        } on io.SocketException catch (_) {
          if (attempts < maxAttempts) {
            await Future.delayed(const Duration(milliseconds: 1000));
            continue;
          }
          rethrow;
        } on http.ClientException catch (ce) {
          final isReset = ce.message.toLowerCase().contains('connection reset') ||
              ce.message.toLowerCase().contains('socketexception');
          if (isReset && attempts < maxAttempts) {
            await Future.delayed(const Duration(milliseconds: 1000));
            continue;
          }
          rethrow;
        } finally {
          client.close();
        }
      }

      if (response != null && response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['script'] != null) {
          String cleanScript = data['script'].toString().trim();
          
          cleanScript = cleanScript.replaceAll(RegExp(r'\r\n'), '\n');
          cleanScript = cleanScript.replaceAll(RegExp(r'\n{3,}'), '\n\n');
          cleanScript = cleanScript.replaceAll(RegExp(r' {2,}'), ' ');
          
          if (cleanScript.length > 5000) {
            cleanScript = cleanScript.substring(0, 5000);
          }

          setState(() {
            _scriptController.text = cleanScript;
          });
        }
      } else {
        throw Exception("Server Error: ${response?.statusCode}");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isIndo ? 'Gagal membuat narasi: $e' : 'Failed to generate narration: $e',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingNarration = false);
    }
  }

  Future<void> _submitData() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      final firestoreService = ref.read(firestoreMarkettingVideoServiceProvider);
      final isIndo = ref.read(appLanguageProvider).languageCode == 'id';
      
      try {
        final io.File? safeProductFile = kIsWeb ? null : (_productImage != null ? io.File(_productImage!.path) : null);
        final io.File? safeLogoFile = kIsWeb ? null : (_logoImage != null ? io.File(_logoImage!.path) : null);

        final String projectTitle = "${_brandController.text} - ${_productTypeController.text}";

        final String? newProjectId = await firestoreService.addProject(
          title: projectTitle,
          rawScript: _scriptController.text,
          imageStyle: _selectedStyle,
          aspectRatio: _selectedAspectRatio,
          language: _selectedLanguage,
          voice: _selectedVoice,
          showSubtitles: _showSubtitles,
          resolution: _selectedResolution, 
          costLevel: _selectedCostLevel, 
          description: _showDescription ? _descriptionController.text.trim() : "", 
          
          productType: _productTypeController.text.trim(),
          brandName: _brandController.text.trim(),
          productDesc: _productDescController.text.trim(),
          
          productImageFile: safeProductFile, 
          logoImageFile: safeLogoFile,
          
          productImageXFile: _productImage,
          logoImageXFile: _logoImage,
          
          descriptionTiming: _showDescription ? _descriptionTiming : "start",
        );

        if (mounted) {
          if (newProjectId != null && newProjectId.isNotEmpty) {
            ref.read(firestoreServiceProvider).logFeatureActivity(
              featureKey: 'auto_marketing_video',
              eventType: 'conversion',
            );

            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => ProjectLoadingMarkettingVideoScreen(
                  projectId: newProjectId,
                ),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(isIndo ? 'Error: Gagal membuat ID proyek.' : 'Error: Failed to create project ID.'),
                backgroundColor: Colors.red),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(isIndo ? 'Terjadi kesalahan saat menambah proyek: $e' : 'Error adding project: $e'),
                backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }
//................................................................//

//No ke-4.........................................................//
//BUILD UI & FORM LAYOUT (RESPONSIVE AI SCRIPT GENERATOR).........//
  @override
  Widget build(BuildContext context) {
    final currentLocale = ref.watch(appLanguageProvider);
    final isIndo = currentLocale.languageCode == 'id';
    String t(String en, String id) => isIndo ? id : en;

    final currentVoiceOptions = _currentVoiceOptions;

    final userAsync = ref.watch(firestoreUserProvider);
    final configAsync = ref.watch(appConfigProvider);

    final int estimatedScenes = _calculateEstimatedScenes(_scriptController.text);
    
    int currentBalance = 0;
    int costPerScene = 0;
    bool configReady = false;
    bool userReady = false;

    userAsync.whenData((user) {
      currentBalance = user.tokenBalance;
      userReady = true;
    });

    configAsync.whenData((config) {
      final markettingCosts = config.costs.markettingVideoCosts;
      if (_selectedCostLevel == 'High') {
        costPerScene = _selectedResolution == '1080p'
            ? markettingCosts.highPerSegment1080p
            : markettingCosts.highPerSegment720p;
      } else {
        costPerScene = _selectedResolution == '1080p'
            ? markettingCosts.standardPerSegment1080p
            : markettingCosts.standardPerSegment720p;
      }
      configReady = true;
    });

    final int requiredTokens = estimatedScenes * costPerScene;
    final bool hasSufficientFunds = currentBalance >= requiredTokens;
    final bool hasInput = estimatedScenes > 0;
    
    final bool isOutOfTokens = hasInput && !hasSufficientFunds;
    final bool canSubmit = hasInput && hasSufficientFunds && !_isLoading && userReady && configReady;

    return Theme(
      data: AppTheme.darkTheme,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Marketing Video'), 
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 20.0),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isOutOfTokens ? Colors.redAccent : Colors.white24,
                      width: 1
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.token, 
                        size: 16, 
                        color: isOutOfTokens ? Colors.redAccent : Colors.amber
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "$requiredTokens / $currentBalance", 
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isOutOfTokens ? Colors.redAccent : Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: _productTypeController,
                                maxLength: 40,
                                decoration: InputDecoration(
                                  labelText: t('Product Type', 'Jenis Produk'),
                                  hintText: t('e.g., Jeans, Skincare', 'Cth: Celana Jean, Skincare'),
                                ),
                                validator: (val) => val == null || val.trim().isEmpty ? t('Required', 'Wajib diisi') : null,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 2,
                              child: _buildImagePickerBox(
                                image: _productImage,
                                onTap: _pickProductImage,
                                onRemove: _removeProductImage,
                                label: t('Product\nPhoto', 'Foto\nProduk'),
                                icon: Icons.shopping_bag_outlined,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: _brandController,
                                maxLength: 40,
                                decoration: InputDecoration(
                                  labelText: t('Brand Name', 'Merk Dagang'),
                                  hintText: t('e.g., Cool Jeans', 'Cth: Cool Jean'),
                                ),
                                validator: (val) => val == null || val.trim().isEmpty ? t('Required', 'Wajib diisi') : null,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 2,
                              child: _buildImagePickerBox(
                                image: _logoImage,
                                onTap: _pickLogoImage,
                                onRemove: _removeLogoImage,
                                label: t('Logo\n(Optional)', 'Logo\n(Opsional)'),
                                icon: Icons.branding_watermark_outlined,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _productDescController,
                          maxLength: 200,
                          maxLines: 2,
                          decoration: InputDecoration(
                            labelText: t('Product Details (USP)', 'Deskripsi Detail Produk (Keunggulan)'),
                            hintText: t('Explain what makes it special...', 'Jelaskan kelebihan produk ini secara singkat...'),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // KOTAK GENERATOR SKRIP AI (TATA LETAK RESPONSIF & BEBAS SESAK)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blueAccent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                t('Don\'t have a script? Let AI write it for you!', 'Belum punya skrip? Biar AI yang buatkan!'),
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent),
                              ),
                              const SizedBox(height: 14),

                              // BARIS 1: BAHASA NARASI (KIRI) & CHARACTERS LENGTH (KANAN)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: TextFormField(
                                      controller: _aiLanguageController,
                                      decoration: InputDecoration(
                                        labelText: t('Narration Language (Optional)', 'Bahasa Narasi (Opsional)'),
                                        hintText: t(
                                          'e.g., English, Spanish...',
                                          'Cth: Inggris, Jawa...',
                                        ),
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    flex: 2,
                                    child: DropdownButtonFormField<int>(
                                      value: _narrationLength,
                                      isExpanded: true,
                                      decoration: InputDecoration(
                                        labelText: t('Characters Length', 'Panjang Karakter'),
                                        isDense: true,
                                      ),
                                      items: const [
                                        DropdownMenuItem(value: 500, child: Text('500')),
                                        DropdownMenuItem(value: 1000, child: Text('1000')),
                                        DropdownMenuItem(value: 1500, child: Text('1500')),
                                        DropdownMenuItem(value: 2000, child: Text('2000')),
                                      ],
                                      onChanged: (val) {
                                        if (val != null) setState(() => _narrationLength = val);
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),

                              // BARIS 2: TOMBOL GENERATE SCRIPT (MANDIRI 1 BARIS PENUH)
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blueAccent,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                onPressed: _isGeneratingNarration ? null : _generateNarrationWithGemini,
                                icon: _isGeneratingNarration
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Icon(Icons.auto_awesome, size: 20),
                                label: Text(
                                  t('Generate Script', 'Buat Narasi'),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        TextFormField(
                          controller: _scriptController,
                          maxLines: 10,
                          maxLength: 5000, 
                          decoration: InputDecoration(
                            labelText: t('Paste or send your narration here..', 'Paste atau kirim narasimu kesini'),
                            hintText: t('Explain your product effectively...', 'Jelaskan produkmu secara efektif...'),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return t('Please enter a Narration for your video.', 'Mohon isi naskah narasi.');
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),

                        SwitchListTile(
                          title: Text(
                            t('Description Overlay', 'Overlay Deskripsi'),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            t('Show a descriptive text overlay on the video', 'Tampilkan teks deskripsi overlay di atas video'),
                            style: const TextStyle(fontSize: 12, color: Colors.white54),
                          ),
                          value: _showDescription,
                          activeColor: Colors.blue,
                          contentPadding: EdgeInsets.zero,
                          onChanged: (bool value) {
                            setState(() => _showDescription = value);
                          },
                        ),
                        if (_showDescription) ...[
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _descriptionController,
                            maxLength: 80,
                            maxLines: 2,
                            decoration: InputDecoration(
                              labelText: t('Description Text', 'Teks Deskripsi'),
                              hintText: t('Enter the description to display...', 'Masukkan deskripsi yang ingin ditampilkan...'),
                            ),
                            validator: (value) {
                              if (_showDescription && (value == null || value.trim().isEmpty)) {
                                return t('Please enter a description.', 'Mohon isi deskripsi.');
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.grey[900],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t('Display Timing', 'Waktu Tampilan'),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white70),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: RadioListTile<String>(
                                        title: Text(t('Start of Video', 'Tampil di Awal'), style: const TextStyle(fontSize: 13)),
                                        subtitle: Text(t('Show from 3s to 10s', 'Muncul 3s s.d 10s'), style: const TextStyle(fontSize: 11, color: Colors.white38)),
                                        value: 'start',
                                        groupValue: _descriptionTiming,
                                        contentPadding: EdgeInsets.zero,
                                        activeColor: Colors.blue,
                                        onChanged: (val) {
                                          if (val != null) setState(() => _descriptionTiming = val);
                                        },
                                      ),
                                    ),
                                    Expanded(
                                      child: RadioListTile<String>(
                                        title: Text(t('End of Video', 'Tampil di Akhir'), style: const TextStyle(fontSize: 13)),
                                        subtitle: Text(t('Show from H-10s to H-3s', 'Muncul H-10s s.d H-3s'), style: const TextStyle(fontSize: 11, color: Colors.white38)),
                                        value: 'end',
                                        groupValue: _descriptionTiming,
                                        contentPadding: EdgeInsets.zero,
                                        activeColor: Colors.blue,
                                        onChanged: (val) {
                                          if (val != null) setState(() => _descriptionTiming = val);
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),

                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _selectedStyle,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  labelText: t('Visual Style', 'Gaya Visual'),
                                ),
                                items: ['Realistic', 'Cartoon_3D', 'Cartoon_2D']
                                    .map((style) => DropdownMenuItem(
                                          value: style,
                                          child: Text(style.replaceAll('_', ' ')),
                                        ))
                                    .toList(),
                                onChanged: (value) {
                                  if (value != null) setState(() => _selectedStyle = value);
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _selectedAspectRatio,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  labelText: t('Aspect Ratio', 'Rasio Aspek'),
                                ),
                                items: {
                                  '${t('Portrait', 'Potret')} (9:16)': '9:16', 
                                  '${t('Landscape', 'Lanskap')} (16:9)': '16:9',
                                  '${t('Square', 'Persegi')} (1:1)': '1:1',
                                }
                                    .entries
                                    .map((entry) => DropdownMenuItem(
                                          value: entry.value,
                                          child: Text(entry.key, overflow: TextOverflow.ellipsis),
                                        ))
                                    .toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() => _selectedAspectRatio = value);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _selectedLanguage,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  labelText: t('Voice Language', 'Bahasa Suara'),
                                ),
                                items: _languageList
                                    .map((lang) => DropdownMenuItem(
                                          value: lang,
                                          child: Text(
                                            lang, 
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ))
                                    .toList(),
                                onChanged: (value) {
                                  if (value != null && value != _selectedLanguage) {
                                    setState(() {
                                      _selectedLanguage = value;
                                      final newOptions = _currentVoiceOptions; 
                                      if (newOptions.isNotEmpty) {
                                        _selectedVoice = newOptions.values.first;
                                      }
                                    });
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _selectedVoice,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  labelText: t('Voice Type', 'Tipe Suara') + ' (${currentVoiceOptions.length})',
                                ),
                                items: currentVoiceOptions.entries.map((entry) {
                                  return DropdownMenuItem<String>(
                                    value: entry.value,
                                    child: Text(entry.key, overflow: TextOverflow.ellipsis),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() => _selectedVoice = value);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _selectedResolution,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  labelText: t('Resolution', 'Resolusi'),
                                ),
                                items: const [
                                  DropdownMenuItem(value: '720p', child: Text('720p (HD)')),
                                  DropdownMenuItem(value: '1080p', child: Text('1080p (FHD)')),
                                ],
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() => _selectedResolution = value);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _selectedCostLevel,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  labelText: t('Quality Tier', 'Kategori Kualitas'),
                                ),
                                items: [
                                  DropdownMenuItem(
                                    value: 'Standard', 
                                    child: Text(
                                      t('Standard', 'Standar'),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 'High', 
                                    child: Text(
                                      t('High', 'Tinggi'),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() => _selectedCostLevel = value);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),

                        ElevatedButton.icon(
                          onPressed: canSubmit ? _submitData : null,
                          icon: _isLoading
                              ? const SizedBox.shrink()
                              : const Icon(Icons.auto_awesome),
                          label: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 3,
                                    ),
                                  )
                                : Text(t('PROCESS VIDEO', 'PROSES VIDEO')),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.grey[800],
                            disabledForegroundColor: Colors.grey[500],
                          ),
                        ),
                        
                        if (isOutOfTokens)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Center(
                              child: Text(
                                t(
                                  "Insufficient balance. You need ${requiredTokens - currentBalance} more tokens.",
                                  "Saldo tidak cukup. Anda butuh ${requiredTokens - currentBalance} token lagi."
                                ),
                                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              
              AnimatedPositioned(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutBack,
                top: isOutOfTokens ? 16.0 : -100.0, 
                left: 16.0,
                right: 16.0,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: isOutOfTokens ? 1.0 : 0.0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade600, 
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black45, 
                          blurRadius: 10, 
                          offset: Offset(0, 4)
                        )
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, color: Colors.white, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            t(
                              "Out of tokens. Upgrade or add more via the dashboard!",
                              "Token habis. Upgrade atau tambah lagi via dasbor!"
                            ),
                            style: const TextStyle(
                              color: Colors.white, 
                              fontWeight: FontWeight.bold, 
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // WIDGET HELPER: DUAL IMAGE PICKER BOX
  Widget _buildImagePickerBox({
    required XFile? image, 
    required VoidCallback onTap, 
    required VoidCallback onRemove, 
    required String label, 
    required IconData icon
  }) {
    bool isHovered = false; 

    return StatefulBuilder(
      builder: (context, setStateLocal) {
        return MouseRegion(
          onEnter: (_) => setStateLocal(() => isHovered = true),
          onExit: (_) => setStateLocal(() => isHovered = false),
          cursor: image == null ? SystemMouseCursors.click : SystemMouseCursors.basic,
          child: GestureDetector(
            onTap: image == null ? onTap : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              height: 90,
              width: double.infinity,
              decoration: BoxDecoration(
                color: isHovered && image == null ? Colors.blueAccent.withOpacity(0.05) : Colors.grey[900],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isHovered && image == null ? Colors.blueAccent : Colors.white24, 
                  width: isHovered && image == null ? 1.5 : 1, 
                  style: BorderStyle.solid
                ),
                boxShadow: isHovered && image == null
                    ? [
                        BoxShadow(
                          color: Colors.blueAccent.withOpacity(0.3),
                          blurRadius: 8,
                          spreadRadius: 1,
                        )
                      ]
                    : [],
              ),
              child: image != null
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(11), 
                          child: kIsWeb
                              ? Image.network(image.path, fit: BoxFit.cover)
                              : Image.file(io.File(image.path), fit: BoxFit.cover),
                        ),
                        Positioned(
                          top: 4, right: 4,
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              onTap: onRemove,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(color: Colors.black87, shape: BoxShape.circle),
                                child: const Icon(Icons.close, color: Colors.white, size: 16),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon, size: 28, color: isHovered ? Colors.blueAccent : Colors.white54),
                        const SizedBox(height: 6),
                        Text(
                          label, 
                          textAlign: TextAlign.center, 
                          style: TextStyle(
                            color: isHovered ? Colors.blueAccent : Colors.white54, 
                            fontSize: 12, 
                            fontWeight: isHovered ? FontWeight.w600 : FontWeight.normal,
                          )
                        ),
                      ],
                    ),
            ),
          ),
        );
      }
    );
  }
}
//................................................................//