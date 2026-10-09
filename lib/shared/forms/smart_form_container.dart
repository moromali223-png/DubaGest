import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';

/// Contrôleur d'orchestration pour formulaire intelligent DUBAGEST.
/// Gère l'accordéon (une seule section ouverte par défaut sur mobile),
/// la navigation entre sections, et le défilement automatique vers les erreurs.
class SmartFormController extends ChangeNotifier {
  SmartFormController({
    int initialOpenIndex = 0,
    this.allowMultipleOpen = false,
  }) {
    if (initialOpenIndex >= 0) {
      _openIndices.add(initialOpenIndex);
    }
  }

  /// Permet d'ouvrir plusieurs sections simultanément (recommandé sur grand écran).
  final bool allowMultipleOpen;

  final Set<int> _openIndices = {};
  final ScrollController scrollController = ScrollController();
  final Map<int, GlobalKey> _sectionKeys = {};

  Set<int> get openIndices => Set.unmodifiable(_openIndices);

  bool isSectionOpen(int index) => _openIndices.contains(index);

  GlobalKey registerSectionKey(int index) {
    return _sectionKeys.putIfAbsent(index, () => GlobalKey());
  }

  void toggleSection(int index) {
    if (_openIndices.contains(index)) {
      _openIndices.remove(index);
    } else {
      if (!allowMultipleOpen) {
        _openIndices.clear();
      }
      _openIndices.add(index);
    }
    notifyListeners();
  }

  void openSection(int index, {bool scrollTo = false}) {
    if (!_openIndices.contains(index)) {
      if (!allowMultipleOpen) {
        _openIndices.clear();
      }
      _openIndices.add(index);
      notifyListeners();
    }
    if (scrollTo) {
      scrollToSection(index);
    }
  }

  void closeSection(int index) {
    if (_openIndices.remove(index)) {
      notifyListeners();
    }
  }

  void openAll(int count) {
    _openIndices.clear();
    for (var i = 0; i < count; i++) {
      _openIndices.add(i);
    }
    notifyListeners();
  }

  void closeAll() {
    _openIndices.clear();
    notifyListeners();
  }

  /// Ouvre la section spécifiée et fait défiler l'écran jusqu'à celle-ci (idéal en cas d'erreur de validation).
  void scrollToSection(int index) {
    openSection(index);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _sectionKeys[index];
      if (key?.currentContext != null) {
        Scrollable.ensureVisible(
          key!.currentContext!,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeInOutCubic,
          alignment: 0.1,
        );
      }
    });
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }
}

/// Conteneur réactif pour formulaires divisés en sections DUBAGEST.
/// Adapte l'affichage sur mobile (1 colonne compacte) et tablette/desktop (support vue 2 colonnes avec résumé latéral).
class SmartFormContainer extends StatelessWidget {
  const SmartFormContainer({
    super.key,
    required this.children,
    this.controller,
    this.sideSummary,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.maxWidth = AppBreakpoints.contentMaxWidth,
  });

  final List<Widget> children;
  final SmartFormController? controller;
  final Widget? sideSummary;
  final EdgeInsetsGeometry padding;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= AppBreakpoints.expanded;

    if (isWide && sideSummary != null) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Padding(
            padding: padding,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Formulaire à gauche
                Expanded(
                  flex: 3,
                  child: SingleChildScrollView(
                    controller: controller?.scrollController,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: children,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                // Résumé dynamique à droite (Sticky)
                Expanded(
                  flex: 2,
                  child: sideSummary!,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: SingleChildScrollView(
          controller: controller?.scrollController,
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    );
  }
}
