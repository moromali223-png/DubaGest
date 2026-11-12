import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../../../utils/app_logger.dart';
import '../../domain/entities/app_version_info.dart';

class UpdateRemoteDataSource {
  const UpdateRemoteDataSource({http.Client? httpClient}) : _client = httpClient;

  final http.Client? _client;
  static const MethodChannel _nativeChannel = MethodChannel('com.example.dubagest/updater');

  static const String _primaryManifestUrl = 'https://dubagest.com/version.json';
  static const String _mirrorManifestUrl = 'https://app.dubagest.com/version.json';

  /// Récupère la version installée sur l'appareil (via canal natif sous Android)
  Future<({String versionName, int versionCode})> getInstalledVersion() async {
    if (kIsWeb) {
      return (versionName: '1.0.0', versionCode: 1);
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        final res = await _nativeChannel.invokeMapMethod<String, dynamic>('getAppVersion');
        if (res != null) {
          final name = res['versionName'] as String? ?? '1.0.0';
          final code = (res['versionCode'] as num?)?.toInt() ?? 1;
          return (versionName: name, versionCode: code);
        }
      } catch (e) {
        AppLogger.warning('Erreur récupération version Android native: $e', tag: 'updater');
      }
    }
    return (versionName: '1.0.0', versionCode: 1);
  }

  /// Télécharge et analyse le manifeste de version centralisé hébergé sur Cloudflare
  Future<AppVersionManifest?> fetchManifest() async {
    final client = _client ?? http.Client();
    final urls = [_primaryManifestUrl, _mirrorManifestUrl];

    for (final url in urls) {
      try {
        final uri = Uri.parse(url);
        final response = await client.get(
          uri,
          headers: {
            'Cache-Control': 'no-cache',
            'Pragma': 'no-cache',
          },
        ).timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic>) {
            return AppVersionManifest.fromJson(decoded);
          }
        }
      } catch (e) {
        AppLogger.warning('Échec récupération manifeste depuis $url: $e', tag: 'updater');
      }
    }
    return null;
  }

  /// Évalue les informations de version et détermine si une mise à jour est disponible
  Future<AppVersionInfo?> checkUpdate() async {
    try {
      final installed = await getInstalledVersion();
      final manifest = await fetchManifest();
      if (manifest == null) return null;

      final isWeb = kIsWeb;
      final config = isWeb ? manifest.pwaRaw : manifest.androidRaw;
      if (config.isEmpty) return null;

      final latestVersion = config['latest_version'] as String? ?? installed.versionName;
      final latestCode = (config['version_code'] as num?)?.toInt() ?? installed.versionCode;

      final minVersion = config['minimum_supported_version'] as String? ?? installed.versionName;
      final minCode = (config['minimum_supported_code'] as num?)?.toInt() ?? 1;

      final forceUpdate = config['force_update'] as bool? ?? false;
      final apkUrl = config['apk_url'] as String? ?? '';
      final sha256 = config['sha256'] as String? ?? '';
      final fileSize = (config['file_size'] as num?)?.toInt() ?? 0;
      final releaseDate = config['release_date'] as String? ?? '';
      final notes = (config['release_notes'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          <String>[];

      final bool isUpdateAvailable;
      if (isWeb) {
        isUpdateAvailable = _compareSemver(latestVersion, installed.versionName) > 0;
      } else {
        isUpdateAvailable = latestCode > installed.versionCode ||
            _compareSemver(latestVersion, installed.versionName) > 0;
      }

      final bool isMandatory = forceUpdate ||
          (isWeb
              ? _compareSemver(minVersion, installed.versionName) > 0
              : installed.versionCode < minCode);

      return AppVersionInfo(
        installedVersionName: installed.versionName,
        installedVersionCode: installed.versionCode,
        latestVersionName: latestVersion,
        latestVersionCode: latestCode,
        minimumVersionName: minVersion,
        minimumVersionCode: minCode,
        isUpdateAvailable: isUpdateAvailable,
        isMandatory: isMandatory,
        apkUrl: apkUrl,
        sha256: sha256,
        fileSize: fileSize,
        releaseDate: releaseDate,
        releaseNotes: notes,
        isPwa: isWeb,
      );
    } catch (e, stack) {
      AppLogger.warning('Erreur analyse mise à jour: $e', tag: 'updater');
      AppLogger.debug(stack.toString(), tag: 'updater');
      return null;
    }
  }

  /// Comparaison sémantique propre de versions (ex: "1.0.1" vs "1.0.0")
  int _compareSemver(String a, String b) {
    final partsA = a.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final partsB = b.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final maxLen = partsA.length > partsB.length ? partsA.length : partsB.length;

    for (int i = 0; i < maxLen; i++) {
      final valA = i < partsA.length ? partsA[i] : 0;
      final valB = i < partsB.length ? partsB[i] : 0;
      if (valA != valB) return valA.compareTo(valB);
    }
    return 0;
  }
}

