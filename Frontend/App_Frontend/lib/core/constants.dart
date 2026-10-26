/// Global application constants and networking configurations for e-Cart Mobile
class AppConstants {
  // Network Defaults
  static const String defaultLaptopIp = '10.138.30.169';
  static const int defaultServerPort = 8000;
  static const String defaultCartId = 'CART_01';
  static const String defaultUserId = 'U12345';
  static const String defaultUserName = 'Alex Morgan';

  // REST API Endpoints
  static const String pairEndpoint = '/api/session/pair';
  static const String checkoutEndpoint = '/api/session/checkout';
  static const String statusEndpoint = '/api/status';
  static const String syncEndpoint = '/api/cart/sync';
  static const String alertEndpoint = '/api/cart/alert';

  // WebSocket URI Templates
  static String cartWsUrl(String host, int port, String cartId) =>
      'ws://$host:$port/ws/cart/$cartId';

  static String httpBaseUrl(String host, int port) => 'http://$host:$port';

  // Security Alert Constants
  static const String alertUnscannedDrop = 'UNSCANNED_DROP';
  static const String alertWeightMismatch = 'WEIGHT_MISMATCH';
  static const String alertScanCancelled = 'SCAN_CANCELLED';

  // Design Tokens (Google Stitch: Cart-app-screens-final-design)
  static const int primaryColorHex = 0xFFFF6400; // Solar Orange
  static const int secondaryColorHex = 0xFF0F172A; // Slate 900
  static const int tertiaryColorHex = 0xFF10B981; // Supermarket Emerald
  static const int neutralColorHex = 0xFF64748B; // Slate Gray
  static const int backgroundColorHex = 0xFFF8FAFC; // Soft Slate Canvas
  static const int surfaceColorHex = 0xFFFFFFFF; // Pure White Card
  static const int surfaceDarkHex = 0xFF1E293B; // Slate 800 (Trolley Bar)
  static const int hazardErrorHex = 0xFFEF4444; // Anomaly Red
  static const int offerAmberHex = 0xFFF59E0B; // Savings Amber
  static const int wayfindingBlueHex = 0xFF0284C7; // Aisle Navigation Blue
}
