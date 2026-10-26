import 'package:flutter/material.dart';
import '../core/theme.dart';

/// "Vision Verified" badge indicating AI camera entrance gate verification
class VisionVerifiedBadge extends StatelessWidget {
  final bool isVerified;
  final double fontSize;

  const VisionVerifiedBadge({
    super.key,
    this.isVerified = true,
    this.fontSize = 11.0,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVerified) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppTheme.hazardErrorSubtle,
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          border: Border.all(color: AppTheme.hazardError.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded, size: 12, color: AppTheme.hazardError),
            const SizedBox(width: 4),
            Text(
              'Pending Drop',
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                color: AppTheme.hazardError,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.supermarketGreenSubtle,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        border: Border.all(color: AppTheme.supermarketGreenBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.verified, size: 13, color: AppTheme.supermarketGreen),
          const SizedBox(width: 4),
          Text(
            'Vision Verified',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF047857),
            ),
          ),
        ],
      ),
    );
  }
}
