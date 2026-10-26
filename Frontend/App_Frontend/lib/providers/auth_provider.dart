import 'package:flutter/foundation.dart';
import '../core/constants.dart';

/// User authentication and profile state management
class AuthProvider extends ChangeNotifier {
  bool _isAuthenticated = true; // Auto-authenticated for retail shopper MVP
  String _userId = AppConstants.defaultUserId;
  String _userName = AppConstants.defaultUserName;
  String _userPhone = '+91 98765 43210';
  final String _userEmail = 'alex.morgan@retail.com';
  final String _loyaltyTier = 'Gold Member';
  int _rewardPoints = 480;

  bool get isAuthenticated => _isAuthenticated;
  String get userId => _userId;
  String get userName => _userName;
  String get userPhone => _userPhone;
  String get userEmail => _userEmail;
  String get loyaltyTier => _loyaltyTier;
  int get rewardPoints => _rewardPoints;

  void login({
    required String phone,
    String? name,
  }) {
    _isAuthenticated = true;
    _userPhone = phone;
    if (name != null) _userName = name;
    _userId = 'U${phone.replaceAll(RegExp(r'\D'), '').substring(0, 5)}';
    notifyListeners();
  }

  void logout() {
    _isAuthenticated = false;
    notifyListeners();
  }

  void addRewardPoints(int points) {
    _rewardPoints += points;
    notifyListeners();
  }
}
