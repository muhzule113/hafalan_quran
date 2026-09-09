import 'package:flutter_test/flutter_test.dart';
import 'package:hafalan_quran/screens/orang_tua/home_screen.dart';

void main() {
  test('hanya notifikasi yang dipilih berubah status baca', () {
    final notifications = <Map<String, dynamic>>[
      {'id': 'notif-1', 'dibaca': false},
      {'id': 'notif-2', 'dibaca': false},
    ];

    final result = notificationsWithReadState(notifications, 'notif-1', true);

    expect(result[0]['dibaca'], isTrue);
    expect(result[1]['dibaca'], isFalse);
    expect(notifications[0]['dibaca'], isFalse);
  });
}
