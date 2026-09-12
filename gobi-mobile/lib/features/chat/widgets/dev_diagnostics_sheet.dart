import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/app_config.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/backend_health.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/providers/dev_providers.dart';
import '../../../core/services/api_service.dart';

/// Modal bottom sheet showing developer-centric backend diagnostics and network details.
class DevDiagnosticsSheet extends ConsumerStatefulWidget {
  final ApiService? apiService;

  const DevDiagnosticsSheet({super.key, this.apiService});

  static Future<void> show(BuildContext context, {ApiService? apiService}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DevDiagnosticsSheet(apiService: apiService),
    );
  }

  @override
  ConsumerState<DevDiagnosticsSheet> createState() => _DevDiagnosticsSheetState();
}

class _DevDiagnosticsSheetState extends ConsumerState<DevDiagnosticsSheet> {
  bool _isRefreshing = false;
  String? _actionFeedback;

  Future<void> _pingServer() async {
    setState(() {
      _isRefreshing = true;
      _actionFeedback = null;
    });
    try {
      await ref.read(backendHealthProvider.notifier).refreshHealth();
      if (mounted) {
        setState(() {
          _isRefreshing = false;
          _actionFeedback = 'Ping completed.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
          _actionFeedback = 'Ping failed: $e';
        });
      }
    }
  }

  Future<void> _reauthGuest() async {
    setState(() {
      _isRefreshing = true;
      _actionFeedback = null;
    });
    try {
      final ApiService api = widget.apiService ?? ref.read(apiServiceProvider);
      await api.loginAnonymously();
      // Also update authStateProvider if available
      ref.invalidate(authStateProvider);
      if (mounted) {
        setState(() {
          _isRefreshing = false;
          _actionFeedback = 'Re-authenticated anonymous session.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
          _actionFeedback = 'Re-auth failed: $e';
        });
      }
    }
  }

  void _copyToClipboard(String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied $label to clipboard'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final health = ref.watch(backendHealthProvider);
    final ApiService api = widget.apiService ?? ref.watch(apiServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color statusColor;
    String statusTitle;
    IconData statusIcon;

    if (health.isHealthy) {
      statusColor = AppColors.success;
      statusTitle = 'Backend Healthy (${health.latencyMs ?? 0}ms)';
      statusIcon = Icons.check_circle_outline;
    } else if (health.isDegraded) {
      statusColor = AppColors.warning;
      statusTitle = 'Backend Degraded';
      statusIcon = Icons.warning_amber_rounded;
    } else if (health.isChecking) {
      statusColor = Colors.blue;
      statusTitle = 'Checking Connection...';
      statusIcon = Icons.sync;
    } else {
      statusColor = AppColors.error;
      statusTitle = 'Backend Offline';
      statusIcon = Icons.error_outline;
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, -2))
        ],
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'DEV DIAGNOSTICS',
                    style: TextStyle(
                      color: Colors.purple,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Main Status Banner Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: statusColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(statusIcon, color: statusColor, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          statusTitle,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Target: ${api.baseUrl}',
                          style: TextStyle(
                            color: isDark ? Colors.grey[400] : Colors.grey[700],
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _isRefreshing ? Icons.hourglass_top : Icons.refresh,
                      color: statusColor,
                      size: 22,
                    ),
                    tooltip: 'Ping Health Check',
                    onPressed: _isRefreshing ? null : _pingServer,
                  ),
                ],
              ),
            ),

            if (_actionFeedback != null) ...[
              const SizedBox(height: 8),
              Text(
                _actionFeedback!,
                style: const TextStyle(fontSize: 12, color: Colors.blueAccent),
              ),
            ],

            const SizedBox(height: 16),
            const Text(
              'Endpoint & Server Diagnostics',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 8),

            // Diagnostic items
            _DiagnosticTile(
              label: 'Resolved Base URL',
              value: AppConfig.apiBaseUrl,
              isMonospace: true,
              onCopy: () => _copyToClipboard('Base URL', AppConfig.apiBaseUrl),
            ),
            _DiagnosticTile(
              label: 'Roundtrip Latency',
              value: health.latencyMs != null ? '${health.latencyMs} ms' : 'N/A',
            ),
            _DiagnosticTile(
              label: 'Database Status',
              value: health.dbStatus ?? (health.isOffline ? 'Unreachable' : 'Unknown'),
              statusColor: health.dbStatus == 'connected' ? AppColors.success : null,
            ),
            _DiagnosticTile(
              label: 'AI Service & Model',
              value: health.aiModel != null
                  ? '${health.aiModel} (${health.aiProvider ?? "Ready"})'
                  : (health.isOffline ? 'Unavailable' : 'Mock Mode'),
            ),
            _DiagnosticTile(
              label: 'Service & Env',
              value: '${health.service ?? "gobi-backend-api"} • ${health.env ?? "development"} (v${health.version ?? "0.1.0"})',
            ),
            _DiagnosticTile(
              label: 'Last Checked',
              value: '${health.checkedAt.hour.toString().padLeft(2, '0')}:${health.checkedAt.minute.toString().padLeft(2, '0')}:${health.checkedAt.second.toString().padLeft(2, '0')}',
            ),

            const SizedBox(height: 14),
            const Text(
              'Client Auth & Session State',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 8),

            _DiagnosticTile(
              label: 'Device ID',
              value: api.getOrCreateDeviceId(),
              isMonospace: true,
              onCopy: () => _copyToClipboard('Device ID', api.getOrCreateDeviceId()),
            ),
            _DiagnosticTile(
              label: 'Auth Token',
              value: api.token != null
                  ? 'Present (${api.token!.length > 18 ? api.token!.substring(0, 18) + '...' : api.token})'
                  : 'No Token (Unauthenticated)',
              isMonospace: true,
              onCopy: api.token != null ? () => _copyToClipboard('Auth Token', api.token!) : null,
            ),

            const SizedBox(height: 18),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.bolt, size: 16),
                    label: const Text('Re-Auth Guest', style: TextStyle(fontSize: 12)),
                    onPressed: _isRefreshing ? null : _reauthGuest,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copy JSON', style: TextStyle(fontSize: 12)),
                    onPressed: () {
                      final jsonString = const JsonEncoder.withIndent('  ').convert(health.toJson());
                      _copyToClipboard('Diagnostics JSON', jsonString);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DiagnosticTile extends StatelessWidget {
  final String label;
  final String value;
  final bool isMonospace;
  final Color? statusColor;
  final VoidCallback? onCopy;

  const _DiagnosticTile({
    required this.label,
    required this.value,
    this.isMonospace = false,
    this.statusColor,
    this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                fontFamily: isMonospace ? 'monospace' : null,
                color: statusColor ?? (isDark ? Colors.white : Colors.black87),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (onCopy != null)
            InkWell(
              onTap: onCopy,
              borderRadius: BorderRadius.circular(4),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.copy, size: 14, color: Colors.grey),
              ),
            ),
        ],
      ),
    );
  }
}
