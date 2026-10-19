import 'package:flutter/foundation.dart';

import 'api_service.dart';

/// The number on the Cart tab. It lives outside any screen, so every screen's bottom bar shows the same number.
/// ApiService updates it from every cart answer, so it can never disagree with the server.
class CartState {
  CartState._();
  static final CartState instance = CartState._();

  final ValueNotifier<int> count = ValueNotifier<int>(0);

  void update(Map<String, dynamic> cart) {
    final totals = cart['totals'] as Map<String, dynamic>;
    count.value = (totals['item_count'] as num).toInt();
  }

  /// Fetches the cart so the badge is right after the app starts or the user logs in.
  Future<void> refresh() async {
    try {
      await ApiService.instance.getCart(); // getCart updates the count itself
    } on ApiException {
      // The badge keeps its old number. The cart screen shows the real error when it is opened.
    }
  }

  /// Called when the user logs out, so the next user does not see someone else's number.
  void clear() => count.value = 0;
}