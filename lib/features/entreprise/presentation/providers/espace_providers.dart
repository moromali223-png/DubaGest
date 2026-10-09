import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/core_providers.dart';
import '../../../activites/domain/entities/activite.dart';
import '../../domain/entities/espace_courant.dart';
import 'contexte_providers.dart';

/// Activité et site de travail, mémorisés par utilisateur et par entreprise.
class EspaceCourantController extends Notifier<EspaceCourant> {
  String? _cle;

  @override
  EspaceCourant build() {
    final ctx = ref.watch(contexteActifProvider);
    if (ctx == null) {
      _cle = null;
      return EspaceCourant.global;
    }
    _cle = 'espace:${ctx.userId}:${ctx.entreprise!.id}';
    final memorise = EspaceCourant.decoder(ref.read(sharedPreferencesProvider).getString(_cle!));
    return EspaceCourant.resoudre(ctx, memorise);
  }

  Future<void> choisirActivite(ActiviteCode? activite) =>
      _appliquer(EspaceCourant(activite: activite, perimetreId: state.perimetreId));

  Future<void> choisirSite(String? perimetreId) =>
      _appliquer(EspaceCourant(activite: state.activite, perimetreId: perimetreId));

  Future<void> _appliquer(EspaceCourant souhaite) async {
    final ctx = ref.read(contexteActifProvider);
    if (ctx == null) return;
    state = EspaceCourant.resoudre(ctx, souhaite);
    if (_cle case final cle?) await ref.read(sharedPreferencesProvider).setString(cle, state.encoder());
  }
}

final espaceCourantProvider =
    NotifierProvider<EspaceCourantController, EspaceCourant>(EspaceCourantController.new);
