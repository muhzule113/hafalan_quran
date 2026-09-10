import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../utils/supabase_client.dart';

String? notificationSetoranId(Map<String, dynamic> data) {
  final id = data['setoran_id']?.toString().trim();
  return id == null || id.isEmpty ? null : id;
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Background message: \${message.notification?.title}');
}

class NotificationService {
  static final _fcm = FirebaseMessaging.instance;
  static final _localNotif = FlutterLocalNotificationsPlugin();
  static final pendingSetoranId = ValueNotifier<String?>(null);
  static bool _initialized = false;

  static const _channel = AndroidNotificationChannel(
    'hafalan_channel',
    'Notifikasi Hafalan',
    description: 'Notifikasi setoran hafalan santri',
    importance: Importance.high,
    playSound: true,
  );

  static Future<void> init() async {
    if (!_initialized) {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      await _fcm.requestPermission(alert: true, badge: true, sound: true);

      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      await _localNotif.initialize(
        const InitializationSettings(android: androidSettings),
        onDidReceiveNotificationResponse: (response) {
          _queueSetoranId(response.payload);
        },
      );

      final androidPlugin = _localNotif
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidPlugin?.createNotificationChannel(_channel);

      FirebaseMessaging.onMessage.listen((message) {
        final notif = message.notification;
        if (notif != null) {
          _localNotif.show(
            notif.hashCode,
            notif.title,
            notif.body,
            NotificationDetails(
              android: AndroidNotificationDetails(
                _channel.id,
                _channel.name,
                channelDescription: _channel.description,
                importance: Importance.high,
                priority: Priority.high,
                icon: '@mipmap/ic_launcher',
              ),
            ),
            payload: notificationSetoranId(message.data),
          );
        }
      });

      FirebaseMessaging.onMessageOpenedApp.listen(_handleRemoteMessage);

      final initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) _handleRemoteMessage(initialMessage);

      final launchDetails = await _localNotif.getNotificationAppLaunchDetails();
      if (launchDetails?.didNotificationLaunchApp ?? false) {
        _queueSetoranId(launchDetails?.notificationResponse?.payload);
      }

      await _fcm.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      _fcm.onTokenRefresh.listen(_updateToken);
      _initialized = true;
    }

    await _saveFcmToken();
  }

  static void _handleRemoteMessage(RemoteMessage message) {
    _queueSetoranId(notificationSetoranId(message.data));
  }

  static void _queueSetoranId(String? value) {
    final id = value?.trim();
    if (id == null || id.isEmpty) return;
    pendingSetoranId.value = id;
  }

  static String? takePendingSetoranId() {
    final id = pendingSetoranId.value;
    pendingSetoranId.value = null;
    return id;
  }

  static void clearPendingSetoranId() {
    pendingSetoranId.value = null;
  }

  static Future<void> _saveFcmToken() async {
    try {
      final token = await _fcm.getToken();
      final userId = supabase.auth.currentUser?.id;
      if (token != null && userId != null) {
        await supabase
            .from('profiles')
            .update({'fcm_token': token})
            .eq('id', userId);
        print('FCM token saved: \$token');
      }
    } catch (e) {
      print('Error saving FCM token: \$e');
    }
  }

  static Future<void> _updateToken(String token) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId != null) {
        await supabase
            .from('profiles')
            .update({'fcm_token': token})
            .eq('id', userId);
      }
    } catch (e) {
      print('Error updating FCM token: \$e');
    }
  }
}
