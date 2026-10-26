import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/navigation_controller.dart';
import '../core/theme.dart';
import '../core/models.dart';
import '../providers/cart_provider.dart';
import '../providers/search_provider.dart';
import '../widgets/app_bottom_nav_bar.dart';
import 'aisle_screen.dart';
import 'cart_screen.dart';
import 'scan_screen.dart';
import 'searched_screen.dart';
import 'settings_screen.dart';

/// 1:1 Replica of Stitch "search" screen
/// Features: Active Search header, GPS live location, Recent Searches strip,
/// Warm Recommendations container with quick-add, and Trending in DMart Today cards.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _navigateToSearched(String query) {
    context.read<SearchProvider>().search(query);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SearchedScreen(initialQuery: query.isEmpty ? 'Maggi Noodles' : query),
      ),
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
            // 1. TOUCH-FRIENDLY UNIFIED TOP HEADER
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Column(
                children: [
                  // Unified Top App Bar Row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Left: Hamburger Menu Button
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const SettingsScreen()),
                            );
                          },
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: const Icon(Icons.menu, color: Color(0xFF0F172A), size: 22),
                          ),
                        ),

                        // Center: Brand Block & Store Sync Pill
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
                              // Store Sync Dropdown Pill
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
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF008744),
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                      child: const Text(
                                        'D★Mart',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 8,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF10B981),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Text(
                                      'Connected: Bay 14 • #CART_01',
                                      style: TextStyle(
                                        color: Color(0xFF1E293B),
                                        fontSize: 10,
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

                        // Right Action Group: Orange Shopping Cart + Avatar
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
                                          'https://lh3.googleusercontent.com/aida-public/AB6AXuBMqIHVGhIbOgu8VQdb3wxoZSfEV_PvQyiPg8RsJ3oJHuNksKdh36vpum4RNe1GyniQMd7DxtpE2T1fAPORRxtPCYS79lggIl8RTsIvRp3AWUDB9XNdfmF2ULRh7BZ59t3IGuTxaPnt35cP4-j45wtX70QD2a--iQhsUqcYZjSb_GMufVi5AmkzpNAidJk8REPsYKy3hjRC0IAlQx52nTs_rhQ9SioBnBsxTI1viNIpkqDD9Nw5S5rQvw',
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

                  // Active Search Input Row
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () {
                                if (Navigator.of(context).canPop()) {
                                  Navigator.of(context).pop();
                                } else {
                                  context.read<NavigationController>().pop();
                                }
                              },
                              child: const Padding(
                                padding: EdgeInsets.only(right: 8.0),
                                child: Icon(Icons.arrow_back, color: Color(0xFF0F172A), size: 22),
                              ),
                            ),
                            // Search Input Box (Active Focus State)
                            Expanded(
                              child: Container(
                                height: 42,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(24),
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
                                    const Icon(Icons.search, color: AppTheme.primary, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextField(
                                        controller: _searchController,
                                        autofocus: false,
                                        textInputAction: TextInputAction.search,
                                        onSubmitted: _navigateToSearched,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF0F172A),
                                        ),
                                        decoration: const InputDecoration(
                                          hintText: 'Search DMart items, brands or aisles...',
                                          hintStyle: TextStyle(
                                            color: Color(0xFF94A3B8),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          border: InputBorder.none,
                                          isDense: true,
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                      ),
                                    ),
                                    if (_searchController.text.isNotEmpty)
                                      GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _searchController.clear();
                                          });
                                        },
                                        child: Container(
                                          width: 18,
                                          height: 18,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFFF1F5F9),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.close, size: 12, color: Color(0xFF64748B)),
                                        ),
                                      ),
                                    const SizedBox(width: 6),
                                    Container(width: 1, height: 16, color: const Color(0xFFE2E8F0)),
                                    const SizedBox(width: 6),
                                    const Icon(Icons.mic_none, color: Color(0xFF64748B), size: 18),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                _searchController.clear();
                                Navigator.of(context).maybePop();
                              },
                              child: const Text(
                                'Cancel',
                                style: TextStyle(
                                  color: AppTheme.primary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),

                        // Live GPS Store Location Badge Pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Standing: Aisle 3 (Packaged Foods) • 120m to Exit',
                                  style: TextStyle(
                                    color: Color(0xFF065F46),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF059669),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'LIVE GPS',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
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
            ),

            // Main Scrollable Content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                children: [
                  // SECTION 1: RECENT SEARCHES
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Recent Searches',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          // Clear recent searches
                        },
                        child: const Text(
                          'Clear',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Horizontal Scrollable Cards
                  SizedBox(
                    height: 130,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _buildRecentSearchItem(
                          title: 'Maggi 2-Min Noodles',
                          aisle: 'Aisle 3B',
                          imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuB72MIl67Yc3bRr8aekPpwAWkc1CFbVabndWuUYISCEP3HmZxjzOuSICRDuq4LW9icFsQurH_iiaoxWF-IZmHDHR2cHa7ENGJUzdGIkkhbJ84ZhK6vLmPNPu81qFey9F472b2TtAZFMX5lxKbtfUBRjxoZ06VEw0n2LIaPaYOR85L5YHYTfkzHIbKh_nm8n4gBduL4qQVp9zZy_sJ37E5PFQBTuL2ZX-rGRYFvvekEd7HNwnWc64eF-_A',
                          onTap: () => _navigateToSearched('Maggi Noodles'),
                        ),
                        _buildRecentSearchItem(
                          title: 'Amul Butter 500g',
                          aisle: 'Chillers A1',
                          imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuCD-xZzjsgcXuaDvRNyovzM61lWts0vBd2LQ5aa9ott1gmGnSNJ9rPanqidN6a-JbeYyGV-HALBSnOq3T1DlUMfTnSP9H8oM_VPLQXzkXp6gZgT4UClC58fHVjL_AFWhcKKYeBNy4jUCnkzUS3zHbNGCeVnYqaso1I5Xs4b_NRKJkKY3AYeB1YMYwx-QovSfDtTh0HieSkqzqC68ZPV2U29-OzIcdcuL62bz16j383vf6WMnB3Sz_c9ow',
                          onTap: () => _navigateToSearched('Amul Butter'),
                        ),
                        _buildRecentSearchItem(
                          title: 'Tata Salt 1kg',
                          aisle: 'Aisle 3A',
                          imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuDtxS-UXxysAWe18wPRCdPYZYOM17ZQ05sr_6ul8JC9rY_tA7oTTAMC9SJn56r2pAs5Vg4Su6J0qFUdJ2Ii1QQegQAMhe8xf_vOYQdqJCRWLYpfAcxbJv4AvXnl8vGnXN1DP27riY_ayx3fv8Y6jnq7iNIb6ksUa7h4hfbdlHx4Vs4nUubMknjR-e0tpmuEryrbrbP-S3tno5afBn1yO081P9yAGzOv2_VH0zqqE7bfTIgDANJz3-sChA',
                          onTap: () => _navigateToSearched('Tata Salt'),
                        ),
                        _buildRecentSearchItem(
                          title: 'Surf Excel 1kg',
                          aisle: 'Aisle 5C',
                          imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuA4gHb3gXOhchdZ8BFsyCAS83mWj38-RAW3bBuMQWP561qNE_9T5qTfyKod3I6AsYuhK-q7auBG89ClvzJiA1uLfkedKAq0ZZzz1OA1ll6dl-RPV9tHfknPzwgsougjNBNjYvwSoDG78VjTZ4LDfw_vBdS_rvcLHVydY24fHB0HMHw3qfmF29H9Mn1E-GOd5I2AKXeDVi3t7vm-lQFOt6O6TwQneBrZlT6b17k_GVeVhXqamPrw77fTVA',
                          onTap: () => _navigateToSearched('Surf Excel'),
                        ),
                        _buildRecentSearchItem(
                          title: 'Parle-G 250g',
                          aisle: 'Aisle 1C',
                          imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuD4TxNmm2Sa4SHNoklkM9kmr_HUUSXFIqYJ9KMELeyE9TLKqMGkZBwA7_a7qqNAVyzgtzkAplIVwUnHsyTz19yeswP8wRgMHtfotDlkc5i3fBMf8h4gg_reqtdtp9p3Y48TSPhHpzgljLDX-yHpaUNwn1qgjCLo7FdEMvDPrQNVns6N1EBnGxmXbvEyUaNMfALXaYb8SwpH6bLsrmlQ0Sdr-aM8-q_EMMe6eKCEe3XlNRcCg8hdDPCY5g',
                          onTap: () => _navigateToSearched('Parle-G'),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // SECTION 2: RECOMMENDATIONS (Warm Tinted Container)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFED7AA)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text(
                                      'Recommendations',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
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
                                  ],
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Frequently bought & in stock at DMart Bay 14',
                                  style: TextStyle(color: Color(0xFF64748B), fontSize: 10, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                            const Icon(Icons.auto_awesome, color: AppTheme.primary, size: 20),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // 3 Side-by-Side Product Cards
                        Row(
                          children: [
                            Expanded(
                              child: _buildRecommendationCard(
                                title: 'Aashirvaad Atta 5kg',
                                aisle: 'DMart • Aisle 2A',
                                price: '₹245',
                                imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuBZLIqsI8dVdIityH1UduggSeH5uKaj7JjDEeWir3emyLw0NQL7aZe0rx6RCaiFo25gZoqNqJ_aDfVvowa5gT80hyVKZaX1lYmOHe8coYgfJsqBLzYpIWwL9DUTN1FxOSz-7-fe9vixxCtbDt1YaDRji-DNUS4c544gktglt06nWp_0Y_TWIu9v3CInhlhggfhg-HPBw_wiDH1G2hm-4D0EXapxyUAFh2EQMKuUcbvik8SW-WG2McdVLg',
                                onAdd: () {
                                  cart.addItem(
                                    CartItem(
                                      barcode: '8901725181222',
                                      name: 'Aashirvaad Atta 5kg',
                                      price: 245.0,
                                      originalPrice: 280.0,
                                      aisle: 'Aisle 2A',
                                      category: 'Grains & Staples',
                                      timestamp: DateTime.now(),
                                    ),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Added Aashirvaad Atta 5kg to Cart')),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildRecommendationCard(
                                title: 'Parle-G 250g',
                                aisle: 'DMart • Aisle 1C',
                                price: '₹10',
                                imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuD4TxNmm2Sa4SHNoklkM9kmr_HUUSXFIqYJ9KMELeyE9TLKqMGkZBwA7_a7qqNAVyzgtzkAplIVwUnHsyTz19yeswP8wRgMHtfotDlkc5i3fBMf8h4gg_reqtdtp9p3Y48TSPhHpzgljLDX-yHpaUNwn1qgjCLo7FdEMvDPrQNVns6N1EBnGxmXbvEyUaNMfALXaYb8SwpH6bLsrmlQ0Sdr-aM8-q_EMMe6eKCEe3XlNRcCg8hdDPCY5g',
                                onAdd: () {
                                  cart.addItem(
                                    CartItem(
                                      barcode: '8901030383879',
                                      name: 'Parle-G 250g',
                                      price: 10.0,
                                      originalPrice: 12.0,
                                      aisle: 'Aisle 1C',
                                      category: 'Snacks & Sweets',
                                      timestamp: DateTime.now(),
                                    ),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Added Parle-G 250g to Cart')),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildRecommendationCard(
                                title: 'Surf Excel 1kg',
                                aisle: 'DMart • Aisle 5B',
                                price: '₹145',
                                imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuA4gHb3gXOhchdZ8BFsyCAS83mWj38-RAW3bBuMQWP561qNE_9T5qTfyKod3I6AsYuhK-q7auBG89ClvzJiA1uLfkedKAq0ZZzz1OA1ll6dl-RPV9tHfknPzwgsougjNBNjYvwSoDG78VjTZ4LDfw_vBdS_rvcLHVydY24fHB0HMHw3qfmF29H9Mn1E-GOd5I2AKXeDVi3t7vm-lQFOt6O6TwQneBrZlT6b17k_GVeVhXqamPrw77fTVA',
                                onAdd: () {
                                  cart.addItem(
                                    CartItem(
                                      barcode: '8901030383862',
                                      name: 'Surf Excel 1kg',
                                      price: 145.0,
                                      originalPrice: 160.0,
                                      aisle: 'Aisle 5B',
                                      category: 'Household',
                                      timestamp: DateTime.now(),
                                    ),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Added Surf Excel 1kg to Cart')),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // SECTION 3: TRENDING IN DMART TODAY
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 4,
                            height: 16,
                            decoration: BoxDecoration(
                              color: AppTheme.primary,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Trending in DMart Today',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFA7F3D0)),
                            ),
                            child: const Text(
                              'LIVE AISLE STOCK',
                              style: TextStyle(
                                color: Color(0xFF008744),
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () => _navigateToSearched(''),
                        child: const Row(
                          children: [
                            Text(
                              'View All',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primary,
                              ),
                            ),
                            Icon(Icons.chevron_right, size: 16, color: AppTheme.primary),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Horizontal Trending Products
                  SizedBox(
                    height: 195,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _buildTrendingCard(
                          badge: '₹1 OFF',
                          title: 'Maggi 2-Min Noodles',
                          aisle: 'DMart • Aisle 3B',
                          distance: '↗ 12m away',
                          price: '₹14',
                          originalPrice: '₹15',
                          imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuB72MIl67Yc3bRr8aekPpwAWkc1CFbVabndWuUYISCEP3HmZxjzOuSICRDuq4LW9icFsQurH_iiaoxWF-IZmHDHR2cHa7ENGJUzdGIkkhbJ84ZhK6vLmPNPu81qFey9F472b2TtAZFMX5lxKbtfUBRjxoZ06VEw0n2LIaPaYOR85L5YHYTfkzHIbKh_nm8n4gBduL4qQVp9zZy_sJ37E5PFQBTuL2ZX-rGRYFvvekEd7HNwnWc64eF-_A',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const AisleScreen()),
                            );
                          },
                        ),
                        _buildTrendingCard(
                          badge: '11% OFF',
                          title: 'Amul Butter 500g',
                          aisle: 'DMart • Chillers A1',
                          distance: '↗ 24m away',
                          price: '₹245',
                          originalPrice: '₹275',
                          imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuCD-xZzjsgcXuaDvRNyovzM61lWts0vBd2LQ5aa9ott1gmGnSNJ9rPanqidN6a-JbeYyGV-HALBSnOq3T1DlUMfTnSP9H8oM_VPLQXzkXp6gZgT4UClC58fHVjL_AFWhcKKYeBNy4jUCnkzUS3zHbNGCeVnYqaso1I5Xs4b_NRKJkKY3AYeB1YMYwx-QovSfDtTh0HieSkqzqC68ZPV2U29-OzIcdcuL62bz16j383vf6WMnB3Sz_c9ow',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const AisleScreen()),
                            );
                          },
                        ),
                        _buildTrendingCard(
                          badge: '₹2 OFF',
                          title: 'Tata Salt 1kg',
                          aisle: 'DMart • Aisle 3A',
                          distance: '↗ 8m away',
                          price: '₹28',
                          originalPrice: '₹30',
                          imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuDtxS-UXxysAWe18wPRCdPYZYOM17ZQ05sr_6ul8JC9rY_tA7oTTAMC9SJn56r2pAs5Vg4Su6J0qFUdJ2Ii1QQegQAMhe8xf_vOYQdqJCRWLYpfAcxbJv4AvXnl8vGnXN1DP27riY_ayx3fv8Y6jnq7iNIb6ksUa7h4hfbdlHx4Vs4nUubMknjR-e0tpmuEryrbrbP-S3tno5afBn1yO081P9yAGzOv2_VH0zqqE7bfTIgDANJz3-sChA',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const AisleScreen()),
                            );
                          },
                        ),
                        _buildTrendingCard(
                          badge: '₹15 OFF',
                          title: 'Surf Excel 1kg',
                          aisle: 'DMart • Aisle 5B',
                          distance: '↗ 32m away',
                          price: '₹145',
                          originalPrice: '₹160',
                          imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuA4gHb3gXOhchdZ8BFsyCAS83mWj38-RAW3bBuMQWP561qNE_9T5qTfyKod3I6AsYuhK-q7auBG89ClvzJiA1uLfkedKAq0ZZzz1OA1ll6dl-RPV9tHfknPzwgsougjNBNjYvwSoDG78VjTZ4LDfw_vBdS_rvcLHVydY24fHB0HMHw3qfmF29H9Mn1E-GOd5I2AKXeDVi3t7vm-lQFOt6O6TwQneBrZlT6b17k_GVeVhXqamPrw77fTVA',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const AisleScreen()),
                            );
                          },
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

  Widget _buildRecentSearchItem({
    required String title,
    required String aisle,
    required String imageUrl,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 82,
        margin: const EdgeInsets.only(right: 10),
        child: Column(
          children: [
            Container(
              width: 78,
              height: 78,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Image.network(imageUrl, fit: BoxFit.contain),
            ),
            const SizedBox(height: 5),
            Text(
              title,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: Text(
                aisle,
                style: const TextStyle(
                  color: Color(0xFF008744),
                  fontSize: 8.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationCard({
    required String title,
    required String aisle,
    required String price,
    required String imageUrl,
    required VoidCallback onAdd,
  }) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFEDD5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Container(
                height: 72,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(4),
                child: Image.network(imageUrl, fit: BoxFit.contain),
              ),
              Positioned(
                bottom: 4,
                right: 4,
                child: GestureDetector(
                  onTap: onAdd,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: AppTheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 14),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            aisle,
            style: const TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w700,
              color: Color(0xFF008744),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                price,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'In Stock',
                  style: TextStyle(
                    fontSize: 7.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF008744),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrendingCard({
    required String badge,
    required String title,
    required String aisle,
    required String distance,
    required String price,
    required String originalPrice,
    required String imageUrl,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 128,
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  height: 80,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Image.network(imageUrl, fit: BoxFit.contain),
                ),
                Positioned(
                  top: 2,
                  left: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFF008744),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    aisle,
                    style: const TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF008744),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  distance,
                  style: const TextStyle(
                    fontSize: 8,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            Text(
              title,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.only(top: 4),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        price,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        originalPrice,
                        style: const TextStyle(
                          fontSize: 9,
                          color: Color(0xFF94A3B8),
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'In Stock',
                      style: TextStyle(
                        fontSize: 7.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF008744),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
