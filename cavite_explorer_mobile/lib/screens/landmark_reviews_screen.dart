import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import '../services/api_service.dart';
import '../widgets/visitor_review_card.dart';

class LandmarkReviewsScreen extends StatefulWidget {
  final Map<String, dynamic> place;

  const LandmarkReviewsScreen({super.key, required this.place});

  @override
  State<LandmarkReviewsScreen> createState() => _LandmarkReviewsScreenState();
}

class _LandmarkReviewsScreenState extends State<LandmarkReviewsScreen> {
  bool _loading = true;
  String? _error;
  double _average = 0;
  int _reviewCount = 0;
  List<Map<String, dynamic>> _posts = [];

  String get _landmarkId => widget.place['id']?.toString() ?? '';
  String get _landmarkName => widget.place['name']?.toString() ?? 'Landmark';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_landmarkId.isEmpty) return;
    if (mounted && _posts.isEmpty) setState(() => _loading = true);
    try {
      final response =
          await http.get(ApiService.uri('/places/$_landmarkId/community'));
      if (response.statusCode != 200) {
        throw Exception('Could not load visitor reviews.');
      }
      final body = json.decode(response.body) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _average = (body['averageRating'] as num?)?.toDouble() ?? 0;
        _reviewCount = (body['reviewCount'] as num?)?.round() ?? 0;
        _posts = ((body['posts'] as List?) ?? const [])
            .whereType<Map>()
            .map((value) => Map<String, dynamic>.from(value))
            .toList();
        _error = null;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F7F2),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF9F7F2),
        surfaceTintColor: Colors.transparent,
        titleSpacing: 0,
        title: Text(
          'Visitor reviews',
          style: GoogleFonts.poppins(fontSize: 19, fontWeight: FontWeight.w700),
        ),
      ),
      body: RefreshIndicator(
        color: const Color(0xFF176A50),
        onRefresh: _load,
        child: _loading
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 220),
                  Center(child: CircularProgressIndicator()),
                ],
              )
            : _error != null && _posts.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    children: [
                      const SizedBox(height: 120),
                      const Icon(Icons.cloud_off_rounded,
                          color: Color(0xFF176A50), size: 42),
                      const SizedBox(height: 12),
                      Text(_error!, textAlign: TextAlign.center),
                      TextButton(
                          onPressed: _load, child: const Text('Try again')),
                    ],
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
                    itemCount: _posts.length + 1,
                    itemBuilder: (_, index) {
                      if (index == 0) return _summary();
                      return VisitorReviewCard(post: _posts[index - 1]);
                    },
                  ),
      ),
    );
  }

  Widget _summary() => Container(
        margin: const EdgeInsets.only(bottom: 18),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF173F34),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.12),
                borderRadius: BorderRadius.circular(17),
              ),
              alignment: Alignment.center,
              child: Text(
                _reviewCount == 0 ? '—' : _average.toStringAsFixed(1),
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _landmarkName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$_reviewCount verified visitor ${_reviewCount == 1 ? 'review' : 'reviews'}',
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 10.5,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Pull down to refresh',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFFD8F270),
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}
