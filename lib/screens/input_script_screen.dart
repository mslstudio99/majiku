//................................................................//
// NAMA FILE: INPUT_SCRIPT_SCREEN.DART                            //
// PATH: LIB/SCREENS/INPUT_SCRIPT_SCREEN.DART                     //
//................................................................//

//No ke-1.........................................................//
// IMPORT DEPENDENSI & SETUP AWAL                                 //
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/firestore_service.dart';

// --- IMPOR PROVIDER & TEMA ---
import '../providers/visual_settings_provider.dart';
import '../providers/user_provider.dart';
import '../providers/config_provider.dart'; 
import 'project_loading_screen.dart';
import '../theme/app_theme.dart';

/*
KATEGORI_FITUR_UTAMA NO_URUT_05 (REVISI PARIPURNA - UI/UX REFINEMENT)
Tujuan:
- [FIX UI] Menggabungkan Aspect Ratio dan Visual Style ke dalam 1 baris.
- [FIX UX] Menstandarkan ukuran font dropdown bahasa agar konsisten.
- [NEW FEATURE] Pop up animasi peringatan token habis bergaya modern (Hijau/Putih).
- [ANTI-REGRESI] Menjaga seluruh fungsi token, voice, dan database.
- [NEW FEATURE] Toggle penggunaan Asset Overlay Effects untuk optimasi render.
*/
//................................................................//

//No ke-2.........................................................//
// SETUP STATE DAN MAPS OPSI SUARA (VOICES)                       //
class InputScriptScreen extends ConsumerStatefulWidget {
  final String initialTitle;
  final String initialScript;

  const InputScriptScreen({
    super.key,
    this.initialTitle = '',
    this.initialScript = '',
  });

  @override
  ConsumerState<InputScriptScreen> createState() => _InputScriptScreenState();
}

class _InputScriptScreenState extends ConsumerState<InputScriptScreen> {
  final _scriptController = TextEditingController();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  String _selectedStyle = 'Realistic';
  String _selectedAspectRatio = '9:16';
  
  // [PENYESUAIAN DEFAULT]: Bahasa default diubah ke English (US)
  String _selectedLanguage = 'English (US)'; 
  static const String _defaultEnglishVoice = 'en-US-Chirp3-HD-Alnilam';
  String _selectedVoice = _defaultEnglishVoice;
  bool _isLoading = false;
  
  bool _showSubtitles = false; 

  bool _useAssetOverlayEffects = false; 

  // [BARU]: State Tombol ON/OFF Project Title Overlay (Secara Default ON)
  bool _showTitle = true;

  // State Tombol ON/OFF Project Description Overlay (Secara Default OFF)
  bool _showDescription = false;
  
  // State Pilihan Level Biaya & Kualitas Model (Standard vs Good) - Default Standard
  String _selectedCostLevel = 'Standard';

  // ==========================================
  // OPSI SUARA (LENGKAP)
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
    'Autonoe (EN) - F': 'en-US-Chirp3-HD-Autonoe', 'Callirrhoe (EN) - F': 'en-US-Chirp3-HD-Callirrhoe',
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
    'Despina (nl-NL) - F': 'nl-BE-Chirp3-HD-Despina', 'Achird (nl-NL) - M': 'nl-NL-Chirp3-HD-Achird',
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
    'Alnilam (fi-FI) - M': 'fi-FI-Chirp3-HD-Alnilam', 'Charon (fi-FI) - M': 'fi-FI-Chirp3-HD-Charon',
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
    'Alnilam (pl-PL) - M': 'pl-PL-Chirp3-HD-Alnilam', 'Charon (pl-PL) - M': 'pl-PL-Chirp3-HD-Charon',
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
    'English (US)', 'Indonesian', 'English (UK)', 'English (Australia)',
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
      case 'English (US)': return _englishVoiceOptions;
      case 'Indonesian': return _indonesianVoiceOptions;
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
      default: return _englishVoiceOptions;
    }
  }
//................................................................//

//No ke-3.........................................................//
// INIT, DISPOSE, & LOGIC (SUBMIT)                                //
  @override
  void initState() {
    super.initState();
    if (widget.initialTitle.isNotEmpty) {
      _titleController.text = widget.initialTitle;
    }
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
          featureKey: 'auto_naramotion',
          eventType: 'visit',
        );
      }
    });
    // --------------------------------------------------------
  }

  @override
  void dispose() {
    _scriptController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitData() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      final userAsync = ref.read(firestoreUserProvider);
      final configAsync = ref.read(appConfigProvider);
      final currentLocale = ref.read(appLanguageProvider);
      final isIndo = currentLocale.languageCode == 'id';
      String t(String en, String id) => isIndo ? id : en;

      if (userAsync.value == null || configAsync.value == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t('System not ready. Failed to load wallet configuration.', 'Sistem belum siap. Gagal memuat data dompet.')), 
            backgroundColor: Colors.red
          ),
        );
        setState(() => _isLoading = false);
        return;
      }

      final int currentBalance = userAsync.value!.tokenBalance;
      
      // Biaya dinamis: Good (180 TM) vs Standard (120 TM) dari Firestore Config
      final int costPerScene = _selectedCostLevel == 'Good'
          ? (configAsync.value!.costs.motionGoodPerScene)
          : (configAsync.value!.costs.motionPerScene);

      // --- LOGIKA ESTIMASI SCENE (1 KALIMAT PER SEGMEN) ---
      final String text = _scriptController.text.trim();
      final int textLength = text.length;

      int sentenceCount = 0;
      if (textLength > 0) {
        List<String> sentences = text.split(RegExp(r'[.!?]+'));
        sentenceCount = sentences.where((s) => s.trim().isNotEmpty).length;
      }

      int estimatedScenes = sentenceCount;
      const int charRatio = 100;
      int estimatedByLength = (textLength / charRatio).ceil();
      
      if (estimatedByLength > estimatedScenes) {
        estimatedScenes = estimatedByLength;
      }
      if (estimatedScenes == 0 && textLength > 0) estimatedScenes = 1;
      // -----------------------------------------------------

      final int requiredTokens = estimatedScenes * costPerScene;

      if (currentBalance < requiredTokens) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t(
              'Processing failed: Insufficient balance. Estimated need: $requiredTokens tokens, available: $currentBalance.',
              'Gagal diproses: Saldo tidak cukup. Estimasi butuh $requiredTokens token, tersedia $currentBalance.'
            )),
            backgroundColor: Colors.redAccent,
          ),
        );
        setState(() => _isLoading = false);
        return; 
      }

      // Jika toggle _showTitle false, gunakan fallback judul proyek default
      final String effectiveTitle = _showTitle 
          ? _titleController.text.trim() 
          : (_titleController.text.trim().isNotEmpty 
              ? _titleController.text.trim() 
              : 'Naramotion Video');

      // Jika toggle _showDescription bernilai false, kirim deskripsi kosong ""
      final String effectiveDescription = _showDescription 
          ? _descriptionController.text.trim() 
          : '';

      final firestoreService = ref.read(firestoreServiceProvider);
      try {
        final String? newProjectId = await firestoreService.addProject(
          title: effectiveTitle,
          rawScript: _scriptController.text,
          imageStyle: _selectedStyle,
          aspectRatio: _selectedAspectRatio,
          language: _selectedLanguage,
          voice: _selectedVoice,
          showSubtitles: _showSubtitles,
          useAssetOverlayEffects: _useAssetOverlayEffects, 
          description: effectiveDescription,
          showTitle: _showTitle, // [BARU]: Meneruskan status toggle ON/OFF Judul
          showDescription: _showDescription, 
          costLevel: _selectedCostLevel,
          sentencesPerSegment: 1, // Kunci 1 kalimat per segmen
        );

        if (mounted) {
          if (newProjectId != null && newProjectId.isNotEmpty) {
            // --- [LOG AKTIVITAS FITUR: KONVERSI SUKSES (CONVERSION)] ---
            firestoreService.logFeatureActivity(
              featureKey: 'auto_naramotion',
              eventType: 'conversion',
            );
            // -----------------------------------------------------------

            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => ProjectLoadingScreen(
                  projectId: newProjectId,
                ),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(t('Error: Failed to create project ID.', 'Error: Gagal membuat ID proyek.')),
                backgroundColor: Colors.red
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(t('Error adding project: $e', 'Terjadi kesalahan saat menambah proyek: $e')),
              backgroundColor: Colors.red
            ),
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
// BUILD UI & FORM LAYOUT                                         //
  @override
  Widget build(BuildContext context) {
    final currentLocale = ref.watch(appLanguageProvider);
    final isIndo = currentLocale.languageCode == 'id';
    String t(String en, String id) => isIndo ? id : en;

    final currentVoiceOptions = _currentVoiceOptions;

    final userAsync = ref.watch(firestoreUserProvider);
    final configAsync = ref.watch(appConfigProvider);

    // --- ESTIMASI REALTIME (1 KALIMAT PER SEGMEN) ---
    final String text = _scriptController.text.trim();
    final int textLength = text.length;

    int sentenceCount = 0;
    if (textLength > 0) {
      List<String> sentences = text.split(RegExp(r'[.!?]+'));
      sentenceCount = sentences.where((s) => s.trim().isNotEmpty).length;
    }

    int estimatedScenes = sentenceCount;
    const int charRatio = 100;
    int estimatedByLength = (textLength / charRatio).ceil();
    
    if (estimatedByLength > estimatedScenes) {
      estimatedScenes = estimatedByLength;
    }
    if (estimatedScenes == 0 && textLength > 0) {
      estimatedScenes = 1;
    }
    // ------------------------------------------------
    
    int currentBalance = 0;
    int costPerScene = 120;
    bool configReady = false;
    bool userReady = false;

    userAsync.whenData((user) {
      currentBalance = user.tokenBalance;
      userReady = true;
    });

    configAsync.whenData((config) {
      costPerScene = _selectedCostLevel == 'Good'
          ? config.costs.motionGoodPerScene
          : config.costs.motionPerScene;
      configReady = true;
    });

    final int requiredTokens = estimatedScenes * costPerScene;
    final bool hasSufficientFunds = currentBalance >= requiredTokens;
    final bool hasInput = textLength > 0;
    
    final bool isOutOfTokens = hasInput && !hasSufficientFunds;
    final bool canSubmit = hasInput && hasSufficientFunds && !_isLoading && userReady && configReady;

    return Theme(
      data: AppTheme.darkTheme,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Auto Naramotion'),
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
                        // --- [1. TOGGLE ON/OFF PROJECT TITLE OVERLAY (DEFAULT ON)] ---
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _showTitle ? Colors.blue.withOpacity(0.5) : Colors.white12,
                            ),
                          ),
                          child: SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              t('Project Title Overlay', 'Judul Overlay Proyek'),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            subtitle: Text(
                              _showTitle
                                  ? t('Overlay title is ON (Default)', 'Judul overlay AKTIF (Default)')
                                  : t('Overlay title is OFF', 'Judul overlay NONAKTIF'),
                              style: TextStyle(
                                color: _showTitle ? Colors.blueAccent : Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                            value: _showTitle,
                            activeColor: Colors.blueAccent,
                            onChanged: (val) {
                              setState(() => _showTitle = val);
                            },
                          ),
                        ),

                        // Input judul hanya aktif dan wajib diisi jika toggle ON (Menghilang jika OFF)
                        if (_showTitle) ...[
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _titleController,
                            maxLength: 40,
                            decoration: InputDecoration(
                              labelText: t('Project Title', 'Judul Proyek'),
                              hintText: t('e.g., "My First Explainer Video"', 'Cth: "Video Penjelasanku"'),
                            ),
                            validator: (value) {
                              if (_showTitle && (value == null || value.trim().isEmpty)) {
                                return t('Please enter a project title.', 'Mohon isi judul proyek.');
                              }
                              if (value != null && value.length > 40) {
                                return t('Title cannot exceed 40 characters.', 'Judul maksimal 40 karakter.');
                              }
                              return null;
                            },
                          ),
                        ],
                        const SizedBox(height: 24),

                        // --- [2. TOGGLE ON/OFF PROJECT DESCRIPTION OVERLAY (DEFAULT OFF)] ---
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _showDescription ? Colors.blue.withOpacity(0.5) : Colors.white12,
                            ),
                          ),
                          child: SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              t('Project Description Overlay', 'Deskripsi Overlay Proyek'),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            subtitle: Text(
                              _showDescription
                                  ? t('Overlay description is ON', 'Deskripsi overlay AKTIF')
                                  : t('Overlay description is OFF (Default)', 'Deskripsi overlay NONAKTIF (Default)'),
                              style: TextStyle(
                                color: _showDescription ? Colors.blueAccent : Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                            value: _showDescription,
                            activeColor: Colors.blueAccent,
                            onChanged: (val) {
                              setState(() => _showDescription = val);
                            },
                          ),
                        ),

                        // Input deskripsi hanya aktif dan wajib diisi jika toggle ON (Menghilang jika OFF)
                        if (_showDescription) ...[
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _descriptionController,
                            maxLength: 80,
                            maxLines: 2,
                            decoration: InputDecoration(
                              labelText: t('Project Description Text', 'Teks Deskripsi Proyek'),
                              hintText: t(
                                'e.g., "Created using Majiku\nAuto Video Content & Film Maker"',
                                'Cth: "Created using Majiku\nAuto Video Content & Film Maker"'
                              ),
                            ),
                            validator: (value) {
                              if (_showDescription && (value == null || value.trim().isEmpty)) {
                                return t('Please enter a description.', 'Mohon isi deskripsi.');
                              }
                              return null;
                            },
                          ),
                        ],
                        const SizedBox(height: 24),

                        // Row 3: Naskah Narasi (Script)
                        TextFormField(
                          controller: _scriptController,
                          maxLines: 10,
                          maxLength: 15000,
                          decoration: InputDecoration(
                            labelText: t('Paste or send your narration here..', 'Paste atau kirim narasimu kesini'),
                            hintText: t("Exp: Located in the Kedu Plain of Central Java, Borobudur Temple stands majestically as the world's largest Buddhist monument...", "Contoh: Terletak di dataran Kedu, Jawa Tengah, Candi Borobudur berdiri megah sebagai monumen Buddhis terbesar di dunia..."),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return t('Please enter a Narration for your video.', 'Mohon isi naskah narasi.');
                            }
                            if (value.length > 15000) {
                              return t('Narration cannot exceed 18,000 characters.', 'Naskah maksimal 18.000 karakter.');
                            }
                            return null;
                          },
                        ),
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
                                items: const {
                                  'Portrait (9:16)': '9:16',
                                  'Landscape (16:9)': '16:9',
                                  'Square (1:1)': '1:1',
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
                        
                        // --- UI BERDAMPINGAN: OVERLAY & COST LEVEL (GOOD DI ATAS, STANDARD DI BAWAH, TANPA TM) ---
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // BAGIAN KIRI: OVERLAY EFFECT
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.black12,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.white24, width: 1),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            t('Use VFX Overlay', 'Efek Visual'),
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                        ),
                                        SizedBox(
                                          height: 24,
                                          child: Switch(
                                            value: _useAssetOverlayEffects,
                                            activeColor: Colors.blue,
                                            onChanged: (bool value) {
                                              setState(() {
                                                _useAssetOverlayEffects = value;
                                              });
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      t('Light leaks, grain. Off = faster.', 'Tambahan efek. Matikan agar cepat.'),
                                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            // BAGIAN KANAN: COST LEVEL (GOOD DI ATAS, STANDARD DI BAWAH - TANPA EMBEL-EMBEL TM)
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _selectedCostLevel,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  labelText: t('Cost Level', 'Level Biaya'),
                                ),
                                items: [
                                  DropdownMenuItem(
                                    value: 'Good', 
                                    child: Text(t('Good', 'Good'), overflow: TextOverflow.ellipsis),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Standard', 
                                    child: Text(t('Standard', 'Standar'), overflow: TextOverflow.ellipsis),
                                  ),
                                ],
                                onChanged: (String? value) {
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
              
              // --- POP UP ANIMASI TOKEN HABIS ---
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
 }
//................................................................//