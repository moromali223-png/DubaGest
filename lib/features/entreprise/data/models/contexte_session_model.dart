import '../../../../core/sync/sync_models.dart';
import '../../../abonnement/domain/entities/abonnement.dart';
import '../../../activites/domain/entities/activite.dart';
import '../../../modules/domain/entities/app_module.dart';
import '../../../perimetres/domain/entities/perimetre.dart';
import '../../../roles/domain/entities/role.dart';
import '../../../utilisateurs/domain/entities/membre.dart';
import '../../domain/entities/contexte_session.dart';
import '../../domain/entities/entreprise.dart';

typedef Json = Map<String, dynamic>;

/// Conversion de la réponse de `get_contexte_session` en entité de domaine.
/// Tolérant : un code inconnu (ajouté côté serveur) est ignoré.
abstract final class ContexteSessionModel {
  static ContexteSession fromJson(
    Json json, {
    required String userId,
    required DateTime chargeLe,
    required bool depuisCache,
  }) {
    final membreJson = json['membre'] as Json?;
    final perimetres = _list<Json>(json['perimetres']).map(_perimetre).whereType<Perimetre>().toList();

    return ContexteSession(
      userId: userId,
      nomComplet: (json['profil'] as Json?)?['nom_complet'] as String?,
      entreprises: _list<Json>(json['entreprises'])
          .map((e) => EntrepriseResume(id: e['id'] as String, nom: e['nom'] as String))
          .toList(),
      entreprise: _entreprise(json['entreprise'] as Json?),
      membre: membreJson == null
          ? null
          : Membre(
              id: membreJson['id'] as String,
              userId: userId,
              roleCode: membreJson['role_code'] as String,
              statut: MembreStatut.parse(membreJson['statut'] as String),
              perimetreIds: {for (final p in perimetres) p.id},
            ),
      permissions: _list<String>(json['permissions']).toSet(),
      abonnement: _abonnement(json['abonnement'] as Json?),
      plan: _plan(json['plan'] as Json?),
      activites: _list<Json>(json['activites']).map(_activite).whereType<EntrepriseActivite>().toList(),
      roles: {
        for (final r in _list<Json>(json['roles']))
          r['code'] as String: Role(
            code: r['code'] as String,
            activite: ActiviteCode.tryParse(r['activite_code'] as String?),
            accesTousPerimetres: r['acces_tous_perimetres'] == true,
          ),
      },
      modules: _list<Json>(json['modules']).map(_module).whereType<AppModule>().toList(),
      perimetres: perimetres,
      consommation: _consommation(json['usage'] as Json?),
      chargeLe: chargeLe,
      depuisCache: depuisCache,
    );
  }

  static List<T> _list<T>(Object? value) => value is List ? value.cast<T>() : <T>[];

  static Entreprise? _entreprise(Json? j) => j == null
      ? null
      : Entreprise(
          id: j['id'] as String,
          nom: j['nom'] as String,
          statut: EntrepriseStatut.parse(j['statut'] as String),
          pays: j['pays'] as String?,
          devise: j['devise'] as String?,
        );

  static Abonnement? _abonnement(Json? j) => j == null
      ? null
      : Abonnement(
          id: j['id'] as String,
          planCode: j['plan_code'] as String,
          statut: AbonnementStatut.parse(j['statut'] as String),
          dateDebut: DateTime.parse(j['date_debut'] as String),
          dateFin: j['date_fin'] == null ? null : DateTime.parse(j['date_fin'] as String),
        );

  static Plan? _plan(Json? j) {
    if (j == null) return null;
    final activites = <ActiviteCode, PlanActiviteLimites>{};
    for (final a in _list<Json>(j['activites'])) {
      final code = ActiviteCode.tryParse(a['activite_code'] as String?);
      if (code == null) continue;
      activites[code] = PlanActiviteLimites(
        activite: code,
        maxUtilisateurs: a['max_utilisateurs'] as int?,
        maxPerimetres: a['max_perimetres'] as int?,
      );
    }
    return Plan(
      code: j['code'] as String,
      nom: j['nom'] as String,
      maxActivites: j['max_activites'] as int,
      activites: activites,
      quotasRoles: {
        for (final r in _list<Json>(j['roles'])) r['role_code'] as String: r['max_membres'] as int?,
      },
      modules: _list<String>(j['modules']).toSet(),
    );
  }

  static EntrepriseActivite? _activite(Json j) {
    final code = ActiviteCode.tryParse(j['code'] as String?);
    if (code == null) return null;
    return EntrepriseActivite(
      activite: code,
      estActive: j['est_active'] == true,
      typePerimetreDefaut: j['type_perimetre_defaut'] as String,
    );
  }

  static AppModule? _module(Json j) {
    final activiteCode = j['activite_code'] as String?;
    final activite = ActiviteCode.tryParse(activiteCode);
    if (activiteCode != null && activite == null) return null;
    return AppModule(
      code: j['code'] as String,
      activite: activite,
      permissionAcces: j['permission_acces'] as String,
      ordre: j['ordre'] as int,
      categorie: ModuleCategorie.tryParse(j['categorie'] as String?),
    );
  }

  static Perimetre? _perimetre(Json j) {
    final activite = ActiviteCode.tryParse(j['activite_code'] as String?);
    if (activite == null) return null;
    return Perimetre(
      id: j['id'] as String,
      entrepriseId: j['entreprise_id'] as String,
      activite: activite,
      type: PerimetreType.parse(j['type'] as String),
      nom: j['nom'] as String,
      code: j['code'] as String?,
      estActif: j['est_actif'] == true,
      version: j['version'] as int?,
      syncStatus: RecordSyncStatus.synced,
    );
  }

  static ConsommationAbonnement _consommation(Json? j) {
    if (j == null) return ConsommationAbonnement.vide;
    final parActivite = <ActiviteCode, int>{};
    ((j['perimetres_par_activite'] as Json?) ?? const {}).forEach((key, value) {
      final code = ActiviteCode.tryParse(key);
      if (code != null) parActivite[code] = value as int;
    });
    return ConsommationAbonnement(
      utilisateurs: j['utilisateurs'] as int? ?? 0,
      membresParRole: ((j['membres_par_role'] as Json?) ?? const {}).cast<String, int>(),
      perimetresParActivite: parActivite,
    );
  }
}
