import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// A wrapper widget that conditionally renders [child] only during development / debug mode.
///
/// In release mode, it renders [fallback] (defaulting to [SizedBox.shrink]) to ensure
/// developer-only utilities and diagnostics never appear in production.
class DevOnly extends StatelessWidget {
  final Widget child;
  final Widget fallback;
  final bool enabled;

  const DevOnly({
    super.key,
    required this.child,
    this.fallback = const SizedBox.shrink(),
    this.enabled = true,
  });

  /// Helper getter to check if current environment is development/debug mode.
  static bool get isDev => kDebugMode;

  @override
  Widget build(BuildContext context) {
    if (kDebugMode && enabled) {
      return child;
    }
    return fallback;
  }
}
