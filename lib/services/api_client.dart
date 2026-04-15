import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  static const String baseUrl = 'http://localhost:5000/api';
  static String? _token;

  static Future<void> saveToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
  }

  static Future<String?> loadToken() async {
    if (_token != null) return _token;
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('jwt_token');
    return _token;
  }

  static Future<void> saveUserData(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_data', jsonEncode(data));
  }

  static Future<Map<String, dynamic>?> loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString('user_data');
    if (s == null) return null;
    return jsonDecode(s) as Map<String, dynamic>;
  }

  static Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('user_data');
  }

  static Future<Map<String, String>> get _headers async {
    final token = await loadToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<Map<String, dynamic>> get(String path) async {
    final res = await http.get(Uri.parse('$baseUrl$path'), headers: await _headers);
    return _handle(res);
  }

  static Future<Map<String, dynamic>> post(String path, [dynamic body]) async {
    final res = await http.post(Uri.parse('$baseUrl$path'), headers: await _headers,
        body: body != null ? jsonEncode(body) : null);
    return _handle(res);
  }

  static Future<Map<String, dynamic>> patch(String path, [dynamic body]) async {
    final res = await http.patch(Uri.parse('$baseUrl$path'), headers: await _headers,
        body: body != null ? jsonEncode(body) : null);
    return _handle(res);
  }

  static Map<String, dynamic> _handle(http.Response res) {
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400) throw Exception(body['message'] ?? 'Server error');
    return body;
  }
}
