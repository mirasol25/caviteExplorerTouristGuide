import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'landmark_journal_screen.dart';

class VisitedPlacesScreen extends StatefulWidget {
  const VisitedPlacesScreen({super.key});

  @override
  State<VisitedPlacesScreen> createState() => _VisitedPlacesScreenState();
}

class _VisitedPlacesScreenState extends State<VisitedPlacesScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _places = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final user = await AuthService.getUser();
      final token = user?['token']?.toString() ?? '';
      if (token.isEmpty) {
        throw Exception('Sign in to view your visited places.');
      }

      final results = await Future.wait<dynamic>([
        http.get(
          ApiService.uri('/badges/me'),
          headers: {'Authorization': 'Bearer $token'},
        ),
        ApiService.getLandmarks(),
      ]);
      final response = results.first as http.Response;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Could not load your visited places.');
      }
      final badgeBody = json.decode(response.body) as Map<String, dynamic>;
      final earnedBadges = ((badgeBody['collection'] as List?) ?? const [])
          .whereType<Map>()
          .where((badge) => badge['earned'] == true)
          .toList();
      final earnedByLandmark = <String, Map>{
        for (final badge in earnedBadges)
          if (badge['id'] != null) badge['id'].toString(): badge,
      };
      _places = (results.last as List)
          .whereType<Map>()
          .where(
              (place) => earnedByLandmark.containsKey(place['id']?.toString()))
          .map((place) {
        final result = Map<String, dynamic>.from(place);
        final badge = earnedByLandmark[place['id']?.toString()];
        result['earnedAt'] = badge?['earnedAt'];
        return result;
      }).toList()
        ..sort((a, b) => (a['name']?.toString() ?? '')
            .compareTo(b['name']?.toString() ?? ''));
      _error = null;
    } catch (error) {
      _error = error.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(Map<String, dynamic> place) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LandmarkJournalScreen(place: place)),
    );
  }

  String _image(Map<String, dynamic> place) {
    final images = place['images'];
    if (images is List && images.isNotEmpty) {
      final first = images.first;
      if (first is Map) {
        return ApiService.assetUrl(first['url'] ?? first['path'] ?? '');
      }
      return ApiService.assetUrl(first);
    }
    return ApiService.assetUrl(place['image'] ?? place['imageUrl'] ?? '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F4),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F7F4),
        surfaceTintColor: Colors.transparent,
        title: Text('My journey',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _MessageState(
                    icon: Icons.cloud_off_rounded,
                    message: _error!,
                    action: _load,
                  )
                : _places.isEmpty
                    ? const _MessageState(
                        icon: Icons.hiking_rounded,
                        message:
                            'Your verified landmark visits will appear here.',
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
                        children: [
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [
                                Color(0xFF123F33),
                                Color(0xFF176A50),
                              ]),
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: Row(children: [
                              const Icon(Icons.photo_camera_back_rounded,
                                  color: Color(0xFFD8F270), size: 30),
                              const SizedBox(width: 13),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        '${_places.length} places in your journey',
                                        style: GoogleFonts.poppins(
                                            color: Colors.white,
                                            fontSize: 17,
                                            fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 3),
                                    Text(
                                      'Return to your photos and stories, or preserve another visit.',
                                      style: GoogleFonts.poppins(
                                          color: Colors.white70,
                                          fontSize: 10.5,
                                          height: 1.4),
                                    ),
                                  ],
                                ),
                              ),
                            ]),
                          ),
                          const SizedBox(height: 18),
                          ..._places.map((place) => _VisitedPlaceCard(
                                place: place,
                                imageUrl: _image(place),
                                onTap: () => _open(place),
                              )),
                        ],
                      ),
      ),
    );
  }
}

class _VisitedPlaceCard extends StatelessWidget {
  final Map<String, dynamic> place;
  final String imageUrl;
  final VoidCallback onTap;

  const _VisitedPlaceCard({
    required this.place,
    required this.imageUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final location = [place['barangay'], place['municipality']]
        .where((value) => value?.toString().trim().isNotEmpty == true)
        .join(', ');
    final summary =
        (place['shortSummary'] ?? place['description'] ?? '').toString().trim();
    return Semantics(
      button: true,
      label: 'Open your memories from ${place['name']}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFDDE5E0)),
          ),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: SizedBox(
                width: 92,
                height: 104,
                child: imageUrl.endsWith('/')
                    ? const ColoredBox(
                        color: Color(0xFFE7EDE7),
                        child: Icon(Icons.landscape_rounded,
                            color: Color(0xFF176A50)),
                      )
                    : Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        cacheWidth: 300,
                        errorBuilder: (_, __, ___) => const ColoredBox(
                          color: Color(0xFFE7EDE7),
                          child: Icon(Icons.landscape_rounded,
                              color: Color(0xFF176A50)),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(place['name']?.toString() ?? 'Landmark',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                          fontSize: 14,
                          height: 1.25,
                          fontWeight: FontWeight.w700)),
                  if (location.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Row(children: [
                      const Icon(Icons.location_on_outlined,
                          size: 14, color: Color(0xFF176A50)),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                                fontSize: 10, color: Colors.grey.shade600)),
                      ),
                    ]),
                  ],
                  if (summary.isNotEmpty) ...[
                    const SizedBox(height: 7),
                    Text(summary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                            fontSize: 10,
                            height: 1.35,
                            color: Colors.grey.shade600)),
                  ],
                  const SizedBox(height: 9),
                  Row(children: [
                    Text('Open memory lane',
                        style: GoogleFonts.poppins(
                            fontSize: 10.5,
                            color: const Color(0xFF176A50),
                            fontWeight: FontWeight.w700)),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_rounded,
                        size: 15, color: Color(0xFF176A50)),
                  ]),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  final IconData icon;
  final String message;
  final Future<void> Function()? action;

  const _MessageState({
    required this.icon,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(30),
        children: [
          const SizedBox(height: 130),
          Icon(icon, size: 58, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(message,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: Colors.grey.shade600)),
          if (action != null) ...[
            const SizedBox(height: 16),
            Center(
                child: FilledButton(
                    onPressed: action, child: const Text('Try again'))),
          ],
        ],
      );
}
