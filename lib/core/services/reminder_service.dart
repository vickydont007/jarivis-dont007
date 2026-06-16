import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../calendar_event.dart';
import 'calendar_service.dart';

class ReminderService {
  final CalendarService _calendarService;
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  Timer? _reminderTimer;
  bool _initialized = false;

  ReminderService({required CalendarService calendarService})
      : _calendarService = calendarService;

  Future<void> initialize() async {
    if (_initialized) return;
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );
    await _notifications.initialize(initSettings);
    _initialized = true;
    _startReminderCheck();
  }

  void _startReminderCheck() {
    _reminderTimer?.cancel();
    _reminderTimer = Timer.periodic(const Duration(minutes: 1), (_) => _checkReminders());
  }

  Future<void> _checkReminders() async {
    try {
      final upcoming = await _calendarService.getUpcomingEvents(limit: 20);
      final now = DateTime.now();

      for (final event in upcoming) {
        if (event.isCompleted) continue;
        final reminderTime = event.startTime.subtract(Duration(minutes: event.reminderMinutes));
        final diff = reminderTime.difference(now);

        if (diff.inMinutes >= 0 && diff.inMinutes < 2) {
          await _showEventReminder(event);
        }
      }
    } catch (_) {}
  }

  Future<void> _showEventReminder(CalendarEvent event) async {
    if (!_initialized) return;
    const androidDetails = AndroidNotificationDetails(
      'jarvis_calendar_reminders',
      'Calendar Reminders',
      channelDescription: 'Reminders for calendar events',
      importance: Importance.high,
      priority: Priority.high,
    );
    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    final timeUntil = event.startTime.difference(DateTime.now());
    final timeStr = timeUntil.inHours > 0
        ? '${timeUntil.inHours}h ${timeUntil.inMinutes % 60}m'
        : '${timeUntil.inMinutes}m';

    await _notifications.show(
      event.id.hashCode,
      event.title,
      'Starts in $timeStr${event.location.isNotEmpty ? " at ${event.location}" : ""}',
      details,
    );
  }

  Future<void> setReminder({
    required String eventId,
    required int minutesBefore,
    String? customMessage,
  }) async {
    final event = await _calendarService.getEvent(eventId);
    if (event == null) return;

    final updatedEvent = event.copyWith(reminderMinutes: minutesBefore);
    await _calendarService.updateEvent(eventId, reminderMinutes: minutesBefore);
  }

  Future<void> cancelReminder(String eventId) async {
    await _notifications.cancel(eventId.hashCode);
  }

  Future<void> showCustomReminder({
    required String title,
    required String message,
    required DateTime scheduledTime,
  }) async {
    if (!_initialized) return;
    const androidDetails = AndroidNotificationDetails(
      'jarvis_custom_reminders',
      'Custom Reminders',
      channelDescription: 'Custom reminder notifications',
      importance: Importance.high,
      priority: Priority.high,
    );
    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    final delay = scheduledTime.difference(DateTime.now());
    if (delay.isNegative) return;

    Timer(delay, () async {
      await _notifications.show(
        title.hashCode,
        title,
        message,
        details,
      );
    });
  }

  Future<List<Map<String, dynamic>>> getUpcomingReminders() async {
    final events = await _calendarService.getUpcomingEvents(limit: 10);
    final now = DateTime.now();
    final reminders = <Map<String, dynamic>>[];

    for (final event in events) {
      if (event.isCompleted || event.reminderMinutes <= 0) continue;
      final reminderTime = event.startTime.subtract(Duration(minutes: event.reminderMinutes));
      if (reminderTime.isAfter(now)) {
        reminders.add({
          'eventId': event.id,
          'title': event.title,
          'startTime': event.startTime.toIso8601String(),
          'remindAt': reminderTime.toIso8601String(),
          'minutesUntil': reminderTime.difference(now).inMinutes,
        });
      }
    }

    reminders.sort((a, b) => (a['remindAt'] as String).compareTo(b['remindAt'] as String));
    return reminders;
  }

  void dispose() {
    _reminderTimer?.cancel();
    _notifications.cancelAll();
  }
}
