import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class GobiLogo extends StatelessWidget {
  final double size;
  final bool showText;
  final TextStyle? textStyle;
  final double borderRadius;
  final bool elevation;

  const GobiLogo({
    super.key,
    this.size = 80,
    this.showText = false,
    this.textStyle,
    this.borderRadius = 20,
    this.elevation = true,
  });

  @override
  Widget build(BuildContext context) {
    Widget logoIcon = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: elevation
            ? [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Image.asset(
          'assets/images/gobi_logo.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            // Fallback gradient shield if asset image is not loaded
            return Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.accent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.health_and_safety_rounded,
                  size: size * 0.6,
                  color: Colors.white,
                ),
              ),
            );
          },
        ),
      ),
    );

    if (!showText) return logoIcon;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        logoIcon,
        const SizedBox(height: 14),
        Text(
          'Gobi',
          style: textStyle ??
              const TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.2,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'Family Health & Medication Hub',
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withOpacity(0.85),
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}
