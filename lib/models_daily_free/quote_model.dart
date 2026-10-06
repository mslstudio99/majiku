//.......................................................//
// NAMA FILE: QUOTE_MODEL.DART                           //
// DIREKTORI: LIB/MODELS_DAILY_FREE/                     //
// DESKRIPSI: MODEL DATA KATA BIJAK (DAILY QUOTES)       //
//.......................................................//

//No ke-1: IMPOR & DEKLARASI PROPERTI KELAS..............//
//.......................................................//
import 'package:flutter/material.dart';

class Quote {
  final String text;      // Teks Indonesia
  final String? textEn;   // Teks Inggris (Opsional)
  final String author;
  final String category;

  // Properti Identitas & Metrik
  final String? id;          // ID unik quote
  final String? userId;      // ID kreator (jika ada)
  final DateTime? createdAt; // Waktu publikasi
  final int likesCount;      // Jumlah like statis
  final int viewsCount;      // Jumlah tayangan statis

  const Quote({
    required this.text,
    this.textEn,
    required this.author,
    required this.category,
    this.id,
    this.userId,
    this.createdAt,
    this.likesCount = 0,
    this.viewsCount = 0,
  });
//.......................................................//

//No ke-2: METODE HELPER & ALGORITMA METRIK ORGANIK......//
//.......................................................//
  /// Mengambil konten teks sesuai locale bahasa aktif di aplikasi
  String getContent(BuildContext context) {
    final bool isGlobal = Localizations.localeOf(context).languageCode != 'id';
    if (isGlobal && textEn != null && textEn!.isNotEmpty) {
      return textEn!;
    }
    return text;
  }

  /// Algoritma Simulasi Tayangan Organik Harian (Berbasis Seed Hash Teks)
  int get effectiveViews {
    final int seed = (id ?? text).hashCode.abs();

    if (createdAt != null) {
      final int daysElapsed = DateTime.now().difference(createdAt!).inDays;
      final int safeDays = daysElapsed >= 0 ? daysElapsed : 0;
      final int dailyViewsRate = 3 + (seed % 3);
      final int simulatedGrowth = (dailyViewsRate * (safeDays + 1)) + (seed % 7);
      final int totalCalculated = viewsCount + simulatedGrowth;
      return totalCalculated >= 1000 ? (1000 + viewsCount) : totalCalculated;
    }

    if (viewsCount > 0) return viewsCount;
    return (seed % 400) + (text.length * 6) + 300;
  }

  /// Algoritma Simulasi Suka Organik Harian (Proporsional terhadap Views)
  int get effectiveLikes {
    final int seed = (id ?? text).hashCode.abs();

    if (createdAt != null) {
      final int daysElapsed = DateTime.now().difference(createdAt!).inDays;
      final int safeDays = daysElapsed >= 0 ? daysElapsed : 0;
      final int dailyLikesRate = 2 + (seed % 2);
      final int simulatedLikes = (dailyLikesRate * (safeDays + 1)) + (seed % 3);
      final int maxAllowedLikes = (effectiveViews * 0.4).round();
      final int totalCalculated = likesCount + simulatedLikes;

      if (totalCalculated > maxAllowedLikes && maxAllowedLikes > 0) {
        return maxAllowedLikes + likesCount;
      }
      return totalCalculated;
    }

    if (likesCount > 0) return likesCount;
    final int baseStaticLikes = ((effectiveViews * 0.25) + (seed % 15)).round();
    return baseStaticLikes > 0 ? baseStaticLikes : 12;
  }
//.......................................................//

//No ke-3: SERIALISASI & PEMETAAN DATA (MAP/JSON)........//
//.......................................................//
  factory Quote.fromMap(Map<String, dynamic> map) {
    return Quote(
      id: map['id'] as String?,
      userId: map['userId'] as String?,
      text: map['text'] as String? ?? '',
      textEn: map['textEn'] as String?,
      author: map['author'] as String? ?? 'Anonym',
      category: map['category'] as String? ?? 'Umum',
      createdAt: map['createdAt'] != null ? DateTime.tryParse(map['createdAt'].toString()) : null,
      likesCount: (map['likesCount'] as num?)?.toInt() ?? 
                  (map['likesCount'] is String ? int.tryParse(map['likesCount']) ?? 0 : 0),
      viewsCount: (map['viewsCount'] as num?)?.toInt() ?? 
                  (map['viewsCount'] is String ? int.tryParse(map['viewsCount']) ?? 0 : 0),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      if (userId != null) 'userId': userId,
      'text': text,
      if (textEn != null) 'textEn': textEn,
      'author': author,
      'category': category,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      'likesCount': likesCount,
      'viewsCount': viewsCount,
    };
  }
}
//.......................................................//