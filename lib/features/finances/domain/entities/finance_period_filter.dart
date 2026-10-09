/// Période d'analyse financière.
enum TypePeriodeFinance {
  aujourdhui('AUJOURDHUI'),
  cetteSemaine('CETTE_SEMAINE'),
  ceMois('CE_MOIS'),
  ceTrimestre('CE_TRIMESTRE'),
  cetteAnnee('CETTE_ANNEE'),
  personnalise('PERSONNALISE');

  const TypePeriodeFinance(this.code);
  final String code;

  static TypePeriodeFinance parse(String? c) =>
      values.firstWhere((v) => v.code == c, orElse: () => ceMois);
}

/// Plage de dates concrète [debut, fin] (inclusive).
class PlageDates {
  const PlageDates({required this.debut, required this.fin});

  final DateTime debut;
  final DateTime fin;

  int get dureeJours => fin.difference(debut).inDays + 1;

  bool contient(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    final d0 = DateTime(debut.year, debut.month, debut.day);
    final d1 = DateTime(fin.year, fin.month, fin.day);
    return !d.isBefore(d0) && !d.isAfter(d1);
  }

  /// Calcule la plage précédente de même durée pour la comparaison.
  PlageDates plagePrecedente() {
    final jours = dureeJours;
    final finPrec = debut.subtract(const Duration(days: 1));
    final debPrec = finPrec.subtract(Duration(days: jours - 1));
    return PlageDates(
      debut: DateTime(debPrec.year, debPrec.month, debPrec.day),
      fin: DateTime(finPrec.year, finPrec.month, finPrec.day, 23, 59, 59),
    );
  }
}

/// Filtre de période financière avec résolution dynamique de dates.
class FiltrePeriodeFinance {
  const FiltrePeriodeFinance({
    this.type = TypePeriodeFinance.ceMois,
    this.debutPersonnalise,
    this.finPersonnalise,
  });

  final TypePeriodeFinance type;
  final DateTime? debutPersonnalise;
  final DateTime? finPersonnalise;

  PlageDates resoudre(DateTime maintenant) {
    final j = DateTime(maintenant.year, maintenant.month, maintenant.day);
    switch (type) {
      case TypePeriodeFinance.aujourdhui:
        return PlageDates(
          debut: j,
          fin: DateTime(j.year, j.month, j.day, 23, 59, 59),
        );
      case TypePeriodeFinance.cetteSemaine:
        // Semaine du lundi au dimanche
        final decalage = (j.weekday - DateTime.monday) % 7;
        final debut = j.subtract(Duration(days: decalage));
        final fin = debut.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
        return PlageDates(debut: debut, fin: fin);
      case TypePeriodeFinance.ceMois:
        final debut = DateTime(j.year, j.month, 1);
        final fin = DateTime(j.year, j.month + 1, 0, 23, 59, 59);
        return PlageDates(debut: debut, fin: fin);
      case TypePeriodeFinance.ceTrimestre:
        final moisDebut = ((j.month - 1) ~/ 3) * 3 + 1;
        final debut = DateTime(j.year, moisDebut, 1);
        final fin = DateTime(j.year, moisDebut + 3, 0, 23, 59, 59);
        return PlageDates(debut: debut, fin: fin);
      case TypePeriodeFinance.cetteAnnee:
        final debut = DateTime(j.year, 1, 1);
        final fin = DateTime(j.year, 12, 31, 23, 59, 59);
        return PlageDates(debut: debut, fin: fin);
      case TypePeriodeFinance.personnalise:
        final deb = debutPersonnalise ?? DateTime(j.year, j.month, 1);
        final f = finPersonnalise ?? j;
        return PlageDates(
          debut: DateTime(deb.year, deb.month, deb.day),
          fin: DateTime(f.year, f.month, f.day, 23, 59, 59),
        );
    }
  }

  String libelleCourt() => switch (type) {
        TypePeriodeFinance.aujourdhui => "Aujourd'hui",
        TypePeriodeFinance.cetteSemaine => 'Cette semaine',
        TypePeriodeFinance.ceMois => 'Ce mois',
        TypePeriodeFinance.ceTrimestre => 'Ce trimestre',
        TypePeriodeFinance.cetteAnnee => 'Cette année',
        TypePeriodeFinance.personnalise => 'Personnalisé',
      };
}
