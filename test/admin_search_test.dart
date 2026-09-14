import 'package:flutter_test/flutter_test.dart';
import 'package:hafalan_quran/utils/search_utils.dart';

void main() {
  final records = <Map<String, dynamic>>[
    {
      'nama': 'Ahmad Fauzan',
      'kelas': 'Tahfiz A',
      'nama_wali': 'Budi Fauzan',
    },
    {
      'nama': 'Siti Aminah',
      'no_hp': '081234567890',
    },
  ];

  Iterable<String?> fields(Map<String, dynamic> record) => [
        record['nama']?.toString(),
        record['kelas']?.toString(),
        record['nama_wali']?.toString(),
        record['no_hp']?.toString(),
      ];

  test('mengembalikan semua data saat kata kunci kosong atau spasi', () {
    expect(
      filterAdminRecords(records, '  ', getSearchFields: fields),
      same(records),
    );
  });

  test('mencari substring tanpa membedakan huruf besar kecil', () {
    final result = filterAdminRecords(
      records,
      'AMIN',
      getSearchFields: fields,
    );

    expect(result.map((record) => record['nama']), ['Siti Aminah']);
  });

  test('mencari field tambahan dan mengabaikan field null', () {
    final result = filterAdminRecords(
      records,
      '081234',
      getSearchFields: fields,
    );

    expect(result.map((record) => record['nama']), ['Siti Aminah']);
  });

  test('mengembalikan daftar kosong jika tidak ada kecocokan', () {
    expect(
      filterAdminRecords(records, 'tidak ada', getSearchFields: fields),
      isEmpty,
    );
  });
}
