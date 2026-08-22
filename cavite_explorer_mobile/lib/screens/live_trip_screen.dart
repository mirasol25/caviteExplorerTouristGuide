import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/background_tracking_service.dart';
import '../services/location_service.dart';

class _NavigationLeg {
  final int index;
  final String mode;
  final String signboard;
  final bool isOnDemand;
  final List<LatLng> points;

  const _NavigationLeg({
    required this.index,
    required this.mode,
    required this.signboard,
    required this.isOnDemand,
    required this.points,
  });
}

/// Foreground, location-aware guidance for an administrator-verified commute.
/// GPS only advances through the saved journey; it never invents another route.
class LiveTripScreen extends StatefulWidget {
  final Map<String, dynamic> trip;

  const LiveTripScreen({super.key, required this.trip});

  @override
  State<LiveTripScreen> createState() => _LiveTripScreenState();
}

class _LiveTripScreenState extends State<LiveTripScreen> {
  static const double _boardingRadiusMeters = 55;
  static const double _arrivalRadiusMeters = 45;
  static const double _routeCorridorMeters = 90;
  static const double _vehicleSpeedMetersPerSecond = 2.7;

  final MapController _mapController = MapController();
  StreamSubscription<Position>? _positionStream;
  Position? _currentPosition;
  DateTime? _previousPositionAt;

  int _currentStep = 0;
  String _phase = 'walking';
  double? _distanceToTarget;
  double _currentSpeed = 0;
  bool _locationAvailable = false;
  bool _followUser = true;
  bool _tripCompleted = false;
  bool _completionSynced = false;
  bool _isOffRoute = false;
  bool _routeServiceAvailable = true;
  bool _arrivalSummaryShown = false;
  int _nearTargetSamples = 0;
  int _vehicleMovementSamples = 0;
  int _futureLegMatchSamples = 0;
  int _offRouteSamples = 0;
  Timer? _nearTargetTimer;
  Timer? _badgeUiTimer;
  Timer? _badgeServerTimer;
  DateTime? _lastBadgeCheckInAt;
  bool _badgeCheckInFlight = false;
  final ValueNotifier<Map<String, dynamic>> _badgeVisit =
      ValueNotifier<Map<String, dynamic>>({
    'status': 'VERIFYING',
    'requiredSeconds': 30 * 60,
    'remainingSeconds': 30 * 60,
    'accumulatedSeconds': 0,
    'graceRemainingSeconds': 5 * 60,
    'earned': false,
  });
  final DateTime _tripStartedAt = DateTime.now();
  String? _lastAlertKey;
  String? _lastPublishedCommuteState;

  final Map<int, int> _legProgress = {};
  final Set<int> _completedLegs = {};
  List<LatLng> _walkingRoute = [];
  LatLng? _walkingRouteTarget;
  int _walkingProgress = 0;
  int _walkingRouteRequestId = 0;
  bool _walkingRouteLoading = false;

  late final List<Map<String, dynamic>> _navigationSteps;
  List<Map<String, dynamic>> get _steps => _navigationSteps;

  late final List<_NavigationLeg> _legs = _parseLegs();

  List<_NavigationLeg> _parseLegs() {
    final values = (widget.trip['routeGeometry'] as List?) ?? const [];
    final grouped = <int, List<LatLng>>{};
    final metadata = <int, Map<String, dynamic>>{};
    for (final value in values.whereType<Map>()) {
      final latitude = (value['latitude'] as num?)?.toDouble();
      final longitude = (value['longitude'] as num?)?.toDouble();
      if (latitude == null || longitude == null) continue;
      final index = (value['legIndex'] as num?)?.toInt() ?? 0;
      grouped.putIfAbsent(index, () => []).add(LatLng(latitude, longitude));
      metadata.putIfAbsent(index, () => Map<String, dynamic>.from(value));
    }
    return grouped.entries
        .where((entry) => entry.value.length >= 2)
        .map((entry) {
      final data = metadata[entry.key] ?? const <String, dynamic>{};
      return _NavigationLeg(
        index: entry.key,
        mode: data['mode']?.toString() ?? 'Public transport',
        signboard: data['signboard']?.toString() ?? 'Verified route',
        isOnDemand: data['isOnDemand'] == true,
        points: entry.value,
      );
    }).toList()
      ..sort((first, second) => first.index.compareTo(second.index));
  }

  Map<String, dynamic>? get _activeStep {
    if (_steps.isEmpty || _currentStep < 0 || _currentStep >= _steps.length) {
      return null;
    }
    return _steps[_currentStep];
  }

  String _typeOf(Map<String, dynamic>? step) =>
      step?['type']?.toString().toLowerCase() ?? '';

  int? _legIndexOf(Map<String, dynamic>? step) =>
      (step?['legIndex'] as num?)?.toInt();

  int? _legIndexAt(int stepIndex) {
    if (stepIndex < 0 || stepIndex >= _steps.length) return null;
    final explicit = _legIndexOf(_steps[stepIndex]);
    if (explicit != null) return explicit;
    var rideIndex = -1;
    for (var index = 0; index <= stepIndex; index++) {
      if (_typeOf(_steps[index]) == 'ride') rideIndex++;
    }
    if (rideIndex >= 0) return rideIndex;
    return _legs.isEmpty ? null : 0;
  }

  _NavigationLeg? _legByIndex(int? index) {
    if (index == null) return null;
    for (final leg in _legs) {
      if (leg.index == index) return leg;
    }
    return null;
  }

  LatLng? _pointFor(dynamic step) {
    if (step is! Map) return null;
    final latitude = (step['latitude'] as num?)?.toDouble();
    final longitude = (step['longitude'] as num?)?.toDouble();
    return latitude == null || longitude == null
        ? null
        : LatLng(latitude, longitude);
  }

  LatLng? _nextPinnedPoint(int from) {
    for (var index = from; index < _steps.length; index++) {
      final point = _pointFor(_steps[index]);
      if (point != null) return point;
    }
    return null;
  }

  LatLng? _dropOffForRide(int stepIndex) {
    final legIndex = _legIndexAt(stepIndex);
    for (var index = stepIndex + 1; index < _steps.length; index++) {
      final step = _steps[index];
      if (_typeOf(step) == 'alight' && _legIndexAt(index) == legIndex) {
        return _pointFor(step);
      }
      if (_typeOf(step) == 'ride') break;
    }
    final leg = _legByIndex(legIndex);
    return leg?.points.last ?? _nextPinnedPoint(stepIndex + 1);
  }

  LatLng? get _activeTarget {
    final step = _activeStep;
    if (step == null) return null;
    final type = _typeOf(step);
    if (type == 'ride' && _phase == 'riding') {
      return _dropOffForRide(_currentStep);
    }
    if (type == 'walk' && _pointFor(step) == null) {
      return _nextPinnedPoint(_currentStep + 1);
    }
    return _pointFor(step) ?? _nextPinnedPoint(_currentStep + 1);
  }

  @override
  void initState() {
    super.initState();
    _navigationSteps = ((widget.trip['commuteGuide'] as List?) ?? const [])
        .whereType<Map>()
        .map((step) => Map<String, dynamic>.from(step))
        .toList();
    final savedStep = (widget.trip['currentStep'] as num?)?.toInt() ?? 0;
    _currentStep = _steps.isEmpty ? 0 : savedStep.clamp(0, _steps.length - 1);
    _inferCompletedLegs();
    _prepareCurrentStep(skipStartingStep: true);
    _startLocationTracking();
    unawaited(BackgroundTrackingService.startCommute(widget.trip));
  }

  void _inferCompletedLegs() {
    for (var index = 0;
        index < math.min(_currentStep, _steps.length);
        index++) {
      if (_typeOf(_steps[index]) == 'alight') {
        final legIndex = _legIndexAt(index);
        if (legIndex != null) _completedLegs.add(legIndex);
      }
    }
  }

  void _prepareCurrentStep({bool skipStartingStep = false}) {
    if (_steps.isEmpty) return;
    if (skipStartingStep &&
        _currentStep < _steps.length - 1 &&
        _steps[_currentStep]['phase'] == 'start') {
      _currentStep++;
    }
    final type = _typeOf(_activeStep);
    _phase = switch (type) {
      'ride' => 'approaching_boarding',
      'arrival' => 'arriving',
      'alight' => 'alighting',
      _ => 'walking',
    };
    _nearTargetSamples = 0;
    _vehicleMovementSamples = 0;
    _futureLegMatchSamples = 0;
    _offRouteSamples = 0;
    _isOffRoute = false;
    _distanceToTarget = null;
    _nearTargetTimer?.cancel();
  }

  Future<void> _startLocationTracking() async {
    await _positionStream?.cancel();
    final firstPosition = await LocationService.promptLocationOnce();
    if (!mounted || firstPosition == null) return;
    _updatePosition(firstPosition);
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5,
      ),
    ).listen(
      _updatePosition,
      onError: (_) {
        if (mounted) setState(() => _locationAvailable = false);
      },
    );
  }

  Future<void> _enableLiveLocation() async {
    final enabled = await LocationService.toggleLocation(true);
    if (!enabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Turn on Location and allow Cavite Explorer to use it.',
            ),
          ),
        );
      }
      return;
    }
    await _startLocationTracking();
  }

  double _effectiveSpeed(Position position) {
    var speed =
        position.speed.isFinite && position.speed >= 0 ? position.speed : 0.0;
    final previous = _currentPosition;
    final previousAt = _previousPositionAt;
    if (previous != null && previousAt != null) {
      final seconds =
          DateTime.now().difference(previousAt).inMilliseconds / 1000;
      if (seconds > 0.4) {
        final displacement = Geolocator.distanceBetween(
          previous.latitude,
          previous.longitude,
          position.latitude,
          position.longitude,
        );
        speed = math.max(speed, displacement / seconds);
      }
    }
    return speed.clamp(0, 45).toDouble();
  }

  void _sendNavigationAlert(String key, {bool strong = false}) {
    if (_lastAlertKey == key) return;
    _lastAlertKey = key;
    unawaited(SystemSound.play(SystemSoundType.alert));
    unawaited(
        strong ? HapticFeedback.heavyImpact() : HapticFeedback.mediumImpact());
  }

  double _navigationZoom(double speed) {
    if (_distanceToTarget != null && _distanceToTarget! <= 180) return 17.0;
    if (_phase != 'riding') return 17.2;
    if (speed >= 16) return 14.2;
    if (speed >= 8) return 14.8;
    return 15.4;
  }

  void _updateOffRouteState(Position position) {
    if (_tripCompleted) return;
    double? corridorDistance;
    if (_phase == 'riding') {
      corridorDistance = _distanceToLeg(
        position,
        _legByIndex(_legIndexAt(_currentStep)),
      );
    } else if (_walkingRoute.length >= 2) {
      corridorDistance = _distanceToPath(position, _walkingRoute);
    }
    if (corridorDistance == null) return;
    final outside = corridorDistance > (_phase == 'riding' ? 125 : 70);
    _offRouteSamples = outside ? _offRouteSamples + 1 : 0;
    final offRouteNow = _offRouteSamples >= 3;
    if (offRouteNow != _isOffRoute && mounted) {
      setState(() => _isOffRoute = offRouteNow);
      if (offRouteNow) {
        _sendNavigationAlert('off-route-$_currentStep', strong: true);
        if (_phase != 'riding') {
          unawaited(_refreshWalkingRoute(position, force: true));
        }
      }
    }
  }

  void _updatePosition(Position position) {
    if (!mounted) return;
    final speed = _effectiveSpeed(position);
    _previousPositionAt = DateTime.now();
    setState(() {
      _currentPosition = position;
      _currentSpeed = speed;
      _locationAvailable = true;
    });

    if (_followUser) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_followUser) return;
        try {
          _mapController.move(
            LatLng(position.latitude, position.longitude),
            _navigationZoom(speed),
          );
        } catch (_) {
          // The first location can arrive before FlutterMap is attached.
        }
      });
    }
    if (_tripCompleted) {
      return;
    }
    _evaluateNavigation(position, speed);
    _updateOffRouteState(position);
    unawaited(_refreshWalkingRoute(position));
    _publishCommuteState();
  }

  List<LatLng> _decodePolyline6(String encoded) {
    final points = <LatLng>[];
    var index = 0;
    var latitude = 0;
    var longitude = 0;
    while (index < encoded.length) {
      var shift = 0;
      var result = 0;
      int byte;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20 && index < encoded.length);
      latitude += (result & 1) != 0 ? ~(result >> 1) : result >> 1;

      shift = 0;
      result = 0;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20 && index < encoded.length);
      longitude += (result & 1) != 0 ? ~(result >> 1) : result >> 1;
      points.add(LatLng(latitude / 1e6, longitude / 1e6));
    }
    return points;
  }

  double _distanceToPath(Position position, List<LatLng> path) {
    var nearest = double.infinity;
    for (final point in path) {
      nearest = math.min(
        nearest,
        Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          point.latitude,
          point.longitude,
        ),
      );
    }
    return nearest;
  }

  void _updateWalkingProgress(Position position) {
    if (_walkingRoute.length < 2) return;
    var bestIndex = _walkingProgress;
    var bestDistance = double.infinity;
    for (var index = _walkingProgress; index < _walkingRoute.length; index++) {
      final point = _walkingRoute[index];
      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        point.latitude,
        point.longitude,
      );
      if (distance < bestDistance) {
        bestDistance = distance;
        bestIndex = index;
      }
    }
    if (bestDistance <= 55 && bestIndex > _walkingProgress && mounted) {
      setState(() => _walkingProgress = bestIndex);
    }
  }

  Future<void> _refreshWalkingRoute(Position position,
      {bool force = false}) async {
    if (_tripCompleted || _phase == 'riding') {
      if (_walkingRoute.isNotEmpty && mounted) {
        setState(() {
          _walkingRoute = [];
          _walkingRouteTarget = null;
          _walkingProgress = 0;
        });
      }
      return;
    }
    final target = _activeTarget;
    if (target == null) return;
    final sameTarget = _walkingRouteTarget != null &&
        Geolocator.distanceBetween(
              _walkingRouteTarget!.latitude,
              _walkingRouteTarget!.longitude,
              target.latitude,
              target.longitude,
            ) <=
            5;
    if (sameTarget && _walkingRoute.isNotEmpty && !force) {
      _updateWalkingProgress(position);
      if (_distanceToPath(position, _walkingRoute) <= 55) return;
    }
    if (_walkingRouteLoading) return;

    final requestId = ++_walkingRouteRequestId;
    _walkingRouteLoading = true;
    if (!sameTarget && mounted) {
      setState(() {
        _walkingRoute = [];
        _walkingRouteTarget = target;
        _walkingProgress = 0;
      });
    }
    final request = {
      'locations': [
        {'lat': position.latitude, 'lon': position.longitude},
        {'lat': target.latitude, 'lon': target.longitude},
      ],
      'costing': 'pedestrian',
      'shape_format': 'polyline6',
    };
    final uri = Uri.https(
      'valhalla1.openstreetmap.de',
      '/route',
      {'json': json.encode(request)},
    );
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        if (mounted) setState(() => _routeServiceAvailable = false);
        return;
      }
      final body = json.decode(response.body) as Map<String, dynamic>;
      final trip = body['trip'];
      final legs = trip is Map ? trip['legs'] : null;
      if (legs is! List || legs.isEmpty || legs.first is! Map) return;
      final shape = (legs.first as Map)['shape']?.toString() ?? '';
      if (shape.isEmpty) return;
      final points = _decodePolyline6(shape);
      if (!mounted ||
          requestId != _walkingRouteRequestId ||
          points.length < 2) {
        return;
      }
      setState(() {
        _walkingRoute = points;
        _walkingRouteTarget = target;
        _walkingProgress = 0;
        _routeServiceAvailable = true;
        _isOffRoute = false;
        _offRouteSamples = 0;
      });
    } catch (_) {
      if (mounted) setState(() => _routeServiceAvailable = false);
    } finally {
      if (requestId == _walkingRouteRequestId) _walkingRouteLoading = false;
    }
  }

  void _evaluateNavigation(Position position, double speed) {
    if (_steps.isEmpty || _tripCompleted) return;
    final step = _activeStep;
    if (step == null) return;
    final type = _typeOf(step);

    if (step['phase'] == 'start') {
      _advanceTo(_currentStep + 1);
      return;
    }

    if (type == 'ride' && _phase == 'riding') {
      _updateRouteProgress(position, _legIndexAt(_currentStep));
    }

    final target = _activeTarget;
    if (target == null) return;
    final meters = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      target.latitude,
      target.longitude,
    );
    if (mounted) setState(() => _distanceToTarget = meters);

    switch (type) {
      case 'ride':
        _evaluateRide(position, speed, meters);
      case 'walk':
        _evaluateWalk(meters);
      case 'alight':
        _evaluateAlight(speed, meters);
      case 'arrival':
        _evaluateArrival(meters);
    }
  }

  void _evaluateWalk(double meters) {
    if (_confirmNearTarget(meters <= _arrivalRadiusMeters)) {
      _advanceTo(_currentStep + 1);
    }
  }

  void _evaluateRide(Position position, double speed, double meters) {
    final step = _activeStep!;
    final leg = _legByIndex(_legIndexAt(_currentStep));
    final boardingPoint = _pointFor(step);

    if (_phase == 'approaching_boarding') {
      if (meters <= _boardingRadiusMeters) {
        setState(() {
          _phase = 'waiting_to_board';
          _distanceToTarget = 0;
        });
        _sendNavigationAlert('boarding-${_legIndexAt(_currentStep)}');
      }
      return;
    }

    if (_phase == 'waiting_to_board') {
      final movedFromBoarding = boardingPoint == null
          ? 0.0
          : Geolocator.distanceBetween(
              boardingPoint.latitude,
              boardingPoint.longitude,
              position.latitude,
              position.longitude,
            );
      final routeDistance = _distanceToLeg(position, leg);
      final looksLikeBoarding = speed >= _vehicleSpeedMetersPerSecond &&
          movedFromBoarding >= 20 &&
          routeDistance <= _routeCorridorMeters;
      _vehicleMovementSamples =
          looksLikeBoarding ? _vehicleMovementSamples + 1 : 0;
      if (_vehicleMovementSamples >= 2) {
        setState(() {
          _phase = 'riding';
          _walkingRoute = [];
          _walkingRouteTarget = null;
          _walkingProgress = 0;
        });
        _nearTargetSamples = 0;
      }
      return;
    }

    if (_phase == 'riding') {
      if (_recoverOntoNextRoute(position, speed)) return;
      if (meters <= 150) {
        _sendNavigationAlert('dropoff-near-${_legIndexAt(_currentStep)}');
      }
      final closeEnough = meters <= _boardingRadiusMeters;
      final stopping = speed < _vehicleSpeedMetersPerSecond;
      if (_confirmNearTarget(closeEnough && (stopping || meters <= 25))) {
        final legIndex = _legIndexAt(_currentStep);
        if (legIndex != null) _completedLegs.add(legIndex);
        var next = _currentStep + 1;
        if (next < _steps.length && _typeOf(_steps[next]) == 'alight') next++;
        _advanceTo(next);
      }
    }
  }

  void _evaluateAlight(double speed, double meters) {
    if (!_confirmNearTarget(meters <= _boardingRadiusMeters &&
        speed < _vehicleSpeedMetersPerSecond)) {
      return;
    }
    final legIndex = _legIndexAt(_currentStep);
    if (legIndex != null) _completedLegs.add(legIndex);
    _advanceTo(_currentStep + 1);
  }

  void _evaluateArrival(double meters) {
    if (_confirmNearTarget(meters <= _arrivalRadiusMeters)) _completeTrip();
  }

  bool _confirmNearTarget(bool isNear) {
    if (!isNear) {
      _nearTargetSamples = 0;
      _nearTargetTimer?.cancel();
      return false;
    }
    _nearTargetSamples++;
    if (_nearTargetSamples == 1) {
      _nearTargetTimer?.cancel();
      _nearTargetTimer = Timer(const Duration(seconds: 2), () {
        final position = _currentPosition;
        if (mounted && position != null) _evaluateNavigation(position, 0);
      });
    }
    return _nearTargetSamples >= 2;
  }

  double _distanceToLeg(Position position, _NavigationLeg? leg) {
    if (leg == null || leg.points.isEmpty) return double.infinity;
    var nearest = double.infinity;
    for (final point in leg.points) {
      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        point.latitude,
        point.longitude,
      );
      if (distance < nearest) nearest = distance;
    }
    return nearest;
  }

  ({double distance, int pointIndex}) _nearestPointOnLeg(
    Position position,
    _NavigationLeg leg,
  ) {
    var nearestDistance = double.infinity;
    var nearestIndex = 0;
    for (var index = 0; index < leg.points.length; index++) {
      final point = leg.points[index];
      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        point.latitude,
        point.longitude,
      );
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestIndex = index;
      }
    }
    return (distance: nearestDistance, pointIndex: nearestIndex);
  }

  int? _nextRideStepIndex() {
    for (var index = _currentStep + 1; index < _steps.length; index++) {
      if (_typeOf(_steps[index]) == 'ride') return index;
    }
    return null;
  }

  bool _recoverOntoNextRoute(Position position, double speed) {
    final currentLeg = _legByIndex(_legIndexAt(_currentStep));
    final nextRideStep = _nextRideStepIndex();
    if (currentLeg == null || nextRideStep == null) {
      _futureLegMatchSamples = 0;
      return false;
    }
    final nextLeg = _legByIndex(_legIndexAt(nextRideStep));
    if (nextLeg == null || nextLeg.index == currentLeg.index) {
      _futureLegMatchSamples = 0;
      return false;
    }

    final currentMatch = _nearestPointOnLeg(position, currentLeg);
    final nextMatch = _nearestPointOnLeg(position, nextLeg);
    final closeToNextRoute = nextMatch.distance <= 65;
    final clearlyLeftCurrentRoute = currentMatch.distance > 105 ||
        nextMatch.distance + 45 < currentMatch.distance;
    final distanceToNextStart = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      nextLeg.points.first.latitude,
      nextLeg.points.first.longitude,
    );
    final hasReachedNextService =
        nextMatch.pointIndex > 0 || distanceToNextStart <= 90;

    final matchesFutureLeg =
        closeToNextRoute && clearlyLeftCurrentRoute && hasReachedNextService;
    _futureLegMatchSamples = matchesFutureLeg ? _futureLegMatchSamples + 1 : 0;
    if (_futureLegMatchSamples < 2) return false;

    setState(() {
      _completedLegs.add(currentLeg.index);
      _currentStep = nextRideStep;
      _nearTargetSamples = 0;
      _vehicleMovementSamples = 0;
      _futureLegMatchSamples = 0;
      _offRouteSamples = 0;
      _isOffRoute = false;
      _legProgress[nextLeg.index] = nextMatch.pointIndex;
      _phase =
          speed >= _vehicleSpeedMetersPerSecond ? 'riding' : 'waiting_to_board';
      _walkingRoute = [];
      _walkingRouteTarget = null;
      _walkingProgress = 0;
      final nextTarget = speed >= _vehicleSpeedMetersPerSecond
          ? _dropOffForRide(nextRideStep)
          : nextLeg.points.first;
      _distanceToTarget = nextTarget == null
          ? null
          : Geolocator.distanceBetween(
              position.latitude,
              position.longitude,
              nextTarget.latitude,
              nextTarget.longitude,
            );
    });
    unawaited(_syncProgress());
    _sendNavigationAlert('step-$_currentStep');
    return true;
  }

  void _updateRouteProgress(Position position, int? legIndex) {
    final leg = _legByIndex(legIndex);
    if (leg == null || leg.points.length < 2) return;
    final currentIndex = _legProgress[leg.index] ?? 0;
    var bestIndex = currentIndex;
    var bestDistance = double.infinity;
    for (var index = currentIndex; index < leg.points.length; index++) {
      final point = leg.points[index];
      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        point.latitude,
        point.longitude,
      );
      if (distance < bestDistance) {
        bestDistance = distance;
        bestIndex = index;
      }
    }
    if (bestDistance <= _routeCorridorMeters && bestIndex > currentIndex) {
      setState(() => _legProgress[leg.index] = bestIndex);
    }
  }

  void _advanceTo(int index) {
    if (_steps.isEmpty) return;
    if (index >= _steps.length) {
      _completeTrip();
      return;
    }
    setState(() {
      _currentStep = index.clamp(0, _steps.length - 1);
      _prepareCurrentStep(skipStartingStep: true);
    });
    unawaited(_syncProgress());
    _sendNavigationAlert('step-$_currentStep');
    final currentPosition = _currentPosition;
    if (currentPosition != null) {
      unawaited(_refreshWalkingRoute(currentPosition, force: true));
    }
    Timer(const Duration(milliseconds: 350), () {
      final position = _currentPosition;
      if (mounted && position != null) _evaluateNavigation(position, 0);
    });
  }

  void _completeTrip() {
    if (_tripCompleted) return;
    setState(() {
      _tripCompleted = true;
      _phase = 'arrived';
      _currentStep = math.max(0, _steps.length - 1);
      _distanceToTarget = 0;
      for (final leg in _legs) {
        _completedLegs.add(leg.index);
      }
    });
    if (!_completionSynced) {
      _completionSynced = true;
      unawaited(_syncProgress(status: 'COMPLETED'));
    }
    _sendNavigationAlert('trip-arrived', strong: true);
    BackgroundTrackingService.finishCommute();
    final landmark = widget.trip['landmark'];
    if (landmark is Map) {
      unawaited(BackgroundTrackingService.startVisit(
        Map<String, dynamic>.from(landmark),
      ));
    }
  }

  Future<void> _syncProgress({String status = 'ACTIVE'}) async {
    final tripId = widget.trip['id']?.toString();
    final token = (await AuthService.getUser())?['token'];
    if (tripId == null || token == null || token.isEmpty) return;
    try {
      await http.patch(
        ApiService.uri('/trips/$tripId/progress'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'currentStep': _currentStep,
          'status': status,
        }),
      );
    } catch (_) {
      // Navigation remains usable offline; the next transition retries sync.
    }
  }

  void _skipCurrentStep() {
    final legIndex = _legIndexAt(_currentStep);
    if (_typeOf(_activeStep) == 'ride' && legIndex != null) {
      _completedLegs.add(legIndex);
    }
    var next = _currentStep + 1;
    if (next < _steps.length && _typeOf(_steps[next]) == 'alight') next++;
    _advanceTo(next);
  }

  Future<void> _endTrip() async {
    await _syncProgress(status: 'CANCELLED');
    BackgroundTrackingService.finishCommute();
    if (mounted) Navigator.pop(context);
  }

  void _publishCommuteState() {
    if (_tripCompleted) return;
    final tripId = widget.trip['id']?.toString() ?? '';
    if (tripId.isEmpty) return;
    final key = '$_currentStep|$_phase|$_statusLabel|$_currentInstruction';
    if (_lastPublishedCommuteState == key) return;
    _lastPublishedCommuteState = key;
    BackgroundTrackingService.updateCommute(
      tripId: tripId,
      status: _statusLabel,
      instruction: _currentInstruction,
    );
  }

  @override
  void dispose() {
    _nearTargetTimer?.cancel();
    _badgeUiTimer?.cancel();
    _badgeServerTimer?.cancel();
    _positionStream?.cancel();
    _badgeVisit.dispose();
    super.dispose();
  }

  String? get _landmarkId =>
      widget.trip['landmarkId']?.toString() ??
      (widget.trip['landmark'] as Map?)?['id']?.toString();

  String get _landmarkName =>
      (widget.trip['landmark'] as Map?)?['name']?.toString() ??
      widget.trip['title']?.toString().replaceFirst('Commute to ', '') ??
      'this landmark';

  void _startBadgeCountdown() {
    final configuredMinutes =
        ((widget.trip['landmark'] as Map?)?['badgeRequiredMinutes'] as num?)
                ?.round() ??
            30;
    final requiredSeconds = math.max(1, configuredMinutes) * 60;
    _badgeVisit.value = {
      ..._badgeVisit.value,
      'requiredSeconds': requiredSeconds,
      'remainingSeconds': requiredSeconds,
    };
    _badgeUiTimer?.cancel();
    _badgeServerTimer?.cancel();
    _badgeServerTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      final position = _currentPosition;
      if (position != null) unawaited(_checkInForBadge(position, force: true));
    });
    _badgeUiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final current = Map<String, dynamic>.from(_badgeVisit.value);
      final status = current['status']?.toString();
      if (status == 'ACTIVE') {
        final remaining = math.max(
          0,
          ((current['remainingSeconds'] as num?)?.round() ?? 0) - 1,
        );
        current['remainingSeconds'] = remaining;
        current['accumulatedSeconds'] = math.min(
          (current['requiredSeconds'] as num?)?.round() ?? remaining,
          ((current['accumulatedSeconds'] as num?)?.round() ?? 0) + 1,
        );
      } else if (status == 'PAUSED' || status == 'OUTSIDE') {
        final grace = math.max(
          0,
          ((current['graceRemainingSeconds'] as num?)?.round() ?? 0) - 1,
        );
        current['graceRemainingSeconds'] = grace;
        if (grace == 0 && status == 'PAUSED') {
          current['status'] = 'RESET';
          current['accumulatedSeconds'] = 0;
          current['remainingSeconds'] = current['requiredSeconds'];
        }
      }
      _badgeVisit.value = current;
    });
  }

  Future<void> _checkInForBadge(Position position, {bool force = false}) async {
    final landmarkId = _landmarkId;
    if (landmarkId == null ||
        landmarkId.isEmpty ||
        _badgeCheckInFlight ||
        _badgeVisit.value['earned'] == true) {
      return;
    }
    final now = DateTime.now();
    if (!force &&
        _lastBadgeCheckInAt != null &&
        now.difference(_lastBadgeCheckInAt!) < const Duration(seconds: 5)) {
      return;
    }
    _badgeCheckInFlight = true;
    _lastBadgeCheckInAt = now;
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
          'latitude': position.latitude,
          'longitude': position.longitude,
          'accuracy': position.accuracy,
        }),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        if (!mounted) return;
        _badgeVisit.value = data;
        if (data['earned'] == true) {
          _badgeUiTimer?.cancel();
          _badgeServerTimer?.cancel();
          _sendNavigationAlert('badge-earned-$landmarkId', strong: true);
        }
      }
    } catch (_) {
      // Keep the last verified countdown visible and retry on the next GPS fix.
    } finally {
      _badgeCheckInFlight = false;
    }
  }

  String _countdownText(dynamic secondsValue) {
    final seconds = math.max(0, (secondsValue as num?)?.round() ?? 0);
    final minutes = seconds ~/ 60;
    final remainder = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainder.toString().padLeft(2, '0')}';
  }

  IconData _vehicleIcon(dynamic value) {
    final mode = value?.toString().toLowerCase() ?? '';
    if (mode.contains('tricycle')) return Icons.electric_rickshaw;
    if (mode.contains('jeepney')) return Icons.airport_shuttle;
    if (mode.contains('multicab')) return Icons.local_shipping;
    if (mode.contains('uv')) return Icons.local_taxi;
    return Icons.directions_bus_filled;
  }

  IconData _iconFor(Map<String, dynamic>? step) {
    final type = _typeOf(step);
    if (type == 'ride') return _vehicleIcon(step?['vehicle_mode']);
    if (type == 'transfer' || type == 'alight') return Icons.sync_alt;
    if (type == 'arrival') return Icons.location_on;
    return Icons.directions_walk;
  }

  String get _statusLabel => _isOffRoute
      ? 'You may be off route'
      : switch (_phase) {
          'approaching_boarding' => 'Walk to your boarding point',
          'waiting_to_board' => 'Board your ride',
          'riding' => _distanceToTarget != null && _distanceToTarget! <= 150
              ? _nextRideStepIndex() != null
                  ? 'Prepare to transfer'
                  : 'Prepare to get off'
              : 'Ride in progress',
          'alighting' => 'Get off here',
          'arriving' => 'Almost there',
          'arrived' => 'You have arrived',
          _ => 'Follow the walking path',
        };

  String get _currentInstruction {
    final step = _activeStep;
    if (step == null) return '';
    if (_isOffRoute) {
      return _phase == 'riding'
          ? 'Return to the highlighted verified route. The guide will reconnect automatically.'
          : 'Updating the safest walking connection to your next point.';
    }
    if (_phase == 'waiting_to_board') {
      final mode = step['vehicle_mode']?.toString() ?? 'vehicle';
      final signboard = step['signboard']?.toString() ?? 'verified route';
      if (step['isOnDemand'] == true ||
          mode.toLowerCase().contains('tricycle')) {
        return 'Go to the tricycle, board, and tell the driver your destination.';
      }
      return 'Board the $mode with $signboard signboard.';
    }
    if (_phase == 'riding') {
      final mode = step['vehicle_mode']?.toString() ?? 'vehicle';
      if (_distanceToTarget != null && _distanceToTarget! <= 150) {
        final meters = _distanceToTarget!.round();
        return _nextRideStepIndex() != null
            ? 'Transfer point in $meters m. Prepare to get off the $mode.'
            : 'Your drop-off is $meters m away. Prepare to get off the $mode.';
      }
      return 'Stay on the $mode and follow the verified route.';
    }
    return step['instruction']?.toString() ?? '';
  }

  String get _distanceText {
    final distance = _distanceToTarget;
    if (!_locationAvailable) return 'Location unavailable';
    if (distance == null) return 'Finding your position…';
    if (distance < 1000) return '${distance.round()} m away';
    return '${(distance / 1000).toStringAsFixed(1)} km away';
  }

  String get _nextInstruction {
    for (var index = _currentStep + 1; index < _steps.length; index++) {
      final instruction = _steps[index]['instruction']?.toString().trim() ?? '';
      if (instruction.isNotEmpty) return instruction;
    }
    return _tripCompleted ? 'Trip complete' : 'Continue to your destination';
  }

  int get _ridesRemaining => _steps
      .skip(math.min(_currentStep, _steps.length))
      .where((step) => _typeOf(step) == 'ride')
      .length;

  double? get _totalFare {
    var total = 0.0;
    var found = false;
    for (final step in _steps.where((step) => _typeOf(step) == 'ride')) {
      final fare = step['estimatedFare'];
      if (fare is num) {
        total += fare.toDouble();
        found = true;
      }
    }
    return found ? total : null;
  }

  double _geometryMeters(List<LatLng> points, {int start = 0}) {
    var total = 0.0;
    for (var index = math.max(1, start + 1); index < points.length; index++) {
      total += Geolocator.distanceBetween(
        points[index - 1].latitude,
        points[index - 1].longitude,
        points[index].latitude,
        points[index].longitude,
      );
    }
    return total;
  }

  double get _remainingRouteMeters {
    var total = 0.0;
    final activeLeg = _displayLegIndex;
    for (final leg in _legs) {
      if (_completedLegs.contains(leg.index)) continue;
      final start = leg.index == activeLeg ? (_legProgress[leg.index] ?? 0) : 0;
      total += _geometryMeters(leg.points, start: start);
    }
    if (_phase != 'riding') {
      if (_walkingRoute.length >= 2) {
        total += _geometryMeters(_walkingRoute, start: _walkingProgress);
      } else {
        total += _distanceToTarget ?? 0;
      }
    }
    return total;
  }

  String get _remainingDistanceText {
    final meters = _tripCompleted ? 0.0 : _remainingRouteMeters;
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  String get _etaText {
    if (_tripCompleted) return 'Arrived';
    final meters = _remainingRouteMeters;
    final assumedSpeed = _phase == 'riding'
        ? math.max(_currentSpeed, 5.0)
        : math.max(_currentSpeed, 1.25);
    final minutes = math.max(1, (meters / assumedSpeed / 60).ceil());
    return '$minutes min';
  }

  String get _fareText {
    final fare = _totalFare;
    return fare == null ? 'Fare --' : '₱${fare.toStringAsFixed(0)}';
  }

  String get _gpsStatus {
    final position = _currentPosition;
    if (!_locationAvailable || position == null) return 'GPS unavailable';
    if (position.accuracy <= 20) return 'GPS accurate';
    if (position.accuracy <= 50) return 'GPS fair';
    return 'Weak GPS';
  }

  int? get _displayLegIndex {
    final direct = _legIndexAt(_currentStep);
    if (direct != null) return direct;
    for (var index = _currentStep + 1; index < _steps.length; index++) {
      final next = _legIndexAt(index);
      if (next != null) return next;
    }
    return null;
  }

  List<Polyline> _routePolylines() {
    final activeLegIndex = _displayLegIndex;
    final polylines = <Polyline>[];
    for (final leg in _legs) {
      final active = leg.index == activeLegIndex;
      final completed = _completedLegs.contains(leg.index);
      final progress =
          active && _phase == 'riding' ? (_legProgress[leg.index] ?? 0) : 0;

      if (completed) {
        polylines.add(Polyline(
          points: leg.points,
          strokeWidth: 5,
          color: const Color(0xFF9AA3AD),
        ));
        continue;
      }

      if (active && progress > 0) {
        final passedEnd = (progress + 1).clamp(0, leg.points.length);
        final passedPoints = leg.points.sublist(0, passedEnd);
        if (passedPoints.length >= 2) {
          polylines.add(Polyline(
            points: passedPoints,
            strokeWidth: 5,
            color: const Color(0xFF9AA3AD),
          ));
        }
      }

      final remainingPoints = leg.points.sublist(
        progress.clamp(0, leg.points.length - 1),
      );
      if (remainingPoints.length < 2) continue;
      final color = active
          ? leg.isOnDemand
              ? const Color(0xFFF26432)
              : const Color(0xFF2878F0)
          : const Color(0xFFB8C2CC);
      if (active) {
        polylines.add(Polyline(
          points: remainingPoints,
          strokeWidth: 8,
          color: Colors.white,
        ));
      }
      polylines.add(Polyline(
        points: remainingPoints,
        strokeWidth: active ? 5 : 3,
        color: color,
        pattern: active
            ? const StrokePattern.solid()
            : StrokePattern.dashed(segments: const [7, 6]),
      ));
    }
    return polylines;
  }

  List<Polyline> _walkingPolylines() {
    if (_walkingRoute.length < 2 || _phase == 'riding') return const [];
    final progress = _walkingProgress.clamp(0, _walkingRoute.length - 1);
    final polylines = <Polyline>[];
    if (progress > 0) {
      final passed = _walkingRoute.sublist(0, progress + 1);
      if (passed.length >= 2) {
        polylines.add(Polyline(
          points: passed,
          strokeWidth: 4,
          color: const Color(0xFF9AA3AD),
          pattern: StrokePattern.dashed(segments: const [7, 6]),
        ));
      }
    }
    final remaining = _walkingRoute.sublist(progress);
    if (remaining.length >= 2) {
      polylines.add(Polyline(
        points: remaining,
        strokeWidth: 7,
        color: Colors.white,
        pattern: StrokePattern.dashed(segments: const [7, 6]),
      ));
      polylines.add(Polyline(
        points: remaining,
        strokeWidth: 4,
        color: const Color(0xFF2878F0),
        pattern: StrokePattern.dashed(segments: const [7, 6]),
      ));
    }
    return polylines;
  }

  Widget _buildTripStatusBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xF5FFFFFF),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _statusValue(_etaText, 'remaining'),
          _statusDivider(),
          _statusValue(_remainingDistanceText, 'distance'),
          _statusDivider(),
          _statusValue(_fareText, 'total fare'),
          _statusDivider(),
          _statusValue('$_ridesRemaining', 'rides left'),
        ],
      ),
    );
  }

  Widget _statusValue(String value, String label) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF202124),
            ),
          ),
          Text(
            label,
            maxLines: 1,
            style: GoogleFonts.poppins(fontSize: 8, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _statusDivider() => Container(
        width: 1,
        height: 27,
        color: const Color(0xFFE1E5EA),
      );

  LatLng get _mapCenter {
    if (_currentPosition != null) {
      return LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
    }
    return _activeTarget ??
        (_legs.isNotEmpty
            ? _legs.first.points.first
            : const LatLng(14.4793, 120.8969));
  }

  Widget _buildMap() {
    final target = _activeTarget;
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _mapCenter,
            initialZoom: 15,
            onPositionChanged: (_, hasGesture) {
              if (hasGesture && _followUser && mounted) {
                setState(() => _followUser = false);
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.cavite_explorer_mobile',
            ),
            PolylineLayer(polylines: _routePolylines()),
            if (_walkingRoute.isNotEmpty)
              PolylineLayer(polylines: _walkingPolylines()),
            MarkerLayer(markers: [
              if (target != null && !_tripCompleted)
                Marker(
                  point: target,
                  width: 48,
                  height: 48,
                  child: const Icon(
                    Icons.location_on,
                    color: Color(0xFFEF5350),
                    size: 44,
                    shadows: [Shadow(color: Colors.white, blurRadius: 5)],
                  ),
                ),
              if (_currentPosition != null)
                Marker(
                  point: LatLng(
                    _currentPosition!.latitude,
                    _currentPosition!.longitude,
                  ),
                  width: 52,
                  height: 52,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF2878F0),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 8),
                      ],
                    ),
                    child: Transform.rotate(
                      angle: ((_currentPosition!.heading.isFinite
                                  ? _currentPosition!.heading
                                  : 0) *
                              math.pi) /
                          180,
                      child: const Icon(
                        Icons.navigation,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ),
            ]),
          ],
        ),
        Positioned(
          top: 12,
          left: 12,
          right: 12,
          child: Semantics(
            button: true,
            label: 'Open the full commute guide',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _showFullGuide,
              child: _buildInstructionCard(),
            ),
          ),
        ),
        Positioned(
          right: 14,
          bottom: 82,
          child: FloatingActionButton.small(
            heroTag: 'live-trip-recenter',
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF2878F0),
            onPressed: () {
              setState(() => _followUser = true);
              final position = _currentPosition;
              if (position != null) {
                _mapController.move(
                  LatLng(position.latitude, position.longitude),
                  16.5,
                );
              }
            },
            child: Icon(_followUser ? Icons.gps_fixed : Icons.my_location),
          ),
        ),
        Positioned(
          left: 12,
          right: 12,
          bottom: 12,
          child: _buildTripStatusBar(),
        ),
      ],
    );
  }

  Widget _buildInstructionCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: _tripCompleted
            ? const Color(0xFF237A45)
            : _isOffRoute
                ? const Color(0xFFD95F24)
                : const Color(0xFF1769C9),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              _tripCompleted ? Icons.check : _iconFor(_activeStep),
              color: Colors.white,
              size: 27,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _statusLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.82),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _tripCompleted
                      ? 'You reached your destination.'
                      : _currentInstruction,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                if (!_tripCompleted) ...[
                  const SizedBox(height: 7),
                  Text(
                    'NEXT  $_nextInstruction',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.78),
                    ),
                  ),
                ],
                if (!_locationAvailable)
                  GestureDetector(
                    onTap: _enableLiveLocation,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Tap to enable live location',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          decoration: TextDecoration.underline,
                          decorationColor: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 76),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _tripCompleted ? 'Arrived' : _distanceText,
                  textAlign: TextAlign.right,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                if (_phase == 'riding') ...[
                  const SizedBox(height: 3),
                  Text(
                    '${(_currentSpeed * 3.6).round()} km/h',
                    style: GoogleFonts.poppins(
                      fontSize: 9,
                      color: Colors.white.withValues(alpha: 0.78),
                    ),
                  ),
                ],
                const SizedBox(height: 3),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _locationAvailable
                          ? Icons.gps_fixed_rounded
                          : Icons.gps_off_rounded,
                      size: 11,
                      color: Colors.white.withValues(alpha: 0.82),
                    ),
                    if (!_routeServiceAvailable) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.cloud_off_rounded,
                        size: 11,
                        color: Colors.white.withValues(alpha: 0.82),
                      ),
                    ],
                  ],
                ),
                Icon(
                  Icons.keyboard_arrow_up_rounded,
                  size: 18,
                  color: Colors.white.withValues(alpha: 0.86),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuideStep(int index) {
    final step = _steps[index];
    final done = index < _currentStep || _tripCompleted;
    final current = index == _currentStep && !_tripCompleted;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: done || current
                  ? const Color(0xFF2878F0)
                  : const Color(0xFFE9EDF2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              done ? Icons.check : _iconFor(step),
              color: done || current ? Colors.white : Colors.grey[600],
              size: 17,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(
                step['instruction']?.toString() ?? '',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  height: 1.4,
                  fontWeight: current ? FontWeight.w700 : FontWeight.w400,
                  color: done ? Colors.grey[500] : const Color(0xFF30343B),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showFullGuide() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.62,
        minChildSize: 0.32,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFFFDFCF9),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(22, 10, 22, 28),
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD6D8DA),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Full commute guide',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF202124),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${math.min(_currentStep + 1, _steps.length)} of ${_steps.length} steps · Updates automatically',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _guideStatusChip(
                    _locationAvailable ? Icons.gps_fixed : Icons.gps_off,
                    _gpsStatus,
                    _locationAvailable,
                  ),
                  _guideStatusChip(
                    _routeServiceAvailable ? Icons.cloud_done : Icons.cloud_off,
                    _routeServiceAvailable
                        ? 'Route online'
                        : 'Route temporarily offline',
                    _routeServiceAvailable,
                  ),
                ],
              ),
              const SizedBox(height: 22),
              ...List.generate(_steps.length, _buildGuideStep),
            ],
          ),
        ),
      ),
    );
  }

  Widget _guideStatusChip(IconData icon, String label, bool healthy) {
    final color = healthy ? const Color(0xFF237A45) : const Color(0xFFD95F24);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _showArrivalSummary() {
    final elapsed = DateTime.now().difference(_tripStartedAt);
    final minutes = math.max(1, elapsed.inMinutes);
    final rides = _steps.where((step) => _typeOf(step) == 'ride').length;
    showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => ValueListenableBuilder<Map<String, dynamic>>(
        valueListenable: _badgeVisit,
        builder: (_, visit, __) {
          final status = visit['status']?.toString() ?? 'VERIFYING';
          final earned = visit['earned'] == true || status == 'COMPLETED';
          final paused = status == 'PAUSED';
          final reset = status == 'RESET';
          final outside = status == 'OUTSIDE';
          final active = status == 'ACTIVE';
          final required = math.max(
            1,
            (visit['requiredSeconds'] as num?)?.round() ?? 30 * 60,
          );
          final remaining = math.max(
            0,
            (visit['remainingSeconds'] as num?)?.round() ?? required,
          );
          final accumulated = math.max(0, required - remaining);
          final progress = (accumulated / required).clamp(0.0, 1.0).toDouble();
          final accent = earned
              ? const Color(0xFF198754)
              : paused || reset || outside
                  ? const Color(0xFFE56B2F)
                  : const Color(0xFF2878F0);
          final title = earned
              ? 'Badge unlocked!'
              : paused
                  ? "You're leaving the landmark"
                  : reset
                      ? 'Visit timer reset'
                      : outside
                          ? 'Move closer to the landmark'
                          : active
                              ? 'Stay here to earn your badge'
                              : 'Verifying your visit...';
          final description = earned
              ? 'You completed the verified visit at $_landmarkName.'
              : paused
                  ? 'The countdown is paused. Return within ${_countdownText(visit['graceRemainingSeconds'])} to keep your progress.'
                  : reset
                      ? 'You were away for more than 5 minutes. Return to $_landmarkName to begin again.'
                      : outside
                          ? 'Enter the verified landmark area to start the countdown.'
                          : active
                              ? 'Remain inside the landmark area. Leaving pauses the timer for up to 5 minutes.'
                              : 'Keep location enabled while we confirm that you are inside the landmark.';

          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.82,
            ),
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            decoration: const BoxDecoration(
              color: Color(0xFFFDFCF9),
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD8D8D4),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: 92,
                      height: 92,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox.expand(
                            child: CircularProgressIndicator(
                              value: earned ? 1.0 : progress,
                              strokeWidth: 7,
                              backgroundColor: accent.withValues(alpha: 0.12),
                              color: accent,
                              strokeCap: StrokeCap.round,
                            ),
                          ),
                          Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.11),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              earned
                                  ? Icons.workspace_premium_rounded
                                  : paused || reset || outside
                                      ? Icons.location_off_rounded
                                      : Icons.location_on_rounded,
                              size: 34,
                              color: accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 15),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        height: 1.45,
                        color: Colors.grey[650],
                      ),
                    ),
                    if (!earned) ...[
                      const SizedBox(height: 18),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.18),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.timer_outlined, color: accent, size: 22),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  active ? 'Time remaining' : 'Visit progress',
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    color: Colors.grey[650],
                                  ),
                                ),
                                Text(
                                  _countdownText(remaining),
                                  style: GoogleFonts.poppins(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: accent,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        _summaryValue(
                            Icons.schedule, '$minutes min', 'Travel time'),
                        _summaryValue(Icons.directions_bus, '$rides', 'Rides'),
                        _summaryValue(
                            Icons.payments_outlined, _fareText, 'Fare'),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          if (mounted) Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: earned
                              ? const Color(0xFF198754)
                              : const Color(0xFF2878F0),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          earned ? 'Finish trip' : 'Finish without badge',
                          style:
                              GoogleFonts.poppins(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _summaryValue(IconData icon, String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF2878F0), size: 20),
          const SizedBox(height: 5),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_steps.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Live commute')),
        body: Center(
          child: Text(
            'This trip has no verified commute steps.',
            style: GoogleFonts.poppins(),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F3),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F7F3),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Live commute',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Navigation options',
            onSelected: (value) {
              if (value == 'recenter') {
                setState(() => _followUser = true);
              } else if (value == 'skip') {
                _skipCurrentStep();
              } else if (value == 'end') {
                _endTrip();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'recenter',
                child: ListTile(
                  leading: Icon(Icons.my_location),
                  title: Text('Recenter map'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              if (!_tripCompleted)
                const PopupMenuItem(
                  value: 'skip',
                  child: ListTile(
                    leading: Icon(Icons.skip_next),
                    title: Text('Skip current step'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              if (!_tripCompleted)
                const PopupMenuItem(
                  value: 'end',
                  child: ListTile(
                    leading: Icon(Icons.stop_circle_outlined),
                    title: Text('End trip'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              bottom: _tripCompleted ? 78 : 10,
              child: Container(
                margin: const EdgeInsets.fromLTRB(10, 4, 10, 0),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFFDDE3E8)),
                ),
                child: _buildMap(),
              ),
            ),
            if (_tripCompleted)
              Positioned(
                left: 16,
                right: 16,
                bottom: 10,
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2878F0),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'Done',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
