import 'package:flutter/material.dart';

import '../../../activites/domain/entities/activite.dart';

/// Icônes de présentation des modules (aucune règle d'accès ici).
IconData moduleIcon(String code) => switch (code) {
      'admin.entreprise' => Icons.business_outlined,
      'admin.utilisateurs' => Icons.group_outlined,
      'admin.perimetres' => Icons.storefront_outlined,
      'admin.abonnement' => Icons.workspace_premium_outlined,
      'admin.audit' => Icons.history_rounded,
      'commerce.produits' => Icons.local_offer_outlined,
      'commerce.stock' => Icons.view_in_ar_outlined,
      'commerce.ventes' => Icons.shopping_cart_outlined,
      'commerce.achats' => Icons.receipt_long_outlined,
      'commerce.fournisseurs' => Icons.local_shipping_outlined,
      'commun.contacts' => Icons.people_outline_rounded,
      'commun.documents' => Icons.description_outlined,
      'commun.agenda' => Icons.calendar_today_outlined,
      'commun.rapports' => Icons.bar_chart_rounded,
      'finances.creances' => Icons.request_page_outlined,
      'finances.paiements' => Icons.payments_outlined,
      'finances.caisse' => Icons.credit_card_outlined,
      'services.services' => Icons.category_outlined,
      'services.prestations' => Icons.build_circle_outlined,
      'services.planning' => Icons.calendar_month_rounded,
      'services.devis' => Icons.request_quote_outlined,
      'services.facturation' => Icons.description_outlined,
      'services.rapports' => Icons.analytics_outlined,
      'immobilier.biens' => Icons.home_work_outlined,
      'immobilier.proprietaires' => Icons.badge_outlined,
      'immobilier.locataires' => Icons.family_restroom_outlined,
      'immobilier.locations' => Icons.key_outlined,
      'immobilier.contrats' => Icons.description_outlined,
      'immobilier.loyers' => Icons.account_balance_wallet_outlined,
      _ => Icons.widgets_outlined,
    };

IconData activiteIcon(ActiviteCode a) => switch (a) {
      ActiviteCode.commerce => Icons.storefront,
      ActiviteCode.services => Icons.design_services,
      ActiviteCode.immobilier => Icons.apartment,
    };
