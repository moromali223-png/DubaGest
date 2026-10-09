-- =============================================================================
-- COMMERCE : REÇUS DE VENTE
--
-- Chaque vente porte un numéro commercial lisible, distinct de son UUID :
--
--     REC-{AAAAMMJJ}-{POSTE}{SÉQUENCE}      ex. REC-20261007-A001
--
--   • POSTE : lettre attribuée par le serveur à chaque appareil, PAR BOUTIQUE
--     (A, B, … Z, AA, AB…). Deux appareils d'une boutique n'ont jamais la même
--     lettre : chacun numérote seul, hors-ligne, sans collision possible ;
--   • SÉQUENCE : repart à 001 chaque jour, par boutique et par poste ;
--   • unicité garantie par la base : (entreprise, boutique, date, poste, séquence)
--     et (entreprise, boutique, numéro) ;
--   • vente arrivée sans numéro valide (appareil jamais connecté, ancien
--     client, collision anormale) : le serveur la numérote lui-même sur le
--     poste « 0 » (REC-20261007-0001), par un compteur transactionnel. Une
--     vente n'est donc JAMAIS refusée ni perdue à cause de son numéro.
--
-- Aussi : acompte sur une vente à crédit (paiement partiel) et traçabilité de
-- l'annulation (date, auteur). Un reçu n'est jamais supprimé : annulé, il
-- reste consultable avec son statut.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Postes de vente : un appareil = une lettre par boutique
-- -----------------------------------------------------------------------------

create table public.postes_vente (
  id uuid primary key default gen_random_uuid(),
  entreprise_id uuid not null references public.entreprises (id) on delete cascade,
  perimetre_id uuid not null,
  appareil_id text not null check (char_length(appareil_id) between 8 and 64),
  code text not null check (code ~ '^[A-Z]{1,2}$'),
  created_by uuid default auth.uid() references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  unique (perimetre_id, appareil_id),
  unique (perimetre_id, code),
  foreign key (perimetre_id, entreprise_id) references public.perimetres (id, entreprise_id)
);

alter table public.postes_vente enable row level security;
create policy postes_vente_lecture on public.postes_vente for select to authenticated
  using (app.peut(entreprise_id, 'commerce.ventes', 'sales.view', perimetre_id)
         or app.peut(entreprise_id, 'commerce.ventes', 'sales.create', perimetre_id));
revoke all on public.postes_vente from anon, authenticated;
grant select on public.postes_vente to authenticated;
grant all on public.postes_vente to service_role;

-- Compteurs des numéros attribués par le serveur (poste « 0 »). Interne.
create table public.compteurs_recus (
  perimetre_id uuid not null references public.perimetres (id) on delete cascade,
  date_commerciale date not null,
  poste text not null,
  dernier integer not null default 0 check (dernier >= 0),
  primary key (perimetre_id, date_commerciale, poste)
);
alter table public.compteurs_recus enable row level security;
revoke all on public.compteurs_recus from anon, authenticated;
grant all on public.compteurs_recus to service_role;

-- n = 0 → A, 25 → Z, 26 → AA, …
create or replace function app.code_poste(n integer)
returns text
language sql
immutable
set search_path = ''
as $$
  select case when n < 26 then chr(65 + n)
              else chr(65 + n / 26 - 1) || chr(65 + n % 26) end;
$$;

-- Attribue (ou retrouve) la lettre de cet appareil dans la boutique.
-- Renvoie aussi les dernières séquences déjà utilisées par ce poste, pour
-- qu'un appareil réinstallé ou purgé ne réutilise jamais un numéro.
create or replace function public.attribuer_poste_vente(
  p_entreprise_id uuid,
  p_perimetre_id uuid,
  p_appareil_id text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_poste public.postes_vente;
  v_n integer;
begin
  if not app.peut(p_entreprise_id, 'commerce.ventes', 'sales.create', p_perimetre_id) then
    raise exception 'PERMISSION_REFUSEE' using errcode = '42501';
  end if;

  select * into v_poste from public.postes_vente
  where perimetre_id = p_perimetre_id and appareil_id = p_appareil_id;

  if v_poste.id is null then
    -- Verrou de la boutique : deux appareils ne reçoivent jamais la même lettre.
    perform 1 from public.perimetres
    where id = p_perimetre_id and entreprise_id = p_entreprise_id
    for update;
    if not found then
      perform app.refuser('PERIMETRE_INVALIDE');
    end if;
    select count(*) into v_n from public.postes_vente where perimetre_id = p_perimetre_id;
    if v_n >= 702 then
      perform app.refuser('POSTES_EPUISES');
    end if;
    insert into public.postes_vente (entreprise_id, perimetre_id, appareil_id, code)
    values (p_entreprise_id, p_perimetre_id, p_appareil_id, app.code_poste(v_n))
    returning * into v_poste;
  end if;

  return jsonb_build_object(
    'perimetre_id', v_poste.perimetre_id,
    'code', v_poste.code,
    'derniers', coalesce((
      select jsonb_object_agg(to_char(date_commerciale, 'YYYY-MM-DD'), m)
      from (
        select date_commerciale, max(sequence) as m from public.ventes
        where perimetre_id = p_perimetre_id and poste = v_poste.code
          and date_commerciale >= current_date - 3
        group by date_commerciale
      ) s), '{}'::jsonb)
  );
end;
$$;

revoke execute on function public.attribuer_poste_vente(uuid, uuid, text) from public, anon;
grant execute on function public.attribuer_poste_vente(uuid, uuid, text) to authenticated;

-- -----------------------------------------------------------------------------
-- 2. Ventes : numéro, acompte, annulation tracée
-- -----------------------------------------------------------------------------

alter table public.ventes
  add column numero text,
  add column date_commerciale date,
  add column poste text check (poste ~ '^([A-Z]{1,2}|0)$'),
  add column sequence integer check (sequence between 1 and 99999),
  add column montant_paye bigint not null default 0 check (montant_paye >= 0),
  add column annulee_le timestamptz,
  add column annulee_par uuid references public.profiles (id) on delete set null,
  add column annulee_par_nom text;

-- Ventes existantes : numérotées par le serveur, dans l'ordre chronologique.
alter table public.ventes disable trigger user;
with n as (
  select id, date_vente::date as d,
         row_number() over (partition by perimetre_id, date_vente::date order by date_vente, created_at, id) as s
  from public.ventes
)
update public.ventes v
set date_commerciale = n.d,
    poste = '0',
    sequence = n.s,
    numero = 'REC-' || to_char(n.d, 'YYYYMMDD') || '-0' || lpad(n.s::text, 3, '0'),
    montant_paye = case when v.reglement = 'IMMEDIAT' then v.total else 0 end,
    annulee_le = case when v.statut = 'ANNULEE' then v.updated_at end
from n where n.id = v.id;
alter table public.ventes enable trigger user;

insert into public.compteurs_recus (perimetre_id, date_commerciale, poste, dernier)
select perimetre_id, date_commerciale, '0', max(sequence) from public.ventes
group by perimetre_id, date_commerciale;

alter table public.ventes
  alter column numero set not null,
  alter column date_commerciale set not null,
  alter column poste set not null,
  alter column sequence set not null,
  add constraint ventes_numero_unique unique (entreprise_id, perimetre_id, numero),
  add constraint ventes_sequence_unique unique (entreprise_id, perimetre_id, date_commerciale, poste, sequence),
  add constraint ventes_montant_paye_total_check check (montant_paye <= total),
  drop constraint ventes_check,
  add constraint ventes_paiement_check check (
    (reglement = 'IMMEDIAT' and mode_code is not null and paiement_id is not null)
    or (reglement = 'CREDIT' and (montant_paye = 0 or (mode_code is not null and paiement_id is not null))));

create index ventes_recherche_idx on public.ventes (entreprise_id, date_commerciale desc, perimetre_id);

-- Numéro définitif d'une vente (appelé à l'insertion, dans la même transaction).
create or replace function app.numeroter_vente(v public.ventes)
returns public.ventes
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_jour date := (v.date_vente at time zone 'UTC')::date;
  v_valide boolean;
begin
  -- Date commerciale = jour local de l'appareil ; à un jour près de la vente.
  if v.date_commerciale is null or abs(v.date_commerciale - v_jour) > 1 then
    v.date_commerciale := v_jour;
  end if;

  v_valide := v.poste is not null and v.poste <> '0' and v.sequence is not null
    and v.sequence between 1 and 99999
    and exists (select 1 from public.postes_vente p where p.perimetre_id = v.perimetre_id and p.code = v.poste)
    and not exists (select 1 from public.ventes x
                    where x.perimetre_id = v.perimetre_id and x.date_commerciale = v.date_commerciale
                      and x.poste = v.poste and x.sequence = v.sequence);

  if not v_valide then
    -- Numérotation serveur : compteur verrouillé, sans trou ni doublon.
    insert into public.compteurs_recus as c (perimetre_id, date_commerciale, poste, dernier)
    values (v.perimetre_id, v.date_commerciale, '0', 1)
    on conflict (perimetre_id, date_commerciale, poste) do update set dernier = c.dernier + 1
    returning dernier into v.sequence;
    v.poste := '0';
  end if;

  v.numero := 'REC-' || to_char(v.date_commerciale, 'YYYYMMDD') || '-' || v.poste
              || lpad(v.sequence::text, 3, '0');
  return v;
end;
$$;

create or replace function app.tg_ventes_avant()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    perform app.exiger(app.peut(new.entreprise_id, 'commerce.ventes', 'sales.create', new.perimetre_id));
    if not app.lignes_valides(new.lignes, new.entreprise_id) then
      perform app.refuser('LIGNES_INVALIDES');
    end if;
    new.total := app.total_lignes(new.lignes) - new.remise;
    if new.total < 0 then
      perform app.refuser('MONTANT_INVALIDE');
    end if;
    if new.reglement = 'CREDIT' and new.contact_id is null then
      perform app.refuser('CLIENT_REQUIS');
    end if;

    if new.reglement = 'IMMEDIAT' then
      new.montant_paye := new.total;
    elsif coalesce(new.montant_paye, 0) <= 0 then
      new.montant_paye := 0;
    elsif new.montant_paye >= new.total then
      perform app.refuser('MONTANT_INVALIDE');
    end if;

    if new.montant_paye > 0 or new.reglement = 'IMMEDIAT' then
      perform app.exiger(app.peut(new.entreprise_id, 'finances.paiements', 'payments.create', new.perimetre_id));
      -- Vente faite au comptoir : si la caisse a été fermée entre-temps,
      -- le paiement est gardé, sans mouvement de caisse.
      if new.session_id is not null and not exists (
        select 1 from public.caisse_sessions s
        where s.id = new.session_id and s.entreprise_id = new.entreprise_id
          and s.statut = 'OUVERTE' and s.perimetre_id = new.perimetre_id
      ) then
        new.session_id := null;
      end if;
    else
      new.mode_code := null;
      new.session_id := null;
      new.paiement_id := null;
    end if;

    if new.date_vente > now() + interval '1 day' then
      new.date_vente := now();
    end if;
    new.statut := 'VALIDEE';
    new.motif_annulation := null;
    new.annulee_le := null;
    new.annulee_par := null;
    new.annulee_par_nom := null;
    new.created_by := coalesce(auth.uid(), new.created_by);
    new.auteur_nom := (select nom_complet from public.profiles where id = new.created_by);
    new := app.numeroter_vente(new);
    return new;
  end if;

  -- Modification : note, ou annulation d'une vente non encaissée.
  perform app.exiger(app.peut(new.entreprise_id, 'commerce.ventes', 'sales.update', new.perimetre_id));
  if old.statut = 'ANNULEE' then
    perform app.refuser('VENTE_ANNULEE');
  end if;
  if new.statut = 'ANNULEE' and exists (
    select 1 from public.engagements e where e.id = old.id and e.montant_regle > 0
  ) then
    perform app.refuser('VENTE_PAYEE');
  end if;
  if new.statut = 'ANNULEE' then
    new.annulee_le := now();
    new.annulee_par := auth.uid();
    new.annulee_par_nom := (select nom_complet from public.profiles where id = auth.uid());
  end if;
  -- Le reçu émis ne change pas.
  new.numero := old.numero;
  new.date_commerciale := old.date_commerciale;
  new.poste := old.poste;
  new.sequence := old.sequence;
  return new;
end;
$$;

create or replace function app.tg_ventes_apres()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v record;
begin
  perform app.rpc_de_confiance(true);

  if tg_op = 'INSERT' then
    for v in
      select * from jsonb_to_recordset(new.lignes)
        as x(id uuid, produit_id uuid, unite text, facteur numeric, quantite numeric)
    loop
      insert into public.mouvements_stock (id, entreprise_id, perimetre_id, produit_id, type, motif, quantite,
                                           quantite_saisie, unite_saisie, facteur, origine_type, origine_id,
                                           date_mouvement, created_by)
      values (v.id, new.entreprise_id, new.perimetre_id, v.produit_id, 'SORTIE', 'VENTE', v.quantite * v.facteur,
              v.quantite, v.unite, v.facteur, 'VENTE', new.id, new.date_vente, new.created_by);
    end loop;

    if new.total > 0 then
      insert into public.engagements (id, entreprise_id, perimetre_id, sens, contact_id, libelle, montant_total,
                                      date_engagement, origine_type, origine_id)
      values (new.id, new.entreprise_id, new.perimetre_id, 'A_RECEVOIR', new.contact_id, 'Vente ' || new.numero,
              new.total, new.date_vente::date, 'VENTE', new.id);

      -- Payé tout de suite, ou acompte d'une vente à crédit.
      if new.montant_paye > 0 then
        insert into public.paiements (id, entreprise_id, perimetre_id, sens, montant, mode_code, date_paiement,
                                      contact_id, note, session_id, affectations)
        values (new.paiement_id, new.entreprise_id, new.perimetre_id, 'ENTREE', new.montant_paye, new.mode_code,
                least(new.date_vente, now()), new.contact_id, 'Vente ' || new.numero, new.session_id,
                jsonb_build_array(jsonb_build_object(
                  'id', new.paiement_id, 'engagement_id', new.id, 'montant', new.montant_paye)));
      end if;
    end if;
  elsif new.statut = 'ANNULEE' and old.statut <> 'ANNULEE' then
    -- Les produits reviennent en stock ; la somme à recevoir est annulée.
    for v in
      select * from jsonb_to_recordset(new.lignes)
        as x(id uuid, produit_id uuid, unite text, facteur numeric, quantite numeric)
    loop
      insert into public.mouvements_stock (entreprise_id, perimetre_id, produit_id, type, motif, quantite,
                                           quantite_saisie, unite_saisie, facteur, origine_type, origine_id,
                                           note, created_by)
      values (new.entreprise_id, new.perimetre_id, v.produit_id, 'ENTREE', 'RETOUR', v.quantite * v.facteur,
              v.quantite, v.unite, v.facteur, 'VENTE', new.id, new.motif_annulation, auth.uid());
    end loop;
    update public.engagements set statut = 'ANNULE', motif_annulation = new.motif_annulation where id = new.id;
  end if;

  perform app.rpc_de_confiance(false);
  return null;
end;
$$;

grant insert (date_commerciale, poste, sequence, montant_paye) on public.ventes to authenticated;

update app.sync_tables
set colonnes_creation = colonnes_creation || array['date_commerciale', 'poste', 'sequence', 'montant_paye']
where table_name = 'ventes';
