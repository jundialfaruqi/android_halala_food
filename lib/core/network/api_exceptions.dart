import 'dart:convert';
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
        dynamic responseData = dioException.response?.data;
        String message = statusCode == 401
            ? 'Email atau password yang Anda masukkan salah.'
            : 'Terjadi kesalahan pada server ($statusCode).';

        if (responseData is String) {
          try {
            responseData = jsonDecode(responseData);
          } catch (_) {}
        }

        if (responseData is Map) {
          if (responseData['message'] != null &&
              responseData['message'].toString().trim().isNotEmpty) {
            message = responseData['message'].toString();
          } else if (responseData['error'] != null &&
              responseData['error'].toString().trim().isNotEmpty) {
            message = responseData['error'].toString();
          } else if (responseData['errors'] is Map &&
              (responseData['errors'] as Map).isNotEmpty) {
            final errorsMap = responseData['errors'] as Map;
            final firstVal = errorsMap.values.first;
            if (firstVal is List && firstVal.isNotEmpty) {
              message = firstVal.first.toString();
            } else if (firstVal != null) {
              message = firstVal.toString();
            }
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
