import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/database/json_cache_store.dart';
import '../../../core/errors/error_mapper.dart';
import '../../../core/errors/failure.dart';

/// Logo de l'entreprise : stocké dans le bucket privé « fichiers »
/// (`<entreprise>/logo/…`), copie gardée sur l'appareil pour les documents
/// émis hors-ligne.
class LogoEntreprise {
  LogoEntreprise({required SupabaseClient? Function() client, required JsonCacheStore cache})
      : _client = client,
        _cache = cache;

  final SupabaseClient? Function() _client;
  final JsonCacheStore _cache;

  static const tailleMax = 2 * 1024 * 1024;
  static String _cle(String eid) => 'logo_entreprise:$eid';

  Future<Uint8List?> local(String eid) async {
    final c = await _cache.read(_cle(eid));
    final b64 = c?.data['octets'] as String?;
    return b64 == null ? null : base64Decode(b64);
  }

  /// Met la copie locale à jour si le logo a changé côté serveur.
  Future<Uint8List?> synchroniser(String eid, String? chemin) async {
    final c = await _cache.read(_cle(eid));
    if (chemin == null) {
      if (c != null) await _cache.write(_cle(eid), const {});
      return null;
    }
    if (c?.data['chemin'] == chemin && c?.data['octets'] != null) return base64Decode(c!.data['octets'] as String);
    final client = _client() ?? (throw const Failure(FailureKind.network));
    try {
      final octets = await client.storage.from('fichiers').download(chemin);
      await _cache.write(_cle(eid), {'chemin': chemin, 'octets': base64Encode(octets)});
      return octets;
    } catch (e, st) {
      throw ErrorMapper.map(e, st);
    }
  }

  /// En ligne, avec `entreprise.manage` (contrôlé par le serveur).
  Future<Uint8List> envoyer(String eid, Uint8List octets, String typeMime) async {
    if (!{'image/png', 'image/jpeg', 'image/webp'}.contains(typeMime)) {
      throw const Failure.rule('TYPE_FICHIER_INVALIDE');
    }
    if (octets.length > tailleMax) throw const Failure.rule('FICHIER_TROP_GROS', {'max': 2});
    final client = _client() ?? (throw const Failure(FailureKind.network));
    final extension = typeMime.split('/').last == 'jpeg' ? 'jpg' : typeMime.split('/').last;
    final chemin = '$eid/logo/logo-${DateTime.now().millisecondsSinceEpoch}.$extension';
    try {
      await client.storage.from('fichiers').uploadBinary(chemin, octets, fileOptions: FileOptions(contentType: typeMime));
      await client.from('entreprises').update({'logo_path': chemin}).eq('id', eid);
    } catch (e, st) {
      throw ErrorMapper.map(e, st);
    }
    await _cache.write(_cle(eid), {'chemin': chemin, 'octets': base64Encode(octets)});
    return octets;
  }
}
