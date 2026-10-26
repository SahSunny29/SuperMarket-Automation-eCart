import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/navigation_controller.dart';
import '../providers/cart_provider.dart';
import '../screens/scan_screen.dart';

/// Bold, high-contrast, attention-seeking Security Alert Modal rendered when an
/// UNSCANNED_DROP or anomaly event occurs. Informs shopper that syncing has been
/// halted immediately and prompts re-pairing.
class UnscannedAlertModal extends StatelessWidget {
  const UnscannedAlertModal({super.key});

  static Future<void> show(BuildContext context) {
    // Provide tactile warning haptic pulse
    HapticFeedback.heavyImpact();
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const UnscannedAlertModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final alert = cart.activeSecurityAlert;
    final message = alert?.message ??
        'SECURITY ALERT: Unscanned Item Detected! Cart syncing has been terminated. Please re-scan the cart QR code or contact store staff.';

    return PopScope(
      canPop: false,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 24,
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // High-Contrast Red Pulsing Halo with Warning Shield
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFEF4444), width: 3),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33DC2626),
                      blurRadius: 18,
                      spreadRadius: 2,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.gpp_bad_rounded,
                  color: Color(0xFFDC2626),
                  size: 44,
                ),
              ),
              const SizedBox(height: 18),

              // Title Header
              const Text(
                'SECURITY ALERT',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                  color: Color(0xFF991B1B),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),

              const Text(
                'Unscanned Item Detected!',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // Trolley Tag Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: const Text(
                  'SYNC HALTED • TROLLEY DISCONNECTED',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: Color(0xFFDC2626),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Bold Red Alert Box with Message
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFFCCD5), width: 1.5),
                ),
                child: Text(
                  message,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF881337),
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 16),

              const Text(
                'To resume shopping, please re-scan the QR code on the trolley handle. If you require assistance, a floor associate will gladly help.',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 20),

              // Action 1: "Re-Scan Cart QR Code" Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 3,
                  ),
                  onPressed: () {
                    cart.clearSecurityAlert();
                    Navigator.of(context).pop();
                    try {
                      final nav = context.read<NavigationController>();
                      nav.setIndex(2); // Scan tab index
                    } catch (_) {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ScanScreen()),
                      );
                    }
                  },
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.qr_code_scanner, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Re-Scan Cart QR Code',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Action 2: "Close & Return to Home" Button
              SizedBox(
                width: double.infinity,
                height: 42,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF475569),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    cart.clearSecurityAlert();
                    Navigator.of(context).pop();
                    try {
                      final nav = context.read<NavigationController>();
                      nav.setIndex(0); // Home tab index
                    } catch (_) {}
                  },
                  child: const Text(
                    'Close & Return to Home',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
