import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

// 🚀 NEW: Imported your AuthService
import '../services/auth_service.dart';
import '../services/api_service.dart';
import 'live_trip_screen.dart';

class TripPlanScreen extends StatefulWidget {
  final String landmarkId; 
  final String destinationName;
  final String startAddress;
  final Map<String, List<String>> nearbyAmenities;
  final List<dynamic> commuteSteps;
  final List<dynamic> routeGeometry;

  const TripPlanScreen({
    super.key,
    required this.landmarkId, 
    required this.destinationName,
    required this.startAddress,
    required this.nearbyAmenities,
    this.commuteSteps = const [],
    this.routeGeometry = const [],
  });

  @override
  State<TripPlanScreen> createState() => _TripPlanScreenState();
}

class _TripPlanScreenState extends State<TripPlanScreen> {
  bool _isLoading = false;
  bool _startNow = false;
  DateTime _selectedDate = DateTime.now();
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  String _tripTitle = "Generating Trip Plan...";
  List<dynamic> _itinerary = [];
  
  bool _isSaved = false;

  @override
  void initState() {
    super.initState();
    final now = TimeOfDay.now();
    _startTime = now;
    _endTime = TimeOfDay(hour: (now.hour + 4) % 24, minute: now.minute);
  }

  DateTime _dateAt(TimeOfDay time) => DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, time.hour, time.minute);
  DateTime get _plannedStart => _startNow ? DateTime.now() : _dateAt(_startTime);
  DateTime get _plannedEnd {
    var end = _dateAt(_endTime);
    if (!end.isAfter(_plannedStart)) end = end.add(const Duration(days: 1));
    return end;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(context: context, initialTime: isStart ? _startTime : _endTime);
    if (picked != null) setState(() { if (isStart) _startTime = picked; else _endTime = picked; });
  }

  Future<void> _generateTripPlan() async {
    setState(() { _isLoading = true; _itinerary = []; });

    String cafes = widget.nearbyAmenities['cafe']?.join(", ") ?? "No specific cafes found";
    String restos = widget.nearbyAmenities['restaurant']?.join(", ") ?? "No specific restaurants found";

    final prompt = """
      You are a local Cavite, Philippines travel itinerary expert.
      The user wants to make a trip starting from: ${widget.startAddress}.
      The main destination is: ${widget.destinationName}.
      The selected time window is ${DateFormat('EEEE, MMMM d, yyyy h:mm a').format(_plannedStart)} until ${DateFormat('h:mm a').format(_plannedEnd)}.
      
      Here are establishments supplied by the app. They might be unavailable:
      - Nearby Restaurants/Fastfood: $restos
      - Nearby Cafes/Coffee Shops: $cafes
      
      Create a realistic itinerary that fits entirely inside the selected time window. Include travel and exploration, but do not assume a full-day trip. Use a supplied establishment only when its name is present. When none is supplied, use a generic activity such as "Choose a nearby restaurant"; never invent a business name, schedule, price, or opening hour.
      
      Return ONLY a JSON object exactly matching this structure:
      {
        "title": "A Day at ${widget.destinationName}",
        "itinerary": [
          {
            "time": "09:00 AM", 
            "activity": "Leave home from ${widget.startAddress}", 
            "icon_type": "transit",
            "search_query": "none"
          },
          {
            "time": "12:00 PM", 
            "activity": "Lunch at [Restaurant Name]", 
            "icon_type": "food",
            "search_query": "[Restaurant Name], ${widget.destinationName}"
          }
        ]
      }
      
      Rules for icon_type: Use ONLY "transit", "arrive", "food", "explore", or "coffee".
      Rules for search_query: If it's a specific place (food, coffee, explore, arrive), provide a highly searchable term for Google Maps. If it's general transit or leaving home, put "none".
    """;

    try {
      final token = (await AuthService.getUser())?['token'];
      if (token == null || token.isEmpty) throw Exception('Sign in to generate a trip');
      final response = await http.post(
        ApiService.uri('/assistant/generate'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'prompt': prompt}),
      );

      if (response.statusCode == 200) {
        final aiResult = json.decode(response.body);
        
        if (mounted) {
          setState(() {
            _tripTitle = aiResult['title'] ?? "Your Trip Plan";
            _itinerary = aiResult['itinerary'] ?? [];
            _isSaved = false; // Reset save state for new trip
            _isLoading = false;
          });
        }
      } else {
        debugPrint('AI trip request failed (${response.statusCode}): ${response.body}');
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("❌ AI Trip Error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- 💾 REAL SAVE TRIP LOGIC USING AUTH TOKEN ---
  Future<void> _toggleSaveTrip() async {
    // 1. Optimistically update UI so it feels instant
    setState(() {
      _isSaved = !_isSaved;
    });

    if (_isSaved) {
      try {
        // 🚀 NEW: Fetch the actual token from your AuthService
        final userData = await AuthService.getUser();
        final token = userData?['token'];

        if (token == null || token.isEmpty) {
          setState(() => _isSaved = false);
          _showSnackBar("You must be logged in to save trips.", Icons.lock_outline);
          return;
        }

        // 2. Send the data to your NestJS Backend
        final url = ApiService.uri('/trips/save');
        final response = await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token', // 🚀 Using the real token!
          },
          body: json.encode({
            "landmarkId": widget.landmarkId,
            "title": _tripTitle,
            "startAddress": widget.startAddress,
            "itinerary": _itinerary,
            "commuteGuide": widget.commuteSteps,
            "routeGeometry": widget.routeGeometry,
            "plannedStartAt": _plannedStart.toIso8601String(),
            "plannedEndAt": _plannedEnd.toIso8601String(),
            "tripMode": _startNow ? "NOW" : "SCHEDULED",
            "status": _startNow ? "ACTIVE" : "PLANNED",
          }),
        );

        if (response.statusCode == 201 || response.statusCode == 200) {
          // Success! Show confirmation
          _showSnackBar("Trip saved to your profile!", Icons.check_circle);
        } else {
          // Revert UI if the server rejected it
          setState(() => _isSaved = false);
          _showSnackBar("Failed to save trip to database.", Icons.error_outline);
          debugPrint("Backend Status Code: ${response.statusCode}");
          debugPrint("Backend Response: ${response.body}");
        }
      } catch (e) {
        // Revert UI on network error
        setState(() => _isSaved = false);
        _showSnackBar("Network error. Could not save.", Icons.wifi_off);
        debugPrint("Save Trip Error: $e");
      }
    } else {
      // NOTE: If you want to actually delete it from the database when they un-bookmark it, 
      // you would need to make a DELETE request to your backend here!
      _showSnackBar("Trip removed from saved.", Icons.info_outline);
    }
  }

  void _showSnackBar(String message, IconData icon) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message, 
                style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w500)
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.black87,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      )
    );
  }

  // --- 🗺️ OPEN IN GOOGLE MAPS ---
  Future<void> _openStepInMaps(String query) async {
    if (query == 'none' || query.isEmpty) return;
    
    final Uri url = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not open Google Maps.")));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error launching maps.")));
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

  Future<void> _startLiveTrip() async {
    try {
      final token = (await AuthService.getUser())?['token'];
      if (token == null || token.isEmpty) throw Exception('Sign in to start a trip');
      final response = await http.post(
        ApiService.uri('/trips/save'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: json.encode({
          'landmarkId': widget.landmarkId,
          'title': _tripTitle,
          'startAddress': widget.startAddress,
          'itinerary': _itinerary,
          'commuteGuide': widget.commuteSteps,
          'routeGeometry': widget.routeGeometry,
          'plannedStartAt': _plannedStart.toIso8601String(),
          'plannedEndAt': _plannedEnd.toIso8601String(),
          'tripMode': 'NOW',
          'status': 'ACTIVE',
        }),
      );
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Could not save this trip');
      }
      final trip = json.decode(response.body) as Map<String, dynamic>;
      if (!mounted) return;
      await Navigator.push(context, MaterialPageRoute(builder: (_) => LiveTripScreen(trip: trip)));
    } catch (e) {
      if (mounted) _showSnackBar(e.toString().replaceFirst('Exception: ', ''), Icons.error_outline);
    }
  }

  Widget _timeButton(String label, TimeOfDay time, VoidCallback onTap) {
    return Expanded(
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.schedule, size: 17),
        label: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[600])),
          Text(time.format(context), style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        ]),
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  Widget _buildPlanningForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Plan your visit', style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.bold, color: const Color(0xFF1A1A1A))),
        const SizedBox(height: 6),
        Text('Choose when you want to explore ${widget.destinationName}.', style: GoogleFonts.poppins(color: Colors.grey[600], height: 1.45)),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.blueAccent.withOpacity(.2))),
          child: Column(children: [
            SwitchListTile.adaptive(
              value: _startNow,
              contentPadding: EdgeInsets.zero,
              title: Text('Start trip now', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
              subtitle: Text('Use the current time for a live-ready itinerary.', style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[600])),
              onChanged: (value) => setState(() => _startNow = value),
            ),
            if (!_startNow) ...[
              const Divider(height: 24),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_month_outlined, color: Colors.blueAccent),
                title: Text('Date', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                subtitle: Text(DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate), style: GoogleFonts.poppins(fontSize: 12)),
                trailing: const Icon(Icons.chevron_right),
                onTap: _pickDate,
              ),
              const SizedBox(height: 10),
              Row(children: [
                _timeButton('Start time', _startTime, () => _pickTime(true)),
                const SizedBox(width: 12),
                _timeButton('Finish by', _endTime, () => _pickTime(false)),
              ]),
            ] else ...[
              const SizedBox(height: 8),
              _timeButton('Finish by', _endTime, () => _pickTime(false)),
            ],
          ]),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton.icon(
            onPressed: _generateTripPlan,
            icon: const Icon(Icons.auto_awesome),
            label: Text('Generate my trip', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          ),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F7F2),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: Text("Trip Plan", style: GoogleFonts.poppins(color: Colors.black87, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          if (!_isLoading && _itinerary.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: IconButton(
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                  child: Icon(
                    _isSaved ? Icons.bookmark : Icons.bookmark_border,
                    key: ValueKey(_isSaved),
                    color: _isSaved ? Colors.blueAccent : Colors.black87,
                    size: 28,
                  ),
                ),
                onPressed: _toggleSaveTrip,
              ),
            ),
        ],
      ),
      
      floatingActionButton: !_isLoading && _itinerary.isNotEmpty ? FloatingActionButton.extended(
        onPressed: () {
          setState(() {
            _isLoading = true;
            _itinerary.clear();
          });
          _generateTripPlan();
        },
        backgroundColor: Colors.black87,
        icon: const Icon(Icons.refresh, color: Colors.white),
        label: Text("Remix Trip", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
      ) : null,

      body: _isLoading 
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(color: Colors.blueAccent),
                const SizedBox(height: 16),
                Text("Crafting your perfect trip...", style: GoogleFonts.poppins(color: Colors.grey[700])),
              ],
            ),
          )
        : _itinerary.isEmpty
          ? _buildPlanningForm()
          : SingleChildScrollView(
              padding: const EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_tripTitle, style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFF1A1A1A), height: 1.2)),
                  const SizedBox(height: 8),
                  Text("AI-Generated Itinerary powered by Groq", style: GoogleFonts.poppins(fontSize: 12, color: Colors.blueAccent, fontWeight: FontWeight.w600)),
                  if (_startNow) ...[
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _startLiveTrip,
                        icon: const Icon(Icons.navigation_outlined),
                        label: Text('Start live commute guide', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  
                  // TIMELINE BUILDER
                  ..._itinerary.asMap().entries.map((entry) {
                    int index = entry.key;
                    var item = entry.value;
                    bool isLast = index == _itinerary.length - 1;
                    
                    bool hasMapLink = item['search_query'] != null && item['search_query'] != 'none';

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 80,
                          child: Text(
                            item['time'], 
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
                                onTap: hasMapLink ? () => _openStepInMaps(item['search_query']) : null,
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
                                          item['activity'], 
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
