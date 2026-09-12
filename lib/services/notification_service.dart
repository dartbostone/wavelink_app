import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Bonus 1 & 2 — local notification shown when an incoming call arrives,
/// including while the app is backgrounded. A production build would pair
/// this with FCM (push) so the notification can wake the app up from
/// fully-killed state; that requires a server-side trigger (e.g. a Cloud
/// Function that watches new `calls` docs) which is out of scope for this
/// assignment but noted here and in the README.
class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
    );
    _initialized = true;
  }

  Future<void> showIncomingCall({
    required String callerName,
    required bool isVideo,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'incoming_calls',
      'Incoming Calls',
      channelDescription:
          'Notifies you of incoming ConnectCall audio/video calls',
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.call,
      fullScreenIntent: true,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );
    await _plugin.show(
      id: 0,
      title: 'Incoming ${isVideo ? 'Video' : 'Audio'} Call',
      body: callerName,
      notificationDetails: details,
    );
  }

  Future<void> cancelIncomingCall() async {
    await _plugin.cancel(id: 0);
  }
}
