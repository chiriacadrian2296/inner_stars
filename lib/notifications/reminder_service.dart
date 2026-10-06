import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

const _androidChannel = AndroidNotificationDetails(
  'daily_reminder',
  'Daily reminder',
  importance: Importance.defaultImportance,
  priority: Priority.defaultPriority,
);

/// Schedules (or cancels) the daily "log a win" reminder, and can fire an
/// immediate test notification on demand. Tapping any of these notifications
/// (cold start or while running) is reported via the `onNotificationTap`
/// callback passed to [create] — the app wires that to opening the
/// add-win screen.
class ReminderService {
  ReminderService._(this._plugin);

  /// The next [_daysAhead] days are scheduled individually (not one
  /// repeating alarm) so the body text can cycle through several phrases
  /// instead of repeating the same one every day. IDs are base-relative,
  /// one per day offset; [_testNotificationId] is deliberately outside that
  /// range so a manual test never collides with or disturbs the real
  /// schedule.
  static const _notificationIdBase = 1001;
  static const _daysAhead = 5;
  static const _testNotificationId = 999;
  static bool _timezoneReady = false;

  final FlutterLocalNotificationsPlugin _plugin;

  static Future<ReminderService> create({
    void Function(NotificationResponse)? onNotificationTap,
  }) async {
    final plugin = FlutterLocalNotificationsPlugin();
    // Must be a plain white silhouette drawable, not the full-color launcher
    // mipmap — Android's status bar only reads the alpha channel of a
    // notification icon (API 21+), so the adaptive launcher icon used to
    // render as blank/invisible there.
    const androidSettings = AndroidInitializationSettings(
      '@drawable/ic_stat_notification',
    );
    await plugin.initialize(
      settings: const InitializationSettings(android: androidSettings),
      onDidReceiveNotificationResponse: onNotificationTap,
    );

    if (!_timezoneReady) {
      tz_data.initializeTimeZones();
      // Some real devices (OEM skins especially) report a timezone
      // identifier the bundled tz database doesn't recognize, unlike
      // emulators — tz.getLocation then throws, and since this whole chain
      // is awaited from main.dart's startup with no error handling, an
      // uncaught throw here used to leave the entire app stuck on its
      // splash screen forever. Falling back to UTC keeps startup unblocked;
      // scheduled reminder times just won't be local-time-accurate on a
      // device that hits this.
      try {
        final localTimezone = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(localTimezone.identifier));
      } catch (_) {
        tz.setLocalLocation(tz.getLocation('UTC'));
      }
      _timezoneReady = true;
    }

    return ReminderService._(plugin);
  }

  /// Android 13+ requires runtime permission for notifications. Returns
  /// whether the reminder can actually be shown; other platforms in this
  /// app (none yet) default to true since no prompt is needed.
  Future<bool> requestPermission() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin == null) return true;
    final granted = await androidPlugin.requestNotificationsPermission();
    return granted ?? false;
  }

  /// Android 12+ (API 31+) gates *exact*-time alarms behind this separate
  /// "Alarms & reminders" permission — without it, [scheduleUpcoming] falls
  /// back to an inexact alarm that Android is free to delay by a wide
  /// margin, which is why the reminder used to fire late or not at all.
  /// There's no in-app grant dialog for it (unlike [requestPermission]):
  /// this sends the user to the system settings screen for it, best-effort
  /// — the app has no way to know when/if they come back having granted it,
  /// so [scheduleUpcoming] always re-checks [_canScheduleExactAlarms] fresh
  /// rather than assuming this call succeeded.
  Future<void> requestExactAlarmPermission() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.requestExactAlarmsPermission();
  }

  Future<bool> _canScheduleExactAlarms() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin == null) return true;
    return await androidPlugin.canScheduleExactNotifications() ?? false;
  }

  /// Whether the app process was cold-started by the user tapping a
  /// notification — [onNotificationTap] alone can't see this, since it
  /// isn't attached yet at that point. Check once, right after [create].
  Future<bool> launchedFromNotification() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    return details?.didNotificationLaunchApp ?? false;
  }

  /// Schedules the next [_daysAhead] days at [hour]:[minute], one [bodies]
  /// entry per day (cycling if there are fewer phrases than days). Replaces
  /// whatever was scheduled before — call again (e.g. when the app is
  /// reopened) to keep the window topped up, since exact-date alarms don't
  /// refill themselves the way a single repeating one would.
  Future<void> scheduleUpcoming({
    required int hour,
    required int minute,
    required String title,
    required List<String> bodies,
  }) async {
    await _plugin.cancelAll();
    final scheduleMode = await _canScheduleExactAlarms()
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
    final now = tz.TZDateTime.now(tz.local);
    for (var i = 0; i < _daysAhead; i++) {
      var date = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );
      if (!date.isAfter(now)) date = date.add(const Duration(days: 1));
      date = date.add(Duration(days: i));

      await _plugin.zonedSchedule(
        id: _notificationIdBase + i,
        scheduledDate: date,
        title: title,
        body: bodies[i % bodies.length],
        notificationDetails: const NotificationDetails(
          android: _androidChannel,
        ),
        androidScheduleMode: scheduleMode,
      );
    }
  }

  Future<void> cancel() => _plugin.cancelAll();

  /// Fires right away — for the "send test notification" button in
  /// Settings. Uses its own id, well outside the scheduled range, so it
  /// never overwrites (or gets overwritten by) the real daily reminders.
  Future<void> showNow({required String title, required String body}) {
    return _plugin.show(
      id: _testNotificationId,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(android: _androidChannel),
    );
  }
}
