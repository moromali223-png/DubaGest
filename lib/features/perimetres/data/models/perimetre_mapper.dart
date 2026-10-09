import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/sync/sync_models.dart';
import '../../../activites/domain/entities/activite.dart';
import '../../domain/entities/perimetre.dart';

abstract final class PerimetreMapper {
  static Perimetre fromRow(PerimetreRow r) => Perimetre(
        id: r.id,
        entrepriseId: r.entrepriseId,
        activite: ActiviteCode.tryParse(r.activiteCode) ?? ActiviteCode.commerce,
        type: PerimetreType.parse(r.type),
        nom: r.nom,
        code: r.code,
        estActif: r.estActif,
        version: r.version,
        syncStatus: RecordSyncStatus.fromWire(r.syncStatus),
      );

  static PerimetresCompanion toLocalCompanion(Perimetre p) => PerimetresCompanion.insert(
        id: p.id,
        entrepriseId: p.entrepriseId,
        activiteCode: p.activite.code,
        type: p.type.code,
        nom: p.nom,
        code: Value(p.code),
        estActif: Value(p.estActif),
        version: Value(p.version),
        syncStatus: p.syncStatus.wire,
      );

  static PerimetresCompanion fromServer(Map<String, dynamic> j, RecordSyncStatus status) =>
      PerimetresCompanion.insert(
        id: j['id'] as String,
        entrepriseId: j['entreprise_id'] as String,
        activiteCode: j['activite_code'] as String,
        type: j['type'] as String,
        nom: j['nom'] as String,
        code: Value(j['code'] as String?),
        estActif: Value(j['est_actif'] as bool? ?? true),
        version: Value(j['version'] as int?),
        updatedAt: Value(j['updated_at'] == null ? null : DateTime.parse(j['updated_at'] as String)),
        deletedAt: const Value(null),
        syncStatus: status.wire,
      );

  /// Charge utile envoyée au serveur (colonnes déclarées dans app.sync_tables).
  static Map<String, dynamic> toInsertPayload(Perimetre p) => {
        'entreprise_id': p.entrepriseId,
        'activite_code': p.activite.code,
        'type': p.type.code,
        'nom': p.nom,
        'code': p.code,
        'est_actif': p.estActif,
      };

  static bool sameContent(PerimetreRow local, Map<String, dynamic> server) =>
      local.nom == server['nom'] &&
      local.code == server['code'] &&
      local.type == server['type'] &&
      local.estActif == server['est_actif'];
}
