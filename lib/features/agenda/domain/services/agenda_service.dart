import '../../../finances/domain/entities/finances.dart';
import '../../../finances/domain/services/etat_finances.dart';
import '../entities/agenda.dart';

/// Construction de l'agenda et des alertes : logique pure, sans base.
abstract final class AgendaService {
  static DateTime _jour(DateTime d) => DateTime(d.year, d.month, d.day);

  /// [finances] : null si l'utilisateur ne voit pas les sommes dues.
  static Agenda construire({
    required List<Echeance> echeances,
    required DateTime maintenant,
    required String userId,
    EtatFinances? finances,
    bool mesTaches = false,
  }) {
    final elements = <ElementAgenda>[
      for (final e in echeances)
        if (e.aFaire && !e.refusee && (!mesTaches || e.concerne(userId))) ElementEcheance(e),
      if (finances != null && !mesTaches)
        for (final s in finances.suivis)
          if (s.engagement.echeance != null && s.reste > 0 && !s.engagement.refuse) ElementSommeDue(s),
    ]..sort((a, b) => a.date.compareTo(b.date));

    final aujourdhui = _jour(maintenant);
    final dansUneSemaine = aujourdhui.add(const Duration(days: 8));
    // En retard à partir du lendemain ; le jour même, reste dans « Aujourd'hui ».
    bool enRetard(ElementAgenda x) => _jour(x.date).isBefore(aujourdhui);

    final retard = <ElementAgenda>[], jour = <ElementAgenda>[], semaine = <ElementAgenda>[], tard = <ElementAgenda>[];
    for (final x in elements) {
      final d = _jour(x.date);
      if (enRetard(x)) {
        retard.add(x);
      } else if (d == aujourdhui) {
        jour.add(x);
      } else if (d.isBefore(dansUneSemaine)) {
        semaine.add(x);
      } else {
        tard.add(x);
      }
    }
    return Agenda(enRetard: retard, aujourdhui: jour, aVenir: semaine, plusTard: tard);
  }

  /// Alertes réelles de cet utilisateur, les plus urgentes d'abord.
  static List<Alerte> alertes({
    required List<Echeance> echeances,
    required DateTime maintenant,
    required String userId,
    EtatFinances? finances,
    bool voirCreances = false,
    bool voirCaisse = false,
  }) {
    final aujourdhui = _jour(maintenant);
    final resultat = <Alerte>[];

    final miennes = echeances.where((e) => e.aFaire && !e.refusee && e.concerne(userId)).toList()
      ..sort((a, b) => a.dateHeure.compareTo(b.dateHeure));
    for (final e in miennes) {
      final rappel = e.dateHeure.subtract(Duration(minutes: e.rappelMinutes ?? 0));
      if (_jour(e.dateHeure).isBefore(aujourdhui)) {
        resultat.add(AlerteEcheance(e, enRetard: true));
      } else if (_jour(e.dateHeure) == aujourdhui || (e.rappelMinutes != null && !maintenant.isBefore(rappel))) {
        resultat.add(AlerteEcheance(e, enRetard: false));
      }
    }

    if (finances != null) {
      if (voirCreances) {
        final retard = finances.suivis
            .where((s) => !s.engagement.refuse && s.engagement.sens == SensEngagement.aRecevoir)
            .where((s) => s.etat(maintenant) == EtatReglement.enRetard)
            .toList();
        if (retard.isNotEmpty) {
          resultat.add(AlerteCreancesEnRetard(nombre: retard.length, montant: retard.fold(0, (t, s) => t + s.reste)));
        }
      }
      if (voirCaisse) {
        for (final c in finances.caisses) {
          final s = finances.sessionOuverte(c.id);
          if (s != null && maintenant.difference(s.ouverteLe) > const Duration(hours: 24)) {
            resultat.add(AlerteCaisseOuverte(c, s.ouverteLe));
          }
        }
      }
      final refusees = finances.paiements.where((p) => p.refuse).length +
          finances.depenses.where((d) => d.refusee).length +
          finances.engagements.where((e) => e.refuse && e.origineType == 'MANUEL').length;
      if (refusees > 0) resultat.add(AlerteEcrituresRefusees(refusees));
    }
    return resultat;
  }
}
