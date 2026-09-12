/// Model representing the backend API health, diagnostic metadata, and network roundtrip latency.
class BackendHealth {
  final String status; // 'healthy' | 'degraded' | 'offline' | 'checking'
  final int? latencyMs;
  final String? service;
  final String? env;
  final String? version;
  final String? dbStatus;
  final String? dbError;
  final String? aiStatus;
  final String? aiProvider;
  final String? aiModel;
  final DateTime? serverTimestamp;
  final DateTime checkedAt;
  final String? errorMessage;
  final String? targetUrl;

  BackendHealth({
    required this.status,
    this.latencyMs,
    this.service,
    this.env,
    this.version,
    this.dbStatus,
    this.dbError,
    this.aiStatus,
    this.aiProvider,
    this.aiModel,
    this.serverTimestamp,
    DateTime? checkedAt,
    this.errorMessage,
    this.targetUrl,
  }) : checkedAt = checkedAt ?? DateTime.now();

  bool get isHealthy => status == 'healthy';
  bool get isChecking => status == 'checking';
  bool get isOffline => status == 'offline';
  bool get isDegraded => status == 'degraded';

  factory BackendHealth.checking({String? targetUrl}) {
    return BackendHealth(
      status: 'checking',
      targetUrl: targetUrl,
    );
  }

  factory BackendHealth.offline({
    String? errorMessage,
    int? latencyMs,
    String? targetUrl,
  }) {
    return BackendHealth(
      status: 'offline',
      errorMessage: errorMessage,
      latencyMs: latencyMs,
      targetUrl: targetUrl,
    );
  }

  factory BackendHealth.fromJson(
    Map<String, dynamic> json, {
    int? latencyMs,
    String? targetUrl,
  }) {
    final db = json['database'] as Map<String, dynamic>?;
    final ai = json['ai'] as Map<String, dynamic>?;

    DateTime? parsedTs;
    if (json['timestamp'] != null) {
      try {
        parsedTs = DateTime.parse(json['timestamp'] as String);
      } catch (_) {}
    }

    return BackendHealth(
      status: (json['status'] as String?) ?? 'healthy',
      latencyMs: latencyMs,
      service: json['service'] as String?,
      env: json['env'] as String?,
      version: json['version'] as String?,
      dbStatus: db?['status'] as String?,
      dbError: db?['error'] as String?,
      aiStatus: ai?['status'] as String?,
      aiProvider: ai?['provider'] as String?,
      aiModel: ai?['model'] as String?,
      serverTimestamp: parsedTs,
      targetUrl: targetUrl,
    );
  }

  Map<String, dynamic> toJson() => {
        'status': status,
        'latency_ms': latencyMs,
        'service': service,
        'env': env,
        'version': version,
        'database': {
          'status': dbStatus,
          'error': dbError,
        },
        'ai': {
          'status': aiStatus,
          'provider': aiProvider,
          'model': aiModel,
        },
        'server_timestamp': serverTimestamp?.toIso8601String(),
        'checked_at': checkedAt.toIso8601String(),
        'error_message': errorMessage,
        'target_url': targetUrl,
      };
}
