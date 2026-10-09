-- =============================================================================
-- SOCLE COMMUN — ÉTAPE 9 : PARAMÈTRES DE L'ENTREPRISE
--
--   modes_paiement   modes proposés par l'entreprise (sous-ensemble du
--                    catalogue commun) ; contrôlé à chaque nouveau paiement ;
--   pied_recu        mention imprimée en bas des reçus (figée à l'émission).
--
-- Modifiés en ligne par l'administration (entreprise.manage, politique
-- existante sur entreprises), lus par tous les membres avec la fiche.
-- =============================================================================

alter table public.entreprises
  add column modes_paiement text[] not null
    default array['ESPECES', 'MOBILE_MONEY', 'CARTE', 'VIREMENT', 'CHEQUE', 'AUTRE'],
  -- Jour du dernier changement : un paiement daté de ce jour ou avant (saisi
  -- hors-ligne) avec un mode retiré depuis reste accepté : l'argent a été reçu.
  add column modes_paiement_modifies_le timestamptz,
  add column pied_recu text check (char_length(pied_recu) <= 300);

grant update (modes_paiement, pied_recu) on public.entreprises to authenticated;

create or replace function app.tg_entreprises_parametres()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.modes_paiement is distinct from old.modes_paiement then
    if new.modes_paiement is null
       or exists (select 1 from unnest(new.modes_paiement) c
                  where not exists (select 1 from public.modes_paiement m where m.code = c and m.est_actif)) then
      perform app.refuser('MODES_PAIEMENT_INVALIDES');
    end if;
    -- Sans doublon, dans l'ordre du catalogue.
    select coalesce(array_agg(m.code order by m.ordre), '{}') into new.modes_paiement
    from public.modes_paiement m
    where m.code = any (new.modes_paiement);
    if cardinality(new.modes_paiement) = 0 then
      perform app.refuser('MODES_PAIEMENT_INVALIDES');
    end if;
    new.modes_paiement_modifies_le := now();
  end if;
  new.pied_recu := nullif(trim(new.pied_recu), '');
  return new;
end;
$$;

create trigger entreprises_parametres before update on public.entreprises
  for each row execute function app.tg_entreprises_parametres();

-- Nouveau paiement : le mode doit être proposé par l'entreprise. Les
-- annulations reprennent le mode d'origine et ne sont pas concernées.
create or replace function app.tg_paiements_mode_entreprise()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_entreprise public.entreprises;
begin
  if new.annule_paiement_id is not null then
    return new;
  end if;
  select * into v_entreprise from public.entreprises where id = new.entreprise_id;
  if not (new.mode_code = any (v_entreprise.modes_paiement))
     and (v_entreprise.modes_paiement_modifies_le is null
          or new.date_paiement::date > v_entreprise.modes_paiement_modifies_le::date) then
    perform app.refuser('MODE_PAIEMENT_DESACTIVE', jsonb_build_object('mode', new.mode_code));
  end if;
  return new;
end;
$$;

-- Nommé pour passer après paiements_avant (ordre alphabétique) : le mode
-- d'une annulation est alors déjà celui du paiement d'origine.
create trigger paiements_mode_entreprise before insert on public.paiements
  for each row execute function app.tg_paiements_mode_entreprise();
