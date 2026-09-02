import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../../data/repositories/medication_repository.dart';

final intentRouterServiceProvider = Provider<IntentRouterService>((ref) {
  throw UnimplementedError('Initialize with container overrides');
});

class IntentEvent {
  final String action;
  final Map<String, String> params;
  final String statusMessage;
  final dynamic resultData;
  final DateTime timestamp;

  IntentEvent({
    required this.action,
    required this.params,
    required this.statusMessage,
    this.resultData,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class IntentRouterService {
  final MedicationRepository _medicationRepository;
  final _appLinks = AppLinks();
  final _logger = Logger();
  StreamSubscription<Uri>? _sub;

  final _eventController = StreamController<IntentEvent>.broadcast();
  Stream<IntentEvent> get events => _eventController.stream;

  IntentRouterService(this._medicationRepository);

  /// Initializes deep link listeners for cold start and running app instances
  Future<void> init() async {
    try {
      // 1. Check if app was launched from a deep link (cold start)
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _logger.i('Initial deep link received: $initialUri');
        await handleUri(initialUri);
      }

      // 2. Listen to continuous deep link events while app is running
      _sub = _appLinks.uriLinkStream.listen((uri) async {
        _logger.i('Runtime deep link received: $uri');
        await handleUri(uri);
      }, onError: (err) {
        _logger.e('Error on uriLinkStream: $err');
      });
    } catch (e) {
      _logger.e('Failed to initialize AppLinks: $e');
    }
  }

  /// Parses and routes incoming voice action URIs
  Future<IntentEvent?> handleUri(Uri uri) async {
    final path = uri.path.replaceAll(RegExp(r'^/+|/+$'), '');
    final params = uri.queryParameters;
    _logger.i('Handling intent URI -> path: $path, params: $params');

    try {
      // Step 1: SET SCHEDULE
      // URI: gobi://intent/medication/set-schedule?name=vitamin+d&frequency=weekly&durationWeeks=6&dosage=1
      if (path == 'medication/set-schedule' || uri.host == 'medication' && path == 'set-schedule') {
        final name = params['name'] ?? 'Vitamin D';
        final freqRaw = (params['frequency'] ?? 'weekly').toLowerCase();
        final freqType = freqRaw.contains('week') ? 'weekly' : (freqRaw.contains('day') ? 'daily' : 'weekly');
        final durationWeeks = int.tryParse(params['durationWeeks'] ?? '6') ?? 6;
        final dosage = params['dosage'] ?? '1';

        final result = await _medicationRepository.setSchedule(
          name: name,
          frequencyType: freqType,
          durationWeeks: durationWeeks,
          dosage: dosage,
          unit: 'dose',
        );

        final event = IntentEvent(
          action: 'SET_SCHEDULE',
          params: params,
          statusMessage: result.summaryMessage,
          resultData: result,
        );
        _eventController.add(event);
        return event;
      }

      // Step 2: GET SCHEDULE / QUERY
      // URI: gobi://intent/medication/get-schedule?name=vit+d
      if (path == 'medication/get-schedule' || uri.host == 'medication' && path == 'get-schedule') {
        final name = params['name'] ?? 'Vitamin D';
        final statusResult = await _medicationRepository.getScheduleStatus(name: name);

        final event = IntentEvent(
          action: 'GET_SCHEDULE',
          params: params,
          statusMessage: statusResult['message'] as String,
          resultData: statusResult,
        );
        _eventController.add(event);
        return event;
      }

      // Step 3: RECORD DOSE
      // URI: gobi://intent/medication/record-dose?name=vit+d&status=taken
      if (path == 'medication/record-dose' || uri.host == 'medication' && path == 'record-dose') {
        final name = params['name'] ?? 'Vitamin D';
        final status = params['status'] ?? 'taken';

        final recordResult = await _medicationRepository.recordDose(
          name: name,
          status: status,
        );

        final event = IntentEvent(
          action: 'RECORD_DOSE',
          params: params,
          statusMessage: recordResult['message'] as String,
          resultData: recordResult,
        );
        _eventController.add(event);
        return event;
      }
    } catch (e, stack) {
      _logger.e('Error routing intent URI: $e', error: e, stackTrace: stack);
      final errorEvent = IntentEvent(
        action: 'ERROR',
        params: params,
        statusMessage: 'Error handling intent: $e',
      );
      _eventController.add(errorEvent);
      return errorEvent;
    }

    return null;
  }

  void dispose() {
    _sub?.cancel();
    _eventController.close();
  }
}
