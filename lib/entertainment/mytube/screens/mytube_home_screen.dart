//============================================================================//
// DIREKTORI: lib/entertainment/mytube/screens/                              //
// FILE: MYTUBE_HOME_SCREEN.DART                                             //
// BERANDA EKSPLORASI MYTUBE (SHOVI NEW 4, SHOVI POPULER 6, RESPONSIVE GRID)  //
//============================================================================//

//No ke-1....................................................................//
//IMPORTS & DEPENDENCIES                                                     //
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../providers/config_provider.dart';
import '../../../providers/user_provider.dart';
import '../models/video_mytube_model.dart';
import '../services/firestore_mytube_service.dart';
import '../services/mytube_ad_service.dart'; // [BARU]: Orkestrator Iklan Terpusat MyTube
import '../view_model/mytube_feed_view_model.dart';
import 'mytube_feed_screen.dart';
import 'mytube_filter_sheet.dart';
//............................................................................//

//No ke-2....................................................................//
//WIDGET DECLARATION & STATE SETUP (SYNC NEGARA 100 NEGARA, EN/ORIGINAL FALLBACK)
class MytubeHomeScreen extends ConsumerStatefulWidget {
  const MytubeHomeScreen({super.key});

  // [SINGLE SOURCE OF TRUTH]: Cache In-Memory RAM Terpusat untuk Home & Feed Screen
  // Menjamin 0 Latensi, 0 Kuota Berulang, dan Bebas Race Condition
  static final Map<String, String> titleMemoryCache = {};

  // [KAMUS RESMI PEMETAAN NEGARA PROFIL KE 37 KODE BAHASA MYTUBE]
  static const Map<String, String> countryToLanguageCodeMap = {
    // 1. Kawasan Nusantara & Melayu
    'indonesia': 'id',
    'id': 'id',
    'malaysia': 'id',
    'brunei': 'id',

    // 2. Kawasan Asia Selatan
    'india': 'hi',
    'pakistan': 'ur',
    'bangladesh': 'bn',

    // 3. Kawasan Anglosphere (Bahasa Inggris Resmi)
    'united states': 'en',
    'united kingdom': 'en-gb',
    'australia': 'en-au',
    'canada': 'en',
    'new zealand': 'en',
    'singapore': 'en',
    'philippines': 'en',
    'ireland': 'en',
    'south africa': 'en',
    'nigeria': 'en',
    'kenya': 'en',

    // 4. Kawasan Timur Tengah & Afrika Utara (Arab)
    'saudi arabia': 'ar',
    'united arab emirates': 'ar',
    'qatar': 'ar',
    'kuwait': 'ar',
    'bahrain': 'ar',
    'oman': 'ar',
    'egypt': 'ar',
    'jordan': 'ar',
    'lebanon': 'ar',
    'iraq': 'ar',
    'yemen': 'ar',
    'morocco': 'ar',
    'algeria': 'ar',
    'tunisia': 'ar',
    'libya': 'ar',

    // 5. Kawasan Asia Timur & Tenggara
    'japan': 'ja',
    'south korea': 'ko',
    'taiwan': 'zh',
    'thailand': 'th',
    'vietnam': 'vi',

    // 6. Kawasan Hispanik & Amerika Latin (Spanyol & Portugis)
    'spain': 'es',
    'mexico': 'es-us',
    'argentina': 'es',
    'colombia': 'es',
    'chile': 'es',
    'peru': 'es',
    'ecuador': 'es',
    'venezuela': 'es',
    'brazil': 'pt',
    'portugal': 'pt',

    // 7. Kawasan Eropa Barat & Tengah
    'germany': 'de',
    'austria': 'de',
    'switzerland': 'de',
    'france': 'fr',
    'belgium': 'nl-be',
    'netherlands': 'nl',
    'italy': 'it',

    // 8. Kawasan Skandinavia & Nordik
    'denmark': 'da',
    'norway': 'no',
    'sweden': 'sv',
    'finland': 'fi',

    // 9. Kawasan Eropa Timur & Eurasia
    'russia': 'ru',
    'ukraine': 'uk',
    'poland': 'pl',
    'turkey': 'tr',
    'kazakhstan': 'ru',
    'belarus': 'ru',
  };

  // Helper Resolver Universal: Digunakan oleh Home dan Feed agar logika bahasa 100% sinkron
  static String resolveLanguageCode({
    required String? userCountry,
    required bool isAppIndo,
    String? preferredDubbing,
    String? preferredSubtitle,
  }) {
    // Prioritas 1: Preferensi DUBBING aktif pengguna
    if (preferredDubbing != null && preferredDubbing.isNotEmpty && preferredDubbing != 'off') {
      return preferredDubbing;
    }

    // Prioritas 2: Preferensi SUBTITLE aktif pengguna
    if (preferredSubtitle != null && preferredSubtitle.isNotEmpty && preferredSubtitle != 'off') {
      return preferredSubtitle;
    }

    // Prioritas 3: Lokasi Domisili Akun Pengguna (Sinkronisasi 100 Negara)
    if (userCountry != null && userCountry.trim().isNotEmpty && userCountry.trim().toLowerCase() != 'unknown') {
      final cleanCountry = userCountry.trim().toLowerCase();

      if (countryToLanguageCodeMap.containsKey(cleanCountry)) {
        return countryToLanguageCodeMap[cleanCountry]!;
      }

      if (cleanCountry.contains('indonesia')) return 'id';
      if (cleanCountry.contains('malaysia')) return 'id';
      if (cleanCountry.contains('india')) return 'hi';
      if (cleanCountry.contains('arab')) return 'ar';
      if (cleanCountry.contains('japan')) return 'ja';
      if (cleanCountry.contains('korea')) return 'ko';

      final directMapped = MytubeFeedViewModel.getLanguageCode(userCountry.trim());
      if (directMapped != 'en' || cleanCountry.contains('english') || cleanCountry.contains('united')) {
        return directMapped;
      }

      return 'en';
    }

    // Prioritas 4: Bahasa Antarmuka Aplikasi saat ini
    return isAppIndo ? 'id' : 'en';
  }

  @override
  ConsumerState<MytubeHomeScreen> createState() => _MytubeHomeScreenState();
}

class _MytubeHomeScreenState extends ConsumerState<MytubeHomeScreen> {
  // Alias Anti-Regresi: Menunjuk langsung ke Cache Terpusat MytubeHomeScreen
  static Map<String, String> get _titleMemoryCache => MytubeHomeScreen.titleMemoryCache;
  static Map<String, String> get _countryToLanguageCodeMap => MytubeHomeScreen.countryToLanguageCodeMap;

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  String? _userDubbingLangCode;
  String? _userDubbingLangName;
  String? _userSubtitleLangCode;
  String? _userSubtitleLangName;
  bool _isPreferencesLoaded = false;

  // [STATE FILTER HOME EKSPLORASI MANDIRI]
  bool _isSearchOpen = false;
  String _searchQuery = '';
  String? _selectedCategory;
  String? _selectedLocation;

  bool get _isFilterActive =>
      _searchQuery.trim().isNotEmpty ||
      _selectedCategory != null ||
      _selectedLocation != null;

  static List<String> get _languages => MytubeFeedViewModel.supportedLanguages;

  @override
  void initState() {
    super.initState();
    _loadUserPreferences();

    // [INISIALISASI IKLAN MYTUBE]: Memulai stopwatch 1 menit sejak pertama kali masuk ke Beranda
    MytubeAdService.instance.startSessionTimerIfNeeded();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUserPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dub = prefs.getString('mytube_pref_audio_lang_code');
      final dubName = prefs.getString('mytube_pref_audio_lang_name');
      final sub = prefs.getString('mytube_pref_sub_lang_code');
      final subName = prefs.getString('mytube_pref_sub_lang_name');

      if (mounted) {
        setState(() {
          _userDubbingLangCode = (dub != null && dub != 'off' && dub.isNotEmpty) ? dub : null;
          _userDubbingLangName = _userDubbingLangCode != null ? (dubName ?? MytubeFeedViewModel.getLanguageName(_userDubbingLangCode!)) : null;
          _userSubtitleLangCode = (sub != null && sub != 'off' && sub.isNotEmpty) ? sub : null;
          _userSubtitleLangName = _userSubtitleLangCode != null ? (subName ?? 'English (US)') : null;
          _isPreferencesLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isPreferencesLoaded = true);
      }
    }
  }

  // --- RESOLVER KODE BAHASA JUDUL TERBAIK BERBASIS PRIORITAS KETAT & FALLBACK EN/ORIGINAL ---
  String? _resolveTargetLanguageCode(String? userCountry, bool isAppIndo) {
    return MytubeHomeScreen.resolveLanguageCode(
      userCountry: userCountry,
      isAppIndo: isAppIndo,
      preferredDubbing: _userDubbingLangCode,
      preferredSubtitle: _userSubtitleLangCode,
    );
  }

  // --- HANDLER SEGERA SIMPAN DUBBING / SUBTITLE DARI HOME (REALTIME REACTIVE TITLES) ---
  Future<void> _setHomeAudioPreference(String? code, String? name) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (code == null) {
        await prefs.setString('mytube_pref_audio_lang_code', 'off');
        await prefs.remove('mytube_pref_audio_lang_name');
      } else {
        await prefs.setString('mytube_pref_audio_lang_code', code);
        await prefs.setString('mytube_pref_audio_lang_name', name ?? MytubeFeedViewModel.getLanguageName(code));
      }
    } catch (_) {}

    setState(() {
      _userDubbingLangCode = code;
      _userDubbingLangName = name;
    });
  }

  Future<void> _setHomeSubtitlePreference(String? code, String? name) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (code == null) {
        await prefs.setString('mytube_pref_sub_lang_code', 'off');
        await prefs.remove('mytube_pref_sub_lang_name');
      } else {
        await prefs.setString('mytube_pref_sub_lang_code', code);
        await prefs.setString('mytube_pref_sub_lang_name', name ?? 'English (US)');
      }
    } catch (_) {}

    setState(() {
      _userSubtitleLangCode = code;
      _userSubtitleLangName = name;
    });
  }

  void _clearAllFilters() {
    setState(() {
      _searchQuery = '';
      _searchController.clear();
      _selectedCategory = null;
      _selectedLocation = null;
    });
  }
//............................................................................//

//No ke-3....................................................................//
//MAIN BUILD, APPBAR (HOME ICON EXIT), BOTTOM NAV (SV CATALOG) & 3 SECTIONS  //
  @override
  Widget build(BuildContext context) {
    final currentLocale = ref.watch(appLanguageProvider);
    final isIndo = currentLocale.languageCode == 'id';
    String t(String en, String id) => isIndo ? id : en;

    final userAsync = ref.watch(firestoreUserProvider);
    final userCountry = userAsync.value?.country;
    final String? activeLangCode = _resolveTargetLanguageCode(userCountry, isIndo);

    return Scaffold(
      backgroundColor: const Color(0xFF101014),
      appBar: AppBar(
        backgroundColor: const Color(0xFF18181F),
        elevation: 0,
        titleSpacing: 0,
        // [POJOK KIRI ATAS]: Ikon Home (Tanpa Teks) untuk Keluar dari MyTube ke Dashboard Utama Majiku
        leading: IconButton(
          icon: const Icon(Icons.home_rounded, color: Colors.white, size: 24),
          tooltip: t('Main Dashboard', 'Dashboard Utama'),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).popUntil((route) => route.isFirst);
            } else {
              Navigator.of(context).pushReplacementNamed('/');
            }
          },
        ),
        title: Row(
          children: [
            // [SAKELAR KAPSUL SHORT / LONG]: Netral di Home -> Menyala saat masuk feed
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E24),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white24, width: 0.8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. Tombol Mode SHORT
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const MytubeFeedScreen(initialVideoType: 'SHORT'),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.bolt, color: Colors.white70, size: 16),
                    ),
                  ),
                  const SizedBox(width: 3),

                  // 2. Tombol Mode LONG
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const MytubeFeedScreen(initialVideoType: 'LONG'),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.tv_rounded, color: Colors.white70, size: 16),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // 1. TOMBOL PENCARIAN (SEARCH)
          IconButton(
            icon: Icon(
              _isSearchOpen ? Icons.search_off_rounded : Icons.search_rounded,
              color: _searchQuery.isNotEmpty ? Colors.amberAccent : Colors.white70,
              size: 22,
            ),
            tooltip: t('Search Video Title', 'Cari Judul Video'),
            onPressed: () {
              setState(() {
                _isSearchOpen = !_isSearchOpen;
                if (!_isSearchOpen && _searchQuery.isNotEmpty) {
                  _searchController.clear();
                  _searchQuery = '';
                }
              });
            },
          ),

          // 2. TOMBOL FILTER KONTEN (PINDAHAN DARI FEED)
          Stack(
            alignment: Alignment.topRight,
            children: [
              IconButton(
                icon: Icon(
                  Icons.tune_rounded,
                  color: (_selectedCategory != null || _selectedLocation != null)
                      ? Colors.amberAccent
                      : Colors.white70,
                  size: 22,
                ),
                tooltip: t('Filter Content', 'Filter Konten'),
                onPressed: () => _showFilterSheet(t, isIndo),
              ),
              if (_selectedCategory != null || _selectedLocation != null)
                Positioned(
                  top: 9,
                  right: 9,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Colors.amberAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),

          // 3. TOMBOL SEGARKAN (REFRESH)
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            tooltip: t('Refresh Feed', 'Segarkan Beranda'),
            onPressed: () {
              _loadUserPreferences();
              setState(() {});
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final bool isWideScreen = constraints.maxWidth >= 800;
          final int crossAxisCount = isWideScreen ? 5 : 2;
          final double horizontalPadding = isWideScreen ? 32.0 : 16.0;

          // [KUOTA RESPONSIF STANDAR]: Web 10 (2 baris x 5), HP 6 (3 baris x 2)
          final int newAndPopCount = isWideScreen ? 10 : 6;
          const int othersMaxCount = 10;

          return RefreshIndicator(
            color: Colors.amberAccent,
            backgroundColor: const Color(0xFF1E1E24),
            onRefresh: () async {
              await _loadUserPreferences();
              setState(() {});
            },
            child: SingleChildScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                16,
                horizontalPadding,
                30,
              ),
              child: _buildHomeSectionsBody(
                crossAxisCount: crossAxisCount,
                newAndPopCount: newAndPopCount,
                othersMaxCount: othersMaxCount,
                activeLangCode: activeLangCode,
                t: t,
              ),
            ),
          );
        },
      ),
      // [BOTTOM NAVIGATION BAR PERSIS FEED]: SV (Katalog Aktif Amber), CC, DUB, Koleksi
      bottomNavigationBar: _buildBottomNavigationBar(t, isIndo),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: iconColor.withOpacity(0.35), width: 1),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16.5,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.white54, fontSize: 11.5),
            ),
          ],
        ),
      ],
    );
  }

  // --- PEMANGGIL MODAL FILTER KONTEN MYTUBE DI HOME ---
  void _showFilterSheet(String Function(String, String) t, bool isIndo) {
    MytubeFilterSheet.show(
      context: context,
      initialCategory: _selectedCategory,
      initialLocation: _selectedLocation,
      t: t,
      isIndo: isIndo,
      onApplyFilter: (category, location) {
        setState(() {
          _selectedCategory = category;
          _selectedLocation = location;
        });
      },
    );
  }

  // --- BOTTOM NAVIGATION BAR (SV KATALOG BERANDA, CC, DUB, KOLEKSI) ---
  Widget _buildBottomNavigationBar(String Function(String, String) t, bool isIndo) {
    final bool isSubActive = _userSubtitleLangCode != null;
    final bool isDubActive = _userDubbingLangCode != null;

    return Container(
      padding: EdgeInsets.only(
        top: 6,
        bottom: MediaQuery.of(context).padding.bottom > 0 ? MediaQuery.of(context).padding.bottom : 6,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F12).withOpacity(0.96),
        border: const Border(top: BorderSide(color: Colors.white12, width: 0.8)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // 1. KATALOG BERANDA MYTUBE (LABEL 'SV' & IKON DAFTAR ISI GRID) -> Scroll to top saat di Home
          InkWell(
            onTap: () {
              if (_scrollController.hasClients) {
                _scrollController.animateTo(
                  0,
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOut,
                );
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.grid_view_rounded, color: Colors.amberAccent, size: 24),
                  SizedBox(height: 2),
                  Text(
                    'SV',
                    style: TextStyle(color: Colors.amberAccent, fontSize: 11.5, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),

          // 2. SUBTITLE (CC)
          InkWell(
            onTap: () => _showSubtitleModalSheet(t, isIndo),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isSubActive ? Icons.closed_caption_rounded : Icons.closed_caption_off_rounded,
                    color: isSubActive ? Colors.amberAccent : Colors.white70,
                    size: 24,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isSubActive ? 'CC (${_userSubtitleLangCode!.toUpperCase()})' : 'Subtitle',
                    style: TextStyle(
                      color: isSubActive ? Colors.amberAccent : Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. AUDIO DUBBING (DUB)
          InkWell(
            onTap: () => _showAudioModalSheet(t, isIndo),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isDubActive ? Icons.record_voice_over_rounded : Icons.voice_over_off_rounded,
                    color: isDubActive ? Colors.amberAccent : Colors.white70,
                    size: 24,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isDubActive ? 'DUB (${_userDubbingLangCode!.toUpperCase()})' : 'DUB',
                    style: TextStyle(
                      color: isDubActive ? Colors.amberAccent : Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 4. KOLEKSI (LIBRARY)
          InkWell(
            onTap: () => _showLibraryModalSheet(t, isIndo),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.bookmarks_rounded, color: Colors.white70, size: 22),
                  const SizedBox(height: 2),
                  Text(
                    t('Library', 'Koleksi'),
                    style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- A. MODAL PILIH SUBTITLE (CC) 37 BAHASA DUNIA ---
  void _showSubtitleModalSheet(String Function(String, String) t, bool isIndo) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFF1E1E24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.72,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Column(
            children: [
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.closed_caption_rounded, color: Colors.amberAccent, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        t('Video Subtitles (CC)', 'Subtitle Video (CC)'),
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  if (_userSubtitleLangCode != null)
                    TextButton(
                      onPressed: () {
                        _setHomeSubtitlePreference(null, null);
                        Navigator.of(ctx).pop();
                      },
                      child: Text(
                        t('Turn Off', 'Matikan'),
                        style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
              const Divider(color: Colors.white12, height: 18),

              Expanded(
                child: ListView.separated(
                  itemCount: _languages.length,
                  separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
                  itemBuilder: (context, idx) {
                    final langName = _languages[idx];
                    final code = MytubeFeedViewModel.getLanguageCode(langName);
                    final isCurrentActive = _userSubtitleLangCode == code;

                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      title: Text(
                        langName,
                        style: TextStyle(
                          color: isCurrentActive ? Colors.amberAccent : Colors.white,
                          fontWeight: isCurrentActive ? FontWeight.bold : FontWeight.normal,
                          fontSize: 14,
                        ),
                      ),
                      trailing: isCurrentActive
                          ? const Icon(Icons.check_circle_rounded, color: Colors.amberAccent, size: 20)
                          : null,
                      onTap: () {
                        Navigator.of(ctx).pop();
                        _setHomeSubtitlePreference(code, langName);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- B. MODAL PILIH AUDIO DUBBING 37 BAHASA DUNIA ---
  void _showAudioModalSheet(String Function(String, String) t, bool isIndo) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFF1E1E24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Column(
            children: [
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.record_voice_over_rounded, color: Colors.amberAccent, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        t('Audio Language (Dubbing)', 'Bahasa Audio (Dubbing)'),
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  if (_userDubbingLangCode != null)
                    TextButton(
                      onPressed: () {
                        _setHomeAudioPreference(null, null);
                        Navigator.of(ctx).pop();
                      },
                      child: Text(
                        t('Original Audio', 'Audio Asli'),
                        style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
              const Divider(color: Colors.white12, height: 18),

              ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                leading: Icon(
                  Icons.audiotrack_rounded,
                  color: _userDubbingLangCode == null ? Colors.amberAccent : Colors.white54,
                  size: 20,
                ),
                title: Text(
                  t('Original Video Audio', 'Audio Asli Bawaan Video'),
                  style: TextStyle(
                    color: _userDubbingLangCode == null ? Colors.amberAccent : Colors.white,
                    fontWeight: _userDubbingLangCode == null ? FontWeight.bold : FontWeight.normal,
                    fontSize: 14,
                  ),
                ),
                trailing: _userDubbingLangCode == null
                    ? const Icon(Icons.check_circle_rounded, color: Colors.amberAccent, size: 20)
                    : null,
                onTap: () {
                  Navigator.of(ctx).pop();
                  _setHomeAudioPreference(null, null);
                },
              ),
              const Divider(color: Colors.white12, height: 8),

              Expanded(
                child: ListView.separated(
                  itemCount: _languages.length,
                  separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
                  itemBuilder: (context, idx) {
                    final langName = _languages[idx];
                    final code = MytubeFeedViewModel.getLanguageCode(langName);
                    final isCurrentActive = _userDubbingLangCode == code;

                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      title: Text(
                        langName,
                        style: TextStyle(
                          color: isCurrentActive ? Colors.amberAccent : Colors.white,
                          fontWeight: isCurrentActive ? FontWeight.bold : FontWeight.normal,
                          fontSize: 14,
                        ),
                      ),
                      trailing: isCurrentActive
                          ? const Icon(Icons.check_circle_rounded, color: Colors.amberAccent, size: 20)
                          : null,
                      onTap: () {
                        Navigator.of(ctx).pop();
                        _setHomeAudioPreference(code, langName);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- C. MODAL LEMBAR KOLEKSI SAYA (MYTUBE LIBRARY) ---
  void _showLibraryModalSheet(String Function(String, String) t, bool isIndo) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFF16161A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DefaultTabController(
          length: 2,
          child: Container(
            height: MediaQuery.of(context).size.height * 0.78,
            padding: const EdgeInsets.only(top: 14),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 12),
                TabBar(
                  indicatorColor: Colors.amberAccent,
                  labelColor: Colors.amberAccent,
                  unselectedLabelColor: Colors.white60,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                  tabs: [
                    Tab(
                      icon: const Icon(Icons.bookmark_outline, size: 20),
                      text: t('Saved Videos', 'Video Tersimpan'),
                    ),
                    Tab(
                      icon: const Icon(Icons.people_outline, size: 20),
                      text: t('Following', 'Diikuti'),
                    ),
                  ],
                ),
                const Divider(color: Colors.white12, height: 1),

                Expanded(
                  child: TabBarView(
                    children: [
                      // TAB 1: DAFTAR VIDEO TERSIMPAN
                      FutureBuilder<QuerySnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('users')
                            .doc(uid)
                            .collection('mytube_saves')
                            .orderBy('saved_at', descending: true)
                            .get(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator(color: Colors.amberAccent));
                          }

                          final docs = snapshot.data?.docs ?? [];
                          if (docs.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.bookmark_border_rounded, color: Colors.white24, size: 54),
                                  const SizedBox(height: 12),
                                  Text(
                                    t('No saved videos yet.', 'Belum ada video yang disimpan.'),
                                    style: const TextStyle(color: Colors.white54, fontSize: 13.5),
                                  ),
                                ],
                              ),
                            );
                          }

                          return ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: docs.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, idx) {
                              final data = docs[idx].data() as Map<String, dynamic>;
                              final videoId = data['video_id'] ?? docs[idx].id;
                              final videoType = data['video_type'] ?? 'SHORT';

                              return Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E1E24),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: Colors.white12,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        videoType == 'LONG' ? Icons.tv_rounded : Icons.bolt,
                                        color: videoType == 'LONG' ? Colors.orangeAccent : Colors.amberAccent,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            videoId,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            'Type: $videoType',
                                            style: const TextStyle(color: Colors.white54, fontSize: 11),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                      onPressed: () async {
                                        await docs[idx].reference.delete();
                                        (context as Element).markNeedsBuild();
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),

                      // TAB 2: DAFTAR CHANNEL YANG DIIKUTI
                      FutureBuilder<QuerySnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('users')
                            .doc(uid)
                            .collection('mytube_following')
                            .orderBy('followed_at', descending: true)
                            .get(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator(color: Colors.amberAccent));
                          }

                          final docs = snapshot.data?.docs ?? [];
                          if (docs.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.people_outline_rounded, color: Colors.white24, size: 54),
                                  const SizedBox(height: 12),
                                  Text(
                                    t('Not following any channels yet.', 'Belum mengikuti channel mana pun.'),
                                    style: const TextStyle(color: Colors.white54, fontSize: 13.5),
                                  ),
                                ],
                              ),
                            );
                          }

                          return ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: docs.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, idx) {
                              final data = docs[idx].data() as Map<String, dynamic>;
                              final channelName = data['channel_name'] ?? 'Creator';
                              final avatarUrl = data['avatar_url'] ?? '';

                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E1E24),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor: Colors.white12,
                                      backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                                      child: avatarUrl.isEmpty ? const Icon(Icons.person, color: Colors.white54) : null,
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Text(
                                        '@$channelName',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
                                      ),
                                    ),
                                    TextButton(
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.white60,
                                        backgroundColor: Colors.white10,
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                      ),
                                      onPressed: () async {
                                        await docs[idx].reference.delete();
                                        (context as Element).markNeedsBuild();
                                      },
                                      child: Text(
                                        t('Unfollow', 'Berhenti'),
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
//............................................................................//

//No ke-4....................................................................//
//GRID STREAM BUILDER & ASYNC VIDEO LISTENER (DEDUPLIKASI KONTEN LINTAS SEKSI)//
  // Fungsi Pembantu Query Paralel Shorts & Longs Secara Efisien
  Future<List<List<QueryDocumentSnapshot>>> _fetchHomeVideos() async {
    final shortsFuture = FirebaseFirestore.instance
        .collectionGroup(FirestoreMytubeService.subColShortVideo)
        .orderBy('created_at', descending: true)
        .limit(60)
        .get();

    final longsFuture = FirebaseFirestore.instance
        .collectionGroup(FirestoreMytubeService.subColLongVideo)
        .orderBy('created_at', descending: true)
        .limit(60)
        .get();

    final results = await Future.wait([shortsFuture, longsFuture]);
    return [results[0].docs, results[1].docs];
  }

  // Filter Kategori, Pencarian & Lokasi Universal
  List<VideoMytubeModel> _applyFilters(List<VideoMytubeModel> list) {
    if (!_isFilterActive) return list;
    return list.where((v) {
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.trim().toLowerCase();
        final matchTitle = v.title.toLowerCase().contains(q);
        final matchChannel = v.channelName.toLowerCase().contains(q);
        final matchDesc = v.description.toLowerCase().contains(q);
        if (!matchTitle && !matchChannel && !matchDesc) return false;
      }

      if (_selectedCategory != null && _selectedCategory!.isNotEmpty) {
        final sel = _selectedCategory!.trim().toLowerCase();
        final matchPrimary = v.category.trim().toLowerCase() == sel;
        final matchArray = v.categories.any((c) => c.trim().toLowerCase() == sel);
        if (!matchPrimary && !matchArray) return false;
      }

      if (_selectedLocation != null && _selectedLocation!.isNotEmpty) {
        final locQ = _selectedLocation!.trim().toLowerCase();
        final matchesGlobal = v.targetLocations.any((l) => l.trim().toLowerCase() == 'global');
        final matchesSpecific = v.targetLocations.any((l) => l.trim().toLowerCase() == locQ);
        if (!matchesGlobal && !matchesSpecific) return false;
      }

      return true;
    }).toList();
  }

  // --- KONTEN UTAMA BERANDA: 3 SEKSI TERPADU DENGAN DEDUPLIKASI ANTI-DUPLIKAT ---
  Widget _buildHomeSectionsBody({
    required int crossAxisCount,
    required int newAndPopCount,
    required int othersMaxCount,
    required String? activeLangCode,
    required String Function(String, String) t,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- KOTAK INPUT PENCARIAN (JIKA SEARCH DIBUKA) ---
        if (_isSearchOpen) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E24),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amberAccent.withOpacity(0.5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.search, color: Colors.amberAccent, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white, fontSize: 13.5),
                    decoration: InputDecoration(
                      hintText: t('Search title or channel...', 'Cari judul video atau kreator...'),
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val;
                      });
                    },
                  ),
                ),
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70, size: 18),
                    onPressed: () {
                      setState(() {
                        _searchController.clear();
                        _searchQuery = '';
                      });
                    },
                  ),
              ],
            ),
          ),
        ],

        // --- BANNER CHIP INDIKATOR FILTER AKTIF ---
        if (_isFilterActive) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                Text(
                  t('Filter Active:', 'Filter Aktif:'),
                  style: const TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (_selectedCategory != null)
                        Chip(
                          label: Text(_selectedCategory!),
                          labelStyle: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold),
                          backgroundColor: Colors.amberAccent,
                          deleteIconColor: Colors.black,
                          onDeleted: () => setState(() => _selectedCategory = null),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                        ),
                      if (_selectedLocation != null)
                        Chip(
                          label: Text('📍 $_selectedLocation'),
                          labelStyle: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold),
                          backgroundColor: Colors.lightGreenAccent,
                          deleteIconColor: Colors.black,
                          onDeleted: () => setState(() => _selectedLocation = null),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                        ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _clearAllFilters,
                  child: Text(t('Reset', 'Reset'), style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                ),
              ],
            ),
          ),
        ],

        // --- PEMUATAN DATA UTAMA BERANDA VIA FUTURE BUILDER ATOMIK ---
        FutureBuilder<List<List<QueryDocumentSnapshot>>>(
          future: _fetchHomeVideos(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(48),
                  child: CircularProgressIndicator(color: Colors.amberAccent),
                ),
              );
            }

            if (snapshot.hasError) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E24),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    t('Failed to load videos.', 'Gagal memuat daftar video.'),
                    style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                  ),
                ),
              );
            }

            final shortDocs = snapshot.data?[0] ?? [];
            final longDocs = snapshot.data?[1] ?? [];

            var allShorts = shortDocs
                .map((doc) => VideoMytubeModel.fromFirestore(doc))
                .where((v) => v.videoUrl.isNotEmpty || v.streamingUrl.isNotEmpty)
                .toList();

            var allLongs = longDocs
                .map((doc) => VideoMytubeModel.fromFirestore(doc))
                .where((v) => v.videoUrl.isNotEmpty || v.streamingUrl.isNotEmpty)
                .toList();

            // Terapkan filter pencarian, kategori, dan lokasi
            final filteredShorts = _applyFilters(allShorts);
            final filteredLongs = _applyFilters(allLongs);

            // ==========================================================
            // LOGIKA DEDUPLIKASI KETAT & PERINGKAT 3 SEKSI
            // ==========================================================
            final Set<String> displayedVideoIds = {};

            // 1. SEKSI NEW: Ambil video short rilis terbaru
            final newVideos = filteredShorts.take(newAndPopCount).toList();
            displayedVideoIds.addAll(newVideos.map((v) => v.id));

            // 2. SEKSI POPULER: Ambil video short terpopuler di luar video New
            final popularCandidates = filteredShorts.where((v) => !displayedVideoIds.contains(v.id)).toList();
            popularCandidates.sort((a, b) => b.viewsCount.compareTo(a.viewsCount));
            final popularVideos = popularCandidates.take(newAndPopCount).toList();
            displayedVideoIds.addAll(popularVideos.map((v) => v.id));

            // 3. SEKSI OTHERS (HYBRID CAMPURAN SHORTS & LONGS):
            // Kumpulkan seluruh video yang belum muncul di New maupun Populer
            final othersPool = [...filteredShorts, ...filteredLongs]
                .where((v) => !displayedVideoIds.contains(v.id))
                .toList();
            // Urutkan berdasarkan views terbanyak (highest views first)
            othersPool.sort((a, b) => b.viewsCount.compareTo(a.viewsCount));
            // Ambil maksimal 10 video
            final othersVideos = othersPool.take(othersMaxCount).toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ==========================================================
                // SEKSI 1: SHOVI NEW (RESPONSIF: WEB 10, HP 6)
                // ==========================================================
                _buildSectionHeader(
                  title: 'ShoVi New',
                  subtitle: t('Latest fresh short content', 'Konten video short paling baru'),
                  icon: Icons.fiber_new_rounded,
                  iconColor: Colors.amberAccent,
                ),
                const SizedBox(height: 14),

                _buildVideoGrid(
                  videos: newVideos,
                  crossAxisCount: crossAxisCount,
                  activeLangCode: activeLangCode,
                  t: t,
                ),

                const SizedBox(height: 36),

                // ==========================================================
                // SEKSI 2: SHOVI POPULER (RESPONSIF: WEB 10, HP 6)
                // ==========================================================
                _buildSectionHeader(
                  title: 'ShoVi Populer',
                  subtitle: t('Most watched trending videos', 'Video terpopuler paling banyak ditonton'),
                  icon: Icons.local_fire_department_rounded,
                  iconColor: Colors.deepOrangeAccent,
                ),
                const SizedBox(height: 14),

                _buildVideoGrid(
                  videos: popularVideos,
                  crossAxisCount: crossAxisCount,
                  activeLangCode: activeLangCode,
                  t: t,
                ),

                const SizedBox(height: 36),

                // ==========================================================
                // SEKSI 3: SHOVI OTHERS (HYBRID: CAMPURAN ADAPTIF SHORTS & LONGS)
                // ==========================================================
                _buildSectionHeader(
                  title: 'ShoVi Others',
                  subtitle: t('Mixed trending shorts & long videos', 'Campuran video short & panjang terpopuler pilihan'),
                  icon: Icons.auto_awesome_motion_rounded,
                  iconColor: Colors.cyanAccent,
                ),
                const SizedBox(height: 14),

                _buildOthersHybridSection(
                  videos: othersVideos,
                  activeLangCode: activeLangCode,
                  t: t,
                ),

                const SizedBox(height: 30),
              ],
            );
          },
        ),
      ],
    );
  }

  // --- GRID RENDERER RESPONSIF KHUSUS SHORTS (NEW & POPULER) ---
  Widget _buildVideoGrid({
    required List<VideoMytubeModel> videos,
    required int crossAxisCount,
    required String? activeLangCode,
    required String Function(String, String) t,
  }) {
    if (videos.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A22),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white12),
        ),
        child: Center(
          child: Text(
            t('No videos available in this section.', 'Belum ada video tersedia di bagian ini.'),
            style: const TextStyle(color: Colors.white54, fontSize: 12.5),
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 14,
        mainAxisSpacing: 18,
        childAspectRatio: 0.52, // Standar rasio tegak potret Shorts
      ),
      itemCount: videos.length,
      itemBuilder: (context, index) {
        final video = videos[index];
        return _buildVideoCard(video, activeLangCode, t);
      },
    );
  }

  // --- TATA LETAK HIBRIDA SHOVI OTHERS: ADAPTIF LONGS (16:9) & SHORTS (9:16) BERDAMPINGAN ---
  Widget _buildOthersHybridSection({
    required List<VideoMytubeModel> videos,
    required String? activeLangCode,
    required String Function(String, String) t,
  }) {
    if (videos.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A22),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white12),
        ),
        child: Center(
          child: Text(
            t('No videos available in this section.', 'Belum ada video tersedia di bagian ini.'),
            style: const TextStyle(color: Colors.white54, fontSize: 12.5),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isWideScreen = constraints.maxWidth >= 800;

        // Kelompokkan video berurutan menggunakan Dart Record bawaan (Bebas dari deklarasi class bersarang)
        final batches = <({bool isLong, List<VideoMytubeModel> videos})>[];
        bool? currentIsLong;
        List<VideoMytubeModel> currentList = [];

        for (final v in videos) {
          final isLong = v.videoType == 'LONG' || v.isLandscape;
          if (currentIsLong == null) {
            currentIsLong = isLong;
            currentList.add(v);
          } else if (currentIsLong == isLong) {
            currentList.add(v);
          } else {
            batches.add((isLong: currentIsLong, videos: List.from(currentList)));
            currentIsLong = isLong;
            currentList = [v];
          }
        }
        if (currentList.isNotEmpty && currentIsLong != null) {
          batches.add((isLong: currentIsLong, videos: currentList));
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: batches.map((batch) {
            // [STANDAR ORIENTASI PRESISI]:
            // Longs: 1 baris isi 1 di HP, 1 baris isi 3 di PC Web (Rasio 1.20)
            // Shorts: 1 baris isi 2 di HP, 1 baris isi 5 di PC Web (Rasio 0.52)
            final int batchCols = batch.isLong
                ? (isWideScreen ? 3 : 1)
                : (isWideScreen ? 5 : 2);
            final double batchRatio = batch.isLong ? 1.20 : 0.52;

            return Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: batchCols,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 18,
                  childAspectRatio: batchRatio,
                ),
                itemCount: batch.videos.length,
                itemBuilder: (context, idx) {
                  final video = batch.videos[idx];
                  return _buildVideoCard(video, activeLangCode, t);
                },
              ),
            );
          }).toList(),
        );
      },
    );
  }
//............................................................................//

//No ke-5....................................................................//
//VIDEO CARD: JUDUL DI ATAS THUMBNAIL, ADAPTIF 9:16 / 16:9 & ON-DEMAND TITLES//
  // Guard in-flight untuk mencegah pemanggilan ganda ke Cloud Function
  static final Set<String> _inFlightTitleRequests = {};

  Widget _buildVideoCard(
    VideoMytubeModel video,
    String? activeLangCode,
    String Function(String, String) t,
  ) {
    // Identifikasi format video (Long / Lanskap vs Short Vertikal)
    final bool isLongVideo = video.videoType == 'LONG' || video.isLandscape;
    final double targetPosterRatio = isLongVideo ? (16 / 9) : (9 / 16);

    // [DATA KATEGORI RESMI]: Utamakan categories array, fallback ke primary category
    final List<String> effectiveCategories = video.categories.isNotEmpty
        ? video.categories
        : (video.category.trim().isNotEmpty ? [video.category.trim()] : const ['Comedy & Funny']);

    return InkWell(
      onTap: () {
        // [NATURAL BREAK INTERSTITIAL & PRECISION JUMP]: Teruskan initialVideoId dan initialVideoType secara presisi
        MytubeAdService.instance.showAdIfEligible(
          onActionProceed: () {
            if (mounted) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => MytubeFeedScreen(
                    initialVideoId: video.id,
                    initialVideoType: isLongVideo ? 'LONG' : 'SHORT',
                  ),
                ),
              );
            }
          },
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A22),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12, width: 0.8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. JUDUL DI ATAS THUMBNAIL (TERJEMAHAN OTOMATIS CERDAS DARI TITLES/ - HURUF BESAR/KAPITAL)
            SizedBox(
              height: 36,
              child: _buildDynamicTitle(video, activeLangCode),
            ),
            const SizedBox(height: 6),

            // 2. POSTER THUMBNAIL ADAPTIF (16:9 UNTUK LONG VIDEO, 9:16 UNTUK SHORTS)
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: targetPosterRatio,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Container(color: const Color(0xFF141418)),
                        if (video.thumbnailUrl.isNotEmpty)
                          Image.network(
                            video.thumbnailUrl,
                            fit: BoxFit.contain,
                            alignment: Alignment.center,
                            errorBuilder: (_, __, ___) => _buildFallbackPoster(),
                            loadingBuilder: (_, child, progress) {
                              if (progress == null) return child;
                              return Container(color: const Color(0xFF141418));
                            },
                          )
                        else
                          _buildFallbackPoster(),

                        // Durasi Video di Sudut Kanan Bawah
                        Positioned(
                          bottom: 6,
                          right: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _formatDuration(video.durationSeconds),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),

            // 3. BARIS 1: KATEGORI 1 (SELALU RATA KIRI)
            Align(
              alignment: Alignment.centerLeft,
              child: _buildCategoryBadge(effectiveCategories.first),
            ),
            const SizedBox(height: 4),

            // 4. BARIS 2: VIEWS (RATA KIRI) & JIKA ADA KATEGORI 2 (RATA KANAN PENUH SEJAJAR VIEW)
            Row(
              children: [
                // Views di Pojok Kiri Bawah
                const Icon(Icons.remove_red_eye_rounded, color: Colors.white38, size: 12),
                const SizedBox(width: 4),
                Text(
                  _formatCompact(video.viewsCount),
                  style: const TextStyle(color: Colors.white38, fontSize: 10.5),
                ),

                const SizedBox(width: 6),

                // Kategori 2 (Jika Ada): Rata Kanan Penuh Mengisi Sisa Ruang Baris
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: effectiveCategories.length > 1
                        ? _buildCategoryBadge(effectiveCategories[1])
                        : const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- HELPER CHIP BADGE KATEGORI INDIVIDUAL ---
  Widget _buildCategoryBadge(String categoryName) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        categoryName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.amberAccent,
          fontSize: 9.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // --- BUILDER JUDUL DINAMIS: MEMBACA BERKAS .TXT DARI STORAGE / ON-DEMAND AUTO-HEAL (HURUF KAPITAL) ---
  Widget _buildDynamicTitle(VideoMytubeModel video, String? targetLangCode) {
    if (targetLangCode != null && targetLangCode.isNotEmpty) {
      // 1. Cek dari map titles dokumen Firestore
      final sharedTitleUrl = video.titles?[targetLangCode];
      if (sharedTitleUrl != null && sharedTitleUrl.isNotEmpty) {
        return _buildCachedTextTitle(sharedTitleUrl, fallbackTitle: video.title);
      }

      // 2. Cek apakah teks terjemahan sudah ada di cache RAM lokal
      final memoryKey = '${video.id}_$targetLangCode';
      if (_titleMemoryCache.containsKey(memoryKey)) {
        return Text(
          _titleMemoryCache[memoryKey]!.toUpperCase(),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            height: 1.25,
          ),
        );
      }

      // 3. [AUTO-HEAL TRIGGER UNTUK VIDEO LAMA]: Panggil Cloud Function secara senyap di latar belakang
      _triggerOnDemandTitleTranslation(video, targetLangCode);
    }

    // Fallback: Tampilkan judul asli bawaan video dalam huruf kapital
    return Text(
      video.title.toUpperCase(),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.bold,
        height: 1.25,
      ),
    );
  }

  // Pemicu On-Demand Pembuatan File titles/{langCode}.txt untuk Video Lama
  void _triggerOnDemandTitleTranslation(VideoMytubeModel video, String targetLangCode) {
    final requestKey = '${video.id}_$targetLangCode';
    if (_inFlightTitleRequests.contains(requestKey)) return;
    _inFlightTitleRequests.add(requestKey);

    final targetLangName = MytubeFeedViewModel.getLanguageName(targetLangCode);

    FirebaseFunctions.instanceFor(region: 'asia-southeast2')
        .httpsCallable('generateTitleOnDemand')
        .call({
      'videoId': video.id,
      'creatorEmail': video.uploaderEmail,
      'channelId': video.channelId,
      'videoType': video.videoType,
      'targetLanguageCode': targetLangCode,
      'targetLanguageName': targetLangName,
    }).then((result) {
      final data = result.data as Map<dynamic, dynamic>? ?? {};
      final String? titleText = data['titleText'] as String?;
      final String? url = data['url'] as String?;

      if (titleText != null && titleText.trim().isNotEmpty) {
        final upperTitle = titleText.trim().toUpperCase();
        _titleMemoryCache[requestKey] = upperTitle;
        if (url != null && url.isNotEmpty) {
          _titleMemoryCache[url] = upperTitle;
        }
        if (mounted) setState(() {});
      } else if (url != null && url.isNotEmpty) {
        http.get(Uri.parse(url)).then((res) {
          if (res.statusCode == 200 && res.body.trim().isNotEmpty) {
            final upperTitle = res.body.trim().toUpperCase();
            _titleMemoryCache[requestKey] = upperTitle;
            _titleMemoryCache[url] = upperTitle;
            if (mounted) setState(() {});
          }
        }).catchError((_) {});
      }
    }).catchError((err) {
      debugPrint('[MYTUBE TITLE AUTO-HEAL ERROR]: $err');
    }).whenComplete(() {
      _inFlightTitleRequests.remove(requestKey);
    });
  }

  Widget _buildCachedTextTitle(String storageTxtUrl, {required String fallbackTitle}) {
    if (_titleMemoryCache.containsKey(storageTxtUrl)) {
      return Text(
        _titleMemoryCache[storageTxtUrl]!.toUpperCase(),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          height: 1.25,
        ),
      );
    }

    return FutureBuilder<String>(
      future: http.get(Uri.parse(storageTxtUrl)).then((res) {
        if (res.statusCode == 200 && res.body.trim().isNotEmpty) {
          final text = res.body.trim().toUpperCase();
          _titleMemoryCache[storageTxtUrl] = text;
          return text;
        }
        return fallbackTitle.toUpperCase();
      }).catchError((_) => fallbackTitle.toUpperCase()),
      builder: (context, snap) {
        final titleText = (snap.data ?? fallbackTitle).toUpperCase();
        return Text(
          titleText,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            height: 1.25,
          ),
        );
      },
    );
  }

  Widget _buildFallbackPoster() {
    return Container(
      color: const Color(0xFF141418),
      child: const Center(
        child: Icon(Icons.play_circle_fill_rounded, color: Colors.white24, size: 36),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _formatCompact(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return '$count';
  }
}
//............................................................................//