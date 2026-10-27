import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/core_providers.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../data/datasources/invitation_data_sources.dart';
import '../../data/repositories/invitation_repository_impl.dart';
import '../../domain/entities/invitation.dart';
import '../../domain/repositories/invitation_repository.dart';
import '../../domain/usecases/gerer_invitations.dart';

final invitationRepositoryProvider = Provider<InvitationRepository>((ref) => InvitationRepositoryImpl(
      remote: InvitationRemoteDataSource(ref.watch(supabaseClientProvider)),
      local: InvitationLocalDataSource(ref.watch(sharedPreferencesProvider)),
    ));

final creerInvitationProvider = Provider((ref) => CreerInvitation(ref.watch(invitationRepositoryProvider)));
final renvoyerInvitationProvider =
    Provider((ref) => RenvoyerInvitation(ref.watch(invitationRepositoryProvider)));
final supprimerInvitationProvider =
    Provider((ref) => SupprimerInvitation(ref.watch(invitationRepositoryProvider)));
final listerInvitationsProvider =
    Provider((ref) => ListerInvitations(ref.watch(invitationRepositoryProvider)));
final annulerInvitationProvider =
    Provider((ref) => AnnulerInvitation(ref.watch(invitationRepositoryProvider)));
final verifierInvitationProvider =
    Provider((ref) => VerifierInvitation(ref.watch(invitationRepositoryProvider)));
final accepterInvitationProvider =
    Provider((ref) => AccepterInvitation(ref.watch(invitationRepositoryProvider)));

/// Jeton d'invitation en attente (lien ouvert avant connexion). Le routeur
/// s'en sert pour reprendre le parcours « Rejoindre » après authentification.
class InvitationEnAttente extends Notifier<String?> {
  @override
  String? build() => ref.watch(invitationRepositoryProvider).jetonEnAttente;

  Future<void> memoriser(String token) async {
    final t = token.trim();
    if (t.isEmpty) return;
    await ref.read(invitationRepositoryProvider).memoriserJeton(t);
    state = t;
  }

  Future<void> oublier() async {
    await ref.read(invitationRepositoryProvider).oublierJeton();
    state = null;
  }
}

final invitationEnAttenteProvider =
    NotifierProvider<InvitationEnAttente, String?>(InvitationEnAttente.new);

final invitationsProvider = FutureProvider.autoDispose<List<Invitation>>((ref) async {
  final ctx = ref.watch(contexteActifProvider);
  if (ctx == null) return const [];
  return ref.watch(listerInvitationsProvider).call(ctx);
});

final apercuInvitationProvider =
    FutureProvider.autoDispose.family<InvitationApercu, String>((ref, token) {
  return ref.watch(verifierInvitationProvider).call(token);
});
