import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/localization/l10n.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../../finances/domain/entities/finances.dart' show ModePaiement;
import '../../../finances/presentation/providers/finances_providers.dart';
import '../../../finances/presentation/widgets/finances_widgets.dart' show FinancesLabels, deviseProvider;
import '../../domain/entities/commerce.dart';
import '../commerce_providers.dart';
import '../widgets/choix_contact.dart';
import '../widgets/commerce_widgets.dart';

/// Statut d'un reçu, tel que le client et l'administrateur le comprennent.
enum StatutRecu { paye, partiel, credit, annule }

/// Ligne du reçu, déjà lisible : « 2 cartons », prix réellement appliqué.
class LigneRecu {
  const LigneRecu({required this.produit, required this.quantite, required this.prixUnitaire, required this.montant});
  final String produit;
  final String quantite;
  final int prixUnitaire;
  final int montant;
}

/// Tout ce qu'affiche un reçu, repris de la vente, de l'entreprise, de la
/// boutique et des paiements : rien n'est ressaisi par le vendeur.
class DonneesRecu {
  const DonneesRecu({
    required this.venteId,
    required this.numero,
    required this.entreprise,
    required this.boutique,
    required this.date,
    required this.lignes,
    required this.sousTotal,
    required this.remise,
    required this.total,
    required this.paye,
    required this.reste,
    required this.statut,
    required this.devise,
    this.logo,
    this.telephone,
    this.adresse,
    this.identifiantFiscal,
    this.registreCommerce,
    this.client,
    this.clientTelephone,
    this.vendeur,
    this.paiement,
    this.annulation,
    this.pied,
  });

  final String venteId;

  /// `null` : numéro attribué par le serveur à la synchronisation.
  final String? numero;
  final String entreprise;
  final Uint8List? logo;
  final String? telephone;
  final String? adresse;
  final String? identifiantFiscal;
  final String? registreCommerce;
  final String boutique;
  final DateTime date;
  final String? client;
  final String? clientTelephone;
  final String? vendeur;
  final List<LigneRecu> lignes;
  final int sousTotal;
  final int remise;
  final int total;
  final int paye;
  final int reste;
  final StatutRecu statut;

  /// Mode de paiement lisible (« Espèces »), ou « Crédit ».
  final String? paiement;

  /// « Annulé le … par … ».
  final String? annulation;
  final String? pied;
  final String devise;

  String get nomFichier => 'Recu-${numero ?? 'vente-${venteId.substring(0, 8)}'}.pdf';
}

/// Statut d'une vente au vu des paiements reçus depuis.
StatutRecu statutRecu(Vente v, int reste) {
  if (v.annulee) return StatutRecu.annule;
  if (reste <= 0) return StatutRecu.paye;
  return reste < v.total ? StatutRecu.partiel : StatutRecu.credit;
}

/// Reste dû aujourd'hui (paiements reçus depuis la vente compris).
int resteVente(WidgetRef ref, Vente v) {
  if (v.annulee) return 0;
  final finances = ref.watch(etatFinancesProvider).value;
  final creance = finances?.engagements.where((e) => e.id == v.id).firstOrNull;
  return creance == null ? v.resteInitial : finances!.suivi(creance).reste;
}

String libelleStatutRecu(AppLocalizations l10n, StatutRecu s) => switch (s) {
      StatutRecu.paye => l10n.rcpStatusValid,
      StatutRecu.partiel => l10n.rcpStatusPartial,
      StatutRecu.credit => l10n.rcpStatusCredit,
      StatutRecu.annule => l10n.rcpStatusCancelled,
    };

String libellePaiementVente(AppLocalizations l10n, Vente v) {
  final mode = v.modePaiement == null ? null : l10n.modePaiement(ModePaiement.parse(v.modePaiement));
  if (v.reglement == ReglementVente.immediat) return mode ?? '';
  return mode == null ? l10n.rcpCredit : '${l10n.rcpCredit} · $mode';
}

/// Assemble le reçu d'une vente (à appeler dans un `build`).
DonneesRecu donneesRecu(BuildContext context, WidgetRef ref, Vente v) {
  final l10n = context.l10n;
  final etat = ref.watch(etatCommerceProvider).value;
  final ctx = ref.watch(contexteActifProvider);
  final profil = ref.watch(profilEntrepriseProvider).value;
  final contact = v.contactId == null
      ? null
      : ref.watch(tousContactsProvider).value?.where((c) => c.id == v.contactId).firstOrNull;
  final reste = resteVente(ref, v);
  final locale = Localizations.localeOf(context).toString();
  return DonneesRecu(
    venteId: v.id,
    numero: v.numero ?? numeroRecu(v.dateCommerciale ?? jourCommercial(v.date), v.poste ?? '', v.sequence ?? 1),
    entreprise: profil?.nom ?? ctx?.entreprise?.nom ?? '',
    logo: ref.watch(logoEntrepriseProvider).value,
    telephone: profil?.telephone,
    adresse: [profil?.adresse, profil?.ville].whereType<String>().where((s) => s.isNotEmpty).join(', '),
    identifiantFiscal: profil?.identifiantFiscal,
    registreCommerce: profil?.registreCommerce,
    boutique: nomBoutique(ref, v.perimetreId),
    date: v.date.toLocal(),
    client: contact?.nomAffiche,
    clientTelephone: contact?.telephone,
    vendeur: v.auteurNom,
    lignes: [
      for (final l in v.lignes)
        LigneRecu(
          produit: etat?.produit(l.produitId)?.nom ?? '—',
          quantite: qteUnite(context, l.quantite, l.unite),
          prixUnitaire: l.prixUnitaire,
          montant: l.montant,
        ),
    ],
    sousTotal: v.sousTotal,
    remise: v.remise,
    total: v.total,
    paye: v.annulee ? v.montantPaye : v.total - reste,
    reste: reste,
    statut: statutRecu(v, reste),
    paiement: libellePaiementVente(l10n, v),
    annulation: !v.annulee
        ? null
        : v.annuleeLe == null
            ? l10n.comCancelled
            : l10n.rcpCancelledInfo(
                DateFormat.yMd(locale).add_Hm().format(v.annuleeLe!.toLocal()), v.annuleeParNom ?? '—'),
    pied: profil?.piedRecu,
    devise: ref.watch(deviseProvider),
  );
}
