import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/backend_health.dart';
import '../services/api_service.dart';
import 'app_providers.dart';

/// StateNotifier that polls and tracks backend health, liveness, and latency.
class BackendHealthNotifier extends StateNotifier<BackendHealth> {
  final ApiService _apiService;
  Timer? _pollingTimer;
  VoidCallback? _healthListenerRemover;

  BackendHealthNotifier(this._apiService, {bool autoPoll = false})
      : super(
          _apiService.lastKnownHealth.value ??
              BackendHealth.checking(targetUrl: _apiService.baseUrl),
        ) {
    void onHealthUpdate() {
      final h = _apiService.lastKnownHealth.value;
      if (h != null && mounted) {
        state = h;
      }
    }

    _apiService.lastKnownHealth.addListener(onHealthUpdate);
    _healthListenerRemover = () => _apiService.lastKnownHealth.removeListener(onHealthUpdate);

    refreshHealth();

    if (autoPoll && kDebugMode) {
      _pollingTimer = Timer.periodic(const Duration(seconds: 20), (_) => refreshHealth());
    }
  }

  /// Manually marks the backend as healthy with known roundtrip latency.
  void markHealthy({int? latencyMs}) {
    final updated = BackendHealth(
      status: 'healthy',
      latencyMs: latencyMs ?? state.latencyMs,
      targetUrl: _apiService.baseUrl,
      service: state.service ?? 'gobi-backend-api',
      dbStatus: state.dbStatus ?? 'connected',
      aiStatus: state.aiStatus ?? 'ready',
      aiModel: state.aiModel,
    );
    _apiService.lastKnownHealth.value = updated;
    if (mounted) {
      state = updated;
    }
  }

  /// Forces an immediate health check ping against the backend.
  Future<void> refreshHealth() async {
    try {
      final health = await _apiService.checkHealth();
      if (mounted) {
        state = health;
      }
    } catch (e) {
      if (mounted) {
        state = BackendHealth.offline(
          errorMessage: e.toString(),
          targetUrl: _apiService.baseUrl,
        );
      }
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _healthListenerRemover?.call();
    super.dispose();
  }
}

/// Provider for active backend health state and diagnostics.
final backendHealthProvider =
    StateNotifierProvider.autoDispose<BackendHealthNotifier, BackendHealth>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return BackendHealthNotifier(apiService, autoPoll: false);
});
