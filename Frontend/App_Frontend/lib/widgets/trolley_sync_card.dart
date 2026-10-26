import 'package:flutter/material.dart';
import '../core/theme.dart';

/// Dark telemetry card (#0F172A) displaying active trolley hardware status
class TrolleySyncCard extends StatelessWidget {
  final bool isSynced;
  final String? cartId;
  final int itemCount;
  final double runningTotal;
  final bool isWsConnected;
  final VoidCallback onScanPressed;

  const TrolleySyncCard({
    super.key,
    required this.isSynced,
    this.cartId,
    required this.itemCount,
    required this.runningTotal,
    this.isWsConnected = false,
    required this.onScanPressed,
  });

  @override
  Widget build(BuildContext context) {
    if (!isSynced) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.secondary,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          boxShadow: [
            BoxShadow(
              color: AppTheme.secondary.withValues(alpha: 0.25),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppTheme.offerAmber,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'NO TROLLEY PAIRED',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Colors.white70,
                              letterSpacing: 0.8,
                            ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                const Icon(Icons.shopping_cart_outlined, color: Colors.white54, size: 22),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Pair with Smart Trolley',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Scan the 2D QR matrix on the cart handle to activate real-time edge vision shopping.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white70,
                    height: 1.4,
                  ),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: onScanPressed,
              icon: const Icon(Icons.qr_code_scanner, size: 20),
              label: const Text('Scan Cart QR Matrix'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 46),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.secondary,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.inverseSurfaceCard, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppTheme.secondary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.supermarketGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  border: Border.all(color: AppTheme.supermarketGreen.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppTheme.supermarketGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'TROLLEY ACTIVE • ${cartId ?? "CART_01"}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppTheme.supermarketGreen,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                          ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  Icon(
                    isWsConnected ? Icons.wifi : Icons.wifi_off,
                    size: 16,
                    color: isWsConnected ? AppTheme.supermarketGreen : Colors.white38,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isWsConnected ? 'Edge Sync' : 'Connecting...',
                    style: TextStyle(
                      fontSize: 11,
                      color: isWsConnected ? AppTheme.supermarketGreen : Colors.white38,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Running Total',
                    style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '₹${runningTotal.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              Container(
                height: 40,
                width: 1,
                color: Colors.white.withValues(alpha: 0.15),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Items In Basket',
                    style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$itemCount units',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
