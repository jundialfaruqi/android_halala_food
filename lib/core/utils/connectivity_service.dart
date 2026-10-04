import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

export 'package:connectivity_plus/connectivity_plus.dart';

extension ConnectivityResultListX on List<ConnectivityResult> {
  bool get hasActiveConnection => any((r) =>
      r == ConnectivityResult.mobile ||
      r == ConnectivityResult.wifi ||
      r == ConnectivityResult.ethernet ||
      r == ConnectivityResult.vpn);
}

final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityService();
});

final connectivityStatusProvider =
    StreamProvider<List<ConnectivityResult>>((ref) async* {
  final service = ref.watch(connectivityServiceProvider);
  final initial = await service.checkConnectivity();
  yield initial;
  yield* service.onConnectivityChanged;
});

class ConnectivityService {
  final Connectivity _connectivity;

  ConnectivityService({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  Future<List<ConnectivityResult>> checkConnectivity() {
    return _connectivity.checkConnectivity();
  }

  Future<bool> hasConnection() async {
    final results = await checkConnectivity();
    return hasActiveConnection(results);
  }

  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      _connectivity.onConnectivityChanged;

  bool hasActiveConnection(List<ConnectivityResult> results) {
    return results.any((result) =>
        result == ConnectivityResult.mobile ||
        result == ConnectivityResult.wifi ||
        result == ConnectivityResult.ethernet ||
        result == ConnectivityResult.vpn);
  }
}
