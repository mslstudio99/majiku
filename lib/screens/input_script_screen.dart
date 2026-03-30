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
  final _formKey = GlobalKey<FormState>();
  
  String _selectedStyle = 'Realistic';
  String _selectedAspectRatio = '9:16';
  
  String _selectedLanguage = 'Indonesian'; 
  static const String _defaultIndonesianVoice = 'id-ID-Chirp3-HD-Achernar';
  String _selectedVoice = _defaultIndonesianVoice;
  bool _isLoading = false;
  
  // --- KATEGORI_UX_OTOMATIS (NO_URUT_01): Variabel State Subtitle ---
  bool _showSubtitles = false; // Default nyala (bisa Anda ubah ke false jika mau)
  // --- AKHIR TAMBAHAN ---

  // ==========================================
  // OPSI SUARA (LENGKAP)
  // ==========================================

  final Map<String, String> _indonesianVoiceOptions = {
    'Achernar (ID)': 'id-ID-Chirp3-HD-Achernar', 'Achird (ID)': 'id-ID-Chirp3-HD-Achird',
    'Algenib (ID)': 'id-ID-Chirp3-HD-Algenib', 'Algieba (ID)': 'id-ID-Chirp3-HD-Algieba',
    'Alnilam (ID)': 'id-ID-Chirp3-HD-Alnilam', 'Aoede (ID)': 'id-ID-Chirp3-HD-Aoede',
    'Autonoe (ID)': 'id-ID-Chirp3-HD-Autonoe', 'Callirrhoe (ID)': 'id-ID-Chirp3-HD-Callirrhoe',
    'Charon (ID)': 'id-ID-Chirp3-HD-Charon', 'Despina (ID)': 'id-ID-Chirp3-HD-Despina',
    'Enceladus (ID)': 'id-ID-Chirp3-HD-Enceladus', 'Erinome (ID)': 'id-ID-Chirp3-HD-Erinome',
    'Fenrir (ID)': 'id-ID-Chirp3-HD-Fenrir', 'Gacrux (ID)': 'id-ID-Chirp3-HD-Gacrux',
    'Iapetus (ID)': 'id-ID-Chirp3-HD-Iapetus', 'Kore (ID)': 'id-ID-Chirp3-HD-Kore',
    'Laomedeia (ID)': 'id-ID-Chirp3-HD-Laomedeia', 'Leda (ID)': 'id-ID-Chirp3-HD-Leda',
    'Orus (ID)': 'id-ID-Chirp3-HD-Orus', 'Puck (ID)': 'id-ID-Chirp3-HD-Puck',
    'Pulcherrima (ID)': 'id-ID-Chirp3-HD-Pulcherrima', 'Rasalgethi (ID)': 'id-ID-Chirp3-HD-Rasalgethi',
    'Sadachbia (ID)': 'id-ID-Chirp3-HD-Sadachbia', 'Sadaltager (ID)': 'id-ID-Chirp3-HD-Sadaltager',
    'Schedar (ID)': 'id-ID-Chirp3-HD-Schedar', 'Sulafat (ID)': 'id-ID-Chirp3-HD-Sulafat',
    'Umbriel (ID)': 'id-ID-Chirp3-HD-Umbriel', 'Vindemiatrix (ID)': 'id-ID-Chirp3-HD-Vindemiatrix',
    'Zephyr (ID)': 'id-ID-Chirp3-HD-Zephyr', 'Zubenelgenubi (ID)': 'id-ID-Chirp3-HD-Zubenelgenubi',
  };

  final Map<String, String> _englishVoiceOptions = {
    'Alnilam (EN)': 'en-US-Chirp3-HD-Alnilam', 'Aoede (EN)': 'en-US-Chirp3-HD-Aoede',
    'Autonoe (EN)': 'en-US-Chirp3-HD-Autonoe', 'Callirrhoe (EN)': 'en-US-Chirp3-HD-Callirrhoe',
    'Charon (EN)': 'en-US-Chirp3-HD-Charon', 'Despina (EN)': 'en-US-Chirp3-HD-Despina',
    'Enceladus (EN)': 'en-US-Chirp3-HD-Enceladus', 'Erinome (EN)': 'en-US-Chirp3-HD-Erinome',
    'Fenrir (EN)': 'en-US-Chirp3-HD-Fenrir', 'Gacrux (EN)': 'en-US-Chirp3-HD-Gacrux',
    'Iapetus (EN)': 'en-US-Chirp3-HD-Iapetus', 'Kore (EN)': 'en-US-Chirp3-HD-Kore',
    'Laomedeia (EN)': 'en-US-Chirp3-HD-Laomedeia', 'Leda (EN)': 'en-US-Chirp3-HD-Leda',
    'Orus (EN)': 'en-US-Chirp3-HD-Orus', 'Puck (EN)': 'en-US-Chirp3-HD-Puck',
    'Pulcherrima (EN)': 'en-US-Chirp3-HD-Pulcherrima', 'Rasalgethi (EN)': 'en-US-Chirp3-HD-Rasalgethi',
    'Sadachbia (EN)': 'en-US-Chirp3-HD-Sadachbia', 'Sadaltager (EN)': 'en-US-Chirp3-HD-Sadaltager',
    'Schedar (EN)': 'en-US-Chirp3-HD-Schedar', 'Sulafat (EN)': 'en-US-Chirp3-HD-Sulafat',
    'Umbriel (EN)': 'en-US-Chirp3-HD-Umbriel', 'Vindemiatrix (EN)': 'en-US-Chirp3-HD-Vindemiatrix',
    'Zephyr (EN)': 'en-US-Chirp3-HD-Zephyr', 'Zubenelgenubi (EN)': 'en-US-Chirp3-HD-Zubenelgenubi',
  };

  final Map<String, String> _arabicVoiceOptions = {
    'Achernar (ar-XA)': 'ar-XA-Chirp3-HD-Achernar', 'Aoede (ar-XA)': 'ar-XA-Chirp3-HD-Aoede',
    'Autonoe (ar-XA)': 'ar-XA-Chirp3-HD-Autonoe', 'Callirrhoe (ar-XA)': 'ar-XA-Chirp3-HD-Callirrhoe',
    'Despina (ar-XA)': 'ar-XA-Chirp3-HD-Despina', 'Achird (ar-XA)': 'ar-XA-Chirp3-HD-Achird',
    'Algenib (ar-XA)': 'ar-XA-Chirp3-HD-Algenib', 'Algieba (ar-XA)': 'ar-XA-Chirp3-HD-Algieba',
    'Alnilam (ar-XA)': 'ar-XA-Chirp3-HD-Alnilam', 'Charon (ar-XA)': 'ar-XA-Chirp3-HD-Charon',
  };

  final Map<String, String> _bengaliVoiceOptions = {
    'Achernar (bn-IN)': 'bn-IN-Chirp3-HD-Achernar', 'Aoede (bn-IN)': 'bn-IN-Chirp3-HD-Aoede',
    'Autonoe (bn-IN)': 'bn-IN-Chirp3-HD-Autonoe', 'Callirrhoe (bn-IN)': 'bn-IN-Chirp3-HD-Callirrhoe',
    'Despina (bn-IN)': 'bn-IN-Chirp3-HD-Despina', 'Achird (bn-IN)': 'bn-IN-Chirp3-HD-Achird',
    'Algenib (bn-IN)': 'bn-IN-Chirp3-HD-Algenib', 'Algieba (bn-IN)': 'bn-IN-Chirp3-HD-Algieba',
    'Alnilam (bn-IN)': 'bn-IN-Chirp3-HD-Alnilam', 'Charon (bn-IN)': 'bn-IN-Chirp3-HD-Charon',
  };

  final Map<String, String> _danishVoiceOptions = {
    'Achernar (da-DK)': 'da-DK-Chirp3-HD-Achernar', 'Aoede (da-DK)': 'da-DK-Chirp3-HD-Aoede',
    'Autonoe (da-DK)': 'da-DK-Chirp3-HD-Autonoe', 'Callirrhoe (da-DK)': 'da-DK-Chirp3-HD-Callirrhoe',
    'Despina (da-DK)': 'da-DK-Chirp3-HD-Despina', 'Achird (da-DK)': 'da-DK-Chirp3-HD-Achird',
    'Algenib (da-DK)': 'da-DK-Chirp3-HD-Algenib', 'Algieba (da-DK)': 'da-DK-Chirp3-HD-Algieba',
    'Alnilam (da-DK)': 'da-DK-Chirp3-HD-Alnilam', 'Charon (da-DK)': 'da-DK-Chirp3-HD-Charon',
  };

  final Map<String, String> _dutchBelgiumVoiceOptions = {
    'Achernar (nl-BE)': 'nl-BE-Chirp3-HD-Achernar', 'Aoede (nl-BE)': 'nl-BE-Chirp3-HD-Aoede',
    'Autonoe (nl-BE)': 'nl-BE-Chirp3-HD-Autonoe', 'Callirrhoe (nl-BE)': 'nl-BE-Chirp3-HD-Callirrhoe',
    'Despina (nl-BE)': 'nl-BE-Chirp3-HD-Despina', 'Achird (nl-BE)': 'nl-BE-Chirp3-HD-Achird',
    'Algenib (nl-BE)': 'nl-BE-Chirp3-HD-Algenib', 'Algieba (nl-BE)': 'nl-BE-Chirp3-HD-Algieba',
    'Alnilam (nl-BE)': 'nl-BE-Chirp3-HD-Alnilam', 'Charon (nl-BE)': 'nl-BE-Chirp3-HD-Charon',
  };

  final Map<String, String> _dutchNetherlandsVoiceOptions = {
    'Achernar (nl-NL)': 'nl-NL-Chirp3-HD-Achernar', 'Aoede (nl-NL)': 'nl-NL-Chirp3-HD-Aoede',
    'Autonoe (nl-NL)': 'nl-NL-Chirp3-HD-Autonoe', 'Callirrhoe (nl-NL)': 'nl-NL-Chirp3-HD-Callirrhoe',
    'Despina (nl-NL)': 'nl-NL-Chirp3-HD-Despina', 'Achird (nl-NL)': 'nl-NL-Chirp3-HD-Achird',
    'Algenib (nl-NL)': 'nl-NL-Chirp3-HD-Algenib', 'Algieba (nl-NL)': 'nl-NL-Chirp3-HD-Algieba',
    'Alnilam (nl-NL)': 'nl-NL-Chirp3-HD-Alnilam', 'Charon (nl-NL)': 'nl-NL-Chirp3-HD-Charon',
  };

  final Map<String, String> _englishAustraliaVoiceOptions = {
    'Achernar (en-AU)': 'en-AU-Chirp3-HD-Achernar', 'Aoede (en-AU)': 'en-AU-Chirp3-HD-Aoede',
    'Autonoe (en-AU)': 'en-AU-Chirp3-HD-Autonoe', 'Callirrhoe (en-AU)': 'en-AU-Chirp3-HD-Callirrhoe',
    'Despina (en-AU)': 'en-AU-Chirp3-HD-Despina', 'Achird (en-AU)': 'en-AU-Chirp3-HD-Achird',
    'Algenib (en-AU)': 'en-AU-Chirp3-HD-Algenib', 'Algieba (en-AU)': 'en-AU-Chirp3-HD-Algieba',
    'Alnilam (en-AU)': 'en-AU-Chirp3-HD-Alnilam', 'Charon (en-AU)': 'en-AU-Chirp3-HD-Charon',
  };

  final Map<String, String> _englishIndiaVoiceOptions = {
    'Achernar (en-IN)': 'en-IN-Chirp3-HD-Achernar', 'Aoede (en-IN)': 'en-IN-Chirp3-HD-Aoede',
    'Autonoe (en-IN)': 'en-IN-Chirp3-HD-Autonoe', 'Callirrhoe (en-IN)': 'en-IN-Chirp3-HD-Callirrhoe',
    'Despina (en-IN)': 'en-IN-Chirp3-HD-Despina', 'Achird (en-IN)': 'en-IN-Chirp3-HD-Achird',
    'Algenib (en-IN)': 'en-IN-Chirp3-HD-Algenib', 'Algieba (en-IN)': 'en-IN-Chirp3-HD-Algieba',
    'Alnilam (en-IN)': 'en-IN-Chirp3-HD-Alnilam', 'Charon (en-IN)': 'en-IN-Chirp3-HD-Charon',
  };

  final Map<String, String> _englishUKVoiceOptions = {
    'Achernar (en-GB)': 'en-GB-Chirp3-HD-Achernar', 'Aoede (en-GB)': 'en-GB-Chirp3-HD-Aoede',
    'Autonoe (en-GB)': 'en-GB-Chirp3-HD-Autonoe', 'Callirrhoe (en-GB)': 'en-GB-Chirp3-HD-Callirrhoe',
    'Despina (en-GB)': 'en-GB-Chirp3-HD-Despina', 'Achird (en-GB)': 'en-GB-Chirp3-HD-Achird',
    'Algenib (en-GB)': 'en-GB-Chirp3-HD-Algenib', 'Algieba (en-GB)': 'en-GB-Chirp3-HD-Algieba',
    'Alnilam (en-GB)': 'en-GB-Chirp3-HD-Alnilam', 'Charon (en-GB)': 'en-GB-Chirp3-HD-Charon',
  };

  final Map<String, String> _finnishVoiceOptions = {
    'Achernar (fi-FI)': 'fi-FI-Chirp3-HD-Achernar', 'Aoede (fi-FI)': 'fi-FI-Chirp3-HD-Aoede',
    'Autonoe (fi-FI)': 'fi-FI-Chirp3-HD-Autonoe', 'Callirrhoe (fi-FI)': 'fi-FI-Chirp3-HD-Callirrhoe',
    'Despina (fi-FI)': 'fi-FI-Chirp3-HD-Despina', 'Achird (fi-FI)': 'fi-FI-Chirp3-HD-Achird',
    'Algenib (fi-FI)': 'fi-FI-Chirp3-HD-Algenib', 'Algieba (fi-FI)': 'fi-FI-Chirp3-HD-Algieba',
    'Alnilam (fi-FI)': 'fi-FI-Chirp3-HD-Alnilam', 'Charon (fi-FI)': 'fi-FI-Chirp3-HD-Charon',
  };

  final Map<String, String> _frenchCanadaVoiceOptions = {
    'Achernar (fr-CA)': 'fr-CA-Chirp3-HD-Achernar', 'Aoede (fr-CA)': 'fr-CA-Chirp3-HD-Aoede',
    'Autonoe (fr-CA)': 'fr-CA-Chirp3-HD-Autonoe', 'Callirrhoe (fr-CA)': 'fr-CA-Chirp3-HD-Callirrhoe',
    'Despina (fr-CA)': 'fr-CA-Chirp3-HD-Despina', 'Achird (fr-CA)': 'fr-CA-Chirp3-HD-Achird',
    'Algenib (fr-CA)': 'fr-CA-Chirp3-HD-Algenib', 'Algieba (fr-CA)': 'fr-CA-Chirp3-HD-Algieba',
    'Alnilam (fr-CA)': 'fr-CA-Chirp3-HD-Alnilam', 'Charon (fr-CA)': 'fr-CA-Chirp3-HD-Charon',
  };

  final Map<String, String> _frenchFranceVoiceOptions = {
    'Achernar (fr-FR)': 'fr-FR-Chirp3-HD-Achernar', 'Aoede (fr-FR)': 'fr-FR-Chirp3-HD-Aoede',
    'Autonoe (fr-FR)': 'fr-FR-Chirp3-HD-Autonoe', 'Callirrhoe (fr-FR)': 'fr-FR-Chirp3-HD-Callirrhoe',
    'Despina (fr-FR)': 'fr-FR-Chirp3-HD-Despina', 'Achird (fr-FR)': 'fr-FR-Chirp3-HD-Achird',
    'Algenib (fr-FR)': 'fr-FR-Chirp3-HD-Algenib', 'Algieba (fr-FR)': 'fr-FR-Chirp3-HD-Algieba',
    'Alnilam (fr-FR)': 'fr-FR-Chirp3-HD-Alnilam', 'Charon (fr-FR)': 'fr-FR-Chirp3-HD-Charon',
  };

  final Map<String, String> _germanVoiceOptions = {
    'Achernar (de-DE)': 'de-DE-Chirp3-HD-Achernar', 'Aoede (de-DE)': 'de-DE-Chirp3-HD-Aoede',
    'Autonoe (de-DE)': 'de-DE-Chirp3-HD-Autonoe', 'Callirrhoe (de-DE)': 'de-DE-Chirp3-HD-Callirrhoe',
    'Despina (de-DE)': 'de-DE-Chirp3-HD-Despina', 'Achird (de-DE)': 'de-DE-Chirp3-HD-Achird',
    'Algenib (de-DE)': 'de-DE-Chirp3-HD-Algenib', 'Algieba (de-DE)': 'de-DE-Chirp3-HD-Algieba',
    'Alnilam (de-DE)': 'de-DE-Chirp3-HD-Alnilam', 'Charon (de-DE)': 'de-DE-Chirp3-HD-Charon',
  };

  final Map<String, String> _gujaratiVoiceOptions = {
    'Achernar (gu-IN)': 'gu-IN-Chirp3-HD-Achernar', 'Aoede (gu-IN)': 'gu-IN-Chirp3-HD-Aoede',
    'Autonoe (gu-IN)': 'gu-IN-Chirp3-HD-Autonoe', 'Callirrhoe (gu-IN)': 'gu-IN-Chirp3-HD-Callirrhoe',
    'Despina (gu-IN)': 'gu-IN-Chirp3-HD-Despina', 'Achird (gu-IN)': 'gu-IN-Chirp3-HD-Achird',
    'Algenib (gu-IN)': 'gu-IN-Chirp3-HD-Algenib', 'Algieba (gu-IN)': 'gu-IN-Chirp3-HD-Algieba',
    'Alnilam (gu-IN)': 'gu-IN-Chirp3-HD-Alnilam', 'Charon (gu-IN)': 'gu-IN-Chirp3-HD-Charon',
  };

  final Map<String, String> _hindiVoiceOptions = {
    'Achernar (hi-IN)': 'hi-IN-Chirp3-HD-Achernar', 'Aoede (hi-IN)': 'hi-IN-Chirp3-HD-Aoede',
    'Autonoe (hi-IN)': 'hi-IN-Chirp3-HD-Autonoe', 'Callirrhoe (hi-IN)': 'hi-IN-Chirp3-HD-Callirrhoe',
    'Despina (hi-IN)': 'hi-IN-Chirp3-HD-Despina', 'Achird (hi-IN)': 'hi-IN-Chirp3-HD-Achird',
    'Algenib (hi-IN)': 'hi-IN-Chirp3-HD-Algenib', 'Algieba (hi-IN)': 'hi-IN-Chirp3-HD-Algieba',
    'Alnilam (hi-IN)': 'hi-IN-Chirp3-HD-Alnilam', 'Charon (hi-IN)': 'hi-IN-Chirp3-HD-Charon',
  };

  final Map<String, String> _italianVoiceOptions = {
    'Achernar (it-IT)': 'it-IT-Chirp3-HD-Achernar', 'Aoede (it-IT)': 'it-IT-Chirp3-HD-Aoede',
    'Autonoe (it-IT)': 'it-IT-Chirp3-HD-Autonoe', 'Callirrhoe (it-IT)': 'it-IT-Chirp3-HD-Callirrhoe',
    'Despina (it-IT)': 'it-IT-Chirp3-HD-Despina', 'Achird (it-IT)': 'it-IT-Chirp3-HD-Achird',
    'Algenib (it-IT)': 'it-IT-Chirp3-HD-Algenib', 'Algieba (it-IT)': 'it-IT-Chirp3-HD-Algieba',
    'Alnilam (it-IT)': 'it-IT-Chirp3-HD-Alnilam', 'Charon (it-IT)': 'it-IT-Chirp3-HD-Charon',
  };

  final Map<String, String> _japaneseVoiceOptions = {
    'Achernar (ja-JP)': 'ja-JP-Chirp3-HD-Achernar', 'Aoede (ja-JP)': 'ja-JP-Chirp3-HD-Aoede',
    'Autonoe (ja-JP)': 'ja-JP-Chirp3-HD-Autonoe', 'Callirrhoe (ja-JP)': 'ja-JP-Chirp3-HD-Callirrhoe',
    'Despina (ja-JP)': 'ja-JP-Chirp3-HD-Despina', 'Achird (ja-JP)': 'ja-JP-Chirp3-HD-Achird',
    'Algenib (ja-JP)': 'ja-JP-Chirp3-HD-Algenib', 'Algieba (ja-JP)': 'ja-JP-Chirp3-HD-Algieba',
    'Alnilam (ja-JP)': 'ja-JP-Chirp3-HD-Alnilam', 'Charon (ja-JP)': 'ja-JP-Chirp3-HD-Charon',
  };

  final Map<String, String> _kannadaVoiceOptions = {
    'Achernar (kn-IN)': 'kn-IN-Chirp3-HD-Achernar', 'Aoede (kn-IN)': 'kn-IN-Chirp3-HD-Aoede',
    'Autonoe (kn-IN)': 'kn-IN-Chirp3-HD-Autonoe', 'Callirrhoe (kn-IN)': 'kn-IN-Chirp3-HD-Callirrhoe',
    'Despina (kn-IN)': 'kn-IN-Chirp3-HD-Despina', 'Achird (kn-IN)': 'kn-IN-Chirp3-HD-Achird',
    'Algenib (kn-IN)': 'kn-IN-Chirp3-HD-Algenib', 'Algieba (kn-IN)': 'kn-IN-Chirp3-HD-Algieba',
    'Alnilam (kn-IN)': 'kn-IN-Chirp3-HD-Alnilam', 'Charon (kn-IN)': 'kn-IN-Chirp3-HD-Charon',
  };

  final Map<String, String> _koreanVoiceOptions = {
    'Achernar (ko-KR)': 'ko-KR-Chirp3-HD-Achernar', 'Aoede (ko-KR)': 'ko-KR-Chirp3-HD-Aoede',
    'Autonoe (ko-KR)': 'ko-KR-Chirp3-HD-Autonoe', 'Callirrhoe (ko-KR)': 'ko-KR-Chirp3-HD-Callirrhoe',
    'Despina (ko-KR)': 'ko-KR-Chirp3-HD-Despina', 'Achird (ko-KR)': 'ko-KR-Chirp3-HD-Achird',
    'Algenib (ko-KR)': 'ko-KR-Chirp3-HD-Algenib', 'Algieba (ko-KR)': 'ko-KR-Chirp3-HD-Algieba',
    'Alnilam (ko-KR)': 'ko-KR-Chirp3-HD-Alnilam', 'Charon (ko-KR)': 'ko-KR-Chirp3-HD-Charon',
  };

  final Map<String, String> _malayalamVoiceOptions = {
    'Achernar (ml-IN)': 'ml-IN-Chirp3-HD-Achernar', 'Aoede (ml-IN)': 'ml-IN-Chirp3-HD-Aoede',
    'Autonoe (ml-IN)': 'ml-IN-Chirp3-HD-Autonoe', 'Callirrhoe (ml-IN)': 'ml-IN-Chirp3-HD-Callirrhoe',
    'Despina (ml-IN)': 'ml-IN-Chirp3-HD-Despina', 'Achird (ml-IN)': 'ml-IN-Chirp3-HD-Achird',
    'Algenib (ml-IN)': 'ml-IN-Chirp3-HD-Algenib', 'Algieba (ml-IN)': 'ml-IN-Chirp3-HD-Algieba',
    'Alnilam (ml-IN)': 'ml-IN-Chirp3-HD-Alnilam', 'Charon (ml-IN)': 'ml-IN-Chirp3-HD-Charon',
  };

  final Map<String, String> _mandarinVoiceOptions = {
    'Achernar (cmn-CN)': 'cmn-CN-Chirp3-HD-Achernar', 'Aoede (cmn-CN)': 'cmn-CN-Chirp3-HD-Aoede',
    'Autonoe (cmn-CN)': 'cmn-CN-Chirp3-HD-Autonoe', 'Callirrhoe (cmn-CN)': 'cmn-CN-Chirp3-HD-Callirrhoe',
    'Despina (cmn-CN)': 'cmn-CN-Chirp3-HD-Despina', 'Achird (cmn-CN)': 'cmn-CN-Chirp3-HD-Achird',
    'Algenib (cmn-CN)': 'cmn-CN-Chirp3-HD-Algenib', 'Algieba (cmn-CN)': 'cmn-CN-Chirp3-HD-Algieba',
    'Alnilam (cmn-CN)': 'cmn-CN-Chirp3-HD-Alnilam', 'Charon (cmn-CN)': 'cmn-CN-Chirp3-HD-Charon',
  };

  final Map<String, String> _marathiVoiceOptions = {
    'Achernar (mr-IN)': 'mr-IN-Chirp3-HD-Achernar', 'Aoede (mr-IN)': 'mr-IN-Chirp3-HD-Aoede',
    'Autonoe (mr-IN)': 'mr-IN-Chirp3-HD-Autonoe', 'Callirrhoe (mr-IN)': 'mr-IN-Chirp3-HD-Callirrhoe',
    'Despina (mr-IN)': 'mr-IN-Chirp3-HD-Despina', 'Achird (mr-IN)': 'mr-IN-Chirp3-HD-Achird',
    'Algenib (mr-IN)': 'mr-IN-Chirp3-HD-Algenib', 'Algieba (mr-IN)': 'mr-IN-Chirp3-HD-Algieba',
    'Alnilam (mr-IN)': 'mr-IN-Chirp3-HD-Alnilam', 'Charon (mr-IN)': 'mr-IN-Chirp3-HD-Charon',
  };

  final Map<String, String> _norwegianVoiceOptions = {
    'Achernar (nb-NO)': 'nb-NO-Chirp3-HD-Achernar', 'Aoede (nb-NO)': 'nb-NO-Chirp3-HD-Aoede',
    'Autonoe (nb-NO)': 'nb-NO-Chirp3-HD-Autonoe', 'Callirrhoe (nb-NO)': 'nb-NO-Chirp3-HD-Callirrhoe',
    'Despina (nb-NO)': 'nb-NO-Chirp3-HD-Despina', 'Achird (nb-NO)': 'nb-NO-Chirp3-HD-Achird',
    'Algenib (nb-NO)': 'nb-NO-Chirp3-HD-Algenib', 'Algieba (nb-NO)': 'nb-NO-Chirp3-HD-Algieba',
    'Alnilam (nb-NO)': 'nb-NO-Chirp3-HD-Alnilam', 'Charon (nb-NO)': 'nb-NO-Chirp3-HD-Charon',
  };

  final Map<String, String> _polishVoiceOptions = {
    'Achernar (pl-PL)': 'pl-PL-Chirp3-HD-Achernar', 'Aoede (pl-PL)': 'pl-PL-Chirp3-HD-Aoede',
    'Autonoe (pl-PL)': 'pl-PL-Chirp3-HD-Autonoe', 'Callirrhoe (pl-PL)': 'pl-PL-Chirp3-HD-Callirrhoe',
    'Despina (pl-PL)': 'pl-PL-Chirp3-HD-Despina', 'Achird (pl-PL)': 'pl-PL-Chirp3-HD-Achird',
    'Algenib (pl-PL)': 'pl-PL-Chirp3-HD-Algenib', 'Algieba (pl-PL)': 'pl-PL-Chirp3-HD-Algieba',
    'Alnilam (pl-PL)': 'pl-PL-Chirp3-HD-Alnilam', 'Charon (pl-PL)': 'pl-PL-Chirp3-HD-Charon',
  };

  final Map<String, String> _portugueseBrazilVoiceOptions = {
    'Achernar (pt-BR)': 'pt-BR-Chirp3-HD-Achernar', 'Aoede (pt-BR)': 'pt-BR-Chirp3-HD-Aoede',
    'Autonoe (pt-BR)': 'pt-BR-Chirp3-HD-Autonoe', 'Callirrhoe (pt-BR)': 'pt-BR-Chirp3-HD-Callirrhoe',
    'Despina (pt-BR)': 'pt-BR-Chirp3-HD-Despina', 'Achird (pt-BR)': 'pt-BR-Chirp3-HD-Achird',
    'Algenib (pt-BR)': 'pt-BR-Chirp3-HD-Algenib', 'Algieba (pt-BR)': 'pt-BR-Chirp3-HD-Algieba',
    'Alnilam (pt-BR)': 'pt-BR-Chirp3-HD-Alnilam', 'Charon (pt-BR)': 'pt-BR-Chirp3-HD-Charon',
  };

  final Map<String, String> _russianVoiceOptions = {
    'Aoede (ru-RU)': 'ru-RU-Chirp3-HD-Aoede', 'Kore (ru-RU)': 'ru-RU-Chirp3-HD-Kore',
    'Leda (ru-RU)': 'ru-RU-Chirp3-HD-Leda', 'Zephyr (ru-RU)': 'ru-RU-Chirp3-HD-Zephyr',
    'Achernar (ru-RU)': 'ru-RU-Chirp3-HD-Achernar', 'Charon (ru-RU)': 'ru-RU-Chirp3-HD-Charon',
    'Fenrir (ru-RU)': 'ru-RU-Chirp3-HD-Fenrir', 'Orus (ru-RU)': 'ru-RU-Chirp3-HD-Orus',
    'Puck (ru-RU)': 'ru-RU-Chirp3-HD-Puck', 'Achird (ru-RU)': 'ru-RU-Chirp3-HD-Achird',
  };

  final Map<String, String> _spanishSpainVoiceOptions = {
    'Achernar (es-ES)': 'es-ES-Chirp3-HD-Achernar', 'Aoede (es-ES)': 'es-ES-Chirp3-HD-Aoede',
    'Autonoe (es-ES)': 'es-ES-Chirp3-HD-Autonoe', 'Callirrhoe (es-ES)': 'es-ES-Chirp3-HD-Callirrhoe',
    'Despina (es-ES)': 'es-ES-Chirp3-HD-Despina', 'Achird (es-ES)': 'es-ES-Chirp3-HD-Achird',
    'Algenib (es-ES)': 'es-ES-Chirp3-HD-Algenib', 'Algieba (es-ES)': 'es-ES-Chirp3-HD-Algieba',
    'Alnilam (es-ES)': 'es-ES-Chirp3-HD-Alnilam', 'Charon (es-ES)': 'es-ES-Chirp3-HD-Charon',
  };

  final Map<String, String> _spanishUSVoiceOptions = {
    'Achernar (es-US)': 'es-US-Chirp3-HD-Achernar', 'Aoede (es-US)': 'es-US-Chirp3-HD-Aoede',
    'Autonoe (es-US)': 'es-US-Chirp3-HD-Autonoe', 'Callirrhoe (es-US)': 'es-US-Chirp3-HD-Callirrhoe',
    'Despina (es-US)': 'es-US-Chirp3-HD-Despina', 'Achird (es-US)': 'es-US-Chirp3-HD-Achird',
    'Algenib (es-US)': 'es-US-Chirp3-HD-Algenib', 'Algieba (es-US)': 'es-US-Chirp3-HD-Algieba',
    'Alnilam (es-US)': 'es-US-Chirp3-HD-Alnilam', 'Charon (es-US)': 'es-US-Chirp3-HD-Charon',
  };

  final Map<String, String> _swedishVoiceOptions = {
    'Achernar (sv-SE)': 'sv-SE-Chirp3-HD-Achernar', 'Aoede (sv-SE)': 'sv-SE-Chirp3-HD-Aoede',
    'Autonoe (sv-SE)': 'sv-SE-Chirp3-HD-Autonoe', 'Callirrhoe (sv-SE)': 'sv-SE-Chirp3-HD-Callirrhoe',
    'Despina (sv-SE)': 'sv-SE-Chirp3-HD-Despina', 'Achird (sv-SE)': 'sv-SE-Chirp3-HD-Achird',
    'Algenib (sv-SE)': 'sv-SE-Chirp3-HD-Algenib', 'Algieba (sv-SE)': 'sv-SE-Chirp3-HD-Algieba',
    'Alnilam (sv-SE)': 'sv-SE-Chirp3-HD-Alnilam', 'Charon (sv-SE)': 'sv-SE-Chirp3-HD-Charon',
  };

  final Map<String, String> _tamilVoiceOptions = {
    'Achernar (ta-IN)': 'ta-IN-Chirp3-HD-Achernar', 'Aoede (ta-IN)': 'ta-IN-Chirp3-HD-Aoede',
    'Autonoe (ta-IN)': 'ta-IN-Chirp3-HD-Autonoe', 'Callirrhoe (ta-IN)': 'ta-IN-Chirp3-HD-Callirrhoe',
    'Despina (ta-IN)': 'ta-IN-Chirp3-HD-Despina', 'Achird (ta-IN)': 'ta-IN-Chirp3-HD-Achird',
    'Algenib (ta-IN)': 'ta-IN-Chirp3-HD-Algenib', 'Algieba (ta-IN)': 'ta-IN-Chirp3-HD-Algieba',
    'Alnilam (ta-IN)': 'ta-IN-Chirp3-HD-Alnilam', 'Charon (ta-IN)': 'ta-IN-Chirp3-HD-Charon',
  };

  final Map<String, String> _teluguVoiceOptions = {
    'Achernar (te-IN)': 'te-IN-Chirp3-HD-Achernar', 'Aoede (te-IN)': 'te-IN-Chirp3-HD-Aoede',
    'Autonoe (te-IN)': 'te-IN-Chirp3-HD-Autonoe', 'Callirrhoe (te-IN)': 'te-IN-Chirp3-HD-Callirrhoe',
    'Despina (te-IN)': 'te-IN-Chirp3-HD-Despina', 'Achird (te-IN)': 'te-IN-Chirp3-HD-Achird',
    'Algenib (te-IN)': 'te-IN-Chirp3-HD-Algenib', 'Algieba (te-IN)': 'te-IN-Chirp3-HD-Algieba',
    'Alnilam (te-IN)': 'te-IN-Chirp3-HD-Alnilam', 'Charon (te-IN)': 'te-IN-Chirp3-HD-Charon',
  };

  final Map<String, String> _thaiVoiceOptions = {
    'Achernar (th-TH)': 'th-TH-Chirp3-HD-Achernar', 'Aoede (th-TH)': 'th-TH-Chirp3-HD-Aoede',
    'Autonoe (th-TH)': 'th-TH-Chirp3-HD-Autonoe', 'Callirrhoe (th-TH)': 'th-TH-Chirp3-HD-Callirrhoe',
    'Despina (th-TH)': 'th-TH-Chirp3-HD-Despina', 'Achird (th-TH)': 'th-TH-Chirp3-HD-Achird',
    'Algenib (th-TH)': 'th-TH-Chirp3-HD-Algenib', 'Algieba (th-TH)': 'th-TH-Chirp3-HD-Algieba',
    'Alnilam (th-TH)': 'th-TH-Chirp3-HD-Alnilam', 'Charon (th-TH)': 'th-TH-Chirp3-HD-Charon',
  };

  final Map<String, String> _turkishVoiceOptions = {
    'Achernar (tr-TR)': 'tr-TR-Chirp3-HD-Achernar', 'Aoede (tr-TR)': 'tr-TR-Chirp3-HD-Aoede',
    'Autonoe (tr-TR)': 'tr-TR-Chirp3-HD-Autonoe', 'Callirrhoe (tr-TR)': 'tr-TR-Chirp3-HD-Callirrhoe',
    'Despina (tr-TR)': 'tr-TR-Chirp3-HD-Despina', 'Achird (tr-TR)': 'tr-TR-Chirp3-HD-Achird',
    'Algenib (tr-TR)': 'tr-TR-Chirp3-HD-Algenib', 'Algieba (tr-TR)': 'tr-TR-Chirp3-HD-Algieba',
    'Alnilam (tr-TR)': 'tr-TR-Chirp3-HD-Alnilam', 'Charon (tr-TR)': 'tr-TR-Chirp3-HD-Charon',
  };

  final Map<String, String> _ukrainianVoiceOptions = {
    'Achernar (uk-UA)': 'uk-UA-Chirp3-HD-Achernar', 'Aoede (uk-UA)': 'uk-UA-Chirp3-HD-Aoede',
    'Autonoe (uk-UA)': 'uk-UA-Chirp3-HD-Autonoe', 'Callirrhoe (uk-UA)': 'uk-UA-Chirp3-HD-Callirrhoe',
    'Despina (uk-UA)': 'uk-UA-Chirp3-HD-Despina', 'Achird (uk-UA)': 'uk-UA-Chirp3-HD-Achird',
    'Algenib (uk-UA)': 'uk-UA-Chirp3-HD-Algenib', 'Algieba (uk-UA)': 'uk-UA-Chirp3-HD-Algieba',
    'Alnilam (uk-UA)': 'uk-UA-Chirp3-HD-Alnilam', 'Charon (uk-UA)': 'uk-UA-Chirp3-HD-Charon',
  };

  final Map<String, String> _urduIndiaVoiceOptions = {
    'Achernar (ur-IN)': 'ur-IN-Chirp3-HD-Achernar', 'Aoede (ur-IN)': 'ur-IN-Chirp3-HD-Aoede',
    'Autonoe (ur-IN)': 'ur-IN-Chirp3-HD-Autonoe', 'Callirrhoe (ur-IN)': 'ur-IN-Chirp3-HD-Callirrhoe',
    'Despina (ur-IN)': 'ur-IN-Chirp3-HD-Despina', 'Achird (ur-IN)': 'ur-IN-Chirp3-HD-Achird',
    'Algenib (ur-IN)': 'ur-IN-Chirp3-HD-Algenib', 'Algieba (ur-IN)': 'ur-IN-Chirp3-HD-Algieba',
    'Alnilam (ur-IN)': 'ur-IN-Chirp3-HD-Alnilam', 'Charon (ur-IN)': 'ur-IN-Chirp3-HD-Charon',
  };

  final Map<String, String> _vietnameseVoiceOptions = {
    'Achernar (vi-VN)': 'vi-VN-Chirp3-HD-Achernar', 'Aoede (vi-VN)': 'vi-VN-Chirp3-HD-Aoede',
    'Autonoe (vi-VN)': 'vi-VN-Chirp3-HD-Autonoe', 'Callirrhoe (vi-VN)': 'vi-VN-Chirp3-HD-Callirrhoe',
    'Despina (vi-VN)': 'vi-VN-Chirp3-HD-Despina', 'Achird (vi-VN)': 'vi-VN-Chirp3-HD-Achird',
    'Algenib (vi-VN)': 'vi-VN-Chirp3-HD-Algenib', 'Algieba (vi-VN)': 'vi-VN-Chirp3-HD-Algieba',
    'Alnilam (vi-VN)': 'vi-VN-Chirp3-HD-Alnilam', 'Charon (vi-VN)': 'vi-VN-Chirp3-HD-Charon',
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

    _scriptController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _scriptController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _submitData() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      final firestoreService = ref.read(firestoreServiceProvider);
      try {
        final String? newProjectId = await firestoreService.addProject(
          title: _titleController.text,
          rawScript: _scriptController.text,
          imageStyle: _selectedStyle,
          aspectRatio: _selectedAspectRatio,
          language: _selectedLanguage,
          voice: _selectedVoice,
          // --- KATEGORI_UX_OTOMATIS (NO_URUT_02): Kirim Nilai Toggle ---
          showSubtitles: _showSubtitles,
          // --- AKHIR TAMBAHAN ---
        );

        if (mounted) {
          if (newProjectId != null && newProjectId.isNotEmpty) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => ProjectLoadingScreen(
                  projectId: newProjectId,
                ),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Error: Failed to create project ID.'),
                  backgroundColor: Colors.red),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Error adding project: $e'),
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
// BUILD UI & FORM LAYOUT                                         //
  @override
  Widget build(BuildContext context) {
    final currentLocale = ref.watch(appLanguageProvider);
    final isIndo = currentLocale.languageCode == 'id';
    String t(String en, String id) => isIndo ? id : en;

    final currentVoiceOptions = _currentVoiceOptions;

    final userAsync = ref.watch(firestoreUserProvider);
    final configAsync = ref.watch(appConfigProvider);

    final int textLength = _scriptController.text.trim().length;
    int estimatedScenes = (textLength / 150).ceil();
    if (estimatedScenes == 0 && textLength > 0) estimatedScenes = 1;
    
    int currentBalance = 0;
    int costPerScene = 0;
    bool configReady = false;
    bool userReady = false;

    userAsync.whenData((user) {
      currentBalance = user.tokenBalance;
      userReady = true;
    });

    configAsync.whenData((config) {
      costPerScene = config.costs.motion_per_scene;
      configReady = true;
    });

    final int requiredTokens = estimatedScenes * costPerScene;
    final bool hasSufficientFunds = currentBalance >= requiredTokens;
    final bool hasInput = textLength > 0;
    
    // [FITUR BARU] Kondisi validasi kemunculan pop up
    final bool isOutOfTokens = hasInput && !hasSufficientFunds;
    final bool canSubmit = hasInput && hasSufficientFunds && !_isLoading && userReady && configReady;

    return Theme(
      data: AppTheme.darkTheme,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('VMotion'),
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
        // [FITUR BARU] Menggunakan SafeArea & Stack agar Pop Up mengambang dinamis
        body: SafeArea(
          child: Stack(
            children: [
              // --- FORM UTAMA KONTEN ---
              Positioned.fill(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _titleController,
                          maxLength: 40,
                          decoration: InputDecoration(
                            labelText: t('Project Title', 'Judul Proyek'),
                            hintText: t('e.g., "My First Explainer Video"', 'Cth: "Video Penjelasanku"'),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return t('Please enter a project title.', 'Mohon isi judul proyek.');
                            }
                            if (value.length > 40) {
                              return t('Title cannot exceed 40 characters.', 'Judul maksimal 40 karakter.');
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),

                        TextFormField(
                          controller: _scriptController,
                          maxLines: 10,
                          maxLength: 15000,
                          decoration: InputDecoration(
                            labelText: t('Paste or send your narration here..', 'Paste atau kirim narasimu kesini'),
                            hintText: t('Paste or type your full video Narration here...', 'Tempel atau ketik naskah narasi lengkap di sini...'),
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
                                  'Landscape (16:9)': '16:9',
                                  'Potrait (9:16)': '9:16',
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
                        
                        // --- KATEGORI_UX_OTOMATIS (NO_URUT_03): UI Toggle Subtitle ---
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black12,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white24, width: 1),
                          ),
                          child: SwitchListTile(
                            title: Text(
                              t('Show Subtitles', 'Tampilkan Subtitle'),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            subtitle: Text(
                              t('Auto-generate subtitles for your video', 'Buat subtitle otomatis pada video'),
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            value: _showSubtitles,
                            activeColor: Colors.blue,
                            onChanged: (bool value) {
                              setState(() {
                                _showSubtitles = value;
                              });
                            },
                          ),
                        ),
                        // --- AKHIR TAMBAHAN ---
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
              
              // --- [FITUR BARU] POP UP ANIMASI TOKEN HABIS ---
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
                      color: Colors.green.shade600, // Background Hijau
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
                        const Expanded(
                          child: Text(
                            "Out of tokens. Upgrade or add more via the dashboard!",
                            style: TextStyle(
                              color: Colors.white, // Teks Putih
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