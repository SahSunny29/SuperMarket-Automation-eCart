import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../core/models.dart';
import '../providers/cart_provider.dart';
import '../widgets/app_bottom_nav_bar.dart';
import 'aisle_screen.dart';
import 'cart_screen.dart';
import 'scan_screen.dart';
import 'settings_screen.dart';

/// 1:1 Replica of Stitch "searched" screen
/// Features: Active query search bar with Aisles filter, Quick category chips,
/// Highlighted "Closest Shelf Match" card with proximity strip & Guide button,
/// "Other Matches in Aisle 3 & 4" list, and Trending Tag Cloud.
class SearchedScreen extends StatefulWidget {
  final String initialQuery;

  const SearchedScreen({
    super.key,
    this.initialQuery = 'Maggi Noodles',
  });

  @override
  State<SearchedScreen> createState() => _SearchedScreenState();
}

class _SearchedScreenState extends State<SearchedScreen> {
  late TextEditingController _searchController;
  int _selectedFilterIndex = 0;

  final List<String> _filters = [
    'All (8)',
    'Instant Noodles (4)',
    'Oats & Atta Noodles (2)',
    'Sauces & Masala (2)',
  ];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _navigateToAisle() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AisleScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // 1. TOUCH-FRIENDLY STREAMLINED TOP HEADER
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Column(
                children: [
                  // Top App Bar Row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Left Back / Menu Button
                        GestureDetector(
                          onTap: () {
                            if (Navigator.of(context).canPop()) {
                              Navigator.of(context).pop();
                            } else {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const SettingsScreen()),
                              );
                            }
                          },
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Icon(
                              Navigator.of(context).canPop() ? Icons.arrow_back : Icons.menu,
                              color: const Color(0xFF0F172A),
                              size: 22,
                            ),
                          ),
                        ),

                        // Center Brand & Store Dropdown
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primary,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'E-CART',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'Smart Trolley',
                                    style: TextStyle(
                                      color: Color(0xFF0F172A),
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF16A34A),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Text(
                                      'D-Mart • Bay 14 • #CART_01',
                                      style: TextStyle(
                                        color: Color(0xFF1E293B),
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 2),
                                    const Icon(Icons.expand_more, size: 14, color: Color(0xFF64748B)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Right Action Group: Shopping Cart + Avatar
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const CartScreen()),
                                );
                              },
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFF7ED),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFFFFEDD5)),
                                    ),
                                    child: const Icon(Icons.shopping_cart_outlined, color: AppTheme.primary, size: 20),
                                  ),
                                  Positioned(
                                    top: -4,
                                    right: -4,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primary,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: Colors.white, width: 1.5),
                                      ),
                                      child: Text(
                                        '${cart.itemCount}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                                );
                              },
                              child: Stack(
                                children: [
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: AppTheme.primary.withValues(alpha: 0.4), width: 2),
                                      image: const DecorationImage(
                                        image: NetworkImage(
                                          'https://lh3.googleusercontent.com/aida-public/AB6AXuDt_G-RXYn9TghMxF5lI9vsEQHrGTAXQj1X4F5Uac0AQSeSBFApQTaM5-oTszRR5h9I2GCbmI0hCpORtYSDQsqpj9_QZLF-cJnnst1wwVTDPgQzlmz7cEjpoIkbLMXzk5oFYxbLNoOoBPwYehuvz8M4S6xWVgj58deX9Fcc-dvcQ7dlRu_fUKphsmCP8gfq037OhvFBc2bI_Id_HFJaMz8mhWz3rfWPO6mix9rE-Re4D591mlxYQhIVXg',
                                        ),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 2),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Search Bar Row with Pre-filled Active Query
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.primary, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primary.withValues(alpha: 0.12),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          const Icon(Icons.search, color: AppTheme.primary, size: 22),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                              decoration: const InputDecoration(
                                hintText: 'Search groceries & brands...',
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _searchController.clear();
                              });
                            },
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: const BoxDecoration(
                                color: Color(0xFFF1F5F9),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, size: 13, color: Color(0xFF64748B)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.mic_none, color: Color(0xFF94A3B8), size: 20),
                          const SizedBox(width: 8),
                          Container(width: 1.5, height: 18, color: const Color(0xFFE2E8F0)),
                          const SizedBox(width: 8),
                          // Aisles Filter Button with Orange Funnel Icon
                          GestureDetector(
                            onTap: _navigateToAisle,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF7ED),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFFFEDD5)),
                              ),
                              child: const Row(
                                children: [
                                  Text(
                                    'Aisles',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                  SizedBox(width: 3),
                                  Icon(Icons.filter_alt, size: 15, color: AppTheme.primary),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Main Scrollable Results
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                children: [
                  // 1. Search Status Banner & Filter Chips
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
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
                          RichText(
                            text: TextSpan(
                              style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569)),
                              children: [
                                const TextSpan(text: 'Searching in '),
                                const TextSpan(
                                  text: 'D-Mart HSR Layout',
                                  style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                                ),
                                const TextSpan(text: ' • '),
                                TextSpan(
                                  text: '8 results',
                                  style: const TextStyle(fontWeight: FontWeight.w900, color: AppTheme.primary),
                                ),
                                TextSpan(text: ' for "${_searchController.text.isEmpty ? "Maggi" : _searchController.text}"'),
                              ],
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedFilterIndex = 0;
                          });
                        },
                        child: const Text(
                          'Clear all',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Filter Chips
                  SizedBox(
                    height: 32,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _filters.length,
                      itemBuilder: (context, index) {
                        final isSelected = index == _selectedFilterIndex;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedFilterIndex = index;
                            });
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected ? AppTheme.primary : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected ? AppTheme.primary : const Color(0xFFE2E8F0),
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: AppTheme.primary.withValues(alpha: 0.3),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Text(
                              _filters[index],
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                color: isSelected ? Colors.white : const Color(0xFF334155),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 2. REAL-TIME IN-STORE WAYFINDING MATCH CARD (Top Recommended Result)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFB923C), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top Highlight Badges
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF7ED),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFFFFEDD5)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.radar, color: AppTheme.primary, size: 14),
                                  SizedBox(width: 4),
                                  Text(
                                    'CLOSEST SHELF MATCH',
                                    style: TextStyle(
                                      color: AppTheme.primary,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFFA7F3D0)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF10B981),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Text(
                                    'In Stock (38 units)',
                                    style: TextStyle(
                                      color: Color(0xFF047857),
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Main Item Info
                        GestureDetector(
                          onTap: _navigateToAisle,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 78,
                                height: 78,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF7ED),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFFFEDD5)),
                                ),
                                padding: const EdgeInsets.all(6),
                                child: Image.network(
                                  'https://lh3.googleusercontent.com/aida-public/AB6AXuB72MIl67Yc3bRr8aekPpwAWkc1CFbVabndWuUYISCEP3HmZxjzOuSICRDuq4LW9icFsQurH_iiaoxWF-IZmHDHR2cHa7ENGJUzdGIkkhbJ84ZhK6vLmPNPu81qFey9F472b2TtAZFMX5lxKbtfUBRjxoZ06VEw0n2LIaPaYOR85L5YHYTfkzHIbKh_nm8n4gBduL4qQVp9zZy_sJ37E5PFQBTuL2ZX-rGRYFvvekEd7HNwnWc64eF-_A',
                                  fit: BoxFit.contain,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF008744),
                                            borderRadius: BorderRadius.circular(3),
                                          ),
                                          child: const Text(
                                            'D★Mart',
                                            style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        const Text(
                                          'Packaged Foods',
                                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    const Text(
                                      'Maggi 2-Minute Masala Noodles (Pack of 4, 280g)',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF0F172A),
                                        height: 1.25,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        const Text(
                                          '₹52.00',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w900,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        const Text(
                                          'MRP ₹56.00',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF94A3B8),
                                            decoration: TextDecoration.lineThrough,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFECFDF5),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text(
                                            'Save ₹4',
                                            style: TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF008744),
                                            ),
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

                        const SizedBox(height: 12),

                        // Live Wayfinding & Proximity Strip
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.pin_drop, size: 16, color: AppTheme.primary),
                                      SizedBox(width: 4),
                                      Text(
                                        'Aisle 4 • Sec 2 (Eye Level)',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Padding(
                                    padding: const EdgeInsets.only(left: 20.0),
                                    child: Text(
                                      '14m away • ~20s walk from current position',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              // Guide Button
                              GestureDetector(
                                onTap: _navigateToAisle,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F172A),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.navigation, size: 14, color: AppTheme.primary),
                                      SizedBox(width: 4),
                                      Text(
                                        'Guide',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Quick Add Action
                        SizedBox(
                          width: double.infinity,
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
                              cart.addItem(
                                CartItem(
                                  barcode: '8901058852234',
                                  name: 'Maggi 2-Minute Masala Noodles (Pack of 4, 280g)',
                                  price: 52.0,
                                  originalPrice: 56.0,
                                  quantity: 1,
                                  category: 'Instant Noodles',
                                  aisle: 'Aisle 4 • Sec 2',
                                  timestamp: DateTime.now(),
                                ),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Added Maggi 4-Pack to Smart Trolley')),
                              );
                            },
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_shopping_cart, color: Colors.white, size: 18),
                                SizedBox(width: 8),
                                Text(
                                  'Add to Smart Trolley',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 3. SUBSEQUENT SEARCH MATCH CARDS
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'OTHER MATCHES IN AISLE 3 & 4',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF334155),
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        'Sorted by distance',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Match Card 1: Maggi Special Masala Noodles (70g)
                  _buildSubsequentMatchCard(
                    title: 'Maggi Special Masala Noodles (70g)',
                    aisle: 'Aisle 4 • Sec 2',
                    distance: '• 15m away',
                    price: '₹14.00',
                    imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuB72MIl67Yc3bRr8aekPpwAWkc1CFbVabndWuUYISCEP3HmZxjzOuSICRDuq4LW9icFsQurH_iiaoxWF-IZmHDHR2cHa7ENGJUzdGIkkhbJ84ZhK6vLmPNPu81qFey9F472b2TtAZFMX5lxKbtfUBRjxoZ06VEw0n2LIaPaYOR85L5YHYTfkzHIbKh_nm8n4gBduL4qQVp9zZy_sJ37E5PFQBTuL2ZX-rGRYFvvekEd7HNwnWc64eF-_A',
                    onTap: _navigateToAisle,
                    onAdd: () {
                      cart.addItem(
                        CartItem(
                          barcode: '8901058852241',
                          name: 'Maggi Special Masala Noodles (70g)',
                          price: 14.0,
                          originalPrice: 15.0,
                          aisle: 'Aisle 4 • Sec 2',
                          category: 'Instant Noodles',
                          timestamp: DateTime.now(),
                        ),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Added Maggi Special Masala to Cart')),
                      );
                    },
                  ),

                  const SizedBox(height: 8),

                  // Match Card 2: Maggi Hot & Sweet Chilli Sauce (500g)
                  _buildSubsequentMatchCard(
                    title: 'Maggi Hot & Sweet Chilli Sauce (500g)',
                    aisle: 'Aisle 3 • Sec 1',
                    distance: '• 8m away',
                    price: '₹115.00',
                    imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuCNuqw3kYKh8dfPJOiMpdJjsPyyZjatnNzWA3LZyYSI28vSosOXSq8vwHFfb-1WzwUwDUubxrMXt5cDs1UEIEb948G7DSBl81cBpOjqKGJMrZQUeUyaJ5FyqpG6_1FzvEO2heC4W5AenWNyEtVP1DhpLT5a556Ck3sBTQGfuGVXj8g1xbrfr9DbcYQgIDcTuYk-M4Sig34BYnQGJcSPIMPgLlDFgmGEQQYFuUuwbf-AP482Q5OqqAwYIQ',
                    onTap: _navigateToAisle,
                    onAdd: () {
                      cart.addItem(
                        CartItem(
                          barcode: '8901058852258',
                          name: 'Maggi Hot & Sweet Chilli Sauce (500g)',
                          price: 115.0,
                          originalPrice: 130.0,
                          aisle: 'Aisle 3 • Sec 1',
                          category: 'Sauces & Masala',
                          timestamp: DateTime.now(),
                        ),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Added Maggi Chilli Sauce to Cart')),
                      );
                    },
                  ),

                  const SizedBox(height: 8),

                  // Match Card 3: Maggi Pazzta Cheesy Tomato (64g)
                  _buildSubsequentMatchCard(
                    title: 'Maggi Pazzta Cheesy Tomato (64g)',
                    aisle: 'Aisle 4 • Sec 3',
                    distance: '• 18m away',
                    price: '₹28.00',
                    imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuBZLIqsI8dVdIityH1UduggSeH5uKaj7JjDEeWir3emyLw0NQL7aZe0rx6RCaiFo25gZoqNqJ_aDfVvowa5gT80hyVKZaX1lYmOHe8coYgfJsqBLzYpIWwL9DUTN1FxOSz-7-fe9vixxCtbDt1YaDRji-DNUS4c544gktglt06nWp_0Y_TWIu9v3CInhlhggfhg-HPBw_wiDH1G2hm-4D0EXapxyUAFh2EQMKuUcbvik8SW-WG2McdVLg',
                    onTap: _navigateToAisle,
                    onAdd: () {
                      cart.addItem(
                        CartItem(
                          barcode: '8901058852265',
                          name: 'Maggi Pazzta Cheesy Tomato (64g)',
                          price: 28.0,
                          originalPrice: 32.0,
                          aisle: 'Aisle 4 • Sec 3',
                          category: 'Instant Noodles',
                          timestamp: DateTime.now(),
                        ),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Added Maggi Pazzta to Cart')),
                      );
                    },
                  ),

                  const SizedBox(height: 18),

                  // 4. RECENT SEARCHES & TRENDING IN STORE TAG CLOUD
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.trending_up, color: AppTheme.primary, size: 18),
                                SizedBox(width: 6),
                                Text(
                                  'Trending in D-Mart Today',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              'Live aisle picks',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildTagChip('Amul Butter', hasHistory: true),
                            _buildTagChip('Tata Salt 1kg', hasHistory: true),
                            _buildTagChip('Aashirvaad Atta 5kg', hasFire: true),
                            _buildTagChip('Surf Excel Matic', hasFire: true),
                            _buildTagChip('Parle-G Gold'),
                          ],
                        ),
                      ],
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

  Widget _buildSubsequentMatchCard({
    required String title,
    required String aisle,
    required String distance,
    required String price,
    required String imageUrl,
    required VoidCallback onTap,
    required VoidCallback onAdd,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFF1F5F9)),
              ),
              padding: const EdgeInsets.all(4),
              child: Image.network(imageUrl, fit: BoxFit.contain),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        aisle,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF008744),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        distance,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF94A3B8),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        price,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'In Stock',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF047857),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: onAdd,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFFEDD5)),
                ),
                child: const Icon(Icons.add, color: AppTheme.primary, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagChip(String label, {bool hasHistory = false, bool hasFire = false}) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _searchController.text = label;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasHistory) ...[
              const Icon(Icons.history, size: 14, color: Color(0xFF94A3B8)),
              const SizedBox(width: 4),
            ],
            if (hasFire) ...[
              const Icon(Icons.local_fire_department, size: 14, color: AppTheme.primary),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
