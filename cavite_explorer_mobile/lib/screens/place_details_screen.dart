import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import '../screens/map_preview_screen.dart';
import '../services/api_service.dart';

class PlaceDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> place;
  final Position? userPosition;

  const PlaceDetailsScreen({super.key, required this.place, this.userPosition});

  @override
  State<PlaceDetailsScreen> createState() => _PlaceDetailsScreenState();
}

class _PlaceDetailsScreenState extends State<PlaceDetailsScreen> {
  int _currentImageIndex = 0;
  int _detailSection = 0;
  final PageController _imagePageController = PageController();
  Timer? _imageSlider;

  @override
  void initState() {
    super.initState();
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

  @override
  void dispose() {
    _imageSlider?.cancel();
    _imagePageController.dispose();
    super.dispose();
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
                    return Image.network(
                        ApiService.assetUrl(
                            images.isEmpty ? fallbackImage : images[index]),
                        fit: BoxFit.cover,
                        width: double.infinity);
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
                      const SizedBox(height: 32),
                      Text("Learn more about $name",
                          style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.black87,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      _buildMinigameCard(
                          name, images.isNotEmpty ? images[0] : fallbackImage),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => MapPreviewScreen(
                                  place: widget.place,
                                  userPosition: widget.userPosition,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.map_outlined,
                              color: Colors.white),
                          label: Text("View on map",
                              style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              elevation: 0),
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
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2))
                    ]),
                child: const Icon(Icons.arrow_back,
                    color: Colors.black87, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _text(dynamic value) => value?.toString().trim() ?? '';

  List<String> _list(dynamic value) {
    if (value is! List) return const [];
    return value
        .map((item) => _text(item))
        .where((item) => item.isNotEmpty)
        .toList();
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

  Widget _buildDetailTabs({
    required bool hasVisit,
    required bool hasHistory,
    required bool hasReminders,
  }) {
    final tabs = <({int index, String label})>[
      (index: 0, label: 'Overview'),
      if (hasVisit) (index: 1, label: 'Plan visit'),
      if (hasHistory) (index: 2, label: 'History'),
      if (hasReminders) (index: 3, label: 'Reminders'),
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE7EDE7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: tabs.map((tab) {
            final selected = _detailSection == tab.index;
            return Padding(
              padding: const EdgeInsets.only(right: 3),
              child: InkWell(
                borderRadius: BorderRadius.circular(9),
                onTap: () => setState(() => _detailSection = tab.index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color:
                        selected ? const Color(0xFF176A50) : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(tab.label,
                      style: GoogleFonts.poppins(
                          fontSize: 11,
                          color:
                              selected ? Colors.white : const Color(0xFF5B7064),
                          fontWeight: FontWeight.w700)),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
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
