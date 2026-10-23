//============================================================================//
// DIREKTORI: LIB/ENTERTAINMENT/MYTUBE/SCREENS/                               //
// FILE: CONTENT_MANAGEMENT_SCREEN.DART                                       //
// PORTAL ADMIN CONTENT MANAGEMENT: TABEL MONITORING CHANNEL & KONTEN        //
//============================================================================//

//No ke-1....................................................................//
//IMPORTS & DEPENDENCIES                                                     //
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/config_provider.dart';
import '../models/creator_mytube_model.dart';
import '../services/firestore_mytube_service.dart';
import 'history_content.dart';
//............................................................................//

//No ke-2....................................................................//
//WIDGET DECLARATION & STATE SETUP                                           //
class ContentManagementScreen extends ConsumerStatefulWidget {
  const ContentManagementScreen({super.key});

  @override
  ConsumerState<ContentManagementScreen> createState() => _ContentManagementScreenState();
}

class _ContentManagementScreenState extends ConsumerState<ContentManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return '-';
    DateTime date;
    if (timestamp is Timestamp) {
      date = timestamp.toDate();
    } else if (timestamp is DateTime) {
      date = timestamp;
    } else if (timestamp is String) {
      date = DateTime.tryParse(timestamp) ?? DateTime.now();
    } else {
      return '-';
    }

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agt', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    final d = date.day.toString().padLeft(2, '0');
    final m = months[(date.month - 1).clamp(0, 11)];
    final y = date.year;
    return '$d $m $y';
  }

  void _copyToClipboard(String text, String label, bool isIndo) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isIndo ? '$label disalin ke clipboard' : '$label copied to clipboard',
          style: const TextStyle(fontSize: 13),
        ),
        backgroundColor: const Color(0xFF2563EB),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
//............................................................................//

//No ke-3....................................................................//
//MAIN BUILD & APPBAR (SEARCH & HEADER ACTIONS)                              //
  @override
  Widget build(BuildContext context) {
    final currentLocale = ref.watch(appLanguageProvider);
    final isIndo = currentLocale.languageCode == 'id';
    String t(String en, String id) => isIndo ? id : en;

    return Scaffold(
      backgroundColor: const Color(0xFF121214),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E24),
        elevation: 0,
        title: Text(
          t('Content Management', 'Manajemen Konten'),
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            tooltip: t('Refresh', 'Segarkan'),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: Column(
        children: [
          // Baris Atas: Info Singkat & Pencarian Instan
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            color: const Color(0xFF18181D),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.table_chart_rounded, color: Colors.amberAccent, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      t('Registered Channels & Content Auditor', 'Daftar Channel & Audit Konten Kreator'),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Search Bar Responsif
                TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white, fontSize: 13.5),
                  decoration: InputDecoration(
                    hintText: t(
                      'Search by channel name, channel ID, or email...',
                      'Cari berdasarkan nama channel, channel ID, atau email...',
                    ),
                    hintStyle: const TextStyle(color: Colors.white30, fontSize: 12.5),
                    prefixIcon: const Icon(Icons.search, color: Colors.amberAccent, size: 18),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.white54, size: 16),
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFF121214),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Colors.white12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Colors.amberAccent),
                    ),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val.trim().toLowerCase();
                    });
                  },
                ),
              ],
            ),
          ),

          // Konten Utama: Stream Tabel Channel
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection(FirestoreMytubeService.colMytube)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.amberAccent));
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        t('Error loading channels: ${snapshot.error}', 'Gagal memuat daftar channel: ${snapshot.error}'),
                        style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Center(
                    child: Text(
                      t('No registered channels found.', 'Belum ada channel terdaftar.'),
                      style: const TextStyle(color: Colors.white54, fontSize: 14),
                    ),
                  );
                }

                // Parsing Dokumen Channel
                List<Map<String, dynamic>> channelList = [];

                for (final doc in docs) {
                  final data = doc.data() as Map<String, dynamic>? ?? {};
                  final channelId = (data['channel_id'] ?? data['channelId'] ?? doc.id).toString();
                  final channelName = (data['channel_name'] ?? data['channelName'] ?? 'Official Channel').toString();
                  final email = (data['email'] ?? data['uploader_email'] ?? doc.id).toString();
                  final avatarUrl = (data['avatar_url'] ?? data['avatarUrl'] ?? '').toString();
                  final createdAt = data['created_at'] ?? data['createdAt'];

                  // Filter Pencarian Lokal
                  if (_searchQuery.isNotEmpty) {
                    final matchName = channelName.toLowerCase().contains(_searchQuery);
                    final matchId = channelId.toLowerCase().contains(_searchQuery);
                    final matchEmail = email.toLowerCase().contains(_searchQuery);
                    if (!matchName && !matchId && !matchEmail) continue;
                  }

                  channelList.add({
                    'docId': doc.id,
                    'channelId': channelId,
                    'channelName': channelName,
                    'email': email,
                    'avatarUrl': avatarUrl,
                    'createdAt': createdAt,
                  });
                }

                if (channelList.isEmpty) {
                  return Center(
                    child: Text(
                      t('No channels match your search.', 'Tidak ada channel yang cocok dengan pencarian.'),
                      style: const TextStyle(color: Colors.white54, fontSize: 13.5),
                    ),
                  );
                }

                return _buildDataTable(channelList, t, isIndo);
              },
            ),
          ),
        ],
      ),
    );
  }
//............................................................................//

//No ke-4....................................................................//
//DATA TABLE BUILDER (RESPONSIVE FULL-WIDTH WEB & FLUID MOBILE ADAPTIVE)     //
  Widget _buildDataTable(
    List<Map<String, dynamic>> channels,
    String Function(String, String) t,
    bool isIndo,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Deteksi apakah perangkat adalah Web/Desktop/Layar Lebar (>= 850 dp)
        final bool isWideScreen = constraints.maxWidth >= 850;
        
        // Di Web/PC, paksa lebar tabel memenuhi 100% layar (minWidth = maxWidth)
        // Di HP, berikan batas aman 780 dp agar tetap bisa digeser tanpa tabrakan kolom
        final double effectiveTableWidth = isWideScreen ? constraints.maxWidth - 32 : 780.0;

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            scrollDirection: Axis.horizontal,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: effectiveTableWidth,
                ),
                child: DataTable(
                  headingRowColor: MaterialStateProperty.all(const Color(0xFF1E1E24)),
                  dataRowColor: MaterialStateProperty.resolveWith<Color?>(
                    (Set<MaterialState> states) {
                      return const Color(0xFF151518);
                    },
                  ),
                  horizontalMargin: 20,
                  columnSpacing: isWideScreen ? 36 : 20,
                  dividerThickness: 0.6,
                  headingTextStyle: const TextStyle(
                    color: Colors.amberAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                    letterSpacing: 0.5,
                  ),
                  dataTextStyle: const TextStyle(color: Colors.white, fontSize: 13),
                  border: TableBorder.all(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(10),
                    width: 0.8,
                  ),
                  columns: [
                    DataColumn(label: Text(t('No', 'No'))),
                    DataColumn(label: Text(t('Nama Channel', 'Nama Channel'))),
                    DataColumn(label: Text(t('Channel ID', 'Channel ID'))),
                    DataColumn(label: Text(t('Email', 'Email'))),
                    DataColumn(label: Text(t('Content History', 'Content History'))),
                    DataColumn(label: Text(t('Tanggal Dibuat', 'Tanggal Dibuat'))),
                  ],
                  rows: List.generate(channels.length, (index) {
                    final item = channels[index];
                    final int no = index + 1;
                    final String channelName = item['channelName'];
                    final String channelId = item['channelId'];
                    final String email = item['email'];
                    final String avatarUrl = item['avatarUrl'];
                    final dynamic createdAt = item['createdAt'];

                    return DataRow(
                      cells: [
                        // 1. No
                        DataCell(
                          Text(
                            '$no',
                            style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.bold),
                          ),
                        ),

                        // 2. Nama Channel (+ Avatar) - Melebar proporsional di PC
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 15,
                                backgroundColor: Colors.amberAccent.withOpacity(0.2),
                                backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                                child: avatarUrl.isEmpty
                                    ? const Icon(Icons.person, color: Colors.amberAccent, size: 18)
                                    : null,
                              ),
                              const SizedBox(width: 10),
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: isWideScreen ? 280 : 160,
                                ),
                                child: Text(
                                  channelName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // 3. Channel ID (+ Quick Copy) - Sangat lega di PC
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: isWideScreen ? 220 : 130,
                                ),
                                child: Text(
                                  channelId,
                                  style: const TextStyle(
                                    color: Colors.cyanAccent,
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(Icons.copy_rounded, color: Colors.white38, size: 14),
                                tooltip: t('Copy Channel ID', 'Salin Channel ID'),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => _copyToClipboard(channelId, 'Channel ID', isIndo),
                              ),
                            ],
                          ),
                        ),

                        // 4. Email - Sangat lega di PC
                        DataCell(
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: isWideScreen ? 280 : 160,
                            ),
                            child: Text(
                              email,
                              style: const TextStyle(color: Colors.white70),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),

                        // 5. Content History (Tombol Buka Riwayat Konten)
                        DataCell(
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                horizontal: isWideScreen ? 14 : 10,
                                vertical: 8,
                              ),
                              elevation: 1,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            icon: const Icon(Icons.video_library_rounded, size: 15, color: Colors.white),
                            label: Text(
                              t('Lihat Konten', 'Lihat Konten'),
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => HistoryContentScreen(
                                    initialTabIndex: 0,
                                    targetChannelId: channelId,
                                    targetChannelName: channelName,
                                    targetCreatorEmail: email,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),

                        // 6. Tanggal Dibuat
                        DataCell(
                          Text(
                            _formatDate(createdAt),
                            style: const TextStyle(color: Colors.white60, fontSize: 12),
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
//............................................................................//