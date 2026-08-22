import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://cavite-explorer-backend.onrender.com',
  );

  static Uri uri(String path) => Uri.parse('$baseUrl$path');

  static String assetUrl(dynamic value) {
    var path = (value ?? '').toString().trim();
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    final parsed = Uri.tryParse(path);
    if (parsed?.scheme == 'file') path = parsed!.path;
    return '$baseUrl${path.startsWith('/') ? '' : '/'}$path';
  }

  static Future<List<dynamic>> getLandmarks() async {
    final response = await http.get(Uri.parse('$baseUrl/places'));

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load landmarks');
    }
  }
}
