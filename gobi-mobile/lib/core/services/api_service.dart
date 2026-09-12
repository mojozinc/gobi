import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../models/backend_health.dart';

class ApiService {
  final String baseUrl;
  final SharedPreferences? prefs;
  final http.Client _client;
  final ValueNotifier<BackendHealth?> lastKnownHealth = ValueNotifier<BackendHealth?>(null);
  String? _token;
  Map<String, dynamic>? _user;

  ApiService({
    String? baseUrl,
    this.prefs,
    http.Client? client,
  })  : baseUrl = baseUrl ?? AppConfig.apiBaseUrl,
        _client = client ?? http.Client() {
    _token = prefs?.getString('auth_token');
    final userStr = prefs?.getString('user_data');
    if (userStr != null) {
      try {
        _user = jsonDecode(userStr);
      } catch (_) {}
    }
  }

  void setToken(String token) {
    _token = token;
    prefs?.setString('auth_token', token);
  }

  void setUser(Map<String, dynamic> user) {
    _user = user;
    prefs?.setString('user_data', jsonEncode(user));
  }

  void clearAuth() {
    _token = null;
    _user = null;
    prefs?.remove('auth_token');
    prefs?.remove('user_data');
  }

  String? get token => _token ?? prefs?.getString('auth_token');
  Map<String, dynamic>? get currentUser {
    if (_user != null) return _user;
    final userStr = prefs?.getString('user_data');
    if (userStr != null) {
      try {
        _user = jsonDecode(userStr);
      } catch (_) {}
    }
    return _user;
  }
  bool get isAuthenticated => token != null && token!.isNotEmpty;

  String getOrCreateDeviceId() {
    String? id = prefs?.getString('device_installation_id');
    if (id == null || id.isEmpty) {
      id = 'dev_${DateTime.now().millisecondsSinceEpoch}_${(1000 + (DateTime.now().microsecond % 9000))}';
      prefs?.setString('device_installation_id', id);
    }
    return id;
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };

  /// Ensures an active authentication token exists, performing guest login if needed.
  Future<void> ensureAuthenticated() async {
    if (!isAuthenticated) {
      try {
        await loginAnonymously();
      } catch (e) {
        debugPrint('Auto-auth attempt notice: $e');
      }
    }
  }

  Future<http.Response> _postAuthenticated(Uri uri, Map<String, dynamic> body) async {
    if (!isAuthenticated) {
      await ensureAuthenticated();
    }

    debugPrint('[ApiService] 🚀 POST $uri (auth: ${isAuthenticated ? "token present" : "no token"})');
    try {
      var res = await _client.post(
        uri,
        headers: _headers,
        body: jsonEncode(body),
      );
      debugPrint('[ApiService] 📥 Response ${res.statusCode} from $uri (${res.bodyBytes.length} bytes)');

      // If 401 Unauthorized (expired or invalidated token), clear stale token, re-auth and retry once
      if (res.statusCode == 401) {
        debugPrint('[ApiService] ⚠️ Received 401. Re-authenticating and retrying once...');
        clearAuth();
        await ensureAuthenticated();
        res = await _client.post(
          uri,
          headers: _headers,
          body: jsonEncode(body),
        );
        debugPrint('[ApiService] 📥 Retry response ${res.statusCode} from $uri');
      }

      return res;
    } catch (e) {
      debugPrint('[ApiService] ❌ Network connection failure for $uri: $e');
      rethrow;
    }
  }

  /// Internal helper to execute authenticated GET requests with automatic 401 recovery retry.
  Future<http.Response> _getAuthenticated(Uri uri) async {
    if (!isAuthenticated) {
      await ensureAuthenticated();
    }

    debugPrint('[ApiService] 🚀 GET $uri (auth: ${isAuthenticated ? "token present" : "no token"})');
    try {
      var res = await _client.get(uri, headers: _headers);
      debugPrint('[ApiService] 📥 Response ${res.statusCode} from $uri');

      if (res.statusCode == 401) {
        debugPrint('[ApiService] ⚠️ Received 401. Re-authenticating and retrying once...');
        clearAuth();
        await ensureAuthenticated();
        res = await _client.get(uri, headers: _headers);
        debugPrint('[ApiService] 📥 Retry response ${res.statusCode} from $uri');
      }

      return res;
    } catch (e) {
      debugPrint('[ApiService] ❌ Network connection failure for $uri: $e');
      rethrow;
    }
  }

  // Auth
  Future<Map<String, dynamic>> loginAnonymously({String? deviceId, String? name}) async {
    final devId = deviceId ?? getOrCreateDeviceId();
    final res = await _client.post(
      Uri.parse('$baseUrl/auth/anonymous'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'device_id': devId,
        'name': name ?? 'Guest User',
      }),
    );
    final data = jsonDecode(utf8.decode(res.bodyBytes));
    if (res.statusCode == 200) {
      setToken(data['token']);
      if (data['user'] != null) {
        setUser(data['user']);
      }
      return data;
    }
    throw Exception(data['detail'] ?? 'Anonymous login failed');
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await _client.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    final data = jsonDecode(utf8.decode(res.bodyBytes));
    if (res.statusCode == 200) {
      setToken(data['token']);
      if (data['user'] != null) {
        setUser(data['user']);
      }
      return data;
    }
    throw Exception(data['detail'] ?? 'Login failed');
  }

  Future<Map<String, dynamic>> register(String name, String email, String password) async {
    final res = await _client.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'email': email, 'password': password}),
    );
    final data = jsonDecode(utf8.decode(res.bodyBytes));
    if (res.statusCode == 201) {
      setToken(data['token']);
      if (data['user'] != null) {
        setUser(data['user']);
      }
      return data;
    }
    throw Exception(data['detail'] ?? 'Registration failed');
  }

  // AI Endpoints
  Future<Map<String, dynamic>> parseVoiceIntent(String text, {int? dependentId}) async {
    final res = await _postAuthenticated(
      Uri.parse('$baseUrl/ai/parse-intent'),
      {
        'text': text,
        if (dependentId != null) 'dependent_id': dependentId,
      },
    );
    final data = jsonDecode(utf8.decode(res.bodyBytes));
    if (res.statusCode != 200) {
      throw Exception(data['detail'] ?? 'Voice intent parsing failed');
    }
    return data;
  }

  Future<Map<String, dynamic>> scanPrescription(String filePath, {int? dependentId}) async {
    if (!isAuthenticated) {
      await ensureAuthenticated();
    }

    final uri = Uri.parse('$baseUrl/ai/scan-prescription');
    final request = http.MultipartRequest('POST', uri);
    
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    if (dependentId != null) {
      request.fields['dependent_id'] = dependentId.toString();
    }
    request.files.add(await http.MultipartFile.fromPath('file', filePath));

    final streamedResponse = await _client.send(request);
    final response = await http.Response.fromStream(streamedResponse);
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode != 200) {
      throw Exception(data['detail'] ?? 'Prescription scan failed');
    }
    return data;
  }

  Future<Map<String, dynamic>> sendHealthChat(String query, {int? dependentId, List<Map<String, String>>? history}) async {
    final res = await _postAuthenticated(
      Uri.parse('$baseUrl/ai/chat'),
      {
        'query': query,
        if (dependentId != null) 'dependent_id': dependentId,
        'conversation_history': history ?? [],
      },
    );
    final data = jsonDecode(utf8.decode(res.bodyBytes));
    if (res.statusCode != 200) {
      throw Exception(data['detail'] ?? 'Chat request failed with status ${res.statusCode}');
    }
    return data;
  }

  // Medications
  Future<List<dynamic>> getMedications({int? dependentId}) async {
    final url = dependentId != null 
        ? '$baseUrl/medications?dependent_id=$dependentId'
        : '$baseUrl/medications';
    final res = await _getAuthenticated(Uri.parse(url));
    if (res.statusCode == 200) {
      return jsonDecode(utf8.decode(res.bodyBytes));
    }
    return [];
  }

  Future<Map<String, dynamic>> createMedication(Map<String, dynamic> data) async {
    final res = await _postAuthenticated(
      Uri.parse('$baseUrl/medications'),
      data,
    );
    final resData = jsonDecode(utf8.decode(res.bodyBytes));
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception(resData['detail'] ?? 'Create medication failed');
    }
    return resData;
  }

  Future<List<dynamic>> getTodayDoses({int? dependentId}) async {
    final url = dependentId != null
        ? '$baseUrl/medications/doses/today?dependent_id=$dependentId'
        : '$baseUrl/medications/doses/today';
    final res = await _getAuthenticated(Uri.parse(url));
    if (res.statusCode == 200) {
      return jsonDecode(utf8.decode(res.bodyBytes));
    }
    return [];
  }

  Future<Map<String, dynamic>> takeDose(int doseId) async {
    final res = await _postAuthenticated(
      Uri.parse('$baseUrl/medications/doses/$doseId/take'),
      {},
    );
    final resData = jsonDecode(utf8.decode(res.bodyBytes));
    if (res.statusCode != 200) {
      throw Exception(resData['detail'] ?? 'Take dose failed');
    }
    return resData;
  }

  Future<Map<String, dynamic>> undoDose(int doseId) async {
    final res = await _postAuthenticated(
      Uri.parse('$baseUrl/medications/doses/$doseId/undo'),
      {},
    );
    final resData = jsonDecode(utf8.decode(res.bodyBytes));
    if (res.statusCode != 200) {
      throw Exception(resData['detail'] ?? 'Undo dose failed');
    }
    return resData;
  }

  /// Checks the health and liveness of the backend API.
  Future<BackendHealth> checkHealth({Duration timeout = const Duration(seconds: 4)}) async {
    final url = '$baseUrl/health';
    final uri = Uri.parse(url);
    final stopwatch = Stopwatch()..start();

    debugPrint('[ApiService] 🔍 checkHealth calling $uri');
    try {
      final res = await _client.get(uri).timeout(timeout);
      stopwatch.stop();
      final latencyMs = stopwatch.elapsedMilliseconds;
      debugPrint('[ApiService] 📥 checkHealth response ${res.statusCode} (${latencyMs}ms)');

      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        final health = BackendHealth.fromJson(data, latencyMs: latencyMs, targetUrl: url);
        lastKnownHealth.value = health;
        return health;
      } else {
        final health = BackendHealth.offline(
          errorMessage: 'HTTP ${res.statusCode}: ${res.reasonPhrase}',
          latencyMs: latencyMs,
          targetUrl: url,
        );
        lastKnownHealth.value = health;
        return health;
      }
    } catch (e) {
      stopwatch.stop();
      debugPrint('[ApiService] ❌ checkHealth failed for $uri: $e');
      final health = BackendHealth.offline(
        errorMessage: e.toString(),
        latencyMs: stopwatch.elapsedMilliseconds,
        targetUrl: url,
      );
      lastKnownHealth.value = health;
      return health;
    }
  }
}
