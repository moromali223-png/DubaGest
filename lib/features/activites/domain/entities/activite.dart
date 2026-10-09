/// Catalogue des activités (table `public.activites`).
enum ActiviteCode {
  commerce('COMMERCE'),
  services('SERVICES'),
  immobilier('IMMOBILIER');

  const ActiviteCode(this.code);
  final String code;

  /// `null` pour une activité inconnue de cette version de l'application
  /// (ajoutée côté serveur) : elle est ignorée plutôt que de planter.
  static ActiviteCode? tryParse(String? code) {
    for (final a in values) {
      if (a.code == code) return a;
    }
    return null;
  }
}

/// Activité rattachée à une entreprise.
class EntrepriseActivite {
  const EntrepriseActivite({
    required this.activite,
    required this.estActive,
    required this.typePerimetreDefaut,
  });

  final ActiviteCode activite;
  final bool estActive;
  final String typePerimetreDefaut;
}
