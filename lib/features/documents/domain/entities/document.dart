import '../../../../core/sync/sync_models.dart';

enum TypeDocument {
  recu('RECU'),
  facture('FACTURE'),
  devis('DEVIS'),
  avoir('AVOIR');

  const TypeDocument(this.code);
  final String code;

  static TypeDocument parse(String? code) => values.firstWhere((t) => t.code == code, orElse: () => recu);
}

/// Numéro affiché : PREFIXE-ANNÉE-00000 (même règle que le serveur).
String formatNumero(String prefixe, int annee, int sequence) =>
    '$prefixe-$annee-${sequence.toString().padLeft(5, '0')}';

/// Bloc de numéros réservé par cet appareil, utilisable hors-ligne.
class NumeroBloc {
  const NumeroBloc({
    required this.id,
    required this.entrepriseId,
    required this.userId,
    required this.type,
    required this.prefixe,
    required this.annee,
    required this.debut,
    required this.fin,
    required this.prochain,
  });

  final String id;
  final String entrepriseId;
  final String userId;
  final TypeDocument type;
  final String prefixe;
  final int annee;
  final int debut;
  final int fin;

  /// Prochain numéro libre de ce bloc sur cet appareil.
  final int prochain;

  int get restant => prochain > fin ? 0 : fin - prochain + 1;
}

/// Document émis : son [contenu] est figé à l'émission (en-tête de
/// l'entreprise, contact, montants) et ne change plus.
class Document {
  const Document({
    required this.id,
    required this.entrepriseId,
    required this.type,
    required this.numero,
    required this.blocId,
    required this.sequence,
    required this.langue,
    required this.date,
    required this.montant,
    required this.origineType,
    required this.contenu,
    this.origineId,
    this.perimetreId,
    this.contactId,
    this.version,
    this.syncStatus = RecordSyncStatus.synced,
  });

  final String id;
  final String entrepriseId;
  final TypeDocument type;
  final String numero;
  final String blocId;
  final int sequence;

  /// Langue du document (celle choisie dans le profil de l'entreprise).
  final String langue;
  final DateTime date;
  final int montant;
  final String origineType;
  final String? origineId;
  final String? perimetreId;
  final String? contactId;
  final Map<String, dynamic> contenu;
  final int? version;
  final RecordSyncStatus syncStatus;

  /// Refusé par le serveur (ex. reçu déjà émis sur un autre appareil).
  bool get refuse => syncStatus == RecordSyncStatus.syncError && version == null;
}
