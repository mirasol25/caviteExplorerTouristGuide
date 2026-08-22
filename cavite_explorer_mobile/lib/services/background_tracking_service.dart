import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:native_geofence/native_geofence.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';
import 'auth_service.dart';
import 'notification_service.dart';

const _landmarksKey = 'background_landmarks';
const _claimedKey = 'claimed_landmark_badges';
const _activeVisitKey = 'active_landmark_visit';
const _visitStateKey = 'active_visit_state';
const _activeVisitIdsKey = 'active_landmark_visits';
const _visitStatesKey = 'active_visit_states';
const _awarenessEnabledKey = 'landmark_awareness_enabled';
const _nearbyCooldownPrefix = 'nearby_notified_';
const _geofenceFingerprintKey = 'landmark_geofence_fingerprint';

Map<String, dynamic>? _landmarkFromPrefs(
    SharedPreferences prefs, String landmarkId) {
  final raw = prefs.getString(_landmarksKey);
  if (raw == null) return null;
  final landmarks = (json.decode(raw) as List?)?.whereType<Map>() ?? const [];
  for (final value in landmarks) {
    if (value['id']?.toString() == landmarkId) {
      return Map<String, dynamic>.from(value);
    }
  }
  return null;
}

Set<String> _activeVisitIds(SharedPreferences prefs) {
  final ids = prefs.getStringList(_activeVisitIdsKey)?.toSet() ?? <String>{};
  final legacy = prefs.getString(_activeVisitKey);
  if (legacy != null && legacy.isNotEmpty) ids.add(legacy);
  return ids;
}

Future<void> _saveActiveVisitIds(
    SharedPreferences prefs, Set<String> ids) async {
  await prefs.setStringList(_activeVisitIdsKey, ids.toList());
  if (ids.isEmpty) {
    await prefs.remove(_activeVisitKey);
  } else {
    await prefs.setString(_activeVisitKey, ids.first);
  }
}

Map<String, Map<String, dynamic>> _visitStates(SharedPreferences prefs) {
  final states = <String, Map<String, dynamic>>{};
  final raw = prefs.getString(_visitStatesKey);
  if (raw != null) {
    final decoded = json.decode(raw);
    if (decoded is Map) {
      for (final entry in decoded.entries) {
        if (entry.value is Map) {
          states[entry.key.toString()] =
              Map<String, dynamic>.from(entry.value as Map);
        }
      }
    }
  }
  final legacy = prefs.getString(_visitStateKey);
  if (states.isEmpty && legacy != null) {
    final state = Map<String, dynamic>.from(json.decode(legacy) as Map);
    final id = state['landmarkId']?.toString();
    if (id != null && id.isNotEmpty) states[id] = state;
  }
  return states;
}

Future<void> _saveVisitStates(SharedPreferences prefs,
    Map<String, Map<String, dynamic>> states) async {
  await prefs.setString(_visitStatesKey, json.encode(states));
  if (states.isEmpty) {
    await prefs.remove(_visitStateKey);
  } else {
    await prefs.setString(_visitStateKey, json.encode(states.values.first));
  }
}

@pragma('vm:entry-point')
Future<void> landmarkGeofenceTriggered(GeofenceCallbackParams params) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  await NotificationService.initialize();
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  final claimed = prefs.getStringList(_claimedKey)?.toSet() ?? <String>{};

  for (final geofence in params.geofences) {
    final separator = geofence.id.indexOf('__');
    if (separator < 0) continue;
    final kind = geofence.id.substring(0, separator);
    final landmarkId = geofence.id.substring(separator + 2);
    if (claimed.contains(landmarkId)) continue;
    final landmark = _landmarkFromPrefs(prefs, landmarkId);
    if (landmark == null) continue;

    if (kind == 'near' && params.event == GeofenceEvent.enter) {
      final key = '$_nearbyCooldownPrefix$landmarkId';
      final last = DateTime.tryParse(prefs.getString(key) ?? '');
      if (last == null ||
          DateTime.now().difference(last) >= const Duration(hours: 24)) {
        await prefs.setString(key, DateTime.now().toIso8601String());
        await NotificationService.showNearby(landmark);
      }
    }

    if (kind == 'visit' && params.event == GeofenceEvent.enter) {
      final activeIds = _activeVisitIds(prefs)..add(landmarkId);
      await _saveActiveVisitIds(prefs, activeIds);
      final states = _visitStates(prefs);
      states.putIfAbsent(
        landmarkId,
        () => {
          'landmarkId': landmarkId,
          'landmarkName': landmark['name'],
          'status': 'VERIFYING',
          'requiredSeconds':
              ((landmark['badgeRequiredMinutes'] as num?)?.round() ?? 30) * 60,
          'remainingSeconds':
              ((landmark['badgeRequiredMinutes'] as num?)?.round() ?? 30) * 60,
        },
      );
      await _saveVisitStates(prefs, states);
      await NotificationService.showVisit(
        landmarkId: landmarkId,
        title: 'You are at ${landmark['name']}!',
        body: 'Your verified badge countdown is starting.',
      );
      final service = FlutterBackgroundService();
      if (!await service.isRunning()) await service.startService();
      service.invoke('startVisit', {'landmarkId': landmarkId});
    }

    if (kind == 'visit' && params.event == GeofenceEvent.exit) {
      if (_activeVisitIds(prefs).contains(landmarkId)) {
        await NotificationService.showVisit(
          landmarkId: landmarkId,
          title: 'You are away from ${landmark['name']}',
          body: 'Return within 5 minutes or your badge timer will reset.',
        );
        FlutterBackgroundService().invoke('verifyVisit');
      }
    }
  }
}

class BackgroundTrackingService {
  static final FlutterBackgroundService _service = FlutterBackgroundService();
  static bool _configured = false;
  static Future<void>? _awarenessRefresh;

  static Future<void> initialize() async {
    await NotificationService.initialize();
    await NativeGeofenceManager.instance.initialize();
    if (_configured) return;
    await _service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: backgroundTrackingEntryPoint,
        autoStart: false,
        autoStartOnBoot: false,
        isForegroundMode: true,
        notificationChannelId: 'active_journey',
        initialNotificationTitle: 'Cavite Explorer',
        initialNotificationContent: 'Preparing location guidance...',
        foregroundServiceNotificationId: NotificationService.foregroundId,
        foregroundServiceTypes: const [AndroidForegroundType.location],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: backgroundTrackingEntryPoint,
        onBackground: (_) async => true,
      ),
    );
    _configured = true;
  }

  static Future<bool> requestAndEnableAwareness() async {
    final foreground = await Permission.location.request();
    final notifications = await NotificationService.requestPermission();
    if (!foreground.isGranted || !notifications) return false;
    final background = await Permission.locationAlways.request();
    if (!background.isGranted) return false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_awarenessEnabledKey, true);
    await refreshLandmarkAwareness();
    return true;
  }

  static Future<bool> get isAwarenessEnabled async =>
      (await SharedPreferences.getInstance()).getBool(_awarenessEnabledKey) ??
      false;

  static Future<void> disableAwareness() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_awarenessEnabledKey, false);
    await NativeGeofenceManager.instance.removeAllGeofences();
  }

  static Future<void> refreshLandmarkAwareness() async {
    if (_awarenessRefresh != null) return _awarenessRefresh!;
    final refresh = _refreshLandmarkAwareness();
    _awarenessRefresh = refresh;
    try {
      await refresh;
    } finally {
      _awarenessRefresh = null;
    }
  }

  static Future<void> _refreshLandmarkAwareness() async {
    final enabled = await isAwarenessEnabled;
    final backgroundGranted = await Permission.locationAlways.isGranted;
    if (!enabled || !backgroundGranted) {
      return;
    }
    final landmarks = await ApiService.getLandmarks();
    final token = (await AuthService.getUser())?['token'];
    final claimed = <String>{};
    if (token != null && token.isNotEmpty) {
      try {
        final response = await http.get(
          ApiService.uri('/badges/me'),
          headers: {'Authorization': 'Bearer $token'},
        );
        if (response.statusCode == 200) {
          final body = json.decode(response.body) as Map<String, dynamic>;
          for (final value in (body['earned'] as List?) ?? const []) {
            if (value is Map && value['landmarkId'] != null) {
              claimed.add(value['landmarkId'].toString());
            }
          }
        }
      } catch (_) {}
    }

    Position? position;
    try {
      position = await Geolocator.getLastKnownPosition();
    } catch (_) {}
    final candidates = landmarks
        .whereType<Map>()
        .map((value) => Map<String, dynamic>.from(value))
        .where((value) => !claimed.contains(value['id']?.toString()))
        .toList();
    if (position != null) {
      final currentPosition = position;
      candidates.sort(
        (a, b) => _distanceTo(currentPosition, a)
            .compareTo(_distanceTo(currentPosition, b)),
      );
    }
    final selected = candidates.take(45).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_landmarksKey, json.encode(selected));
    await prefs.setStringList(_claimedKey, claimed.toList());

    final definitions = selected
        .map((landmark) => {
              'id': landmark['id']?.toString(),
              'latitude': (landmark['latitude'] as num?)?.toDouble(),
              'longitude': (landmark['longitude'] as num?)?.toDouble(),
              'radius': math
                  .max(
                    100,
                    (landmark['badgeRadiusMeters'] as num?)?.toDouble() ?? 100,
                  )
                  .toDouble(),
            })
        .where((value) =>
            value['id'] != null &&
            value['latitude'] != null &&
            value['longitude'] != null)
        .toList()
      ..sort((a, b) => a['id'].toString().compareTo(b['id'].toString()));
    final fingerprint = json.encode(definitions);
    final expectedIds = <String>{
      for (final definition in definitions) ...{
        'near__${definition['id']}',
        'visit__${definition['id']}',
      },
    };
    try {
      final registered =
          (await NativeGeofenceManager.instance.getRegisteredGeofenceIds())
              .toSet();
      if (prefs.getString(_geofenceFingerprintKey) == fingerprint &&
          registered.length == expectedIds.length &&
          registered.containsAll(expectedIds)) {
        return;
      }
    } catch (_) {
      // Rebuild the registrations when Android cannot return their state.
    }

    await NativeGeofenceManager.instance.removeAllGeofences();
    var allRegistered = true;
    for (final landmark in selected) {
      final id = landmark['id']?.toString();
      final latitude = (landmark['latitude'] as num?)?.toDouble();
      final longitude = (landmark['longitude'] as num?)?.toDouble();
      if (id == null || latitude == null || longitude == null) continue;
      final location = Location(latitude: latitude, longitude: longitude);
      try {
        await NativeGeofenceManager.instance.createGeofence(
          Geofence(
            id: 'near__$id',
            location: location,
            radiusMeters: 500,
            triggers: const {GeofenceEvent.enter},
            androidSettings: AndroidGeofenceSettings(
              initialTriggers: const {GeofenceEvent.enter},
              expiration: const Duration(days: 30),
              notificationResponsiveness: const Duration(minutes: 1),
            ),
            iosSettings: const IosGeofenceSettings(initialTrigger: true),
          ),
          landmarkGeofenceTriggered,
        );
        await NativeGeofenceManager.instance.createGeofence(
          Geofence(
            id: 'visit__$id',
            location: location,
            radiusMeters: math
                .max(
                  100,
                  (landmark['badgeRadiusMeters'] as num?)?.toDouble() ?? 100,
                )
                .toDouble(),
            triggers: const {GeofenceEvent.enter, GeofenceEvent.exit},
            androidSettings: AndroidGeofenceSettings(
              initialTriggers: const {GeofenceEvent.enter},
              expiration: const Duration(days: 30),
              notificationResponsiveness: const Duration(seconds: 30),
            ),
            iosSettings: const IosGeofenceSettings(initialTrigger: true),
          ),
          landmarkGeofenceTriggered,
        );
      } catch (error) {
        allRegistered = false;
        debugPrint('Could not register landmark geofence $id: $error');
      }
    }
    if (allRegistered) {
      await prefs.setString(_geofenceFingerprintKey, fingerprint);
    } else {
      await prefs.remove(_geofenceFingerprintKey);
    }
  }

  static double _distanceTo(Position position, Map<String, dynamic> landmark) {
    return Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      (landmark['latitude'] as num?)?.toDouble() ?? 0,
      (landmark['longitude'] as num?)?.toDouble() ?? 0,
    );
  }

  static Future<void> startVisit(Map<String, dynamic> landmark) async {
    await initialize();
    final id = landmark['id']?.toString();
    if (id == null || id.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final claimed = prefs.getStringList(_claimedKey) ?? const <String>[];
    if (claimed.contains(id)) return;
    final stored = _landmarkFromPrefs(prefs, id);
    if (stored == null) {
      final list = (json.decode(prefs.getString(_landmarksKey) ?? '[]') as List)
          .whereType<Map>()
          .map((value) => Map<String, dynamic>.from(value))
          .toList()
        ..add(Map<String, dynamic>.from(landmark));
      await prefs.setString(_landmarksKey, json.encode(list));
    }
    final activeIds = _activeVisitIds(prefs)..add(id);
    await _saveActiveVisitIds(prefs, activeIds);
    if (!await _service.isRunning()) await _service.startService();
    _service.invoke('startVisit', {'landmarkId': id});
  }

  static Future<void> startCommute(Map<String, dynamic> trip) async {
    await initialize();
    if (!await _service.isRunning()) await _service.startService();
    _service.invoke('startCommute', {
      'tripId': trip['id']?.toString() ?? '',
      'status': 'Live commute active',
      'instruction': 'Preparing your verified commute guide...',
    });
  }

  static void updateCommute({
    required String tripId,
    required String status,
    required String instruction,
  }) {
    _service.invoke('updateCommute', {
      'tripId': tripId,
      'status': status,
      'instruction': instruction,
    });
  }

  static void finishCommute() => _service.invoke('finishCommute');
  static void setAppForeground(bool value) =>
      _service.invoke('appVisibility', {'foreground': value});
}

@pragma('vm:entry-point')
void backgroundTrackingEntryPoint(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.initialize();
  final prefs = await SharedPreferences.getInstance();
  Position? latestPosition;
  final checking = <String>{};
  Map<String, dynamic>? commute;

  Future<void> publishVisit(Map<String, dynamic> state) async {
    final landmarkId = state['landmarkId']?.toString() ?? '';
    final states = _visitStates(prefs);
    states[landmarkId] = state;
    await _saveVisitStates(prefs, states);
    service.invoke('visitUpdate', state);
    final remaining = (state['remainingSeconds'] as num?)?.round() ?? 0;
    final grace = (state['graceRemainingSeconds'] as num?)?.round() ?? 0;
    final status = state['status']?.toString() ?? 'VERIFYING';
    if (state['earned'] == true || status == 'COMPLETED') {
      final claimed = prefs.getStringList(_claimedKey)?.toSet() ?? <String>{};
      claimed.add(landmarkId);
      await prefs.setStringList(_claimedKey, claimed.toList());
      final activeIds = _activeVisitIds(prefs)..remove(landmarkId);
      await _saveActiveVisitIds(prefs, activeIds);
      states.remove(landmarkId);
      await _saveVisitStates(prefs, states);
      await NotificationService.showBadgeEarned(state);
      service.invoke('badgeEarned', state);
      if (commute == null && activeIds.isEmpty) service.stopSelf();
      return;
    }
    final minutes = remaining ~/ 60;
    final seconds = remaining % 60;
    final countdown =
        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    if (status == 'PAUSED' || status == 'OUTSIDE') {
      await NotificationService.showVisit(
        landmarkId: landmarkId,
        title: "You're away from the landmark",
        body:
            'Countdown paused. Return within ${(grace / 60).ceil()} minute(s) to keep your progress.',
      );
    } else if (status == 'RESET') {
      await NotificationService.showVisit(
        landmarkId: landmarkId,
        title: 'Landmark visit timer reset',
        body: 'Return to the landmark to start earning this badge again.',
      );
    } else {
      await NotificationService.showVisit(
        landmarkId: landmarkId,
        title: 'Stay here to earn your badge',
        body: '$countdown remaining in your verified visit.',
      );
    }
  }

  Future<void> checkVisit(String landmarkId) async {
    if (checking.contains(landmarkId) || latestPosition == null) return;
    await prefs.reload();
    if (!_activeVisitIds(prefs).contains(landmarkId)) return;
    checking.add(landmarkId);
    try {
      final token = (await AuthService.getUser())?['token'];
      if (token == null || token.isEmpty) return;
      final response = await http.post(
        ApiService.uri('/badges/$landmarkId/check-in'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'latitude': latestPosition!.latitude,
          'longitude': latestPosition!.longitude,
          'accuracy': latestPosition!.accuracy,
        }),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final state = json.decode(response.body) as Map<String, dynamic>;
        state['landmarkId'] = landmarkId;
        state['landmarkName'] = _landmarkFromPrefs(prefs, landmarkId)?['name'];
        await publishVisit(state);
      }
    } catch (error) {
      debugPrint('Background badge check failed: $error');
    } finally {
      checking.remove(landmarkId);
    }
  }

  Future<void> checkVisits() async {
    await prefs.reload();
    final ids = _activeVisitIds(prefs);
    // Keep preference updates ordered so two overlapping landmark check-ins
    // cannot overwrite one another's stored state.
    for (final id in ids) {
      await checkVisit(id);
    }
  }

  service.on('startVisit').listen((event) async {
    final id = event?['landmarkId']?.toString();
    if (id != null && id.isNotEmpty) {
      final ids = _activeVisitIds(prefs)..add(id);
      await _saveActiveVisitIds(prefs, ids);
      await checkVisit(id);
    }
  });
  service.on('verifyVisit').listen((_) => checkVisits());
  service.on('startCommute').listen((event) async {
    commute = event == null ? null : Map<String, dynamic>.from(event);
    if (commute != null) {
      await NotificationService.showCommute(
        tripId: commute!['tripId']?.toString() ?? '',
        status: commute!['status']?.toString() ?? 'Live commute',
        instruction: commute!['instruction']?.toString() ?? '',
      );
    }
  });
  service.on('updateCommute').listen((event) async {
    if (event == null) return;
    commute = Map<String, dynamic>.from(event);
    await NotificationService.showCommute(
      tripId: commute!['tripId']?.toString() ?? '',
      status: commute!['status']?.toString() ?? 'Live commute',
      instruction: commute!['instruction']?.toString() ?? '',
    );
  });
  service.on('finishCommute').listen((_) async {
    commute = null;
    await NotificationService.cancelCommute();
    await prefs.reload();
    if (_activeVisitIds(prefs).isEmpty) service.stopSelf();
  });

  try {
    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 8,
      ),
    ).listen((position) {
      latestPosition = position;
      unawaited(checkVisits());
    });
    latestPosition = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
  } catch (error) {
    debugPrint('Background location could not start: $error');
  }
  Timer.periodic(const Duration(seconds: 5), (_) => checkVisits());
}

class VisitTrackingController {
  VisitTrackingController._();
  static final instance = VisitTrackingController._();

  final ValueNotifier<List<Map<String, dynamic>>> visits =
      ValueNotifier(<Map<String, dynamic>>[]);
  final ValueNotifier<Map<String, dynamic>?> visit = ValueNotifier(null);
  final ValueNotifier<Map<String, dynamic>?> unlockedBadge =
      ValueNotifier(null);
  StreamSubscription<Map<String, dynamic>?>? _visitSubscription;
  StreamSubscription<Map<String, dynamic>?>? _badgeSubscription;
  Timer? _ticker;

  Future<void> initialize() async {
    await BackgroundTrackingService.initialize();
    final prefs = await SharedPreferences.getInstance();
    visits.value = _visitStates(prefs).values.toList();
    _syncPrimary();
    _visitSubscription ??=
        FlutterBackgroundService().on('visitUpdate').listen((value) {
      if (value != null) _upsert(Map<String, dynamic>.from(value));
    });
    _badgeSubscription ??=
        FlutterBackgroundService().on('badgeEarned').listen((value) {
      if (value != null) {
        final state = Map<String, dynamic>.from(value);
        final id = state['landmarkId']?.toString();
        visits.value = visits.value
            .where((item) => item['landmarkId']?.toString() != id)
            .toList();
        _syncPrimary();
        unlockedBadge.value = state;
      }
    });
    _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) {
      var changed = false;
      final nextVisits = visits.value.map((current) {
        final next = Map<String, dynamic>.from(current);
        final status = next['status']?.toString();
        if (status == 'ACTIVE') {
          next['remainingSeconds'] = math.max(
            0,
            ((next['remainingSeconds'] as num?)?.round() ?? 0) - 1,
          );
          changed = true;
        } else if (status == 'PAUSED' || status == 'OUTSIDE') {
          final grace =
              ((next['graceRemainingSeconds'] as num?)?.round() ?? 300) - 1;
          next['graceRemainingSeconds'] = math.max(0, grace);
          changed = true;
        }
        return next;
      }).toList();
      if (changed) {
        visits.value = nextVisits;
        _syncPrimary();
      }
    });
    unawaited(BackgroundTrackingService.refreshLandmarkAwareness());
  }

  void _upsert(Map<String, dynamic> state) {
    final id = state['landmarkId']?.toString();
    if (id == null || id.isEmpty) return;
    final next = visits.value
        .where((item) => item['landmarkId']?.toString() != id)
        .toList();
    if (state['earned'] != true && state['status']?.toString() != 'COMPLETED') {
      next.insert(0, state);
    }
    visits.value = next;
    _syncPrimary();
  }

  void _syncPrimary() {
    if (visits.value.isEmpty) {
      visit.value = null;
      return;
    }
    final active = visits.value.where(
      (item) => item['status']?.toString() == 'ACTIVE',
    );
    visit.value = active.isNotEmpty ? active.first : visits.value.first;
  }

  void consumeUnlock() => unlockedBadge.value = null;
}
