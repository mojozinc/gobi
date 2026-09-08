import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/widgets/gobi_logo.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    // Brief splash delay for smooth visual transition
    await Future.delayed(const Duration(milliseconds: 1200));

    if (!mounted) return;

    final apiService = ref.read(apiServiceProvider);

    // If token already saved, proceed directly to home
    if (apiService.isAuthenticated) {
      Navigator.of(context).pushReplacementNamed('/home');
      return;
    }

    // Auto-login as anonymous / persistent guest user so user never has to log in
    try {
      await apiService.loginAnonymously();
    } catch (e) {
      debugPrint('Anonymous login attempt notice: $e');
    }

    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App Logo
            GobiLogo(
              size: 110,
              showText: true,
              borderRadius: 24,
            ),
            SizedBox(height: 48),
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
