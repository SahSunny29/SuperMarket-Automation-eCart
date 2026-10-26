import 'package:flutter/foundation.dart';
import '../core/models.dart';

/// Store catalog and aisle wayfinding search provider
class SearchProvider extends ChangeNotifier {
  String _query = '';
  String? _selectedCategory;
  String? _selectedAisle;
  bool _isSearching = false;

  final List<String> _recentSearches = [
    'Maggi 2-Min Noodles',
    'Amul Butter 500g',
    'Tata Salt 1kg',
    'Surf Excel 1kg',
    'Parle-G 250g',
  ];

  // Pre-seeded retail product inventory for instant mock searches
  final List<StoreProduct> _allProducts = [
    const StoreProduct(
      id: 'MAGGI_01',
      name: 'Maggi 2-Minute Masala Noodles (Pack of 4, 280g)',
      barcode: '8901058852234',
      price: 52.0,
      originalPrice: 56.0,
      aisle: 'Aisle 4 • Sec 2 (Eye Level)',
      category: 'Instant Noodles',
      stock: 38,
      distanceMeters: 14.0,
      imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuB72MIl67Yc3bRr8aekPpwAWkc1CFbVabndWuUYISCEP3HmZxjzOuSICRDuq4LW9icFsQurH_iiaoxWF-IZmHDHR2cHa7ENGJUzdGIkkhbJ84ZhK6vLmPNPu81qFey9F472b2TtAZFMX5lxKbtfUBRjxoZ06VEw0n2LIaPaYOR85L5YHYTfkzHIbKh_nm8n4gBduL4qQVp9zZy_sJ37E5PFQBTuL2ZX-rGRYFvvekEd7HNwnWc64eF-_A',
    ),
    const StoreProduct(
      id: 'MAGGI_02',
      name: 'Maggi Special Masala Noodles (70g)',
      barcode: '8901058852241',
      price: 14.0,
      originalPrice: 15.0,
      aisle: 'Aisle 4 • Sec 2',
      category: 'Instant Noodles',
      stock: 42,
      distanceMeters: 15.0,
      imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuB72MIl67Yc3bRr8aekPpwAWkc1CFbVabndWuUYISCEP3HmZxjzOuSICRDuq4LW9icFsQurH_iiaoxWF-IZmHDHR2cHa7ENGJUzdGIkkhbJ84ZhK6vLmPNPu81qFey9F472b2TtAZFMX5lxKbtfUBRjxoZ06VEw0n2LIaPaYOR85L5YHYTfkzHIbKh_nm8n4gBduL4qQVp9zZy_sJ37E5PFQBTuL2ZX-rGRYFvvekEd7HNwnWc64eF-_A',
    ),
    const StoreProduct(
      id: 'MAGGI_03',
      name: 'Maggi Hot & Sweet Chilli Sauce (500g)',
      barcode: '8901058852258',
      price: 115.0,
      originalPrice: 130.0,
      aisle: 'Aisle 3 • Sec 1',
      category: 'Sauces & Masala',
      stock: 20,
      distanceMeters: 8.0,
      imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuCNuqw3kYKh8dfPJOiMpdJjsPyyZjatnNzWA3LZyYSI28vSosOXSq8vwHFfb-1WzwUwDUubxrMXt5cDs1UEIEb948G7DSBl81cBpOjqKGJMrZQUeUyaJ5FyqpG6_1FzvEO2heC4W5AenWNyEtVP1DhpLT5a556Ck3sBTQGfuGVXj8g1xbrfr9DbcYQgIDcTuYk-M4Sig34BYnQGJcSPIMPgLlDFgmGEQQYFuUuwbf-AP482Q5OqqAwYIQ',
    ),
    const StoreProduct(
      id: 'MAGGI_04',
      name: 'Maggi Pazzta Cheesy Tomato (64g)',
      barcode: '8901058852265',
      price: 28.0,
      originalPrice: 32.0,
      aisle: 'Aisle 4 • Sec 3',
      category: 'Instant Noodles',
      stock: 25,
      distanceMeters: 18.0,
      imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuBZLIqsI8dVdIityH1UduggSeH5uKaj7JjDEeWir3emyLw0NQL7aZe0rx6RCaiFo25gZoqNqJ_aDfVvowa5gT80hyVKZaX1lYmOHe8coYgfJsqBLzYpIWwL9DUTN1FxOSz-7-fe9vixxCtbDt1YaDRji-DNUS4c544gktglt06nWp_0Y_TWIu9v3CInhlhggfhg-HPBw_wiDH1G2hm-4D0EXapxyUAFh2EQMKuUcbvik8SW-WG2McdVLg',
    ),
    const StoreProduct(
      id: 'AMUL_01',
      name: 'Amul Butter 500g',
      barcode: '8901030383848',
      price: 245.0,
      originalPrice: 275.0,
      aisle: 'Chillers A1',
      category: 'Dairy',
      stock: 45,
      distanceMeters: 24.0,
      imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuCD-xZzjsgcXuaDvRNyovzM61lWts0vBd2LQ5aa9ott1gmGnSNJ9rPanqidN6a-JbeYyGV-HALBSnOq3T1DlUMfTnSP9H8oM_VPLQXzkXp6gZgT4UClC58fHVjL_AFWhcKKYeBNy4jUCnkzUS3zHbNGCeVnYqaso1I5Xs4b_NRKJkKY3AYeB1YMYwx-QovSfDtTh0HieSkqzqC68ZPV2U29-OzIcdcuL62bz16j383vf6WMnB3Sz_c9ow',
    ),
    const StoreProduct(
      id: 'TATA_01',
      name: 'Tata Salt 1kg',
      barcode: '8901030383855',
      price: 28.0,
      originalPrice: 30.0,
      aisle: 'Aisle 3A',
      category: 'Cooking Essentials',
      stock: 90,
      distanceMeters: 8.0,
      imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuDtxS-UXxysAWe18wPRCdPYZYOM17ZQ05sr_6ul8JC9rY_tA7oTTAMC9SJn56r2pAs5Vg4Su6J0qFUdJ2Ii1QQegQAMhe8xf_vOYQdqJCRWLYpfAcxbJv4AvXnl8vGnXN1DP27riY_ayx3fv8Y6jnq7iNIb6ksUa7h4hfbdlHx4Vs4nUubMknjR-e0tpmuEryrbrbP-S3tno5afBn1yO081P9yAGzOv2_VH0zqqE7bfTIgDANJz3-sChA',
    ),
    const StoreProduct(
      id: 'SURF_01',
      name: 'Surf Excel 1kg',
      barcode: '8901030383862',
      price: 145.0,
      originalPrice: 160.0,
      aisle: 'Aisle 5C',
      category: 'Household',
      stock: 50,
      distanceMeters: 32.0,
      imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuA4gHb3gXOhchdZ8BFsyCAS83mWj38-RAW3bBuMQWP561qNE_9T5qTfyKod3I6AsYuhK-q7auBG89ClvzJiA1uLfkedKAq0ZZzz1OA1ll6dl-RPV9tHfknPzwgsougjNBNjYvwSoDG78VjTZ4LDfw_vBdS_rvcLHVydY24fHB0HMHw3qfmF29H9Mn1E-GOd5I2AKXeDVi3t7vm-lQFOt6O6TwQneBrZlT6b17k_GVeVhXqamPrw77fTVA',
    ),
    const StoreProduct(
      id: 'PARLE_01',
      name: 'Parle-G 250g',
      barcode: '8901030383879',
      price: 10.0,
      originalPrice: 12.0,
      aisle: 'Aisle 1C',
      category: 'Snacks & Sweets',
      stock: 120,
      distanceMeters: 16.0,
      imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuD4TxNmm2Sa4SHNoklkM9kmr_HUUSXFIqYJ9KMELeyE9TLKqMGkZBwA7_a7qqNAVyzgtzkAplIVwUnHsyTz19yeswP8wRgMHtfotDlkc5i3fBMf8h4gg_reqtdtp9p3Y48TSPhHpzgljLDX-yHpaUNwn1qgjCLo7FdEMvDPrQNVns6N1EBnGxmXbvEyUaNMfALXaYb8SwpH6bLsrmlQ0Sdr-aM8-q_EMMe6eKCEe3XlNRcCg8hdDPCY5g',
    ),
    const StoreProduct(
      id: 'ATTA_01',
      name: 'Aashirvaad Atta 5kg',
      barcode: '8901725181222',
      price: 245.0,
      originalPrice: 280.0,
      aisle: 'Aisle 2A',
      category: 'Grains & Staples',
      stock: 40,
      distanceMeters: 19.0,
      imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuBZLIqsI8dVdIityH1UduggSeH5uKaj7JjDEeWir3emyLw0NQL7aZe0rx6RCaiFo25gZoqNqJ_aDfVvowa5gT80hyVKZaX1lYmOHe8coYgfJsqBLzYpIWwL9DUTN1FxOSz-7-fe9vixxCtbDt1YaDRji-DNUS4c544gktglt06nWp_0Y_TWIu9v3CInhlhggfhg-HPBw_wiDH1G2hm-4D0EXapxyUAFh2EQMKuUcbvik8SW-WG2McdVLg',
    ),
  ];

  String get query => _query;
  String? get selectedCategory => _selectedCategory;
  String? get selectedAisle => _selectedAisle;
  bool get isSearching => _isSearching;
  List<String> get recentSearches => List.unmodifiable(_recentSearches);

  List<StoreProduct> get searchResults {
    return _allProducts.where((product) {
      final matchesQuery = _query.isEmpty ||
          product.name.toLowerCase().contains(_query.toLowerCase()) ||
          product.barcode.contains(_query) ||
          product.category.toLowerCase().contains(_query.toLowerCase());

      final matchesCategory = _selectedCategory == null ||
          product.category == _selectedCategory;

      final matchesAisle =
          _selectedAisle == null || product.aisle.contains(_selectedAisle!);

      return matchesQuery && matchesCategory && matchesAisle;
    }).toList();
  }

  void search(String newQuery) {
    _query = newQuery;
    _isSearching = true;
    notifyListeners();

    if (newQuery.trim().isNotEmpty && !_recentSearches.contains(newQuery.trim())) {
      _recentSearches.insert(0, newQuery.trim());
      if (_recentSearches.length > 8) _recentSearches.removeLast();
    }
  }

  void clearSearch() {
    _query = '';
    _selectedCategory = null;
    _selectedAisle = null;
    _isSearching = false;
    notifyListeners();
  }

  void setCategory(String? category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void setAisle(String? aisle) {
    _selectedAisle = aisle;
    notifyListeners();
  }
}
