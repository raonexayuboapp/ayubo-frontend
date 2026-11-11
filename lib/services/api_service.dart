import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';
import '../utils/money.dart';
import 'cart_state.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final Map<String, String> fieldErrors;

  ApiException(this.message, {this.statusCode, this.fieldErrors = const {}});

  @override
  String toString() => message;
}

class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  // 10.0.2.2 = your PC from the Android emulator. Override with --dart-define.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

  static const _tokenKey = 'auth_token';
  final _storage = const FlutterSecureStorage();

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Accept': 'application/json'},
      validateStatus: (_) => true, // we handle every status ourselves
    ),
  );

  // ---------- core request ----------

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Object? body,
    bool auth = false,
  }) async {
    final headers = <String, dynamic>{'Accept-Language': currentAppLocale};

    if (auth) {
      final token = await _storage.read(key: _tokenKey);
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    debugPrint('API BASE URL: ${_dio.options.baseUrl}');
    debugPrint('REQUEST URL: ${_dio.options.baseUrl}$path');

    final Response<dynamic> res;

    try {
      res = await _dio.request<dynamic>(
        path,
        data: body,
        options: Options(method: method, headers: headers),
      );
    } on DioException catch (e) {
      debugPrint('DIO ERROR TYPE: ${e.type}');
      debugPrint('DIO ERROR MESSAGE: ${e.message}');
      debugPrint('DIO ERROR DETAILS: ${e.error}');
      debugPrint('DIO ERROR URL: ${e.requestOptions.uri}');

      String message =
          'Cannot reach the server. Please check your network connection.';

      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        message = 'Connection timed out. Please try again.';
      } else if (e.type == DioExceptionType.connectionError) {
        message =
            'Unable to connect to server. Ensure your backend is running.';
      } else if (e.message != null && e.message!.isNotEmpty) {
        message = e.message!;
      }

      throw ApiException('Network error: $message');
    }

    final code = res.statusCode ?? 0;

    final map = res.data is Map<String, dynamic>
        ? res.data as Map<String, dynamic>
        : <String, dynamic>{};

    if (code >= 200 && code < 300) return map;

    if (auth && code == 401) {
      await _storage.delete(key: _tokenKey);
    }

    final errs = map['errors'];

    throw ApiException(
      (map['message'] as String?) ?? 'Something went wrong.',
      statusCode: code,
      fieldErrors: errs is Map
          ? errs.map((k, v) => MapEntry(k.toString(), v.toString()))
          : const {},
    );
  }

  // ---------- endpoints ----------

  Future<void> health() async {
    await _send('GET', '/api/health');
  }

  Future<void> register({
    required String firstName,
    required String lastName,
    required String mobileNumber,
    required String email,
    required String password,
    required String passwordConfirmation,
  }) async {
    await _send(
      'POST',
      '/api/auth/register',
      body: {
        'first_name': firstName,
        'last_name': lastName,
        'mobile_number': mobileNumber,
        'email': email,
        'password': password,
        'password_confirmation': passwordConfirmation,
      },
    );
  }

  Future<void> verifyEmail({
    required String email,
    required String code,
  }) async {
    await _send(
      'POST',
      '/api/auth/verify-email',
      body: {'email': email, 'code': code},
    );
  }

  Future<void> resendVerification(String email) async {
    await _send(
      'POST',
      '/api/auth/resend-verification',
      body: {'email': email},
    );
  }

  Future<void> forgotPassword(String email) async {
    await _send('POST', '/api/auth/forgot-password', body: {'email': email});
  }

  Future<void> resetPassword({
    required String email,
    required String code,
    required String password,
    required String passwordConfirmation,
  }) async {
    await _send(
      'POST',
      '/api/auth/reset-password',
      body: {
        'email': email,
        'code': code,
        'password': password,
        'password_confirmation': passwordConfirmation,
      },
    );
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirmation,
  }) async {
    await _send(
      'POST',
      '/api/auth/change-password',
      auth: true,
      body: {
        'current_password': currentPassword,
        'new_password': newPassword,
        'new_password_confirmation': newPasswordConfirmation,
      },
    );
  }

  Future<Map<String, dynamic>> updateProfile({
    required String firstName,
    required String lastName,
    required String mobileNumber,
  }) async {
    final res = await _send(
      'PATCH',
      '/api/profile',
      auth: true,
      body: {
        'first_name': firstName,
        'last_name': lastName,
        'mobile_number': mobileNumber,
      },
    );
    return (res['data'] as Map<String, dynamic>)['user']
        as Map<String, dynamic>;
  }

  /// Saves the customer's selected app language to their profile.
  /// Only 'en' and 'de' are supported by the backend.
  Future<Map<String, dynamic>> updatePreferredLanguage(
    String languageCode,
  ) async {
    final res = await _send(
      'PATCH',
      '/api/profile',
      auth: true,
      body: {'preferred_language': languageCode},
    );
    return (res['data'] as Map<String, dynamic>)['user']
        as Map<String, dynamic>;
  }

  Future<void> deleteAccount(String password) async {
    await _send(
      'DELETE',
      '/api/profile',
      auth: true,
      body: {'password': password},
    );
    await _storage.delete(key: _tokenKey);
    CartState.instance.clear();
  }

  Future<List<Map<String, dynamic>>> listAddresses() async {
    final res = await _send('GET', '/api/addresses', auth: true);
    final list =
        (res['data'] as Map<String, dynamic>)['addresses'] as List<dynamic>;
    return list.cast<Map<String, dynamic>>();
  }

  Future<void> createAddress(Map<String, dynamic> body) async {
    await _send('POST', '/api/addresses', auth: true, body: body);
  }

  Future<void> updateAddress(int id, Map<String, dynamic> body) async {
    await _send('PATCH', '/api/addresses/$id', auth: true, body: body);
  }

  Future<void> deleteAddress(int id) async {
    await _send('DELETE', '/api/addresses/$id', auth: true);
  }

  /// Stores the token securely and returns the user map.
  /// A 403 ApiException means the email is not verified yet.
  Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await _send(
      'POST',
      '/api/auth/login',
      body: {'email': email, 'password': password},
    );
    final data = res['data'] as Map<String, dynamic>;
    await _storage.write(key: _tokenKey, value: data['token'] as String);
    return data['user'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> me() async {
    final res = await _send('GET', '/api/me', auth: true);
    return (res['data'] as Map<String, dynamic>)['user']
        as Map<String, dynamic>;
  }

  Future<void> logout() async {
    try {
      await _send('POST', '/api/auth/logout', auth: true);
    } on ApiException {
      // Even if the server call fails, forget the token locally.
    } finally {
      await _storage.delete(key: _tokenKey);
      CartState.instance.clear();
    }
  }

  Future<bool> hasToken() async =>
      (await _storage.read(key: _tokenKey)) != null;

  Future<Map<String, dynamic>> adminListUsers({
    String search = '',
    int page = 1,
  }) async {
    final path = Uri(
      path: '/api/admin/users',
      queryParameters: {
        if (search.isNotEmpty) 'search': search,
        'page': '$page',
      },
    ).toString();
    final res = await _send('GET', path, auth: true);
    return res['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> adminUpdateUser(
    int id,
    Map<String, dynamic> body,
  ) async {
    final res = await _send(
      'PATCH',
      '/api/admin/users/$id',
      auth: true,
      body: body,
    );
    return (res['data'] as Map<String, dynamic>)['user']
        as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> adminListPlans() async {
    final res = await _send('GET', '/api/admin/membership-plans', auth: true);
    final list =
        (res['data'] as Map<String, dynamic>)['plans'] as List<dynamic>;
    return list.cast<Map<String, dynamic>>();
  }

  Future<void> adminCreatePlan(Map<String, dynamic> body) async {
    await _send('POST', '/api/admin/membership-plans', auth: true, body: body);
  }

  Future<void> adminUpdatePlan(int id, Map<String, dynamic> body) async {
    await _send(
      'PATCH',
      '/api/admin/membership-plans/$id',
      auth: true,
      body: body,
    );
  }

  // ---------- cart ----------

  /// Adds the selected app language to every cart request.
  /// Example: /api/cart?lang=en
  String _cartPath(String path) {
    return Uri(
      path: path,
      queryParameters: {'lang': currentAppLocale},
    ).toString();
  }

  Future<Map<String, dynamic>> getCart() async {
    return _cart(await _send('GET', _cartPath('/api/cart'), auth: true));
  }

  Future<Map<String, dynamic>> addToCart(int variantId, int quantity) async {
    return _cart(
      await _send(
        'POST',
        _cartPath('/api/cart/items'),
        auth: true,
        body: {'variant_id': variantId, 'quantity': quantity},
      ),
    );
  }

  Future<Map<String, dynamic>> setCartQuantity(int itemId, int quantity) async {
    return _cart(
      await _send(
        'PATCH',
        _cartPath('/api/cart/items/$itemId'),
        auth: true,
        body: {'quantity': quantity},
      ),
    );
  }

  Future<Map<String, dynamic>> removeCartItem(int itemId) async {
    return _cart(
      await _send('DELETE', _cartPath('/api/cart/items/$itemId'), auth: true),
    );
  }

  /// Every cart answer is the WHOLE cart. The badge is updated here, so no screen can forget to.
  Map<String, dynamic> _cart(Map<String, dynamic> res) {
    final cart =
        (res['data'] as Map<String, dynamic>)['cart'] as Map<String, dynamic>;
    CartState.instance.update(cart);
    return cart;
  }

  // ---------- memberships ----------

  /// {plans: [...], membership: {...} or null}
  Future<Map<String, dynamic>> membershipPlans() async {
    final res = await _send('GET', '/api/membership-plans', auth: true);
    return res['data'] as Map<String, dynamic>;
  }

  /// Customer purchase of a membership plan. Adds the plan's product variant to cart.
  Future<Map<String, dynamic>> purchaseMembership(int planId) async {
    final res = await _send(
      'POST',
      '/api/memberships',
      auth: true,
      body: {'plan_id': planId},
    );
    return res['data'] as Map<String, dynamic>;
  }

  // ---------- admin: membership plans ----------

  Future<List<Map<String, dynamic>>> adminMembershipPlans() async {
    final res = await _send('GET', '/api/admin/membership-plans', auth: true);
    final list =
        (res['data'] as Map<String, dynamic>)['plans'] as List<dynamic>;
    return list.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> adminMembershipPlan(int id) async {
    final res = await _send(
      'GET',
      '/api/admin/membership-plans/$id',
      auth: true,
    );
    return (res['data'] as Map<String, dynamic>)['plan']
        as Map<String, dynamic>;
  }

  Future<void> adminCreateMembershipPlan(Map<String, dynamic> body) async {
    await _send('POST', '/api/admin/membership-plans', auth: true, body: body);
  }

  Future<void> adminUpdateMembershipPlan(
    int id,
    Map<String, dynamic> body,
  ) async {
    await _send(
      'PATCH',
      '/api/admin/membership-plans/$id',
      auth: true,
      body: body,
    );
  }

  // ---------- products (customer) ----------

  Future<Map<String, dynamic>> listProducts({
    String search = '',
    int? categoryId,
    String sort = 'newest',
    int page = 1,
  }) async {
    final path = Uri(
      path: '/api/products',
      queryParameters: {
        'page': '$page',
        'sort': sort,
        'lang': currentAppLocale,
        if (search.isNotEmpty) 'search': search,
        if (categoryId != null) 'category_id': '$categoryId',
      },
    ).toString();
    final res = await _send('GET', path, auth: true);
    return res['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getProduct(int id) async {
    final res = await _send(
      'GET',
      '/api/products/$id?lang=$currentAppLocale',
      auth: true,
    );
    return (res['data'] as Map<String, dynamic>)['product']
        as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> listCategories() async {
    final res = await _send(
      'GET',
      '/api/categories?lang=$currentAppLocale',
      auth: true,
    );
    final list =
        (res['data'] as Map<String, dynamic>)['categories'] as List<dynamic>;
    return list.cast<Map<String, dynamic>>();
  }

  // ---------- products (admin) ----------

  Future<Map<String, dynamic>> adminListProducts({
    String search = '',
    String status = '',
    int page = 1,
  }) async {
    final path = Uri(
      path: '/api/admin/products',
      queryParameters: {
        'page': '$page',
        if (search.isNotEmpty) 'search': search,
        if (status.isNotEmpty) 'status': status,
      },
    ).toString();
    final res = await _send('GET', path, auth: true);
    return res['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> adminGetProduct(int id) async {
    final res = await _send('GET', '/api/admin/products/$id', auth: true);
    return (res['data'] as Map<String, dynamic>)['product']
        as Map<String, dynamic>;
  }

  Future<void> adminCreateProduct(Map<String, dynamic> body) async {
    await _send('POST', '/api/admin/products', auth: true, body: body);
  }

  Future<void> adminUpdateProduct(int id, Map<String, dynamic> body) async {
    await _send('PATCH', '/api/admin/products/$id', auth: true, body: body);
  }

  Future<List<Map<String, dynamic>>> adminTaxRates({bool all = false}) async {
    final res = await _send(
      'GET',
      all ? '/api/admin/tax-rates?all=1' : '/api/admin/tax-rates',
      auth: true,
    );
    final list =
        (res['data'] as Map<String, dynamic>)['tax_rates'] as List<dynamic>;
    return list.cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> adminCategories() async {
    final res = await _send('GET', '/api/admin/categories', auth: true);
    final list =
        (res['data'] as Map<String, dynamic>)['categories'] as List<dynamic>;
    return list.cast<Map<String, dynamic>>();
  }

  // ---------- favourites ----------

  Future<Map<String, dynamic>> listFavourites({int page = 1}) async {
    final res = await _send('GET', '/api/favourites?page=$page', auth: true);
    return res['data'] as Map<String, dynamic>;
  }

  Future<void> addFavourite(int productId) async {
    await _send('POST', '/api/products/$productId/favourite', auth: true);
  }

  Future<void> removeFavourite(int productId) async {
    await _send('DELETE', '/api/products/$productId/favourite', auth: true);
  }

  // ---------- admin: categories ----------

  Future<Map<String, dynamic>> adminGetCategory(int id) async {
    final res = await _send('GET', '/api/admin/categories/$id', auth: true);
    return (res['data'] as Map<String, dynamic>)['category']
        as Map<String, dynamic>;
  }

  Future<void> adminCreateCategory(Map<String, dynamic> body) async {
    await _send('POST', '/api/admin/categories', auth: true, body: body);
  }

  Future<void> adminUpdateCategory(int id, Map<String, dynamic> body) async {
    await _send('PATCH', '/api/admin/categories/$id', auth: true, body: body);
  }

  Future<void> adminDeleteCategory(int id) async {
    await _send('DELETE', '/api/admin/categories/$id', auth: true);
  }

  // ---------- admin: tax rates ----------

  Future<void> adminCreateTaxRate(Map<String, dynamic> body) async {
    await _send('POST', '/api/admin/tax-rates', auth: true, body: body);
  }

  /// Ends a rate on a date (YYYY-MM-DD), or makes it open-ended again with null.
  Future<void> adminEndTaxRate(int id, String? validTo) async {
    await _send(
      'PATCH',
      '/api/admin/tax-rates/$id',
      auth: true,
      body: {'valid_to': validTo},
    );
  }

  // ---------- admin: stock (used in part 4b) ----------

  Future<List<Map<String, dynamic>>> adminStockLocations() async {
    final res = await _send('GET', '/api/admin/stock-locations', auth: true);
    final list =
        (res['data'] as Map<String, dynamic>)['locations'] as List<dynamic>;
    return list.cast<Map<String, dynamic>>();
  }

  Future<void> adminCreateStockLocation(String code, String name) async {
    await _send(
      'POST',
      '/api/admin/stock-locations',
      auth: true,
      body: {'code': code, 'name': name},
    );
  }

  Future<Map<String, dynamic>> adminVariantStock(int variantId) async {
    final res = await _send(
      'GET',
      '/api/admin/variants/$variantId/stock',
      auth: true,
    );
    return res['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> adminStockMovements(
    int variantId, {
    int page = 1,
  }) async {
    final res = await _send(
      'GET',
      '/api/admin/variants/$variantId/stock-movements?page=$page',
      auth: true,
    );
    return res['data'] as Map<String, dynamic>;
  }

  /// [operation] is 'receive', 'adjust' or 'count'. The body must contain a request_key.
  Future<Map<String, dynamic>> adminStockOperation(
    int variantId,
    String operation,
    Map<String, dynamic> body,
  ) async {
    final res = await _send(
      'POST',
      '/api/admin/variants/$variantId/stock/$operation',
      auth: true,
      body: body,
    );
    return res['data'] as Map<String, dynamic>;
  }

  // ---------- admin: image upload (used in part 4b) ----------

  Future<Map<String, dynamic>> adminUploadImage({
    required List<int> bytes,
    required String filename,
    String? altText,
  }) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
      if (altText != null && altText.isNotEmpty) 'alt_text': altText,
    });
    final res = await _send('POST', '/api/admin/media', auth: true, body: form);
    return (res['data'] as Map<String, dynamic>)['media']
        as Map<String, dynamic>;
  }

  // ---------- shipping ----------

  /// The shipping quote for the cart. With no arguments the customer's default shipping address is used.
  Future<Map<String, dynamic>> shippingQuote({
    int? addressId,
    String? country,
  }) async {
    final q = <String, String>{
      if (addressId != null) 'address_id': '$addressId',
      if (country != null) 'country': country,
    };
    final path = q.isEmpty
        ? '/api/shipping/quote'
        : Uri(path: '/api/shipping/quote', queryParameters: q).toString();

    final res = await _send('GET', path, auth: true);
    return (res['data'] as Map<String, dynamic>)['quote']
        as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> adminShippingMethods() async {
    final res = await _send('GET', '/api/admin/shipping-methods', auth: true);
    final list =
        (res['data'] as Map<String, dynamic>)['methods'] as List<dynamic>;
    return list.cast<Map<String, dynamic>>();
  }

  Future<void> adminCreateShippingMethod(Map<String, dynamic> body) async {
    await _send('POST', '/api/admin/shipping-methods', auth: true, body: body);
  }

  Future<void> adminUpdateShippingMethod(
    int id,
    Map<String, dynamic> body,
  ) async {
    await _send(
      'PATCH',
      '/api/admin/shipping-methods/$id',
      auth: true,
      body: body,
    );
  }

  Future<void> adminCreateShippingRate(
    int methodId,
    Map<String, dynamic> body,
  ) async {
    await _send(
      'POST',
      '/api/admin/shipping-methods/$methodId/rates',
      auth: true,
      body: body,
    );
  }

  Future<void> adminUpdateShippingRate(
    int id,
    Map<String, dynamic> body,
  ) async {
    await _send(
      'PATCH',
      '/api/admin/shipping-rates/$id',
      auth: true,
      body: body,
    );
  }

  Future<void> adminDeleteShippingRate(int id) async {
    await _send('DELETE', '/api/admin/shipping-rates/$id', auth: true);
  }

  // ---------- checkout and orders ----------

  /// Places the order. Answers {order, replayed}. The same checkout_key never creates a second order.
  Future<Map<String, dynamic>> placeOrder(Map<String, dynamic> body) async {
    final res = await _send('POST', '/api/checkout', auth: true, body: body);
    return res['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> listOrders({int page = 1}) async {
    final res = await _send('GET', '/api/orders?page=$page', auth: true);
    return res['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getOrder(int id) async {
    final res = await _send('GET', '/api/orders/$id', auth: true);
    return (res['data'] as Map<String, dynamic>)['order']
        as Map<String, dynamic>;
  }

  // ---------- checkout preview, payment, receipts ----------

  /// What the order would cost, across all payment sources (membership credit, gift voucher, online).
  Future<Map<String, dynamic>> checkoutPreview({
    int? addressId,
    int? methodId,
    String? paymentSource,
    List<String>? voucherCodes,
  }) async {
    final q = <String, String>{
      if (addressId != null) 'shipping_address_id': '$addressId',
      if (methodId != null) 'shipping_method_id': '$methodId',
      if (paymentSource != null && paymentSource.isNotEmpty)
        'payment_source': paymentSource,
      if (voucherCodes != null && voucherCodes.isNotEmpty)
        'voucher_code': voucherCodes.first,
    };
    final path = q.isEmpty
        ? '/api/checkout/preview'
        : Uri(path: '/api/checkout/preview', queryParameters: q).toString();

    final res = await _send('GET', path, auth: true);
    return (res['data'] as Map<String, dynamic>)['preview']
        as Map<String, dynamic>;
  }

  /// Starts (or resumes) paying an order. Answers {payment, action}: the action says what the app must do next.
  Future<Map<String, dynamic>> payOrder(int orderId) async {
    final res = await _send('POST', '/api/orders/$orderId/pay', auth: true);
    return res['data'] as Map<String, dynamic>;
  }

  /// The development payment page's two buttons (the paths come from the payment's action). Answers the updated order.
  Future<Map<String, dynamic>> devPayment(String path) async {
    final res = await _send('POST', path, auth: true);
    return (res['data'] as Map<String, dynamic>)['order']
        as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> cancelOrder(int orderId) async {
    final res = await _send('POST', '/api/orders/$orderId/cancel', auth: true);
    return (res['data'] as Map<String, dynamic>)['order']
        as Map<String, dynamic>;
  }

  /// The receipt PDF. Answers (bytes, null) or (null, a message for the customer).
  Future<(List<int>?, String?)> downloadReceipt(
    int orderId, {
    bool admin = false,
  }) async {
    try {
      final token = await _storage.read(key: _tokenKey);

      // Capture the selected language when the download starts.
      final language = currentAppLocale;

      debugPrint('Receipt download language: $language');

      final res = await _dio.get<List<int>>(
        admin
            ? '/api/admin/orders/$orderId/receipt'
            : '/api/orders/$orderId/receipt',
        options: Options(
          responseType: ResponseType.bytes,
          headers: {
            'Accept-Language': language,
            if (token != null) 'Authorization': 'Bearer $token',
          },
          validateStatus: (_) => true,
        ),
      );

      final status = res.statusCode ?? 0;

      if (status == 200 && res.data != null) {
        return (res.data!, null);
      }

      return (
        null,
        status == 404
            ? 'This receipt does not exist.'
            : 'The receipt could not be created (error $status).',
      );
    } on DioException catch (e) {
      debugPrint('Receipt download error: ${e.message}');
      return (null, 'Cannot reach the server. Check your connection.');
    }
  }

  // ---------- vouchers and loyalty points ----------

  Future<Map<String, dynamic>> listVouchers({int page = 1}) async {
    final res = await _send('GET', '/api/vouchers?page=$page', auth: true);
    return res['data'] as Map<String, dynamic>;
  }

  /// One voucher with its transactions.
  Future<Map<String, dynamic>> getVoucher(int id) async {
    final res = await _send('GET', '/api/vouchers/$id', auth: true);
    return (res['data'] as Map<String, dynamic>)['voucher']
        as Map<String, dynamic>;
  }

  /// {balance, transactions, meta}
  Future<Map<String, dynamic>> loyalty({int page = 1}) async {
    final res = await _send('GET', '/api/loyalty?page=$page', auth: true);
    return res['data'] as Map<String, dynamic>;
  }

  // ---------- vouchers: spending, adding, staff ----------

  /// What each typed code is worth. Nothing is changed or claimed. The codes travel in the body, never in a URL.
  Future<List<Map<String, dynamic>>> checkVouchers(List<String> codes) async {
    final res = await _send(
      'POST',
      '/api/vouchers/check',
      auth: true,
      body: {'codes': codes},
    );
    return ((res['data'] as Map<String, dynamic>)['vouchers'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
  }

  /// Adds a voucher to the customer's account. Answers {claimed, voucher_id, balance_cents}.
  Future<Map<String, dynamic>> claimVoucher(String code) async {
    final res = await _send(
      'POST',
      '/api/vouchers/claim',
      auth: true,
      body: {'code': code},
    );
    return res['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> adminListVouchers({
    String state = '',
    String kind = '',
    String search = '',
    int page = 1,
  }) async {
    final path = Uri(
      path: '/api/admin/vouchers',
      queryParameters: {
        'page': '$page',
        if (state.isNotEmpty) 'state': state,
        if (kind.isNotEmpty) 'kind': kind,
        if (search.isNotEmpty) 'q': search,
      },
    ).toString();

    final res = await _send('GET', path, auth: true);
    return res['data'] as Map<String, dynamic>;
  }

  /// One voucher with its transactions.
  Future<Map<String, dynamic>> adminGetVoucher(int id) async {
    final res = await _send('GET', '/api/admin/vouchers/$id', auth: true);
    return (res['data'] as Map<String, dynamic>)['voucher']
        as Map<String, dynamic>;
  }

  /// Issues vouchers. The answer holds the plain codes: they exist nowhere else.
  Future<List<Map<String, dynamic>>> adminIssueVouchers(
    Map<String, dynamic> body,
  ) async {
    final res = await _send(
      'POST',
      '/api/admin/vouchers',
      auth: true,
      body: body,
    );
    return ((res['data'] as Map<String, dynamic>)['vouchers'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
  }

  Future<void> adminCancelVoucher(int id) async {
    await _send('POST', '/api/admin/vouchers/$id/cancel', auth: true, body: {});
  }

  /// Assigns an existing voucher to an existing customer by email.
  Future<Map<String, dynamic>> adminAssignVoucher(int id, String email) async {
    final res = await _send(
      'POST',
      '/api/admin/vouchers/$id/assign',
      auth: true,
      body: {'customer_email': email.trim()},
    );
    return (res['data'] as Map<String, dynamic>)['voucher']
        as Map<String, dynamic>;
  }

  /// [date] is YYYY-MM-DD (valid until the end of that day), or null for no expiry.
  Future<void> adminSetVoucherExpiry(int id, String? date) async {
    await _send(
      'PATCH',
      '/api/admin/vouchers/$id',
      auth: true,
      body: {'expires_at': date},
    );
  }

  // ---------- gift vouchers customers can buy ----------

  /// The voucher amounts on sale: [{variant_id, name, price_cents, currency}], cheapest first. Public.
  Future<List<Map<String, dynamic>>> giftVoucherAmounts() async {
    final res = await _send(
      'GET',
      '/api/gift-vouchers?lang=$currentAppLocale',
      auth: false,
    );

    return ((res['data'] as Map<String, dynamic>)['amounts'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
  }

  /// Puts vouchers into the cart. The caller refreshes the cart badge.
  Future<void> addGiftVouchersToCart(int variantId, int quantity) async {
    await _send(
      'POST',
      _cartPath('/api/cart/items'),
      auth: true,
      body: {'variant_id': variantId, 'quantity': quantity},
    );
  }

  /// Staff: the tax rates to choose from when creating a voucher amount.
  Future<List<Map<String, dynamic>>> voucherTaxRates() async {
    final res = await _send('GET', '/api/admin/tax-rates', auth: true);
    return ((res['data'] as Map<String, dynamic>)['tax_rates'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
  }

  /// Staff: creates a voucher product, one amount customers can buy.
  Future<void> createVoucherAmount({
    required int cents,
    required int taxRateId,
    required String nameDe,
    required String nameEn,
  }) async {
    await _send(
      'POST',
      '/api/admin/products',
      auth: true,
      body: {
        'slug': 'gift-voucher-$cents',
        'product_type': 'gift_voucher',
        'status': 'published',
        'tax_rate_id': taxRateId,
        'translations': {
          'de': {'name': nameDe},
          'en': {'name': nameEn},
        },
        'variants': [
          {'sku': 'GV-$cents', 'price_cents': cents},
        ],
      },
    );
  }

  /// Staff: every voucher amount, on sale or not: [{variant_id, price_cents, name, on_sale, sold}].
  Future<List<Map<String, dynamic>>> adminVoucherAmounts() async {
    final res = await _send(
      'GET',
      '/api/admin/gift-voucher-amounts',
      auth: true,
    );
    return ((res['data'] as Map<String, dynamic>)['amounts'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
  }

  Future<void> adminCreateVoucherAmount(int cents) async {
    await _send(
      'POST',
      '/api/admin/gift-voucher-amounts',
      auth: true,
      body: {'value_cents': cents},
    );
  }

  Future<void> adminSetVoucherAmountOnSale(int variantId, bool onSale) async {
    await _send(
      'PATCH',
      '/api/admin/gift-voucher-amounts/$variantId',
      auth: true,
      body: {'on_sale': onSale},
    );
  }

  // ---------- admin: orders ----------

  Future<Map<String, dynamic>> adminListOrders({
    String status = '',
    String paymentStatus = '',
    String search = '',
    int page = 1,
  }) async {
    final path = Uri(
      path: '/api/admin/orders',
      queryParameters: {
        'page': '$page',
        if (status.isNotEmpty) 'status': status,
        if (paymentStatus.isNotEmpty) 'payment_status': paymentStatus,
        if (search.isNotEmpty) 'q': search,
      },
    ).toString();

    final res = await _send('GET', path, auth: true);
    return res['data'] as Map<String, dynamic>;
  }

  /// {order, admin}: the order as the customer sees it, plus what only staff see.
  Future<Map<String, dynamic>> adminGetOrder(int id) async {
    final res = await _send('GET', '/api/admin/orders/$id', auth: true);
    return res['data'] as Map<String, dynamic>;
  }

  Future<void> adminAddOrderNote(int id, String note) async {
    await _send(
      'POST',
      '/api/admin/orders/$id/notes',
      auth: true,
      body: {'note': note},
    );
  }

  Future<void> adminSetOrderStatus(int id, String status, String? note) async {
    await _send(
      'POST',
      '/api/admin/orders/$id/status',
      auth: true,
      body: {'status': status, if (note != null) 'note': note},
    );
  }

  Future<void> adminMarkPaid(int id, {String? reference, String? note}) async {
    await _send(
      'POST',
      '/api/admin/orders/$id/mark-paid',
      auth: true,
      body: {
        if (reference != null) 'reference': reference,
        if (note != null) 'note': note,
      },
    );
  }

  Future<void> adminCancelOrder(int id, {String? reason}) async {
    await _send(
      'POST',
      '/api/admin/orders/$id/cancel',
      auth: true,
      body: {if (reason != null) 'reason': reason},
    );
  }

  /// Answers "refunded", "partially_refunded" or "already_applied".
  Future<String> adminRefund(int id, Map<String, dynamic> body) async {
    final res = await _send(
      'POST',
      '/api/admin/orders/$id/refund',
      auth: true,
      body: body,
    );
    return (res['data'] as Map<String, dynamic>)['result'] as String;
  }

  Future<void> adminAddParcel(
    int orderId,
    String carrier,
    String? tracking,
  ) async {
    await _send(
      'POST',
      '/api/admin/orders/$orderId/shipments',
      auth: true,
      body: {
        'carrier': carrier,
        if (tracking != null) 'tracking_number': tracking,
      },
    );
  }

  Future<void> adminUpdateParcel(int id, Map<String, dynamic> body) async {
    await _send('PATCH', '/api/admin/shipments/$id', auth: true, body: body);
  }

  /// The plain voucher codes of a paid order. Every call is written to the audit log by the server.
  Future<List<Map<String, dynamic>>> adminVoucherCodes(int id) async {
    final res = await _send(
      'GET',
      '/api/admin/orders/$id/voucher-codes',
      auth: true,
    );
    return ((res['data'] as Map<String, dynamic>)['codes'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
  }

  Future<void> adminResendVouchers(int id) async {
    await _send(
      'POST',
      '/api/admin/orders/$id/resend-vouchers',
      auth: true,
      body: {},
    );
  }
}
