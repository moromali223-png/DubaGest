import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/router/routes.dart';
import '../../domain/entities/agenda.dart';
import '../providers/agenda_providers.dart';

/// « Planifier une relance » depuis une fiche (contact, somme due…).
class BoutonRelance extends ConsumerWidget {
  const BoutonRelance({super.key, required this.cibleType, required this.cibleId, this.titre});
  final CibleType cibleType;
  final String cibleId;
  final String? titre;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(droitsAgendaProvider).gerer) return const SizedBox.shrink();
    return OutlinedButton.icon(
      key: const Key('planifier-relance'),
      onPressed: () => context.push(Routes.echeanceNouvelle(cibleType: cibleType, cibleId: cibleId, titre: titre)),
      icon: const Icon(Icons.add_alarm),
      label: Text(context.l10n.agendaPlanFollowUp),
    );
  }
}
