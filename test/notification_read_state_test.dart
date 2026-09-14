import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hafalan_quran/screens/orang_tua/home_screen.dart';
import 'package:hafalan_quran/services/notification_service.dart';

void main() {
  tearDown(NotificationService.clearPendingSetoranId);

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

  test('payload notifikasi hanya menerima setoran_id yang valid', () {
    expect(notificationSetoranId({'setoran_id': 'setoran-42'}), 'setoran-42');
    expect(notificationSetoranId({'setoran_id': '  '}), isNull);
    expect(notificationSetoranId({}), isNull);
  });

  test('notifikasi push menemukan notifikasi berdasarkan setoran', () {
    final notifications = <Map<String, dynamic>>[
      {'id': 'notif-1', 'setoran_id': 'setoran-42'},
    ];

    expect(
      notificationForSetoran(notifications, 'setoran-42')?['id'],
      'notif-1',
    );
    expect(notificationForSetoran(notifications, 'setoran-lain'), isNull);
  });

  test('tujuan notifikasi hanya dikonsumsi satu kali', () {
    NotificationService.pendingSetoranId.value = 'setoran-42';

    expect(NotificationService.takePendingSetoranId(), 'setoran-42');
    expect(NotificationService.takePendingSetoranId(), isNull);
  });

  test('status baca tersimpan sebelum setoran dibuka', () async {
    final events = <String>[];
    final saved = Completer<void>();

    final opening = openAfterNotificationRead(
      markAsRead: () async {
        events.add('save-start');
        await saved.future;
        events.add('save-done');
      },
      open: () async => events.add('open'),
    );

    await Future<void>.delayed(Duration.zero);
    expect(events, ['save-start']);

    saved.complete();
    await opening;

    expect(events, ['save-start', 'save-done', 'open']);
  });
}
