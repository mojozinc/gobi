import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gobi_mobile/core/services/api_service.dart';
import 'package:gobi_mobile/features/chat/screens/health_chat_screen.dart';

void main() {
  testWidgets('HealthChatScreen renders welcome message and quick prompt suggestions', (WidgetTester tester) async {
    final apiService = ApiService(baseUrl: 'http://127.0.0.1:8000/api/v1');

    await tester.pumpWidget(
      MaterialApp(
        home: HealthChatScreen(apiService: apiService),
      ),
    );

    // Verify initial UI elements
    expect(find.text('Health & RAG Chat'), findsOneWidget);
    expect(find.textContaining('Hello! I am your Gobi Health Assistant'), findsOneWidget);
    expect(find.text('What medications do I take today?'), findsOneWidget);
    expect(find.text('Did I take my morning dose?'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });
}
