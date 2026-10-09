import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';

/// Modèle générique pour un élément sélectionnable.
class SelectionOption<T> {
  const SelectionOption({
    required this.value,
    required this.title,
    this.subtitle,
    this.icon,
    this.badge,
    this.group,
    this.enabled = true,
  });

  final T value;
  final String title;
  final String? subtitle;
  final IconData? icon;
  final String? badge;
  final String? group;
  final bool enabled;
}

/// Affiche une feuille modale (Bottom Sheet sur mobile, Dialog sur desktop)
/// permettant de rechercher et sélectionner un élément unique avec option Quick Add.
Future<T?> showSearchableSelectionSheet<T>({
  required BuildContext context,
  required String title,
  required List<SelectionOption<T>> options,
  T? selectedValue,
  String searchHint = 'Rechercher...',
  String emptyMessage = 'Aucun résultat',
  String? quickAddLabel,
  VoidCallback? onQuickAdd,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _SearchableSingleSelectionSheet<T>(
      title: title,
      options: options,
      selectedValue: selectedValue,
      searchHint: searchHint,
      emptyMessage: emptyMessage,
      quickAddLabel: quickAddLabel,
      onQuickAdd: onQuickAdd,
    ),
  );
}

/// Affiche une feuille modale pour sélection multiple avec recherche,
/// boutons Tout sélectionner / Tout désélectionner, et compteur d'éléments.
Future<Set<T>?> showMultiSelectSheet<T>({
  required BuildContext context,
  required String title,
  required List<SelectionOption<T>> options,
  Set<T> initialSelection = const {},
  String searchHint = 'Rechercher...',
  String emptyMessage = 'Aucun résultat',
  String validateLabel = 'Valider',
  String? quickAddLabel,
  VoidCallback? onQuickAdd,
}) {
  return showModalBottomSheet<Set<T>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _MultiSelectSheet<T>(
      title: title,
      options: options,
      initialSelection: initialSelection,
      searchHint: searchHint,
      emptyMessage: emptyMessage,
      validateLabel: validateLabel,
      quickAddLabel: quickAddLabel,
      onQuickAdd: onQuickAdd,
    ),
  );
}

class _SearchableSingleSelectionSheet<T> extends StatefulWidget {
  const _SearchableSingleSelectionSheet({
    required this.title,
    required this.options,
    this.selectedValue,
    required this.searchHint,
    required this.emptyMessage,
    this.quickAddLabel,
    this.onQuickAdd,
  });

  final String title;
  final List<SelectionOption<T>> options;
  final T? selectedValue;
  final String searchHint;
  final String emptyMessage;
  final String? quickAddLabel;
  final VoidCallback? onQuickAdd;

  @override
  State<_SearchableSingleSelectionSheet<T>> createState() =>
      _SearchableSingleSelectionSheetState<T>();
}

class _SearchableSingleSelectionSheetState<T>
    extends State<_SearchableSingleSelectionSheet<T>> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<SelectionOption<T>> get _filteredOptions {
    if (_query.trim().isEmpty) return widget.options;
    final words = _query.toLowerCase().trim().split(RegExp(r'\s+'));
    return widget.options.where((opt) {
      final combined = '${opt.title} ${opt.subtitle ?? ''} ${opt.group ?? ''}'.toLowerCase();
      return words.every((w) => combined.contains(w));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredOptions;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Titre
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  if (widget.quickAddLabel != null && widget.onQuickAdd != null)
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onQuickAdd!();
                      },
                      icon: const Icon(Icons.add_rounded, size: 18, color: AppColors.green),
                      label: Text(
                        widget.quickAddLabel!,
                        style: const TextStyle(
                          color: AppColors.green,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // Barre de recherche
            if (widget.options.length > 5) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: TextField(
                  controller: _searchController,
                  autofocus: widget.options.length > 10,
                  decoration: InputDecoration(
                    hintText: widget.searchHint,
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.muted),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],

            const Divider(height: 1, color: AppColors.border),

            // Liste des options
            Flexible(
              child: filtered.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.search_off_rounded, size: 40, color: AppColors.muted),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              widget.emptyMessage,
                              style: const TextStyle(color: AppColors.muted, fontSize: 14),
                            ),
                            if (widget.quickAddLabel != null && widget.onQuickAdd != null) ...[
                              const SizedBox(height: AppSpacing.md),
                              FilledButton.tonalIcon(
                                onPressed: () {
                                  Navigator.pop(context);
                                  widget.onQuickAdd!();
                                },
                                icon: const Icon(Icons.add_rounded),
                                label: Text(widget.quickAddLabel!),
                              ),
                            ],
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: filtered.length,
                      separatorBuilder: (context, index) => const Divider(height: 1, indent: 56, color: AppColors.border),
                      itemBuilder: (context, index) {
                        final opt = filtered[index];
                        final isSelected = widget.selectedValue == opt.value;

                        return ListTile(
                          enabled: opt.enabled,
                          leading: opt.icon != null
                              ? Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFF01226C).withValues(alpha: 0.1)
                                        : AppColors.background,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    opt.icon,
                                    size: 20,
                                    color: isSelected ? const Color(0xFF01226C) : AppColors.ink,
                                  ),
                                )
                              : null,
                          title: Text(
                            opt.title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? const Color(0xFF01226C) : AppColors.ink,
                            ),
                          ),
                          subtitle: opt.subtitle != null
                              ? Text(opt.subtitle!, style: const TextStyle(fontSize: 12.5, color: AppColors.muted))
                              : null,
                          trailing: isSelected
                              ? const Icon(Icons.check_circle_rounded, color: Color(0xFF01226C), size: 22)
                              : opt.badge != null
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.background,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        opt.badge!,
                                        style: const TextStyle(fontSize: 11, color: AppColors.muted),
                                      ),
                                    )
                                  : null,
                          onTap: () => Navigator.pop(context, opt.value),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MultiSelectSheet<T> extends StatefulWidget {
  const _MultiSelectSheet({
    required this.title,
    required this.options,
    required this.initialSelection,
    required this.searchHint,
    required this.emptyMessage,
    required this.validateLabel,
    this.quickAddLabel,
    this.onQuickAdd,
  });

  final String title;
  final List<SelectionOption<T>> options;
  final Set<T> initialSelection;
  final String searchHint;
  final String emptyMessage;
  final String validateLabel;
  final String? quickAddLabel;
  final VoidCallback? onQuickAdd;

  @override
  State<_MultiSelectSheet<T>> createState() => _MultiSelectSheetState<T>();
}

class _MultiSelectSheetState<T> extends State<_MultiSelectSheet<T>> {
  final _searchController = TextEditingController();
  String _query = '';
  late final Set<T> _selected = Set.from(widget.initialSelection);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<SelectionOption<T>> get _filteredOptions {
    if (_query.trim().isEmpty) return widget.options;
    final words = _query.toLowerCase().trim().split(RegExp(r'\s+'));
    return widget.options.where((opt) {
      final combined = '${opt.title} ${opt.subtitle ?? ''} ${opt.group ?? ''}'.toLowerCase();
      return words.every((w) => combined.contains(w));
    }).toList();
  }

  void _selectAll() {
    setState(() {
      for (final opt in _filteredOptions) {
        if (opt.enabled) _selected.add(opt.value);
      }
    });
  }

  void _deselectAll() {
    setState(() {
      for (final opt in _filteredOptions) {
        _selected.remove(opt.value);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredOptions;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header avec Titre et Compteur
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                        if (_selected.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF01226C).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${_selected.length}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF01226C),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (widget.quickAddLabel != null && widget.onQuickAdd != null)
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onQuickAdd!();
                      },
                      icon: const Icon(Icons.add_rounded, size: 18, color: AppColors.green),
                      label: Text(
                        widget.quickAddLabel!,
                        style: const TextStyle(
                          color: AppColors.green,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // Barre de recherche
            if (widget.options.length > 5) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: widget.searchHint,
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.muted),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],

            // Actions rapides Tout sélectionner / Tout désélectionner
            if (widget.options.length > 3)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
                child: Row(
                  children: [
                    TextButton.icon(
                      onPressed: _selectAll,
                      icon: const Icon(Icons.select_all_rounded, size: 16),
                      label: const Text('Tout sélectionner', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: _deselectAll,
                      icon: const Icon(Icons.deselect_rounded, size: 16),
                      label: const Text('Tout désélectionner', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                  ],
                ),
              ),

            const Divider(height: 1, color: AppColors.border),

            // Liste à cases à cocher
            Flexible(
              child: filtered.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: Text(
                          widget.emptyMessage,
                          style: const TextStyle(color: AppColors.muted, fontSize: 14),
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: filtered.length,
                      separatorBuilder: (context, index) => const Divider(height: 1, indent: 56, color: AppColors.border),
                      itemBuilder: (context, index) {
                        final opt = filtered[index];
                        final isSelected = _selected.contains(opt.value);

                        return CheckboxListTile(
                          value: isSelected,
                          enabled: opt.enabled,
                          activeColor: const Color(0xFF01226C),
                          secondary: opt.icon != null
                              ? Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFF01226C).withValues(alpha: 0.1)
                                        : AppColors.background,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    opt.icon,
                                    size: 20,
                                    color: isSelected ? const Color(0xFF01226C) : AppColors.ink,
                                  ),
                                )
                              : null,
                          title: Text(
                            opt.title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? const Color(0xFF01226C) : AppColors.ink,
                            ),
                          ),
                          subtitle: opt.subtitle != null
                              ? Text(opt.subtitle!, style: const TextStyle(fontSize: 12.5, color: AppColors.muted))
                              : null,
                          onChanged: opt.enabled
                              ? (bool? val) {
                                  setState(() {
                                    if (val == true) {
                                      _selected.add(opt.value);
                                    } else {
                                      _selected.remove(opt.value);
                                    }
                                  });
                                }
                              : null,
                        );
                      },
                    ),
            ),

            // Barre de validation
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Annuler'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF01226C),
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.pop(context, _selected),
                      child: Text(
                        _selected.isEmpty
                            ? widget.validateLabel
                            : '${widget.validateLabel} (${_selected.length})',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget affichant un sélecteur intelligent sous forme de chips compactes
/// avec bouton d'ajout qui ouvre le sélecteur modale.
class SmartMultiSelectChips<T> extends StatelessWidget {
  const SmartMultiSelectChips({
    super.key,
    required this.title,
    required this.selectedItems,
    required this.itemLabelBuilder,
    required this.onTapOpenSheet,
    required this.onRemoveItem,
    this.addLabel = '+ Ajouter',
    this.emptyLabel = 'Aucune sélection',
  });

  final String title;
  final Iterable<T> selectedItems;
  final String Function(T item) itemLabelBuilder;
  final VoidCallback onTapOpenSheet;
  final void Function(T item) onRemoveItem;
  final String addLabel;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final list = selectedItems.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink),
            ),
            if (list.isNotEmpty)
              Text(
                '${list.length} sélectionné${list.length > 1 ? 's' : ''}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final item in list)
              InputChip(
                label: Text(itemLabelBuilder(item)),
                selected: true,
                selectedColor: const Color(0xFF01226C).withValues(alpha: 0.1),
                labelStyle: const TextStyle(
                  color: Color(0xFF01226C),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                deleteIcon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF01226C)),
                onDeleted: () => onRemoveItem(item),
                onPressed: onTapOpenSheet,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: const Color(0xFF01226C).withValues(alpha: 0.2)),
                ),
              ),
            ActionChip(
              onPressed: onTapOpenSheet,
              avatar: const Icon(Icons.add_rounded, size: 16, color: AppColors.green),
              label: Text(
                list.isEmpty ? addLabel : '+ Ajouter',
                style: const TextStyle(
                  color: AppColors.green,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              backgroundColor: AppColors.greenSoft,
              side: BorderSide(color: AppColors.green.withValues(alpha: 0.3)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ],
        ),
      ],
    );
  }
}
