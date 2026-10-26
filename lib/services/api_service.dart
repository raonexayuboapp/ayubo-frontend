import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
final headers = <String, dynamic>{};
if (auth) {
final token = await _storage.read(key: _tokenKey);
if (token != null) headers['Authorization'] = 'Bearer $token';
}

final Response<dynamic> res;
try {
res = await _dio.request<dynamic>(
path,
data: body,
options: Options(method: method, headers: headers),
);
} on DioException catch (e) {
  throw ApiException(
    'Network error: ${e.type} - ${e.message}',
  );
}

final code = res.statusCode ?? 0;
final map = res.data is Map<String, dynamic>
? res.data as Map<String, dynamic>
    : <String, dynamic>{};

if (code >= 200 && code < 300) return map;

if (auth && code == 401) await _storage.delete(key: _tokenKey);

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
await _send('POST', '/api/auth/register', body: {
'first_name': firstName,
'last_name': lastName,
'mobile_number': mobileNumber,
'email': email,
'password': password,
'password_confirmation': passwordConfirmation,
});
}

Future<void> verifyEmail({required String email, required String code}) async {
await _send('POST', '/api/auth/verify-email',
body: {'email': email, 'code': code});
}

Future<void> resendVerification(String email) async {
await _send('POST', '/api/auth/resend-verification',
body: {'email': email});
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
await _send('POST', '/api/auth/reset-password', body: {
'email': email,
'code': code,
'password': password,
'password_confirmation': passwordConfirmation,
});
}

Future<void> changePassword({
required String currentPassword,
required String newPassword,
required String newPasswordConfirmation,
}) async {
await _send('POST', '/api/auth/change-password', auth: true, body: {
'current_password': currentPassword,
'new_password': newPassword,
'new_password_confirmation': newPasswordConfirmation,
});
}

Future<Map<String, dynamic>> updateProfile({
required String firstName,
required String lastName,
required String mobileNumber,
}) async {
final res = await _send('PATCH', '/api/profile', auth: true, body: {
'first_name': firstName,
'last_name': lastName,
'mobile_number': mobileNumber,
});
return (res['data'] as Map<String, dynamic>)['user'] as Map<String, dynamic>;
}

Future<void> deleteAccount(String password) async {
await _send('DELETE', '/api/profile',
auth: true, body: {'password': password});
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
final res = await _send('POST', '/api/auth/login',
body: {'email': email, 'password': password});
final data = res['data'] as Map<String, dynamic>;
await _storage.write(key: _tokenKey, value: data['token'] as String);
return data['user'] as Map<String, dynamic>;
}

Future<Map<String, dynamic>> me() async {
final res = await _send('GET', '/api/me', auth: true);
return (res['data'] as Map<String, dynamic>)['user'] as Map<String, dynamic>;
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
final path = Uri(path: '/api/admin/users', queryParameters: {
if (search.isNotEmpty) 'search': search,
'page': '$page',
}).toString();
final res = await _send('GET', path, auth: true);
return res['data'] as Map<String, dynamic>;
}

Future<Map<String, dynamic>> adminUpdateUser(
int id,
Map<String, dynamic> body,
) async {
final res =
await _send('PATCH', '/api/admin/users/$id', auth: true, body: body);
return (res['data'] as Map<String, dynamic>)['user'] as Map<String, dynamic>;
}

Future<List<Map<String, dynamic>>> adminListPlans() async {
final res = await _send('GET', '/api/admin/membership-plans', auth: true);
final list =
(res['data'] as Map<String, dynamic>)['plans'] as List<dynamic>;
return list.cast<Map<String, dynamic>>();
}

Future<void> adminCreatePlan(Map<String, dynamic> body) async {
await _send('POST', '/api/admin/membership-plans',
auth: true, body: body);
}

Future<void> adminUpdatePlan(int id, Map<String, dynamic> body) async {
await _send('PATCH', '/api/admin/membership-plans/$id',
auth: true, body: body);
}

  // ---------- cart ----------

  Future<Map<String, dynamic>> getCart() async {
    return _cart(await _send('GET', '/api/cart', auth: true));
  }

  Future<Map<String, dynamic>> addToCart(int variantId, int quantity) async {
    return _cart(await _send('POST', '/api/cart/items',
        auth: true, body: {'variant_id': variantId, 'quantity': quantity}));
  }

  Future<Map<String, dynamic>> setCartQuantity(int itemId, int quantity) async {
    return _cart(await _send('PATCH', '/api/cart/items/$itemId', auth: true, body: {'quantity': quantity}));
  }

  Future<Map<String, dynamic>> removeCartItem(int itemId) async {
    return _cart(await _send('DELETE', '/api/cart/items/$itemId', auth: true));
  }

  /// Every cart answer is the WHOLE cart. The badge is updated here, so no screen can forget to.
  Map<String, dynamic> _cart(Map<String, dynamic> res) {
    final cart = (res['data'] as Map<String, dynamic>)['cart'] as Map<String, dynamic>;
    CartState.instance.update(cart);
    return cart;
  }

  // ---------- memberships ----------

  /// {plans: [...], membership: {...} or null}
  Future<Map<String, dynamic>> membershipPlans() async {
    final res = await _send('GET', '/api/membership-plans', auth: true);
    return res['data'] as Map<String, dynamic>;
  }

  // ---------- admin: membership plans ----------

  Future<List<Map<String, dynamic>>> adminMembershipPlans() async {
    final res = await _send('GET', '/api/admin/membership-plans', auth: true);
    final list = (res['data'] as Map<String, dynamic>)['plans'] as List<dynamic>;
    return list.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> adminMembershipPlan(int id) async {
    final res = await _send('GET', '/api/admin/membership-plans/$id', auth: true);
    return (res['data'] as Map<String, dynamic>)['plan'] as Map<String, dynamic>;
  }

  Future<void> adminCreateMembershipPlan(Map<String, dynamic> body) async {
    await _send('POST', '/api/admin/membership-plans', auth: true, body: body);
  }

  Future<void> adminUpdateMembershipPlan(int id, Map<String, dynamic> body) async {
    await _send('PATCH', '/api/admin/membership-plans/$id', auth: true, body: body);
  }
// ---------- products (customer) ----------

Future<Map<String, dynamic>> listProducts({
String search = '',
int? categoryId,
String sort = 'newest',
int page = 1,
}) async {
final path = Uri(path: '/api/products', queryParameters: {
'page': '$page',
'sort': sort,
if (search.isNotEmpty) 'search': search,
if (categoryId != null) 'category_id': '$categoryId',
}).toString();
final res = await _send('GET', path, auth: true);
return res['data'] as Map<String, dynamic>;
}

Future<Map<String, dynamic>> getProduct(int id) async {
final res = await _send('GET', '/api/products/$id', auth: true);
return (res['data'] as Map<String, dynamic>)['product'] as Map<String, dynamic>;
}

Future<List<Map<String, dynamic>>> listCategories() async {
final res = await _send('GET', '/api/categories', auth: true);
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
final path = Uri(path: '/api/admin/products', queryParameters: {
'page': '$page',
if (search.isNotEmpty) 'search': search,
if (status.isNotEmpty) 'status': status,
}).toString();
final res = await _send('GET', path, auth: true);
return res['data'] as Map<String, dynamic>;
}

Future<Map<String, dynamic>> adminGetProduct(int id) async {
final res = await _send('GET', '/api/admin/products/$id', auth: true);
return (res['data'] as Map<String, dynamic>)['product'] as Map<String, dynamic>;
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
await _send('PATCH', '/api/admin/categories/$id',
auth: true, body: body);
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
await _send('PATCH', '/api/admin/tax-rates/$id',
auth: true, body: {'valid_to': validTo});
}

// ---------- admin: stock (used in part 4b) ----------

Future<List<Map<String, dynamic>>> adminStockLocations() async {
final res = await _send('GET', '/api/admin/stock-locations', auth: true);
final list =
(res['data'] as Map<String, dynamic>)['locations'] as List<dynamic>;
return list.cast<Map<String, dynamic>>();
}

Future<void> adminCreateStockLocation(String code, String name) async {
await _send('POST', '/api/admin/stock-locations',
auth: true, body: {'code': code, 'name': name});
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
final res = await _send(
'POST',
'/api/admin/media',
auth: true,
body: form,
);
return (res['data'] as Map<String, dynamic>)['media'] as Map<String, dynamic>;
}

  // ---------- shipping ----------

  /// The shipping quote for the cart. With no arguments the customer's default shipping address is used.
  Future<Map<String, dynamic>> shippingQuote({int? addressId, String? country}) async {
    final q = <String, String>{
      if (addressId != null) 'address_id': '$addressId',
      if (country != null) 'country': country,
    };
    final path = q.isEmpty
        ? '/api/shipping/quote'
        : Uri(path: '/api/shipping/quote', queryParameters: q).toString();

    final res = await _send('GET', path, auth: true);
    return (res['data'] as Map<String, dynamic>)['quote'] as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> adminShippingMethods() async {
    final res = await _send('GET', '/api/admin/shipping-methods', auth: true);
    final list = (res['data'] as Map<String, dynamic>)['methods'] as List<dynamic>;
    return list.cast<Map<String, dynamic>>();
  }

  Future<void> adminCreateShippingMethod(Map<String, dynamic> body) async {
    await _send('POST', '/api/admin/shipping-methods', auth: true, body: body);
  }

  Future<void> adminUpdateShippingMethod(int id, Map<String, dynamic> body) async {
    await _send('PATCH', '/api/admin/shipping-methods/$id', auth: true, body: body);
  }

  Future<void> adminCreateShippingRate(int methodId, Map<String, dynamic> body) async {
    await _send('POST', '/api/admin/shipping-methods/$methodId/rates', auth: true, body: body);
  }

  Future<void> adminUpdateShippingRate(int id, Map<String, dynamic> body) async {
    await _send('PATCH', '/api/admin/shipping-rates/$id', auth: true, body: body);
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
    return (res['data'] as Map<String, dynamic>)['order'] as Map<String, dynamic>;
  }
}