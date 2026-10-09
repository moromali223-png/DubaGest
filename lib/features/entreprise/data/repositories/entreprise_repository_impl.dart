import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/database/json_cache_store.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/errors/failure.dart';
import '../../../activites/domain/entities/activite.dart';
import '../../domain/entities/offre_plan.dart';
import '../../domain/entities/profil_entreprise.dart';
import '../../domain/repositories/entreprise_repository.dart';

/// Création d'entreprise : en ligne uniquement (pas de file hors-ligne : la
/// création doit être validée immédiatement par le serveur).
class EntrepriseRepositoryImpl implements EntrepriseRepository {
  EntrepriseRepositoryImpl(this._client, {JsonCacheStore? cache}) : _cache = cache;
  final SupabaseClient _client;

  /// Dernier profil connu : en-tête des documents émis hors-ligne.
  final JsonCacheStore? _cache;

  static String _cleProfil(String entrepriseId) => 'profil_entreprise:$entrepriseId';

  @override
  Future<List<OffrePlan>> offres() => _guard(() async {
        final rows = await _client
            .from('plans')
            .select('code, max_activites, prix_mensuel, devise_prix, plan_activites(activite_code)')
            .eq('est_actif', true)
            .order('ordre', ascending: true);
        return [
          for (final p in rows)
            OffrePlan(
              code: p['code'] as String,
              maxActivites: p['max_activites'] as int,
              prixMensuel: p['prix_mensuel'] as int? ?? 0,
              devisePrix: p['devise_prix'] as String? ?? 'XOF',
              activites: [
                for (final a in (p['plan_activites'] as List).cast<Map<String, dynamic>>())
                  ?ActiviteCode.tryParse(a['activite_code'] as String?),
              ]..sort((a, b) => a.index.compareTo(b.index)),
            ),
        ];
      });

  @override
  Future<String> creer({
    required String nom,
    required String planCode,
    required List<ActiviteCode> activites,
  }) =>
      _guard(() => _client.rpc<String>('creer_entreprise', params: {
            'p_nom': nom,
            'p_plan_code': planCode,
            'p_activites': [for (final a in activites) a.code],
          }));

  @override
  Future<ProfilEntreprise> profil(String entrepriseId) async {
    Map<String, dynamic> j;
    try {
      j = await _guard(() => _client
          .from('entreprises')
          .select('id, nom, devise, langue_defaut, pays, telephone, adresse, ville, '
              'identifiant_fiscal, registre_commerce, logo_path, modes_paiement, pied_recu')
          .eq('id', entrepriseId)
          .single());
      await _cache?.write(_cleProfil(entrepriseId), j);
    } on Failure catch (f) {
      // Hors-ligne seulement : un refus de droits n'est jamais masqué.
      final cache = f.kind == FailureKind.network ? await _cache?.read(_cleProfil(entrepriseId)) : null;
      if (cache == null) rethrow;
      j = cache.data;
    }
    return ProfilEntreprise(
          id: j['id'] as String,
          nom: j['nom'] as String,
          devise: j['devise'] as String,
          langueDocuments: j['langue_defaut'] as String,
          pays: j['pays'] as String?,
          telephone: j['telephone'] as String?,
          adresse: j['adresse'] as String?,
          ville: j['ville'] as String?,
          identifiantFiscal: j['identifiant_fiscal'] as String?,
      registreCommerce: j['registre_commerce'] as String?,
      logoPath: j['logo_path'] as String?,
      // Profil mis en cache avant l'étape 9 : tous les modes.
      modesPaiement: (j['modes_paiement'] as List?)?.cast<String>() ?? ProfilEntreprise.tousLesModes,
      piedRecu: j['pied_recu'] as String?,
    );
  }

  @override
  Future<void> enregistrerParametres(String entrepriseId, {required List<String> modesPaiement, String? piedRecu}) =>
      _guard(() async {
        final lignes = await _client
            .from('entreprises')
            .update({
              'modes_paiement': modesPaiement,
              'pied_recu': piedRecu?.trim().isEmpty ?? true ? null : piedRecu!.trim(),
            })
            .eq('id', entrepriseId)
            .select('id');
        // Ligne masquée par la RLS (droit retiré entre-temps) : rien n'a changé.
        if (lignes.isEmpty) throw const Failure(FailureKind.forbidden);
        // Profil en cache rafraîchi tout de suite (formulaires hors-ligne).
        await profil(entrepriseId);
      });

  @override
  Future<void> enregistrerProfil(ProfilEntreprise p) => _guard(() async {
        String? vide(String? v) => (v == null || v.trim().isEmpty) ? null : v.trim();
        await _client.from('entreprises').update({
          'nom': p.nom.trim(),
          'devise': p.devise,
          'langue_defaut': p.langueDocuments,
          'pays': vide(p.pays)?.toUpperCase(),
          'telephone': vide(p.telephone),
          'adresse': vide(p.adresse),
          'ville': vide(p.ville),
          'identifiant_fiscal': vide(p.identifiantFiscal),
          'registre_commerce': vide(p.registreCommerce),
        }).eq('id', p.id);
      });

  @override
  Future<void> activerActivite({
    required String entrepriseId,
    required ActiviteCode activite,
    required bool dejaRattachee,
  }) =>
      _guard(() async {
        if (dejaRattachee) {
          await _client
              .from('entreprise_activites')
              .update({'est_active': true})
              .eq('entreprise_id', entrepriseId)
              .eq('activite_code', activite.code);
        } else {
          await _client
              .from('entreprise_activites')
              .insert({'entreprise_id': entrepriseId, 'activite_code': activite.code});
        }
      });

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (e, st) {
      throw ErrorMapper.map(e, st);
    }
  }
}
