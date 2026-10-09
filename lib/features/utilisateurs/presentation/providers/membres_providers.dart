import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/core_providers.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../data/datasources/membre_data_sources.dart';
import '../../data/repositories/membre_repository_impl.dart';
import '../../domain/entities/membre.dart';
import '../../domain/repositories/membre_repository.dart';
import '../../domain/usecases/gerer_membres.dart';

final membreRepositoryProvider = Provider<MembreRepository>((ref) => MembreRepositoryImpl(
      remote: MembreRemoteDataSource(ref.watch(supabaseClientProvider)),
      local: MembreLocalDataSource(ref.watch(jsonCacheStoreProvider)),
    ));

final listerMembresProvider = Provider((ref) => ListerMembres(ref.watch(membreRepositoryProvider)));
final affecterPerimetreProvider =
    Provider((ref) => AffecterPerimetre(ref.watch(membreRepositoryProvider)));
final retirerPerimetreProvider =
    Provider((ref) => RetirerPerimetre(ref.watch(membreRepositoryProvider)));
final modifierRoleMembreProvider =
    Provider((ref) => ModifierRoleMembre(ref.watch(membreRepositoryProvider)));
final modifierStatutMembreProvider =
    Provider((ref) => ModifierStatutMembre(ref.watch(membreRepositoryProvider)));
final supprimerMembreProvider =
    Provider((ref) => SupprimerMembre(ref.watch(membreRepositoryProvider)));
final verifierAjoutMembreProvider = Provider((ref) => const VerifierAjoutMembre());

final membresProvider = FutureProvider.autoDispose<List<Membre>>((ref) async {
  final ctx = ref.watch(contexteActifProvider);
  if (ctx == null) return const [];
  return ref.watch(listerMembresProvider).call(ctx);
});
