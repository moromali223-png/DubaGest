import '../../../activites/domain/entities/activite.dart';

/// Formule proposée à la création d'une entreprise (catalogue serveur).
class OffrePlan {
  const OffrePlan({
    required this.code,
    required this.maxActivites,
    required this.activites,
    this.prixMensuel = 0,
    this.devisePrix = 'XOF',
  });

  final String code;
  final int maxActivites;
  final List<ActiviteCode> activites;

  /// Prix mensuel en unités entières de [devisePrix].
  final int prixMensuel;
  final String devisePrix;
}
