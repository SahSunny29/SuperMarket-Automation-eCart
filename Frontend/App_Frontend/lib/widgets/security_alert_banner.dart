import 'package:flutter/material.dart';
import '../core/models.dart';
import '../core/theme.dart';

/// Persistent hazard alert banner/modal when an UNSCANNED_DROP anomaly occurs
class SecurityAlertBanner extends StatelessWidget {
  final SecurityAlert alert;
  final VoidCallback onDismiss;

  const SecurityAlertBanner({
    super.key,
    required this.alert,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.hazardErrorSubtle,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.hazardError, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppTheme.hazardError.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.hazardError,
                  borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
                ),
                child: const Icon(
                  Icons.notifications_active_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SECURITY ALERT: UNSCANNED ITEM',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppTheme.hazardError,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Trolley ${alert.cartId} flagged an unverified drop.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.secondary,
                          ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppTheme.neutral, size: 20),
                onPressed: onDismiss,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'SECURITY ALERT: Unscanned item detected! Cart syncing has been terminated. Please re-scan the cart QR code to begin a new session.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.secondary.withValues(alpha: 0.8),
                  height: 1.4,
                ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onDismiss,
                  icon: const Icon(Icons.qr_code_scanner, size: 18),
                  label: const Text('Re-Scan Cart QR'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.hazardError,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 38),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
