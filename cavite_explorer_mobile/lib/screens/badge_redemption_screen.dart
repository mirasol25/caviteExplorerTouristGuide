import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'map_preview_screen.dart';

class BadgeRedemptionScreen extends StatefulWidget {
  final String userBadgeId;

  const BadgeRedemptionScreen({super.key, required this.userBadgeId});

  @override
  State<BadgeRedemptionScreen> createState() => _BadgeRedemptionScreenState();
}

class _BadgeRedemptionScreenState extends State<BadgeRedemptionScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final user = await AuthService.getUser();
      final response = await http.get(
        ApiService.uri('/rewards/badges/${widget.userBadgeId}'),
        headers: {'Authorization': 'Bearer ${user?['token'] ?? ''}'},
      );
      final body = json.decode(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(body['message'] ?? 'Could not load badge rewards.');
      }
      _data = Map<String, dynamic>.from(body);
      _error = null;
    } catch (error) {
      _error = error.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _commuteTo(Map<String, dynamic> partner) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MapPreviewScreen(
          place: {
            'id': 'partner-${partner['id']}',
            'name': partner['name'],
            'description': partner['description'] ??
                'Cavite Explorer partner offering badge-holder rewards.',
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

  @override
  Widget build(BuildContext context) {
    final badge = _data?['badge'] is Map
        ? Map<String, dynamic>.from(_data!['badge'])
        : <String, dynamic>{};
    final partners = ((_data?['partners'] as List?) ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    return Scaffold(
      backgroundColor: const Color(0xFFF6F3EC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F3EC),
        surfaceTintColor: Colors.transparent,
        title: Text('Badge rewards',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, textAlign: TextAlign.center))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 34),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF173F34),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(children: [
                          Container(
                              width: 43,
                              height: 43,
                              decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: .12),
                                  borderRadius: BorderRadius.circular(13)),
                              child: const Icon(Icons.qr_code_2_rounded,
                                  color: Color(0xFFF1D27B))),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text('Show this badge at checkout',
                                    style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700)),
                                const SizedBox(height: 2),
                                Text(
                                    'The partner will scan the live QR to apply your discount.',
                                    style: GoogleFonts.poppins(
                                        color: Colors.white70, fontSize: 10.5)),
                              ])),
                        ]),
                      ),
                      const SizedBox(height: 18),
                      _BadgeBack(
                        name: badge['name']?.toString() ?? 'Explorer Badge',
                        uniqueId: badge['uniqueId']?.toString() ?? '',
                        credential: _data?['credential']?.toString() ?? '',
                      ),
                      const SizedBox(height: 22),
                      Text('Partners within 2.5 km',
                          style: GoogleFonts.poppins(
                              fontSize: 19, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(
                        'Each partner reward can be claimed once with this badge.',
                        style: GoogleFonts.poppins(
                            fontSize: 11, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 13),
                      if (partners.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20)),
                          child: Text(
                            'No approved participating partners are currently available within 2.5 km of this landmark.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                                fontSize: 12, color: Colors.grey.shade600),
                          ),
                        )
                      else
                        ...partners.map((partner) {
                          final offers =
                              (partner['offers'] as List?) ?? const [];
                          final offer = offers.isNotEmpty && offers.first is Map
                              ? Map<String, dynamic>.from(offers.first)
                              : <String, dynamic>{};
                          final claimed = partner['claimed'] == true;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 11),
                            padding: const EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              color: claimed
                                  ? const Color(0xFFE4F2E8)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(19),
                              border: Border.all(
                                  color: claimed
                                      ? const Color(0xFF87C29D)
                                      : const Color(0xFFE1E3DE)),
                            ),
                            child: Row(children: [
                              Container(
                                width: 48,
                                height: 48,
                                clipBehavior: Clip.antiAlias,
                                decoration: BoxDecoration(
                                  color: claimed
                                      ? const Color(0xFF176A50)
                                      : const Color(0xFFF0E6CC),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: partner['image']
                                            ?.toString()
                                            .isNotEmpty ==
                                        true
                                    ? Stack(fit: StackFit.expand, children: [
                                        Image.network(
                                          ApiService.assetUrl(partner['image']),
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              const Icon(
                                                  Icons.storefront_rounded,
                                                  color: Color(0xFF8B6728)),
                                        ),
                                        if (claimed)
                                          Container(
                                            color: const Color(0x99176A50),
                                            child: const Icon(
                                                Icons.check_rounded,
                                                color: Colors.white),
                                          ),
                                      ])
                                    : Icon(
                                        claimed
                                            ? Icons.check_rounded
                                            : Icons.storefront_rounded,
                                        color: claimed
                                            ? Colors.white
                                            : const Color(0xFF8B6728),
                                      ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        partner['name']?.toString() ??
                                            'Partner',
                                        style: GoogleFonts.poppins(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 3),
                                    Text(
                                      claimed
                                          ? 'Reward already claimed'
                                          : offer['discountLabel']
                                                  ?.toString() ??
                                              'Badge-holder reward',
                                      style: GoogleFonts.poppins(
                                          fontSize: 10.5,
                                          color: claimed
                                              ? const Color(0xFF176A50)
                                              : const Color(0xFF9A6D19),
                                          fontWeight: FontWeight.w600),
                                    ),
                                    Text(
                                      '${partner['distanceMeters'] ?? 0} m from the landmark',
                                      style: GoogleFonts.poppins(
                                          fontSize: 9.5,
                                          color: Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Commute to partner',
                                onPressed: partner['latitude'] == null
                                    ? null
                                    : () => _commuteTo(partner),
                                icon: const Icon(Icons.directions_rounded,
                                    color: Color(0xFF176A50)),
                              ),
                            ]),
                          );
                        }),
                    ],
                  ),
                ),
    );
  }
}

class _BadgeBack extends StatelessWidget {
  final String name;
  final String uniqueId;
  final String credential;

  const _BadgeBack({
    required this.name,
    required this.uniqueId,
    required this.credential,
  });

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFDF8),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: const Color(0xFFE7DFC9)),
          boxShadow: const [
            BoxShadow(
                color: Color(0x16705A2B), blurRadius: 24, offset: Offset(0, 10))
          ],
        ),
        child: Column(children: [
          Text('OFFICIAL CAVITE EXPLORER BADGE',
              style: GoogleFonts.poppins(
                  color: const Color(0xFF8B6728),
                  fontSize: 9,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 330),
            child: AspectRatio(
              aspectRatio: 1,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final qrSize = constraints.maxWidth * .335;
                  return Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x4A5A421C),
                          blurRadius: 24,
                          offset: Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.asset(
                          'assets/images/badge-qr-template.png',
                          fit: BoxFit.contain,
                          alignment: Alignment.center,
                          filterQuality: FilterQuality.high,
                        ),
                        Align(
                          alignment: const Alignment(0, -0.015),
                          child: Container(
                            width: qrSize,
                            height: qrSize,
                            padding: EdgeInsets.all(qrSize * .06),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFEF9),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(
                                color: const Color(0xFF5A421C),
                                width: 1.5,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                    color: Color(0x44301E08),
                                    blurRadius: 5,
                                    offset: Offset(0, 2)),
                              ],
                            ),
                            child: QrImageView(
                              data: credential,
                              padding: EdgeInsets.zero,
                              backgroundColor: const Color(0xFFFFFEF9),
                              eyeStyle: const QrEyeStyle(
                                eyeShape: QrEyeShape.square,
                                color: Color(0xFF21180B),
                              ),
                              dataModuleStyle: const QrDataModuleStyle(
                                dataModuleShape: QrDataModuleShape.square,
                                color: Color(0xFF21180B),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            name,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: const Color(0xFF20251F),
              fontSize: 18,
              height: 1.25,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text('Present this rotating QR to a participating partner',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: Colors.black45, fontSize: 10)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFEDE8DB),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'ID ${uniqueId.toUpperCase()}',
              textAlign: TextAlign.center,
              style: GoogleFonts.robotoMono(
                color: const Color(0xFF685D47),
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ]),
      );
}
