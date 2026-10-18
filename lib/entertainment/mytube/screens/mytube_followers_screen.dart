//============================================================================//
// DIREKTORI: lib/entertainment/mytube/screens/                              //
// FILE: MYTUBE_FOLLOWERS_SCREEN.DART                                        //
// LAYAR DAFTAR PENGIKUT CHANNEL KHUSUS (PENCARIAN, EMAIL, REAL-TIME STATS)   //
//============================================================================//

//No ke-1....................................................................//
//IMPORTS & DEPENDENCIES                                                     //
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../providers/config_provider.dart';
import '../services/firestore_mytube_service.dart';
//............................................................................//

//No ke-2....................................................................//
//WIDGET DECLARATION & STATE SETUP                                           //
class MytubeFollowersScreen extends ConsumerStatefulWidget {
  final String creatorEmail;
  final String channelName;

  const MytubeFollowersScreen({
    super.key,
    required this.creatorEmail,
    this.channelName = 'Channel',
  });

  @override
  ConsumerState<MytubeFollowersScreen> createState() => _MytubeFollowersScreenState();
}

class _MytubeFollowersScreenState extends ConsumerState<MytubeFollowersScreen> {
  final FirestoreMytubeService _service = FirestoreMytubeService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
//............................................................................//

//No ke-3....................................................................//
//MAIN BUILD & APP BAR                                                       //
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t('Channel Followers', 'Pengikut Channel'),
              style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold),
            ),
            Text(
              widget.channelName.isNotEmpty ? '@${widget.channelName}' : widget.creatorEmail,
              style: const TextStyle(fontSize: 11.5, color: Colors.white54),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // 1. Bilah Pencarian Pengikut (Nama atau Email)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: const Color(0xFF18181E),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF22222A),
                hintText: t('Search follower name or email...', 'Cari nama atau email pengikut...'),
                hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
                prefixIcon: const Icon(Icons.search, color: Colors.amberAccent, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, color: Colors.white54, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
            ),
          ),

          // 2. Daftar Pengikut Real-Time
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _service.streamCreatorFollowers(widget.creatorEmail),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.amberAccent));
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      t('Failed to load followers: ${snapshot.error}', 'Gagal memuat pengikut: ${snapshot.error}'),
                      style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                    ),
                  );
                }

                final allFollowers = snapshot.data ?? [];
                
                // Filter lokal berdasarkan nama atau email
                final filteredFollowers = allFollowers.where((f) {
                  final name = (f['display_name'] ?? '').toString().toLowerCase();
                  final email = (f['email'] ?? '').toString().toLowerCase();
                  return name.contains(_searchQuery) || email.contains(_searchQuery);
                }).toList();

                if (allFollowers.isEmpty) {
                  return _buildEmptyState(
                    t('No followers yet.', 'Belum ada pengikut.'),
                    t('Share your channel and upload videos to get followers!', 'Bagikan channel Anda dan unggah video untuk mendapatkan pengikut!'),
                  );
                }

                if (filteredFollowers.isEmpty) {
                  return _buildEmptyState(
                    t('No results match your search.', 'Tidak ada pengikut yang cocok dengan pencarian.'),
                    t('Try a different name or email.', 'Coba cari dengan kata kunci lain.'),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  itemCount: filteredFollowers.length,
                  separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
                  itemBuilder: (context, index) {
                    final follower = filteredFollowers[index];
                    final name = follower['display_name'] ?? 'Pengikut MyTube';
                    final email = follower['email'] as String? ?? '';
                    final avatar = follower['avatar_url'] as String? ?? '';
                    final followedAt = follower['followed_at'];

                    String dateStr = '';
                    if (followedAt is Timestamp) {
                      final dt = followedAt.toDate();
                      dateStr = '${dt.day}/${dt.month}/${dt.year}';
                    }

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: CircleAvatar(
                        radius: 22,
                        backgroundColor: Colors.amberAccent.withOpacity(0.15),
                        backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                        child: avatar.isEmpty
                            ? const Icon(Icons.person, color: Colors.amberAccent, size: 24)
                            : null,
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (dateStr.isNotEmpty)
                            Text(
                              dateStr,
                              style: const TextStyle(color: Colors.white38, fontSize: 11),
                            ),
                        ],
                      ),
                      subtitle: Row(
                        children: [
                          const Icon(Icons.email_outlined, color: Colors.amberAccent, size: 14),
                          const SizedBox(width: 5),
                          Expanded(
                            child: SelectableText(
                              email.isNotEmpty ? email : t('No public email', 'Email tidak tersedia'),
                              style: TextStyle(
                                color: email.isNotEmpty ? Colors.white70 : Colors.white30,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      trailing: email.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.copy_rounded, color: Colors.white54, size: 18),
                              tooltip: t('Copy Email', 'Salin Email'),
                              onPressed: () async {
                                await Clipboard.setData(ClipboardData(text: email));
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(t('Email copied: $email', 'Email disalin: $email')),
                                      backgroundColor: const Color(0xFF2563EB),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                }
                              },
                            )
                          : null,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.people_outline_rounded, color: Colors.white24, size: 64),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.white38, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
//............................................................................//