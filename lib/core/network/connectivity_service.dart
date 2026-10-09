import 'package:connectivity_plus/connectivity_plus.dart';

/// Disponibilité réseau. Indique la présence d'une interface, pas la
/// joignabilité du serveur : les échecs réels sont gérés par la sync (réessais).
abstract interface class ConnectivityService {
  Stream<bool> get onlineChanges;
  Future<bool> isOnline();
}

class ConnectivityPlusService implements ConnectivityService {
  ConnectivityPlusService([Connectivity? connectivity]) : _connectivity = connectivity ?? Connectivity();
  final Connectivity _connectivity;

  @override
  Stream<bool> get onlineChanges => _connectivity.onConnectivityChanged.map(_hasNetwork).distinct();

  @override
  Future<bool> isOnline() async => _hasNetwork(await _connectivity.checkConnectivity());

  static bool _hasNetwork(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);
}
