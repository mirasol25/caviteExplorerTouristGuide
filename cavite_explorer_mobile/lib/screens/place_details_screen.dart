import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../screens/map_preview_screen.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/background_tracking_service.dart';
import '../widgets/landmark_community_section.dart';

class PlaceDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> place;
  final Position? userPosition;
  final int initialSection;
  final bool openCommunityComposer;

  const PlaceDetailsScreen({
    super.key,
    required this.place,
    this.userPosition,
    this.initialSection = 0,
    this.openCommunityComposer = false,
  });

  @override
  State<PlaceDetailsScreen> createState() => _PlaceDetailsScreenState();
}

class _PlaceDetailsScreenState extends State<PlaceDetailsScreen>
    with SingleTickerProviderStateMixin {
  int _currentImageIndex = 0;
  late int _detailSection;
  bool _badgeClaimed = false;
  bool _favorite = false;
  bool _favoriteBusy = false;
  bool _partnersLoading = true;
  String? _partnersError;
  List<Map<String, dynamic>> _coveredPartners = [];
  final PageController _imagePageController = PageController();
  Timer? _imageSlider;
  AnimationController? _badgePulse;

  void _ensureBadgePulse() {
    _badgePulse ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    )..repeat(reverse: true);
  }

  @override
  void initState() {
    super.initState();
    _detailSection = widget.initialSection;
    _ensureBadgePulse();
    _loadBadgeClaimed();
    _loadFavorite();
    _loadCoveredPartners();
    VisitTrackingController.instance.unlockedBadge.addListener(_badgeUnlocked);
    final images = widget.place['images'] is List
        ? List<dynamic>.from(widget.place['images'] as List)
        : <dynamic>[];
    if (images.length > 1) {
      _imageSlider = Timer.periodic(const Duration(seconds: 4), (_) {
        if (!mounted || !_imagePageController.hasClients) return;
        final nextIndex = (_currentImageIndex + 1) % images.length;
        _imagePageController.animateToPage(
          nextIndex,
          duration: const Duration(milliseconds: 550),
          curve: Curves.easeInOutCubic,
        );
      });
    }
  }

  Future<void> _loadFavorite() async {
    final user = await AuthService.getUser();
    final token = user?['token'] ?? '';
    final id = widget.place['id']?.toString() ?? '';
    if (token.isEmpty || id.isEmpty) return;
    try {
      final response = await http.get(ApiService.uri('/places/$id/favorite'),
          headers: {'Authorization': 'Bearer $token'});
      if (response.statusCode == 200 && mounted) {
        setState(() => _favorite = json.decode(response.body)['saved'] == true);
      }
    } catch (_) {}
  }

  Future<void> _toggleFavorite() async {
    final user = await AuthService.getUser();
    final token = user?['token'] ?? '';
    if (token.isEmpty) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sign in to save landmarks.')));
      return;
    }
    setState(() => _favoriteBusy = true);
    final id = widget.place['id'];
    try {
      final response = await (_favorite
          ? http.delete(ApiService.uri('/places/$id/favorite'),
              headers: {'Authorization': 'Bearer $token'})
          : http.post(ApiService.uri('/places/$id/favorite'),
              headers: {'Authorization': 'Bearer $token'}));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        var message = 'Could not update saved landmark.';
        try {
          final body = json.decode(response.body);
          if (body is Map && body['message'] != null) {
            message = body['message'].toString();
          }
        } catch (_) {}
        throw Exception(message);
      }
      if (mounted) {
        setState(() => _favorite = !_favorite);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_favorite
                ? 'Landmark saved.'
                : 'Removed from saved landmarks.')));
      }
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _favoriteBusy = false);
    }
  }

  @override
  void dispose() {
    VisitTrackingController.instance.unlockedBadge
        .removeListener(_badgeUnlocked);
    _imageSlider?.cancel();
    _imagePageController.dispose();
    _badgePulse?.dispose();
    super.dispose();
  }

  void _badgeUnlocked() {
    final badge = VisitTrackingController.instance.unlockedBadge.value;
    if (badge?['landmarkId']?.toString() == widget.place['id']?.toString() &&
        mounted) {
      setState(() => _badgeClaimed = true);
    }
  }

  Future<void> _loadBadgeClaimed() async {
    try {
      final user = await AuthService.getUser();
      final token = user?['token']?.toString() ?? '';
      if (token.isEmpty) return;
      final response = await http.get(
        ApiService.uri('/badges/me'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode < 200 || response.statusCode >= 300) return;
      final body = json.decode(response.body) as Map<String, dynamic>;
      final id = widget.place['id']?.toString();
      final claimed = ((body['collection'] as List?) ?? const []).any(
        (badge) =>
            badge is Map &&
            badge['id']?.toString() == id &&
            badge['earned'] == true,
      );
      if (mounted) setState(() => _badgeClaimed = claimed);
    } catch (_) {
      // The landmark remains usable when collection status is unavailable.
    }
  }

  Future<void> _loadCoveredPartners() async {
    final landmarkId = widget.place['id']?.toString() ?? '';
    if (landmarkId.isEmpty) {
      if (mounted) setState(() => _partnersLoading = false);
      return;
    }
    try {
      final response = await http.get(
        ApiService.uri('/places/${Uri.encodeComponent(landmarkId)}/partners'),
      );
      final body = json.decode(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(body is Map
            ? body['message'] ?? 'Could not load badge partners.'
            : 'Could not load badge partners.');
      }
      _coveredPartners = (body as List)
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      _partnersError = null;
    } catch (error) {
      _partnersError = error.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) setState(() => _partnersLoading = false);
    }
  }

  void _openPartner(Map<String, dynamic> partner) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MapPreviewScreen(
          userPosition: widget.userPosition,
          place: {
            'id': 'partner-${partner['id']}',
            'name': partner['name'],
            'description': partner['description'] ??
                'Approved Cavite Explorer partner offering badge-holder rewards.',
            'municipality': partner['municipality'],
            'barangay': partner['barangay'],
            'latitude': partner['latitude'],
            'longitude': partner['longitude'],
            'images': partner['image'] == null ? [] : [partner['image']],
            'category': 'Partner',
          },
        ),
      ),
    );
  }

  Future<void> _openExplore() async {
    if (_badgeClaimed) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.replay_circle_filled_rounded,
              color: Color(0xFF176A50), size: 42),
          title: Text('Revisit this place?',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
          content: Text(
            'You already collected this landmark badge. You can revisit and explore again, but no additional badge will be awarded.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 12.5, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Continue revisit'),
            ),
          ],
        ),
      );
      if (proceed != true || !mounted) return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MapPreviewScreen(
          place: widget.place,
          userPosition: widget.userPosition,
        ),
      ),
    );
  }

  @override
  void reassemble() {
    super.reassemble();
    _ensureBadgePulse();
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
    final String description = widget.place['description'] ??
        "The Emilio Aguinaldo Shrine is a national shrine located in Kawit, Cavite in the Philippines, where the Philippine Declaration of Independence from Spain was declared on June 12, 1898. To commemorate the event, the Philippine flag is raised here by top government officials each year. The house is now a museum.";
    final String shortSummary = _text(widget.place['shortSummary']);
    final bool alwaysOpen = widget.place['isAlwaysOpen'] == true;
    final bool freeEntrance = widget.place['isFreeEntrance'] == true;
    final String schedule = alwaysOpen
        ? 'Open 24 hours'
        : [
            _text(widget.place['openingDays']),
            [
              _text(widget.place['openingTime']),
              _text(widget.place['closingTime'])
            ].where((value) => value.isNotEmpty).join(' – '),
          ].where((value) => value.isNotEmpty).join(' · ');
    final visitorInformation = <MapEntry<String, String>>[
      if (schedule.isNotEmpty) MapEntry('Opening schedule', schedule),
      if (freeEntrance || _text(widget.place['entranceFee']).isNotEmpty)
        MapEntry(
            'Entrance fee',
            freeEntrance
                ? 'Free entrance'
                : _text(widget.place['entranceFee'])),
      if (_text(widget.place['visitDuration']).isNotEmpty)
        MapEntry('Visit duration', _text(widget.place['visitDuration'])),
      if (_text(widget.place['bestTimeToVisit']).isNotEmpty)
        MapEntry('Best time to visit', _text(widget.place['bestTimeToVisit'])),
      if (_text(widget.place['contactNumber']).isNotEmpty)
        MapEntry('Contact', _text(widget.place['contactNumber'])),
      if (_text(widget.place['websiteUrl']).isNotEmpty)
        MapEntry('Official page', _text(widget.place['websiteUrl'])),
    ];
    final historicalInformation = <MapEntry<String, String>>[
      if (_text(widget.place['historicalBackground']).isNotEmpty)
        MapEntry('Historical background',
            _text(widget.place['historicalBackground'])),
      if (_text(widget.place['culturalSignificance']).isNotEmpty)
        MapEntry('Cultural significance',
            _text(widget.place['culturalSignificance'])),
      if (_text(widget.place['yearEstablished']).isNotEmpty)
        MapEntry('Year established', _text(widget.place['yearEstablished'])),
    ];
    final reminders = <MapEntry<String, String>>[
      if (_text(widget.place['dressCode']).isNotEmpty)
        MapEntry('Dress code', _text(widget.place['dressCode'])),
      if (_text(widget.place['photographyRules']).isNotEmpty)
        MapEntry('Photography', _text(widget.place['photographyRules'])),
      if (_text(widget.place['prohibitedItems']).isNotEmpty)
        MapEntry('Prohibited items', _text(widget.place['prohibitedItems'])),
      if (_text(widget.place['petPolicy']).isNotEmpty)
        MapEntry('Pet policy', _text(widget.place['petPolicy'])),
      if (_text(widget.place['safetyReminders']).isNotEmpty)
        MapEntry('Safety', _text(widget.place['safetyReminders'])),
      if (_text(widget.place['emergencyContact']).isNotEmpty)
        MapEntry('Emergency contact', _text(widget.place['emergencyContact'])),
      if (_text(widget.place['visitorTips']).isNotEmpty)
        MapEntry('Visitor tips', _text(widget.place['visitorTips'])),
    ];
    final String badgeName = _text(widget.place['badgeName']).isNotEmpty
        ? _text(widget.place['badgeName'])
        : '$name Explorer';
    final String badgeDescription =
        _text(widget.place['badgeDescription']).isNotEmpty
            ? _text(widget.place['badgeDescription'])
            : 'Complete a verified visit to $name to unlock this badge.';
    final int badgeMinutes =
        (widget.place['badgeRequiredMinutes'] as num?)?.round() ?? 30;
    final Color badgeColor = _badgeColor(widget.place['badgeColor']);

    final List<dynamic> images = widget.place['images'] != null
        ? List<dynamic>.from(widget.place['images'])
        : [];
    final String fallbackImage =
        "https://via.placeholder.com/600x400?text=No+Image";
    final screenHeight = MediaQuery.of(context).size.height;

    // --- DISTANCE CALCULATION ---
    String distanceText = "";
    if (widget.userPosition != null &&
        widget.place['latitude'] != null &&
        widget.place['longitude'] != null) {
      double distanceInMeters = Geolocator.distanceBetween(
          widget.userPosition!.latitude,
          widget.userPosition!.longitude,
          (widget.place['latitude'] as num).toDouble(),
          (widget.place['longitude'] as num).toDouble());

      if (distanceInMeters < 1000) {
        distanceText = "${distanceInMeters.toStringAsFixed(0)} m away";
      } else {
        distanceText =
            "${(distanceInMeters / 1000).toStringAsFixed(1)} km away";
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9F7F2),
      body: Stack(
        children: [
          // 1. BACKGROUND IMAGE
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: screenHeight * 0.45,
            child: Stack(
              children: [
                PageView.builder(
                  controller: _imagePageController,
                  itemCount: images.isEmpty ? 1 : images.length,
                  onPageChanged: (index) =>
                      setState(() => _currentImageIndex = index),
                  itemBuilder: (context, index) {
                    return Semantics(
                      image: true,
                      label:
                          '$name photo ${index + 1} of ${images.isEmpty ? 1 : images.length}',
                      child: Image.network(
                          ApiService.assetUrl(
                              images.isEmpty ? fallbackImage : images[index]),
                          fit: BoxFit.cover,
                          width: double.infinity,
                          cacheWidth: 1200,
                          filterQuality: FilterQuality.medium,
                          errorBuilder: (_, __, ___) => Container(
                                color: const Color(0xFFE8EEE9),
                                alignment: Alignment.center,
                                child: const Icon(
                                    Icons.image_not_supported_outlined,
                                    size: 38,
                                    color: Color(0xFF809087)),
                              )),
                    );
                  },
                ),
                if (images.length > 1)
                  Positioned(
                    bottom: 40,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(images.length, (index) {
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: _currentImageIndex == index ? 8 : 6,
                          height: _currentImageIndex == index ? 8 : 6,
                          decoration: BoxDecoration(
                              color: _currentImageIndex == index
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.5),
                              shape: BoxShape.circle),
                        );
                      }),
                    ),
                  )
              ],
            ),
          ),
          // 2. SCROLLABLE CONTENT
          SingleChildScrollView(
            child: Column(
              children: [
                SizedBox(height: screenHeight * 0.38),
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFAF8F5),
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(32)),
                  ),
                  padding: const EdgeInsets.only(
                      top: 12, left: 24, right: 24, bottom: 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                            width: 40,
                            height: 5,
                            decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(10))),
                      ),
                      const SizedBox(height: 24),
                      if (_text(widget.place['category']).isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                              color: const Color(0xFFE8F2E8),
                              borderRadius: BorderRadius.circular(99)),
                          child: Text(
                              _text(widget.place['category']).toUpperCase(),
                              style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  letterSpacing: .7,
                                  color: const Color(0xFF176A50),
                                  fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(height: 10),
                      ],
                      Text(name,
                          style: GoogleFonts.poppins(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1A1A1A),
                              height: 1.12)),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildMetaChip(Icons.location_on_outlined, location,
                              const Color(0xFFF1F3F1), const Color(0xFF33413A)),
                          if (distanceText.isNotEmpty)
                            _buildMetaChip(Icons.near_me_rounded, distanceText,
                                const Color(0xFFEAF1FF), Colors.blueAccent),
                        ],
                      ),
                      const SizedBox(height: 22),
                      _buildDetailTabs(
                        hasVisit: visitorInformation.isNotEmpty,
                        hasHistory: historicalInformation.isNotEmpty ||
                            _list(widget.place['importantPeople']).isNotEmpty ||
                            _list(widget.place['importantEvents']).isNotEmpty ||
                            _list(widget.place['interestingFacts']).isNotEmpty,
                        hasReminders: reminders.isNotEmpty,
                      ),
                      const SizedBox(height: 18),
                      if (_detailSection == 0) ...[
                        if (shortSummary.isNotEmpty) ...[
                          Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                  color: const Color(0xFFF0F6F0),
                                  borderRadius: BorderRadius.circular(16)),
                              child: Text(shortSummary,
                                  style: GoogleFonts.poppins(
                                      fontSize: 15,
                                      color: const Color(0xFF244A3B),
                                      fontWeight: FontWeight.w600,
                                      height: 1.5))),
                          const SizedBox(height: 18),
                        ],
                        Text('About this place',
                            style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: const Color(0xFF273C32),
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Text(description,
                            style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.grey[700],
                                height: 1.58)),
                        const SizedBox(height: 22),
                        ValueListenableBuilder<List<Map<String, dynamic>>>(
                          valueListenable:
                              VisitTrackingController.instance.visits,
                          builder: (_, visits, __) {
                            Map<String, dynamic>? activeVisit;
                            final landmarkId = widget.place['id']?.toString();
                            for (final visit in visits) {
                              if (visit['landmarkId']?.toString() ==
                                  landmarkId) {
                                activeVisit = visit;
                                break;
                              }
                            }
                            return _buildLandmarkBadge(
                              name: badgeName,
                              description: badgeDescription,
                              iconName: _text(widget.place['badgeIcon']),
                              imagePath: _text(widget.place['badgeImage']),
                              color: badgeColor,
                              requiredMinutes: badgeMinutes,
                              activeVisit: activeVisit,
                              claimed: _badgeClaimed,
                            );
                          },
                        ),
                      ],
                      if (_detailSection == 1 && visitorInformation.isNotEmpty)
                        _buildVisitSection(visitorInformation),
                      if (_detailSection == 2)
                        _buildInformationSection(
                            'History and significance',
                            Icons.account_balance_outlined,
                            historicalInformation,
                            lists: {
                              'Important people':
                                  _list(widget.place['importantPeople']),
                              'Important events':
                                  _list(widget.place['importantEvents']),
                              'Interesting facts':
                                  _list(widget.place['interestingFacts'])
                            }),
                      if (_detailSection == 3 && reminders.isNotEmpty)
                        _buildInformationSection('Before you go',
                            Icons.info_outline_rounded, reminders),
                      if (_detailSection == 4)
                        LandmarkCommunitySection(
                          place: widget.place,
                          openComposerOnLoad: widget.openCommunityComposer,
                        ),
                      if (_detailSection == 5)
                        _buildCoveredPartnersSection(badgeName),
                      const SizedBox(height: 26),
                      SizedBox(
                        width: double.infinity,
                        height: 58,
                        child: ElevatedButton.icon(
                          onPressed: _openExplore,
                          icon: Icon(
                              _badgeClaimed
                                  ? Icons.replay_rounded
                                  : Icons.explore_outlined,
                              color: Colors.white),
                          label: Text(
                              _badgeClaimed
                                  ? 'Revisit this place'
                                  : 'Explore this landmark',
                              style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF176A50),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18)),
                              shadowColor:
                                  const Color(0xFF176A50).withOpacity(.28),
                              elevation: 8),
                        ),
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 3. BACK BUTTON
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 20,
            child: IconButton(
              tooltip: 'Back',
              onPressed: () => Navigator.pop(context),
              style: IconButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                  elevation: 4,
                  shadowColor: Colors.black26),
              icon: const Icon(Icons.arrow_back, size: 20),
            ),
          ),
          // Keep actions above the scroll view so their taps are not captured
          // by the transparent header area of the scrolling content.
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            right: 20,
            child: Semantics(
              button: true,
              label: _favorite
                  ? 'Remove $name from saved landmarks'
                  : 'Save $name',
              child: IconButton(
                tooltip: _favorite ? 'Remove from saved' : 'Save landmark',
                onPressed: _favoriteBusy ? null : _toggleFavorite,
                style: IconButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF176A50),
                    elevation: 4,
                    shadowColor: Colors.black26),
                icon: _favoriteBusy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(_favorite
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _text(dynamic value) => value?.toString().trim() ?? '';

  String _countdown(int seconds) {
    final safe = math.max(0, seconds);
    return '${(safe ~/ 60).toString().padLeft(2, '0')}:${(safe % 60).toString().padLeft(2, '0')}';
  }

  List<String> _list(dynamic value) {
    if (value is! List) return const [];
    return value
        .map((item) => _text(item))
        .where((item) => item.isNotEmpty)
        .toList();
  }

  Color _badgeColor(dynamic value) {
    final hex = _text(value).replaceFirst('#', '');
    if (RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(hex)) {
      return Color(int.parse('FF$hex', radix: 16));
    }
    return const Color(0xFF176A50);
  }

  IconData _badgeIcon(String value) {
    switch (value) {
      case 'church':
        return Icons.church_outlined;
      case 'museum':
        return Icons.museum_outlined;
      case 'nature':
        return Icons.park_outlined;
      case 'monument':
        return Icons.account_balance_outlined;
      case 'plaza':
        return Icons.location_city_outlined;
      default:
        return Icons.workspace_premium_outlined;
    }
  }

  Widget _buildLandmarkBadge({
    required String name,
    required String description,
    required String iconName,
    required String imagePath,
    required Color color,
    required int requiredMinutes,
    Map<String, dynamic>? activeVisit,
    bool claimed = false,
  }) {
    final inProgress = activeVisit != null && !claimed;
    final visitStatus = activeVisit?['status']?.toString() ?? '';
    final paused = visitStatus == 'PAUSED' || visitStatus == 'OUTSIDE';
    final remaining = math.max(
      0,
      (activeVisit?['remainingSeconds'] as num?)?.round() ??
          requiredMinutes * 60,
    );
    return AnimatedBuilder(
      animation: _badgePulse ?? kAlwaysDismissedAnimation,
      builder: (context, child) => Transform.scale(
        scale: 1 + ((_badgePulse?.value ?? 0) * .006),
        child: child,
      ),
      child: Semantics(
        button: true,
        label: 'Preview the $name badge',
        child: GestureDetector(
          onTap: () => _showBadgeDetails(
            name: name,
            description: description,
            iconName: iconName,
            imagePath: imagePath,
            color: color,
            requiredMinutes: requiredMinutes,
          ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color.withOpacity(.13), color.withOpacity(.035)],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: color.withOpacity(.24)),
              boxShadow: [
                BoxShadow(
                    color: color.withOpacity(.08),
                    blurRadius: 22,
                    offset: const Offset(0, 9))
              ],
            ),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                      color: color.withOpacity(.12),
                      borderRadius: BorderRadius.circular(9)),
                  child: Icon(Icons.workspace_premium_rounded,
                      size: 17, color: color),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text('COLLECTIBLE LANDMARK BADGE',
                      style: GoogleFonts.poppins(
                          fontSize: 9,
                          letterSpacing: .8,
                          color: color,
                          fontWeight: FontWeight.w800)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.78),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: color.withOpacity(.14))),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(
                        claimed
                            ? Icons.check_circle_outline_rounded
                            : inProgress
                                ? paused
                                    ? Icons.pause_rounded
                                    : Icons.timer_outlined
                                : Icons.lock_outline_rounded,
                        size: 12,
                        color: color),
                    const SizedBox(width: 4),
                    Text(
                        claimed
                            ? 'COLLECTED'
                            : inProgress
                                ? 'IN PROGRESS'
                                : 'LOCKED',
                        style: GoogleFonts.poppins(
                            fontSize: 8,
                            letterSpacing: .5,
                            color: color,
                            fontWeight: FontWeight.w800)),
                  ]),
                ),
              ]),
              const SizedBox(height: 16),
              Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                Container(
                  width: 96,
                  height: 96,
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: color.withOpacity(.28), width: 2),
                    boxShadow: [
                      BoxShadow(
                          color: color.withOpacity(.24),
                          blurRadius: 18,
                          offset: const Offset(0, 7))
                    ],
                  ),
                  child: _buildShiningBadgeArtwork(
                    imagePath: imagePath,
                    iconName: iconName,
                    color: color,
                    iconSize: 40,
                    cacheWidth: 320,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: GoogleFonts.poppins(
                                fontSize: 17,
                                height: 1.25,
                                color: const Color(0xFF18372D),
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Text(description,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                                fontSize: 10.5,
                                height: 1.45,
                                color: const Color(0xFF66776F))),
                      ]),
                ),
              ]),
              const SizedBox(height: 17),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.72),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: color.withOpacity(.13))),
                child: Row(children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                        color: color.withOpacity(.12), shape: BoxShape.circle),
                    child: Icon(
                        claimed
                            ? Icons.workspace_premium_rounded
                            : inProgress
                                ? Icons.timer_outlined
                                : Icons.location_on_outlined,
                        size: 18,
                        color: color),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              claimed
                                  ? 'Badge already collected'
                                  : inProgress
                                      ? paused
                                          ? 'Visit paused • ${_countdown(remaining)} remaining'
                                          : '${_countdown(remaining)} remaining to unlock'
                                      : 'Stay for $requiredMinutes minutes to unlock',
                              style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: color,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text(
                              claimed
                                  ? 'Revisit anytime and add more memories to your journey.'
                                  : inProgress
                                      ? paused
                                          ? 'Return within the grace period to keep your progress.'
                                          : 'Keep exploring while your visit is verified.'
                                      : 'Your visit will be verified at this landmark.',
                              style: GoogleFonts.poppins(
                                  fontSize: 9.5,
                                  color: const Color(0xFF718078))),
                        ]),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                        color: color.withOpacity(.1),
                        borderRadius: BorderRadius.circular(99)),
                    child: Text('VIEW BADGE',
                        style: GoogleFonts.poppins(
                            fontSize: 7.5,
                            letterSpacing: .3,
                            color: color,
                            fontWeight: FontWeight.w800)),
                  ),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildShiningBadgeArtwork({
    required String imagePath,
    required String iconName,
    required Color color,
    required double iconSize,
    required int cacheWidth,
  }) {
    return ClipOval(
      child: LayoutBuilder(builder: (context, constraints) {
        final size =
            constraints.maxWidth.isFinite ? constraints.maxWidth : iconSize * 2;
        return Stack(fit: StackFit.expand, children: [
          ColoredBox(
            color: color,
            child: imagePath.isNotEmpty
                ? Image.network(
                    ApiService.assetUrl(imagePath),
                    fit: BoxFit.cover,
                    cacheWidth: cacheWidth,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (_, __, ___) => Icon(_badgeIcon(iconName),
                        color: Colors.white, size: iconSize),
                  )
                : Icon(_badgeIcon(iconName),
                    color: Colors.white, size: iconSize),
          ),
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _badgePulse ?? kAlwaysDismissedAnimation,
              builder: (context, child) {
                final progress = _badgePulse?.value ?? 0;
                final glow = .12 + (math.sin(progress * math.pi) * .12);
                return Stack(children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: const Alignment(-.35, -.45),
                          radius: 1.05,
                          colors: [
                            Colors.white.withOpacity(glow),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: (-size * .55) + (progress * size * 1.55),
                    top: -size * .25,
                    child: Transform.rotate(
                      angle: -.28,
                      child: Container(
                        width: size * .24,
                        height: size * 1.5,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            Colors.white.withOpacity(0),
                            Colors.white.withOpacity(.72),
                            Colors.white.withOpacity(0),
                          ]),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: size * .14,
                    top: size * .12,
                    child: Opacity(
                      opacity: .45 + (progress * .5),
                      child: Icon(Icons.auto_awesome_rounded,
                          size: size * .16, color: Colors.white),
                    ),
                  ),
                ]);
              },
            ),
          ),
        ]);
      }),
    );
  }

  void _showBadgeDetails({
    required String name,
    required String description,
    required String iconName,
    required String imagePath,
    required Color color,
    required int requiredMinutes,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        var badgeAnimation = 0;
        return StatefulBuilder(
          builder: (modalContext, setSheetState) => SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              decoration: const BoxDecoration(
                color: Color(0xFFFBFAF7),
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                      width: 42,
                      height: 5,
                      decoration: BoxDecoration(
                          color: const Color(0xFFD8DDD9),
                          borderRadius: BorderRadius.circular(99))),
                  const SizedBox(height: 22),
                  Text('A BADGE WORTH EXPLORING FOR',
                      style: GoogleFonts.poppins(
                          fontSize: 9,
                          letterSpacing: 1.1,
                          color: color,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 18),
                  GestureDetector(
                    onTap: () => setSheetState(() => badgeAnimation++),
                    child: TweenAnimationBuilder<double>(
                      key: ValueKey(badgeAnimation),
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 720),
                      curve: Curves.easeInOut,
                      builder: (context, progress, child) {
                        final bounce = math.sin(progress * math.pi);
                        final wobble = math.sin(progress * math.pi * 2) *
                            .045 *
                            (1 - progress);
                        return Transform.rotate(
                          angle: wobble,
                          child: Transform.scale(
                            scale: 1 + (bounce * .12),
                            child: child,
                          ),
                        );
                      },
                      child: Stack(alignment: Alignment.center, children: [
                        AnimatedBuilder(
                          animation: _badgePulse ?? kAlwaysDismissedAnimation,
                          builder: (context, child) => Transform.scale(
                            scale: 1 + ((_badgePulse?.value ?? 0) * .06),
                            child: Opacity(
                              opacity: .72 + ((_badgePulse?.value ?? 0) * .28),
                              child: child,
                            ),
                          ),
                          child: Container(
                            width: 174,
                            height: 174,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(colors: [
                                color.withOpacity(.28),
                                color.withOpacity(.02)
                              ]),
                            ),
                          ),
                        ),
                        Container(
                          width: 142,
                          height: 142,
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: color.withOpacity(.32), width: 2),
                            boxShadow: [
                              BoxShadow(
                                  color: color.withOpacity(.3),
                                  blurRadius: 28,
                                  offset: const Offset(0, 12))
                            ],
                          ),
                          child: _buildShiningBadgeArtwork(
                            imagePath: imagePath,
                            iconName: iconName,
                            color: color,
                            iconSize: 58,
                            cacheWidth: 520,
                          ),
                        ),
                        Positioned(
                          right: 12,
                          bottom: 12,
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 4)),
                            child: const Icon(Icons.lock_rounded,
                                size: 18, color: Colors.white),
                          ),
                        ),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text('Tap the badge',
                      style: GoogleFonts.poppins(
                          fontSize: 9,
                          color: color.withOpacity(.72),
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 18),
                  Text(name,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                          fontSize: 23,
                          height: 1.2,
                          color: const Color(0xFF18372D),
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(description,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                          fontSize: 12,
                          height: 1.55,
                          color: const Color(0xFF687970))),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: color.withOpacity(.07),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: color.withOpacity(.16))),
                    child: Column(children: [
                      _buildBadgeGoal(
                          Icons.location_on_outlined,
                          'Visit the landmark',
                          'Be physically present at the destination.',
                          color),
                      const SizedBox(height: 14),
                      _buildBadgeGoal(
                          Icons.timer_outlined,
                          'Explore for $requiredMinutes minutes',
                          'Time spent discovering the place counts toward the badge.',
                          color),
                      const SizedBox(height: 14),
                      _buildBadgeGoal(
                          Icons.workspace_premium_outlined,
                          'Add it to your collection',
                          'Claim the badge once your visit is verified.',
                          color),
                    ]),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        Future<void>.delayed(Duration.zero, _openExplore);
                      },
                      icon: Icon(
                          _badgeClaimed
                              ? Icons.replay_rounded
                              : Icons.explore_outlined,
                          color: Colors.white),
                      label: Text(
                          _badgeClaimed
                              ? 'Revisit this place'
                              : 'Explore this landmark',
                          style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.white,
                              fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: color,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15)),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBadgeGoal(
      IconData icon, String title, String subtitle, Color color) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
            color: color.withOpacity(.12), shape: BoxShape.circle),
        child: Icon(icon, size: 18, color: color),
      ),
      const SizedBox(width: 11),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: GoogleFonts.poppins(
                  fontSize: 11.5,
                  color: const Color(0xFF253C32),
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(subtitle,
              style: GoogleFonts.poppins(
                  fontSize: 9.5, height: 1.4, color: const Color(0xFF718078))),
        ]),
      ),
    ]);
  }

  Widget _buildMetaChip(
      IconData icon, String label, Color background, Color color) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
          color: background, borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Flexible(
            child: Text(label,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                    fontSize: 12, color: color, fontWeight: FontWeight.w600))),
      ]),
    );
  }

  Widget _buildCoveredPartnersSection(String badgeName) {
    if (_partnersLoading) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 42),
        alignment: Alignment.center,
        child: const CircularProgressIndicator(color: Color(0xFF176A50)),
      );
    }
    if (_partnersError != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF4EE),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFFFC9AF)),
        ),
        child: Column(children: [
          const Icon(Icons.storefront_outlined,
              color: Color(0xFFC5522F), size: 31),
          const SizedBox(height: 9),
          Text(_partnersError!,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 11.5, height: 1.45)),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: () {
              setState(() => _partnersLoading = true);
              _loadCoveredPartners();
            },
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
          ),
        ]),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF123E33), Color(0xFF1E785C)],
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(children: [
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(13),
            ),
            child:
                const Icon(Icons.local_offer_rounded, color: Color(0xFFDDF56E)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Badge partner coverage',
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(
                '${_coveredPartners.length} approved ${_coveredPartners.length == 1 ? 'partner' : 'partners'} within 2.5 km',
                style:
                    GoogleFonts.poppins(color: Colors.white70, fontSize: 10.5),
              ),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 13),
      Text('Where you can use $badgeName',
          style:
              GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700)),
      const SizedBox(height: 4),
      Text(
        'Earn this landmark badge, then present its QR at a participating partner. Each partner reward can be redeemed once.',
        style: GoogleFonts.poppins(
            fontSize: 10.5, height: 1.5, color: Colors.grey.shade600),
      ),
      const SizedBox(height: 13),
      if (_coveredPartners.isEmpty)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
          decoration: BoxDecoration(
            color: const Color(0xFFF2F5F1),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFDCE4DD)),
          ),
          child: Column(children: [
            const Icon(Icons.store_mall_directory_outlined,
                color: Color(0xFF6B8175), size: 34),
            const SizedBox(height: 9),
            Text('No covered partners yet',
                style: GoogleFonts.poppins(
                    fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text(
              'Approved businesses that accept this badge within 2.5 km will appear here.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 10.5, height: 1.45, color: Colors.grey.shade600),
            ),
          ]),
        )
      else
        ..._coveredPartners.map((partner) {
          final offers = (partner['offers'] as List?) ?? const [];
          final offer = offers.isNotEmpty && offers.first is Map
              ? Map<String, dynamic>.from(offers.first as Map)
              : <String, dynamic>{};
          final meters = (partner['distanceMeters'] as num?)?.toInt() ?? 0;
          final distance = meters >= 1000
              ? '${(meters / 1000).toStringAsFixed(1)} km away'
              : '$meters m away';
          return Container(
            margin: const EdgeInsets.only(bottom: 11),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFDCE3DD)),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x0D000000),
                    blurRadius: 12,
                    offset: Offset(0, 5)),
              ],
            ),
            child: Row(children: [
              Container(
                width: 49,
                height: 49,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5F2E9),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: partner['image']?.toString().isNotEmpty == true
                    ? Image.network(
                        ApiService.assetUrl(partner['image']),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                            Icons.storefront_rounded,
                            color: Color(0xFF176A50)),
                      )
                    : const Icon(Icons.storefront_rounded,
                        color: Color(0xFF176A50)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(partner['name']?.toString() ?? 'Partner',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                              fontSize: 12.5, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 3),
                      Text(offer['discountLabel']?.toString() ?? 'Badge reward',
                          style: GoogleFonts.poppins(
                              fontSize: 10.5,
                              color: const Color(0xFF9A6D19),
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(
                        '${partner['category'] ?? 'Local partner'}  •  $distance',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                            fontSize: 9.5, color: Colors.grey.shade600),
                      ),
                    ]),
              ),
              IconButton.filledTonal(
                tooltip: 'Commute to partner',
                onPressed: partner['latitude'] == null
                    ? null
                    : () => _openPartner(partner),
                style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFE8F2E8)),
                icon: const Icon(Icons.directions_rounded,
                    color: Color(0xFF176A50), size: 21),
              ),
            ]),
          );
        }),
    ]);
  }

  Widget _buildDetailTabs({
    required bool hasVisit,
    required bool hasHistory,
    required bool hasReminders,
  }) {
    final tabs = <({int index, String label, IconData icon})>[
      (index: 0, label: 'Overview', icon: Icons.grid_view_rounded),
      if (hasHistory)
        (index: 2, label: 'History', icon: Icons.account_balance_rounded),
      if (hasVisit)
        (index: 1, label: 'Plan visit', icon: Icons.event_available_rounded),
      if (hasReminders)
        (index: 3, label: 'Reminders', icon: Icons.info_outline_rounded),
      (index: 4, label: 'Community', icon: Icons.people_alt_outlined),
      (index: 5, label: 'Badge offers', icon: Icons.local_offer_outlined),
    ];
    return LayoutBuilder(builder: (context, constraints) {
      Widget tabButton(({int index, String label, IconData icon}) tab) {
        final selected = _detailSection == tab.index;
        return Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(9),
            onTap: () => setState(() => _detailSection = tab.index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 9),
              decoration: BoxDecoration(
                color: selected ? const Color(0xFF176A50) : Colors.transparent,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(tab.icon,
                    size: 16,
                    color: selected ? Colors.white : const Color(0xFF5B7064)),
                const SizedBox(height: 4),
                Text(
                  tab.label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 9.5,
                    color: selected ? Colors.white : const Color(0xFF5B7064),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ]),
            ),
          ),
        );
      }

      final topTabs = tabs.take(3).toList();
      final bottomTabs = tabs.skip(3).toList();
      return Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFFE7EDE7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Row(children: [
              for (var i = 0; i < topTabs.length; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                tabButton(topTabs[i]),
              ],
            ]),
            if (bottomTabs.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(children: [
                for (var i = 0; i < bottomTabs.length; i++) ...[
                  if (i > 0) const SizedBox(width: 4),
                  tabButton(bottomTabs[i]),
                ],
              ]),
            ],
          ],
        ),
      );
    });
  }

  Widget _buildVisitSection(List<MapEntry<String, String>> entries) {
    String valueFor(String label) {
      for (final entry in entries) {
        if (entry.key == label) return entry.value;
      }
      return '';
    }

    final schedule = valueFor('Opening schedule');
    final fee = valueFor('Entrance fee');
    final duration = valueFor('Visit duration');
    final extras = entries
        .where((entry) => ![
              'Opening schedule',
              'Entrance fee',
              'Visit duration'
            ].contains(entry.key))
        .toList();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE1E9E1)),
          boxShadow: const [
            BoxShadow(
                color: Color(0x0A173A2E), blurRadius: 16, offset: Offset(0, 6))
          ]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                  color: const Color(0xFFE8F3E7),
                  borderRadius: BorderRadius.circular(11)),
              child: const Icon(Icons.event_available_outlined,
                  color: Color(0xFF176A50), size: 20)),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Plan your visit',
                    style: GoogleFonts.poppins(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1D332A))),
                Text('Helpful details before you go',
                    style: GoogleFonts.poppins(
                        fontSize: 11, color: const Color(0xFF718078)))
              ])),
        ]),
        if (schedule.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
              width: double.infinity,
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                  color: const Color(0xFFF3F8F2),
                  borderRadius: BorderRadius.circular(13)),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.schedule_rounded,
                    size: 18, color: Color(0xFF176A50)),
                const SizedBox(width: 9),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('Opening schedule',
                          style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: const Color(0xFF557065),
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 3),
                      Text(schedule,
                          style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: const Color(0xFF263C33),
                              height: 1.4,
                              fontWeight: FontWeight.w600))
                    ]))
              ])),
        ],
        if (fee.isNotEmpty || duration.isNotEmpty) ...[
          const SizedBox(height: 12),
          Row(children: [
            if (fee.isNotEmpty)
              Expanded(
                  child: _buildVisitMetric(
                      Icons.confirmation_number_outlined, 'Entrance', fee)),
            if (fee.isNotEmpty && duration.isNotEmpty)
              const SizedBox(width: 10),
            if (duration.isNotEmpty)
              Expanded(
                  child: _buildVisitMetric(
                      Icons.timelapse_outlined, 'Visit duration', duration))
          ]),
        ],
        if (extras.isNotEmpty) ...[
          const SizedBox(height: 12),
          ...extras.map((entry) => _buildVisitRow(entry.key, entry.value)),
        ],
      ]),
    );
  }

  Widget _buildVisitMetric(IconData icon, String label, String value) =>
      Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: const Color(0xFFFAFBFA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE8EEE8))),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 17, color: const Color(0xFF176A50)),
            const SizedBox(height: 8),
            Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: const Color(0xFF718078),
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: const Color(0xFF263C33),
                    fontWeight: FontWeight.w600))
          ]));

  Widget _buildVisitRow(String label, String value) => Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFEAF0EA)))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.info_outline_rounded,
            size: 17, color: Color(0xFF6A8074)),
        const SizedBox(width: 9),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: const Color(0xFF62756A),
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(value,
              maxLines: label == 'Official page' ? 2 : null,
              overflow: label == 'Official page' ? TextOverflow.ellipsis : null,
              style: GoogleFonts.poppins(
                  fontSize: 12, color: const Color(0xFF263C33), height: 1.4))
        ]))
      ]));

  Widget _buildInformationSection(
    String title,
    IconData icon,
    List<MapEntry<String, String>> entries, {
    Map<String, List<String>> lists = const {},
  }) {
    final populatedLists =
        lists.entries.where((entry) => entry.value.isNotEmpty).toList();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3E8E3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: const Color(0xFFEAF3E5),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 19, color: const Color(0xFF176A50)),
            ),
            const SizedBox(width: 10),
            Expanded(
                child: Text(title,
                    style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1D332A)))),
          ]),
          if (entries.isNotEmpty) const SizedBox(height: 14),
          ...entries.map((entry) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.key,
                          style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: const Color(0xFF6F7F77),
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 3),
                      Text(entry.value,
                          style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: const Color(0xFF263C33),
                              height: 1.45)),
                    ]),
              )),
          ...populatedLists.map((entry) => Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 10),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.key,
                          style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: const Color(0xFF6F7F77),
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 5),
                      ...entry.value.map((item) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Padding(
                                      padding: EdgeInsets.only(top: 7),
                                      child: Icon(Icons.circle,
                                          size: 5, color: Color(0xFF176A50))),
                                  const SizedBox(width: 8),
                                  Expanded(
                                      child: Text(item,
                                          style: GoogleFonts.poppins(
                                              fontSize: 13,
                                              color: const Color(0xFF263C33),
                                              height: 1.4))),
                                ]),
                          )),
                    ]),
              )),
        ],
      ),
    );
  }

  Widget _buildMinigameCard(String placeName, String bgImage) {
    return Container(
      width: double.infinity,
      height: 120,
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          image:
              DecorationImage(image: NetworkImage(bgImage), fit: BoxFit.cover)),
      child: Container(
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.black.withOpacity(0.8),
                  Colors.black.withOpacity(0.3)
                ])),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Minigame • Find the Items",
                      style: GoogleFonts.poppins(
                          color: Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text(placeName,
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(
                      "Find items inside the $placeName and learn the history behind every item.",
                      style: GoogleFonts.poppins(
                          color: Colors.white70, fontSize: 10),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.8),
                    shape: BoxShape.circle),
                child: const Icon(Icons.play_arrow_rounded,
                    color: Colors.black87, size: 24))
          ],
        ),
      ),
    );
  }
}
