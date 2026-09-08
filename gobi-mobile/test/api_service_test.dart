import 'package:flutter_test/flutter_test.dart';
import 'package:gobi_mobile/core/services/api_service.dart';

void main() {
  group('ApiService Tests', () {
    test('instantiates with default baseUrl and token management', () {
      final api = ApiService();
      expect(api.baseUrl, 'http://127.0.0.1:8000/api/v1');
      expect(api.token, isNull);

      api.setToken('test-jwt-token');
      expect(api.token, 'test-jwt-token');
    });

    test('instantiates with custom baseUrl', () {
      final api = ApiService(baseUrl: 'https://api.gobi.health/v1');
      expect(api.baseUrl, 'https://api.gobi.health/v1');
    });
  });
}
