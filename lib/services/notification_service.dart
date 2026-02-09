import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();
    // Get device IANA timezone from native platform via MethodChannel
    const platform = MethodChannel('habit_tracker/timezone');
    try {
      final String tzName = await platform.invokeMethod('getLocalTimezone');
      if (tzName.isNotEmpty) {
        tz.setLocalLocation(tz.getLocation(tzName));
        print('[Timezone] Set local timezone to: $tzName');
      } else {
        tz.setLocalLocation(tz.getLocation('UTC'));
        print('[Timezone] Empty timezone from platform, using UTC');
      }
    } catch (e) {
      print('[Timezone] Error getting timezone from platform: $e, falling back to UTC');
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const initSettings = InitializationSettings(
      android: androidSettings,
    );

    await _notifications.initialize(initSettings);

    // Request notification permissions for Android 13+
    await _requestPermissions();

    // Create notification channel
    await _createNotificationChannel();
  }

  Future<void> _requestPermissions() async {
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _notifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      // Request exact alarm permission
      await androidImplementation.requestExactAlarmsPermission();

      // Request notification permission
      final bool? granted = await androidImplementation.requestNotificationsPermission();
      print('Notification permission granted: $granted');
    }
  }

  Future<void> _createNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'habit_channel', // id
      'Habit Reminders', // name
      description: 'Notifications for habit reminders', // description
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _notifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      await androidImplementation.createNotificationChannel(channel);
      print('Notification channel created');
    }
  }

  Future<void> scheduleHabitReminder({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledTime,
  }) async {
    print('[Notification] Scheduling id=$id at $scheduledTime (local tz)');
    print('[Notification] Current time: ${tz.TZDateTime.now(tz.local)}');
    print('[Notification] Time until notification: ${scheduledTime.difference(tz.TZDateTime.now(tz.local))}');
    
    await _notifications.zonedSchedule(
      id,
      title,
      body,
      scheduledTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'habit_channel',
          'Habit Reminders',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
        ),
      ),
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      // For weekly reminders (specific weekday + time) use dayOfWeekAndTime
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );

    // Debug: print pending notifications count after scheduling
    final pending = await getPendingNotifications();
    print('[Notification] Scheduled notification id=$id. Total pending=${pending.length}');
  }

  // Helper: Schedule a test notification for 10 seconds from now
  Future<void> scheduleTestNotification() async {
    final testTime = tz.TZDateTime.now(tz.local).add(const Duration(seconds: 10));
    print('[Test] Scheduling test notification for 10 seconds from now: $testTime');
    
    await scheduleHabitReminder(
      id: 99999,
      title: 'Test Notification',
      body: 'This should appear in 10 seconds',
      scheduledTime: testTime,
    );
  }

  // Show an immediate notification
  Future<void> showNotification({
    required String title,
    required String body,
    required int id,
  }) async {
    await _notifications.show(
      id,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'habit_channel',
          'Habit Reminders',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
        ),
      ),
    );
  }

  // Cancel a specific notification by ID
  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  // Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  // Get all pending notifications (useful for debugging)
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }

  // Generate unique notification ID based on habit ID and day
  int generateNotificationId(int habitId, int dayIndex) {
    // habitId * 10 + dayIndex ensures unique IDs
    // Example: habit 123, monday (0) = 1230, tuesday (1) = 1231, etc.
    return habitId * 10 + dayIndex;
  }
}
