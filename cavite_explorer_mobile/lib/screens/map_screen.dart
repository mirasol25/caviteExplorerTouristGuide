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
import '../services/background_tracking_service.dart';
import '../services/location_service.dart';
import 'map_preview_screen.dart';
import 'place_details_screen.dart';

enum _MapFilter { all, unclaimed, inProgress, claimed, popular, topRated }

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  List<dynamic> _allLandmarks = [];
  Position? _currentPosition;
  Map<String, dynamic>? _selectedPlace;
  bool _isLoading = true;
  String? _error;
  double _zoom = 12.5;
  _MapFilter _filter = _MapFilter.all;
  Set<String> _claimedLandmarkIds = <String>{};
  Set<String> _progressLandmarkIds = <String>{};

  @override
  void initState() {
    super.initState();
    VisitTrackingController.instance.unlockedBadge.addListener(_badgeUnlocked);
    VisitTrackingController.instance.visits.addListener(_visitsChanged);
    _visitsChanged();
    _initializeMapData();
  }

  @override
  void dispose() {
    VisitTrackingController.instance.unlockedBadge
        .removeListener(_badgeUnlocked);
    VisitTrackingController.instance.visits.removeListener(_visitsChanged);
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _badgeUnlocked() {
    final id = VisitTrackingController
        .instance.unlockedBadge.value?['landmarkId']
        ?.toString();
    if (id != null && id.isNotEmpty && mounted) {
      setState(() => _claimedLandmarkIds.add(id));
    }
  }

  void _visitsChanged() {
    final next = VisitTrackingController.instance.visits.value
        .map((visit) => visit['landmarkId']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
    final changed = next.length != _progressLandmarkIds.length ||
        next.any((id) => !_progressLandmarkIds.contains(id));
    if (!changed) return;
    _progressLandmarkIds = next;
    if (mounted) setState(() {});
  }

  Future<Set<String>> _loadClaimedLandmarks() async {
    final token = (await AuthService.getUser())?['token']?.toString();
    if (token == null || token.isEmpty) return <String>{};
    try {
      final response = await http.get(ApiService.uri('/badges/me'),
          headers: {'Authorization': 'Bearer $token'});
      if (response.statusCode != 200) return <String>{};
      final body = json.decode(response.body) as Map<String, dynamic>;
      return ((body['earned'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => item['landmarkId']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();
    } catch (_) {
      return <String>{};
    }
  }

  Future<void> _initializeMapData() async {
    try {
      // Landmarks are enough to render the map. Location and badge status can
      // finish afterward without keeping the whole screen behind a spinner.
      final locationFuture = LocationService.promptLocationOnce();
      final badgesFuture = _loadClaimedLandmarks();
      final landmarks = await ApiService.getLandmarks();
      if (!mounted) return;
      setState(() {
        _allLandmarks = landmarks;
        _zoom = 10.5;
        _isLoading = false;
        _error = null;
      });
      final results = await Future.wait([locationFuture, badgesFuture]);
      if (!mounted) return;
      final position = results[0] as Position?;
      setState(() {
        _currentPosition = position;
        _claimedLandmarkIds = results[1] as Set<String>;
      });
      if (position != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _mapController.move(
              LatLng(position.latitude, position.longitude), 12.8);
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'The landmark map could not be loaded.';
      });
    }
  }

  double? _number(dynamic value) => value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '');

  LatLng? _point(dynamic place) {
    final latitude = _number(place['latitude']);
    final longitude = _number(place['longitude']);
    if (latitude == null ||
        longitude == null ||
        latitude.abs() > 90 ||
        longitude.abs() > 180) {
      return null;
    }
    return LatLng(latitude, longitude);
  }

  double _ratingScore(dynamic place) {
    final rating = _number(place['averageRating']) ?? 0;
    final reviews = _number(place['reviewCount']) ?? 0;
    return (reviews / (reviews + 5)) * rating + (5 / (reviews + 5)) * 3.5;
  }

  List<dynamic> get _visibleLandmarks {
    final query = _searchController.text.trim().toLowerCase();
    var places = _allLandmarks.where((place) {
      if (_point(place) == null) return false;
      final searchable = [
        place['name'],
        place['municipality'],
        place['barangay'],
        place['category']
      ].whereType<Object>().join(' ').toLowerCase();
      if (query.isNotEmpty && !searchable.contains(query)) return false;
      final id = place['id']?.toString() ?? '';
      switch (_filter) {
        case _MapFilter.unclaimed:
          return !_claimedLandmarkIds.contains(id);
        case _MapFilter.inProgress:
          return _progressLandmarkIds.contains(id) &&
              !_claimedLandmarkIds.contains(id);
        case _MapFilter.claimed:
          return _claimedLandmarkIds.contains(id);
        default:
          return true;
      }
    }).toList();
    if (_filter == _MapFilter.popular) {
      places.sort((a, b) => (_number(b['badgeClaimCount']) ?? 0)
          .compareTo(_number(a['badgeClaimCount']) ?? 0));
      places = places.take(10).toList();
    } else if (_filter == _MapFilter.topRated) {
      places.removeWhere((place) => (_number(place['reviewCount']) ?? 0) <= 0);
      places.sort((a, b) => _ratingScore(b).compareTo(_ratingScore(a)));
      places = places.take(10).toList();
    }
    return places;
  }

  String get _filterLabel => _labelFor(_filter);
  IconData get _filterIcon => _iconFor(_filter);

  int _displayLevel(double zoom) {
    if (zoom < 11) return 0;
    if (zoom < 12.5) return 1;
    if (zoom < 13.4) return 2;
    if (zoom < 14) return 3;
    if (zoom < 15.7) return 4;
    return 5;
  }

  List<_LandmarkCluster> _clusters(List<dynamic> places) {
    if (_zoom >= 15.7) {
      return places
          .map((place) => _LandmarkCluster([place], _point(place)!))
          .toList();
    }
    final cell = _zoom < 11
        ? .12
        : _zoom < 12.5
            ? .055
            : _zoom < 14
                ? .022
                : .008;
    final grouped = <String, List<dynamic>>{};
    for (final place in places) {
      final point = _point(place)!;
      final key =
          '${(point.latitude / cell).floor()}:${(point.longitude / cell).floor()}';
      grouped.putIfAbsent(key, () => []).add(place);
    }
    return grouped.values.map((items) {
      final latitude = items
              .map((place) => _point(place)!.latitude)
              .reduce((a, b) => a + b) /
          items.length;
      final longitude = items
              .map((place) => _point(place)!.longitude)
              .reduce((a, b) => a + b) /
          items.length;
      return _LandmarkCluster(items, LatLng(latitude, longitude));
    }).toList();
  }

  void _selectPlace(Map<String, dynamic> place, {bool focus = false}) {
    _searchFocus.unfocus();
    setState(() => _selectedPlace = place);
    final point = _point(place);
    if (focus && point != null) _mapController.move(point, math.max(_zoom, 15));
  }

  void _submitSearch(String _) {
    final places = _visibleLandmarks;
    if (places.isNotEmpty) {
      _selectPlace(Map<String, dynamic>.from(places.first), focus: true);
    }
  }

  void _recenter() {
    if (_currentPosition == null) return;
    setState(() => _selectedPlace = null);
    _mapController.move(
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude), 15);
  }

  void _fitLandmarks() {
    final points = _visibleLandmarks.map(_point).whereType<LatLng>().toList();
    if (points.isEmpty) return;
    setState(() => _selectedPlace = null);
    if (points.length == 1) {
      _mapController.move(points.first, 15);
    } else {
      _mapController.fitCamera(CameraFit.coordinates(
        coordinates: points,
        padding: const EdgeInsets.fromLTRB(44, 170, 44, 90),
        maxZoom: 14,
      ));
    }
  }

  void _openDetails(Map<String, dynamic> place) => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => PlaceDetailsScreen(
                place: place, userPosition: _currentPosition)),
      );

  void _openCommute(Map<String, dynamic> place) => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) =>
                MapPreviewScreen(place: place, userPosition: _currentPosition)),
      );

  @override
  Widget build(BuildContext context) {
    final initialCenter = _currentPosition != null
        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
        : const LatLng(14.2810, 120.9290);
    final places = _visibleLandmarks;
    final clusters = _clusters(places);
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F1),
      body: Stack(children: [
        if (_isLoading)
          const Center(
              child: CircularProgressIndicator(color: Color(0xFF176A50)))
        else if (_error != null)
          _buildError()
        else
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: initialCenter,
              initialZoom: _zoom,
              minZoom: 8,
              maxZoom: 18,
              keepAlive: true,
              onTap: (_, __) {
                _searchFocus.unfocus();
                if (_selectedPlace != null) {
                  setState(() => _selectedPlace = null);
                }
              },
              onPositionChanged: (camera, _) {
                final nextZoom = camera.zoom;
                final displayChanged =
                    _displayLevel(nextZoom) != _displayLevel(_zoom);
                if (displayChanged && mounted) {
                  setState(() => _zoom = nextZoom);
                } else {
                  // Track the camera without rebuilding the tile and marker
                  // layers for every frame of a pinch gesture.
                  _zoom = nextZoom;
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.cavite_explorer_mobile',
                keepBuffer: 3,
                panBuffer: 2,
                tileDisplay: const TileDisplay.instantaneous(),
              ),
              MarkerLayer(markers: [
                ...clusters.map((cluster) => cluster.items.length > 1
                    ? _clusterMarker(cluster)
                    : _landmarkMarker(
                        Map<String, dynamic>.from(cluster.items.first))),
                if (_currentPosition != null) _userMarker(),
              ]),
            ],
          ),
        _buildTopControls(places.length),
        if (!_isLoading && _error == null) _buildMapButtons(),
        if (_selectedPlace != null) _buildPlacePreview(_selectedPlace!),
      ]),
    );
  }

  Widget _buildTopControls(int resultCount) => Positioned(
        top: MediaQuery.paddingOf(context).top + 10,
        left: 14,
        right: 14,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            _roundButton(
                Icons.arrow_back_rounded, () => Navigator.pop(context)),
            const SizedBox(width: 9),
            Expanded(
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(17),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0x1C000000),
                        blurRadius: 16,
                        offset: Offset(0, 6))
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocus,
                  textInputAction: TextInputAction.search,
                  onChanged: (_) => setState(() => _selectedPlace = null),
                  onSubmitted: _submitSearch,
                  style: GoogleFonts.poppins(fontSize: 12.5),
                  decoration: InputDecoration(
                    hintText: 'Search landmarks or cities',
                    hintStyle: GoogleFonts.poppins(
                        fontSize: 11.5, color: Colors.grey.shade500),
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: Color(0xFF52655B)),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _selectedPlace = null);
                            },
                            icon: const Icon(Icons.close_rounded, size: 19),
                          ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 9),
            PopupMenuButton<_MapFilter>(
              initialValue: _filter,
              tooltip: 'Filter landmarks',
              position: PopupMenuPosition.under,
              onSelected: (value) {
                setState(() {
                  _filter = value;
                  _selectedPlace = null;
                });
                if (!_isLoading && _error == null) {
                  WidgetsBinding.instance
                      .addPostFrameCallback((_) => _fitLandmarks());
                }
              },
              itemBuilder: (_) => _MapFilter.values
                  .map((value) => PopupMenuItem(
                        value: value,
                        child: Row(children: [
                          Icon(_iconFor(value),
                              size: 18, color: const Color(0xFF176A50)),
                          const SizedBox(width: 10),
                          Text(_labelFor(value),
                              style: GoogleFonts.poppins(fontSize: 12)),
                        ]),
                      ))
                  .toList(),
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFF173F34),
                  borderRadius: BorderRadius.circular(17),
                  boxShadow: const [
                    BoxShadow(color: Color(0x1C000000), blurRadius: 14)
                  ],
                ),
                child: const Icon(Icons.tune_rounded, color: Colors.white),
              ),
            ),
          ]),
          const SizedBox(height: 9),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .94),
              borderRadius: BorderRadius.circular(99),
              boxShadow: const [
                BoxShadow(color: Color(0x12000000), blurRadius: 9)
              ],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(_filterIcon, size: 15, color: const Color(0xFF176A50)),
              const SizedBox(width: 6),
              Text('$_filterLabel • $resultCount places',
                  style: GoogleFonts.poppins(
                      fontSize: 10.5,
                      color: const Color(0xFF314A3E),
                      fontWeight: FontWeight.w600)),
            ]),
          ),
        ]),
      );

  Widget _roundButton(IconData icon, VoidCallback onPressed) => Material(
        color: Colors.white,
        elevation: 4,
        shadowColor: Colors.black26,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
              width: 50,
              height: 50,
              child: Icon(icon, color: const Color(0xFF1E2B25))),
        ),
      );

  Widget _buildMapButtons() => Positioned(
        right: 15,
        bottom: _selectedPlace == null ? 28 : 188,
        child: Column(children: [
          _smallMapButton(
              Icons.center_focus_strong_rounded, _fitLandmarks, 'Show places'),
          const SizedBox(height: 9),
          _smallMapButton(Icons.my_location_rounded, _recenter, 'My location',
              enabled: _currentPosition != null),
        ]),
      );

  Widget _smallMapButton(IconData icon, VoidCallback action, String tooltip,
          {bool enabled = true}) =>
      Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.white,
          elevation: 4,
          shadowColor: Colors.black26,
          borderRadius: BorderRadius.circular(15),
          child: InkWell(
            onTap: enabled ? action : null,
            borderRadius: BorderRadius.circular(15),
            child: SizedBox(
                width: 48,
                height: 48,
                child: Icon(icon,
                    size: 21,
                    color: enabled
                        ? const Color(0xFF176A50)
                        : Colors.grey.shade400)),
          ),
        ),
      );

  Marker _clusterMarker(_LandmarkCluster cluster) => Marker(
        point: cluster.center,
        width: 66,
        height: 66,
        child: GestureDetector(
          onTap: () =>
              _mapController.move(cluster.center, math.min(_zoom + 2.2, 16.2)),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF176A50),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x42000000),
                    blurRadius: 11,
                    offset: Offset(0, 5))
              ],
            ),
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('${cluster.items.length}',
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800)),
              Text('PLACES',
                  style: GoogleFonts.poppins(
                      color: const Color(0xFFDDF56E),
                      fontSize: 7,
                      letterSpacing: .6,
                      fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      );

  Marker _landmarkMarker(Map<String, dynamic> place) {
    final id = place['id']?.toString() ?? '';
    final claimed = _claimedLandmarkIds.contains(id);
    final progress = _progressLandmarkIds.contains(id) && !claimed;
    final selected = _selectedPlace?['id']?.toString() == id;
    final detailed = _zoom >= 13.4;
    final size = selected
        ? 70.0
        : detailed
            ? 56.0
            : 42.0;
    final images = place['images'] is List
        ? List<dynamic>.from(place['images'] as List)
        : <dynamic>[];
    final image = images.isEmpty ? '' : ApiService.assetUrl(images.first);
    final borderColor = claimed
        ? const Color(0xFF37A36B)
        : progress
            ? const Color(0xFFF0A22E)
            : selected
                ? const Color(0xFF2E7DFF)
                : Colors.white;
    return Marker(
      point: _point(place)!,
      width: size + 10,
      height: size + 14,
      child: GestureDetector(
        onTap: () => _selectPlace(place),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: const Color(0xFFE8EEE9),
              shape: BoxShape.circle,
              border: Border.all(color: borderColor, width: selected ? 4 : 3),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x3D000000),
                    blurRadius: 8,
                    offset: Offset(0, 4))
              ],
            ),
            child: ClipOval(
              child: Stack(fit: StackFit.expand, children: [
                if (detailed && image.isNotEmpty)
                  Image.network(image,
                      fit: BoxFit.cover,
                      cacheWidth: 180,
                      filterQuality: FilterQuality.low,
                      gaplessPlayback: true,
                      errorBuilder: (_, __, ___) =>
                          _markerFallback(place['category']))
                else
                  _markerFallback(place['category']),
                if (claimed)
                  Container(
                      color: const Color(0xFF176A50).withValues(alpha: .5)),
                if (claimed)
                  const Icon(Icons.check_rounded,
                      color: Colors.white, size: 28),
                if (progress)
                  const Align(
                      alignment: Alignment.topRight,
                      child: Icon(Icons.timelapse_rounded,
                          color: Color(0xFFFFB23E), size: 19)),
              ]),
            ),
          ),
          if (selected)
            Container(
                width: 12,
                height: 7,
                decoration: const BoxDecoration(
                    color: Color(0xFF2E7DFF),
                    borderRadius:
                        BorderRadius.vertical(bottom: Radius.circular(10)))),
        ]),
      ),
    );
  }

  Widget _markerFallback(dynamic category) => Container(
        color: const Color(0xFFE9F1EA),
        child: Icon(_categoryIcon(category?.toString() ?? ''),
            color: const Color(0xFF176A50), size: 24),
      );

  Marker _userMarker() => Marker(
        point: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        width: 42,
        height: 42,
        child: Container(
          padding: const EdgeInsets.all(5),
          decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Color(0x3B000000), blurRadius: 9)]),
          child: Container(
            decoration: const BoxDecoration(
                color: Color(0xFF2E7DFF), shape: BoxShape.circle),
            child: const Icon(Icons.navigation_rounded,
                color: Colors.white, size: 18),
          ),
        ),
      );

  Widget _buildPlacePreview(Map<String, dynamic> place) {
    final images = place['images'] is List
        ? List<dynamic>.from(place['images'] as List)
        : <dynamic>[];
    final image = images.isEmpty ? '' : ApiService.assetUrl(images.first);
    final id = place['id']?.toString() ?? '';
    final claimed = _claimedLandmarkIds.contains(id);
    final progress = _progressLandmarkIds.contains(id) && !claimed;
    final rating = _number(place['averageRating']) ?? 0;
    final reviews = (_number(place['reviewCount']) ?? 0).toInt();
    return Positioned(
      left: 14,
      right: 14,
      bottom: 18,
      child: Material(
        color: Colors.white,
        elevation: 10,
        shadowColor: Colors.black26,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: 78,
                height: 94,
                child: image.isEmpty
                    ? _markerFallback(place['category'])
                    : Image.network(image,
                        fit: BoxFit.cover,
                        cacheWidth: 240,
                        filterQuality: FilterQuality.medium,
                        gaplessPlayback: true,
                        errorBuilder: (_, __, ___) =>
                            _markerFallback(place['category'])),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                          child: Text(place['name']?.toString() ?? 'Landmark',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  height: 1.2,
                                  fontWeight: FontWeight.w700))),
                      IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: () =>
                              setState(() => _selectedPlace = null),
                          icon: const Icon(Icons.close_rounded, size: 19)),
                    ]),
                    Text(
                      [place['barangay'], place['municipality']]
                          .where((value) =>
                              value != null &&
                              value.toString().trim().isNotEmpty)
                          .join(', '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                          fontSize: 9.5, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 5),
                    Row(children: [
                      Icon(
                          claimed
                              ? Icons.verified_rounded
                              : progress
                                  ? Icons.timelapse_rounded
                                  : Icons.star_rounded,
                          size: 15,
                          color: claimed
                              ? const Color(0xFF29935C)
                              : progress
                                  ? const Color(0xFFF0A22E)
                                  : const Color(0xFFF0A928)),
                      const SizedBox(width: 4),
                      Expanded(
                          child: Text(
                        claimed
                            ? 'Badge collected'
                            : progress
                                ? 'Badge visit in progress'
                                : reviews > 0
                                    ? '${rating.toStringAsFixed(1)} • $reviews ratings'
                                    : 'Badge available',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                            fontSize: 9.5,
                            color: const Color(0xFF486054),
                            fontWeight: FontWeight.w600),
                      )),
                    ]),
                    const SizedBox(height: 9),
                    Row(children: [
                      Expanded(
                          child: OutlinedButton(
                        onPressed: () => _openDetails(place),
                        style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF176A50),
                            side: const BorderSide(color: Color(0xFFB8CDBF)),
                            visualDensity: VisualDensity.compact),
                        child: const Text('View'),
                      )),
                      const SizedBox(width: 8),
                      Expanded(
                          child: FilledButton.icon(
                        onPressed: () => _openCommute(place),
                        style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF176A50),
                            visualDensity: VisualDensity.compact),
                        icon: const Icon(Icons.directions_transit_rounded,
                            size: 16),
                        label: const Text('Commute'),
                      )),
                    ]),
                  ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildError() => Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.map_outlined, color: Color(0xFF176A50), size: 48),
            const SizedBox(height: 12),
            Text(_error!,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _error = null;
                });
                _initializeMapData();
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ]),
        ),
      );

  String _labelFor(_MapFilter value) => switch (value) {
        _MapFilter.all => 'All places',
        _MapFilter.unclaimed => 'Unclaimed badges',
        _MapFilter.inProgress => 'Badge visits in progress',
        _MapFilter.claimed => 'Collected badges',
        _MapFilter.popular => 'Most popular',
        _MapFilter.topRated => 'Top rated',
      };

  IconData _iconFor(_MapFilter value) => switch (value) {
        _MapFilter.all => Icons.place_outlined,
        _MapFilter.unclaimed => Icons.lock_outline_rounded,
        _MapFilter.inProgress => Icons.timelapse_rounded,
        _MapFilter.claimed => Icons.verified_rounded,
        _MapFilter.popular => Icons.local_fire_department_rounded,
        _MapFilter.topRated => Icons.star_rounded,
      };

  IconData _categoryIcon(String category) {
    final value = category.toLowerCase();
    if (value.contains('church') || value.contains('relig')) {
      return Icons.church_outlined;
    }
    if (value.contains('park') || value.contains('nature')) {
      return Icons.park_outlined;
    }
    if (value.contains('museum')) {
      return Icons.museum_outlined;
    }
    if (value.contains('monument') || value.contains('histor')) {
      return Icons.account_balance_outlined;
    }
    return Icons.location_on_rounded;
  }
}

class _LandmarkCluster {
  final List<dynamic> items;
  final LatLng center;
  const _LandmarkCluster(this.items, this.center);
}
