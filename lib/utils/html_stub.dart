// [STUB FILE]
// File ini hanya dipanggil saat dijalankan di Android/iOS (Native).
// Tujuannya agar compiler tidak error saat membaca sintaks 'html.Blob' dsb.

class Blob {
  Blob(List<dynamic> content, String type);
}

class Url {
  static String createObjectUrlFromBlob(Blob blob) => '';
  static void revokeObjectUrl(String url) {}
}

class AnchorElement {
  String href = '';
  String download = '';
  void click() {}
  AnchorElement({required this.href});
}