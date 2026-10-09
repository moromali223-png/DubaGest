import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/permissions/access_decision.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../../entreprise/presentation/providers/espace_providers.dart';
import '../../domain/entities/navigation_model.dart';
import '../../domain/services/navigation_builder.dart';

final navigationBuilderProvider = Provider((ref) => const NavigationBuilder());

final navigationModelProvider = Provider<NavigationModel?>((ref) {
  final ctx = ref.watch(contexteActifProvider);
  if (ctx == null) return null;
  final espace = ref.watch(espaceCourantProvider);
  return ref.watch(navigationBuilderProvider).build(ctx, activite: espace.activite);
});

/// Décision d'accès à un module (garde de route, affichage d'action).
final moduleAccessProvider = Provider.family<AccessDecision, String>((ref, moduleCode) {
  final ctx = ref.watch(contexteActifProvider);
  if (ctx == null) return const AccessDenied(RuleCodes.subscriptionInactive);
  return ctx.accessPolicy().canAccessModule(moduleCode);
});
