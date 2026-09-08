import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gobi_mobile/core/services/api_service.dart';

void main() {
  group('ApiService Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('instantiates with default baseUrl and token management', () async {
      final prefs = await SharedPreferences.getInstance();
      final api = ApiService(prefs: prefs);
      expect(api.baseUrl, 'http://127.0.0.1:8000/api/v1');
      expect(api.token, isNull);
      expect(api.isAuthenticated, isFalse);

      api.setToken('test-jwt-token');
      expect(api.token, 'test-jwt-token');
      expect(api.isAuthenticated, isTrue);

      api.clearAuth();
      expect(api.token, isNull);
      expect(api.isAuthenticated, isFalse);
    });

    test('reads token and user dynamically from SharedPreferences', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', 'shared-pref-token');
      await prefs.setString('user_data', jsonEncode({'id': 1, 'name': 'Test User', 'email': 'test@gobi.local'}));

      final api = ApiService(prefs: prefs);
      expect(api.token, 'shared-pref-token');
      expect(api.currentUser?['name'], 'Test User');
    });

    test('parseVoiceIntent calls correct endpoint with Bearer auth', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/v1/ai/parse-intent');
        expect(request.headers['Authorization'], 'Bearer my-token');
        final body = jsonDecode(request.body);
        expect(body['text'], 'take metformin');
        return http.Response(
          jsonEncode({
            'action': 'RECORD_DOSE',
            'record_dose_data': {'name': 'Metformin', 'status': 'taken'},
            'message': 'Recorded dose for Metformin'
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final api = ApiService(client: mockClient);
      api.setToken('my-token');

      final result = await api.parseVoiceIntent('take metformin');
      expect(result['action'], 'RECORD_DOSE');
      expect(result['record_dose_data']['name'], 'Metformin');
    });

    test('takeDose and undoDose execute correctly', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/v1/medications/doses/42/take') {
          return http.Response(
            jsonEncode({'id': 42, 'status': 'taken', 'medication_name': 'Vitamin D'}),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        } else if (request.url.path == '/api/v1/medications/doses/42/undo') {
          return http.Response(
            jsonEncode({'id': 42, 'status': 'pending', 'medication_name': 'Vitamin D'}),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response('Not found', 404);
      });

      final api = ApiService(client: mockClient);
      api.setToken('tok');

      final taken = await api.takeDose(42);
      expect(taken['status'], 'taken');

      final undone = await api.undoDose(42);
      expect(undone['status'], 'pending');
    });
  });
}
