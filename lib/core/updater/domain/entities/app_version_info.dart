import 'package:flutter/foundation.dart';

/// Statut de disponibilité de la mise à jour
enum UpdateAvailability {
  upToDate,
  optionalUpdate,
  mandatoryUpdate,
}

/// Informations complètes sur une version d'application (Android APK ou PWA)
class AppVersionInfo {
  const AppVersionInfo({
    required this.installedVersionName,
    required this.installedVersionCode,
    required this.latestVersionName,
    required this.latestVersionCode,
    required this.minimumVersionName,
    required this.minimumVersionCode,
    required this.isUpdateAvailable,
    required this.isMandatory,
    required this.apkUrl,
    required this.sha256,
    required this.fileSize,
    required this.releaseDate,
    required this.releaseNotes,
    required this.isPwa,
  });

  final String installedVersionName;
  final int installedVersionCode;
  final String latestVersionName;
  final int latestVersionCode;
  final String minimumVersionName;
  final int minimumVersionCode;
  final bool isUpdateAvailable;
  final bool isMandatory;
  final String apkUrl;
  final String sha256;
  final int fileSize;
  final String releaseDate;
  final List<String> releaseNotes;
  final bool isPwa;

  UpdateAvailability get availability {
    if (!isUpdateAvailable) return UpdateAvailability.upToDate;
    if (isMandatory) return UpdateAvailability.mandatoryUpdate;
    return UpdateAvailability.optionalUpdate;
  }
}

/// Manifeste complet désérialisé depuis le fichier JSON centralisé Cloudflare
class AppVersionManifest {
  const AppVersionManifest({
    required this.manifestVersion,
    required this.updatedAt,
    required this.androidRaw,
    required this.pwaRaw,
  });

  final int manifestVersion;
  final String updatedAt;
  final Map<String, dynamic> androidRaw;
  final Map<String, dynamic> pwaRaw;

  factory AppVersionManifest.fromJson(Map<String, dynamic> json) {
    return AppVersionManifest(
      manifestVersion: (json['version'] as num?)?.toInt() ?? 1,
      updatedAt: json['updated_at'] as String? ?? '',
      androidRaw: (json['android'] as Map<String, dynamic>?) ?? {},
      pwaRaw: (json['pwa'] as Map<String, dynamic>?) ?? {},
    );
  }
}

