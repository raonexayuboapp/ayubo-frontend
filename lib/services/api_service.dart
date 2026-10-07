import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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
        Map<String, dynamic>? body,
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
    } on DioException {
      throw ApiException('Cannot reach the server. Check your connection.');
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
    await _send('POST', '/api/auth/resend-verification', body: {'email': email});
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
    await _send('DELETE', '/api/profile', auth: true, body: {'password': password});
    await _storage.delete(key: _tokenKey);
  }

  Future<List<Map<String, dynamic>>> listAddresses() async {
    final res = await _send('GET', '/api/addresses', auth: true);
    final list = (res['data'] as Map<String, dynamic>)['addresses'] as List<dynamic>;
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
    }
  }

  Future<bool> hasToken() async => (await _storage.read(key: _tokenKey)) != null;
}