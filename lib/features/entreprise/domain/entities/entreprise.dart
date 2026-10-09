enum EntrepriseStatut {
  active('ACTIVE'),
  suspendue('SUSPENDUE'),
  archivee('ARCHIVEE');

  const EntrepriseStatut(this.code);
  final String code;

  static EntrepriseStatut parse(String code) =>
      values.firstWhere((s) => s.code == code, orElse: () => EntrepriseStatut.suspendue);
}

/// Tenant : toutes les données métier lui sont rattachées.
class Entreprise {
  const Entreprise({
    required this.id,
    required this.nom,
    required this.statut,
    this.pays,
    this.devise,
  });

  final String id;
  final String nom;
  final EntrepriseStatut statut;
  final String? pays;
  final String? devise;
}

class EntrepriseResume {
  const EntrepriseResume({required this.id, required this.nom});
  final String id;
  final String nom;
}
