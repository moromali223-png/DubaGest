import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/super_admin_entities.dart';
import '../providers/super_admin_providers.dart';
import '../widgets/super_admin_scaffold.dart';

class SuperAdminAuditPage extends ConsumerStatefulWidget {
  const SuperAdminAuditPage({super.key});

  @override
  ConsumerState<SuperAdminAuditPage> createState() => _SuperAdminAuditPageState();
}

class _SuperAdminAuditPageState extends ConsumerState<SuperAdminAuditPage> {
  final _searchCtrl = TextEditingController();
  String _filtreTexte = '';
  String? _filtreAction;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _afficherDetailsLog(AdminAuditLog log) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => Padding(
          padding: const EdgeInsets.all(20),
          child: ListView(
            controller: scrollController,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.security_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          log.action,
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                        ),
                        Text(
                          'ID: ${log.id}',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),
              _buildDetailRow('Date & Heure', log.createdAt.toLocal().toString()),
              _buildDetailRow('Super Admin (initiateur)', log.adminEmail ?? log.adminId ?? 'N/A'),
              _buildDetailRow('Type de cible', log.cibleType),
              _buildDetailRow('Identifiant de la cible', log.cibleId),
              if (log.ipAddress != null) _buildDetailRow('Adresse IP', log.ipAddress!),
              const SizedBox(height: 16),
              const Text(
                'Données & Métadonnées brutes (JSON) :',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SelectableText(
                  const JsonEncoder.withIndent('  ').convert(log.details),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Color(0xFF38BDF8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B), fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Color _couleurAction(String action) {
    if (action.contains('SUSPENSION')) return Colors.red.shade700;
    if (action.contains('REACTIVATION')) return Colors.green.shade700;
    if (action.contains('SPONSOR')) return Colors.amber.shade800;
    if (action.contains('BOOTSTRAP')) return Colors.purple.shade700;
    return const Color(0xFF4338CA);
  }

  @override
  Widget build(BuildContext context) {
    final auditLogsAsync = ref.watch(superAdminAuditLogsProvider);

    return SuperAdminScaffold(
      currentIndex: 3,
      title: 'Journal d\'Audit Central',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
          tooltip: 'Actualiser',
          onPressed: () => ref.invalidate(superAdminAuditLogsProvider),
        ),
      ],
      child: RefreshIndicator(
        onRefresh: () async => ref.invalidate(superAdminAuditLogsProvider),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Bandeau explicatif de conformité
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(18),
                child: const Row(
                  children: [
                    Icon(Icons.verified_user_rounded, color: Color(0xFF6366F1), size: 28),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Traçabilité et Immuabilité DubaGest',
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF0F172A)),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Chaque intervention d\'un Super Administrateur (suspension, attribution sponsorisée, réactivation, etc.) est enregistrée de façon infalsifiable dans app.super_admin_audit_logs.',
                            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Filtres et recherche
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        hintText: 'Rechercher par action, cible ou email admin...',
                        prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B)),
                        suffixIcon: _filtreTexte.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _filtreTexte = '');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                      onChanged: (val) => setState(() => _filtreTexte = val.trim().toLowerCase()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value: _filtreAction,
                        hint: const Text('Toutes actions', style: TextStyle(fontSize: 13)),
                        items: const [
                          DropdownMenuItem(value: null, child: Text('Toutes actions')),
                          DropdownMenuItem(value: 'ATTRIBUTION_ACCES_SPONSORISE', child: Text('Attribution Sponsor')),
                          DropdownMenuItem(value: 'REVOCATION_ACCES_SPONSORISE', child: Text('Révocation Sponsor')),
                          DropdownMenuItem(value: 'SUSPENSION_ENTREPRISE', child: Text('Suspension Entreprise')),
                          DropdownMenuItem(value: 'REACTIVATION_ENTREPRISE', child: Text('Réactivation Entreprise')),
                          DropdownMenuItem(value: 'BOOTSTRAP_SUPER_ADMIN', child: Text('Bootstrap')),
                        ],
                        onChanged: (val) => setState(() => _filtreAction = val),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Liste des logs
              auditLogsAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (err, _) => Center(
                  child: Text('Erreur : $err', style: const TextStyle(color: Colors.red)),
                ),
                data: (logs) {
                  final logsFiltres = logs.where((l) {
                    if (_filtreAction != null && l.action != _filtreAction) {
                      return false;
                    }
                    if (_filtreTexte.isNotEmpty) {
                      final texteMatch = l.action.toLowerCase().contains(_filtreTexte) ||
                          l.cibleId.toLowerCase().contains(_filtreTexte) ||
                          (l.adminEmail?.toLowerCase().contains(_filtreTexte) ?? false) ||
                          l.details.toString().toLowerCase().contains(_filtreTexte);
                      if (!texteMatch) return false;
                    }
                    return true;
                  }).toList();

                  if (logsFiltres.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.history_toggle_off_rounded, size: 56, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            const Text(
                              'Aucune opération d\'audit ne correspond à vos critères.',
                              style: TextStyle(color: Color(0xFF64748B), fontSize: 15),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: logsFiltres.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final log = logsFiltres[index];
                      final couleur = _couleurAction(log.action);
                      final dateFormatted = log.createdAt.toLocal().toString().replaceAll('.000', '');

                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: couleur.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.shield_outlined, color: couleur, size: 20),
                          ),
                          title: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: couleur,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  log.action,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Cible: ${log.cibleType} • ${log.cibleId.length > 8 ? log.cibleId.substring(0, 8) : log.cibleId}...',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              '$dateFormatted • par ${log.adminEmail ?? log.adminId}',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                          onTap: () => _afficherDetailsLog(log),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
