import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class VoiceService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isInitialized = false;

  bool get isListening => _speech.isListening;
  bool get isInitialized => _isInitialized;

  Future<bool> init() async {
    if (_isInitialized) return true;
    try {
      _isInitialized = await _speech.initialize(
        onError: (err) => debugPrint('STT Error: $err'),
        onStatus: (status) => debugPrint('STT Status: $status'),
      );
      return _isInitialized;
    } catch (e) {
      debugPrint('STT init error: $e');
      return false;
    }
  }

  Future<bool> initialize() => init();

  Future<void> startListening({
    required Function(String text) onResult,
    Function(dynamic error)? onError,
    Function()? onDone,
  }) async {
    if (!_isInitialized) {
      final ok = await init();
      if (!ok) {
        onError?.call('Speech recognition unavailable');
        return;
      }
    }

    try {
      await _speech.listen(
        onResult: (result) {
          onResult(result.recognizedWords);
        },
        listenFor: const Duration(seconds: 15),
        pauseFor: const Duration(seconds: 3),
        cancelOnError: true,
        partialResults: true,
      );
    } catch (e) {
      onError?.call(e);
    }
  }

  Future<void> stopListening() async {
    if (_speech.isListening) {
      await _speech.stop();
    }
  }
}
