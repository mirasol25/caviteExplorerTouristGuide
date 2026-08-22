import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';
import 'place_details_screen.dart';
import 'badge_redemption_screen.dart';

class BadgeCollectionScreen extends StatefulWidget {
  final String? highlightedLandmarkId;

  const BadgeCollectionScreen({
    super.key,
    this.highlightedLandmarkId,
  });

  @override
  State<BadgeCollectionScreen> createState() => _BadgeCollectionScreenState();
}

class _BadgeCollectionScreenState extends State<BadgeCollectionScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _badges = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final user = await AuthService.getUser();
      final token = user?['token']?.toString();
      if (token == null || token.isEmpty) {
        throw Exception('Sign in to view and earn landmark badges.');
      }
      final response = await http.get(
        ApiService.uri('/badges/me'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Could not load your badge collection.');
      }
      final body = json.decode(response.body) as Map<String, dynamic>;
      final collection = (body['collection'] as List?) ?? const [];
      _badges = collection
          .whereType<Map>()
          .map((value) => Map<String, dynamic>.from(value))
          .toList();
      final highlightedId = widget.highlightedLandmarkId;
      _badges.sort((a, b) {
        final aHighlighted = a['id']?.toString() == highlightedId;
        final bHighlighted = b['id']?.toString() == highlightedId;
        if (aHighlighted != bHighlighted) return aHighlighted ? -1 : 1;
        final aEarned = a['earned'] == true;
        final bEarned = b['earned'] == true;
        if (aEarned != bEarned) return aEarned ? -1 : 1;
        return (a['name']?.toString() ?? '')
            .compareTo(b['name']?.toString() ?? '');
      });
      _error = null;
    } catch (error) {
      _error = error.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final earned = _badges.where((badge) => badge['earned'] == true).length;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F4),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F7F4),
        surfaceTintColor: Colors.transparent,
        title: Text('Badge collection',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      const SizedBox(height: 110),
                      const Icon(Icons.workspace_premium_outlined,
                          size: 58, color: Colors.grey),
                      const SizedBox(height: 18),
                      Text(_error!,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins()),
                      const SizedBox(height: 18),
                      Center(
                        child: FilledButton(
                          onPressed: _load,
                          child: const Text('Try again'),
                        ),
                      ),
                    ],
                  )
                : CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: _CollectionHeader(
                          earned: earned,
                          total: _badges.length,
                        ),
                      ),
                      if (earned > 0)
                        const SliverToBoxAdapter(child: _BadgeQrHint()),
                      if (widget.highlightedLandmarkId != null)
                        SliverToBoxAdapter(
                          child: Container(
                            margin: const EdgeInsets.fromLTRB(18, 0, 18, 14),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 15, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE5F5EB),
                              borderRadius: BorderRadius.circular(16),
                              border:
                                  Border.all(color: const Color(0xFF9ACDB4)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.auto_awesome_rounded,
                                    color: Color(0xFF176A50)),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'New badge added to your collection!',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF176A50),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (_badges.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Text('No landmark badges are available yet.',
                                style: GoogleFonts.poppins(
                                    color: Colors.grey.shade600)),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
                          sliver: SliverGrid(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: .68,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (_, index) => _BadgeCard(
                                badge: _badges[index],
                                highlighted: _badges[index]['id']?.toString() ==
                                    widget.highlightedLandmarkId,
                              ),
                              childCount: _badges.length,
                            ),
                          ),
                        ),
                    ],
                  ),
      ),
    );
  }
}

class _CollectionHeader extends StatelessWidget {
  final int earned;
  final int total;

  const _CollectionHeader({required this.earned, required this.total});

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : earned / total;
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 10, 18, 18),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF123F33), Color(0xFF176A50)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('YOUR CAVITE JOURNEY',
              style: GoogleFonts.poppins(
                  color: const Color(0xFFD8F270),
                  fontSize: 10,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 7),
          Text('$earned of $total badges unlocked',
              style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 13),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              color: const Color(0xFFD8F270),
              backgroundColor: Colors.white.withValues(alpha: .18),
            ),
          ),
          const SizedBox(height: 9),
          Text(
              'Visit landmarks and stay for the verified time to collect more.',
              style: GoogleFonts.poppins(
                  color: Colors.white.withValues(alpha: .75), fontSize: 10.5)),
        ],
      ),
    );
  }
}

class _BadgeQrHint extends StatelessWidget {
  const _BadgeQrHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFAEA),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8CF82)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF173F34),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.qr_code_2_rounded,
              color: Color(0xFFDDF56E),
              size: 27,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your badge is your reward pass',
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF173F34),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Tap any collected badge to show its QR code and discover partners where you can use it.',
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF617067),
                    fontSize: 9.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.touch_app_rounded,
            color: Color(0xFFB18421),
            size: 23,
          ),
        ],
      ),
    );
  }
}

class _BadgeCard extends StatelessWidget {
  final Map<String, dynamic> badge;
  final bool highlighted;

  const _BadgeCard({required this.badge, this.highlighted = false});

  @override
  Widget build(BuildContext context) {
    final unlocked = badge['earned'] == true;
    final name = (badge['badgeName']?.toString().trim().isNotEmpty ?? false)
        ? badge['badgeName'].toString()
        : '${badge['name'] ?? 'Landmark'} Explorer';
    final image = badge['badgeImage']?.toString() ?? '';
    final place = badge['name']?.toString() ?? 'Cavite landmark';
    final minutes = (badge['badgeRequiredMinutes'] as num?)?.round() ?? 30;
    final artwork = Container(
      width: 104,
      height: 104,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: unlocked ? const Color(0xFFE8C76B) : Colors.grey.shade400,
        boxShadow: unlocked
            ? const [BoxShadow(color: Color(0x55D8A62E), blurRadius: 18)]
            : null,
      ),
      child: ClipOval(
        child: image.isNotEmpty
            ? Image.network(
                ApiService.assetUrl(image),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _fallbackBadge(unlocked),
              )
            : _fallbackBadge(unlocked),
      ),
    );

    final card = GestureDetector(
      onTap: unlocked
          ? () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BadgeRedemptionScreen(
                    userBadgeId: badge['uniqueId']?.toString() ?? '',
                  ),
                ),
              )
          : () => _openLandmark(context),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: highlighted
                ? const Color(0xFFE1B33C)
                : unlocked
                    ? const Color(0xFFD7E5DE)
                    : Colors.grey.shade200,
            width: highlighted ? 2 : 1,
          ),
          boxShadow: highlighted
              ? const [
                  BoxShadow(color: Color(0x66E9BD4A), blurRadius: 24),
                ]
              : null,
        ),
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (highlighted) ...[
                    Text('NEW',
                        style: GoogleFonts.poppins(
                            fontSize: 8,
                            letterSpacing: .7,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFFB17C13))),
                    const SizedBox(width: 5),
                  ],
                  Icon(
                    unlocked ? Icons.check_circle_rounded : Icons.lock_rounded,
                    color: unlocked
                        ? const Color(0xFF176A50)
                        : Colors.grey.shade500,
                    size: 20,
                  ),
                ],
              ),
            ),
            ColorFiltered(
              colorFilter: unlocked
                  ? const ColorFilter.mode(Colors.transparent, BlendMode.dst)
                  : const ColorFilter.matrix(<double>[
                      .2126,
                      .7152,
                      .0722,
                      0,
                      0,
                      .2126,
                      .7152,
                      .0722,
                      0,
                      0,
                      .2126,
                      .7152,
                      .0722,
                      0,
                      0,
                      0,
                      0,
                      0,
                      1,
                      0,
                    ]),
              child: Opacity(opacity: unlocked ? 1 : .55, child: artwork),
            ),
            const SizedBox(height: 12),
            Text(name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                    color: unlocked ? const Color(0xFF18372D) : Colors.grey)),
            const Spacer(),
            Text(
              unlocked
                  ? 'Collected at $place'
                  : 'Locked • Visit for $minutes min',
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                  fontSize: 9,
                  color: unlocked ? const Color(0xFF4D786B) : Colors.grey),
            ),
            if (unlocked) ...[
              const SizedBox(height: 7),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFE7F2EA),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.qr_code_2_rounded,
                      color: Color(0xFF176A50), size: 14),
                  const SizedBox(width: 4),
                  Text('Tap for QR & rewards',
                      style: GoogleFonts.poppins(
                          color: const Color(0xFF176A50),
                          fontSize: 7.8,
                          fontWeight: FontWeight.w700)),
                ]),
              ),
            ],
          ],
        ),
      ),
    );
    if (!highlighted) return card;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: .25, end: 1),
      duration: const Duration(milliseconds: 1050),
      curve: Curves.elasticOut,
      builder: (_, value, child) => Transform.scale(
        scale: value,
        child: Opacity(opacity: value.clamp(0, 1).toDouble(), child: child),
      ),
      child: card,
    );
  }

  Future<void> _openLandmark(BuildContext context) async {
    final navigator = Navigator.of(context);
    var dialogOpen = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Row(children: [
              const SizedBox(
                width: 27,
                height: 27,
                child: CircularProgressIndicator(
                    strokeWidth: 3, color: Color(0xFF176A50)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text('Opening landmark...',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF18372D))),
              ),
            ]),
          ),
        ),
      ),
    );
    try {
      final landmarks = await ApiService.getLandmarks();
      final id = badge['id']?.toString();
      final value = landmarks.whereType<Map>().firstWhere(
            (landmark) => landmark['id']?.toString() == id,
          );
      final position = await LocationService.promptLocationOnce();
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      dialogOpen = false;
      await navigator.push(MaterialPageRoute(
        builder: (_) => PlaceDetailsScreen(
          place: Map<String, dynamic>.from(value),
          userPosition: position,
        ),
      ));
    } catch (error) {
      if (context.mounted) {
        if (dialogOpen) Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open landmark details.')),
        );
      }
    }
  }

  Widget _fallbackBadge(bool unlocked) => Container(
        color: unlocked ? const Color(0xFF176A50) : Colors.grey.shade500,
        child: const Icon(Icons.workspace_premium_rounded,
            color: Colors.white, size: 48),
      );
}
