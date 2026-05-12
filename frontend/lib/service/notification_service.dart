// lib/service/notification_service.dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  // 1. 초기화 (main.dart에서 앱 시작 시 한 번 호출)
  static Future<void> init() async {
    // 안드로이드 아이콘 설정 (기본 앱 아이콘 사용)
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS 설정
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(initSettings);
  }

  // 2. 🚨 지워지지 않는 '이용 중' 고정 알림 띄우기
  static Future<void> showOngoingRide({
    required String title,
    required String body,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'active_ride_channel', // 채널 ID
      '이용 중 상태 알림',        // 채널 이름
      channelDescription: '택시 이용 중 화면에 고정되는 알림입니다.',
      importance: Importance.max,
      priority: Priority.high,
      ongoing: true,      // 📍 핵심: 스와이프로 지워지지 않게 고정!
      autoCancel: false,  // 📍 탭해도 알림이 사라지지 않음
      playSound: false,   // 계속 떠있는 알림이므로 소리는 끔
      enableVibration: false,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
    );

    await _plugin.show(
      0, // 알림 ID (고정 알림은 항상 0번을 써서 덮어씌움)
      title,
      body,
      platformDetails,
    );
  }

  // 3. 정산 완료 시 알림 지우기
  static Future<void> cancelOngoingRide() async {
    await _plugin.cancel(0);
  }
}