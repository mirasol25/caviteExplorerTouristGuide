import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart'; 
import 'package:url_launcher/url_launcher.dart';

// Import your AuthService to get the token!
import '../services/auth_service.dart';
import 'live_trip_screen.dart';

class SavedTripsScreen extends StatefulWidget {
  const SavedTripsScreen({super.key});

  @override
  State<SavedTripsScreen> createState() => _SavedTripsScreenState();
}

class _SavedTripsScreenState extends State<SavedTripsScreen> {
  bool _isLoading = true;
  List<dynamic> _savedTrips = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchSavedTrips();
  }

  Future<void> _fetchSavedTrips() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userData = await AuthService.getUser();
      final token = userData?['token'];

      if (token == null || token.isEmpty) {
        setState(() {
          _errorMessage = "Please log in to view your saved trips.";
          _isLoading = false;
        });
        return;
      }

      final url = Uri.parse('http://10.0.2.2:3000/trips');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _savedTrips = data;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = "Failed to load trips. Please try again later.";
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Network error. Check your connection.";
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteTrip(String tripId, int index) async {
    // Optimistically remove from list
    final deletedTrip = _savedTrips.removeAt(index);
    setState(() {});

    try {
      final userData = await AuthService.getUser();
      final token = userData?['token'];
      
      final response = await http.delete(
        Uri.parse('http://10.0.2.2:3000/trips/$tripId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode != 200) {
        // If delete failed, put it back
        setState(() => _savedTrips.insert(index, deletedTrip));
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to delete trip.")));
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Trip deleted.")));
      }
    } catch (e) {
      setState(() => _savedTrips.insert(index, deletedTrip));
    }
  }

  String _formatDate(String isoString) {
    DateTime date = DateTime.parse(isoString);
    return DateFormat('MMM dd, yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F7F2),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: Text("My Saved Trips", style: GoogleFonts.poppins(color: Colors.black87, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
        : _errorMessage != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                  const SizedBox(height: 16),
                  Text(_errorMessage!, style: GoogleFonts.poppins(color: Colors.black87)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _fetchSavedTrips,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                    child: Text("Retry", style: GoogleFonts.poppins(color: Colors.white)),
                  )
                ],
              ),
            )
          : _savedTrips.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.map_outlined, size: 80, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    Text("No trips saved yet.", style: GoogleFonts.poppins(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text("Explore landmarks and use AI to plan your day!", style: GoogleFonts.poppins(color: Colors.grey[500])),
                  ],
                ),
              )
            : RefreshIndicator(
                onRefresh: _fetchSavedTrips,
                child: ListView.builder(
                  padding: const EdgeInsets.all(24),
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: _savedTrips.length,
                  itemBuilder: (context, index) {
                    final trip = _savedTrips[index];
                    final landmarkInfo = trip['landmark']; // Passed from NestJS include block!
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => SavedTripDetailScreen(tripData: trip)),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        trip['title'] ?? "Trip Plan", 
                                        style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                                        maxLines: 1, overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () => _deleteTrip(trip['id'], index),
                                    )
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.location_on, size: 14, color: Colors.blueAccent),
                                    const SizedBox(width: 4),
                                    Text(
                                      landmarkInfo != null ? "${landmarkInfo['name']}, ${landmarkInfo['municipality']}" : "Destination", 
                                      style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.directions_walk, size: 14, color: Colors.orange),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        "From: ${trip['startAddress']}", 
                                        style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
                                        maxLines: 1, overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                      child: Text("${(trip['itinerary'] as List).length} Stops", style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blueAccent)),
                                    ),
                                    Text(
                                      "Saved on ${_formatDate(trip['addedAt'])}", 
                                      style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[400])
                                    ),
                                  ],
                                )
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
    );
  }
}

// =========================================================================
// READ-ONLY DETAIL SCREEN (Displays the saved JSON exactly like the AI did)
// =========================================================================

class SavedTripDetailScreen extends StatelessWidget {
  final Map<String, dynamic> tripData;

  const SavedTripDetailScreen({super.key, required this.tripData});

  Future<void> _openStepInMaps(BuildContext context, String query) async {
    if (query == 'none' || query.isEmpty) return;
    
    final Uri url = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not open Google Maps.")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error launching maps.")));
    }
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'transit': return Icons.directions_bus;
      case 'arrive': return Icons.location_on;
      case 'food': return Icons.restaurant;
      case 'explore': return Icons.local_see;
      case 'coffee': return Icons.local_cafe;
      default: return Icons.schedule;
    }
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'transit': return Colors.blueAccent;
      case 'arrive': return Colors.redAccent;
      case 'food': return Colors.orange;
      case 'explore': return Colors.green;
      case 'coffee': return Colors.brown;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<dynamic> itinerary = tripData['itinerary'] ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFFF9F7F2),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(left: 24, right: 24, top: 8, bottom: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tripData['title'] ?? "Your Trip", style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.bold, color: const Color(0xFF1A1A1A), height: 1.2)),
            const SizedBox(height: 8),
            Text("Starting from: ${tripData['startAddress']}", style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w500)),
            if ((tripData['commuteGuide'] as List?)?.isNotEmpty == true) ...[
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LiveTripScreen(trip: tripData))),
                  icon: const Icon(Icons.navigation_outlined),
                  label: Text('Start live commute guide', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                ),
              ),
            ],
            const SizedBox(height: 32),
            
            // TIMELINE BUILDER
            ...itinerary.asMap().entries.map((entry) {
              int index = entry.key;
              var item = entry.value;
              bool isLast = index == itinerary.length - 1;
              bool hasMapLink = item['search_query'] != null && item['search_query'] != 'none';

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 80,
                    child: Text(
                      item['time'] ?? "", 
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey[800])
                    ),
                  ),
                  
                  Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _getColorForType(item['icon_type']).withOpacity(0.1),
                          shape: BoxShape.circle,
                          border: Border.all(color: _getColorForType(item['icon_type']), width: 2)
                        ),
                        child: Icon(_getIconForType(item['icon_type']), size: 16, color: _getColorForType(item['icon_type'])),
                      ),
                      if (!isLast)
                        Container(width: 2, height: 50, color: Colors.grey[300]),
                    ],
                  ),
                  const SizedBox(width: 16),
                  
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 24.0),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: hasMapLink ? () => _openStepInMaps(context, item['search_query']) : null,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: hasMapLink ? Colors.blueAccent.withOpacity(0.3) : Colors.grey[200]!),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))
                              ]
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    item['activity'] ?? "", 
                                    style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87, height: 1.5),
                                  ),
                                ),
                                if (hasMapLink) ...[
                                  const SizedBox(width: 12),
                                  const Padding(
                                    padding: EdgeInsets.only(top: 2.0),
                                    child: Icon(Icons.directions, size: 18, color: Colors.blueAccent),
                                  )
                                ]
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}
