-- =============================================================================
-- Migration: Module Bénéfice (Activité COMMERCE)
-- Description: Fonction de calcul analytique et financière de la rentabilité
--              commerciale et de la trésorerie réelle par boutique ou consolidée.
-- Migration: 20261106000100_benefice_commerce.sql
-- =============================================================================

create or replace function app.calculer_benefice_commerce(
  p_entreprise_id uuid,
  p_perimetre_id uuid default null,
  p_date_debut timestamptz default null,
  p_date_fin timestamptz default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_debut timestamptz;
  v_fin timestamptz;
  v_debut_prec timestamptz;
  v_fin_prec timestamptz;
  v_duree interval;

  -- Indicateurs période actuelle
  v_ca_brut bigint := 0;
  v_remises bigint := 0;
  v_ca_net bigint := 0;
  v_nb_ventes integer := 0;
  v_cogs bigint := 0;
  v_nb_lignes_total integer := 0;
  v_nb_lignes_avec_cout integer := 0;
  v_marge_brute bigint := 0;
  v_taux_marge numeric(6, 2) := 0;
  v_depenses_commerciales bigint := 0;
  v_benefice_net bigint := 0;
  v_taux_benefice_net numeric(6, 2) := 0;
  v_taux_couverture_cout numeric(6, 2) := 0;

  -- Indicateurs période précédente (comparaison)
  v_ca_net_prec bigint := 0;
  v_cogs_prec bigint := 0;
  v_marge_brute_prec bigint := 0;
  v_depenses_prec bigint := 0;
  v_benefice_net_prec bigint := 0;

  -- Trésorerie réelle sur la période
  v_total_encaisse bigint := 0;
  v_total_decaisse bigint := 0;
  v_solde_tresorerie bigint := 0;
  v_creances_restantes bigint := 0;

  -- Séries et détails
  v_points_evolution jsonb := '[]'::jsonb;
  v_repartition_depenses jsonb := '[]'::jsonb;
  v_produits_rentabilite jsonb := '[]'::jsonb;
  v_produits_cout_manquant jsonb := '[]'::jsonb;
begin
  -- 1. Contrôle des droits de l'utilisateur
  if not app.peut(p_entreprise_id, 'commerce.ventes', 'sales.view', p_perimetre_id) then
    perform app.refuser('ACCES_REFUSE');
  end if;

  -- 2. Résolution des dates (par défaut : mois en cours)
  v_fin := coalesce(p_date_fin, now());
  v_debut := coalesce(p_date_debut, date_trunc('month', now()));
  if v_debut > v_fin then
    v_debut := date_trunc('month', v_fin);
  end if;

  v_duree := v_fin - v_debut;
  v_fin_prec := v_debut - interval '1 second';
  v_debut_prec := v_fin_prec - v_duree;

  -- 3. Chiffre d'Affaires & Ventes (Période actuelle)
  select
    coalesce(count(*), 0),
    coalesce(sum(v.total + v.remise), 0),
    coalesce(sum(v.remise), 0),
    coalesce(sum(v.total), 0)
  into v_nb_ventes, v_ca_brut, v_remises, v_ca_net
  from public.ventes v
  where v.entreprise_id = p_entreprise_id
    and (p_perimetre_id is null or v.perimetre_id = p_perimetre_id)
    and v.statut = 'VALIDEE'
    and v.date_vente >= v_debut
    and v.date_vente <= v_fin;

  -- Chiffre d'affaires période précédente
  select coalesce(sum(v.total), 0)
  into v_ca_net_prec
  from public.ventes v
  where v.entreprise_id = p_entreprise_id
    and (p_perimetre_id is null or v.perimetre_id = p_perimetre_id)
    and v.statut = 'VALIDEE'
    and v.date_vente >= v_debut_prec
    and v.date_vente <= v_fin_prec;

  -- 4. Coût des Marchandises Vendues (COGS) & Rentabilité par produit
  with lignes_extraites as (
    select
      v.id as vente_id,
      v.date_vente,
      (l->>'produit_id')::uuid as produit_id,
      (l->>'quantite')::numeric as quantite,
      coalesce((l->>'facteur')::numeric, 1) as facteur,
      coalesce((l->>'prix_unitaire')::bigint, 0) as prix_unitaire,
      l->>'unite' as unite_nom
    from public.ventes v,
    jsonb_array_elements(v.lignes) l
    where v.entreprise_id = p_entreprise_id
      and (p_perimetre_id is null or v.perimetre_id = p_perimetre_id)
      and v.statut = 'VALIDEE'
      and v.date_vente >= v_debut
      and v.date_vente <= v_fin
  ),
  lignes_valorisees as (
    select
      le.vente_id,
      le.produit_id,
      p.nom as produit_nom,
      le.quantite,
      le.facteur,
      le.unite_nom,
      (le.quantite * le.facteur) as qte_base,
      (le.quantite * le.prix_unitaire)::bigint as ca_ligne,
      p.prix_achat as cout_unitaire_base,
      case
        when p.prix_achat is not null and p.prix_achat > 0 then
          round(le.quantite * le.facteur * p.prix_achat)::bigint
        else 0
      end as cout_total_ligne,
      (p.prix_achat is not null and p.prix_achat > 0) as cout_renseigne
    from lignes_extraites le
    join public.produits p on p.id = le.produit_id and p.entreprise_id = p_entreprise_id
  )
  select
    coalesce(count(*), 0),
    coalesce(sum(case when cout_renseigne then 1 else 0 end), 0),
    coalesce(sum(cout_total_ligne), 0)
  into v_nb_lignes_total, v_nb_lignes_avec_cout, v_cogs
  from lignes_valorisees;

  -- COGS période précédente
  with lignes_prec as (
    select
      (l->>'quantite')::numeric * coalesce((l->>'facteur')::numeric, 1) as qte_base,
      p.prix_achat as cout_unitaire
    from public.ventes v,
    jsonb_array_elements(v.lignes) l
    join public.produits p on p.id = (l->>'produit_id')::uuid and p.entreprise_id = p_entreprise_id
    where v.entreprise_id = p_entreprise_id
      and (p_perimetre_id is null or v.perimetre_id = p_perimetre_id)
      and v.statut = 'VALIDEE'
      and v.date_vente >= v_debut_prec
      and v.date_vente <= v_fin_prec
  )
  select coalesce(sum(round(qte_base * coalesce(cout_unitaire, 0))::bigint), 0)
  into v_cogs_prec
  from lignes_prec;

  -- Calcul de la marge brute
  v_marge_brute := v_ca_net - v_cogs;
  if v_ca_net > 0 then
    v_taux_marge := round((v_marge_brute::numeric / v_ca_net::numeric) * 100, 2);
  else
    v_taux_marge := 0;
  end if;

  if v_nb_lignes_total > 0 then
    v_taux_couverture_cout := round((v_nb_lignes_avec_cout::numeric / v_nb_lignes_total::numeric) * 100, 2);
  else
    v_taux_couverture_cout := 100;
  end if;

  v_marge_brute_prec := v_ca_net_prec - v_cogs_prec;

  -- 5. Dépenses Commerciales Imputables
  select coalesce(sum(d.montant), 0)
  into v_depenses_commerciales
  from public.depenses d
  where d.entreprise_id = p_entreprise_id
    and (d.activite_code = 'COMMERCE' or d.activite_code is null)
    and d.statut = 'ENREGISTREE'
    and d.deleted_at is null
    and (
      (p_perimetre_id is not null and d.perimetre_id = p_perimetre_id)
      or
      (p_perimetre_id is null)
    )
    and d.date_depense >= v_debut::date
    and d.date_depense <= v_fin::date;

  select coalesce(sum(d.montant), 0)
  into v_depenses_prec
  from public.depenses d
  where d.entreprise_id = p_entreprise_id
    and (d.activite_code = 'COMMERCE' or d.activite_code is null)
    and d.statut = 'ENREGISTREE'
    and d.deleted_at is null
    and (
      (p_perimetre_id is not null and d.perimetre_id = p_perimetre_id)
      or
      (p_perimetre_id is null)
    )
    and d.date_depense >= v_debut_prec::date
    and d.date_depense <= v_fin_prec::date;

  -- Bénéfice net estimé
  v_benefice_net := v_marge_brute - v_depenses_commerciales;
  v_benefice_net_prec := v_marge_brute_prec - v_depenses_prec;

  if v_ca_net > 0 then
    v_taux_benefice_net := round((v_benefice_net::numeric / v_ca_net::numeric) * 100, 2);
  else
    v_taux_benefice_net := 0;
  end if;

  -- 6. Trésorerie Réelle sur la Période
  select coalesce(sum(p.montant), 0)
  into v_total_encaisse
  from public.paiements p
  where p.entreprise_id = p_entreprise_id
    and (p_perimetre_id is null or p.perimetre_id = p_perimetre_id)
    and p.sens = 'ENTREE'
    and p.statut = 'VALIDE'
    and p.date_paiement >= v_debut
    and p.date_paiement <= v_fin;

  select coalesce(sum(p.montant), 0)
  into v_total_decaisse
  from public.paiements p
  where p.entreprise_id = p_entreprise_id
    and (
      (p_perimetre_id is not null and p.perimetre_id = p_perimetre_id)
      or
      (p_perimetre_id is null)
    )
    and p.sens = 'SORTIE'
    and p.statut = 'VALIDE'
    and p.date_paiement >= v_debut
    and p.date_paiement <= v_fin;

  v_solde_tresorerie := v_total_encaisse - v_total_decaisse;

  select coalesce(sum(e.montant_total - e.montant_regle), 0)
  into v_creances_restantes
  from public.engagements e
  where e.entreprise_id = p_entreprise_id
    and (p_perimetre_id is null or e.perimetre_id = p_perimetre_id)
    and e.sens = 'A_RECEVOIR'
    and e.origine_type = 'VENTE'
    and e.statut = 'OUVERT'
    and (e.montant_total - e.montant_regle) > 0;

  -- 7. Répartition des dépenses par catégorie
  select coalesce(jsonb_agg(jsonb_build_object(
    'categorie_id', c.id,
    'categorie_nom', coalesce(c.nom, 'Autres charges'),
    'icone', c.icone,
    'couleur', c.couleur,
    'total', agg.somme,
    'pourcentage', case when v_depenses_commerciales > 0
                        then round((agg.somme::numeric / v_depenses_commerciales::numeric) * 100, 1)
                        else 0 end
  ) order by agg.somme desc), '[]'::jsonb)
  into v_repartition_depenses
  from (
    select d.categorie_id, sum(d.montant) as somme
    from public.depenses d
    where d.entreprise_id = p_entreprise_id
      and (d.activite_code = 'COMMERCE' or d.activite_code is null)
      and d.statut = 'ENREGISTREE'
      and d.deleted_at is null
      and (
        (p_perimetre_id is not null and d.perimetre_id = p_perimetre_id)
        or
        (p_perimetre_id is null)
      )
      and d.date_depense >= v_debut::date
      and d.date_depense <= v_fin::date
    group by d.categorie_id
  ) agg
  join public.depense_categories c on c.id = agg.categorie_id;

  -- 8. Top 15 Produits par Bénéfice / Marge
  with lignes_prod as (
    select
      (l->>'produit_id')::uuid as produit_id,
      sum((l->>'quantite')::numeric * coalesce((l->>'facteur')::numeric, 1)) as qte_totale,
      sum((l->>'quantite')::numeric * coalesce((l->>'prix_unitaire')::bigint, 0))::bigint as ca_total
    from public.ventes v,
    jsonb_array_elements(v.lignes) l
    where v.entreprise_id = p_entreprise_id
      and (p_perimetre_id is null or v.perimetre_id = p_perimetre_id)
      and v.statut = 'VALIDEE'
      and v.date_vente >= v_debut
      and v.date_vente <= v_fin
    group by (l->>'produit_id')::uuid
  ),
  top_produits as (
    select
      p.id as produit_id,
      p.nom,
      p.reference,
      p.unite_base,
      lp.qte_totale as quantite_vendue,
      lp.ca_total as chiffre_affaires,
      p.prix_achat as cout_achat_unitaire,
      round(lp.qte_totale * coalesce(p.prix_achat, 0))::bigint as cogs,
      (lp.ca_total - round(lp.qte_totale * coalesce(p.prix_achat, 0))::bigint) as marge_brute,
      (p.prix_achat is null or p.prix_achat = 0) as cout_manquant
    from lignes_prod lp
    join public.produits p on p.id = lp.produit_id and p.entreprise_id = p_entreprise_id
    order by (lp.ca_total - round(lp.qte_totale * coalesce(p.prix_achat, 0))::bigint) desc
    limit 15
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'produit_id', tp.produit_id,
    'nom', tp.nom,
    'reference', tp.reference,
    'unite_base', tp.unite_base,
    'quantite_vendue', tp.quantite_vendue,
    'chiffre_affaires', tp.chiffre_affaires,
    'cout_achat_unitaire', tp.cout_achat_unitaire,
    'cogs', tp.cogs,
    'marge_brute', tp.marge_brute,
    'cout_manquant', tp.cout_manquant
  )), '[]'::jsonb)
  into v_produits_rentabilite
  from top_produits tp;

  -- 9. Produits vendus sans coût de revient (Top 10)
  with sans_cout as (
    select distinct p.id as produit_id, p.nom, p.reference, p.unite_base
    from (
      select distinct (l->>'produit_id')::uuid as produit_id
      from public.ventes v,
      jsonb_array_elements(v.lignes) l
      where v.entreprise_id = p_entreprise_id
        and (p_perimetre_id is null or v.perimetre_id = p_perimetre_id)
        and v.statut = 'VALIDEE'
        and v.date_vente >= v_debut
        and v.date_vente <= v_fin
    ) x
    join public.produits p on p.id = x.produit_id and p.entreprise_id = p_entreprise_id
    where p.prix_achat is null or p.prix_achat = 0
    limit 10
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'produit_id', sc.produit_id,
    'nom', sc.nom,
    'reference', sc.reference,
    'unite_base', sc.unite_base
  )), '[]'::jsonb)
  into v_produits_cout_manquant
  from sans_cout sc;

  -- 10. Série chronologique (par jour si <= 35 jours, sinon par mois)
  if v_duree <= interval '35 days' then
    select coalesce(jsonb_agg(jsonb_build_object(
      'date', s.jour::date,
      'label', to_char(s.jour, 'DD Mon'),
      'chiffre_affaires', coalesce(v_agg.ca, 0),
      'cogs', coalesce(v_agg.cout, 0),
      'marge_brute', coalesce(v_agg.ca, 0) - coalesce(v_agg.cout, 0),
      'depenses', coalesce(d_agg.dep, 0),
      'benefice_net', (coalesce(v_agg.ca, 0) - coalesce(v_agg.cout, 0)) - coalesce(d_agg.dep, 0)
    ) order by s.jour), '[]'::jsonb)
    into v_points_evolution
    from generate_series(v_debut::date, v_fin::date, interval '1 day') s(jour)
    left join (
      with lv as (
        select
          v.date_vente::date as jour,
          v.total as total_vente,
          (l->>'quantite')::numeric * coalesce((l->>'facteur')::numeric, 1) as qte_base,
          p.prix_achat
        from public.ventes v,
        jsonb_array_elements(v.lignes) l
        left join public.produits p on p.id = (l->>'produit_id')::uuid and p.entreprise_id = p_entreprise_id
        where v.entreprise_id = p_entreprise_id
          and (p_perimetre_id is null or v.perimetre_id = p_perimetre_id)
          and v.statut = 'VALIDEE'
          and v.date_vente >= v_debut
          and v.date_vente <= v_fin
      )
      select
        jour,
        coalesce(sum(distinct total_vente), sum(total_vente)) as ca,
        coalesce(sum(round(qte_base * coalesce(prix_achat, 0))::bigint), 0) as cout
      from lv
      group by jour
    ) v_agg on v_agg.jour = s.jour::date
    left join (
      select
        d.date_depense as jour,
        sum(d.montant) as dep
      from public.depenses d
      where d.entreprise_id = p_entreprise_id
        and (d.activite_code = 'COMMERCE' or d.activite_code is null)
        and d.statut = 'ENREGISTREE'
        and d.deleted_at is null
        and (
          (p_perimetre_id is not null and d.perimetre_id = p_perimetre_id)
          or
          (p_perimetre_id is null)
        )
        and d.date_depense >= v_debut::date
        and d.date_depense <= v_fin::date
      group by d.date_depense
    ) d_agg on d_agg.jour = s.jour::date;
  else
    -- Agrégation par mois
    select coalesce(jsonb_agg(jsonb_build_object(
      'date', s.mois::date,
      'label', to_char(s.mois, 'Mon YYYY'),
      'chiffre_affaires', coalesce(v_agg.ca, 0),
      'cogs', coalesce(v_agg.cout, 0),
      'marge_brute', coalesce(v_agg.ca, 0) - coalesce(v_agg.cout, 0),
      'depenses', coalesce(d_agg.dep, 0),
      'benefice_net', (coalesce(v_agg.ca, 0) - coalesce(v_agg.cout, 0)) - coalesce(d_agg.dep, 0)
    ) order by s.mois), '[]'::jsonb)
    into v_points_evolution
    from generate_series(date_trunc('month', v_debut), date_trunc('month', v_fin), interval '1 month') s(mois)
    left join (
      with lv as (
        select
          date_trunc('month', v.date_vente) as mois,
          v.total as total_vente,
          (l->>'quantite')::numeric * coalesce((l->>'facteur')::numeric, 1) as qte_base,
          p.prix_achat
        from public.ventes v,
        jsonb_array_elements(v.lignes) l
        left join public.produits p on p.id = (l->>'produit_id')::uuid and p.entreprise_id = p_entreprise_id
        where v.entreprise_id = p_entreprise_id
          and (p_perimetre_id is null or v.perimetre_id = p_perimetre_id)
          and v.statut = 'VALIDEE'
          and v.date_vente >= v_debut
          and v.date_vente <= v_fin
      )
      select
        mois,
        coalesce(sum(distinct total_vente), sum(total_vente)) as ca,
        coalesce(sum(round(qte_base * coalesce(prix_achat, 0))::bigint), 0) as cout
      from lv
      group by mois
    ) v_agg on v_agg.mois = s.mois
    left join (
      select
        date_trunc('month', d.date_depense::timestamptz) as mois,
        sum(d.montant) as dep
      from public.depenses d
      where d.entreprise_id = p_entreprise_id
        and (d.activite_code = 'COMMERCE' or d.activite_code is null)
        and d.statut = 'ENREGISTREE'
        and d.deleted_at is null
        and (
          (p_perimetre_id is not null and d.perimetre_id = p_perimetre_id)
          or
          (p_perimetre_id is null)
        )
        and d.date_depense >= v_debut::date
        and d.date_depense <= v_fin::date
      group by date_trunc('month', d.date_depense::timestamptz)
    ) d_agg on d_agg.mois = s.mois;
  end if;

  -- 11. Construction du résultat JSON final
  return jsonb_build_object(
    'succes', true,
    'entreprise_id', p_entreprise_id,
    'perimetre_id', p_perimetre_id,
    'date_debut', v_debut,
    'date_fin', v_fin,
    'kpi', jsonb_build_object(
      'chiffre_affaires_brut', v_ca_brut,
      'remises', v_remises,
      'chiffre_affaires_net', v_ca_net,
      'chiffre_affaires_precedent', v_ca_net_prec,
      'nombre_ventes', v_nb_ventes,
      'cogs', v_cogs,
      'cogs_precedent', v_cogs_prec,
      'marge_brute', v_marge_brute,
      'marge_brute_precedente', v_marge_brute_prec,
      'taux_marge', v_taux_marge,
      'depenses_commerciales', v_depenses_commerciales,
      'depenses_precedentes', v_depenses_prec,
      'benefice_net_estime', v_benefice_net,
      'benefice_net_precedent', v_benefice_net_prec,
      'taux_benefice_net', v_taux_benefice_net,
      'taux_couverture_cout', v_taux_couverture_cout,
      'lignes_total', v_nb_lignes_total,
      'lignes_avec_cout', v_nb_lignes_avec_cout
    ),
    'tresorerie', jsonb_build_object(
      'total_encaisse', v_total_encaisse,
      'total_decaisse', v_total_decaisse,
      'solde_net_flux', v_solde_tresorerie,
      'creances_clients_restantes', v_creances_restantes
    ),
    'repartition_depenses', v_repartition_depenses,
    'produits_rentabilite', v_produits_rentabilite,
    'produits_cout_manquant', v_produits_cout_manquant,
    'evolution', v_points_evolution
  );
end;
$$;

-- Exposer dans public pour appel direct par Supabase client (RPC)
create or replace function public.calculer_benefice_commerce(
  p_entreprise_id uuid,
  p_perimetre_id uuid default null,
  p_date_debut timestamptz default null,
  p_date_fin timestamptz default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  return app.calculer_benefice_commerce(
    p_entreprise_id => p_entreprise_id,
    p_perimetre_id => p_perimetre_id,
    p_date_debut => p_date_debut,
    p_date_fin => p_date_fin
  );
end;
$$;

revoke all on function public.calculer_benefice_commerce(uuid, uuid, timestamptz, timestamptz) from anon;
grant execute on function public.calculer_benefice_commerce(uuid, uuid, timestamptz, timestamptz) to authenticated, service_role;
