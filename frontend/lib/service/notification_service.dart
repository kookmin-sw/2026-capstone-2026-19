// lib/service/notification_service.dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    // 💡 핵심 수정 1: initializationSettings 가 아니라 'settings' 입니다!
    await _plugin.initialize(settings: initSettings);
  }

  static Future<void> showOngoingRide({
    required String title,
    required String body,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'active_ride_channel',
      '이용 중 상태 알림',
      channelDescription: '택시 이용 중 화면에 고정되는 알림입니다.',
      importance: Importance.max,
      priority: Priority.high,
      ongoing: true,
      autoCancel: false,
      playSound: false,
      enableVibration: false,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
    );

    // 💡 핵심 수정 2: 모든 값에 이름표(id, title, body, notificationDetails)를 붙여줍니다.
    await _plugin.show(
      id: 0,
      title: title,
      body: body,
      notificationDetails: platformDetails,
    );
  }

  static Future<void> cancelOngoingRide() async {
    // 💡 핵심 수정 3: id 이름표를 붙여줍니다.
    await _plugin.cancel(id: 0);
  }
}