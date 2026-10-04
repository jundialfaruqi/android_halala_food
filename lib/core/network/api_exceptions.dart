import 'package:dio/dio.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic errors;

  ApiException({
    required this.message,
    this.statusCode,
    this.errors,
  });

  factory ApiException.fromDioError(DioException dioException) {
    switch (dioException.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException(
          message: 'Koneksi ke server timeout. Silakan periksa jaringan internet Anda.',
          statusCode: 408,
        );
      case DioExceptionType.badResponse:
        final statusCode = dioException.response?.statusCode;
        final responseData = dioException.response?.data;
        String message = 'Terjadi kesalahan pada server ($statusCode).';

        if (responseData is Map<String, dynamic>) {
          if (responseData['message'] != null) {
            message = responseData['message'].toString();
          } else if (responseData['error'] != null) {
            message = responseData['error'].toString();
          }
          return ApiException(
            message: message,
            statusCode: statusCode,
            errors: responseData['errors'],
          );
        }

        return ApiException(
          message: message,
          statusCode: statusCode,
        );
      case DioExceptionType.cancel:
        return ApiException(message: 'Permintaan dibatalkan.');
      case DioExceptionType.connectionError:
        return ApiException(
          message: 'Tidak dapat terhubung ke server. Pastikan koneksi internet aktif.',
        );
      default:
        return ApiException(
          message: dioException.message ?? 'Terjadi kesalahan tidak terduga.',
        );
    }
  }

  @override
  String toString() => message;
}
