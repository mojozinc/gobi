import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:gobi_mobile/core/dev/dev_only.dart';
import 'package:gobi_mobile/core/models/backend_health.dart';
import 'package:gobi_mobile/core/providers/app_providers.dart';
import 'package:gobi_mobile/core/services/api_service.dart';
import 'package:gobi_mobile/features/chat/widgets/dev_server_status_chip.dart';
import 'package:gobi_mobile/features/chat/widgets/dev_diagnostics_sheet.dart';

void main() {
  group('DevOnly Widget', () {
    testWidgets('renders child when enabled is true in debug mode', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DevOnly(
              child: Text('Debug Only Secret Tool'),
            ),
          ),
        ),
      );

      expect(find.text('Debug Only Secret Tool'), findsOneWidget);
    });

    testWidgets('renders fallback when enabled is false', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DevOnly(
              enabled: false,
              fallback: Text('Production View'),
              child: Text('Debug Only Secret Tool'),
            ),
          ),
        ),
      );

      expect(find.text('Debug Only Secret Tool'), findsNothing);
      expect(find.text('Production View'), findsOneWidget);
    });
  });

  group('BackendHealth Model', () {
    test('parses rich health JSON correctly', () {
      final json = {
        'status': 'healthy',
        'service': 'gobi-backend-api',
        'env': 'development',
        'version': '0.1.0',
        'timestamp': '2026-09-12T05:48:38.340387+00:00',
        'database': {'status': 'connected', 'error': null},
        'ai': {
          'status': 'ready',
          'provider': 'openrouter',
          'model': 'meta-llama/llama-3.3-70b-instruct'
        }
      };

      final health = BackendHealth.fromJson(json, latencyMs: 24, targetUrl: 'http://127.0.0.1:8000/api/v1');

      expect(health.isHealthy, isTrue);
      expect(health.isOffline, isFalse);
      expect(health.isDegraded, isFalse);
      expect(health.latencyMs, equals(24));
      expect(health.service, equals('gobi-backend-api'));
      expect(health.dbStatus, equals('connected'));
      expect(health.aiStatus, equals('ready'));
      expect(health.aiModel, equals('meta-llama/llama-3.3-70b-instruct'));
      expect(health.targetUrl, equals('http://127.0.0.1:8000/api/v1'));
    });

    test('creates offline health state on connection error', () {
      final offline = BackendHealth.offline(
        errorMessage: 'Connection refused',
        latencyMs: 15,
        targetUrl: 'http://192.168.0.111:8000',
      );

      expect(offline.isHealthy, isFalse);
      expect(offline.isOffline, isTrue);
      expect(offline.errorMessage, contains('Connection refused'));
      expect(offline.latencyMs, equals(15));
    });
  });

  group('ApiService.checkHealth', () {
    test('returns healthy BackendHealth on HTTP 200', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/health')) {
          return http.Response(
            jsonEncode({
              'status': 'healthy',
              'service': 'gobi-backend-api',
              'env': 'development',
              'database': {'status': 'connected'},
              'ai': {'status': 'ready', 'model': 'meta-llama/llama-3.3-70b-instruct'}
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final apiService = ApiService(baseUrl: 'http://127.0.0.1:8000', client: mockClient);
      final health = await apiService.checkHealth();

      expect(health.isHealthy, isTrue);
      expect(health.dbStatus, equals('connected'));
      expect(health.aiModel, equals('meta-llama/llama-3.3-70b-instruct'));
    });

    test('returns offline BackendHealth gracefully when client throws', () async {
      final mockClient = MockClient((request) async {
        throw http.ClientException('Network unreachable');
      });

      final apiService = ApiService(baseUrl: 'http://127.0.0.1:8000', client: mockClient);
      final health = await apiService.checkHealth();

      expect(health.isOffline, isTrue);
      expect(health.errorMessage, contains('Network unreachable'));
    });
  });

  group('DevServerStatusChip & DevDiagnosticsSheet', () {
    testWidgets('renders healthy chip with latency and opens diagnostics sheet on tap', (WidgetTester tester) async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'status': 'healthy',
            'service': 'gobi-backend-api',
            'env': 'development',
            'version': '0.1.0',
            'database': {'status': 'connected'},
            'ai': {'status': 'ready', 'model': 'meta-llama/llama-3.3-70b-instruct'}
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiService = ApiService(baseUrl: 'http://127.0.0.1:8000/api/v1', client: mockClient);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiServiceProvider.overrideWithValue(apiService),
          ],
          child: MaterialApp(
            home: Scaffold(
              appBar: AppBar(
                actions: [
                  DevServerStatusChip(apiService: apiService),
                ],
              ),
              body: const Text('Main Body'),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle();

      // Tap on the chip to open diagnostics sheet
      expect(find.byType(DevServerStatusChip), findsOneWidget);
      await tester.tap(find.byType(DevServerStatusChip));
      await tester.pumpAndSettle();

      // Verify diagnostics bottom sheet contents
      expect(find.byType(DevDiagnosticsSheet), findsOneWidget);
      expect(find.text('DEV DIAGNOSTICS'), findsOneWidget);
      expect(find.text('Endpoint & Server Diagnostics'), findsOneWidget);
      expect(find.text('Client Auth & Session State'), findsOneWidget);
      expect(find.text('Re-Auth Guest'), findsOneWidget);
      expect(find.text('Copy JSON'), findsOneWidget);
    });
  });
}
