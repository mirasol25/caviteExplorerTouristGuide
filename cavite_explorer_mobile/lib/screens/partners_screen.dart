import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'map_preview_screen.dart';

class PartnersScreen extends StatefulWidget {
  const PartnersScreen({super.key});

  @override
  State<PartnersScreen> createState() => _PartnersScreenState();
}

class _PartnersScreenState extends State<PartnersScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _partners = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final user = await AuthService.getUser();
      final body = await ApiService.getPartners(user?['token']?.toString() ?? '');
      _partners = body
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

  void _open(Map<String, dynamic> partner) {
    final offers = (partner['offers'] as List?) ?? const [];
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: .68,
        minChildSize: .48,
        maxChildSize: .9,
        expand: false,
        builder: (_, controller) => Container(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
          decoration: const BoxDecoration(
            color: Color(0xFFF9F8F4),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: ListView(controller: controller, children: [
            Center(
                child: Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(8)))),
            const SizedBox(height: 20),
            Row(children: [
              _PartnerLogo(partner: partner, size: 66, radius: 18),
              const SizedBox(width: 13),
              Expanded(
                child: Text(partner['name']?.toString() ?? 'Partner',
                    style: GoogleFonts.poppins(
                        fontSize: 23, fontWeight: FontWeight.w700)),
              ),
            ]),
            const SizedBox(height: 5),
            Text(
              [partner['barangay'], partner['municipality']]
                  .where((item) => item?.toString().isNotEmpty == true)
                  .join(', '),
              style: GoogleFonts.poppins(
                  fontSize: 12, color: Colors.grey.shade600),
            ),
            if (partner['description']?.toString().isNotEmpty == true) ...[
              const SizedBox(height: 18),
              Text(partner['description'].toString(),
                  style: GoogleFonts.poppins(fontSize: 12, height: 1.55)),
            ],
            const SizedBox(height: 20),
            Text('Available badge rewards',
                style: GoogleFonts.poppins(
                    fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 9),
            if (offers.isEmpty)
              Text('No active rewards right now.',
                  style: GoogleFonts.poppins(color: Colors.grey))
            else
              ...offers.whereType<Map>().map((offer) => Container(
                    margin: const EdgeInsets.only(bottom: 9),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: const Color(0xFFE5F2E9),
                        borderRadius: BorderRadius.circular(16)),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(offer['discountLabel']?.toString() ?? 'Reward',
                              style: GoogleFonts.poppins(
                                  color: const Color(0xFF176A50),
                                  fontWeight: FontWeight.w800)),
                          Text(offer['title']?.toString() ?? '',
                              style: GoogleFonts.poppins(
                                  fontSize: 12, fontWeight: FontWeight.w600)),
                          if (offer['badgeLandmark'] is Map)
                            Text(
                                'Requires ${(offer['badgeLandmark'] as Map)['badgeName'] ?? (offer['badgeLandmark'] as Map)['name']}',
                                style: GoogleFonts.poppins(
                                    fontSize: 9.5,
                                    color: Colors.grey.shade600)),
                        ]),
                  )),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: partner['latitude'] == null
                  ? null
                  : () {
                      Navigator.pop(sheetContext);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MapPreviewScreen(place: {
                            'id': 'partner-${partner['id']}',
                            'name': partner['name'],
                            'description': partner['description'] ?? '',
                            'municipality': partner['municipality'],
                            'barangay': partner['barangay'],
                            'latitude': partner['latitude'],
                            'longitude': partner['longitude'],
                            'images': partner['image'] == null
                                ? []
                                : [partner['image']],
                            'category': 'Partner',
                          }),
                        ),
                      );
                    },
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF176A50),
                  padding: const EdgeInsets.symmetric(vertical: 15)),
              icon: const Icon(Icons.directions_transit_rounded),
              label: const Text('Commute to this partner'),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFF7F7F4),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF7F7F4),
          surfaceTintColor: Colors.transparent,
          title: Text('Partner rewards',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                                colors: [Color(0xFF123F33), Color(0xFF176A50)]),
                            borderRadius: BorderRadius.circular(23),
                          ),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.local_offer_rounded,
                                    color: Color(0xFFD8F270), size: 32),
                                const SizedBox(height: 10),
                                Text('Explore more. Enjoy local rewards.',
                                    style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700)),
                                Text(
                                    'Collect landmark badges, then present their QR codes at participating businesses.',
                                    style: GoogleFonts.poppins(
                                        color: Colors.white70,
                                        fontSize: 10.5,
                                        height: 1.45)),
                              ]),
                        ),
                        const SizedBox(height: 18),
                        ..._partners.map((partner) => InkWell(
                              onTap: () => _open(partner),
                              borderRadius: BorderRadius.circular(19),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 11),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(19),
                                    border: Border.all(
                                        color: const Color(0xFFDDE5E0))),
                                child: Row(children: [
                                  _PartnerLogo(partner: partner),
                                  const SizedBox(width: 12),
                                  Expanded(
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                        Text(partner['name']?.toString() ?? '',
                                            style: GoogleFonts.poppins(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700)),
                                        Text(
                                            partner['category']?.toString() ??
                                                '',
                                            style: GoogleFonts.poppins(
                                                color: const Color(0xFF176A50),
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600)),
                                        Text(
                                            '${(partner['offers'] as List?)?.length ?? 0} active rewards',
                                            style: GoogleFonts.poppins(
                                                color: Colors.grey.shade600,
                                                fontSize: 9.5)),
                                      ])),
                                  const Icon(Icons.chevron_right_rounded),
                                ]),
                              ),
                            )),
                      ],
                    ),
                  ),
      );
}

class _PartnerLogo extends StatelessWidget {
  final Map<String, dynamic> partner;
  final double size;
  final double radius;

  const _PartnerLogo({
    required this.partner,
    this.size = 52,
    this.radius = 15,
  });

  @override
  Widget build(BuildContext context) {
    final image = partner['image']?.toString() ?? '';
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFE8F1EA),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: const Color(0xFFD6E4DB)),
      ),
      child: image.isEmpty
          ? const Icon(Icons.storefront_rounded, color: Color(0xFF176A50))
          : Image.network(
              ApiService.assetUrl(image),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(Icons.storefront_rounded,
                  color: Color(0xFF176A50)),
            ),
    );
  }
}
