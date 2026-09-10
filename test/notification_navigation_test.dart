import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hafalan_quran/screens/orang_tua/home_screen.dart';

void main() {
  testWidgets('notifikasi membuka setoran yang terkait', (tester) async {
    String? openedId;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NotificationSetoranTapTarget(
            notification: const {'setoran_id': 'setoran-notif'},
            onOpen: (id) => openedId = id,
            child: const Text('Buka notifikasi'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Buka notifikasi'));

    expect(openedId, 'setoran-notif');
  });

  testWidgets('riwayat membuka setoran yang dipilih', (tester) async {
    String? openedId;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SetoranHistoryTapTarget(
            setoran: const {'id': 'setoran-riwayat'},
            onOpen: (id) => openedId = id,
            child: const Text('Buka riwayat'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Buka riwayat'));

    expect(openedId, 'setoran-riwayat');
  });
}
