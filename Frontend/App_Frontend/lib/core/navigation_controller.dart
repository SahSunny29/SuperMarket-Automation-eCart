import 'package:flutter/material.dart';

/// Navigation controller managing shared bottom navbar tabs and root state transitions
class NavigationController extends ChangeNotifier {
  int _currentIndex = 0;
  final List<int> _history = [0];

  int get currentIndex => _currentIndex;
  bool get canPopHistory => _history.length > 1;

  void setIndex(int index) {
    if (_currentIndex != index) {
      _currentIndex = index;
      if (_history.isEmpty || _history.last != index) {
        _history.add(index);
      }
      notifyListeners();
    }
  }

  bool pop() {
    if (_history.length > 1) {
      _history.removeLast();
      _currentIndex = _history.last;
      notifyListeners();
      return true;
    }
    return false;
  }

  void goToHome() => setIndex(0);
  void goToAisles() => setIndex(1);
  void goToScan() => setIndex(2);
  void goToLiveBill() => setIndex(3);
  void goToHistory() => setIndex(4);
}
