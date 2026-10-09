import 'package:flutter/material.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../shared/widgets/state_views.dart';
import '../widgets/module_visuals.dart';

/// Point d'entrée d'un module métier non encore développé. L'accès a déjà été
/// vérifié par la garde de route.
class ModulePlaceholderPage extends StatelessWidget {
  const ModulePlaceholderPage({super.key, required this.moduleCode});
  final String moduleCode;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.module(moduleCode))),
      body: MessageView(
        icon: moduleIcon(moduleCode),
        title: l10n.moduleComingSoonTitle,
        message: l10n.moduleComingSoonMessage,
      ),
    );
  }
}
