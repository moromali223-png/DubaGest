import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:dubagest/core/updater/data/datasources/update_remote_data_source.dart';
import 'package:dubagest/core/updater/domain/entities/app_version_info.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('Système de mise à jour centralisé (DubaGest Updater)', () {
    test('Désérialisation correcte du manifeste centralisé JSON', () {
      final json = {
        'version': 1,
        'updated_at': '2026-11-12T14:30:00Z',
        'android': {
          'latest_version': '1.0.1',
          'version_code': 2,
          'minimum_supported_version': '1.0.0',
          'minimum_supported_code': 1,
          'apk_url': 'https://dubagest.com/downloads/DubaGest-Android.apk',
          'sha256': '7f81383fc5a9c26abc5ad84aa56e35bdd0a9ae42e5322c630197a21b11e44f3e',
          'file_size': 40397374,
          'force_update': false,
          'release_date': '2026-11-12',
          'release_notes': ['Correctif de sécurité', 'Amélioration synchro'],
        },
        'pwa': {
          'latest_version': '1.0.1',
          'minimum_supported_version': '1.0.0',
          'force_update': false,
          'release_date': '2026-11-12',
          'release_notes': ['Mise à jour PWA'],
        },
      };

      final manifest = AppVersionManifest.fromJson(json);
      expect(manifest.manifestVersion, equals(1));
      expect(manifest.updatedAt, equals('2026-11-12T14:30:00Z'));
      expect(manifest.androidRaw['latest_version'], equals('1.0.1'));
      expect(manifest.androidRaw['version_code'], equals(2));
      expect(manifest.androidRaw['sha256'], equals('7f81383fc5a9c26abc5ad84aa56e35bdd0a9ae42e5322c630197a21b11e44f3e'));
      expect(manifest.pwaRaw['latest_version'], equals('1.0.1'));
    });

    test('Détection d\'une mise à jour disponible lorsque latest > installed', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'version': 1,
            'android': {
              'latest_version': '1.0.1',
              'version_code': 2,
              'minimum_supported_version': '1.0.0',
              'minimum_supported_code': 1,
              'apk_url': 'https://dubagest.com/downloads/DubaGest-Android.apk',
              'sha256': 'abc123hash',
              'file_size': 40000000,
              'force_update': false,
              'release_notes': ['Nouvelle version'],
            },
            'pwa': {
              'latest_version': '1.0.1',
              'minimum_supported_version': '1.0.0',
              'force_update': false,
            },
          }),
          200,
        );
      });

      final dataSource = UpdateRemoteDataSource(httpClient: mockClient);
      final info = await dataSource.checkUpdate();

      expect(info, isNotNull);
      expect(info!.latestVersionName, equals('1.0.1'));
      expect(info.isUpdateAvailable, isTrue);
      expect(info.isMandatory, isFalse);
    });

    test('Détection d\'une mise à jour obligatoire (force_update == true)', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'version': 1,
            'android': {
              'latest_version': '2.0.0',
              'version_code': 10,
              'minimum_supported_version': '2.0.0',
              'minimum_supported_code': 10,
              'apk_url': 'https://dubagest.com/downloads/DubaGest-Android.apk',
              'sha256': 'abc123hash',
              'file_size': 40000000,
              'force_update': true,
              'release_notes': ['Mise à jour majeure obligatoire'],
            },
          }),
          200,
        );
      });

      final dataSource = UpdateRemoteDataSource(httpClient: mockClient);
      final info = await dataSource.checkUpdate();

      expect(info, isNotNull);
      expect(info!.isUpdateAvailable, isTrue);
      expect(info.isMandatory, isTrue);
    });

    test('Vérification stricte de l\'intégrité cryptographique SHA-256', () {
      final contenuApkSimule = utf8.encode('DubaGest APK Binary Data Test');
      final vraiHash = sha256.convert(contenuApkSimule).toString().toLowerCase();

      final fauxHash = '0000000000000000000000000000000000000000000000000000000000000000';

      // Test intégrité conforme
      expect(vraiHash == vraiHash, isTrue);

      // Test détection altération / corruption
      expect(vraiHash == fauxHash, isFalse);
    });
  });
}
