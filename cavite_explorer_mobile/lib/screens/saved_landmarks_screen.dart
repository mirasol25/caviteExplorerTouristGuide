import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'place_details_screen.dart';

class SavedLandmarksScreen extends StatefulWidget {
  const SavedLandmarksScreen({super.key});

  @override
  State<SavedLandmarksScreen> createState() => _SavedLandmarksScreenState();
}

class _SavedLandmarksScreenState extends State<SavedLandmarksScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _places = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final user = await AuthService.getUser();
      final response = await http.get(ApiService.uri('/places/favorites/me'),
          headers: {'Authorization': 'Bearer ${user?['token'] ?? ''}'});
      final body = json.decode(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(body['message'] ?? 'Could not load saved landmarks.');
      }
      _places = (body as List)
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      _error = null;
    } catch (error) {
      _error = error.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFF8F8F6),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF8F8F6),
          surfaceTintColor: Colors.transparent,
          title: Text('Saved landmarks',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(_error!, textAlign: TextAlign.center)))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: _places.isEmpty
                        ? ListView(children: [
                            const SizedBox(height: 130),
                            Icon(Icons.bookmark_border_rounded,
                                size: 58, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text('No saved landmarks yet',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                    fontSize: 19, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 7),
                            Text(
                                'Tap the bookmark on a landmark to keep it here.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                    color: Colors.grey.shade600))
                          ])
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(18, 10, 18, 30),
                            itemCount: _places.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final place = _places[index];
                              final images =
                                  (place['images'] as List?) ?? const [];
                              final name =
                                  place['name']?.toString() ?? 'Landmark';
                              return Semantics(
                                button: true,
                                label: 'Open saved landmark $name',
                                child: Material(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(20),
                                    onTap: () async {
                                      await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (_) =>
                                                  PlaceDetailsScreen(
                                                      place: place)));
                                      _load();
                                    },
                                    child: Padding(
                                        padding: const EdgeInsets.all(10),
                                        child: Row(children: [
                                          ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(15),
                                              child: images.isEmpty
                                                  ? Container(
                                                      width: 86,
                                                      height: 86,
                                                      color: const Color(
                                                          0xFFE5EEE8),
                                                      child: const Icon(
                                                          Icons
                                                              .landscape_rounded,
                                                          color: Color(
                                                              0xFF176A50)))
                                                  : Image.network(ApiService.assetUrl(images.first),
                                                      width: 86,
                                                      height: 86,
                                                      fit: BoxFit.cover,
                                                      cacheWidth: 300,
                                                      errorBuilder: (_, __, ___) =>
                                                          Container(
                                                              width: 86,
                                                              height: 86,
                                                              color: const Color(
                                                                  0xFFE5EEE8),
                                                              child: const Icon(
                                                                  Icons.landscape_rounded)))),
                                          const SizedBox(width: 14),
                                          Expanded(
                                              child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                Text(name,
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: GoogleFonts.poppins(
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        fontSize: 15)),
                                                const SizedBox(height: 6),
                                                Text(
                                                    [
                                                      place['barangay'],
                                                      place['municipality']
                                                    ]
                                                        .where((value) =>
                                                            value != null &&
                                                            value
                                                                .toString()
                                                                .isNotEmpty)
                                                        .join(', '),
                                                    style: GoogleFonts.poppins(
                                                        fontSize: 11,
                                                        color: Colors
                                                            .grey.shade600)),
                                                const SizedBox(height: 7),
                                                Text(
                                                    '${place['reviewCount'] ?? 0} visitor reviews',
                                                    style: GoogleFonts.poppins(
                                                        fontSize: 10,
                                                        color: const Color(
                                                            0xFF176A50),
                                                        fontWeight:
                                                            FontWeight.w600)),
                                              ])),
                                          const Icon(
                                              Icons.chevron_right_rounded,
                                              semanticLabel: 'Open'),
                                        ])),
                                  ),
                                ),
                              );
                            },
                          )),
      );
}
