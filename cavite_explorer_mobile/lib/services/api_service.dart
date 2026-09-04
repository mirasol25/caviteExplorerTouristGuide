import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// A small, device-local copy of Cavite Explorer's public directory data.
///
/// It intentionally stores data and not map tiles, user accounts, or QR codes.
/// Those features need a live connection for correctness and security.
class OfflineDataStatus {
  const OfflineDataStatus({
    required this.lastSynced,
    required this.landmarks,
    required this.routes,
    required this.tricycleTerminals,
    required this.partners,
  });

  final DateTime? lastSynced;
  final int landmarks;
  final int routes;
  final int tricycleTerminals;
  final int partners;

  bool get hasOfflineData =>
      landmarks > 0 || routes > 0 || tricycleTerminals > 0 || partners > 0;
}

class ApiService {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://cavite-explorer-backend.onrender.com',
  );

  static Uri uri(String path) => Uri.parse('$baseUrl$path');

  static const _landmarksCacheKey = 'offline_landmarks_v1';
  static const _routesCacheKey = 'offline_transport_routes_v1';
  static const _tricycleCacheKey = 'offline_tricycle_terminals_v1';
  static const _partnersCacheKey = 'offline_partners_v1';
  static const _lastSyncedKey = 'offline_directory_last_synced_v1';
  static const _matchCachePrefix = 'offline_transport_match_v1_';

  static String assetUrl(dynamic value) {
    var path = (value ?? '').toString().trim();
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    final parsed = Uri.tryParse(path);
    if (parsed?.scheme == 'file') path = parsed!.path;
    return '$baseUrl${path.startsWith('/') ? '' : '/'}$path';
  }

  /// Loads the directory from the service when possible, falling back to the
  /// last successful download if the device is offline.
  static Future<List<dynamic>> getLandmarks({bool forceNetwork = false}) {
    return _getCachedList(
      path: '/places',
      cacheKey: _landmarksCacheKey,
      forceNetwork: forceNetwork,
      errorMessage: 'Failed to load landmarks',
    );
  }

  static Future<List<dynamic>> getTransportRoutes({bool forceNetwork = false}) {
    return _getCachedList(
      path: '/transport/routes',
      cacheKey: _routesCacheKey,
      forceNetwork: forceNetwork,
      errorMessage: 'Failed to load transport routes',
    );
  }

  static Future<List<dynamic>> getTricycleTerminals({bool forceNetwork = false}) {
    return _getCachedList(
      path: '/transport/tricycle-terminals',
      cacheKey: _tricycleCacheKey,
      forceNetwork: forceNetwork,
      errorMessage: 'Failed to load tricycle terminals',
    );
  }

  static Future<List<dynamic>> getPartners(
    String token, {
    bool forceNetwork = false,
  }) {
    return _getCachedList(
      path: '/rewards/partners',
      cacheKey: _partnersCacheKey,
      token: token,
      forceNetwork: forceNetwork,
      errorMessage: 'Failed to load partner rewards',
    );
  }

  /// Caches a previously requested commute result. This lets a saved journey
  /// be reopened offline, but does not invent a route for an unknown journey.
  static Future<List<dynamic>> getTransportMatches({
    required double startLat,
    required double startLng,
    required double destinationLat,
    required double destinationLng,
  }) async {
    final key = _matchCacheKey(startLat, startLng, destinationLat, destinationLng);
    final requestUri = uri('/transport/routes/match').replace(queryParameters: {
      'startLat': startLat.toString(),
      'startLng': startLng.toString(),
      'destinationLat': destinationLat.toString(),
      'destinationLng': destinationLng.toString(),
    });
    try {
      final response = await http.get(requestUri).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        throw Exception('Transport lookup failed (${response.statusCode})');
      }
      final data = _decodeList(response.body);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, jsonEncode(data));
      return data;
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(key);
      if (cached != null) return _decodeList(cached);
      rethrow;
    }
  }

  /// Downloads the directory in the background. Calling this repeatedly is
  /// safe: a failed request keeps the existing local data unchanged.
  static Future<OfflineDataStatus> syncOfflineData({String? token}) async {
    await Future.wait([
      getLandmarks(forceNetwork: true),
      getTransportRoutes(forceNetwork: true),
      getTricycleTerminals(forceNetwork: true),
    ]);
    // Partner rewards are account-protected. A stale sign-in must not block
    // refreshing the public landmark and transport directory.
    if (token != null && token.isNotEmpty) {
      try {
        await getPartners(token, forceNetwork: true);
      } catch (_) {}
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSyncedKey, DateTime.now().toUtc().toIso8601String());
    return offlineDataStatus();
  }

  static Future<OfflineDataStatus> offlineDataStatus() async {
    final prefs = await SharedPreferences.getInstance();
    DateTime? lastSynced;
    final rawDate = prefs.getString(_lastSyncedKey);
    if (rawDate != null) lastSynced = DateTime.tryParse(rawDate)?.toLocal();
    return OfflineDataStatus(
      lastSynced: lastSynced,
      landmarks: _cachedListLength(prefs, _landmarksCacheKey),
      routes: _cachedListLength(prefs, _routesCacheKey),
      tricycleTerminals: _cachedListLength(prefs, _tricycleCacheKey),
      partners: _cachedListLength(prefs, _partnersCacheKey),
    );
  }

  static Future<void> clearOfflineData() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((key) =>
        key == _landmarksCacheKey ||
        key == _routesCacheKey ||
        key == _tricycleCacheKey ||
        key == _partnersCacheKey ||
        key == _lastSyncedKey ||
        key.startsWith(_matchCachePrefix)).toList(growable: false);
    await Future.wait(keys.map(prefs.remove));
  }

  static Future<List<dynamic>> _getCachedList({
    required String path,
    required String cacheKey,
    required String errorMessage,
    String? token,
    bool forceNetwork = false,
  }) async {
    try {
      final response = await http
          .get(uri(path), headers: token == null || token.isEmpty
              ? null
              : {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) throw Exception('$errorMessage (${response.statusCode})');
      final data = _decodeList(response.body);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(cacheKey, jsonEncode(data));
      return data;
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(cacheKey);
      // A background sync must not pretend that cached data is freshly
      // downloaded. Normal screen loads may use the cache safely.
      if (cached != null && !forceNetwork) return _decodeList(cached);
      throw Exception(errorMessage);
    }
  }

  static List<dynamic> _decodeList(String value) {
    final decoded = jsonDecode(value);
    if (decoded is! List) throw const FormatException('Expected a list response');
    return decoded;
  }

  static int _cachedListLength(SharedPreferences prefs, String key) {
    final value = prefs.getString(key);
    if (value == null) return 0;
    try {
      return _decodeList(value).length;
    } catch (_) {
      return 0;
    }
  }

  static String _matchCacheKey(double a, double b, double c, double d) {
    String coordinate(double value) => value.toStringAsFixed(4);
    return '${_matchCachePrefix}${coordinate(a)}_${coordinate(b)}_${coordinate(c)}_${coordinate(d)}';
  }
}
