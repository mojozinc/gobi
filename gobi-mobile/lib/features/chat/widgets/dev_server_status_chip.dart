import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/backend_health.dart';
import '../../../core/providers/dev_providers.dart';
import '../../../core/services/api_service.dart';
import 'dev_diagnostics_sheet.dart';

/// A developer-only status chip indicating live backend connectivity and roundtrip latency.
///
/// Tapping this chip opens the [DevDiagnosticsSheet] for detailed inspection and manual controls.
class DevServerStatusChip extends ConsumerWidget {
  final ApiService? apiService;

  const DevServerStatusChip({super.key, this.apiService});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(backendHealthProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color dotColor;
    String label;

    if (health.isHealthy) {
      dotColor = AppColors.success;
      label = '${health.latencyMs ?? 0}ms';
    } else if (health.isDegraded) {
      dotColor = AppColors.warning;
      label = 'Degraded';
    } else if (health.isChecking) {
      dotColor = Colors.blue;
      label = 'Ping...';
    } else {
      dotColor = AppColors.error;
      label = 'Offline';
    }

    return Tooltip(
      message: 'Dev: Backend status (${health.status}) • Tap for diagnostics',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => DevDiagnosticsSheet.show(context, apiService: apiService),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: dotColor.withOpacity(isDark ? 0.18 : 0.10),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: dotColor.withOpacity(0.4),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: dotColor.withOpacity(0.5),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: dotColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
