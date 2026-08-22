import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../services/api_service.dart';
import '../services/location_service.dart';
import '../services/auth_service.dart';
import '../services/background_tracking_service.dart';
import 'map_preview_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  List<dynamic> _allLandmarks = [];
  Position? _currentPosition;
  bool _isLoading = true;
  Set<String> _claimedLandmarkIds = <String>{};

  @override
  void initState() {
    super.initState();
    VisitTrackingController.instance.unlockedBadge.addListener(_badgeUnlocked);
    _initializeMapData();
  }

  @override
  void dispose() {
    VisitTrackingController.instance.unlockedBadge
        .removeListener(_badgeUnlocked);
    super.dispose();
  }

  void _badgeUnlocked() {
    final id = VisitTrackingController
        .instance.unlockedBadge.value?['landmarkId']
        ?.toString();
    if (id != null && id.isNotEmpty && mounted) {
      setState(() {
        _claimedLandmarkIds.add(id);
      });
    }
  }

  Future<Set<String>> _loadClaimedLandmarks() async {
    final token = (await AuthService.getUser())?['token']?.toString();
    if (token == null || token.isEmpty) return <String>{};
    try {
      final response = await http.get(
        ApiService.uri('/badges/me'),
        headers: {'Authorization': 'Bearer $token'},
      );
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
      // Fetch both location and landmarks simultaneously for speed
      final results = await Future.wait([
        LocationService.promptLocationOnce(),
        ApiService.getLandmarks(),
        _loadClaimedLandmarks(),
      ]);

      if (mounted) {
        setState(() {
          _currentPosition = results[0] as Position?;
          _allLandmarks = results[1] as List<dynamic>;
          _claimedLandmarkIds = results[2] as Set<String>;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading map data: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Default center to Cavite if user location isn't available
    final initialCenter = _currentPosition != null 
        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
        : const LatLng(14.2810, 120.9290); // Central Cavite Coordinates

    return Scaffold(
      body: Stack(
        children: [
          if (_isLoading)
            const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
          else
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: initialCenter,
                initialZoom: 11.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.cavite_explorer_mobile',
                ),
                MarkerLayer(
                  markers: [
                    // 1. Plot all landmark pins with IMAGES
                    ..._allLandmarks.where((p) => p['latitude'] != null && p['longitude'] != null).map((place) {
                      final lat = double.tryParse(place['latitude'].toString()) ?? 0.0;
                      final lng = double.tryParse(place['longitude'].toString()) ?? 0.0;
                      
                      // Extract the first image, or use a fallback
                      final List<dynamic> images = place['images'] != null ? List<dynamic>.from(place['images']) : [];
                      final String imageUrl = ApiService.assetUrl(images.isNotEmpty ? images[0] : "https://via.placeholder.com/150?text=No+Image");
                      final claimed = _claimedLandmarkIds
                          .contains(place['id']?.toString());
                      
                      return Marker(
                        point: LatLng(lat, lng),
                        width: 60, // Increased size slightly to make the image visible
                        height: 60,
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => MapPreviewScreen(
                                  place: place,
                                  userPosition: _currentPosition,
                                ),
                              ),
                            );
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: claimed
                                      ? const Color(0xFF37A36B)
                                      : Colors.white,
                                  width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 3),
                                )
                              ],
                            ),
                            child: ClipOval(
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.network(
                                    imageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: Colors.redAccent,
                                        child: const Icon(Icons.location_on,
                                            color: Colors.white, size: 30),
                                      );
                                    },
                                  ),
                                  if (claimed) ...[
                                    Container(
                                      color: const Color(0xFF176A50)
                                          .withValues(alpha: .42),
                                    ),
                                    const Center(
                                      child: Icon(Icons.check_rounded,
                                          color: Colors.white, size: 30),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),

                    // 2. Plot User Location (Blue Dot)
                    if (_currentPosition != null)
                      Marker(
                        point: LatLng(_currentPosition!.latitude, _currentPosition!.longitude), 
                        width: 24, height: 24, 
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.blue, 
                            shape: BoxShape.circle, 
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4)]
                          )
                        )
                      ),
                  ],
                ),
              ],
            ),

          // BACK BUTTON
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
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2))]
                ),
                child: const Icon(Icons.arrow_back, color: Colors.black87, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
