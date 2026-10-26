import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/navigation_controller.dart';
import '../core/theme.dart';
import '../providers/cart_provider.dart';

/// Exact Stitch 5-Tab Bottom Navigation Dock with Center Pulsating Scan FAB
class AppBottomNavBar extends StatelessWidget {
  final VoidCallback onScanPressed;

  const AppBottomNavBar({
    super.key,
    required this.onScanPressed,
  });

  @override
  Widget build(BuildContext context) {
    final navController = context.watch<NavigationController>();
    final cart = context.watch<CartProvider>();
    final activeIndex = navController.currentIndex;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          top: BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.08),
            offset: const Offset(0, -4),
            blurRadius: 20,
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 72,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // 4 standard tabs around center FAB
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // Tab 0: Home
                  _buildNavItem(
                    context: context,
                    icon: Icons.home,
                    label: 'Home',
                    isActive: activeIndex == 0,
                    onTap: () => navController.goToHome(),
                  ),

                  // Tab 1: Aisles
                  _buildNavItem(
                    context: context,
                    icon: Icons.storefront_outlined,
                    label: 'Aisles',
                    isActive: activeIndex == 1,
                    onTap: () => navController.goToAisles(),
                  ),

                  // Spacer for center elevated Scan FAB
                  const SizedBox(width: 68),

                  // Tab 3: Live Bill
                  _buildNavItem(
                    context: context,
                    icon: Icons.receipt_long_outlined,
                    label: 'Live Bill',
                    badgeCount: cart.itemCount,
                    isActive: activeIndex == 3,
                    onTap: () => navController.goToLiveBill(),
                  ),

                  // Tab 4: History
                  _buildNavItem(
                    context: context,
                    icon: Icons.history,
                    label: 'History',
                    isActive: activeIndex == 4,
                    onTap: () => navController.goToHistory(),
                  ),
                ],
              ),

              // Center Animated Scan FAB
              Positioned(
                top: -18,
                left: 0,
                right: 0,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: onScanPressed,
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.primary,
                            border: Border.all(color: Colors.white, width: 3.5),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primary.withValues(alpha: 0.45),
                                blurRadius: 18,
                                spreadRadius: 2,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.qr_code_scanner,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'Scan',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primary,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    int? badgeCount,
  }) {
    final color = isActive ? AppTheme.primary : const Color(0xFF64748B);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Badge(
              isLabelVisible: (badgeCount ?? 0) > 0,
              label: Text('$badgeCount'),
              backgroundColor: AppTheme.primary,
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                color: color,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
