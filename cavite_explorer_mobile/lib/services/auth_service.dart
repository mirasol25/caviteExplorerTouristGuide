import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  static const _secureStorage = FlutterSecureStorage();
  static const _tokenKey = 'authToken';
  // 1. Save user data when they successfully log in via Google
  static Future<void> saveUser(String name, String email, String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userName', name);
    await prefs.setString('userEmail', email);
    await _secureStorage.write(key: _tokenKey, value: token);
  }

  // 2. Read the user data for the Home and Profile screens
  static Future<Map<String, String>?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('userName');
    final email = prefs.getString('userEmail');
    final token = await _secureStorage.read(key: _tokenKey);

    if (name != null && email != null) {
      return {'name': name, 'email': email, 'token': token ?? ''};
    }
    return null; // Means the user is logged out
  }

  // 3. Clear data when they click Log Out
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userName');
    await prefs.remove('userEmail');
    await _secureStorage.delete(key: _tokenKey);
  }
}
