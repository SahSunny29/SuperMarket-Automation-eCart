import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../core/navigation_controller.dart';
import '../core/theme.dart';
import '../providers/cart_provider.dart';
import 'settings_screen.dart';

/// 1:1 Stitch Replica: e-Cart - QR Scanner Screen
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with SingleTickerProviderStateMixin {
  final MobileScannerController _scannerController = MobileScannerController();
  late AnimationController _laserController;
  late Animation<double> _laserAnimation;

  bool _isTorchOn = false;
  bool _hasProcessed = false;

  @override
  void initState() {
    super.initState();
    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _laserAnimation = Tween<double>(begin: 10, end: 250).animate(
      CurvedAnimation(parent: _laserController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _laserController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _handlePairing(String cartId) async {
    if (_hasProcessed) return;
    _hasProcessed = true;

    final cart = context.read<CartProvider>();
    final success = await cart.pairCart(cartId);

    if (!mounted) return;

    if (success) {
      // Transition to Synced root screen
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      context.read<NavigationController>().goToHome();
    } else {
      _hasProcessed = false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(cart.pairError ?? 'Failed to pair trolley with Central Server.'),
          backgroundColor: AppTheme.hazardError,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'CONFIG',
            textColor: Colors.white,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera feed layer
          MobileScanner(
            controller: _scannerController,
            onDetect: (capture) {
              final barcodes = capture.barcodes;
              if (barcodes.isNotEmpty) {
                final code = barcodes.first.rawValue;
                if (code != null && code.isNotEmpty) {
                  _handlePairing(code);
                }
              }
            },
          ),

          // 60% Dimmed backdrop with transparent cutout
          ColorFiltered(
            colorFilter: ColorFilter.mode(
              Colors.black.withValues(alpha: 0.65),
              BlendMode.srcOut,
            ),
            child: Stack(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.transparent,
                  ),
                ),
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    width: 270,
                    height: 270,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Top Header Area
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Android status bar space + header row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white, size: 26),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Scan QR',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            'Scan the code on your trolley handle',
                            style: TextStyle(
                              color: Color(0xFFCBD5E1),
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Center Reticle with Corner Brackets & Laser
          Center(
            child: GestureDetector(
              onTap: () {
                // Interactive tap-to-simulate for desktop / emulator testing
                _handlePairing('CART_01');
              },
              child: SizedBox(
                width: 270,
                height: 270,
                child: Stack(
                  children: [
                    // Corner Brackets (White, 4px stroke, rounded corners 14px radius)
                    // Top-Left
                    Positioned(
                      top: 0,
                      left: 0,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(color: Colors.white, width: 4),
                            left: BorderSide(color: Colors.white, width: 4),
                          ),
                          borderRadius: BorderRadius.only(topLeft: Radius.circular(14)),
                        ),
                      ),
                    ),
                    // Top-Right
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(color: Colors.white, width: 4),
                            right: BorderSide(color: Colors.white, width: 4),
                          ),
                          borderRadius: BorderRadius.only(topRight: Radius.circular(14)),
                        ),
                      ),
                    ),
                    // Bottom-Left
                    Positioned(
                      bottom: 0,
                      left: 0,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Colors.white, width: 4),
                            left: BorderSide(color: Colors.white, width: 4),
                          ),
                          borderRadius: BorderRadius.only(bottomLeft: Radius.circular(14)),
                        ),
                      ),
                    ),
                    // Bottom-Right
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Colors.white, width: 4),
                            right: BorderSide(color: Colors.white, width: 4),
                          ),
                          borderRadius: BorderRadius.only(bottomRight: Radius.circular(14)),
                        ),
                      ),
                    ),

                    // Target Guide Center Crosshair Hint
                    Center(
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.4),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),

                    // Scanning Laser Beam Animation (Solar Orange #FF6400)
                    AnimatedBuilder(
                      animation: _laserAnimation,
                      builder: (context, child) {
                        return Positioned(
                          top: _laserAnimation.value,
                          left: 12,
                          right: 12,
                          child: Container(
                            height: 2.5,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF6400),
                              borderRadius: BorderRadius.circular(2),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0xFFFF6400),
                                  blurRadius: 12,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                    // Subtle Tap hint for dev simulation
                    Positioned(
                      bottom: 8,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Text(
                          'Tap to Simulate Scan #CART_01',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Instructional Text Below Reticle
          Positioned(
            left: 0,
            right: 0,
            bottom: 180,
            child: Column(
              children: [
                const Text(
                  'Align the QR code within the frame',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'D-Mart Bay 14 • Smart Trolley System',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // Bottom Controls (Torch ON/OFF + Automatic Detection Pill)
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Torch Buttons Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Torch ON Button
                    Column(
                      children: [
                        GestureDetector(
                          onTap: () {
                            setState(() => _isTorchOn = true);
                            _scannerController.toggleTorch();
                          },
                          child: Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: _isTorchOn ? const Color(0xFFFF6400) : Colors.white.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _isTorchOn ? const Color(0xFFFF6400) : Colors.white.withValues(alpha: 0.2),
                              ),
                              boxShadow: _isTorchOn
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFFFF6400).withValues(alpha: 0.4),
                                        blurRadius: 16,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: const Center(
                              child: Icon(Icons.flashlight_on, color: Colors.white, size: 24),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Torch ON',
                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(width: 36),

                    // Torch OFF Button
                    Column(
                      children: [
                        GestureDetector(
                          onTap: () {
                            setState(() => _isTorchOn = false);
                            _scannerController.toggleTorch();
                          },
                          child: Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: !_isTorchOn ? const Color(0xFF1E293B) : Colors.white.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                            ),
                            child: const Center(
                              child: Icon(Icons.flashlight_off, color: Colors.white70, size: 24),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Torch OFF',
                          style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Automatic Detection Badge Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF34D399),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Cart ID will be detected automatically',
                        style: TextStyle(
                          color: Color(0xFFE2E8F0),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
