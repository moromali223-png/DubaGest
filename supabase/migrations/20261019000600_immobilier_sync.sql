-- =============================================================================
-- IMMOBILIER — ÉTAPE 9 : SYNCHRONISATION OFFLINE-FIRST & SUPABASE
--
-- Déclaration des tables du module Immobilier dans app.sync_tables pour
-- permettre l'application idempotente des opérations locales via sync_push,
-- le contrôle de version et la résolution de conflits horodatés.
-- =============================================================================

insert into app.sync_tables (table_name, colonnes_creation, colonnes_modification) values
  ('immobilier_biens',
   array[
     'entreprise_id', 'reference', 'nom', 'description', 'type', 'statut',
     'proprietaire_id', 'loyer_reference', 'periodicite', 'depot_garantie_prevu',
     'adresse', 'ville', 'quartier', 'complement_adresse', 'photos',
     'caracteristiques', 'notes'
   ],
   array[
     'reference', 'nom', 'description', 'type', 'statut',
     'proprietaire_id', 'loyer_reference', 'periodicite', 'depot_garantie_prevu',
     'adresse', 'ville', 'quartier', 'complement_adresse', 'photos',
     'caracteristiques', 'notes'
   ]),

  ('immobilier_locataires_profils',
   array[
     'entreprise_id', 'contact_id', 'type_piece_identite', 'numero_piece_identite',
     'date_expiration_piece', 'photos_piece', 'profession', 'employeur',
     'revenu_mensuel', 'personne_a_prevenir_nom', 'personne_a_prevenir_telephone',
     'personne_a_prevenir_lien', 'statut_financier', 'solde_courant',
     'total_loyers_regles', 'total_loyers_impayes', 'notes_solvabilite'
   ],
   array[
     'type_piece_identite', 'numero_piece_identite', 'date_expiration_piece',
     'photos_piece', 'profession', 'employeur', 'revenu_mensuel',
     'personne_a_prevenir_nom', 'personne_a_prevenir_telephone',
     'personne_a_prevenir_lien', 'statut_financier', 'solde_courant',
     'total_loyers_regles', 'total_loyers_impayes', 'notes_solvabilite'
   ]),

  ('immobilier_locations',
   array[
     'entreprise_id', 'bien_id', 'locataire_id', 'proprietaire_id',
     'date_debut', 'date_fin_prevue', 'loyer_mensuel', 'charges_mensuelles',
     'depot_garantie', 'statut', 'etat_lieux_entree', 'etat_lieux_sortie', 'notes'
   ],
   array[
     'date_debut', 'date_fin_prevue', 'date_fin_reelle', 'loyer_mensuel',
     'charges_mensuelles', 'depot_garantie', 'statut', 'motif_cloture',
     'etat_lieux_entree', 'etat_lieux_sortie', 'notes'
   ]),

  ('immobilier_contrats',
   array[
     'entreprise_id', 'reference', 'bien_id', 'proprietaire_id', 'locataire_id',
     'location_id', 'document_id', 'type_bail', 'statut', 'date_debut',
     'date_fin_prevue', 'reconduction_tacite', 'preavis_mois', 'loyer_mensuel',
     'charges_mensuelles', 'terme_paiement_jour', 'terme_type', 'depot_garantie',
     'penalite_retard_pourcent', 'clauses_particulieres', 'date_signature',
     'signe_par_bailleur', 'signe_par_locataire', 'archive_le'
   ],
   array[
     'type_bail', 'statut', 'date_debut', 'date_fin_prevue', 'date_resiliation',
     'motif_resiliation', 'reconduction_tacite', 'preavis_mois', 'loyer_mensuel',
     'charges_mensuelles', 'terme_paiement_jour', 'terme_type', 'depot_garantie',
     'penalite_retard_pourcent', 'clauses_particulieres', 'date_signature',
     'signe_par_bailleur', 'signe_par_locataire', 'archive_le'
   ]),

  ('immobilier_echeances_loyers',
   array[
     'entreprise_id', 'reference', 'contrat_id', 'bien_id', 'locataire_id',
     'proprietaire_id', 'engagement_id', 'quittance_document_id',
     'recu_document_ids', 'periode_mois', 'periode_annee', 'date_emission',
     'date_exigibilite', 'derniere_date_paiement', 'loyer_net', 'charges',
     'total_du', 'montant_regle', 'statut', 'remarques'
   ],
   array[
     'quittance_document_id', 'recu_document_ids', 'derniere_date_paiement',
     'montant_regle', 'statut', 'remarques'
   ])
on conflict (table_name) do update set
  colonnes_creation = excluded.colonnes_creation,
  colonnes_modification = excluded.colonnes_modification;
