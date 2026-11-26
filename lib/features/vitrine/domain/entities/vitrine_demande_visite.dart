/// Statut d'une demande de visite immobilière
enum StatutDemandeVisite {
  enAttente('EN_ATTENTE', 'En attente'),
  confirmee('CONFIRMEE', 'Confirmée'),
  annulee('ANNULEE', 'Annulée');

  const StatutDemandeVisite(this.code, this.libelle);
  final String code;
  final String libelle;

  static StatutDemandeVisite fromCode(String? code) {
    return values.firstWhere(
      (e) => e.code == code,
      orElse: () => StatutDemandeVisite.enAttente,
    );
  }
}

/// Demande de visite pour un bien immobilier envoyée par un prospect
class VitrineDemandeVisite {
  const VitrineDemandeVisite({
    required this.id,
    required this.vitrineId,
    required this.entrepriseId,
    this.bienId,
    required this.nomBien,
    required this.nomClient,
    required this.telephoneClient,
    this.emailClient,
    required this.dateSouhaitee,
    required this.heureSouhaitee,
    this.messageClient,
    this.statut = StatutDemandeVisite.enAttente,
    this.createdAt,
  });

  final String id;
  final String vitrineId;
  final String entrepriseId;
  final String? bienId;
  final String nomBien;
  final String nomClient;
  final String telephoneClient;
  final String? emailClient;
  final DateTime dateSouhaitee;
  final String heureSouhaitee;
  final String? messageClient;
  final StatutDemandeVisite statut;
  final DateTime? createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'vitrine_id': vitrineId,
        'entreprise_id': entrepriseId,
        if (bienId != null) 'bien_id': bienId,
        'nom_bien': nomBien,
        'nom_client': nomClient,
        'telephone_client': telephoneClient,
        if (emailClient != null) 'email_client': emailClient,
        'date_souhaitee': dateSouhaitee.toIso8601String().split('T').first,
        'heure_souhaitee': heureSouhaitee,
        if (messageClient != null) 'message_client': messageClient,
        'statut': statut.code,
      };

  factory VitrineDemandeVisite.fromJson(Map<String, dynamic> j) {
    return VitrineDemandeVisite(
      id: j['id']?.toString() ?? '',
      vitrineId: j['vitrine_id']?.toString() ?? '',
      entrepriseId: j['entreprise_id']?.toString() ?? '',
      bienId: j['bien_id']?.toString(),
      nomBien: j['nom_bien']?.toString() ?? 'Bien immobilier',
      nomClient: j['nom_client']?.toString() ?? '',
      telephoneClient: j['telephone_client']?.toString() ?? '',
      emailClient: j['email_client']?.toString(),
      dateSouhaitee: DateTime.tryParse(j['date_souhaitee']?.toString() ?? '') ?? DateTime.now(),
      heureSouhaitee: j['heure_souhaitee']?.toString() ?? '10:00',
      messageClient: j['message_client']?.toString(),
      statut: StatutDemandeVisite.fromCode(j['statut']?.toString()),
      createdAt: j['created_at'] != null ? DateTime.tryParse(j['created_at'].toString()) : null,
    );
  }

  VitrineDemandeVisite copyWith({
    String? nomClient,
    String? telephoneClient,
    String? emailClient,
    DateTime? dateSouhaitee,
    String? heureSouhaitee,
    String? messageClient,
    StatutDemandeVisite? statut,
  }) =>
      VitrineDemandeVisite(
        id: id,
        vitrineId: vitrineId,
        entrepriseId: entrepriseId,
        bienId: bienId,
        nomBien: nomBien,
        nomClient: nomClient ?? this.nomClient,
        telephoneClient: telephoneClient ?? this.telephoneClient,
        emailClient: emailClient ?? this.emailClient,
        dateSouhaitee: dateSouhaitee ?? this.dateSouhaitee,
        heureSouhaitee: heureSouhaitee ?? this.heureSouhaitee,
        messageClient: messageClient ?? this.messageClient,
        statut: statut ?? this.statut,
        createdAt: createdAt,
      );
}
