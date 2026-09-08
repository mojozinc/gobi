import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Use localhost (or adb reverse port 8000) for development
  final String baseUrl;
  final SharedPreferences? prefs;
  String? _token;

  ApiService({this.baseUrl = 'http://127.0.0.1:8000/api/v1', this.prefs}) {
    _token = prefs?.getString('auth_token');
  }

  void setToken(String token) {
    _token = token;
    prefs?.setString('auth_token', token);
  }

  String? get token => _token;

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  // Auth
  Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    final data = jsonDecode(res.body);
    if (res.statusCode == 200) {
      setToken(data['token']);
      return data;
    }
    throw Exception(data['detail'] ?? 'Login failed');
  }

  Future<Map<String, dynamic>> register(String name, String email, String password) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'email': email, 'password': password}),
    );
    final data = jsonDecode(res.body);
    if (res.statusCode == 201) {
      setToken(data['token']);
      return data;
    }
    throw Exception(data['detail'] ?? 'Registration failed');
  }

  // AI Endpoints
  Future<Map<String, dynamic>> parseVoiceIntent(String text, {int? dependentId}) async {
    final res = await http.post(
      Uri.parse('$baseUrl/ai/parse-intent'),
      headers: _headers,
      body: jsonEncode({
        'text': text,
        if (dependentId != null) 'dependent_id': dependentId,
      }),
    );
    return jsonDecode(utf8.decode(res.bodyBytes));
  }

  Future<Map<String, dynamic>> scanPrescription(String filePath, {int? dependentId}) async {
    final uri = Uri.parse('$baseUrl/ai/scan-prescription');
    final request = http.MultipartRequest('POST', uri);
    
    if (_token != null) {
      request.headers['Authorization'] = 'Bearer $_token';
    }
    if (dependentId != null) {
      request.fields['dependent_id'] = dependentId.toString();
    }
    request.files.add(await http.MultipartFile.fromPath('file', filePath));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  Future<Map<String, dynamic>> sendHealthChat(String query, {int? dependentId, List<Map<String, String>>? history}) async {
    final res = await http.post(
      Uri.parse('$baseUrl/ai/chat'),
      headers: _headers,
      body: jsonEncode({
        'query': query,
        if (dependentId != null) 'dependent_id': dependentId,
        'conversation_history': history ?? [],
      }),
    );
    return jsonDecode(utf8.decode(res.bodyBytes));
  }

  // Medications
  Future<List<dynamic>> getMedications({int? dependentId}) async {
    final url = dependentId != null 
        ? '$baseUrl/medications?dependent_id=$dependentId'
        : '$baseUrl/medications';
    final res = await http.get(Uri.parse(url), headers: _headers);
    if (res.statusCode == 200) {
      return jsonDecode(utf8.decode(res.bodyBytes));
    }
    return [];
  }

  Future<Map<String, dynamic>> createMedication(Map<String, dynamic> data) async {
    final res = await http.post(
      Uri.parse('$baseUrl/medications'),
      headers: _headers,
      body: jsonEncode(data),
    );
    return jsonDecode(utf8.decode(res.bodyBytes));
  }

  Future<List<dynamic>> getTodayDoses({int? dependentId}) async {
    final url = dependentId != null
        ? '$baseUrl/medications/doses/today?dependent_id=$dependentId'
        : '$baseUrl/medications/doses/today';
    final res = await http.get(Uri.parse(url), headers: _headers);
    if (res.statusCode == 200) {
      return jsonDecode(utf8.decode(res.bodyBytes));
    }
    return [];
  }

  Future<Map<String, dynamic>> takeDose(int doseId) async {
    final res = await http.post(
      Uri.parse('$baseUrl/medications/doses/$doseId/take'),
      headers: _headers,
    );
    return jsonDecode(utf8.decode(res.bodyBytes));
  }

  Future<Map<String, dynamic>> undoDose(int doseId) async {
    final res = await http.post(
      Uri.parse('$baseUrl/medications/doses/$doseId/undo'),
      headers: _headers,
    );
    return jsonDecode(utf8.decode(res.bodyBytes));
  }
}
