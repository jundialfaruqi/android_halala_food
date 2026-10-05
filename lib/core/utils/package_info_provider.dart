import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Provider untuk mengambil metadata package aplikasi (versi, build number, dll.) secara dinamis dari pubspec.yaml / platform.
final packageInfoProvider = FutureProvider<PackageInfo>((ref) async {
  return await PackageInfo.fromPlatform();
});
