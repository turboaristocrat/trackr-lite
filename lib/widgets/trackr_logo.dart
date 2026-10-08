import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// The official TRACKR brand logo widget with custom railway insignia.
class TrackrLogo extends StatelessWidget {
  final double iconSize;
  final double fontSize;
  final bool showText;
  final bool showBadge;
  final String? subtitle;
  final bool isVertical;

  const TrackrLogo({
    super.key,
    this.iconSize = 34,
    this.fontSize = 20,
    this.showText = true,
    this.showBadge = true,
    this.subtitle,
    this.isVertical = false,
  });

  @override
  Widget build(BuildContext context) {
    final iconWidget = Container(
      width: iconSize,
      height: iconSize,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(iconSize * 0.24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFDB324).withValues(alpha: 0.2),
            blurRadius: iconSize * 0.25,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(iconSize * 0.24),
        child: Image.asset(
          'assets/images/trackr_logo.png',
          width: iconSize,
          height: iconSize,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => Container(
            color: const Color(0xFF111418),
            child: const Icon(Icons.flash_on_rounded, color: Color(0xFFFDB324), size: 18),
          ),
        ),
      ),
    );

    if (!showText) {
      return iconWidget;
    }

    final textWidget = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'TRACKR',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            color: AppTheme.textPrimary,
            letterSpacing: 0.8,
            height: 1.05,
          ),
        ),
        if (showBadge) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.secondaryContainer,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'LITE',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: Color(0xFF281800),
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ],
    );

    if (isVertical) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          iconWidget,
          SizedBox(height: iconSize * 0.2),
          textWidget,
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        iconWidget,
        SizedBox(width: iconSize * 0.25),
        textWidget,
      ],
    );
  }
}
