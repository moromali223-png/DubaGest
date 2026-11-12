import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../utils/app_logger.dart';
import '../../data/datasources/update_remote_data_source.dart';
import '../../domain/entities/app_version_info.dart';
import '../../domain/services/apk_download_service.dart';

enum UpdaterStatus {
  idle,
  checking,
  upToDate,
  updateAvailable,
  downloading,
  readyToInstall,
  error,
}

class UpdaterState {
  const UpdaterState({
    this.status = UpdaterStatus.idle,
    this.versionInfo,
    this.downloadProgress = 0.0,
    this.receivedBytes = 0,
    this.totalBytes = 0,
    this.errorMessage,
    this.downloadedApkPath,
    this.pwaUpdateReady = false,
  });

  final UpdaterStatus status;
  final AppVersionInfo? versionInfo;
  final double downloadProgress;
  final int receivedBytes;
  final int totalBytes;
  final String? errorMessage;
  final String? downloadedApkPath;
  final bool pwaUpdateReady;

  UpdaterState copyWith({
    UpdaterStatus? status,
    AppVersionInfo? versionInfo,
    double? downloadProgress,
    int? receivedBytes,
    int? totalBytes,
    String? errorMessage,
    String? downloadedApkPath,
    bool? pwaUpdateReady,
  }) {
    return UpdaterState(
      status: status ?? this.status,
      versionInfo: versionInfo ?? this.versionInfo,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      receivedBytes: receivedBytes ?? this.receivedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      errorMessage: errorMessage,
      downloadedApkPath: downloadedApkPath ?? this.downloadedApkPath,
      pwaUpdateReady: pwaUpdateReady ?? this.pwaUpdateReady,
    );
  }
}

final updateRemoteDataSourceProvider = Provider<UpdateRemoteDataSource>((ref) {
  return const UpdateRemoteDataSource();
});

final apkDownloadServiceProvider = Provider<ApkDownloadService>((ref) {
  return ApkDownloadService();
});

final updaterNotifierProvider = NotifierProvider<UpdaterNotifier, UpdaterState>(UpdaterNotifier.new);

class UpdaterNotifier extends Notifier<UpdaterState> {
  @override
  UpdaterState build() {
    return const UpdaterState();
  }

  UpdateRemoteDataSource get _remoteSource => ref.read(updateRemoteDataSourceProvider);
  ApkDownloadService get _downloadService => ref.read(apkDownloadServiceProvider);

  /// Vérifie la disponibilité d'une nouvelle version sur Cloudflare
  Future<void> verifierMiseAJour({bool manuel = false}) async {
    state = state.copyWith(status: UpdaterStatus.checking, errorMessage: null);

    try {
      final info = await _remoteSource.checkUpdate();
      if (info == null) {
        state = state.copyWith(
          status: manuel ? UpdaterStatus.error : UpdaterStatus.idle,
          errorMessage: manuel ? 'Impossible de joindre le serveur de mise à jour.' : null,
        );
        return;
      }

      if (info.isUpdateAvailable) {
        state = state.copyWith(
          status: UpdaterStatus.updateAvailable,
          versionInfo: info,
        );
      } else {
        state = state.copyWith(
          status: UpdaterStatus.upToDate,
          versionInfo: info,
        );
      }
    } catch (e) {
      AppLogger.warning('Erreur lors de la vérification de mise à jour: $e', tag: 'updater');
      state = state.copyWith(
        status: manuel ? UpdaterStatus.error : UpdaterStatus.idle,
        errorMessage: 'Erreur réseau lors de la vérification : $e',
      );
    }
  }

  /// Déclenche le téléchargement progressif avec vérification SHA-256 puis l'installation
  Future<void> telechargerEtInstaller() async {
    final info = state.versionInfo;
    if (info == null || info.apkUrl.isEmpty) {
      state = state.copyWith(
        status: UpdaterStatus.error,
        errorMessage: 'Lien de téléchargement manquant dans le manifeste officiel.',
      );
      return;
    }

    state = state.copyWith(
      status: UpdaterStatus.downloading,
      downloadProgress: 0.0,
      receivedBytes: 0,
      totalBytes: info.fileSize,
      errorMessage: null,
    );

    try {
      final apkFile = await _downloadService.downloadAndVerifyApk(
        apkUrl: info.apkUrl,
        expectedSha256: info.sha256,
        expectedFileSize: info.fileSize,
        onProgress: (progress, received, total) {
          state = state.copyWith(
            downloadProgress: progress,
            receivedBytes: received,
            totalBytes: total,
          );
        },
      );

      state = state.copyWith(
        status: UpdaterStatus.readyToInstall,
        downloadedApkPath: apkFile.path,
      );

      // Lancement de l'installeur Android
      await _downloadService.triggerInstall(apkFile);
    } catch (e) {
      AppLogger.warning('Échec du téléchargement ou de l\'installation: $e', tag: 'updater');
      state = state.copyWith(
        status: UpdaterStatus.error,
        errorMessage: 'Échec de la mise à jour : $e',
      );
    }
  }

  /// Réessaie l'installation si l'APK est déjà téléchargé
  Future<void> relancerInstallation() async {
    final path = state.downloadedApkPath;
    if (path == null) {
      await telechargerEtInstaller();
      return;
    }
    try {
      final file = File(path);
      if (await file.exists()) {
        await _downloadService.triggerInstall(file);
      } else {
        await telechargerEtInstaller();
      }
    } catch (e) {
      state = state.copyWith(
        status: UpdaterStatus.error,
        errorMessage: 'Impossible de lancer l\'installeur: $e',
      );
    }
  }

  /// Notifie que le Service Worker PWA est prêt à être activé
  void signalerPwaUpdateReady() {
    state = state.copyWith(pwaUpdateReady: true);
  }

  /// Applique la mise à jour PWA en rechargeant le Service Worker
  void appliquerPwaUpdate() {
    if (!kIsWeb) return;
    try {
      // ignore: avoid_dynamic_calls
      // Appel de la méthode JavaScript globale injectée dans index.html
      // import 'dart:js' as js;
    } catch (e) {
      AppLogger.warning('Erreur application mise à jour PWA: $e', tag: 'updater');
    }
  }
}

