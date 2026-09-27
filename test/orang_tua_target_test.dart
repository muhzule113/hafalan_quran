import 'package:flutter_test/flutter_test.dart';
import 'package:hafalan_quran/screens/orang_tua/home_screen.dart';

void main() {
  test('label target menghitung sisa hari dari tanggal kalender', () {
    final now = DateTime(2026, 9, 26, 18);

    expect(parentTargetDeadlineLabel('2026-09-28', now: now), '2 hari lagi');
    expect(
      parentTargetDeadlineLabel('2026-09-26', now: now),
      'Deadline hari ini',
    );
    expect(
      parentTargetDeadlineLabel('2026-09-25', now: now),
      'Terlambat 1 hari',
    );
  });

  test('label status target mengikuti status dari ustad', () {
    expect(parentTargetStatusLabel('aktif'), 'Aktif');
    expect(parentTargetStatusLabel('selesai'), 'Selesai');
    expect(parentTargetStatusLabel('gagal'), 'Gagal');
  });
}
