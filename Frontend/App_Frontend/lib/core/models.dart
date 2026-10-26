/// Data models representing cart items, alerts, and products
library;

class CartItem {
  final String barcode;
  final String name;
  final double price;
  final double originalPrice;
  final int quantity;
  final String category;
  final String aisle;
  final int weightGrams;
  final bool visionVerified;
  final DateTime timestamp;
  final String? imageUrl;

  const CartItem({
    required this.barcode,
    required this.name,
    required this.price,
    this.originalPrice = 0.0,
    this.quantity = 1,
    this.category = 'Groceries',
    this.aisle = 'Aisle 1',
    this.weightGrams = 250,
    this.visionVerified = true,
    required this.timestamp,
    this.imageUrl,
  });

  double get total => price * quantity;
  double get savings =>
      originalPrice > price ? (originalPrice - price) * quantity : 0.0;

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      barcode: json['barcode']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Retail Item',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      originalPrice: (json['original_price'] as num?)?.toDouble() ??
          (json['mrp'] as num?)?.toDouble() ??
          0.0,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      category: json['category']?.toString() ?? 'Groceries',
      aisle: json['aisle']?.toString() ?? 'Aisle 1',
      weightGrams: (json['weight_grams'] as num?)?.toInt() ?? 250,
      visionVerified: json['vision_verified'] == true ||
          json['verified'] == true ||
          json['is_verified'] == true,
      timestamp: json['timestamp'] != null
          ? (json['timestamp'] is num
              ? DateTime.fromMillisecondsSinceEpoch(
                  ((json['timestamp'] as num) * 1000).toInt())
              : DateTime.tryParse(json['timestamp'].toString()) ??
                  DateTime.now())
          : DateTime.now(),
      imageUrl: json['image_url']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'barcode': barcode,
      'name': name,
      'price': price,
      'original_price': originalPrice,
      'quantity': quantity,
      'category': category,
      'aisle': aisle,
      'weight_grams': weightGrams,
      'vision_verified': visionVerified,
      'timestamp': timestamp.toIso8601String(),
      'image_url': imageUrl,
    };
  }

  CartItem copyWith({
    String? barcode,
    String? name,
    double? price,
    double? originalPrice,
    int? quantity,
    String? category,
    String? aisle,
    int? weightGrams,
    bool? visionVerified,
    DateTime? timestamp,
    String? imageUrl,
  }) {
    return CartItem(
      barcode: barcode ?? this.barcode,
      name: name ?? this.name,
      price: price ?? this.price,
      originalPrice: originalPrice ?? this.originalPrice,
      quantity: quantity ?? this.quantity,
      category: category ?? this.category,
      aisle: aisle ?? this.aisle,
      weightGrams: weightGrams ?? this.weightGrams,
      visionVerified: visionVerified ?? this.visionVerified,
      timestamp: timestamp ?? this.timestamp,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}

class SecurityAlert {
  final String alertType;
  final String cartId;
  final String message;
  final DateTime timestamp;
  final bool isResolved;

  const SecurityAlert({
    required this.alertType,
    required this.cartId,
    required this.message,
    required this.timestamp,
    this.isResolved = false,
  });

  factory SecurityAlert.fromJson(Map<String, dynamic> json) {
    return SecurityAlert(
      alertType: json['alert_type']?.toString() ??
          json['action']?.toString() ??
          'UNSCANNED_DROP',
      cartId: json['cart_id']?.toString() ?? 'CART_01',
      message: json['message']?.toString() ??
          'Unscanned physical item detected in cart basket.',
      timestamp: json['timestamp'] != null
          ? (json['timestamp'] is num
              ? DateTime.fromMillisecondsSinceEpoch(
                  ((json['timestamp'] as num) * 1000).toInt())
              : DateTime.tryParse(json['timestamp'].toString()) ??
                  DateTime.now())
          : DateTime.now(),
      isResolved: json['is_resolved'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'alert_type': alertType,
      'cart_id': cartId,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
      'is_resolved': isResolved,
    };
  }
}

class StoreProduct {
  final String id;
  final String name;
  final String barcode;
  final double price;
  final double originalPrice;
  final String aisle;
  final String category;
  final int stock;
  final double distanceMeters;
  final String? imageUrl;

  const StoreProduct({
    required this.id,
    required this.name,
    required this.barcode,
    required this.price,
    required this.originalPrice,
    required this.aisle,
    required this.category,
    required this.stock,
    this.distanceMeters = 5.0,
    this.imageUrl,
  });

  double get discountPercent =>
      originalPrice > price ? ((originalPrice - price) / originalPrice) * 100 : 0.0;

  factory StoreProduct.fromJson(Map<String, dynamic> json) {
    return StoreProduct(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      barcode: json['barcode']?.toString() ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      originalPrice: (json['original_price'] as num?)?.toDouble() ?? 0.0,
      aisle: json['aisle']?.toString() ?? 'Aisle 1',
      category: json['category']?.toString() ?? 'Groceries',
      stock: (json['stock'] as num?)?.toInt() ?? 10,
      distanceMeters: (json['distance_meters'] as num?)?.toDouble() ?? 5.0,
      imageUrl: json['image_url']?.toString(),
    );
  }
}
