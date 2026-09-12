import 'package:connectivity_plus/connectivity_plus.dart';

/// Thin wrapper so the rest of the app depends on a simple bool stream,
/// not on connectivity_plus's richer (and more verbose) API.
class ConnectivityService {
  final Connectivity _connectivity = Connectivity();

  Stream<bool> get onStatusChange => _connectivity.onConnectivityChanged.map(
    (results) => !results.contains(ConnectivityResult.none),
  );

  Future<bool> isOnline() async {
    final result = await _connectivity.checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }
}
