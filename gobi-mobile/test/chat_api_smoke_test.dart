import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gobi_mobile/core/services/api_service.dart';

void main() {
  group('Chat API Smoke Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('sendHealthChat formats request and parses response successfully', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/v1/ai/chat');
        expect(request.headers['Authorization'], 'Bearer smoke-token');
        expect(request.headers['Content-Type'], 'application/json');

        final body = jsonDecode(request.body);
        expect(body['query'], 'What medications should I take today?');
        expect(body['conversation_history'], isEmpty);

        return http.Response(
          jsonEncode({
            'response': 'You have Metformin 500mg scheduled with breakfast.',
            'referenced_medications': ['Metformin 500mg'],
            'referenced_documents': []
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final api = ApiService(client: mockClient);
      api.setToken('smoke-token');

      final result = await api.sendHealthChat('What medications should I take today?');
      expect(result['response'], contains('Metformin 500mg'));
      expect(result['referenced_medications'], contains('Metformin 500mg'));
    });

    test('sendHealthChat transmits conversation history and dependentId', () async {
      final mockClient = MockClient((request) async {
        final body = jsonDecode(request.body);
        expect(body['query'], 'Can I take it before dinner?');
        expect(body['dependent_id'], 7);
        expect(body['conversation_history'], hasLength(2));
        expect(body['conversation_history'][0]['role'], 'user');
        expect(body['conversation_history'][0]['content'], 'Hello');
        expect(body['conversation_history'][1]['role'], 'assistant');

        return http.Response(
          jsonEncode({
            'response': 'Yes, take Metformin with food to minimize nausea.',
            'referenced_medications': [],
            'referenced_documents': []
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final api = ApiService(client: mockClient);
      api.setToken('smoke-token');

      final history = [
        {'role': 'user', 'content': 'Hello'},
        {'role': 'assistant', 'content': 'Hi there! How can I help?'}
      ];

      final result = await api.sendHealthChat(
        'Can I take it before dinner?',
        dependentId: 7,
        history: history,
      );

      expect(result['response'], contains('take Metformin with food'));
    });
  });
}
