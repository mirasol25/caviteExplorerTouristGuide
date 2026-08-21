import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
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
  int _nearTargetSamples = 0;
  int _vehicleMovementSamples = 0;
  Timer? _nearTargetTimer;

  final Map<int, int> _legProgress = {};
  final Set<int> _completedLegs = {};

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
            16.5,
          );
        } catch (_) {
          // The first location can arrive before FlutterMap is attached.
        }
      });
    }
    _evaluateNavigation(position, speed);
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
        setState(() => _phase = 'riding');
        _nearTargetSamples = 0;
      }
      return;
    }

    if (_phase == 'riding') {
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
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _nearTargetTimer?.cancel();
    _positionStream?.cancel();
    super.dispose();
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

  String get _statusLabel => switch (_phase) {
        'approaching_boarding' => 'Walk to your boarding point',
        'waiting_to_board' => 'Board your ride',
        'riding' => _distanceToTarget != null && _distanceToTarget! <= 150
            ? 'Prepare to get off'
            : 'Ride in progress',
        'alighting' => 'Get off here',
        'arriving' => 'Almost there',
        'arrived' => 'You have arrived',
        _ => 'Follow the walking path',
      };

  String get _currentInstruction {
    final step = _activeStep;
    if (step == null) return '';
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
        return 'Your drop-off is near. Prepare to get off the $mode.';
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
      if (_completedLegs.contains(leg.index)) continue;
      final active = leg.index == activeLegIndex;
      final progress =
          active && _phase == 'riding' ? (_legProgress[leg.index] ?? 0) : 0;
      final points = leg.points.sublist(
        progress.clamp(0, leg.points.length - 1),
      );
      if (points.length < 2) continue;
      final color = active
          ? leg.isOnDemand
              ? const Color(0xFFF26432)
              : const Color(0xFF2878F0)
          : const Color(0xFFB8C2CC);
      if (active) {
        polylines.add(Polyline(
          points: points,
          strokeWidth: 8,
          color: Colors.white,
        ));
      }
      polylines.add(Polyline(
        points: points,
        strokeWidth: active ? 5 : 3,
        color: color,
        pattern: active
            ? const StrokePattern.solid()
            : StrokePattern.dashed(segments: const [7, 6]),
      ));
    }
    return polylines;
  }

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
            if (_currentPosition != null &&
                target != null &&
                _phase != 'riding')
              PolylineLayer(polylines: [
                Polyline(
                  points: [
                    LatLng(
                      _currentPosition!.latitude,
                      _currentPosition!.longitude,
                    ),
                    target,
                  ],
                  strokeWidth: 3,
                  color: const Color(0xFF2878F0),
                  pattern: StrokePattern.dashed(segments: const [7, 6]),
                ),
              ]),
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
          right: 14,
          bottom: 14,
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
      ],
    );
  }

  Widget _buildInstructionCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFD9E7FF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 16,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: _tripCompleted
                      ? const Color(0xFF2FA54A)
                      : const Color(0xFF2878F0),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _statusLabel,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _tripCompleted
                        ? const Color(0xFF2FA54A)
                        : const Color(0xFF2878F0),
                  ),
                ),
              ),
              if (_phase == 'riding')
                Text(
                  '${(_currentSpeed * 3.6).round()} km/h',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF2FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _tripCompleted ? Icons.check : _iconFor(_activeStep),
                  color: const Color(0xFF2878F0),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _tripCompleted
                          ? 'You reached your destination.'
                          : _currentInstruction,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF202124),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _tripCompleted
                          ? 'Trip completed automatically'
                          : _distanceText,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!_locationAvailable) ...[
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: _enableLiveLocation,
              icon: const Icon(Icons.my_location, size: 17),
              label: const Text('Enable live location'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSteps() {
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 18),
      childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
      title: Text(
        '${math.min(_currentStep + 1, _steps.length)} of ${_steps.length} commute steps',
        style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        'Steps advance automatically with your location',
        style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[600]),
      ),
      children: List.generate(_steps.length, (index) {
        final step = _steps[index];
        final done = index < _currentStep || _tripCompleted;
        final current = index == _currentStep && !_tripCompleted;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: done || current
                      ? const Color(0xFF2878F0)
                      : const Color(0xFFE9EDF2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  done ? Icons.check : _iconFor(step),
                  color: done || current ? Colors.white : Colors.grey[600],
                  size: 16,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Text(
                    step['instruction']?.toString() ?? '',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      height: 1.35,
                      fontWeight: current ? FontWeight.w700 : FontWeight.w400,
                      color: done ? Colors.grey[500] : const Color(0xFF30343B),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }),
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
        child: Column(
          children: [
            Expanded(
              flex: 5,
              child: Container(
                margin: const EdgeInsets.fromLTRB(14, 4, 14, 0),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFFDDE3E8)),
                ),
                child: _buildMap(),
              ),
            ),
            Expanded(
              flex: 6,
              child: ListView(
                padding: const EdgeInsets.only(bottom: 16),
                children: [
                  _buildInstructionCard(),
                  const SizedBox(height: 6),
                  _buildSteps(),
                  if (_tripCompleted)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2878F0),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            'Done',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
