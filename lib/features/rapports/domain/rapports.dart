import '../../finances/domain/entities/finances.dart';
import '../../finances/domain/services/etat_finances.dart';

enum TypeRapport { tresorerie, depenses, balanceAgee, caisses }

DateTime _jour(DateTime d) => DateTime(d.year, d.month, d.day);

bool _dans(DateTime d, DateTime debut, DateTime fin) {
  final j = _jour(d.toLocal());
  return !j.isBefore(debut) && !j.isAfter(fin);
}

class LigneTresorerie {
  const LigneTresorerie(this.paiement, {required this.annule});
  final Paiement paiement;
  final bool annule;
}

class JournalTresorerie {
  const JournalTresorerie(this.lignes, {required this.entrees, required this.sorties});
  final List<LigneTresorerie> lignes;

  /// Hors paiements annulés et annulations.
  final int entrees;
  final int sorties;
  int get solde => entrees - sorties;
}

class LigneDepenses {
  const LigneDepenses(this.categorie, {required this.nombre, required this.montant});
  final CategorieDepense? categorie;
  final int nombre;
  final int montant;
}

/// Créances d'un contact, réparties par ancienneté du retard.
class LigneBalance {
  LigneBalance(this.contactId);
  final String? contactId;
  int nonEchu = 0;
  int jours30 = 0;
  int jours60 = 0;
  int jours90 = 0;
  int plus90 = 0;
  int get total => nonEchu + jours30 + jours60 + jours90 + plus90;
}

class LigneCaisse {
  const LigneCaisse(this.caisse, this.session);
  final Caisse caisse;
  final SessionCaisse session;
}

/// Rapports communs, calculés sur les données de l'appareil (hors-ligne).
abstract final class Rapports {
  static JournalTresorerie tresorerie(EtatFinances etat, DateTime debut, DateTime fin) {
    final lignes = [
      for (final p in etat.paiements)
        if (!p.refuse && _dans(p.datePaiement, debut, fin)) LigneTresorerie(p, annule: etat.estAnnule(p)),
    ]..sort((a, b) => a.paiement.datePaiement.compareTo(b.paiement.datePaiement));
    var entrees = 0, sorties = 0;
    for (final l in lignes) {
      if (!etat.compte(l.paiement)) continue;
      l.paiement.sens == SensPaiement.entree ? entrees += l.paiement.montant : sorties += l.paiement.montant;
    }
    return JournalTresorerie(lignes, entrees: entrees, sorties: sorties);
  }

  static List<LigneDepenses> depenses(EtatFinances etat, DateTime debut, DateTime fin) {
    final parCategorie = <String, (int, int)>{};
    for (final d in etat.depenses) {
      if (!etat.depenseComptee(d) || !_dans(d.dateDepense, debut, fin)) continue;
      final (n, m) = parCategorie[d.categorieId] ?? (0, 0);
      parCategorie[d.categorieId] = (n + 1, m + d.montant);
    }
    return [
      for (final e in parCategorie.entries)
        LigneDepenses(etat.categorie(e.key), nombre: e.value.$1, montant: e.value.$2),
    ]..sort((a, b) => b.montant.compareTo(a.montant));
  }

  /// Sommes à recevoir non réglées, par contact et par retard à date.
  static List<LigneBalance> balanceAgee(EtatFinances etat, DateTime maintenant) {
    final aujourdhui = _jour(maintenant);
    final parContact = <String?, LigneBalance>{};
    for (final s in etat.suivis) {
      final e = s.engagement;
      if (e.refuse || e.sens != SensEngagement.aRecevoir || s.reste == 0) continue;
      final l = parContact.putIfAbsent(e.contactId, () => LigneBalance(e.contactId));
      final retard = e.echeance == null ? 0 : aujourdhui.difference(e.echeance!).inDays;
      switch (retard) {
        case <= 0:
          l.nonEchu += s.reste;
        case <= 30:
          l.jours30 += s.reste;
        case <= 60:
          l.jours60 += s.reste;
        case <= 90:
          l.jours90 += s.reste;
        default:
          l.plus90 += s.reste;
      }
    }
    return parContact.values.toList()..sort((a, b) => b.total.compareTo(a.total));
  }

  /// Sessions clôturées dans la période (écart compté − attendu).
  static List<LigneCaisse> caisses(EtatFinances etat, DateTime debut, DateTime fin) => [
        for (final s in etat.sessions)
          if (!s.ouverte && s.fermeeLe != null && _dans(s.fermeeLe!, debut, fin))
            if (etat.caisses.where((c) => c.id == s.caisseId).firstOrNull case final c?) LigneCaisse(c, s),
      ]..sort((a, b) => b.session.fermeeLe!.compareTo(a.session.fermeeLe!));
}
