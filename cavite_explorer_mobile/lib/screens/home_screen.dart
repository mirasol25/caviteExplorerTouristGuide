import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'dart:math';

import '../services/api_service.dart';
import '../services/location_service.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'badge_collection_screen.dart';
import 'visited_places_screen.dart';
import 'partners_screen.dart';
import '../services/auth_service.dart';
import '../screens/place_details_screen.dart';
import '../screens/map_screen.dart'; // Make sure the path matches your folder structure

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _userName;
  bool _isLoadingUser = true;
  Position? _currentPosition;

  // --- NEW: SEARCH & FILTER STATE ---
  List<dynamic> _allLandmarks = [];
  bool _isLoadingData = true;
  String _searchQuery = "";
  String _selectedMunicipality = "All";
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchUser();
    _triggerSmartLocation();
    _fetchLandmarks(); // Load data once on startup
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _triggerSmartLocation() async {
    final position = await LocationService.promptLocationOnce();
    if (position != null && mounted) {
      setState(() {
        _currentPosition = position;
      });
    }
  }

  Future<void> _fetchUser() async {
    try {
      final userData = await AuthService.getUser();
      if (mounted) {
        setState(() {
          _userName = userData?['name'];
          _isLoadingUser = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingUser = false);
    }
  }

  // --- NEW: FETCH DATA ONCE ---
  Future<void> _fetchLandmarks() async {
    try {
      final data = await ApiService.getLandmarks();
      if (mounted) {
        setState(() {
          _allLandmarks = data;
          _isLoadingData = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching landmarks: $e");
      if (mounted) setState(() => _isLoadingData = false);
    }
  }

  Future<void> _refreshHome() async {
    await Future.wait([
      _fetchUser(),
      _triggerSmartLocation(),
      _fetchLandmarks(),
    ]);
  }

  // --- NEW: SEARCH & FILTER LOGIC ---
  List<dynamic> get _filteredLandmarks {
    return _allLandmarks.where((place) {
      final name = (place['name'] ?? "").toString().toLowerCase();
      final town = (place['municipality'] ?? "").toString().toLowerCase();
      final barangay = (place['barangay'] ?? "").toString().toLowerCase();
      final query = _searchQuery.toLowerCase();

      final matchesSearch = name.contains(query) ||
          town.contains(query) ||
          barangay.contains(query);
      final matchesFilter = _selectedMunicipality == "All" ||
          place['municipality'] == _selectedMunicipality;

      return matchesSearch && matchesFilter;
    }).toList();
  }

  void _showFilterSheet() {
    // Dynamically extract unique municipalities from your database!
    final municipalities = [
      "All",
      ..._allLandmarks.map((e) => e['municipality'].toString()).toSet()
    ];

    // Sort them alphabetically, keeping "All" at the top
    municipalities.sort((a, b) => a == "All"
        ? -1
        : b == "All"
            ? 1
            : a.compareTo(b));

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(builder: (context, setSheetState) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                    child: Container(
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(10)))),
                const SizedBox(height: 24),
                Text("Filter by Municipality",
                    style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1A1A1A))),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: municipalities.map((town) {
                    final isSelected = _selectedMunicipality == town;
                    return ChoiceChip(
                      label: Text(town,
                          style: GoogleFonts.poppins(
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w500)),
                      selected: isSelected,
                      selectedColor: const Color(0xFF1A1A1A),
                      labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87),
                      backgroundColor: Colors.grey[100],
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: const BorderSide(color: Colors.transparent)),
                      onSelected: (selected) {
                        setSheetState(() => _selectedMunicipality = town);
                        setState(() => _selectedMunicipality =
                            town); // Update main screen too
                        Navigator.pop(context);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Prepare standard sections if not searching
    final popularItems = List<dynamic>.from(_allLandmarks)
      ..sort((a, b) {
        final claims = ((b['badgeClaimCount'] as num?)?.toInt() ?? 0)
            .compareTo((a['badgeClaimCount'] as num?)?.toInt() ?? 0);
        if (claims != 0) return claims;
        return ((b['reviewCount'] as num?)?.toInt() ?? 0)
            .compareTo((a['reviewCount'] as num?)?.toInt() ?? 0);
      });
    final topRatedItems = List<dynamic>.from(_allLandmarks)
      ..removeWhere(
          (item) => ((item['reviewCount'] as num?)?.toInt() ?? 0) == 0)
      ..sort((a, b) {
        double score(dynamic item) {
          final rating = (item['averageRating'] as num?)?.toDouble() ?? 0;
          final reviews = (item['reviewCount'] as num?)?.toDouble() ?? 0;
          // Bayesian weighting keeps a single 5-star review from outranking a
          // consistently highly rated landmark with many verified reviews.
          return (reviews / (reviews + 5)) * rating + (5 / (reviews + 5)) * 3.5;
        }

        final scoreOrder = score(b).compareTo(score(a));
        if (scoreOrder != 0) return scoreOrder;
        return ((b['reviewCount'] as num?)?.toInt() ?? 0)
            .compareTo((a['reviewCount'] as num?)?.toInt() ?? 0);
      });
    List<dynamic> recommendedItems = List.from(_allLandmarks);

    if (_currentPosition != null) {
      recommendedItems.sort((a, b) {
        double distA = Geolocator.distanceBetween(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            (a['latitude'] as num).toDouble(),
            (a['longitude'] as num).toDouble());
        double distB = Geolocator.distanceBetween(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            (b['latitude'] as num).toDouble(),
            (b['longitude'] as num).toDouble());
        return distA.compareTo(distB);
      });
    } else {
      recommendedItems.shuffle();
    }
    recommendedItems = recommendedItems.take(4).toList();

    // Check if user is actively searching or filtering
    bool isSearchingOrFiltering =
        _searchQuery.isNotEmpty || _selectedMunicipality != "All";

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: _isLoadingData
            ? const Center(
                child: CircularProgressIndicator(color: Colors.black87))
            : Stack(
                children: [
                  RefreshIndicator(
                    color: const Color(0xFF176A50),
                    onRefresh: _refreshHome,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 150),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 14),
                          _buildHeader(context),
                          const SizedBox(height: 20),
                          _buildSearchBar(),
                          const SizedBox(height: 28),

                          // --- DYNAMIC UI SWITCH ---
                          if (isSearchingOrFiltering) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("Search Results",
                                    style: GoogleFonts.poppins(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF1A1A1A))),
                                Text("${_filteredLandmarks.length} found",
                                    style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w500)),
                              ],
                            ),
                            const SizedBox(height: 15),
                            _buildGridList(_filteredLandmarks),
                          ] else ...[
                            // Default Standard UI
                            _sectionHeader("Popular Destinations", "See all"),
                            const SizedBox(height: 15),
                            _buildPopularList(popularItems.isEmpty
                                ? _allLandmarks
                                : popularItems),

                            const SizedBox(height: 30),
                            _sectionHeader("Top Rated Places", "View map"),
                            const SizedBox(height: 13),
                            _buildRankedList(topRatedItems.take(10).toList()),

                            const SizedBox(height: 32),
                            _sectionHeader(
                                _currentPosition != null
                                    ? "Nearest to You"
                                    : "Recommended for You",
                                "Explore"),
                            const SizedBox(height: 15),
                            _buildGridList(recommendedItems),
                          ]
                        ],
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: _buildFloatingBottomNav(),
                  ),
                ],
              ),
      ),
    );
  }

  // --- UI COMPONENTS ---

  Widget _buildHeader(BuildContext context) {
    final displayName = (_userName?.trim().isNotEmpty ?? false)
        ? _userName!.trim().split(RegExp(r'\s+')).first
        : 'Explorer';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      child: Row(children: [
        Container(
          width: 50,
          height: 50,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE4E8E3)),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x12000000),
                    blurRadius: 10,
                    offset: Offset(0, 4))
              ]),
          child: ClipOval(
              child: Image.asset('assets/images/cavite-explorer-logo.png',
                  fit: BoxFit.contain)),
        ),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
              _userName == null
                  ? 'DISCOVER LOCAL STORIES'
                  : 'WELCOME BACK, ${displayName.toUpperCase()}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                  color: Colors.grey.shade500,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .8)),
          const SizedBox(height: 1),
          Row(children: [
            Flexible(
                child: Text('Explore Cavite',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                        color: const Color(0xFF1A1A1A),
                        fontSize: 27,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.8))),
            const SizedBox(width: 4),
            const Icon(Icons.location_on_rounded,
                color: Color(0xFF4285F4), size: 23),
          ]),
        ])),
        const SizedBox(width: 10),
        if (_isLoadingUser)
          const SizedBox(
              width: 42,
              height: 42,
              child: Padding(
                  padding: EdgeInsets.all(10),
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.black54)))
        else if (_userName != null)
          Tooltip(
            message: 'Open profile',
            child: InkWell(
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen())),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                  width: 43,
                  height: 43,
                  decoration: BoxDecoration(
                      color: const Color(0xFFE8F1FF),
                      borderRadius: BorderRadius.circular(15)),
                  alignment: Alignment.center,
                  child: Text(displayName.characters.first.toUpperCase(),
                      style: GoogleFonts.poppins(
                          color: const Color(0xFF3478E5),
                          fontWeight: FontWeight.w800,
                          fontSize: 17))),
            ),
          )
        else
          FilledButton(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const LoginScreen())),
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1A1A1A),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14))),
            child: Text('Sign in',
                style: GoogleFonts.poppins(
                    fontSize: 11, fontWeight: FontWeight.w700)),
          ),
      ]),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: const Color(0xFFE9ECE8)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 15,
              offset: const Offset(0, 5))
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) =>
            setState(() => _searchQuery = value), // Live search update!
        decoration: InputDecoration(
          hintText: "Search places, historical sites...",
          hintStyle: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 14),
          prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
          // Clear button or Tune icon depending on state
          suffixIcon: _searchQuery.isNotEmpty || _selectedMunicipality != "All"
              ? IconButton(
                  icon: const Icon(Icons.close, color: Colors.black87),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = "";
                      _selectedMunicipality = "All";
                    });
                  },
                )
              : GestureDetector(
                  onTap: _showFilterSheet, // Trigger bottom sheet!
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(10)),
                    child:
                        const Icon(Icons.tune, color: Colors.white, size: 18),
                  ),
                ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, String actionText) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(title,
            style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1A1A1A),
                letterSpacing: -0.5)),
        if (actionText.isNotEmpty)
          InkWell(
            onTap: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const MapScreen()));
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 2.0, left: 8.0, top: 8.0),
              child: Text(actionText,
                  style: GoogleFonts.poppins(
                      color: Colors.blueAccent,
                      fontWeight: FontWeight.w600,
                      fontSize: 14)),
            ),
          ),
      ],
    );
  }

  Widget _buildPopularList(List<dynamic> items) {
    if (items.isEmpty) {
      return Text("No popular landmarks.", style: GoogleFonts.poppins());
    }

    final availableWidth = MediaQuery.sizeOf(context).width - 36;
    final cardWidth = ((availableWidth - 14) / 2).clamp(165.0, 210.0);
    return SizedBox(
      height: 250,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final images =
              item['images'] != null ? List<dynamic>.from(item['images']) : [];

          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PlaceDetailsScreen(
                      place: item, userPosition: _currentPosition),
                ),
              );
            },
            child: Container(
              width: cardWidth,
              margin: const EdgeInsets.only(right: 14, bottom: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                color: Colors.grey[300],
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 6))
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Stack(
                  children: [
                    Positioned.fill(child: AutoSlidingImages(images: images)),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.8),
                            Colors.transparent
                          ],
                          stops: const [0.0, 0.6],
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['name'] ?? "Unknown",
                              style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.location_on,
                                    color: Colors.white70, size: 14),
                                const SizedBox(width: 4),
                                Expanded(
                                    child: Text(
                                        [item['barangay'], item['municipality']]
                                            .where((part) =>
                                                part != null &&
                                                part
                                                    .toString()
                                                    .trim()
                                                    .isNotEmpty)
                                            .join(', '),
                                        style: GoogleFonts.poppins(
                                            color: Colors.white70,
                                            fontSize: 12),
                                        overflow: TextOverflow.ellipsis)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 11,
                      top: 11,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 6),
                        decoration: BoxDecoration(
                          color: index < 3
                              ? const Color(0xFFF2BE43)
                              : Colors.black.withValues(alpha: .62),
                          borderRadius: BorderRadius.circular(99),
                          boxShadow: const [
                            BoxShadow(color: Color(0x24000000), blurRadius: 7)
                          ],
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(
                            index < 3
                                ? Icons.emoji_events_rounded
                                : Icons.workspace_premium_rounded,
                            color: index < 3
                                ? const Color(0xFF553D08)
                                : Colors.white,
                            size: 13,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '#${index + 1} • ${(item['badgeClaimCount'] as num?)?.toInt() ?? 0} badges',
                            style: GoogleFonts.poppins(
                              color: index < 3
                                  ? const Color(0xFF553D08)
                                  : Colors.white,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ]),
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

  // Used for both Recommendations AND Search Results
  Widget _buildGridList(List<dynamic> items) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 40.0),
        child: Center(
            child: Column(
          children: [
            Icon(Icons.search_off_rounded, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text("No places found.",
                style:
                    GoogleFonts.poppins(color: Colors.grey[500], fontSize: 16)),
          ],
        )),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.78,
      ),
      itemBuilder: (context, index) {
        final item = items[index];

        String distanceText = [item['barangay'], item['municipality']]
            .where((part) => part != null && part.toString().trim().isNotEmpty)
            .join(', ');
        if (distanceText.isEmpty) distanceText = "Cavite";
        if (_currentPosition != null &&
            item['latitude'] != null &&
            item['longitude'] != null) {
          double distanceInMeters = Geolocator.distanceBetween(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
              (item['latitude'] as num).toDouble(),
              (item['longitude'] as num).toDouble());
          distanceText = distanceInMeters < 1000
              ? "${distanceInMeters.toStringAsFixed(0)} m away"
              : "${(distanceInMeters / 1000).toStringAsFixed(1)} km away";
        }

        return GestureDetector(
          onTap: () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => PlaceDetailsScreen(
                        place: item, userPosition: _currentPosition)));
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4))
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20)),
                    child: item['images'] != null &&
                            (item['images'] as List).isNotEmpty
                        ? _ResilientLandmarkImage(
                            source: item['images'][0],
                          )
                        : Container(color: Colors.grey[200]),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['name'] ?? "Unknown",
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: const Color(0xFF1A1A1A)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                              _currentPosition != null
                                  ? Icons.near_me
                                  : Icons.location_city,
                              color: Colors.blueAccent,
                              size: 12),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              distanceText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                  color: Colors.grey[500], fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFloatingBottomNav() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12, left: 18, right: 18),
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 10))
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _navIcon(Icons.home_rounded, true, 'Home'),
          GestureDetector(
            onTap: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => const MapScreen()));
            },
            child: _navIcon(Icons.map_outlined, false, 'Explore map'),
          ),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const VisitedPlacesScreen(),
              ),
            ),
            child: _navIcon(Icons.auto_stories_rounded, false, 'My journey'),
          ),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const BadgeCollectionScreen(),
              ),
            ),
            child: _navIcon(
                Icons.workspace_premium_outlined, false, 'Badge collection'),
          ),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const PartnersScreen(),
              ),
            ),
            child: _navIcon(Icons.local_offer_rounded, false, 'Rewards'),
          ),
        ],
      ),
    );
  }

  Widget _navIcon(IconData icon, bool isActive, String label) {
    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        button: true,
        selected: isActive,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding:
              EdgeInsets.symmetric(horizontal: isActive ? 12 : 8, vertical: 8),
          decoration: BoxDecoration(
              color: isActive
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(24)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon,
                color: isActive ? Colors.white : Colors.white60, size: 21),
            if (isActive) ...[
              const SizedBox(width: 6),
              Text(label,
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700)),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _buildRankedList(List<dynamic> items) {
    if (items.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(18)),
        child: Text(
            'Ratings will appear after verified visitors share their experience.',
            textAlign: TextAlign.center,
            style:
                GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 11)),
      );
    }
    return SizedBox(
      height: 118,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final item = items[index];
          final images =
              item['images'] is List ? item['images'] as List : const [];
          final rating = (item['averageRating'] as num?)?.toDouble() ?? 0;
          final reviews = (item['reviewCount'] as num?)?.toInt() ?? 0;
          return InkWell(
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => PlaceDetailsScreen(
                        place: item, userPosition: _currentPosition))),
            borderRadius: BorderRadius.circular(19),
            child: Container(
              width: 286,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(19),
                  border: Border.all(color: const Color(0xFFE6EAE6)),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0x10000000),
                        blurRadius: 12,
                        offset: Offset(0, 5))
                  ]),
              child: Row(children: [
                Stack(clipBehavior: Clip.none, children: [
                  ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                          width: 88,
                          height: 96,
                          child: images.isNotEmpty
                              ? _ResilientLandmarkImage(source: images.first)
                              : Container(color: Colors.grey.shade200))),
                  Positioned(
                      left: -7,
                      top: -7,
                      child: Container(
                          width: 31,
                          height: 31,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                              color: index < 3
                                  ? const Color(0xFFF4BE3F)
                                  : const Color(0xFF176A50),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: const [
                                BoxShadow(
                                    color: Color(0x22000000), blurRadius: 5)
                              ]),
                          child: Text('${index + 1}',
                              style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800)))),
                ]),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                      Text(item['name']?.toString() ?? 'Landmark',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                              fontSize: 12.5,
                              height: 1.25,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 7),
                      Row(children: [
                        const Icon(Icons.star_rounded,
                            color: Color(0xFFF0A928), size: 17),
                        const SizedBox(width: 3),
                        Text(rating.toStringAsFixed(1),
                            style: GoogleFonts.poppins(
                                fontSize: 11, fontWeight: FontWeight.w700)),
                        Text('  ($reviews ratings)',
                            style: GoogleFonts.poppins(
                                fontSize: 9.5, color: Colors.grey.shade600))
                      ]),
                      const SizedBox(height: 4),
                      Text('#${index + 1} visitor ranking',
                          style: GoogleFonts.poppins(
                              fontSize: 9.5,
                              color: const Color(0xFF176A50),
                              fontWeight: FontWeight.w600)),
                    ])),
              ]),
            ),
          );
        },
      ),
    );
  }
}

class AutoSlidingImages extends StatefulWidget {
  final List<dynamic> images;
  const AutoSlidingImages({super.key, required this.images});

  @override
  State<AutoSlidingImages> createState() => _AutoSlidingImagesState();
}

class _AutoSlidingImagesState extends State<AutoSlidingImages> {
  late PageController _pageController;
  Timer? _timer;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    if (widget.images.length > 1) {
      final int randomDelay = 3000 + Random().nextInt(2000);
      _timer =
          Timer.periodic(Duration(milliseconds: randomDelay), (Timer timer) {
        if (!mounted) return;
        if (_currentPage < widget.images.length - 1) {
          _currentPage++;
          if (_pageController.hasClients) {
            _pageController.animateToPage(_currentPage,
                duration: const Duration(milliseconds: 800),
                curve: Curves.fastOutSlowIn);
          }
        } else {
          _currentPage = 0;
          if (_pageController.hasClients) _pageController.jumpToPage(0);
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) return Container(color: Colors.grey[300]);
    if (widget.images.length == 1) {
      return _ResilientLandmarkImage(source: widget.images[0]);
    }

    return PageView.builder(
      controller: _pageController,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: widget.images.length,
      itemBuilder: (context, index) {
        return _ResilientLandmarkImage(source: widget.images[index]);
      },
    );
  }
}

class _ResilientLandmarkImage extends StatefulWidget {
  final dynamic source;

  const _ResilientLandmarkImage({required this.source});

  @override
  State<_ResilientLandmarkImage> createState() =>
      _ResilientLandmarkImageState();
}

class _ResilientLandmarkImageState extends State<_ResilientLandmarkImage> {
  Timer? _retryTimer;
  int _attempt = 0;
  bool _retryScheduled = false;

  @override
  void didUpdateWidget(covariant _ResilientLandmarkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) {
      _retryTimer?.cancel();
      _attempt = 0;
      _retryScheduled = false;
    }
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }

  void _scheduleRetry() {
    if (_retryScheduled || _attempt >= 2) return;
    _retryScheduled = true;
    _retryTimer = Timer(Duration(milliseconds: 700 + (_attempt * 900)), () {
      if (!mounted) return;
      setState(() {
        _attempt++;
        _retryScheduled = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final baseUrl = ApiService.assetUrl(widget.source);
    final parsed = Uri.tryParse(baseUrl);
    final imageUrl = _attempt == 0 || parsed == null
        ? baseUrl
        : parsed.replace(queryParameters: {
            ...parsed.queryParameters,
            'retry': _attempt.toString(),
          }).toString();
    return Image.network(
      imageUrl,
      key: ValueKey(imageUrl),
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      cacheWidth: 900,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : _imagePlaceholder(loading: true),
      errorBuilder: (context, error, stackTrace) {
        _scheduleRetry();
        return _imagePlaceholder(loading: _attempt < 2);
      },
    );
  }

  Widget _imagePlaceholder({required bool loading}) {
    return ColoredBox(
      color: const Color(0xFFE9EFEA),
      child: Center(
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Color(0xFF176A50),
                ),
              )
            : const Icon(
                Icons.landscape_rounded,
                color: Color(0xFF7B9188),
                size: 34,
              ),
      ),
    );
  }
}
