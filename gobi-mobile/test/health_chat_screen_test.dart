import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:gobi_mobile/core/providers/app_providers.dart';
import 'package:gobi_mobile/core/services/api_service.dart';
import 'package:gobi_mobile/features/chat/screens/health_chat_screen.dart';

void main() {
  testWidgets('HealthChatScreen renders welcome message and quick prompt suggestions', (WidgetTester tester) async {
    final apiService = ApiService(baseUrl: 'http://127.0.0.1:8000/api/v1');

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: HealthChatScreen(apiService: apiService),
        ),
      ),
    );

    // Verify initial UI elements
    expect(find.text('Health & RAG Chat'), findsOneWidget);
    expect(find.byType(MarkdownBody), findsOneWidget);
    expect(find.textContaining('Hello! I am your Gobi Health Assistant'), findsOneWidget);
    expect(find.text('What medications do I take today?'), findsOneWidget);
    expect(find.text('Did I take my morning dose?'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byIcon(Icons.refresh), findsOneWidget);
  });

  testWidgets('HealthChatScreen renders assistant messages with formatted Markdown', (WidgetTester tester) async {
    final apiService = ApiService(baseUrl: 'http://127.0.0.1:8000/api/v1');
    final container = ProviderContainer();

    // Add a rich markdown response
    container.read(chatMessagesProvider.notifier).addMessage(
          ChatMessage(
            text: '# Medication Guide\n**Amoxicillin 500mg**:\n- Take 3 times daily\n- Finish the entire course',
            isUser: false,
          ),
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: HealthChatScreen(apiService: apiService),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify MarkdownBody rendered for assistant message
    expect(find.byType(MarkdownBody), findsNWidgets(2)); // Welcome message + new message
    expect(find.textContaining('Medication Guide'), findsOneWidget);
    expect(find.textContaining('Amoxicillin 500mg'), findsOneWidget);
  });

  testWidgets('New Chat button clears user chat messages and resets conversation', (WidgetTester tester) async {
    final apiService = ApiService(baseUrl: 'http://127.0.0.1:8000/api/v1');
    final container = ProviderContainer();

    container.read(chatMessagesProvider.notifier).addMessage(
          ChatMessage(text: 'Can I take ibuprofen with amoxicillin?', isUser: true),
        );
    container.read(chatMessagesProvider.notifier).addMessage(
          ChatMessage(text: 'Yes, but take ibuprofen with food.', isUser: false),
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: HealthChatScreen(apiService: apiService),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify message is visible
    expect(find.text('Can I take ibuprofen with amoxicillin?'), findsOneWidget);

    // Tap New Chat / Clear
    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify conversation reset
    expect(find.text('Can I take ibuprofen with amoxicillin?'), findsNothing);
    expect(find.textContaining('Hello! I am your Gobi Health Assistant'), findsOneWidget);

    // Clean up snackbar
    ScaffoldMessenger.of(tester.element(find.byType(HealthChatScreen))).removeCurrentSnackBar();
    await tester.pump(const Duration(milliseconds: 100));
  });
}
