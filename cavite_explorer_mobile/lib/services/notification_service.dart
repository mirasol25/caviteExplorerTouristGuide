import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final StreamController<String> notificationPayloads =
    StreamController<String>.broadcast();

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  final payload = response.payload;
  if (payload != null && payload.isNotEmpty) {
    notificationPayloads.add(payload);
  }
}

class NotificationService {
  static const foregroundId = 8801;
  static const rewardId = 8803;
  static final FlutterLocalNotificationsPlugin plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('ic_stat_explorer'),
    );
    await plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          notificationPayloads.add(payload);
        }
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );
    final android = plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(const AndroidNotificationChannel(
      'landmark_discovery',
      'Nearby landmarks',
      description: 'Alerts when an unclaimed landmark is nearby.',
      importance: Importance.high,
    ));
    await android?.createNotificationChannel(const AndroidNotificationChannel(
      'active_journey',
      'Active visits and commutes',
      description: 'Ongoing landmark visits and live commute guidance.',
      importance: Importance.low,
    ));
    await android?.createNotificationChannel(const AndroidNotificationChannel(
      'badge_rewards',
      'Badge rewards',
      description: 'Notifies you when a landmark badge is unlocked.',
      importance: Importance.high,
    ));
    _initialized = true;
  }

  static Future<bool> requestPermission() async {
    await initialize();
    return await plugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission() ??
        true;
  }

  static Future<String?> initialPayload() async {
    await initialize();
    final details = await plugin.getNotificationAppLaunchDetails();
    return details?.didNotificationLaunchApp == true
        ? details?.notificationResponse?.payload
        : null;
  }

  static Future<void> showNearby(Map<String, dynamic> landmark) async {
    await initialize();
    final id = landmark['id']?.toString() ?? '';
    final name = landmark['name']?.toString() ?? 'a Cavite landmark';
    await plugin.show(
      10000 + (id.hashCode.abs() % 1000),
      'You are near a landmark!',
      '$name is nearby. Come by, explore, and earn its badge!',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'landmark_discovery',
          'Nearby landmarks',
          channelDescription: 'Alerts when an unclaimed landmark is nearby.',
          icon: 'ic_stat_explorer',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: 'landmark:$id',
    );
  }

  static Future<void> showVisit({
    required String landmarkId,
    required String title,
    required String body,
  }) async {
    await initialize();
    await plugin.show(
      _visitId(landmarkId),
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'active_journey',
          'Active visits and commutes',
          channelDescription: 'Ongoing landmark visits and commute guidance.',
          icon: 'ic_stat_explorer',
          importance: Importance.low,
          priority: Priority.low,
          ongoing: true,
          onlyAlertOnce: true,
          showWhen: true,
        ),
      ),
      payload: 'visit:$landmarkId',
    );
  }

  static Future<void> showCommute({
    required String tripId,
    required String status,
    required String instruction,
  }) async {
    await initialize();
    await plugin.show(
      foregroundId,
      status,
      instruction,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'active_journey',
          'Active visits and commutes',
          channelDescription: 'Ongoing landmark visits and commute guidance.',
          icon: 'ic_stat_explorer',
          importance: Importance.low,
          priority: Priority.low,
          ongoing: true,
          onlyAlertOnce: true,
        ),
      ),
      payload: 'commute:$tripId',
    );
  }

  static Future<void> showBadgeEarned(Map<String, dynamic> state) async {
    await initialize();
    final landmarkId = state['landmarkId']?.toString() ?? '';
    final badge = state['badge'] is Map
        ? Map<String, dynamic>.from(state['badge'] as Map)
        : const <String, dynamic>{};
    final name = badge['name']?.toString() ?? 'Landmark badge';
    await plugin.show(
      rewardId + (landmarkId.hashCode.abs() % 1000),
      'New badge unlocked!',
      '$name is now yours. View your badge and nearby partner rewards.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'badge_rewards',
          'Badge rewards',
          channelDescription: 'Landmark badge unlock notifications.',
          icon: 'ic_stat_explorer',
          importance: Importance.max,
          priority: Priority.max,
          category: AndroidNotificationCategory.status,
        ),
      ),
      payload: 'badge:$landmarkId',
    );
    await cancelVisit(landmarkId);
  }

  static int _visitId(String landmarkId) =>
      12000 + (landmarkId.hashCode.abs() % 4000);

  static Future<void> cancelVisit(String landmarkId) =>
      plugin.cancel(_visitId(landmarkId));
  static Future<void> cancelCommute() => plugin.cancel(foregroundId);
}
