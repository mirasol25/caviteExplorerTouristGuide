import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  static const _secureStorage = FlutterSecureStorage();
  static const _tokenKey = 'authToken';
  static const _badgeEligibleKey = 'badgeTrackingEligible';
  static final ValueNotifier<bool> badgeEligible = ValueNotifier(false);

  static Future<void> initializeSession() async {
    final user = await getUser();
    final eligible = user != null &&
        user['role'] != 'partner' &&
        (user['token']?.isNotEmpty ?? false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_badgeEligibleKey, eligible);
    badgeEligible.value = eligible;
  }

  // 1. Save user data when they successfully log in via Google
  static Future<void> saveUser(String name, String email, String token,
      {String role = 'user'}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userName', name);
    await prefs.setString('userEmail', email);
    await prefs.setString('userRole', role);
    final eligible = role != 'partner' && token.isNotEmpty;
    await prefs.setBool(_badgeEligibleKey, eligible);
    await _secureStorage.write(key: _tokenKey, value: token);
    badgeEligible.value = eligible;
  }

  // 2. Read the user data for the Home and Profile screens
  static Future<Map<String, String>?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('userName');
    final email = prefs.getString('userEmail');
    final role = prefs.getString('userRole') ?? 'user';
    final token = await _secureStorage.read(key: _tokenKey);

    if (name != null && email != null) {
      return {'name': name, 'email': email, 'token': token ?? '', 'role': role};
    }
    return null; // Means the user is logged out
  }

  // 3. Clear data when they click Log Out
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userName');
    await prefs.remove('userEmail');
    await prefs.remove('userRole');
    await prefs.setBool(_badgeEligibleKey, false);
    await _secureStorage.delete(key: _tokenKey);
    badgeEligible.value = false;
  }
}
