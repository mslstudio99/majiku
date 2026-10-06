//.......................................................//
// NAMA FILE: FREE_DAILY_QUOTES_SCREEN.DART              //
// DIREKTORI: LIB/SCREENS_DAILY_FREE/                    //
// DESKRIPSI: FEED KATA BIJAK HARIAN VERTIKAL (OFFLINE)  //
//.......................................................//

//No ke-1: IMPOR & SETUP DEPENDENSI......................//
//.......................................................//
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models_daily_free/quote_model.dart';
import '../data_quotes/all_data.dart';
import '../providers/config_provider.dart'; 
import '../services/ad_service.dart';
import '../services/firestore_service.dart'; // [BARU]: Akses Pelacak Aktivitas Firestore User Center
//.......................................................//

//No ke-2: STATEFUL WIDGET KELAS UTAMA...................//
//.......................................................//
class FreeDailyQuotesScreen extends ConsumerStatefulWidget {
  const FreeDailyQuotesScreen({super.key});

  @override
  ConsumerState<FreeDailyQuotesScreen> createState() => _FreeDailyQuotesScreenState();
}
//.......................................................//

//No ke-3: STATE VARIABLES & LIFECYCLE (INIT/DISPOSE)....//
//.......................................................//
class _FreeDailyQuotesScreenState extends ConsumerState<FreeDailyQuotesScreen> {
  List<Quote> _allQuotes = [];
  List<Quote> _displayedQuotes = [];
  final Set<String> _likedQuoteIds = {};
  
  String? _selectedCategoryCanonical;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final PageController _pageController = PageController();
  bool _isLoading = true;

  // State Toggle Bahasa Bilingual (ID vs EN)
  bool _isEnglishMode = false;

  // [BARU]: Timer Periodik untuk Iklan
  Timer? _periodicAdTimer;

  final List<String> _canonicalCategories = [
    'Semua Kategori',
    'Cinta',
    'Galau',
    'Logika',
    'Relate',
    'Self Love',
    'Semangat',
    'Sukses',
    'Syukur',
  ];

  @override
  void initState() {
    super.initState();
    
    // Inisialisasi awal mengikuti locale aplikasi
    final currentLocale = ref.read(appLanguageProvider);
    _isEnglishMode = currentLocale.languageCode != 'id';

    _loadQuotesData();

    // 1. Pre-load iklan Interstitial sejak awal layar dibuka
    AdService().loadInterstitial();

    // 2. --- [LOG AKTIVITAS FITUR: KUNJUNGAN DAILY QUOTES (VISIT)] ---
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(firestoreServiceProvider).logFeatureActivity(
          featureKey: 'daily_free',
          subFeatureKey: 'daily_quotes',
          eventType: 'visit',
        );
      }
    });
    // -----------------------------------------------------------------

    // 3. [BARU]: Timer Periodik 7 Menit untuk Pembaca Santai
    // Memicu iklan jika pengguna diam/merenung membaca satu quote dalam waktu lama
    _periodicAdTimer = Timer.periodic(const Duration(minutes: 7), (timer) {
      if (mounted && !kIsWeb) {
        _triggerAdWithTracking();
      }
    });
  }

  @override
  void dispose() {
    // Bersihkan semua controller dan timer untuk mencegah memory leak
    _periodicAdTimer?.cancel();
    _pageController.dispose();
    _searchController.dispose();
    super.dispose();
  }
//.......................................................//

//No ke-4: LOGIKA FILTER, PENCARIAN & HELPER KATEGORI...//
//.......................................................//
  /// [BARU]: Pemicu Iklan berdasarkan Scroll dengan Pelacak Klik (Conversion) ke Firestore
  void _triggerAdWithTracking() {
    AdService().showInterstitial(
      onAdClicked: () {
        if (mounted) {
          ref.read(firestoreServiceProvider).logFeatureActivity(
            featureKey: 'daily_free',
            subFeatureKey: 'daily_quotes',
            eventType: 'conversion', // <--- Mencatat Klik Iklan AdMob ke Firestore!
          );
        }
      },
    );
  }

  void _loadQuotesData() {
    final data = getAllQuotes();
    data.shuffle();

    setState(() {
      _allQuotes = data;
      _applyFilters();
      _isLoading = false;
    });
  }

  List<String> get _autocompleteSuggestions {
    final Set<String> suggestions = {};
    for (var q in _allQuotes) {
      if (q.author.trim().isNotEmpty && q.author.toLowerCase() != 'anonym') {
        suggestions.add(q.author.trim());
      }
    }
    return suggestions.toList();
  }

  String _getCategoryLabel(String category, bool isIndo) {
    final Map<String, String> idToEn = {
      'Semua Kategori': 'All Categories',
      'Cinta': 'Love',
      'Galau': 'Heartbreak',
      'Logika': 'Logic',
      'Relate': 'Relatable',
      'Self Love': 'Self Love',
      'Semangat': 'Motivation',
      'Sukses': 'Success',
      'Syukur': 'Gratitude',
      'Umum': 'General',
    };

    final Map<String, String> enToId = {
      'All Categories': 'Semua Kategori',
      'Love': 'Cinta',
      'Heartbreak': 'Galau',
      'Logic': 'Logika',
      'Relatable': 'Relate',
      'Self Love': 'Self Love',
      'Motivation': 'Semangat',
      'Success': 'Sukses',
      'Gratitude': 'Syukur',
      'General': 'Umum',
    };

    final key = category.trim();
    if (isIndo) {
      return enToId[key] ?? key;
    } else {
      return idToEn[key] ?? key;
    }
  }

  void _applyFilters() {
    List<Quote> filtered = List.from(_allQuotes);

    // 1. Filter Berdasarkan Kategori
    if (_selectedCategoryCanonical != null && _selectedCategoryCanonical != 'Semua Kategori') {
      final target = _selectedCategoryCanonical!.trim().toLowerCase();
      filtered = filtered.where((q) {
        final cat = q.category.trim().toLowerCase();
        return cat == target || 
               _getCategoryLabel(cat, true).toLowerCase() == target ||
               _getCategoryLabel(cat, false).toLowerCase() == target;
      }).toList();
    }

    // 2. Filter Pencarian Universal (Penulis & Isi Teks)
    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.trim().toLowerCase();
      filtered = filtered.where((q) {
        final bool matchAuthor = q.author.trim().toLowerCase().contains(query);
        final bool matchText = q.text.trim().toLowerCase().contains(query);
        final bool matchTextEn = (q.textEn ?? '').trim().toLowerCase().contains(query);
        final bool matchCategory = q.category.trim().toLowerCase().contains(query);
        return matchAuthor || matchText || matchTextEn || matchCategory;
      }).toList();
    }

    _displayedQuotes = filtered;
  }

  void _onCategorySelected(String canonicalCategory) {
    setState(() {
      if (canonicalCategory == 'Semua Kategori') {
        _selectedCategoryCanonical = null;
      } else {
        _selectedCategoryCanonical = canonicalCategory;
      }
      _applyFilters();
    });

    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _applyFilters();
    });

    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }
  }

  void _clearSearch() {
    _searchController.clear();
    FocusScope.of(context).unfocus();
    setState(() {
      _searchQuery = '';
      _applyFilters();
    });

    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }
  }
//.......................................................//

//No ke-5: BUILDER UTAMA (PAGEVIEW & KONTROL ATAS)........//
//.......................................................//
  @override
  Widget build(BuildContext context) {
    final isIndo = !_isEnglishMode;

    final String categoryButtonLabel = _selectedCategoryCanonical == null
        ? (isIndo ? "Kategori" : "Category")
        : _getCategoryLabel(_selectedCategoryCanonical!, isIndo);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF00E5FF)),
              )
            : Stack(
                children: [
                  // 1. Feed Scroll Vertikal (Gaya TikTok / Reels)
                  _displayedQuotes.isEmpty
                      ? _buildEmptyState(isIndo)
                      : PageView.builder(
                          controller: _pageController,
                          scrollDirection: Axis.vertical,
                          itemCount: _displayedQuotes.length,
                          // [LOGIKA SINKRON]: Pemicu Iklan Setiap 7 Scroll + Pelacak Klik
                          onPageChanged: (int index) {
                            if ((index + 1) % 7 == 0) {
                              if (!kIsWeb) {
                                _triggerAdWithTracking();
                              }
                            }
                          },
                          itemBuilder: (context, index) {
                            return _buildQuoteCard(_displayedQuotes[index], context, isIndo);
                          },
                        ),

                  // 2. Baris Kontrol Atas (Back, Kategori, Cari & Toggle Bilingual)
                  Positioned(
                    top: 14,
                    left: 12,
                    right: 12,
                    child: Row(
                      children: [
                        // Tombol Kembali ke Dashboard Majiku
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E1E),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Colors.white),
                            onPressed: () => Navigator.of(context).pop(),
                            tooltip: isIndo ? "Kembali" : "Back",
                          ),
                        ),

                        const SizedBox(width: 8),

                        // Tombol Kategori
                        InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => _showCategoryFilterBottomSheet(isIndo),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            decoration: BoxDecoration(
                              color: _selectedCategoryCanonical != null 
                                  ? const Color(0xFF00E5FF) 
                                  : const Color(0xFF1E1E1E),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _selectedCategoryCanonical != null 
                                    ? const Color(0xFF00E5FF) 
                                    : Colors.white12,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _selectedCategoryCanonical != null 
                                      ? Icons.filter_alt_rounded 
                                      : Icons.grid_view_rounded,
                                  color: _selectedCategoryCanonical != null ? Colors.black : Colors.white70,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  categoryButtonLabel,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: _selectedCategoryCanonical != null ? Colors.black : Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(width: 8),

                        // Kolom Pencarian Universal
                        Expanded(
                          child: _buildSearchField(isIndo),
                        ),

                        const SizedBox(width: 8),

                        // Tombol Bilingual Toggle (Kanan Atas)
                        _buildLanguageToggle(),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
//.......................................................//

//No ke-6: WIDGET KARTU QUOTE (FULL SCREEN / TIKTOK STYLE)//
//.......................................................//
  Widget _buildQuoteCard(Quote quote, BuildContext context, bool isIndo) {
    final String quoteIdentifier = (quote.id != null && quote.id!.trim().isNotEmpty) 
        ? quote.id!.trim() 
        : quote.text.trim();
        
    final bool isLiked = _likedQuoteIds.contains(quoteIdentifier);

    final int baseLikes = quote.effectiveLikes;
    final int displayLikes = isLiked ? baseLikes + 1 : baseLikes;
    final int displayViews = quote.effectiveViews;

    final String translatedCategory = _getCategoryLabel(quote.category, isIndo);

    // [BILINGUAL SWITCHER]: Otomatis pakai textEn jika mode Inggris aktif
    final String quoteText = (!isIndo && quote.textEn != null && quote.textEn!.isNotEmpty)
        ? quote.textEn!
        : quote.text;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 76),
      child: Center(
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. Header: Penulis & Badge Kategori
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00E5FF).withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.format_quote_rounded, size: 20, color: Color(0xFF00E5FF)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            quote.author,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E5FF).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.3)),
                    ),
                    child: Text(
                      translatedCategory.toUpperCase(),
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF00E5FF),
                        fontWeight: FontWeight.w700, 
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 36),
              
              // 2. Isi Teks Quote di Tengah
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0),
                child: Text(
                  '"$quoteText"',
                  style: GoogleFonts.lora(
                    fontSize: 22, 
                    color: const Color(0xFFF0F0F0),
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              
              const SizedBox(height: 36),
              
              // 3. Footer: Tayangan, Tombol Copy Teks, & Tombol Like
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Jumlah Tayangan (Organik)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.visibility_outlined, size: 16, color: Colors.grey.shade500),
                      const SizedBox(width: 6),
                      Text(
                        _formatNumber(displayViews),
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.grey.shade400,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),

                  // Aksi: Salin Teks & Suka
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Tombol Salin Quote
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 20, color: Colors.white70),
                        tooltip: isIndo ? "Salin Kata Bijak" : "Copy Quote",
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: '"$quoteText" - ${quote.author}'));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(isIndo ? 'Quote berhasil disalin!' : 'Quote copied to clipboard!'),
                              backgroundColor: const Color(0xFF00E5FF),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                      
                      const SizedBox(width: 6),

                      // Tombol Suka (Lokal)
                      InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          setState(() {
                            if (isLiked) {
                              _likedQuoteIds.remove(quoteIdentifier);
                            } else {
                              _likedQuoteIds.add(quoteIdentifier);
                            }
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isLiked ? Colors.redAccent.withOpacity(0.15) : Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isLiked ? Colors.redAccent : Colors.white12,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                color: isLiked ? Colors.redAccent : Colors.white70,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _formatNumber(displayLikes),
                                style: GoogleFonts.poppins(
                                  color: isLiked ? Colors.redAccent : Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isIndo) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 70, color: Colors.grey.shade600),
            const SizedBox(height: 16),
            Text(
              isIndo ? "Tidak Ada Quote yang Sesuai" : "No Matching Quotes Found",
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              isIndo 
                ? "Coba ubah kata kunci pencarian atau ganti kategori."
                : "Try changing the search keyword or select another category.",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade400),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                _clearSearch();
                _onCategorySelected('Semua Kategori');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E5FF),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: Text(
                isIndo ? "Reset Filter" : "Reset Filter",
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}k';
    }
    return number.toString();
  }
//.......................................................//

//No ke-7: KOMPONEN KONTROL ATAS & BOTTOM SHEET FILTER...//
//.......................................................//
  // [BARU]: Widget Tombol Switcher Bilingual (ID <-> EN)
  Widget _buildLanguageToggle() {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        setState(() {
          _isEnglishMode = !_isEnglishMode;
        });
      },
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF00E5FF).withOpacity(0.4),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _isEnglishMode ? "🇺🇸 EN" : "🇮🇩 ID",
              style: const TextStyle(
                color: Color(0xFF00E5FF),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField(bool isIndo) {
    return RawAutocomplete<String>(
      textEditingController: _searchController,
      focusNode: FocusNode(),
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.trim().isEmpty) {
          return const Iterable<String>.empty();
        }
        final query = textEditingValue.text.trim().toLowerCase();
        return _autocompleteSuggestions.where((String item) {
          return item.toLowerCase().contains(query);
        });
      },
      onSelected: (String selectedSuggestion) {
        _searchController.text = selectedSuggestion;
        _onSearchChanged(selectedSuggestion);
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return Container(
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white12),
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            onChanged: _onSearchChanged,
            style: const TextStyle(fontSize: 13, color: Colors.white),
            decoration: InputDecoration(
              hintText: isIndo ? "Cari..." : "Search...",
              hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Colors.grey),
              prefixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 16, color: Colors.grey),
                      onPressed: _clearSearch,
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: InputBorder.none,
            ),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(16),
            color: const Color(0xFF252525),
            child: Container(
              width: 220,
              constraints: const BoxConstraints(maxHeight: 220),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 6),
                itemCount: options.length,
                itemBuilder: (BuildContext context, int index) {
                  final String suggestion = options.elementAt(index);
                  return InkWell(
                    onTap: () => onSelected(suggestion),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          const Icon(Icons.person_search_rounded, size: 16, color: Color(0xFF00E5FF)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              suggestion,
                              style: const TextStyle(fontSize: 12, color: Colors.white),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  void _showCategoryFilterBottomSheet(bool isIndo) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade700,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  isIndo ? "Pilih Kategori Quote" : "Select Quote Category",
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 8),
                Divider(color: Colors.grey.shade800),
                Expanded(
                  child: ListView.builder(
                    itemCount: _canonicalCategories.length,
                    itemBuilder: (context, index) {
                      final canonicalCat = _canonicalCategories[index];
                      final bool isAll = canonicalCat == 'Semua Kategori';
                      final bool isSelected = isAll 
                          ? (_selectedCategoryCanonical == null)
                          : (_selectedCategoryCanonical == canonicalCat);

                      final String displayLabel = _getCategoryLabel(canonicalCat, isIndo);

                      return ListTile(
                        leading: Icon(
                          isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                          color: isSelected ? const Color(0xFF00E5FF) : Colors.grey.shade600,
                        ),
                        title: Text(
                          isAll 
                            ? (isIndo ? "Semua Kategori (Koleksi Penuh)" : "All Categories (Full Collection)") 
                            : displayLabel,
                          style: GoogleFonts.poppins(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? const Color(0xFF00E5FF) : Colors.white70,
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          _onCategorySelected(canonicalCat);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
//.......................................................//