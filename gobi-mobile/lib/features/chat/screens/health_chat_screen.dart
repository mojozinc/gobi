import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/dev/dev_only.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/providers/dev_providers.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/voice_service.dart';
import '../widgets/dev_server_status_chip.dart';

class HealthChatScreen extends ConsumerStatefulWidget {
  final ApiService apiService;
  final int? dependentId;

  const HealthChatScreen({
    super.key,
    required this.apiService,
    this.dependentId,
  });

  @override
  ConsumerState<HealthChatScreen> createState() => _HealthChatScreenState();
}

class _HealthChatScreenState extends ConsumerState<HealthChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final VoiceService _voiceService = VoiceService();
  bool _isLoading = false;
  bool _isListening = false;

  final List<String> _quickSuggestions = [
    'What medications do I take today?',
    'Did I take my morning dose?',
    'Summarize my prescription schedule',
    'Any instructions for my meds?',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(backendHealthProvider.notifier).refreshHealth();
    });
  }

  @override
  void dispose() {
    _voiceService.stopListening();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _clearChat() {
    ref.read(chatMessagesProvider.notifier).reset();
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Chat conversation reset.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _toggleMic() async {
    if (_isListening) {
      await _voiceService.stopListening();
      setState(() {
        _isListening = false;
      });
    } else {
      final available = await _voiceService.initialize();
      if (!available) {
        if (mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Speech recognition not available.'),
              duration: Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      setState(() {
        _isListening = true;
      });

      await _voiceService.startListening(
        onResult: (words) {
          if (mounted) {
            setState(() {
              _textController.text = words;
            });
          }
        },
        onError: (err) {
          if (mounted) {
            setState(() {
              _isListening = false;
            });
          }
        },
      );
    }
  }

  void _onTapUserMessage(String query) {
    // If last message was an error for this query, retry immediately
    final messages = ref.read(chatMessagesProvider);
    if (messages.isNotEmpty && messages.last.isError && messages.last.failedQuery == query) {
      _sendMessage(query, true);
      return;
    }
    // Otherwise populate the input field for easy editing
    setState(() {
      _textController.text = query;
      _textController.selection = TextSelection.fromPosition(
        TextPosition(offset: _textController.text.length),
      );
    });
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Loaded "$query" into input field.'),
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: 'Send',
          onPressed: () => _sendMessage(query),
        ),
      ),
    );
  }

  Future<void> _sendMessage([String? promptText, bool isRetry = false]) async {
    final text = promptText ?? _textController.text.trim();
    if (text.isEmpty || _isLoading) return;

    if (_isListening) {
      await _voiceService.stopListening();
      setState(() {
        _isListening = false;
      });
    }

    if (isRetry) {
      ref.read(chatMessagesProvider.notifier).removeLastIfError();
    } else {
      _textController.clear();
      ref.read(chatMessagesProvider.notifier).addMessage(
            ChatMessage(text: text, isUser: true),
          );
    }

    setState(() {
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      final currentMessages = ref.read(chatMessagesProvider);
      final history = currentMessages
          .where((m) => m != currentMessages.first && !m.isError) // exclude initial greeting & errors
          .map((m) => m.toApiMap())
          .toList();

      final stopwatch = Stopwatch()..start();
      final res = await widget.apiService.sendHealthChat(
        text,
        dependentId: widget.dependentId,
        history: history,
      );
      stopwatch.stop();

      final reply = res['response'] as String? ?? 'No response received.';

      if (mounted) {
        ref.read(backendHealthProvider.notifier).markHealthy(latencyMs: stopwatch.elapsedMilliseconds);
        ref.read(chatMessagesProvider.notifier).addMessage(
              ChatMessage(text: reply, isUser: false),
            );
        setState(() {
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        ref.read(chatMessagesProvider.notifier).addMessage(
              ChatMessage(
                text: 'Unable to reach health assistant: $e',
                isUser: false,
                isError: true,
                failedQuery: text,
              ),
            );
        setState(() {
          _isLoading = false;
        });
        _scrollToBottom();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatMessagesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.psychology_outlined, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Health & RAG Chat', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text('Context-aware AI assistant', style: TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ],
        ),
        actions: [
          DevOnly(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
              child: DevServerStatusChip(apiService: widget.apiService),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'New Chat / Clear',
            onPressed: _clearChat,
          ),
        ],
      ),
      body: Column(
        children: [
          // Chat Messages List
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[index];
                return _ChatBubble(
                  message: msg,
                  onRetry: (query) => _sendMessage(query, true),
                  onTapUserMessage: (query) => _onTapUserMessage(query),
                );
              },
            ),
          ),

          // Typing Indicator
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Gobi AI is reasoning over your health records...',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),

          // Quick Suggestion Chips (when only 1 or 2 messages)
          if (messages.length <= 2)
            Container(
              height: 40,
              margin: const EdgeInsets.only(bottom: 8),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _quickSuggestions.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, idx) {
                  return ActionChip(
                    label: Text(
                      _quickSuggestions[idx],
                      style: const TextStyle(fontSize: 12),
                    ),
                    onPressed: () => _sendMessage(_quickSuggestions[idx]),
                    backgroundColor: Colors.white,
                    side: BorderSide(color: Colors.grey.shade300),
                  );
                },
              ),
            ),

          // Bottom Input Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  // Mic button
                  IconButton(
                    icon: Icon(
                      _isListening ? Icons.mic : Icons.mic_none,
                      color: _isListening ? AppColors.error : AppColors.primary,
                    ),
                    onPressed: _toggleMic,
                  ),
                  // Text input
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      decoration: InputDecoration(
                        hintText: _isListening ? 'Listening...' : 'Ask about your meds, doses, or scans...',
                        hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Send button
                  IconButton.filled(
                    onPressed: _isLoading ? null : () => _sendMessage(),
                    icon: const Icon(Icons.send, size: 18),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final void Function(String query)? onRetry;
  final void Function(String query)? onTapUserMessage;

  const _ChatBubble({
    required this.message,
    this.onRetry,
    this.onTapUserMessage,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final isError = message.isError;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser)
            Container(
              margin: const EdgeInsets.only(right: 8, top: 2),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isError
                    ? AppColors.error.withOpacity(0.12)
                    : AppColors.primary.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isError ? Icons.error_outline : Icons.auto_awesome,
                color: isError ? AppColors.error : AppColors.primary,
                size: 16,
              ),
            ),
          Flexible(
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: isError
                  ? () => onRetry?.call(message.failedQuery ?? '')
                  : isUser
                      ? () => onTapUserMessage?.call(message.text)
                      : null,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isUser
                      ? AppColors.primary
                      : isError
                          ? const Color(0xFFFFF2F0)
                          : Colors.grey.shade100,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isUser ? 16 : 4),
                    bottomRight: Radius.circular(isUser ? 4 : 16),
                  ),
                  border: isError
                      ? Border.all(color: const Color(0xFFFFCCC7), width: 1.2)
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    if (isUser)
                      Text(
                        message.text,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          height: 1.35,
                        ),
                      )
                    else if (isError) ...[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'Delivery Failed',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        message.text,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.red.shade900,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Retry action pill button
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => onRetry?.call(message.failedQuery ?? ''),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.error.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.error.withOpacity(0.3)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.refresh, size: 14, color: AppColors.error),
                                SizedBox(width: 6),
                                Text(
                                  'Tap to retry',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.error,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ] else
                      MarkdownBody(
                        data: message.text,
                        styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                          p: const TextStyle(fontSize: 14, height: 1.45, color: Colors.black87),
                          strong: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                          listBullet: const TextStyle(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.bold),
                          h1: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black87),
                          h2: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold, color: Colors.black87),
                          h3: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: Colors.black87),
                          code: TextStyle(backgroundColor: Colors.grey.shade200, fontSize: 12.5, fontFamily: 'monospace'),
                          codeblockDecoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          blockSpacing: 8.0,
                        ),
                      ),
                    const SizedBox(height: 6),
                    Text(
                      '${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        color: isUser
                            ? Colors.white70
                            : isError
                                ? Colors.red.shade400
                                : Colors.grey.shade500,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
