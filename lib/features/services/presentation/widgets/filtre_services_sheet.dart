import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../contacts/domain/entities/contact.dart';
import '../../domain/entities/prestation.dart';

/// Vérifie si une prestation correspond à une plage de dates donnée.
bool prestationCorrespondDate(Prestation p, DateTimeRange range) {
  final debut = DateTime(range.start.year, range.start.month, range.start.day);
  final fin = DateTime(range.end.year, range.end.month, range.end.day, 23, 59, 59);

  final dateEch = p.dateEcheanceComplete ?? p.echeanceJour;
  final dateDeb = p.debutPrevu;
  final dateTerm = p.termineLe ?? p.dateTerminaisonReelle;

  if (dateEch != null && !dateEch.isBefore(debut) && !dateEch.isAfter(fin)) return true;
  if (dateDeb != null && !dateDeb.isBefore(debut) && !dateDeb.isAfter(fin)) return true;
  if (dateTerm != null && !dateTerm.isBefore(debut) && !dateTerm.isAfter(fin)) return true;

  return false;
}

/// Affiche la feuille modale de sélection de client pour le filtrage des services.
Future<Contact?> showModalFiltreClient(
  BuildContext context, {
  required List<Contact> contacts,
  String? clientActuelId,
}) {
  return showModalBottomSheet<Contact?>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) => _ModalFiltreClient(
      contacts: contacts,
      clientActuelId: clientActuelId,
    ),
  );
}

class _ModalFiltreClient extends StatefulWidget {
  const _ModalFiltreClient({
    required this.contacts,
    this.clientActuelId,
  });

  final List<Contact> contacts;
  final String? clientActuelId;

  @override
  State<_ModalFiltreClient> createState() => _ModalFiltreClientState();
}

class _ModalFiltreClientState extends State<_ModalFiltreClient> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final filtered = widget.contacts.where((c) {
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      final matchNom = c.nomAffiche.toLowerCase().contains(q);
      final matchTel = c.telephone?.contains(q) ?? false;
      return matchNom || matchTel;
    }).toList();

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(bottom: bottomInset + 16),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.people_alt_rounded, color: AppColors.green, size: 22),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Filtrer par client',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => Navigator.of(sheetCtx(context)).pop(),
                ),
              ],
            ),
          ),

          // Champ de recherche
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: TextField(
              controller: _searchCtrl,
              autofocus: false,
              decoration: InputDecoration(
                hintText: 'Rechercher un client (nom, tél)...',
                prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.green),
                fillColor: AppColors.background,
                filled: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
              ),
              onChanged: (val) => setState(() => _query = val.trim()),
            ),
          ),

          // Option : Tous les clients (réinitialiser)
          ListTile(
            leading: CircleAvatar(
              backgroundColor: widget.clientActuelId == null
                  ? AppColors.green
                  : AppColors.background,
              child: Icon(
                Icons.people_outline_rounded,
                color: widget.clientActuelId == null ? Colors.white : AppColors.muted,
                size: 20,
              ),
            ),
            title: const Text(
              'Tous les clients',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
            subtitle: const Text(
              'Afficher tous les contrats et interventions',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
            trailing: widget.clientActuelId == null
                ? const Icon(Icons.check_circle_rounded, color: AppColors.green)
                : null,
            onTap: () => Navigator.of(sheetCtx(context)).pop(null),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),

          // Liste des clients
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Text(
                        'Aucun client trouvé',
                        style: TextStyle(color: AppColors.muted, fontSize: 13),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const Divider(height: 1, indent: 70),
                    itemBuilder: (context, index) {
                      final c = filtered[index];
                      final isSelected = c.id == widget.clientActuelId;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isSelected ? AppColors.green : AppColors.greenSoft,
                          child: Text(
                            c.nomAffiche.isNotEmpty
                                ? c.nomAffiche.substring(0, 1).toUpperCase()
                                : 'C',
                            style: TextStyle(
                              color: isSelected ? Colors.white : AppColors.green,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        title: Text(
                          c.nomAffiche,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                            fontSize: 14,
                            color: isSelected ? AppColors.green : AppColors.ink,
                          ),
                        ),
                        subtitle: c.telephone != null
                            ? Text(
                                c.telephone!,
                                style: const TextStyle(fontSize: 12, color: AppColors.muted),
                              )
                            : null,
                        trailing: isSelected
                            ? const Icon(Icons.check_circle_rounded, color: AppColors.green)
                            : null,
                        onTap: () => Navigator.of(sheetCtx(context)).pop(c),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  BuildContext sheetCtx(BuildContext ctx) => ctx;
}

/// Ouvre un menu ou boîte de dialogue pour sélectionner un filtre de date rapide ou personnalisé.
Future<void> showDialogueFiltreDate(
  BuildContext context, {
  DateTimeRange? plageActuelle,
  required Function(DateTimeRange? range, String libelle) onChoisi,
}) async {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  await showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Filtrer par date',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.ink),
            ),
            const SizedBox(height: 12),

            // Toutes les dates
            ListTile(
              leading: const Icon(Icons.date_range_rounded, color: AppColors.green),
              title: const Text('Toutes les dates', style: TextStyle(fontWeight: FontWeight.w700)),
              onTap: () {
                Navigator.of(ctx).pop();
                onChoisi(null, 'Toutes les dates');
              },
            ),

            // Aujourd'hui
            ListTile(
              leading: const Icon(Icons.today_rounded, color: AppColors.green),
              title: const Text('Aujourd\'hui', style: TextStyle(fontWeight: FontWeight.w700)),
              onTap: () {
                Navigator.of(ctx).pop();
                onChoisi(DateTimeRange(start: today, end: today), 'Aujourd\'hui');
              },
            ),

            // Cette semaine
            ListTile(
              leading: const Icon(Icons.calendar_view_week_rounded, color: AppColors.green),
              title: const Text('Cette semaine', style: TextStyle(fontWeight: FontWeight.w700)),
              onTap: () {
                Navigator.of(ctx).pop();
                final debutSemaine = today.subtract(Duration(days: today.weekday - 1));
                final finSemaine = debutSemaine.add(const Duration(days: 6));
                onChoisi(DateTimeRange(start: debutSemaine, end: finSemaine), 'Cette semaine');
              },
            ),

            // Ce mois-ci
            ListTile(
              leading: const Icon(Icons.calendar_month_rounded, color: AppColors.green),
              title: const Text('Ce mois-ci', style: TextStyle(fontWeight: FontWeight.w700)),
              onTap: () {
                Navigator.of(ctx).pop();
                final debutMois = DateTime(today.year, today.month, 1);
                final finMois = DateTime(today.year, today.month + 1, 0);
                final nomMois = DateFormat('MMMM yyyy', 'fr_FR').format(today);
                onChoisi(DateTimeRange(start: debutMois, end: finMois), nomMois);
              },
            ),

            // Date précise
            ListTile(
              leading: const Icon(Icons.edit_calendar_rounded, color: Color(0xFF4F46E5)),
              title: const Text('Choisir une date précise...', style: TextStyle(fontWeight: FontWeight.w700)),
              onTap: () async {
                Navigator.of(ctx).pop();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: plageActuelle?.start ?? today,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2035),
                  locale: const Locale('fr', 'FR'),
                );
                if (picked != null) {
                  final lib = DateFormat('d MMM yyyy', 'fr_FR').format(picked);
                  onChoisi(DateTimeRange(start: picked, end: picked), lib);
                }
              },
            ),

            // Période personnalisée
            ListTile(
              leading: const Icon(Icons.date_range_outlined, color: Color(0xFFEA580C)),
              title: const Text('Période / Intervalle de dates...', style: TextStyle(fontWeight: FontWeight.w700)),
              onTap: () async {
                Navigator.of(ctx).pop();
                final range = await showDateRangePicker(
                  context: context,
                  initialDateRange: plageActuelle,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2035),
                  locale: const Locale('fr', 'FR'),
                  saveText: 'Appliquer',
                );
                if (range != null) {
                  final fmt = DateFormat('d MMM', 'fr_FR');
                  final lib = '${fmt.format(range.start)} - ${fmt.format(range.end)}';
                  onChoisi(range, lib);
                }
              },
            ),
          ],
        ),
      ),
    ),
  );
}
