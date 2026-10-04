import 'dart:async';
import 'package:dio/dio.dart';
import '../../constants/api_endpoints.dart';
import '../../storage/secure_storage_service.dart';

class AuthInterceptor extends QueuedInterceptor {
  final SecureStorageService _storage;
  final Dio _dio;
  bool _isRefreshing = false;
  Completer<String?>? _refreshCompleter;

  AuthInterceptor({
    required SecureStorageService storage,
    required Dio dio,
  })  : _storage = storage,
        _dio = dio;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Jangan kirim token ke endpoint login/register/refresh
    final isAuthPublicPath = options.path.contains(ApiEndpoints.login) ||
        options.path.contains(ApiEndpoints.register) ||
        options.path.contains(ApiEndpoints.refreshToken);

    if (!isAuthPublicPath) {
      final token = await _storage.getAccessToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }

    options.headers['Accept'] = 'application/json';
    return handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final response = err.response;
    final is401 = response?.statusCode == 401;
    final isAuthPublicPath = err.requestOptions.path.contains(ApiEndpoints.login) ||
        err.requestOptions.path.contains(ApiEndpoints.refreshToken);

    if (is401 && !isAuthPublicPath) {
      try {
        final newAccessToken = await _handleRefreshToken();

        if (newAccessToken != null && newAccessToken.isNotEmpty) {
          // Retry original request dengan token baru
          final options = err.requestOptions;
          options.headers['Authorization'] = 'Bearer $newAccessToken';

          final retryResponse = await _dio.fetch(options);
          return handler.resolve(retryResponse);
        } else {
          await _storage.clearSession();
          return handler.next(err);
        }
      } catch (e) {
        await _storage.clearSession();
        return handler.next(err);
      }
    }

    return handler.next(err);
  }

  Future<String?> _handleRefreshToken() async {
    if (_isRefreshing) {
      // Tunggu proses refresh yang sedang berjalan
      return await _refreshCompleter?.future;
    }

    _isRefreshing = true;
    _refreshCompleter = Completer<String?>();

    try {
      final refreshToken = await _storage.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        _refreshCompleter?.complete(null);
        return null;
      }

      // Gunakan Dio instance terpisah tanpa auth interceptor untuk refresh token
      final refreshDio = Dio(
        BaseOptions(
          baseUrl: _dio.options.baseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
        ),
      );

      final response = await refreshDio.post(
        ApiEndpoints.refreshToken,
        data: {'refresh_token': refreshToken},
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        // Asumsi respons token bisa di response.data['data'] atau langsung response.data
        final tokenData = data is Map<String, dynamic> && data.containsKey('data')
            ? data['data']
            : data;

        final newAccessToken = tokenData['access_token']?.toString() ??
            tokenData['token']?.toString();
        final newRefreshToken = tokenData['refresh_token']?.toString();

        if (newAccessToken != null) {
          await _storage.saveAccessToken(newAccessToken);
          if (newRefreshToken != null) {
            await _storage.saveRefreshToken(newRefreshToken);
          }

          _refreshCompleter?.complete(newAccessToken);
          return newAccessToken;
        }
      }

      _refreshCompleter?.complete(null);
      return null;
    } catch (e) {
      _refreshCompleter?.complete(null);
      return null;
    } finally {
      _isRefreshing = false;
      _refreshCompleter = null;
    }
  }
}
