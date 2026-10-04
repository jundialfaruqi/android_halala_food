import 'dart:convert';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// Hasil kompresi foto toko yang 100% konsisten dengan standar web Halala Food
class CompressedPhotoResult {
  final String dataUrl;
  final int originalSizeBytes;
  final int compressedSizeBytes;
  final String format; // 'jpeg' atau 'webp'
  final Uint8List bytes;

  CompressedPhotoResult({
    required this.dataUrl,
    required this.originalSizeBytes,
    required this.compressedSizeBytes,
    required this.format,
    required this.bytes,
  });

  String get originalSizeFormatted {
    if (originalSizeBytes < 1024) return '$originalSizeBytes B';
    if (originalSizeBytes < 1024 * 1024) {
      return '${(originalSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(originalSizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  String get compressedSizeFormatted {
    if (compressedSizeBytes < 1024) return '$compressedSizeBytes B';
    return '${(compressedSizeBytes / 1024).toStringAsFixed(1)} KB';
  }
}

/// Helper kompresi dan validasi foto toko Halala Food
/// Mengikuti standar sistem web Halala Food:
/// - Format: JPG, JPEG, PNG, WEBP
/// - Max input file: 10MB
/// - Target resolusi: Max 1200px
/// - Target kompresi: Kualitas optimal ~50-80KB
/// - Output: Base64 DataURL (data:image/jpeg;base64,...)
class StorePhotoCompressor {
  static const int maxInputBytes = 10 * 1024 * 1024; // 10MB
  static const int maxDimension = 1200; // 1200px max width/height

  /// Validasi dan kompresi file foto toko
  static Future<CompressedPhotoResult> processAndCompress(
    Uint8List rawBytes, {
    String? originalFilename,
  }) async {
    // 1. Validasi ukuran file awal (Max 10MB seperti di web)
    if (rawBytes.length > maxInputBytes) {
      final mb = (rawBytes.length / (1024 * 1024)).toStringAsFixed(2);
      throw Exception('Ukuran file terlalu besar ($mb MB). Maksimal 10MB.');
    }

    // 2. Decode gambar
    final image = img.decodeImage(rawBytes);
    if (image == null) {
      throw Exception('Format gambar rusak atau tidak didukung (harus JPG/PNG/WEBP).');
    }

    // 3. Resize jika dimensi melebihi 1200px (menjaga aspect ratio)
    img.Image resizedImage = image;
    if (image.width > maxDimension || image.height > maxDimension) {
      if (image.width >= image.height) {
        resizedImage = img.copyResize(
          image,
          width: maxDimension,
          interpolation: img.Interpolation.linear,
        );
      } else {
        resizedImage = img.copyResize(
          image,
          height: maxDimension,
          interpolation: img.Interpolation.linear,
        );
      }
    }

    // 4. Kompresi iterative hingga mencapai target optimal (target <= 100KB)
    int quality = 82;
    List<int> compressedBytes = img.encodeJpg(resizedImage, quality: quality);

    while (compressedBytes.length > 80 * 1024 && quality > 40) {
      quality -= 12;
      compressedBytes = img.encodeJpg(resizedImage, quality: quality);
    }

    final uint8Compressed = Uint8List.fromList(compressedBytes);
    final base64String = base64Encode(uint8Compressed);
    final dataUrl = 'data:image/jpeg;base64,$base64String';

    return CompressedPhotoResult(
      dataUrl: dataUrl,
      originalSizeBytes: rawBytes.length,
      compressedSizeBytes: uint8Compressed.length,
      format: 'JPEG',
      bytes: uint8Compressed,
    );
  }
}
