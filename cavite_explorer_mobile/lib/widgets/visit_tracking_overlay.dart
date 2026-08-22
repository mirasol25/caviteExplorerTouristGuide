import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/background_tracking_service.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';
import '../screens/place_details_screen.dart';
import '../screens/badge_collection_screen.dart';

class VisitTrackingOverlay extends StatelessWidget {
  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;

  const VisitTrackingOverlay({
    super.key,
    required this.child,
    required this.navigatorKey,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AuthService.badgeEligible,
      builder: (context, eligible, _) =>
          ValueListenableBuilder<List<Map<String, dynamic>>>(
        valueListenable: VisitTrackingController.instance.visits,
        builder: (context, visits, _) {
          final visit = visits.isEmpty ? null : visits.first;
          final status = visit?['status']?.toString();
          final visible = eligible &&
              visit != null &&
              status != 'COMPLETED' &&
              visit['earned'] != true &&
              visit['landmarkId'] != null;
          return Stack(
            children: [
              child,
              if (visible)
                Positioned(
                  left: 18,
                  right: 18,
                  top: MediaQuery.paddingOf(context).top + 8,
                  child: _VisitPill(
                    visit: visit,
                    visitCount: visits.length,
                    navigatorKey: navigatorKey,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _VisitPill extends StatelessWidget {
  final Map<String, dynamic> visit;
  final int visitCount;
  final GlobalKey<NavigatorState> navigatorKey;

  const _VisitPill({
    required this.visit,
    required this.visitCount,
    required this.navigatorKey,
  });

  @override
  Widget build(BuildContext context) {
    final status = visit['status']?.toString() ?? 'VERIFYING';
    final paused = status == 'PAUSED' || status == 'OUTSIDE';
    final reset = status == 'RESET';
    final color =
        paused || reset ? const Color(0xFFE56B2F) : const Color(0xFF176A50);
    final remaining = (visit['remainingSeconds'] as num?)?.round() ?? 0;
    final name = visit['landmarkName']?.toString() ?? 'Landmark visit';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          final navigatorContext = navigatorKey.currentContext;
          if (navigatorContext != null) {
            _showVisitDetails(navigatorContext, visit);
          }
        },
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: .26),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .17),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  paused || reset
                      ? Icons.location_off_rounded
                      : Icons.workspace_premium_rounded,
                  color: Colors.white,
                  size: 21,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      visitCount > 1
                          ? '$visitCount landmark badges in progress'
                          : paused
                              ? 'Visit paused - return soon'
                              : reset
                                  ? 'Visit timer reset'
                                  : 'Earning $name badge',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      visitCount > 1
                          ? 'Tap to view every active countdown'
                          : paused
                              ? 'Tap to see your 5-minute return window'
                              : '${_clock(remaining)} remaining',
                      style: GoogleFonts.poppins(
                        color: Colors.white.withValues(alpha: .82),
                        fontSize: 9.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: Colors.white, size: 23),
            ],
          ),
        ),
      ),
    );
  }
}

void _showVisitDetails(BuildContext context, Map<String, dynamic> visit) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => ValueListenableBuilder<List<Map<String, dynamic>>>(
      valueListenable: VisitTrackingController.instance.visits,
      builder: (context, visits, child) => visits.length <= 1
          ? _visitDetailsSheet(visits.isEmpty ? visit : visits.first)
          : _multipleVisitDetailsSheet(visits),
    ),
  );
}

Widget _multipleVisitDetailsSheet(List<Map<String, dynamic>> visits) {
  return Container(
    constraints: const BoxConstraints(maxHeight: 560),
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
    decoration: const BoxDecoration(
      color: Color(0xFFFDFCF9),
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    child: SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Badge visits in progress',
              style: GoogleFonts.poppins(
                  fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Each landmark is verified and counted independently.',
              style: GoogleFonts.poppins(
                  fontSize: 11, color: Colors.grey.shade600)),
          const SizedBox(height: 14),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: visits.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (itemContext, index) {
                final visit = visits[index];
                final status = visit['status']?.toString() ?? 'VERIFYING';
                final paused = status == 'PAUSED' || status == 'OUTSIDE';
                final seconds = paused
                    ? (visit['graceRemainingSeconds'] as num?)?.round() ?? 300
                    : (visit['remainingSeconds'] as num?)?.round() ?? 0;
                final color =
                    paused ? const Color(0xFFE56B2F) : const Color(0xFF176A50);
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => unawaited(_openLandmark(itemContext, visit)),
                    borderRadius: BorderRadius.circular(16),
                    child: Ink(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: .08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: color.withValues(alpha: .2)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                              paused
                                  ? Icons.location_off_rounded
                                  : Icons.workspace_premium_rounded,
                              color: color),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  visit['landmarkName']?.toString() ??
                                      'Landmark',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700),
                                ),
                                Text(
                                  paused
                                      ? 'Visit paused • return window'
                                      : 'Inside landmark • badge countdown',
                                  style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                          Text(_clock(seconds),
                              style: GoogleFonts.poppins(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: color)),
                          const SizedBox(width: 4),
                          Icon(Icons.chevron_right_rounded,
                              size: 18, color: color),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

Future<void> _openLandmark(
    BuildContext context, Map<String, dynamic> visit) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  final id = visit['landmarkId']?.toString();
  if (id == null || id.isEmpty) return;
  navigator.pop();
  try {
    final landmarks = await ApiService.getLandmarks();
    final value = landmarks.whereType<Map>().firstWhere(
          (landmark) => landmark['id']?.toString() == id,
        );
    final position = await LocationService.promptLocationOnce();
    await navigator.push(MaterialPageRoute(
      builder: (_) => PlaceDetailsScreen(
        place: Map<String, dynamic>.from(value),
        userPosition: position,
      ),
    ));
  } catch (error) {
    debugPrint('Could not open landmark details: $error');
  }
}

Widget _visitDetailsSheet(Map<String, dynamic> visit) {
  final required = math.max(
    1,
    (visit['requiredSeconds'] as num?)?.round() ?? 1800,
  );
  final remaining = math.max(
    0,
    (visit['remainingSeconds'] as num?)?.round() ?? required,
  );
  final status = visit['status']?.toString() ?? 'VERIFYING';
  final paused = status == 'PAUSED' || status == 'OUTSIDE';
  final reset = status == 'RESET';
  final grace = (visit['graceRemainingSeconds'] as num?)?.round() ?? 300;
  final progress = ((required - remaining) / required).clamp(0.0, 1.0);
  final displayedSeconds = paused ? grace : remaining;
  return Container(
    padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
    decoration: const BoxDecoration(
      color: Color(0xFFFDFCF9),
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    child: SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 78,
            height: 78,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: progress.toDouble(),
                    strokeWidth: 7,
                    color: paused || reset
                        ? const Color(0xFFE56B2F)
                        : const Color(0xFF2878F0),
                    backgroundColor: const Color(0xFFE8EEF8),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Icon(
                  paused || reset
                      ? Icons.location_off_rounded
                      : Icons.location_on_rounded,
                  color: paused || reset
                      ? const Color(0xFFE56B2F)
                      : const Color(0xFF2878F0),
                  size: 32,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            paused
                ? "You're away from the landmark"
                : reset
                    ? 'Your visit timer was reset'
                    : 'Stay here to earn your badge',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            paused
                ? 'Return within ${_clock(grace)} to keep your completed visit time.'
                : reset
                    ? 'Return inside the landmark area to begin again.'
                    : 'You can continue exploring the app. Visit tracking will continue in the background.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 11.5,
              height: 1.45,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            _clock(displayedSeconds),
            style: GoogleFonts.poppins(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: paused || reset
                  ? const Color(0xFFE56B2F)
                  : const Color(0xFF2878F0),
            ),
          ),
          Text(
              paused
                  ? 'return window remaining'
                  : reset
                      ? 'badge time remaining'
                      : 'badge time remaining',
              style: GoogleFonts.poppins(
                  fontSize: 10, color: Colors.grey.shade500)),
          if (paused) ...[
            const SizedBox(height: 10),
            Text(
              'Badge timer paused at ${_clock(remaining)} remaining',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

Future<void> showBadgeUnlockDialog(
    BuildContext context, Map<String, dynamic> state) async {
  final badge = state['badge'] is Map
      ? Map<String, dynamic>.from(state['badge'] as Map)
      : const <String, dynamic>{};
  final name = badge['name']?.toString() ?? 'Landmark Explorer';
  final image = badge['image']?.toString() ?? '';
  final landmarkId = state['landmarkId']?.toString();
  final navigator = Navigator.of(context, rootNavigator: true);
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Badge unlocked',
    barrierColor: Colors.black.withValues(alpha: .76),
    transitionDuration: const Duration(milliseconds: 650),
    pageBuilder: (_, __, ___) => Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: math.min(MediaQuery.sizeOf(context).width - 34, 390),
          padding: const EdgeInsets.fromLTRB(24, 30, 24, 22),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFDF7),
            borderRadius: BorderRadius.circular(30),
            boxShadow: const [
              BoxShadow(color: Color(0x66E7B84A), blurRadius: 45),
            ],
          ),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 900),
            curve: Curves.elasticOut,
            builder: (_, value, child) => Transform.scale(
              scale: value,
              child: Opacity(
                opacity: value.clamp(0, 1).toDouble(),
                child: child,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('NEW BADGE UNLOCKED!',
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        letterSpacing: 1.3,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFB17C13))),
                const SizedBox(height: 22),
                Container(
                  width: 142,
                  height: 142,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFE28A), Color(0xFFE3A72D)],
                    ),
                    boxShadow: const [
                      BoxShadow(color: Color(0x99E7B84A), blurRadius: 34),
                    ],
                  ),
                  child: ClipOval(
                    child: image.isNotEmpty
                        ? Image.network(
                            ApiService.assetUrl(image),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.workspace_premium_rounded,
                              size: 74,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.workspace_premium_rounded,
                            size: 74, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 20),
                Text(name,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                        fontSize: 22,
                        height: 1.25,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF18372D))),
                const SizedBox(height: 9),
                Text(
                  'Your verified visit is complete. Show this badge to participating partners near the landmark to discover available discounts.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                      fontSize: 11.5, height: 1.5, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      navigator.pop();
                      navigator.push(MaterialPageRoute(
                        builder: (_) => BadgeCollectionScreen(
                          highlightedLandmarkId: landmarkId,
                        ),
                      ));
                    },
                    icon: const Icon(Icons.workspace_premium_rounded),
                    label: Text('View my badge',
                        style:
                            GoogleFonts.poppins(fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF176A50),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
    transitionBuilder: (_, animation, __, child) => FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: child,
    ),
  );
}

String _clock(int seconds) {
  final safe = math.max(0, seconds);
  return '${(safe ~/ 60).toString().padLeft(2, '0')}:${(safe % 60).toString().padLeft(2, '0')}';
}
