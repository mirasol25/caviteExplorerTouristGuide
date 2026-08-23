import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_links/app_links.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/map_preview_screen.dart';
import 'screens/new_password_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/partner_dashboard_screen.dart';
import 'screens/partner_invite_screen.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'services/background_tracking_service.dart';
import 'services/location_service.dart';
import 'services/notification_service.dart';
import 'widgets/visit_tracking_overlay.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('Flutter framework error: ${details.exceptionAsString()}');
  };
  await AuthService.initializeSession();
  try {
    await VisitTrackingController.instance.initialize();
  } catch (error, stackTrace) {
    debugPrint('Visit tracking initialization failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
  debugPrint('Cavite Explorer: Flutter application starting');
  runApp(const CaviteExplorerApp());
}

class CaviteExplorerApp extends StatefulWidget {
  const CaviteExplorerApp({super.key});

  @override
  State<CaviteExplorerApp> createState() => _CaviteExplorerAppState();
}

class _CaviteExplorerAppState extends State<CaviteExplorerApp>
    with WidgetsBindingObserver {
  StreamSubscription<String>? _notificationSubscription;
  StreamSubscription<Uri>? _appLinkSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _notificationSubscription =
        notificationPayloads.stream.listen(_openNotificationPayload);
    VisitTrackingController.instance.unlockedBadge.addListener(_showUnlock);
    AuthService.badgeEligible.addListener(_syncBadgeSession);
    _listenForAppLinks();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Android 13+ requires a runtime prompt before nearby-landmark, badge,
      // and live-commute notifications can appear. Ask on the first app launch
      // so it is presented alongside the app's location permission flow.
      await NotificationService.requestPermission();
      final initial = await NotificationService.initialPayload();
      if (initial != null) await _openNotificationPayload(initial);
      await _offerBackgroundAwareness();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notificationSubscription?.cancel();
    _appLinkSubscription?.cancel();
    VisitTrackingController.instance.unlockedBadge.removeListener(_showUnlock);
    AuthService.badgeEligible.removeListener(_syncBadgeSession);
    super.dispose();
  }

  Future<void> _listenForAppLinks() async {
    final links = AppLinks();
    Future<void> open(Uri? uri) async {
      if (uri == null || uri.scheme != 'caviteexplorer') return;
      await Future<void>.delayed(const Duration(milliseconds: 350));
      final navigator = appNavigatorKey.currentState;
      if (navigator == null) return;

      if (uri.host == 'accept-invite') {
        final token = uri.queryParameters['token'];
        if (token == null || token.isEmpty) return;
        await navigator.push(MaterialPageRoute(
            builder: (_) => PartnerInviteScreen(token: token)));
        return;
      }

      if (uri.host == 'reset-password') {
        final error = uri.queryParameters['error'];
        final token = uri.queryParameters['token'];
        if (error != null || token == null || token.isEmpty) {
          _showLinkMessage('This password reset link is invalid or expired.',
              isError: true);
          return;
        }
        await navigator.push(
            MaterialPageRoute(builder: (_) => NewPasswordScreen(token: token)));
        return;
      }

      if (uri.host != 'login-callback') return;
      final error = uri.queryParameters['error'];
      if (error != null) {
        await navigator.pushNamedAndRemoveUntil('/login', (_) => false);
        _showLinkMessage(
          error == 'AccountDisabled'
              ? 'This account has been disabled.'
              : 'Sign in could not be completed. Please try again.',
          isError: true,
        );
        return;
      }
      if (uri.queryParameters['verified'] == 'true') {
        await navigator.pushNamedAndRemoveUntil('/login', (_) => false);
        _showLinkMessage('Email verified. You can now sign in.');
        return;
      }

      final token = uri.queryParameters['token'];
      if (token == null || token.isEmpty) return;
      try {
        final response = await http.get(
          ApiService.uri('/auth/me'),
          headers: {'Authorization': 'Bearer $token'},
        );
        if (response.statusCode != 200) {
          _showLinkMessage('Could not finish signing in. Please try again.',
              isError: true);
          return;
        }
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final user = Map<String, dynamic>.from(data['user'] as Map);
        await AuthService.saveUser(
          user['name']?.toString() ?? 'Explorer',
          user['email']?.toString() ?? '',
          token,
          role: user['role']?.toString() ?? 'user',
        );
        await navigator.pushNamedAndRemoveUntil('/', (_) => false);
      } catch (error) {
        debugPrint('Could not process authentication link: $error');
        _showLinkMessage('Network error while completing sign in.',
            isError: true);
      }
    }

    await open(await links.getInitialLink());
    _appLinkSubscription = links.uriLinkStream.listen(open);
  }

  void _showLinkMessage(String message, {bool isError = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = appNavigatorKey.currentContext;
      if (context == null || !context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : const Color(0xFF176A50),
      ));
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final resumed = state == AppLifecycleState.resumed;
    BackgroundTrackingService.setAppForeground(resumed);
    if (resumed) {
      unawaited(BackgroundTrackingService.refreshLandmarkAwareness());
    }
  }

  void _showUnlock() {
    if (!AuthService.badgeEligible.value) return;
    final state = VisitTrackingController.instance.unlockedBadge.value;
    final context = appNavigatorKey.currentContext;
    if (state == null || context == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final currentContext = appNavigatorKey.currentContext;
      if (currentContext == null) return;
      VisitTrackingController.instance.consumeUnlock();
      await showBadgeUnlockDialog(currentContext, state);
    });
  }

  void _syncBadgeSession() {
    if (AuthService.badgeEligible.value) {
      unawaited(BackgroundTrackingService.refreshLandmarkAwareness());
    } else {
      unawaited(BackgroundTrackingService.suspendBadgeTracking());
    }
  }

  Future<void> _offerBackgroundAwareness() async {
    final signedInUser = await AuthService.getUser();
    if (signedInUser == null || signedInUser['role'] == 'partner') return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('background_awareness_prompted') == true ||
        await BackgroundTrackingService.isAwarenessEnabled) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 900));
    final context = appNavigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    final enable = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.explore_rounded,
            color: Color(0xFF176A50), size: 34),
        title: const Text('Discover landmarks nearby'),
        content: const Text(
          'Allow background location and notifications to discover nearby landmarks, keep badge visits running, and continue live commute guidance when the app is minimized.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Maybe later'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Enable alerts'),
          ),
        ],
      ),
    );
    await prefs.setBool('background_awareness_prompted', true);
    if (enable != true) return;
    final enabled = await BackgroundTrackingService.requestAndEnableAwareness();
    if (enabled) return;
    final currentContext = appNavigatorKey.currentContext;
    if (currentContext == null || !currentContext.mounted) return;
    final open = await showDialog<bool>(
      context: currentContext,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Allow location all the time'),
        content: const Text(
          'Android requires “Allow all the time” location access for landmark alerts while Cavite Explorer is in the background. You can enable it in App permissions > Location.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Open settings'),
          ),
        ],
      ),
    );
    if (open == true) await openAppSettings();
  }

  Future<void> _openNotificationPayload(String payload) async {
    final parts = payload.split(':');
    if (parts.length != 2) return;
    final kind = parts.first;
    final id = parts.last;
    if (kind == 'visit') return;
    if (kind == 'commute') {
      // The active live-commute route remains in the navigator stack and is
      // restored automatically when the notification brings the app forward.
      return;
    }
    try {
      final landmarks = await ApiService.getLandmarks();
      final value = landmarks.whereType<Map>().cast<Map>().firstWhere(
            (landmark) => landmark['id']?.toString() == id,
          );
      final place = Map<String, dynamic>.from(value);
      final position = await LocationService.promptLocationOnce();
      final navigator = appNavigatorKey.currentState;
      if (navigator == null) return;
      await navigator.push(MaterialPageRoute(
        builder: (_) => MapPreviewScreen(
          place: place,
          userPosition: position,
        ),
      ));
      if (kind == 'badge') {
        final state = VisitTrackingController.instance.visit.value;
        final context = appNavigatorKey.currentContext;
        if (state != null && context != null) {
          await showBadgeUnlockDialog(context, state);
        }
      }
    } catch (error) {
      debugPrint('Could not open notification destination: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: 'Cavite Explorer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF9F8F4),
      ),
      // We use initialRoute instead of the 'home:' property
      initialRoute: '/',
      routes: {
        '/': (context) => const _AppStartupScreen(),
        '/login': (context) => const LoginScreen(),
        '/profile': (context) => const ProfileScreen(),
      },
      builder: (context, child) => VisitTrackingOverlay(
        child: child ?? const SizedBox.shrink(),
        navigatorKey: appNavigatorKey,
      ),
    );
  }
}

/// Draws a native Flutter surface before HomeScreen begins location and API work.
/// This prevents a blank window while startup services initialize.
class _AppStartupScreen extends StatefulWidget {
  const _AppStartupScreen();

  @override
  State<_AppStartupScreen> createState() => _AppStartupScreenState();
}

class _AppStartupScreenState extends State<_AppStartupScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      debugPrint('Cavite Explorer: first Flutter frame rendered');
      if (mounted) {
        final user = await AuthService.getUser();
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => user?['role'] == 'partner'
                ? const PartnerDashboardScreen()
                : const HomeScreen(),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
