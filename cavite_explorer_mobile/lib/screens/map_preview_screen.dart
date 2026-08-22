import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'live_trip_screen.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';

class MapPreviewScreen extends StatefulWidget {
  final Map<String, dynamic> place;
  final Position? userPosition;

  const MapPreviewScreen({super.key, required this.place, this.userPosition});

  @override
  State<MapPreviewScreen> createState() => _MapPreviewScreenState();
}

class _MapPreviewScreenState extends State<MapPreviewScreen> {
  final MapController _mapController = MapController();
  Position? _currentPosition;

  String _distanceText = "Calculating...";
  String _startAddress = "Your Current Location"; // Saved to pass to AI

  // --- ⚡ AI COMMUTE STATE ---
  List<dynamic> _commuteSteps = [];
  String _estimatedFare = "₱--";
  bool _isAiLoading = true;
  bool _isStartingCommute = false;
  int _routeRequestId = 0;
  final Map<String, List<LatLng>> _pathCache = {};

  // --- 🗺️ MAP ROUTE & PINS STATE ---
  List<LatLng> _routePoints = [];
  List<List<LatLng>> _routeSegments = [];
  List<bool> _onDemandRouteSegments = [];
  List<List<LatLng>> _transferWalkSegments = [];
  List<Marker> _aiStepMarkers = [];
  Map<String, dynamic>? _verifiedTransportRoute;
  List<Map<String, dynamic>> _verifiedTransportOptions = [];
  int _selectedTransportOption = 0;

  @override
  void initState() {
    super.initState();
    _currentPosition = widget.userPosition;
    _calculateDistanceOnly();
    _initializeMapAndAI();
    _refreshCurrentLocation();
  }

  Future<void> _refreshCurrentLocation() async {
    var position = await LocationService.promptLocationOnce();
    if (position == null) {
      final enabled = await LocationService.toggleLocation(true);
      if (enabled) position = await LocationService.promptLocationOnce();
    }
    if (!mounted || position == null) return;
    setState(() => _currentPosition = position);
    _calculateDistanceOnly();
  }

  LatLng _getPlaceCoords() {
    double lat = 14.4445;
    double lng = 120.9048;
    try {
      if (widget.place['latitude'] != null)
        lat = double.parse(widget.place['latitude'].toString());
      if (widget.place['longitude'] != null)
        lng = double.parse(widget.place['longitude'].toString());
    } catch (e) {
      debugPrint("Coordinate parsing error: $e");
    }
    return LatLng(lat, lng);
  }

  void _calculateDistanceOnly() {
    final coords = _getPlaceCoords();

    if (_currentPosition != null) {
      double distanceInMeters = Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          coords.latitude,
          coords.longitude);

      double distanceInKm = distanceInMeters / 1000;
      _distanceText = distanceInMeters < 1000
          ? "${distanceInMeters.toStringAsFixed(0)} m away"
          : "${distanceInKm.toStringAsFixed(1)} km away";
      setState(() {});
    } else {
      setState(() {
        _distanceText = "Enable location";
      });
    }
  }

  Future<void> _startLiveCommute() async {
    if (_isStartingCommute) return;
    if (_isAiLoading || _commuteSteps.isEmpty || _routeSegments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Wait for the verified commute route to finish loading.')),
      );
      return;
    }
    setState(() => _isStartingCommute = true);
    try {
      final token = (await AuthService.getUser())?['token'];
      if (token == null || token.isEmpty)
        throw Exception('Sign in to start commuting');
      final now = DateTime.now();
      final commuteGuide = _commuteSteps.map((step) {
        final copy = Map<String, dynamic>.from(step as Map);
        final coords = copy.remove('coords');
        if (coords is LatLng) {
          copy['latitude'] = coords.latitude;
          copy['longitude'] = coords.longitude;
        }
        return copy;
      }).toList();
      final verifiedLegs = _verifiedLegs(_verifiedTransportRoute);
      final routeGeometry = <Map<String, dynamic>>[];
      for (var segmentIndex = 0;
          segmentIndex < _routeSegments.length;
          segmentIndex++) {
        final leg = segmentIndex < verifiedLegs.length
            ? verifiedLegs[segmentIndex]
            : const <String, dynamic>{};
        for (final point in _routeSegments[segmentIndex]) {
          routeGeometry.add({
            'latitude': point.latitude,
            'longitude': point.longitude,
            'legIndex': segmentIndex,
            'mode': leg['mode'],
            'signboard': leg['signboard'],
            'isOnDemand': leg['isOnDemand'] == true,
          });
        }
      }
      final destinationName = widget.place['name']?.toString() ?? 'destination';
      final landmarkId = widget.place['id']?.toString();
      if (landmarkId == null || landmarkId.isEmpty) {
        throw Exception('This destination cannot start a saved commute yet');
      }
      final response = await http.post(
        ApiService.uri('/trips/save'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'landmarkId': landmarkId,
          'title': 'Commute to $destinationName',
          'startAddress': _startAddress,
          'itinerary': const [],
          'commuteGuide': commuteGuide,
          'routeGeometry': routeGeometry,
          'plannedStartAt': now.toIso8601String(),
          'plannedEndAt': now.add(const Duration(hours: 4)).toIso8601String(),
          'tripMode': 'NOW',
          'status': 'ACTIVE',
        }),
      );
      if (response.statusCode != 200 && response.statusCode != 201) {
        final body = json.decode(response.body);
        throw Exception(body['message'] ?? 'Could not start the commute');
      }
      final trip = json.decode(response.body) as Map<String, dynamic>;
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => LiveTripScreen(trip: trip)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _isStartingCommute = false);
    }
  }

  List<LatLng> _decodePolyline(String poly, {int precision = 5}) {
    List<LatLng> points = [];
    int index = 0, len = poly.length;
    int lat = 0, lng = 0;
    final divisor = precision == 6 ? 1E6 : 1E5;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = poly.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;

      do {
        b = poly.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      final latitude = lat / divisor;
      final longitude = lng / divisor;
      if (latitude >= -90 &&
          latitude <= 90 &&
          longitude >= -180 &&
          longitude <= 180) {
        points.add(LatLng(latitude, longitude));
      }
    }
    return points;
  }

  Future<List<LatLng>> _findWalkingPath(LatLng from, LatLng to) async {
    final cacheKey = [
      from.latitude.toStringAsFixed(5),
      from.longitude.toStringAsFixed(5),
      to.latitude.toStringAsFixed(5),
      to.longitude.toStringAsFixed(5),
    ].join(':');
    final cached = _pathCache[cacheKey];
    if (cached != null) return cached;
    final request = {
      'locations': [
        {'lat': from.latitude, 'lon': from.longitude},
        {'lat': to.latitude, 'lon': to.longitude},
      ],
      'costing': 'pedestrian',
      'shape_format': 'polyline6',
      'directions_options': {'units': 'kilometers'},
    };
    final uri = Uri.https(
      'valhalla1.openstreetmap.de',
      '/route',
      {'json': json.encode(request)},
    );
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        debugPrint('Walking route failed (${response.statusCode}).');
        return [];
      }
      final result = json.decode(response.body) as Map<String, dynamic>;
      final trip = result['trip'];
      final legs = trip is Map ? trip['legs'] : null;
      if (legs is! List || legs.isEmpty || legs.first is! Map) return [];
      final shape = (legs.first as Map)['shape']?.toString() ?? '';
      if (shape.isEmpty) return [];
      final points = _decodePolyline(shape, precision: 6);
      if (points.length < 2) return [];
      if (_pathCache.length >= 80) _pathCache.remove(_pathCache.keys.first);
      _pathCache[cacheKey] = points;
      return points;
    } catch (error) {
      debugPrint('Pedestrian routing unavailable: $error');
      return [];
    }
  }

  Future<List<LatLng>> _findTricycleRoadPath(LatLng from, LatLng to) async {
    final cacheKey = [
      'tricycle-road',
      from.latitude.toStringAsFixed(5),
      from.longitude.toStringAsFixed(5),
      to.latitude.toStringAsFixed(5),
      to.longitude.toStringAsFixed(5),
    ].join(':');
    final cached = _pathCache[cacheKey];
    if (cached != null) return cached;
    final request = {
      'locations': [
        {'lat': from.latitude, 'lon': from.longitude},
        {'lat': to.latitude, 'lon': to.longitude},
      ],
      // Tricycles may use narrow neighborhood roads, but must never be routed
      // over pedestrian paths or through an off-road landmark interior.
      'costing': 'motor_scooter',
      'shape_format': 'polyline6',
      'directions_options': {'units': 'kilometers'},
    };
    final uri = Uri.https(
      'valhalla1.openstreetmap.de',
      '/route',
      {'json': json.encode(request)},
    );
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        debugPrint('Tricycle road routing failed (${response.statusCode}).');
        return [];
      }
      final result = json.decode(response.body) as Map<String, dynamic>;
      final trip = result['trip'];
      final legs = trip is Map ? trip['legs'] : null;
      if (legs is! List || legs.isEmpty || legs.first is! Map) return [];
      final shape = (legs.first as Map)['shape']?.toString() ?? '';
      if (shape.isEmpty) return [];
      final points = _decodePolyline(shape, precision: 6);
      if (points.length < 2) return [];
      if (_pathCache.length >= 80) _pathCache.remove(_pathCache.keys.first);
      _pathCache[cacheKey] = points;
      return points;
    } catch (error) {
      debugPrint('Tricycle road routing unavailable: $error');
      return [];
    }
  }

  List<List<LatLng>> _tricycleAccessPaths(dynamic value) {
    if (value is! List) return [];
    return value
        .whereType<List>()
        .map((path) => path.map(_pointFromJson).whereType<LatLng>().toList())
        .where((path) => path.length >= 2)
        .toList();
  }

  double _pathDistance(List<LatLng> path) {
    var total = 0.0;
    for (var index = 1; index < path.length; index++) {
      total += Geolocator.distanceBetween(
        path[index - 1].latitude,
        path[index - 1].longitude,
        path[index].latitude,
        path[index].longitude,
      );
    }
    return total;
  }

  List<LatLng> _joinPaths(Iterable<List<LatLng>> sections) {
    final result = <LatLng>[];
    for (final section in sections) {
      for (final point in section) {
        if (result.isEmpty ||
            Geolocator.distanceBetween(
                  result.last.latitude,
                  result.last.longitude,
                  point.latitude,
                  point.longitude,
                ) >
                1) {
          result.add(point);
        }
      }
    }
    return result;
  }

  Future<List<LatLng>> _findTricyclePath(
    LatLng from,
    LatLng to, {
    dynamic accessPaths,
  }) async {
    final directRequest = _findTricycleRoadPath(from, to);
    final connectors = _tricycleAccessPaths(accessPaths).map((path) {
      final forwardGap = Geolocator.distanceBetween(
            from.latitude,
            from.longitude,
            path.first.latitude,
            path.first.longitude,
          ) +
          Geolocator.distanceBetween(
            path.last.latitude,
            path.last.longitude,
            to.latitude,
            to.longitude,
          );
      final reverseGap = Geolocator.distanceBetween(
            from.latitude,
            from.longitude,
            path.last.latitude,
            path.last.longitude,
          ) +
          Geolocator.distanceBetween(
            path.first.latitude,
            path.first.longitude,
            to.latitude,
            to.longitude,
          );
      return (
        path: forwardGap <= reverseGap ? path : path.reversed.toList(),
        gap: forwardGap <= reverseGap ? forwardGap : reverseGap,
      );
    }).toList()
      ..sort((first, second) => first.gap.compareTo(second.gap));

    final connectorRequests = connectors.take(3).map((connector) async {
      final sections = await Future.wait([
        _findTricycleRoadPath(from, connector.path.first),
        _findTricycleRoadPath(connector.path.last, to),
      ]);
      if (sections.any((path) => path.isEmpty)) return <LatLng>[];
      return _joinPaths([sections.first, connector.path, sections.last]);
    });
    final alternatives =
        await Future.wait([directRequest, ...connectorRequests]);
    final validPaths = alternatives.where((path) => path.length >= 2).toList()
      ..sort((first, second) =>
          _pathDistance(first).compareTo(_pathDistance(second)));
    // An absent road route is safer than drawing a false straight line through
    // buildings, parks, waterways, or pedestrian-only areas.
    return validPaths.isEmpty ? [] : validPaths.first;
  }

  Future<List<Map<String, dynamic>>> _findVerifiedTransportRoutes(
      Position position, LatLng destination) async {
    try {
      final uri =
          ApiService.uri('/transport/routes/match').replace(queryParameters: {
        'startLat': position.latitude.toString(),
        'startLng': position.longitude.toString(),
        'destinationLat': destination.latitude.toString(),
        'destinationLng': destination.longitude.toString(),
      });
      final response = await http.get(uri);
      if (response.statusCode != 200) return [];
      final matches = json.decode(response.body) as List<dynamic>;
      return matches
          .whereType<Map>()
          .map((match) => Map<String, dynamic>.from(match))
          .toList();
    } catch (error) {
      debugPrint('Verified transport lookup failed: $error');
      return [];
    }
  }

  double? _verifiedBaseFare(Map<String, dynamic>? route) {
    if (route == null) return null;
    final configuredFare = route['estimatedFare'] ?? route['baseFare'];
    if (configuredFare is num) return configuredFare.toDouble();
    return double.tryParse(configuredFare?.toString() ?? '');
  }

  int _journeyWalkingMeters(Map<String, dynamic> route) {
    int number(dynamic value) => value is num
        ? value.round()
        : (double.tryParse(value?.toString() ?? '') ?? 0).round();
    final transfers = route['transferPoints'] as List<dynamic>? ?? [];
    return number(route['distanceToBoardingMeters']) +
        number(route['distanceFromDropOffMeters']) +
        transfers.whereType<Map>().fold<int>(
              0,
              (total, transfer) => total + number(transfer['walkMeters']),
            );
  }

  Future<void> _selectTransportOption(int index) async {
    if (_isAiLoading ||
        index < 0 ||
        index >= _verifiedTransportOptions.length ||
        index == _selectedTransportOption) return;
    setState(() {
      _selectedTransportOption = index;
      _isAiLoading = true;
    });
    await _initializeMapAndAI(selectedRoute: _verifiedTransportOptions[index]);
  }

  String _formatFare(double fare) => '₱${fare.toStringAsFixed(2)}';

  LatLng? _pointFromJson(dynamic value) {
    if (value is! List || value.length < 2) return null;
    final latitude = value[0];
    final longitude = value[1];
    if (latitude is! num || longitude is! num) return null;
    return LatLng(latitude.toDouble(), longitude.toDouble());
  }

  List<Map<String, dynamic>> _verifiedLegs(Map<String, dynamic>? journey) {
    final values = journey?['legs'];
    if (values is! List) return [];
    return values
        .whereType<Map>()
        .map((value) => Map<String, dynamic>.from(value))
        .toList();
  }

  String _routeText(dynamic value, String fallback) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty || text.toLowerCase() == 'not verified'
        ? fallback
        : text;
  }

  String _vehicleName(dynamic value) {
    final mode = _routeText(value, 'public transport').toLowerCase();
    return mode
        .split(RegExp(r'[ _-]+'))
        .where((word) => word.isNotEmpty)
        .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }

  IconData _vehicleIcon(dynamic value) {
    final mode = value?.toString().trim().toLowerCase() ?? '';
    if (mode.contains('modern') && mode.contains('jeepney')) {
      return Icons.commute;
    }
    if (mode.contains('jeepney')) return Icons.airport_shuttle;
    if (mode.contains('multicab')) return Icons.local_shipping;
    if (mode.contains('tricycle')) return Icons.electric_rickshaw;
    if (mode.contains('uv') || mode.contains('express')) {
      return Icons.local_taxi;
    }
    if (mode.contains('bus')) return Icons.directions_bus_filled;
    return Icons.directions_bus_filled;
  }

  List<Map<String, dynamic>> _buildVerifiedCommuteSteps(
    String startAddress,
    String destinationName,
    Map<String, dynamic> journey,
  ) {
    final legs = _verifiedLegs(journey);
    if (legs.isEmpty) return [];
    final transfers = journey['transferPoints'] as List<dynamic>? ?? [];
    final steps = <Map<String, dynamic>>[
      {
        'instruction': 'Starting point: $startAddress',
        'type': 'walk',
        'phase': 'start',
        'landmark_query': 'none',
      },
    ];

    for (var index = 0; index < legs.length; index++) {
      final leg = legs[index];
      final boardingPlace = _routeText(
        leg['boardingRoadName'],
        _routeText(leg['boardingName'], 'the boarding point'),
      );
      final vehicle = _vehicleName(leg['mode']);
      final signboard = _routeText(leg['signboard'], 'the indicated route');
      final isOnDemandTricycle = leg['isOnDemand'] == true;
      final returnAvailabilityDependent =
          leg['returnAvailabilityDependent'] == true;
      steps.add({
        'instruction': isOnDemandTricycle
            ? returnAvailabilityDependent
                ? 'Look for an available tricycle going toward $signboard. Availability may vary.'
                : 'Walk to $signboard and ride a tricycle to the nearest accessible road for $destinationName'
            : index == 0
                ? 'Walk to $boardingPlace and ride a $vehicle with $signboard signboard'
                : 'Ride a $vehicle with $signboard signboard',
        'type': 'ride',
        'phase': 'board',
        'legIndex': index,
        'isOnDemand': isOnDemandTricycle,
        'signboard': signboard,
        'vehicle_mode': leg['mode'],
        'estimatedFare': leg['estimatedFare'] ?? leg['baseFare'],
        'landmark_query': boardingPlace,
      });

      final isFinalLeg = index == legs.length - 1;
      Map<String, dynamic>? transfer;
      if (!isFinalLeg && index < transfers.length && transfers[index] is Map) {
        transfer = Map<String, dynamic>.from(transfers[index] as Map);
      }
      final dropOffPlace = isFinalLeg
          ? _routeText(
              leg['dropOffRoadName'],
              _routeText(leg['dropOffName'], 'the destination stop'),
            )
          : _routeText(
              transfer?['roadName'],
              _routeText(
                transfer?['name'],
                _routeText(leg['dropOffName'], 'the transfer point'),
              ),
            );
      steps.add({
        'instruction': isFinalLeg && isOnDemandTricycle
            ? 'Get off at the nearest accessible road to $destinationName'
            : 'Get off at $dropOffPlace',
        'type': 'alight',
        'phase': 'alight',
        'legIndex': index,
        'landmark_query': dropOffPlace,
      });
    }

    steps.add({
      'instruction': 'Walk from the drop-off road to $destinationName',
      'type': 'walk',
      'phase': 'walk_to_destination',
      'legIndex': legs.length - 1,
      'landmark_query': destinationName,
    });
    steps.add({
      'instruction': 'Arrival at $destinationName',
      'type': 'arrival',
      'phase': 'arrival',
      'legIndex': legs.length - 1,
      'landmark_query': destinationName,
    });
    return steps;
  }

  Future<void> _initializeMapAndAI(
      {Map<String, dynamic>? selectedRoute}) async {
    final requestId = ++_routeRequestId;
    setState(() => _isAiLoading = true);
    final destinationName = widget.place['name'] ?? "Destination";

    Position? position = _currentPosition;
    if (position == null) {
      try {
        position = await Geolocator.getCurrentPosition();
        if (mounted) {
          setState(() => _currentPosition = position);
          _calculateDistanceOnly();
        }
      } catch (e) {
        setState(() {
          _commuteSteps = [
            {
              "instruction": "Location required for commute guide.",
              "type": "walk"
            }
          ];
          _isAiLoading = false;
        });
        return;
      }
    }

    final destCoords = _getPlaceCoords();
    if (selectedRoute == null) {
      _verifiedTransportOptions =
          await _findVerifiedTransportRoutes(position, destCoords);
      if (!mounted || requestId != _routeRequestId) return;
      _selectedTransportOption = 0;
      _verifiedTransportRoute = _verifiedTransportOptions.isEmpty
          ? null
          : _verifiedTransportOptions.first;
    } else {
      _verifiedTransportRoute = selectedRoute;
    }
    final matchedLegs = _verifiedLegs(_verifiedTransportRoute);
    if (_verifiedTransportRoute == null || matchedLegs.isEmpty) {
      if (!mounted) return;
      setState(() {
        _routePoints = [];
        _routeSegments = [];
        _onDemandRouteSegments = [];
        _transferWalkSegments = [];
        _aiStepMarkers = [];
        _estimatedFare = 'â‚±--';
        _commuteSteps = [
          {
            'instruction':
                'No verified public commute route is available for this trip yet.',
            'type': 'unavailable',
          }
        ];
        _isAiLoading = false;
      });
      return;
    }

    final initialFare = _verifiedBaseFare(_verifiedTransportRoute);
    setState(() {
      _estimatedFare = initialFare == null ? '₱--' : _formatFare(initialFare);
      _commuteSteps = _buildVerifiedCommuteSteps(
        _startAddress,
        destinationName,
        _verifiedTransportRoute!,
      );
      // Recommendations and instructions are useful immediately. Detailed
      // road geometry continues loading below without holding the sheet.
      _isAiLoading = false;
    });
    unawaited(_updateStartAddress(position));

    if (_verifiedTransportRoute != null) {
      final legs = _verifiedLegs(_verifiedTransportRoute);
      final onDemandSegments = <bool>[];
      final segments = <List<LatLng>>[];
      final segmentResults = await Future.wait(
        List.generate(legs.length, (legIndex) async {
          final leg = legs[legIndex];
          final geometry = leg['geometry'] as List<dynamic>? ?? [];
          var segment =
              geometry.map(_pointFromJson).whereType<LatLng>().toList();
          final isOnDemand = leg['isOnDemand'] == true;
          final usesAdminAccessPath = leg['usesAdminAccessPath'] == true;
          if (isOnDemand && !usesAdminAccessPath) {
            final boardingPoint = _pointFromJson(leg['boardingPoint']);
            final dropOffPoint = legIndex == legs.length - 1
                ? destCoords
                : _pointFromJson(leg['dropOffPoint']);
            if (boardingPoint != null && dropOffPoint != null) {
              final neighborhoodPath = await _findTricyclePath(
                boardingPoint,
                dropOffPoint,
                accessPaths: leg['accessPaths'],
              );
              segment = neighborhoodPath;
            }
          }
          return (segment: segment, isOnDemand: isOnDemand);
        }),
      );
      if (!mounted || requestId != _routeRequestId) return;
      for (final result in segmentResults) {
        if (result.segment.length < 2) continue;
        segments.add(result.segment);
        onDemandSegments.add(result.isOnDemand);
      }
      final transfers =
          _verifiedTransportRoute!['transferPoints'] as List<dynamic>? ?? [];
      final walkingRequests = <Future<List<LatLng>>>[];
      for (final value in transfers.whereType<Map>()) {
        final transfer = Map<String, dynamic>.from(value);
        final alightPoint = _pointFromJson(transfer['alightPoint']);
        final boardingPoint = _pointFromJson(transfer['boardingPoint']);
        if (alightPoint == null || boardingPoint == null) continue;
        walkingRequests.add(_findWalkingPath(alightPoint, boardingPoint));
      }
      if (legs.isNotEmpty) {
        final firstBoarding = _pointFromJson(legs.first['boardingPoint']);
        final finalDropOff = _pointFromJson(legs.last['dropOffPoint']);
        final userPoint = LatLng(position.latitude, position.longitude);
        if (firstBoarding != null &&
            Geolocator.distanceBetween(userPoint.latitude, userPoint.longitude,
                    firstBoarding.latitude, firstBoarding.longitude) >
                10) {
          walkingRequests.insert(0, _findWalkingPath(userPoint, firstBoarding));
        }
        final finalLegIsOnDemand = legs.last['isOnDemand'] == true;
        final routedFinalDropOff = finalLegIsOnDemand && segments.isNotEmpty
            ? segments.last.last
            : finalDropOff;
        if (routedFinalDropOff != null &&
            Geolocator.distanceBetween(
                    routedFinalDropOff.latitude,
                    routedFinalDropOff.longitude,
                    destCoords.latitude,
                    destCoords.longitude) >
                10) {
          walkingRequests.add(
            _findWalkingPath(routedFinalDropOff, destCoords),
          );
        }
      }
      final walkingConnections = (await Future.wait(walkingRequests))
          .where((path) => path.isNotEmpty)
          .toList();
      if (!mounted || requestId != _routeRequestId) return;
      final verifiedPoints = segments.expand((segment) => segment).toList();
      if (verifiedPoints.length >= 2 && mounted) {
        setState(() {
          _routePoints = verifiedPoints;
          _routeSegments = segments;
          _onDemandRouteSegments = onDemandSegments;
          _transferWalkSegments = walkingConnections;
        });
      }
    }

    if (!mounted || requestId != _routeRequestId) return;
    await _generateMarkersForSteps();
  }

  Future<void> _updateStartAddress(Position position) async {
    try {
      final geoUrl = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=${position.latitude}&lon=${position.longitude}');
      final geoRes = await http.get(geoUrl, headers: {
        'User-Agent': 'CaviteExplorerApp'
      }).timeout(const Duration(seconds: 5));
      if (geoRes.statusCode != 200) return;
      final geoData = json.decode(geoRes.body);
      final displayName = geoData['display_name']?.toString() ?? '';
      if (displayName.isEmpty || !mounted) return;
      final address = displayName.split(',').take(2).join(',');
      setState(() {
        _startAddress = address;
        if (_commuteSteps.isNotEmpty && _commuteSteps.first['type'] == 'walk') {
          _commuteSteps.first['instruction'] = 'Starting point: $address';
        }
      });
    } catch (error) {
      debugPrint('Reverse geocode failed: $error');
    }
  }

  Future<void> _askAIForguide(
      double userLat,
      double userLng,
      String destName,
      String startAddress,
      String osmRoadPath,
      Map<String, dynamic>? verifiedRoute) async {
    final destCoords = _getPlaceCoords();
    final verifiedFare = _verifiedBaseFare(verifiedRoute);
    final verifiedFareText =
        verifiedFare == null ? '₱--' : _formatFare(verifiedFare);
    final verifiedLegs = _verifiedLegs(verifiedRoute);
    if (verifiedRoute != null && verifiedLegs.isNotEmpty) {
      if (!mounted) return;
      setState(() {
        _estimatedFare = verifiedFareText;
        _commuteSteps = _buildVerifiedCommuteSteps(
          startAddress,
          destName,
          verifiedRoute,
        );
      });
      await _generateMarkersForSteps();
      return;
    }
    final legDetails = List.generate(verifiedLegs.length, (index) {
      final leg = verifiedLegs[index];
      final fare = leg['estimatedFare'] ?? leg['baseFare'];
      final fareText = fare is num ? _formatFare(fare.toDouble()) : '₱--';
      return '''Leg ${index + 1}:
- Route: ${leg['name']}
- Direction: ${leg['direction']}
- Vehicle: ${leg['mode']}
- Required signboard: ${leg['signboard']}
- Verified boarding point name: ${leg['boardingName'] ?? 'Not named'}
- Exact boarding road name: ${leg['boardingRoadName'] ?? 'Not verified'}
- Board at coordinates: ${leg['boardingPoint']}
- Verified drop-off point name: ${leg['dropOffName'] ?? 'Not named'}
- Exact drop-off road name: ${leg['dropOffRoadName'] ?? 'Not verified'}
- Get off at coordinates: ${leg['dropOffPoint']}
- Travel distance: ${leg['distanceKm']} km
- Fare rule: ₱${leg['baseFare']} for the first ${leg['baseDistanceKm']} km, then ₱${leg['additionalFarePerKm']} for each started additional kilometer
- Estimated fare for this leg: $fareText''';
    }).join('\n');
    final transferDetails =
        (verifiedRoute?['transferPoints'] as List<dynamic>? ?? [])
            .whereType<Map>()
            .map((value) {
      final transfer = Map<String, dynamic>.from(value);
      return 'Transfer at ${transfer['name'] ?? 'the verified crossing'} on ${transfer['roadName'] ?? 'the verified route'}, walking approximately ${transfer['walkMeters']} meters from ${transfer['alightPoint']} to ${transfer['boardingPoint']}.';
    }).join('\n');
    final verifiedContext = verifiedRoute == null
        ? 'No administrator-verified public transport route matched this journey. Do not name a specific vehicle route or signboard.'
        : '''ADMINISTRATOR-VERIFIED TRANSPORT JOURNEY (use every leg in this exact order):
$legDetails
$transferDetails
Verified total fare: $verifiedFareText
Fare notes: ${verifiedRoute['fareNotes'] ?? 'Actual fare may vary by distance and current operator rates.'}
Route notes: ${verifiedRoute['notes'] ?? 'None'}
Every fare above comes from the database. Use the verified fares exactly; never calculate or substitute a different fare.
Create exactly one ride step for every verified leg and place a transfer step between consecutive legs. Never skip, reorder, or replace a verified leg.''';

    final prompt = """
      You are a local Cavite, Philippines commute expert. 
      The user is starting at: $startAddress (Latitude: $userLat, Longitude: $userLng).
      The destination is: $destName (Latitude: ${destCoords.latitude}, Longitude: ${destCoords.longitude}).
      
      CRITICAL - MAP SYNC: The physical map has drawn a visual route passing through these specific roads: 
      [$osmRoadPath]

      $verifiedContext
      
      Base the guide only on these road names and administrator-verified transport facts. At boarding, transfer, and drop-off, always use the exact verified point and road names when provided. Never replace them with another road from the general route list. When a verified route is present, explicitly tell the passenger its vehicle type and signboard, and return its exact verified fare. When no verified route is present, do not invent a jeepney, bus, tricycle route, signboard, schedule, road name, or fare; return "₱--" for fare.
      
      CRITICAL FORMAT: Return 3 to 8 short steps. The first step in your JSON 'steps' list MUST be: 
      {"instruction": "Starting point: $startAddress", "type": "walk", "landmark_query": "none"}
      
      Allowed type values are ONLY "walk", "ride", "transfer", and "arrival". Every landmark_query must be "none" or a real road/landmark name from the route context. Return ONLY this JSON object:
      {
        "fare": "₱XX.XX",
        "steps": [
          {"instruction": "Starting point: $startAddress", "type": "walk", "landmark_query": "none"},
          {"instruction": "Ride Jeep passing through Aguinaldo Hwy...", "type": "ride", "landmark_query": "Some Landmark, Cavite"}
        ]
      }
    """;

    try {
      final token = (await AuthService.getUser())?['token'];
      if (token == null || token.isEmpty)
        throw Exception('Sign in to use AI guidance');
      final response = await http.post(
        ApiService.uri('/assistant/generate'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token'
        },
        body: json.encode({'prompt': prompt}),
      );

      if (response.statusCode == 200) {
        final aiResult = json.decode(response.body);

        setState(() {
          _estimatedFare = verifiedFare == null
              ? (aiResult['fare'] ?? "₱--")
              : verifiedFareText;
          _commuteSteps = aiResult['steps'] ?? [];
        });
        await _generateMarkersForSteps();
      } else {
        debugPrint(
            'AI commute request failed (${response.statusCode}): ${response.body}');
        setState(() {
          _commuteSteps = [
            {"instruction": "AI could not generate route.", "type": "walk"}
          ];
          _isAiLoading = false;
        });
      }
    } catch (e) {
      debugPrint("❌ AI Error: $e");
      setState(() => _isAiLoading = false);
    }
  }

  Future<LatLng?> _geocodeLandmark(String query) async {
    if (query.isEmpty || query.toLowerCase() == "none") return null;
    final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=1');
    try {
      final response =
          await http.get(url, headers: {'User-Agent': 'CaviteExplorerApp'});
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data.isNotEmpty) {
          return LatLng(
              double.parse(data[0]['lat']), double.parse(data[0]['lon']));
        }
      }
    } catch (e) {}
    return null;
  }

  Marker _buildJourneyMarker({
    required LatLng point,
    required String title,
    required String detail,
    required IconData icon,
    required Color color,
    required String placement,
  }) {
    final card = Container(
      constraints: const BoxConstraints(maxWidth: 128),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1.6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.16),
            blurRadius: 7,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 27,
            height: 27,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 15),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 9,
                    height: 1.1,
                    letterSpacing: .35,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF202124),
                    fontSize: 10,
                    height: 1.1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final pointer = Icon(
      placement == 'below' ? Icons.arrow_drop_up : Icons.arrow_drop_down,
      color: color,
      size: 18,
    );

    late final Widget markerChild;
    late final Alignment alignment;
    late final double width;
    late final double height;
    if (placement == 'right') {
      alignment = Alignment.centerLeft;
      width = 143;
      height = 52;
      markerChild = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          RotatedBox(quarterTurns: 1, child: pointer),
          Expanded(child: card),
        ],
      );
    } else if (placement == 'below') {
      alignment = Alignment.topCenter;
      width = 128;
      height = 64;
      markerChild = Column(
        mainAxisSize: MainAxisSize.min,
        children: [pointer, Expanded(child: card)],
      );
    } else {
      alignment = Alignment.bottomCenter;
      width = 128;
      height = 64;
      markerChild = Column(
        mainAxisSize: MainAxisSize.min,
        children: [Expanded(child: card), pointer],
      );
    }

    return Marker(
      point: point,
      width: width,
      height: height,
      alignment: alignment,
      child: Tooltip(message: '$title: $detail', child: markerChild),
    );
  }

  Future<void> _generateMarkersForSteps() async {
    final newMarkers = <Marker>[];
    final destinationCoords = _getPlaceCoords();
    final verifiedLegs = _verifiedLegs(_verifiedTransportRoute);
    final verifiedTransfers =
        _verifiedTransportRoute?['transferPoints'] as List<dynamic>? ?? [];

    // A verified journey is the source of truth for map signs. Groq writes the
    // guide, but it must not decide whether a physical point is a boarding,
    // transfer, or drop-off location.
    if (verifiedLegs.isNotEmpty) {
      const boardColor = Color(0xFF246BFD);
      const transferColor = Color(0xFFF26432);
      const getOffColor = Color(0xFFEF5350);

      final firstBoarding = _pointFromJson(verifiedLegs.first['boardingPoint']);
      if (firstBoarding != null) {
        newMarkers.add(_buildJourneyMarker(
          point: firstBoarding,
          title: 'BOARD',
          detail: verifiedLegs.first['signboard']?.toString() ?? 'Ride here',
          icon: _vehicleIcon(verifiedLegs.first['mode']),
          color: boardColor,
          placement: 'above',
        ));
      }

      for (var index = 0; index < verifiedLegs.length - 1; index++) {
        Map<String, dynamic>? transfer;
        if (index < verifiedTransfers.length &&
            verifiedTransfers[index] is Map) {
          transfer = Map<String, dynamic>.from(
            verifiedTransfers[index] as Map,
          );
        }
        final nextLeg = verifiedLegs[index + 1];
        final transferPoint = _pointFromJson(transfer?['boardingPoint']) ??
            _pointFromJson(nextLeg['boardingPoint']);
        if (transferPoint == null) continue;
        final nextSignboard = nextLeg['signboard']?.toString().trim();
        newMarkers.add(_buildJourneyMarker(
          point: transferPoint,
          title: 'TRANSFER',
          detail: nextSignboard == null || nextSignboard.isEmpty
              ? 'Board the next ride'
              : 'Next: $nextSignboard',
          icon: _vehicleIcon(nextLeg['mode']),
          color: transferColor,
          placement: 'right',
        ));
      }

      final finalLeg = verifiedLegs.last;
      final finalLegIsOnDemand = finalLeg['isOnDemand'] == true;
      // Tricycle routing stops on the nearest motor-scooter-accessible road.
      // Any remaining off-road distance is shown separately as walking.
      final routedArrival = finalLegIsOnDemand && _routeSegments.isNotEmpty
          ? _routeSegments.last.last
          : null;
      final finalDropOff =
          routedArrival ?? _pointFromJson(finalLeg['dropOffPoint']);
      if (finalDropOff != null) {
        final dropOffLabel = finalLeg['dropOffName']?.toString().trim();
        final dropOffRoad = finalLeg['dropOffRoadName']?.toString().trim();
        newMarkers.add(_buildJourneyMarker(
          point: finalDropOff,
          title: 'GET OFF',
          detail: finalLegIsOnDemand
              ? widget.place['name']?.toString() ?? 'Nearest destination road'
              : dropOffLabel != null && dropOffLabel.isNotEmpty
                  ? dropOffLabel
                  : dropOffRoad != null && dropOffRoad.isNotEmpty
                      ? dropOffRoad
                      : 'Walk to destination',
          icon: finalLegIsOnDemand ? Icons.electric_rickshaw : Icons.flag,
          color: getOffColor,
          placement: 'below',
        ));
      }

      // Preserve guide-step tapping without using those steps to create signs.
      var rideIndex = 0;
      var transferIndex = 0;
      var alightIndex = 0;
      for (final step in _commuteSteps) {
        final type = step['type']?.toString();
        if (type == 'ride' && rideIndex < verifiedLegs.length) {
          step['coords'] =
              _pointFromJson(verifiedLegs[rideIndex++]['boardingPoint']);
        } else if (type == 'alight' && alightIndex < verifiedLegs.length) {
          final legIndex = alightIndex++;
          final leg = verifiedLegs[legIndex];
          step['coords'] =
              legIndex == verifiedLegs.length - 1 && leg['isOnDemand'] == true
                  ? finalDropOff
                  : _pointFromJson(leg['dropOffPoint']);
        } else if (type == 'transfer' &&
            transferIndex < verifiedTransfers.length &&
            verifiedTransfers[transferIndex] is Map) {
          final transfer = Map<String, dynamic>.from(
            verifiedTransfers[transferIndex++] as Map,
          );
          step['coords'] = _pointFromJson(transfer['boardingPoint']);
        } else if (type == 'walk' &&
            step['phase']?.toString() == 'walk_to_destination') {
          step['coords'] = destinationCoords;
        } else if (type == 'arrival') {
          step['coords'] = destinationCoords;
        }
      }

      if (!mounted) return;
      setState(() {
        _aiStepMarkers = newMarkers;
        _isAiLoading = false;
      });
      return;
    }

    int rideLegIndex = 0;
    int transferIndex = 0;
    for (int i = 0; i < _commuteSteps.length; i++) {
      var step = _commuteSteps[i];
      final type = step['type']?.toString() ?? 'walk';

      // Ride and transfer signs belong on the route line itself. This keeps the
      // boarding point visible even when a landmark name cannot be geocoded.
      if (type == 'ride' || type == 'transfer' || type == 'arrival') {
        LatLng? coords;
        Map<String, dynamic>? markerLeg;
        Map<String, dynamic>? markerTransfer;
        if (type == 'ride' && rideLegIndex < verifiedLegs.length) {
          markerLeg = verifiedLegs[rideLegIndex++];
          coords = _pointFromJson(markerLeg['boardingPoint']);
        } else if (type == 'transfer' &&
            transferIndex < verifiedTransfers.length &&
            verifiedTransfers[transferIndex] is Map) {
          markerTransfer = Map<String, dynamic>.from(
              verifiedTransfers[transferIndex++] as Map);
          coords = _pointFromJson(markerTransfer['boardingPoint']);
        } else if (type == 'arrival' && verifiedLegs.isNotEmpty) {
          markerLeg = verifiedLegs.last;
          coords = _pointFromJson(markerLeg['dropOffPoint']);
        } else if (step['landmark_query'] != null &&
            step['landmark_query'] != "none") {
          final landmark = await _geocodeLandmark(step['landmark_query']);
          if (landmark != null) {
            coords = _routePoints.isNotEmpty
                ? _nearestRoutePoint(landmark)
                : landmark;
          }
        }
        coords ??= _routePointForStep(i, _commuteSteps.length);
        if (coords != null) {
          setState(() {
            _commuteSteps[i]['coords'] = coords;
          });
          final icon = switch (type) {
            'ride' => Icons.directions_bus_filled,
            'transfer' => Icons.sync_alt,
            'arrival' => Icons.flag,
            _ => Icons.directions_walk,
          };
          final color = switch (type) {
            'ride' => Colors.blueAccent,
            'transfer' => Colors.deepOrange,
            'arrival' => Colors.redAccent,
            _ => Colors.teal,
          };
          final markerTitle = switch (type) {
            'transfer' => 'TRANSFER HERE',
            'arrival' => 'GET OFF HERE',
            _ => 'BOARD HERE',
          };
          final markerDetail = type == 'ride'
              ? (markerLeg?['signboard']?.toString() ?? 'Ride vehicle')
              : type == 'transfer'
                  ? 'Walk ${markerTransfer?['walkMeters'] ?? 0} m'
                  : 'Walk to destination';
          newMarkers.add(Marker(
            point: coords,
            width: 150,
            height: 78,
            alignment: Alignment.bottomCenter,
            child: Tooltip(
              message: 'Step ${i + 1}: ${step['instruction']}',
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: color, width: 2),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 3))
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                                color: color, shape: BoxShape.circle),
                            child: Icon(icon, color: Colors.white, size: 18)),
                        const SizedBox(width: 8),
                        Flexible(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                              Text(markerTitle,
                                  maxLines: 1,
                                  style: TextStyle(
                                      color: color,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 10,
                                      letterSpacing: .4)),
                              Text(markerDetail,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: Color(0xFF202124),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11)),
                            ])),
                        const SizedBox(width: 5),
                        Container(
                            width: 20,
                            height: 20,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                                color: color.withOpacity(.12),
                                shape: BoxShape.circle),
                            child: Text('${i + 1}',
                                style: TextStyle(
                                    color: color,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10))),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_drop_down, color: color, size: 24),
                ],
              ),
            ),
          ));
        }
      }
    }
    setState(() {
      _aiStepMarkers = newMarkers;
      _isAiLoading = false;
    });
  }

  LatLng? _routePointForStep(int stepIndex, int totalSteps) {
    if (_routePoints.isEmpty) return null;
    if (_routePoints.length == 1 || totalSteps <= 1) return _routePoints.first;
    final progress = stepIndex / (totalSteps - 1);
    final pointIndex = (progress * (_routePoints.length - 1)).round();
    return _routePoints[pointIndex.clamp(0, _routePoints.length - 1).toInt()];
  }

  LatLng _nearestRoutePoint(LatLng target) {
    return _routePoints.reduce((closest, candidate) {
      final closestDistance = Geolocator.distanceBetween(
        target.latitude,
        target.longitude,
        closest.latitude,
        closest.longitude,
      );
      final candidateDistance = Geolocator.distanceBetween(
        target.latitude,
        target.longitude,
        candidate.latitude,
        candidate.longitude,
      );
      return candidateDistance < closestDistance ? candidate : closest;
    });
  }

  Future<void> _openDrivingDirections() async {
    final coords = _getPlaceCoords();
    final destination = '${coords.latitude},${coords.longitude}';
    final origin = _currentPosition == null
        ? null
        : '${_currentPosition!.latitude},${_currentPosition!.longitude}';
    final Uri androidUri = Uri.parse('google.navigation:q=$destination&mode=d');
    final Uri webUri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': destination,
      'travelmode': 'driving',
      if (origin != null) 'origin': origin,
    });

    try {
      if (await canLaunchUrl(androidUri))
        await launchUrl(androidUri);
      else
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Could not open driving directions.")));
    }
  }

  Future<void> _searchNearby(String category) async {
    final coords = _getPlaceCoords();
    final Uri androidUri = Uri.parse(
        'geo:${coords.latitude},${coords.longitude}?q=${Uri.encodeComponent(category)}');
    final Uri webUri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent('$category near ${coords.latitude},${coords.longitude}')}');

    try {
      if (await canLaunchUrl(androidUri))
        await launchUrl(androidUri);
      else
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Could not search for $category.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final String name = widget.place['name'] ?? "Unknown Place";
    final String locationParts = [
      widget.place['barangay'],
      widget.place['municipality']
    ]
        .where((part) => part != null && part.toString().trim().isNotEmpty)
        .join(', ');
    final String location = locationParts.isEmpty ? "Cavite" : locationParts;
    final LatLng destCoords = _getPlaceCoords();

    LatLng mapCenter = destCoords;
    double mapZoom = 15.0;
    if (_currentPosition != null) {
      mapCenter = LatLng((_currentPosition!.latitude + destCoords.latitude) / 2,
          (_currentPosition!.longitude + destCoords.longitude) / 2);
      mapZoom = 12.0;
    }

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options:
                  MapOptions(initialCenter: mapCenter, initialZoom: mapZoom),
              children: [
                TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.cavite_explorer_mobile'),
                if (_routeSegments.isNotEmpty)
                  PolylineLayer(polylines: [
                    for (int index = 0;
                        index < _routeSegments.length;
                        index++) ...[
                      Polyline(
                          points: _routeSegments[index],
                          strokeWidth: 8,
                          color: Colors.white.withOpacity(.9),
                          pattern: index < _onDemandRouteSegments.length &&
                                  _onDemandRouteSegments[index]
                              ? StrokePattern.dashed(segments: const [10, 6])
                              : const StrokePattern.solid()),
                      Polyline(
                          points: _routeSegments[index],
                          strokeWidth: 5,
                          color: index.isEven
                              ? const Color(0xFF246BFD)
                              : const Color(0xFFF47A32),
                          pattern: index < _onDemandRouteSegments.length &&
                                  _onDemandRouteSegments[index]
                              ? StrokePattern.dashed(segments: const [10, 6])
                              : const StrokePattern.solid()),
                    ],
                    for (final transferWalk in _transferWalkSegments)
                      Polyline(
                          points: transferWalk,
                          strokeWidth: 4,
                          color: const Color(0xFF4B5563),
                          pattern: const StrokePattern.dotted()),
                  ]),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: destCoords,
                      width: 64,
                      height: 64,
                      child: const Tooltip(
                        message: 'Destination',
                        child: Icon(Icons.location_on,
                            color: Colors.redAccent,
                            size: 52,
                            shadows: [
                              Shadow(color: Colors.white, blurRadius: 5)
                            ]),
                      ),
                    ),
                    if (_currentPosition != null)
                      Marker(
                        point: LatLng(_currentPosition!.latitude,
                            _currentPosition!.longitude),
                        width: 46,
                        height: 46,
                        child: const Tooltip(
                          message: 'Your location',
                          child: Icon(Icons.my_location,
                              color: Colors.green,
                              size: 34,
                              shadows: [
                                Shadow(color: Colors.white, blurRadius: 5)
                              ]),
                        ),
                      ),
                    ..._aiStepMarkers,
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 20,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2))
                    ]),
                child: const Icon(Icons.arrow_back,
                    color: Colors.black87, size: 20),
              ),
            ),
          ),
          DraggableScrollableSheet(
            initialChildSize: 0.42,
            minChildSize: 0.25,
            maxChildSize: 0.70,
            snap: true,
            snapSizes: const [0.42, 0.70],
            builder: (BuildContext context, ScrollController scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFFAF8F5),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black26,
                        blurRadius: 20,
                        offset: Offset(0, -5))
                  ],
                ),
                child: SingleChildScrollView(
                  controller: scrollController,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(
                      top: 12, left: 20, right: 20, bottom: 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                          child: Container(
                              width: 50,
                              height: 5,
                              decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  borderRadius: BorderRadius.circular(10)))),
                      const SizedBox(height: 20),
                      Text(name,
                          style: GoogleFonts.poppins(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1A1A1A),
                              height: 1.1)),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                            color: const Color(0xFFF1F3F1),
                            borderRadius: BorderRadius.circular(12)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.location_on_outlined,
                              color: Color(0xFF33413A), size: 17),
                          const SizedBox(width: 6),
                          Text(location,
                              style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: const Color(0xFF33413A),
                                  fontWeight: FontWeight.w600)),
                        ]),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 15),
                        decoration: BoxDecoration(
                            color: const Color(0xFFEAF1FF),
                            borderRadius: BorderRadius.circular(18)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Expanded(
                                child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  const Icon(Icons.near_me_outlined,
                                      size: 14, color: Color(0xFF5D6E8B)),
                                  const SizedBox(width: 5),
                                  Text("Distance",
                                      style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          color: const Color(0xFF5D6E8B)))
                                ]),
                                const SizedBox(height: 3),
                                Text(_distanceText,
                                    style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF246BFD))),
                              ],
                            )),
                            const SizedBox(width: 16),
                            Container(
                                width: 1,
                                height: 35,
                                color: Colors.blueAccent.withOpacity(0.2)),
                            const SizedBox(width: 16),
                            Expanded(
                                child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  const Icon(Icons.verified_outlined,
                                      size: 14, color: Color(0xFF5D6E8B)),
                                  const SizedBox(width: 5),
                                  Text(
                                      _verifiedTransportRoute != null
                                          ? (_verifiedLegs(
                                                          _verifiedTransportRoute)
                                                      .length >
                                                  1
                                              ? "Verified total fare"
                                              : "Verified base fare")
                                          : "Estimated fare",
                                      style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          color: const Color(0xFF5D6E8B)))
                                ]),
                                const SizedBox(height: 3),
                                _isAiLoading
                                    ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.green))
                                    : Text(_estimatedFare,
                                        style: GoogleFonts.poppins(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF2FA54A))),
                              ],
                            )),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (_verifiedTransportOptions.length > 1) ...[
                        Builder(builder: (context) {
                          final walkingValues = _verifiedTransportOptions
                              .map(_journeyWalkingMeters)
                              .toList();
                          final fareValues = _verifiedTransportOptions
                              .map(_verifiedBaseFare)
                              .whereType<double>()
                              .toList();
                          final leastWalking = walkingValues.reduce(
                              (first, second) =>
                                  first < second ? first : second);
                          final lowestFare = fareValues.isEmpty
                              ? null
                              : fareValues.reduce((first, second) =>
                                  first < second ? first : second);
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Choose your commute',
                                  style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF1A1A1A))),
                              const SizedBox(height: 4),
                              Text('Compare walking distance, rides, and fare.',
                                  style: GoogleFonts.poppins(
                                      fontSize: 11, color: Colors.grey[600])),
                              const SizedBox(height: 10),
                              SizedBox(
                                height: 128,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _verifiedTransportOptions.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(width: 10),
                                  itemBuilder: (context, index) {
                                    final option =
                                        _verifiedTransportOptions[index];
                                    final selected =
                                        index == _selectedTransportOption;
                                    final walking = walkingValues[index];
                                    final fare = _verifiedBaseFare(option);
                                    final rides = _verifiedLegs(option).length;
                                    final profileValues =
                                        option['recommendationProfiles'] is List
                                            ? option['recommendationProfiles']
                                                as List<dynamic>
                                            : <dynamic>[
                                                option['recommendationProfile']
                                              ];
                                    final labels = profileValues
                                        .map((profile) =>
                                            switch (profile?.toString()) {
                                              'balanced' => 'Best value',
                                              'budget' => 'Lowest fare',
                                              'convenient' => 'Most convenient',
                                              'alternative' => 'Alternative',
                                              _ => null,
                                            })
                                        .whereType<String>()
                                        .toList();
                                    if (labels.isEmpty) {
                                      if (walking == leastWalking) {
                                        labels.add('Shortest walk');
                                      }
                                      if (fare != null && fare == lowestFare) {
                                        labels.add('Lowest fare');
                                      }
                                    }
                                    final walkingText = walking < 1000
                                        ? '$walking m walk'
                                        : '${(walking / 1000).toStringAsFixed(1)} km walk';
                                    return GestureDetector(
                                      onTap: () =>
                                          _selectTransportOption(index),
                                      child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 180),
                                        width: 205,
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: selected
                                              ? const Color(0xFFEAF2FF)
                                              : Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          border: Border.all(
                                            color: selected
                                                ? const Color(0xFF246BFD)
                                                : const Color(0xFFDDE3EA),
                                            width: selected ? 2 : 1,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              labels.isEmpty
                                                  ? 'Route ${index + 1}'
                                                  : labels.join(' · '),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.poppins(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: selected
                                                    ? const Color(0xFF246BFD)
                                                    : const Color(0xFF15704F),
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              option['name']?.toString() ??
                                                  'Verified route',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.poppins(
                                                fontSize: 10,
                                                color: Colors.grey[700],
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              '$rides ${rides == 1 ? 'ride' : 'rides'} · $walkingText',
                                              style: GoogleFonts.poppins(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600),
                                            ),
                                            const Spacer(),
                                            Text(
                                              fare == null
                                                  ? 'Fare unavailable'
                                                  : _formatFare(fare),
                                              style: GoogleFonts.poppins(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w800,
                                                color: Colors.green[700],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          );
                        }),
                        const SizedBox(height: 16),
                      ],
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: Colors.orangeAccent.withOpacity(0.3)),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.02),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2))
                            ]),
                        child: ExpansionTile(
                          initiallyExpanded: true,
                          tilePadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          shape: const Border(),
                          title: Row(
                            children: [
                              const Icon(Icons.bolt,
                                  size: 22, color: Colors.orange),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    Text("Public Commute Guide",
                                        style: GoogleFonts.poppins(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFFB85B09))),
                                    Text("Verified local transport details",
                                        style: GoogleFonts.poppins(
                                            fontSize: 10,
                                            color: const Color(0xFF8B7866))),
                                  ])),
                            ],
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(
                                  left: 16, right: 16, bottom: 14),
                              child: _isAiLoading
                                  ? const Center(
                                      child: Padding(
                                          padding: EdgeInsets.all(12.0),
                                          child: CircularProgressIndicator(
                                              color: Colors.orange,
                                              strokeWidth: 2)))
                                  : _commuteSteps.isEmpty
                                      ? Text(
                                          "No route found. Ensure location is enabled.",
                                          style: GoogleFonts.poppins(
                                              fontSize: 13, color: Colors.grey))
                                      : Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: _commuteSteps.map((step) {
                                            IconData stepIcon =
                                                Icons.directions_walk;
                                            Color iconColor = Colors.grey[600]!;
                                            Color bgColor = Colors.grey[100]!;

                                            if (step['type'] == 'ride') {
                                              stepIcon = _vehicleIcon(
                                                  step['vehicle_mode'] ??
                                                      step['instruction']);
                                              iconColor = Colors.blueAccent;
                                              bgColor = Colors.blueAccent
                                                  .withOpacity(0.1);
                                            }
                                            if (step['type'] == 'transfer' ||
                                                step['type'] == 'alight') {
                                              stepIcon = Icons.sync_alt;
                                              iconColor = Colors.orange;
                                              bgColor = Colors.orange
                                                  .withOpacity(0.1);
                                            }
                                            if (step['type'] == 'arrival') {
                                              stepIcon = Icons.location_on;
                                              iconColor = Colors.redAccent;
                                              bgColor = Colors.redAccent
                                                  .withOpacity(0.1);
                                            }
                                            if (step['type'] == 'unavailable') {
                                              stepIcon = Icons.alt_route;
                                              iconColor = Colors.orange;
                                              bgColor = Colors.orange
                                                  .withOpacity(0.1);
                                            }

                                            return InkWell(
                                              onTap: () {
                                                if (step['coords'] != null)
                                                  _mapController.move(
                                                      step['coords'] as LatLng,
                                                      17.0);
                                              },
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: Padding(
                                                padding: const EdgeInsets.only(
                                                    bottom: 12.0),
                                                child: Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .all(8),
                                                        decoration:
                                                            BoxDecoration(
                                                                color: bgColor,
                                                                shape: BoxShape
                                                                    .circle),
                                                        child: Icon(stepIcon,
                                                            size: 16,
                                                            color: iconColor)),
                                                    const SizedBox(width: 13),
                                                    Expanded(
                                                        child: Padding(
                                                            padding:
                                                                const EdgeInsets
                                                                    .only(
                                                                    top: 6.0),
                                                            child: Text(
                                                                step[
                                                                    'instruction'],
                                                                style: GoogleFonts
                                                                    .poppins(
                                                                        fontSize:
                                                                            13,
                                                                        color: Colors
                                                                            .black87,
                                                                        height:
                                                                            1.4)))),
                                                  ],
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                            ),
                          ],
                        ),
                      ),
                      // Keep the driving and trip actions visually separate
                      // from the commute instructions above.
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Tooltip(
                                message:
                                    'Private car, motorcycle, or taxi directions',
                                child: OutlinedButton(
                                  onPressed: _openDrivingDirections,
                                  style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 16),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(16)),
                                      side: const BorderSide(
                                          color: Colors.blueAccent, width: 2)),
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                            Icons
                                                .directions_car_filled_outlined,
                                            color: Colors.blueAccent,
                                            size: 18),
                                        const SizedBox(width: 7),
                                        Text('Drive',
                                            style: GoogleFonts.poppins(
                                                color: Colors.blueAccent,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700))
                                      ],
                                    ),
                                  ),
                                )),
                          ),
                          const SizedBox(width: 16),

                          // Start the selected verified route immediately.
                          Expanded(
                            flex: 3,
                            child: ElevatedButton.icon(
                              onPressed:
                                  _isStartingCommute ? null : _startLiveCommute,
                              icon: _isStartingCommute
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.navigation_rounded,
                                      color: Colors.white, size: 18),
                              label: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                    _isStartingCommute
                                        ? "Starting..."
                                        : "Commute",
                                    style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white)),
                              ),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blueAccent,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16)),
                                  elevation: 0),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
