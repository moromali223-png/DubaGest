/// Statut d'une demande de rendez-vous reçue via la vitrine
enum StatutRendezVous {
  enAttente('EN_ATTENTE', 'En attente'),
  confirme('CONFIRME', 'Confirmé'),
  refuse('REFUSE', 'Refusé'),
  termine('TERMINE', 'Terminé');

  const StatutRendezVous(this.code, this.libelle);
  final String code;
  final String libelle;

  static StatutRendezVous fromCode(String? code) {
    return values.firstWhere(
      (e) => e.code == code,
      orElse: () => StatutRendezVous.enAttente,
    );
  }
}

/// Demande de rendez-vous enregistrée depuis la vitrine
class VitrineRendezVous {
  const VitrineRendezVous({
    required this.id,
    required this.vitrineId,
    required this.entrepriseId,
    this.prestationId,
    required this.nomPrestation,
    required this.dateSouhaitee,
    required this.heureSouhaitee,
    required this.nomClient,
    required this.telephoneClient,
    this.messageClient,
    this.statut = StatutRendezVous.enAttente,
    this.reponseSalon,
    this.createdAt,
  });

  final String id;
  final String vitrineId;
  final String entrepriseId;
  final String? prestationId;
  final String nomPrestation;
  final DateTime dateSouhaitee;
  final String heureSouhaitee;
  final String nomClient;
  final String telephoneClient;
  final String? messageClient;
  final StatutRendezVous statut;
  final String? reponseSalon;
  final DateTime? createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'vitrine_id': vitrineId,
        'entreprise_id': entrepriseId,
        'prestation_id': prestationId,
        'nom_prestation': nomPrestation,
        'date_souhaitee': dateSouhaitee.toIso8601String().split('T').first,
        'heure_souhaitee': heureSouhaitee,
        'nom_client': nomClient,
        'telephone_client': telephoneClient,
        'message_client': messageClient,
        'statut': statut.code,
        'reponse_salon': reponseSalon,
      };

  factory VitrineRendezVous.fromJson(Map<String, dynamic> j) {
    final ds = j['date_souhaitee'] != null
        ? DateTime.tryParse(j['date_souhaitee'].toString()) ?? DateTime.now()
        : DateTime.now();
    return VitrineRendezVous(
      id: j['id'] as String? ?? '',
      vitrineId: j['vitrine_id'] as String? ?? '',
      entrepriseId: j['entreprise_id'] as String? ?? '',
      prestationId: j['prestation_id'] as String?,
      nomPrestation: j['nom_prestation'] as String? ?? '',
      dateSouhaitee: ds,
      heureSouhaitee: j['heure_souhaitee'] as String? ?? '10:00',
      nomClient: j['nom_client'] as String? ?? '',
      telephoneClient: j['telephone_client'] as String? ?? '',
      messageClient: j['message_client'] as String?,
      statut: StatutRendezVous.fromCode(j['statut'] as String?),
      reponseSalon: j['reponse_salon'] as String?,
      createdAt: j['created_at'] != null ? DateTime.tryParse(j['created_at'].toString()) : null,
    );
  }

  VitrineRendezVous copyWith({
    String? id,
    String? vitrineId,
    String? entrepriseId,
    String? prestationId,
    String? nomPrestation,
    DateTime? dateSouhaitee,
    String? heureSouhaitee,
    String? nomClient,
    String? telephoneClient,
    String? messageClient,
    StatutRendezVous? statut,
    String? reponseSalon,
    DateTime? createdAt,
  }) =>
      VitrineRendezVous(
        id: id ?? this.id,
        vitrineId: vitrineId ?? this.vitrineId,
        entrepriseId: entrepriseId ?? this.entrepriseId,
        prestationId: prestationId ?? this.prestationId,
        nomPrestation: nomPrestation ?? this.nomPrestation,
        dateSouhaitee: dateSouhaitee ?? this.dateSouhaitee,
        heureSouhaitee: heureSouhaitee ?? this.heureSouhaitee,
        nomClient: nomClient ?? this.nomClient,
        telephoneClient: telephoneClient ?? this.telephoneClient,
        messageClient: messageClient ?? this.messageClient,
        statut: statut ?? this.statut,
        reponseSalon: reponseSalon ?? this.reponseSalon,
        createdAt: createdAt ?? this.createdAt,
      );
}
