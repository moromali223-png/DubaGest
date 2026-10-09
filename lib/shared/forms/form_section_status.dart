import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';

/// État de complétion d'une section de formulaire intelligent.
enum FormSectionStatus {
  /// Section entièrement remplie et valide
  complete,

  /// Section partiellement complétée
  partial,

  /// Section incomplète alors qu'elle contient des informations obligatoires
  error,

  /// Section facultative et non renseignée
  emptyOptional,

  /// Section obligatoire pas encore renseignée
  emptyRequired;

  /// Icône représentative du statut
  IconData get icon => switch (this) {
        FormSectionStatus.complete => Icons.check_circle_rounded,
        FormSectionStatus.partial => Icons.circle,
        FormSectionStatus.error => Icons.error_rounded,
        FormSectionStatus.emptyOptional => Icons.radio_button_unchecked_rounded,
        FormSectionStatus.emptyRequired => Icons.priority_high_rounded,
      };

  /// Couleur associée au statut
  Color get color => switch (this) {
        FormSectionStatus.complete => AppColors.positive,
        FormSectionStatus.partial => AppColors.gold,
        FormSectionStatus.error => AppColors.negative,
        FormSectionStatus.emptyOptional => AppColors.muted,
        FormSectionStatus.emptyRequired => AppColors.warning,
      };

  /// Libellé d'accessibilité et badge textuel court
  String get label => switch (this) {
        FormSectionStatus.complete => 'Complété',
        FormSectionStatus.partial => 'En cours',
        FormSectionStatus.error => 'Requis',
        FormSectionStatus.emptyOptional => 'Facultatif',
        FormSectionStatus.emptyRequired => 'Obligatoire',
      };
}
