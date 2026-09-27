import 'package:flutter_test/flutter_test.dart';
import 'package:hafalan_quran/screens/orang_tua/home_screen.dart';

void main() {
  final children = <Map<String, dynamic>>[
    {'id': 'anak-1', 'nama': 'Ahmad'},
    {'id': 'anak-2', 'nama': 'Zahra'},
  ];

  test('memilih anak pertama atau mempertahankan anak yang dipilih', () {
    expect(selectParentSantri(children, null)?['id'], 'anak-1');
    expect(selectParentSantri(children, 'anak-2')?['id'], 'anak-2');
    expect(selectParentSantri(children, 'anak-hilang')?['id'], 'anak-1');
  });

  test('notifikasi anak kedua menemukan data anak yang benar', () {
    final notification = <String, dynamic>{
      'setoran_id': 'setoran-2',
      'santri_id': 'anak-2',
    };
    final target = notificationForSetoran([notification], 'setoran-2');

    expect(parentSantriById(children, target?['santri_id'])?['nama'], 'Zahra');
  });
}
