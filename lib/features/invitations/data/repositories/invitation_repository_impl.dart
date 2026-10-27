import '../../../../core/errors/error_mapper.dart';
import '../../domain/entities/invitation.dart';
import '../../domain/repositories/invitation_repository.dart';
import '../datasources/invitation_data_sources.dart';

/// En ligne uniquement : une invitation n'a de valeur que validée par le serveur.
class InvitationRepositoryImpl implements InvitationRepository {
  InvitationRepositoryImpl({
    required InvitationRemoteDataSource remote,
    required InvitationLocalDataSource local,
  })  : _remote = remote,
        _local = local;

  final InvitationRemoteDataSource _remote;
  final InvitationLocalDataSource _local;

  @override
  Future<InvitationCreee> creer({
    required String entrepriseId,
    required String email,
    required String roleCode,
    required List<String> perimetreIds,
  }) =>
      _guard(() async {
        final json = await _remote.creer(
          entrepriseId: entrepriseId,
          email: email,
          roleCode: roleCode,
          perimetreIds: perimetreIds,
        );
        return InvitationCreee(
          id: json['id'] as String,
          token: json['token'] as String,
          expiresAt: DateTime.parse(json['expires_at'] as String),
        );
      });

  @override
  Future<List<Invitation>> lister(String entrepriseId) => _guard(() async {
        final rows = await _remote.lister(entrepriseId);
        return rows
            .map((j) => Invitation(
                  id: j['id'] as String,
                  email: j['email'] as String,
                  roleCode: j['role_code'] as String,
                  statut: InvitationStatut.parse(j['statut'] as String),
                  expiresAt: DateTime.parse(j['expires_at'] as String),
                  createdAt: DateTime.parse(j['created_at'] as String),
                  perimetreIds: [
                    for (final p in (j['invitation_perimetres'] as List? ?? const []).cast<Map<String, dynamic>>())
                      p['perimetre_id'] as String,
                  ],
                ))
            .toList();
      });

  @override
  Future<InvitationCreee> renvoyer(String invitationId) => _guard(() async {
        final json = await _remote.renvoyer(invitationId);
        return InvitationCreee(
          id: json['id'] as String,
          token: json['token'] as String,
          expiresAt: DateTime.parse(json['expires_at'] as String),
        );
      });

  @override
  Future<void> supprimer(String invitationId) => _guard(() => _remote.supprimer(invitationId));

  @override
  Future<void> annuler(String invitationId) => _guard(() => _remote.annuler(invitationId));

  @override
  Future<InvitationApercu> verifier(String token) => _guard(() async {
        final j = await _remote.verifier(token.trim());
        return InvitationApercu(
          statut: InvitationStatut.parse(j['statut'] as String?),
          entrepriseNom: j['entreprise_nom'] as String?,
          roleCode: j['role_code'] as String?,
          emailMasque: j['email_masque'] as String?,
          expiresAt: j['expires_at'] == null ? null : DateTime.parse(j['expires_at'] as String),
        );
      });

  @override
  Future<String> accepter(String token) => _guard(() => _remote.accepter(token.trim()));

  @override
  String? get jetonEnAttente => _local.jeton;

  @override
  Future<void> memoriserJeton(String token) => _local.memoriser(token);

  @override
  Future<void> oublierJeton() => _local.oublier();

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (e, st) {
      throw ErrorMapper.map(e, st);
    }
  }
}
