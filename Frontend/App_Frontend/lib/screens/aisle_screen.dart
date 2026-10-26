import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../widgets/app_bottom_nav_bar.dart';
import 'scan_screen.dart';

/// 1:1 Replica of Stitch "Aisle" screen
/// Features: In-Store Wayfinding Map, Segmented Floor Switcher, Walking ETA,
/// Detailed 2D CustomPainted Store Layout with dashed navigation path from "YOU ARE HERE"
/// to "TARGET Sec 4 Noodles", and Bottom Action Drawer with "Start AR Navigation".
class AisleScreen extends StatefulWidget {
  const AisleScreen({super.key});

  @override
  State<AisleScreen> createState() => _AisleScreenState();
}

class _AisleScreenState extends State<AisleScreen> with SingleTickerProviderStateMixin {
  int _selectedFloor = 0;
  double _zoomLevel = 1.0;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FF),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Streamlined Wayfinding Header
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Color(0xFFE5EEFF))),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x0A000000),
                    blurRadius: 8,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Primary Header Row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.of(context).maybePop(),
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFFF8FAFC),
                            ),
                            child: const Icon(Icons.arrow_back, color: Color(0xFF0F172A), size: 22),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    'Aisle 4 Product Map',
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0B1C30),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text('•', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                                  const SizedBox(width: 4),
                                  const Expanded(
                                    child: Text(
                                      'Maggi Noodles',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF565E74),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'D-Mart · HSR Layout',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Live GPS Signal Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFA7F3D0)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'LIVE GPS',
                                style: TextStyle(
                                  color: Color(0xFF047857),
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Segmented Pill Floor Switcher
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF4FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE5EEFF)),
                      ),
                      child: Row(
                        children: [
                          _buildFloorPill('Ground Floor', 0),
                          _buildFloorPill('1st Floor', 1),
                          _buildFloorPill('2nd Floor', 2),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Map Area & Viewport
            Expanded(
              child: Stack(
                children: [
                  // Map Canvas & Store Plan
                  Positioned.fill(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 170),
                      child: Column(
                        children: [
                          // Walking ETA Chip & Map Utilities
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: const Color(0xFFE5EEFF)),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x06000000),
                                      blurRadius: 6,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.directions_walk, size: 17, color: AppTheme.primary),
                                    SizedBox(width: 6),
                                    Text(
                                      '18m • 25s walk to shelf',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0B1C30),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  // Recalibrate Compass Button
                                  GestureDetector(
                                    onTap: () {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Compass Recalibrated')),
                                      );
                                    },
                                    child: Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: const Color(0xFFE5EEFF)),
                                      ),
                                      child: const Icon(Icons.explore, size: 18, color: Color(0xFF0B1C30)),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Zoom Controls
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: const Color(0xFFE5EEFF)),
                                    ),
                                    child: Row(
                                      children: [
                                        GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              _zoomLevel = (_zoomLevel + 0.1).clamp(0.8, 1.4);
                                            });
                                          },
                                          child: const SizedBox(
                                            width: 32,
                                            height: 32,
                                            child: Icon(Icons.add, size: 16, color: Color(0xFF0B1C30)),
                                          ),
                                        ),
                                        Container(width: 1, height: 16, color: const Color(0xFFE5EEFF)),
                                        GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              _zoomLevel = (_zoomLevel - 0.1).clamp(0.8, 1.4);
                                            });
                                          },
                                          child: const SizedBox(
                                            width: 32,
                                            height: 32,
                                            child: Icon(Icons.remove, size: 16, color: Color(0xFF0B1C30)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // Architectural Store Vector Schematic Plan
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x06000000),
                                  blurRadius: 10,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(12),
                            child: AnimatedBuilder(
                              animation: _pulseAnimation,
                              builder: (context, _) {
                                return Transform.scale(
                                  scale: _zoomLevel,
                                  child: CustomPaint(
                                    size: const Size(340, 440),
                                    painter: StoreMapPainter(pulseFactor: _pulseAnimation.value),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Item Breakdown Details Drawer (Elevated above bottom bar)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0B1C30).withValues(alpha: 0.1),
                            blurRadius: 24,
                            offset: const Offset(0, -4),
                          ),
                        ],
                        border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Touch Drag Handle
                          Container(
                            width: 36,
                            height: 4,
                            decoration: BoxDecoration(
                              color: const Color(0xFFCBD5E1),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Product Details Info
                          Row(
                            children: [
                              Stack(
                                children: [
                                  Container(
                                    width: 58,
                                    height: 58,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFF7ED),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFFFFEDD5)),
                                    ),
                                    padding: const EdgeInsets.all(4),
                                    child: Image.network(
                                      'https://lh3.googleusercontent.com/aida-public/AB6AXuBj6nx7kCIOllmG6s3X7_o_CTq8t5vb-oSDvNbAAiBqHfNGp2pA1Gj8xFlBN1yUqCQ-i3t51NN12wj-nJ0aZfI6TieFCknl_w8gfsZnVT-Ug7HH4DOBuy08BltgZDvbJW1WqwN7uC0l37Zn4l-llvPVKcxnheT0MvjVy0SSSfJJTkbN-mWTsY3mTotrS7M3xhZCsNhPHSQ1Lrecn0nLY-3O3q5kPWNKpKh55FLpYhV-h1n3nNu2NRiIfQ',
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                  Positioned(
                                    top: 4,
                                    left: 4,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF006C49),
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                      child: const Text(
                                        'Rack 2',
                                        style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFECFDF5),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: const Row(
                                            children: [
                                              Icon(Icons.circle, color: Color(0xFF10B981), size: 6),
                                              SizedBox(width: 4),
                                              Text(
                                                'In Stock (42 units)',
                                                style: TextStyle(
                                                  color: Color(0xFF047857),
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Text(
                                          '₹14.00',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w900,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    const Text(
                                      'Maggi 2-Minute Masala 70g',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF0B1C30),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    const Row(
                                      children: [
                                        Icon(Icons.pin_drop, size: 13, color: AppTheme.primary),
                                        SizedBox(width: 3),
                                        Text(
                                          'Ground · Sec 4 · Aisle 4 • Eye-level shelf',
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF565E74),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // Dual Action CTAs
                          Row(
                            children: [
                              Expanded(
                                flex: 4,
                                child: SizedBox(
                                  height: 44,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primary,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: 2,
                                      shadowColor: AppTheme.primary.withValues(alpha: 0.4),
                                    ),
                                    onPressed: () {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Starting Augmented Reality (AR) Camera Guidance...'),
                                          backgroundColor: AppTheme.primary,
                                        ),
                                      );
                                    },
                                    child: const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.navigation, color: Colors.white, size: 18),
                                        SizedBox(width: 8),
                                        Text(
                                          'Start AR Navigation',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 1,
                                child: SizedBox(
                                  height: 44,
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor: const Color(0xFFEFF4FF),
                                      side: const BorderSide(color: Color(0xFFE5EEFF)),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      padding: EdgeInsets.zero,
                                    ),
                                    onPressed: () {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Marked item as collected!')),
                                      );
                                    },
                                    child: const Icon(Icons.check_circle, color: Color(0xFF006C49), size: 22),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNavBar(
        onScanPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ScanScreen()),
          );
        },
      ),
    );
  }

  Widget _buildFloorPill(String title, int index) {
    final isSelected = _selectedFloor == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedFloor = index;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? const [
                    BoxShadow(
                      color: Color(0x0A000000),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isSelected) ...[
                Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: AppTheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
              ],
              Text(
                title,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected ? AppTheme.primary : const Color(0xFF565E74),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// CustomPainter rendering 1:1 Vector Schematic Store Map with dashed walking path
class StoreMapPainter extends CustomPainter {
  final double pulseFactor;

  StoreMapPainter({required this.pulseFactor});

  @override
  void paint(Canvas canvas, Size size) {
    // Background
    final bgPaint = Paint()..color = const Color(0xFFFAFCFF);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.width, size.height), const Radius.circular(14)),
      bgPaint,
    );

    // Peripheral Wall Outline (Dashed)
    final wallPaint = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(8, 8, size.width - 16, size.height - 16), const Radius.circular(10)),
      wallPaint,
    );

    // Zone Headers
    _drawText(canvas, 'PACKAGED FOODS', const Offset(80, 24), fontSize: 8.5, color: const Color(0xFF94A3B8), isBold: true);
    _drawText(canvas, 'INSTANT MEALS', const Offset(220, 24), fontSize: 8.5, color: const Color(0xFF94A3B8), isBold: true);

    // Shelf Blocks (Sec 1, Sec 2, Sec 3)
    final shelfFill = Paint()..color = const Color(0xFFEFF4FE);
    final shelfBorder = Paint()
      ..color = const Color(0xFFDCE9FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    // Top Row Shelves
    _drawShelfBlock(canvas, const Rect.fromLTWH(48, 40, 40, 56), 'Sec 1', shelfFill, shelfBorder);
    _drawShelfBlock(canvas, const Rect.fromLTWH(116, 40, 38, 56), 'Sec 2', shelfFill, shelfBorder);
    _drawShelfBlock(canvas, const Rect.fromLTWH(180, 40, 38, 56), 'Sec 3', shelfFill, shelfBorder);

    // TARGET SECTION: Sec 4, Aisle 4
    final targetRect = const Rect.fromLTWH(244, 40, 48, 56);
    final targetFill = Paint()..color = const Color(0xFFFFEDD5);
    final targetBorder = Paint()
      ..color = AppTheme.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRRect(RRect.fromRectAndRadius(targetRect, const Radius.circular(6)), targetFill);
    canvas.drawRRect(RRect.fromRectAndRadius(targetRect, const Radius.circular(6)), targetBorder);

    // Target orange badge header
    final targetBadgePaint = Paint()..color = AppTheme.primary;
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(246, 42, 44, 12), const Radius.circular(3)),
      targetBadgePaint,
    );
    _drawText(canvas, 'TARGET', const Offset(255, 43), fontSize: 7.5, color: Colors.white, isBold: true);
    _drawText(canvas, 'Sec 4', const Offset(256, 62), fontSize: 10, color: const Color(0xFF9A3412), isBold: true);
    _drawText(canvas, 'Noodles', const Offset(254, 76), fontSize: 7.5, color: const Color(0xFFC2410C), isBold: true);

    // Mid Row Shelves (Sec 5, 6, 7, 8)
    _drawShelfBlock(canvas, const Rect.fromLTWH(48, 126, 40, 64), 'Sec 5\nSnacks', shelfFill, shelfBorder);
    _drawShelfBlock(canvas, const Rect.fromLTWH(116, 126, 38, 64), 'Sec 6\nBeverages', shelfFill, shelfBorder);
    _drawShelfBlock(canvas, const Rect.fromLTWH(180, 126, 38, 64), 'Sec 7\nBreakfast', shelfFill, shelfBorder);
    _drawShelfBlock(canvas, const Rect.fromLTWH(244, 126, 48, 64), 'Sec 8\nSauces', shelfFill, shelfBorder);

    // Bulk Staples Rows
    final bulkFill = Paint()..color = const Color(0xFFF1F5F9);
    final bulkBorder = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    _drawShelfBlock(canvas, const Rect.fromLTWH(48, 220, 106, 36), 'Atta, Rice & Pulses', bulkFill, bulkBorder);
    _drawShelfBlock(canvas, const Rect.fromLTWH(180, 220, 112, 36), 'Oils & Spices', bulkFill, bulkBorder);

    // Express Billing Counters B1-B6
    final billingZone = const Rect.fromLTWH(32, 286, 276, 52);
    canvas.drawRRect(RRect.fromRectAndRadius(billingZone, const Radius.circular(8)), shelfFill);
    _drawText(canvas, 'EXPRESS BILLING COUNTERS', const Offset(104, 292), fontSize: 8, color: const Color(0xFF475569), isBold: true);

    final counterFill = Paint()..color = Colors.white;
    final counterBorder = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (int i = 0; i < 6; i++) {
      final cr = Rect.fromLTWH(42.0 + (i * 44), 306, 32, 22);
      canvas.drawRRect(RRect.fromRectAndRadius(cr, const Radius.circular(4)), counterFill);
      canvas.drawRRect(RRect.fromRectAndRadius(cr, const Radius.circular(4)), counterBorder);
      _drawText(canvas, 'B${i + 1}', Offset(52.0 + (i * 44), 311), fontSize: 8, color: const Color(0xFF334155), isBold: true);
    }

    // Entrance Gate
    final entranceRect = const Rect.fromLTWH(90, 366, 160, 30);
    final entranceFill = Paint()..color = const Color(0xFFF0FDF4);
    final entranceBorder = Paint()
      ..color = const Color(0xFFBBF7D0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(RRect.fromRectAndRadius(entranceRect, const Radius.circular(6)), entranceFill);
    canvas.drawRRect(RRect.fromRectAndRadius(entranceRect, const Radius.circular(6)), entranceBorder);
    _drawText(canvas, 'Entrance / Turnstiles →', const Offset(118, 375), fontSize: 9, color: const Color(0xFF15803D), isBold: true);

    // Smart Walkway Dashed Orange Navigation Path
    final pathPaint = Paint()
      ..color = AppTheme.primary
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final navPath = Path()
      ..moveTo(106, 356)
      ..lineTo(106, 272)
      ..lineTo(168, 272)
      ..lineTo(168, 108)
      ..lineTo(236, 108)
      ..lineTo(236, 68)
      ..lineTo(246, 68);

    canvas.drawPath(navPath, pathPaint);

    // Target Location Pulse Circle
    final pulsePaint = Paint()
      ..color = AppTheme.primary.withValues(alpha: 0.25 / pulseFactor)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(268, 68), 16 * pulseFactor, pulsePaint);

    // Pin Icon at Target
    final pinPaint = Paint()..color = AppTheme.primary;
    canvas.drawCircle(const Offset(268, 68), 7, pinPaint);
    canvas.drawCircle(const Offset(268, 68), 3, Paint()..color = Colors.white);

    // Floating Target Callout Bubble
    final bubbleRect = const Rect.fromLTWH(132, 10, 160, 24);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bubbleRect, const Radius.circular(12)),
      Paint()..color = const Color(0xFF0F172A),
    );
    _drawText(canvas, 'Ground · Sec 4 · Aisle 4', const Offset(142, 16), fontSize: 8.5, color: Colors.white, isBold: true);
    _drawText(canvas, 'BAY B', const Offset(254, 16), fontSize: 8.5, color: AppTheme.primary, isBold: true);

    // "YOU ARE HERE" Blue Marker
    final blueHalo = Paint()
      ..color = const Color(0xFF2563EB).withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(106, 356), 12 * pulseFactor, blueHalo);

    final blueDot = Paint()..color = const Color(0xFF2563EB);
    canvas.drawCircle(const Offset(106, 356), 6, blueDot);
    canvas.drawCircle(
      const Offset(106, 356),
      6,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    _drawText(canvas, 'YOU ARE HERE', const Offset(78, 342), fontSize: 7.5, color: const Color(0xFF1E40AF), isBold: true);
  }

  void _drawShelfBlock(Canvas canvas, Rect rect, String label, Paint fill, Paint border) {
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(6)), fill);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(6)), border);

    final lines = label.split('\n');
    double startY = rect.top + (rect.height / 2) - (lines.length * 6);
    for (final line in lines) {
      _drawText(
        canvas,
        line,
        Offset(rect.left + (rect.width / 2) - (line.length * 2.8), startY),
        fontSize: 8.5,
        color: const Color(0xFF334155),
        isBold: true,
      );
      startY += 12;
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset, {
    required double fontSize,
    required Color color,
    bool isBold = false,
  }) {
    final textSpan = TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant StoreMapPainter oldDelegate) =>
      oldDelegate.pulseFactor != pulseFactor;
}
