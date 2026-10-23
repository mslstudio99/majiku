//============================================================================//
// DIREKTORI: lib/entertainment/mytube/screens/                              //
// FILE: MYTUBE_FILTER_SHEET.DART                                             //
// LEMBAR FILTER MANDIRI (KATEGORI, LANGUAGE, & TOPIC LOCATION 100 NEGARA)    //
//============================================================================//

//No ke-1....................................................................//
//IMPORTS & WIDGET DECLARATION                                               //
import 'package:flutter/material.dart';
import '../models/video_mytube_model.dart';
import '../view_model/mytube_feed_view_model.dart';

class MytubeFilterSheet extends StatefulWidget {
  final MytubeFeedViewModel viewModel;
  final String Function(String, String) t;
  final bool isIndo;

  const MytubeFilterSheet({
    super.key,
    required this.viewModel,
    required this.t,
    required this.isIndo,
  });

  static void show({
    required BuildContext context,
    required MytubeFeedViewModel viewModel,
    required String Function(String, String) t,
    required bool isIndo,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFF1E1E24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => MytubeFilterSheet(
        viewModel: viewModel,
        t: t,
        isIndo: isIndo,
      ),
    );
  }

  @override
  State<MytubeFilterSheet> createState() => _MytubeFilterSheetState();
}
//............................................................................//

//No ke-2....................................................................//
//STATE & INTERACTIVE UI LOGIC                                               //
class _MytubeFilterSheetState extends State<MytubeFilterSheet> {
  // Daftar 17 Kategori Resmi Terurut A-Z
  static const List<Map<String, String>> _categories = [
    {'en': 'Cartoons & Anime', 'id': 'Kartun & Anime'},
    {'en': 'Comedy & Funny', 'id': 'Lucu'},
    {'en': 'Education & Facts', 'id': 'Edukasi & Fakta'},
    {'en': 'Faith & Religion', 'id': 'Religi'},
    {'en': 'Finance & Investment', 'id': 'Keuangan'},
    {'en': 'Food & Culinary', 'id': 'Kuliner'},
    {'en': 'Health & Wellness', 'id': 'Kesehatan'},
    {'en': 'History', 'id': 'Sejarah'},
    {'en': 'Horror & Mystery', 'id': 'Horor & Misteri'},
    {'en': 'Music & Artists', 'id': 'Musik & Artis'},
    {'en': 'Myths & Legends', 'id': 'Mitos & Legenda'},
    {'en': 'Nature & Animals', 'id': 'Alam, Binatang & Tumbuhan'},
    {'en': 'News & Information', 'id': 'Berita'},
    {'en': 'Places & Travel', 'id': 'Tempat & Perjalanan'},
    {'en': 'Popular Figures', 'id': 'Tokoh Populer'},
    {'en': 'Sports & Fitness', 'id': 'Olahraga'},
    {'en': 'Technology & Gadgets', 'id': 'Teknologi'},
  ];

  // State lokal lembar filter
  String? _tempCategory;
  String? _tempLocation;

  String _selectedContinent = 'Asia';
  String _locationSearchQuery = '';
  final TextEditingController _locationSearchController = TextEditingController();
  final ScrollController _continentScrollController = ScrollController();

  // Indikator panah geser untuk memandu pengguna di layar HP
  bool _canScrollLeft = false;
  bool _canScrollRight = true;

  @override
  void initState() {
    super.initState();
    _tempCategory = widget.viewModel.selectedCategory;
    _tempLocation = widget.viewModel.selectedLocation;

    _continentScrollController.addListener(_updateContinentScrollIndicators);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateContinentScrollIndicators();
    });
  }

  void _updateContinentScrollIndicators() {
    if (!_continentScrollController.hasClients) return;
    final maxScroll = _continentScrollController.position.maxScrollExtent;
    final currentScroll = _continentScrollController.offset;

    final canLeft = currentScroll > 5;
    final canRight = currentScroll < maxScroll - 5;

    if (canLeft != _canScrollLeft || canRight != _canScrollRight) {
      if (mounted) {
        setState(() {
          _canScrollLeft = canLeft;
          _canScrollRight = canRight;
        });
      }
    }
  }

  void _scrollContinents(bool right) {
    if (!_continentScrollController.hasClients) return;
    final targetOffset = right
        ? (_continentScrollController.offset + 140.0)
        : (_continentScrollController.offset - 140.0);
    _continentScrollController.animateTo(
      targetOffset.clamp(0.0, _continentScrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _continentScrollController.removeListener(_updateContinentScrollIndicators);
    _continentScrollController.dispose();
    _locationSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    final isIndo = widget.isIndo;
    final double bottomInset = MediaQuery.of(context).padding.bottom;

    // Filter daftar negara berdasarkan pencarian atau benua aktif
    List<String> displayedCountries = [];
    if (_locationSearchQuery.trim().isNotEmpty) {
      displayedCountries = MytubeLocationDatabase.allCountries
          .where((c) => c.toLowerCase().contains(_locationSearchQuery.trim().toLowerCase()))
          .toList();
    } else {
      displayedCountries = MytubeLocationDatabase.continentCountries[_selectedContinent] ?? [];
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isWideScreen = constraints.maxWidth >= 700;

        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          padding: EdgeInsets.fromLTRB(20, 16, 20, 14.0 + bottomInset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    t('MyTube Content Filter', 'Filter Konten MyTube'),
                    style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  if (_tempCategory != null || _tempLocation != null)
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _tempCategory = null;
                          _tempLocation = null;
                        });
                        widget.viewModel.clearAllFilters();
                      },
                      child: Text(
                        t('Reset', 'Reset'),
                        style: const TextStyle(color: Colors.amberAccent, fontSize: 13),
                      ),
                    ),
                ],
              ),
              const Divider(color: Colors.white12, height: 20),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- 1. KATEGORI KONTEN (A-Z) ---
                      Text(
                        t('CONTENT CATEGORY (A-Z)', 'KATEGORI KONTEN (A-Z)'),
                        style: const TextStyle(color: Colors.amberAccent, fontSize: 12.5, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _categories.map((cat) {
                          final catEn = cat['en']!;
                          final catLabel = isIndo ? cat['id']! : cat['en']!;
                          final isSelected = _tempCategory == catEn;

                          return ChoiceChip(
                            label: Text(
                              catLabel,
                              style: TextStyle(
                                color: isSelected ? Colors.black : Colors.white,
                                fontSize: 12.5,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: Colors.amberAccent,
                            backgroundColor: const Color(0xFF2B2B36),
                            side: BorderSide(color: isSelected ? Colors.amberAccent : Colors.white12),
                            onSelected: (selected) {
                              setState(() {
                                _tempCategory = selected ? catEn : null;
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),

                      // --- 2. TOPIC LOCATION (GLOBAL + SEARCH + 6 BENUA & 100 NEGARA) ---
                      Text(
                        t('TOPIC LOCATION', 'LOKASI TOPIK'),
                        style: const TextStyle(color: Colors.amberAccent, fontSize: 12.5, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),

                      // Opsi Cepat: Global
                      InkWell(
                        onTap: () {
                          setState(() {
                            if (_tempLocation == 'Global') {
                              _tempLocation = null;
                            } else {
                              _tempLocation = 'Global';
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: _tempLocation == 'Global' ? Colors.amberAccent.withOpacity(0.2) : const Color(0xFF2B2B36),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _tempLocation == 'Global' ? Colors.amberAccent : Colors.white12,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.public,
                                color: _tempLocation == 'Global' ? Colors.amberAccent : Colors.white70,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                t('Global (Universal Content)', 'Global (Konten Universal)'),
                                style: TextStyle(
                                  color: _tempLocation == 'Global' ? Colors.amberAccent : Colors.white,
                                  fontSize: 12.5,
                                  fontWeight: _tempLocation == 'Global' ? FontWeight.bold : FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Search Bar Negara
                      TextField(
                        controller: _locationSearchController,
                        style: const TextStyle(color: Colors.white, fontSize: 13.5),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search, color: Colors.white54, size: 18),
                          hintText: t('Search country (e.g. Indonesia, Japan)...', 'Cari negara (cth: Indonesia, Japan)...'),
                          hintStyle: const TextStyle(color: Colors.white24, fontSize: 12.5),
                          filled: true,
                          fillColor: const Color(0xFF141418),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          isDense: true,
                          suffixIcon: _locationSearchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, color: Colors.white54, size: 16),
                                  onPressed: () {
                                    setState(() {
                                      _locationSearchController.clear();
                                      _locationSearchQuery = '';
                                    });
                                  },
                                )
                              : null,
                        ),
                        onChanged: (val) {
                          setState(() {
                            _locationSearchQuery = val;
                          });
                        },
                      ),
                      const SizedBox(height: 12),

                      // [NAVIGASI BENUA ADAPTIF: WRAP DI WEB PC & SCROLL BERPANAH DI LAYAR HP]
                      if (_locationSearchQuery.trim().isEmpty) ...[
                        if (isWideScreen)
                          // Tampilan Web/PC: Seluruh Benua Terhampar Lega dan Teks Bebas Terjepit
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: MytubeLocationDatabase.continents.map((continent) {
                              final isCurrent = _selectedContinent == continent;
                              return FilterChip(
                                avatar: Icon(
                                  isCurrent ? Icons.public : Icons.folder_open_rounded,
                                  color: isCurrent ? Colors.black : Colors.cyanAccent.shade100,
                                  size: 15,
                                ),
                                label: Text(continent),
                                labelStyle: TextStyle(
                                  color: isCurrent ? Colors.black : Colors.cyanAccent.shade100,
                                  fontSize: 12,
                                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                                ),
                                selected: isCurrent,
                                showCheckmark: false,
                                selectedColor: Colors.cyanAccent,
                                backgroundColor: const Color(0xFF132330),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side: BorderSide(
                                    color: isCurrent
                                        ? Colors.cyanAccent
                                        : Colors.cyanAccent.withOpacity(0.35),
                                    width: 1.0,
                                  ),
                                ),
                                onSelected: (selected) {
                                  if (selected) {
                                    setState(() {
                                      _selectedContinent = continent;
                                    });
                                  }
                                },
                              );
                            }).toList(),
                          )
                        else
                          // Tampilan HP: Scrollview Dilengkapi Panah Penunjuk di Kiri/Kanan
                          Row(
                            children: [
                              // Panah Geser Kiri (Muncul Jika Tergeser)
                              if (_canScrollLeft)
                                InkWell(
                                  onTap: () => _scrollContinents(false),
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    margin: const EdgeInsets.only(right: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF132330),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.cyanAccent.withOpacity(0.5), width: 0.8),
                                    ),
                                    child: const Icon(Icons.chevron_left_rounded, color: Colors.cyanAccent, size: 18),
                                  ),
                                ),

                              // Daftar Benua yang Dapat Digeser
                              Expanded(
                                child: SingleChildScrollView(
                                  controller: _continentScrollController,
                                  scrollDirection: Axis.horizontal,
                                  physics: const BouncingScrollPhysics(),
                                  child: Row(
                                    children: MytubeLocationDatabase.continents.map((continent) {
                                      final isCurrent = _selectedContinent == continent;
                                      return Padding(
                                        padding: const EdgeInsets.only(right: 8),
                                        child: FilterChip(
                                          avatar: Icon(
                                            isCurrent ? Icons.public : Icons.folder_open_rounded,
                                            color: isCurrent ? Colors.black : Colors.cyanAccent.shade100,
                                            size: 14,
                                          ),
                                          label: Text(continent),
                                          labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          labelStyle: TextStyle(
                                            color: isCurrent ? Colors.black : Colors.cyanAccent.shade100,
                                            fontSize: 11.5,
                                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                                          ),
                                          selected: isCurrent,
                                          showCheckmark: false,
                                          selectedColor: Colors.cyanAccent,
                                          backgroundColor: const Color(0xFF132330),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                            side: BorderSide(
                                              color: isCurrent
                                                  ? Colors.cyanAccent
                                                  : Colors.cyanAccent.withOpacity(0.35),
                                              width: 1.0,
                                            ),
                                          ),
                                          onSelected: (selected) {
                                            if (selected) {
                                              setState(() {
                                                _selectedContinent = continent;
                                              });
                                            }
                                          },
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),

                              // Panah Geser Kanan (Muncul Jika Masih Ada Konten di Kanan)
                              if (_canScrollRight)
                                InkWell(
                                  onTap: () => _scrollContinents(true),
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    margin: const EdgeInsets.only(left: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF132330),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.cyanAccent.withOpacity(0.5), width: 0.8),
                                    ),
                                    child: const Icon(Icons.chevron_right_rounded, color: Colors.cyanAccent, size: 18),
                                  ),
                                ),
                            ],
                          ),
                        const SizedBox(height: 12),
                      ],

                      // Daftar Negara Terpilih / Pilihan Per Negara (Tema Amber Kontras)
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: displayedCountries.map((country) {
                          final isSelected = _tempLocation == country;

                          return ChoiceChip(
                            label: Text(
                              country,
                              style: TextStyle(
                                color: isSelected ? Colors.black : Colors.white,
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: Colors.amberAccent,
                            backgroundColor: const Color(0xFF2B2B36),
                            side: BorderSide(color: isSelected ? Colors.amberAccent : Colors.white12),
                            onSelected: (selected) {
                              setState(() {
                                _tempLocation = selected ? country : null;
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amberAccent,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 2,
                  ),
                  onPressed: () {
                    widget.viewModel.setCategoryFilter(_tempCategory);
                    widget.viewModel.setLanguageFilter(null);
                    widget.viewModel.setLocationFilter(_tempLocation);
                    Navigator.of(context).pop();
                  },
                  child: Text(t('Apply Filter', 'Terapkan Filter'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
//............................................................................//