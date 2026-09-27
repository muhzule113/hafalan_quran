import 'package:flutter_test/flutter_test.dart';
import 'package:hafalan_quran/utils/search_utils.dart';

void main() {
  final records = <Map<String, dynamic>>[
    {'id': 's1', 'nama': 'Ahmad', 'kelas': 'SMP Kelas 1', 'ustadz_id': 'u1'},
    {'id': 's2', 'nama': 'Siti', 'kelas': 'SMP Kelas 1', 'ustadz_id': null},
    {'id': 's3', 'nama': 'Umar', 'kelas': 'SMP Kelas 2', 'ustadz_id': 'u2'},
  ];

  test('memfilter santri berdasarkan ustadz dan status belum dibagi', () {
    expect(
      filterAssignedSantri(records, 'u1').map((record) => record['nama']),
      ['Ahmad'],
    );
    expect(filterUnassignedSantri(records).map((record) => record['nama']), [
      'Siti',
    ]);
  });

  test('assignment massal hanya mengubah kelas yang dipilih', () {
    final result = applyClassAssignment(records, 'SMP Kelas 1', 'u3');

    expect(result[0]['ustadz_id'], 'u3');
    expect(result[1]['ustadz_id'], 'u3');
    expect(result[2]['ustadz_id'], 'u2');
  });

  test('assignment null mengembalikan santri menjadi belum dibagi', () {
    final result = applyClassAssignment(records, 'SMP Kelas 2', null);

    expect(result[2]['ustadz_id'], isNull);
    expect(result[0]['ustadz_id'], 'u1');
  });
}
