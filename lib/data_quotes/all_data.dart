//.......................................................//
// NAMA FILE: ALL_DATA.DART                              //
// DIREKTORI: LIB/DATA_QUOTES/                           //
// DESKRIPSI: GUDANG SENTRAL DATA KATA BIJAK (MAJIKU)     //
//.......................................................//

//No ke-1: IMPOR MODEL & GUDANG DATA KATEGORI............//
//.......................................................//
import '../models_daily_free/quote_model.dart';

import 'data_galau.dart';
import 'data_self_love.dart';
import 'data_relate.dart';
import 'data_semangat.dart';
import 'data_cinta.dart';
import 'data_logika.dart';
import 'data_sukses.dart';
import 'data_syukur.dart';
//.......................................................//

//No ke-2: FUNGSI PENGAMBIL DATA UTAMA...................//
//.......................................................//
/// Mengambil seluruh data quote gabungan dari seluruh kategori
List<Quote> getAllQuotes() {
  return [
    ...cintaQuotes,
    ...galauQuotes,
    ...selfLoveQuotes,
    ...relateQuotes,
    ...semangatQuotes,
    ...logikaQuotes,
    ...suksesQuotes,
    ...syukurQuotes,
  ];
}

/// Pemetaan data per kategori
Map<String, List<Quote>> quotesByCategory = {
  'Cinta': cintaQuotes,
  'Galau': galauQuotes,
  'Self Love': selfLoveQuotes,
  'Relate': relateQuotes,
  'Semangat': semangatQuotes,
  'Logika': logikaQuotes,
  'Sukses': suksesQuotes,
  'Syukur': syukurQuotes,
};
//.......................................................//