import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'dart:math';

import '../services/api_service.dart';
import '../services/location_service.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
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
      ..._allLandmarks.map((e) => e['municipality'].toString()).toSet().toList()
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
    final popularItems =
        _allLandmarks.where((l) => l['category'] == 'Popular').toList();
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
                  SingleChildScrollView(
                    padding:
                        const EdgeInsets.only(left: 20, right: 20, bottom: 100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),
                        _buildHeader(context),
                        const SizedBox(height: 25),
                        _buildSearchBar(),
                        const SizedBox(height: 30),

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

                          const SizedBox(height: 35),
                          _sectionHeader("Learn & Play", ""),
                          const SizedBox(height: 15),
                          _buildFeaturedCard(),

                          const SizedBox(height: 35),
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ClipOval(
          child: Container(
            width: 52,
            height: 52,
            color: Colors.white,
            padding: const EdgeInsets.all(3),
            child: Image.asset(
              'assets/images/cavite-explorer-logo.png',
              fit: BoxFit.contain,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Explore",
                style: GoogleFonts.poppins(
                    color: Colors.grey[500],
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.5,
                    height: 1.0)),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text("Cavite",
                      style: GoogleFonts.poppins(
                          color: const Color(0xFF1A1A1A),
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1.0)),
                  const SizedBox(width: 4),
                  const Icon(Icons.location_on,
                      color: Colors.blueAccent, size: 28),
                ],
              ),
            ),
          ],
        )),
        const SizedBox(width: 8),
        if (_isLoadingUser)
          const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.black54))
        else if (_userName != null)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 82),
            child: Text(_userName!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: const Color(0xFF1A1A1A))),
          )
        else
          TextButton(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (context) => const LoginScreen())),
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFF1A1A1A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              elevation: 4,
              shadowColor: Colors.black.withValues(alpha: 0.2),
            ),
            child: Text("Sign In",
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, fontSize: 14)),
          ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
              print("$actionText clicked");
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
    if (items.isEmpty)
      return Text("No popular landmarks.", style: GoogleFonts.poppins());

    return SizedBox(
      height: 260,
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
              width: 180,
              margin: const EdgeInsets.only(right: 20, bottom: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: Colors.grey[300],
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 6))
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
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
                                  fontSize: 16,
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
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFeaturedCard() {
    return Container(
      width: double.infinity,
      height: 160,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
            colors: [Color(0xFF2C3E50), Color(0xFF3498DB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF3498DB).withValues(alpha: 0.3),
              blurRadius: 15,
              offset: const Offset(0, 8))
        ],
      ),
      child: Stack(
        children: [
          Positioned(
              right: -20,
              bottom: -20,
              child: Icon(Icons.explore,
                  size: 120, color: Colors.white.withValues(alpha: 0.1))),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("Historical Minigame",
                    style: GoogleFonts.poppins(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2)),
                const SizedBox(height: 8),
                Text("Find The Hidden\nArtifacts",
                    style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        height: 1.2)),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20)),
                  child: Text("Play Now",
                      style: GoogleFonts.poppins(
                          color: const Color(0xFF2C3E50),
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                )
              ],
            ),
          ),
        ],
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
        childAspectRatio: 0.85,
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
                        ? Image.network(ApiService.assetUrl(item['images'][0]),
                            fit: BoxFit.cover, width: double.infinity)
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
      margin: const EdgeInsets.only(bottom: 20, left: 30, right: 30),
      padding: const EdgeInsets.symmetric(vertical: 15),
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
          _navIcon(Icons.home_rounded, true),
          GestureDetector(
            onTap: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => const MapScreen()));
            },
            child: _navIcon(Icons.map_outlined, false),
          ),
          _navIcon(Icons.bookmark_border_rounded, false),
          GestureDetector(
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (context) => const ProfileScreen())),
            child: _navIcon(Icons.person_outline_rounded, false),
          ),
        ],
      ),
    );
  }

  Widget _navIcon(IconData icon, bool isActive) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: EdgeInsets.all(isActive ? 12 : 8),
      decoration: BoxDecoration(
          color: isActive
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.transparent,
          shape: BoxShape.circle),
      child:
          Icon(icon, color: isActive ? Colors.white : Colors.white54, size: 26),
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
    if (widget.images.length == 1)
      return Image.network(ApiService.assetUrl(widget.images[0]),
          fit: BoxFit.cover, width: double.infinity, height: double.infinity);

    return PageView.builder(
      controller: _pageController,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: widget.images.length,
      itemBuilder: (context, index) {
        return Image.network(ApiService.assetUrl(widget.images[index]),
            fit: BoxFit.cover, width: double.infinity, height: double.infinity);
      },
    );
  }
}
