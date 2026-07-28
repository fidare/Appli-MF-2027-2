-- ============================================================
-- Appli Miss France 2027 — Les Pronostics
-- Script complet : à coller tel quel dans Supabase → SQL Editor → Run.
-- Réexécutable sans risque (idempotent).
--
-- Sécurité : les tables ne sont PAS lisibles/modifiables via l'API
-- publique. Tout passe par des fonctions qui vérifient le jeton de
-- session du joueur (obtenu via pseudo + PIN). Les PIN ne sont
-- visibles que depuis le dashboard Supabase et la page admin.
-- ============================================================

-- ------------------------------------------------------------
-- 1. Tables
-- ------------------------------------------------------------

create table if not exists public.mf_joueurs (
  id bigint generated always as identity primary key,
  pseudo text not null unique,
  nom_affiche text not null,
  photo_url text,
  pin text not null check (pin ~ '^[0-9]{4}$'),
  jeton uuid not null default gen_random_uuid(),
  est_admin boolean not null default false,
  points_qcm numeric not null default 0
);

create table if not exists public.mf_candidates (
  id bigint generated always as identity primary key,
  nom text not null,
  region text not null,
  age int,
  taille text,
  profession text,
  photo_url text,
  photo_surprise_url text,
  dans_top15 boolean not null default false,
  est_finaliste boolean not null default false,
  rang_final int check (rang_final between 1 and 5)
);

alter table public.mf_candidates
  add column if not exists est_finaliste boolean not null default false;

create table if not exists public.mf_pronostics (
  id bigint generated always as identity primary key,
  joueur_id bigint not null references public.mf_joueurs (id) on delete cascade,
  candidate_id bigint not null references public.mf_candidates (id) on delete cascade,
  statut text check (statut in ('ballotage', 'top15', 'top5')),
  top5 boolean not null default false,
  rang int check (rang between 1 and 5),
  essai int check (essai in (1, 2)),
  modifie_le timestamptz not null default now(),
  unique (joueur_id, candidate_id)
);

-- Migration : les « 5 » deviennent un choix indépendant (parmi le vrai
-- top 15), portés par la colonne booléenne top5.
alter table public.mf_pronostics
  add column if not exists top5 boolean not null default false;
update public.mf_pronostics set top5 = true, statut = 'top15' where statut = 'top5';

create table if not exists public.mf_config (
  id int primary key default 1 check (id = 1),
  phase text not null default 'preparation'
    check (phase in ('preparation', 'selection15', 'top5', 'ordre', 'essais', 'cloture', 'resultats')),
  pts_top15 int not null default 5,
  pts_top5 int not null default 10,
  pts_ordre int not null default 10,
  pts_essai1 int not null default 50,
  pts_essai2 int not null default 25
);

insert into public.mf_config (id) values (1) on conflict (id) do nothing;

-- Dossiers déposés « chez l'huissier » : un joueur qui a scellé sa
-- sélection pour la phase en cours ne peut plus la modifier (tant
-- qu'il ne récupère pas son dossier).
create table if not exists public.mf_validations (
  joueur_id bigint not null references public.mf_joueurs (id) on delete cascade,
  phase text not null,
  valide_le timestamptz not null default now(),
  primary key (joueur_id, phase)
);

-- ------------------------------------------------------------
-- 2. Verrouillage API : RLS activé, aucune policy = aucun accès
--    direct. Seules exceptions : lecture publique de la config
--    (phase + barème) et des candidates (fiches des Miss).
-- ------------------------------------------------------------

alter table public.mf_joueurs enable row level security;
alter table public.mf_candidates enable row level security;
alter table public.mf_pronostics enable row level security;
alter table public.mf_config enable row level security;
alter table public.mf_validations enable row level security;

drop policy if exists "lecture publique config" on public.mf_config;
create policy "lecture publique config" on public.mf_config
  for select to anon using (true);

drop policy if exists "lecture publique candidates" on public.mf_candidates;
create policy "lecture publique candidates" on public.mf_candidates
  for select to anon using (true);

-- Vue publique des joueurs : uniquement pseudo, nom et photo
-- (jamais le PIN ni le jeton — la vue est exécutée avec les droits
-- de son propriétaire, pas ceux du visiteur).
create or replace view public.mf_joueurs_public as
  select id, pseudo, nom_affiche, photo_url from public.mf_joueurs;

grant select on public.mf_joueurs_public to anon;

-- ------------------------------------------------------------
-- 3. Fonctions joueur
-- ------------------------------------------------------------

-- Connexion : pseudo + PIN → jeton de session (vide si PIN faux).
create or replace function public.mf_connexion(p_pseudo text, p_pin text)
returns table (jeton uuid, nom_affiche text, est_admin boolean)
language sql
security definer set search_path = public
as $$
  select j.jeton, j.nom_affiche, j.est_admin
  from mf_joueurs j
  where j.pseudo = p_pseudo and j.pin = p_pin;
$$;

-- Profil du joueur connecté (fige = dossier scellé pour la phase en cours).
drop function if exists public.mf_mon_profil(uuid);
create function public.mf_mon_profil(p_jeton uuid)
returns table (pseudo text, nom_affiche text, photo_url text, est_admin boolean, points_qcm numeric, fige boolean)
language sql
security definer set search_path = public
as $$
  select j.pseudo, j.nom_affiche, j.photo_url, j.est_admin, j.points_qcm,
    exists (select 1 from mf_validations v, mf_config c
            where c.id = 1 and v.joueur_id = j.id and v.phase = c.phase)
  from mf_joueurs j
  where j.jeton = p_jeton;
$$;

-- Mes pronostics.
drop function if exists public.mf_mes_pronostics(uuid);
create function public.mf_mes_pronostics(p_jeton uuid)
returns table (candidate_id bigint, statut text, top5 boolean, rang int, essai int)
language sql
security definer set search_path = public
as $$
  select p.candidate_id, p.statut, p.top5, p.rang, p.essai
  from mf_pronostics p
  join mf_joueurs j on j.id = p.joueur_id
  where j.jeton = p_jeton;
$$;

-- Sélections.
-- Phase 1 (selection15) : p_statut 'top15' (rejoindre l'équipe) ou 'aucun'.
-- Phase 2 (top5) : p_statut 'top5' (parmi le vrai top 15) ou 'aucun'.
create or replace function public.mf_definir_statut(p_jeton uuid, p_candidate bigint, p_statut text)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  v_j bigint;
  v_phase text;
  v_nb int;
begin
  select id into v_j from mf_joueurs where jeton = p_jeton;
  if v_j is null then raise exception 'Session invalide, reconnecte-toi.'; end if;
  if p_statut not in ('top15', 'top5', 'aucun') then
    raise exception 'Statut inconnu.';
  end if;
  select phase into v_phase from mf_config where id = 1;
  if exists (select 1 from mf_validations v where v.joueur_id = v_j and v.phase = v_phase) then
    raise exception 'Ton dossier est scellé chez l''huissier ! Récupère-le pour modifier.';
  end if;

  if v_phase = 'selection15' then
    if p_statut = 'top15' then
      select count(*) into v_nb from mf_pronostics
        where joueur_id = v_j and statut = 'top15';
      if v_nb >= 15 and not exists (select 1 from mf_pronostics
          where joueur_id = v_j and candidate_id = p_candidate and statut = 'top15') then
        raise exception 'Ta liste des 15 est pleine ! Retire quelqu''un d''abord.';
      end if;
      insert into mf_pronostics (joueur_id, candidate_id, statut)
        values (v_j, p_candidate, 'top15')
      on conflict (joueur_id, candidate_id) do update
        set statut = 'top15', modifie_le = now();
    elsif p_statut = 'aucun' then
      update mf_pronostics set statut = null, modifie_le = now()
        where joueur_id = v_j and candidate_id = p_candidate;
    else
      raise exception 'En phase 1, on compose son équipe de 15 !';
    end if;

  elsif v_phase = 'top5' then
    if p_statut = 'top5' then
      if not exists (select 1 from mf_candidates c where c.id = p_candidate and c.dans_top15) then
        raise exception 'Cette Miss n''est plus en lice — choisis parmi les 15 encore en course !';
      end if;
      select count(*) into v_nb from mf_pronostics where joueur_id = v_j and top5;
      if v_nb >= 5 and not exists (select 1 from mf_pronostics
          where joueur_id = v_j and candidate_id = p_candidate and top5) then
        raise exception 'Tu as déjà 5 finalistes ! Retires-en une d''abord.';
      end if;
      insert into mf_pronostics (joueur_id, candidate_id, top5)
        values (v_j, p_candidate, true)
      on conflict (joueur_id, candidate_id) do update
        set top5 = true, modifie_le = now();
    elsif p_statut = 'aucun' then
      update mf_pronostics set top5 = false, modifie_le = now()
        where joueur_id = v_j and candidate_id = p_candidate;
    else
      raise exception 'En phase 2, on choisit ses 5 parmi les 15 en lice !';
    end if;

  else
    raise exception 'Les sélections sont fermées dans la phase actuelle.';
  end if;

  delete from mf_pronostics
    where joueur_id = v_j and candidate_id = p_candidate
      and statut is null and not top5 and rang is null and essai is null;
end;
$$;

-- Classement des 5 finalistes officielles (phase "ordre") :
-- une fois les vraies finalistes annoncées, chaque joueur les classe
-- de 1 (sa Miss France) à 5 — qu'elles soient ou non dans ses listes.
create or replace function public.mf_definir_rang(p_jeton uuid, p_candidate bigint, p_rang int)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  v_j bigint;
  v_phase text;
begin
  select id into v_j from mf_joueurs where jeton = p_jeton;
  if v_j is null then raise exception 'Session invalide, reconnecte-toi.'; end if;
  select phase into v_phase from mf_config where id = 1;
  if v_phase <> 'ordre' then
    raise exception 'Le classement des finalistes n''est pas ouvert en ce moment.';
  end if;
  if exists (select 1 from mf_validations v where v.joueur_id = v_j and v.phase = v_phase) then
    raise exception 'Ton dossier est scellé chez l''huissier ! Récupère-le pour modifier.';
  end if;
  if not exists (select 1 from mf_candidates c where c.id = p_candidate and c.est_finaliste) then
    raise exception 'Seules les 5 finalistes officielles peuvent être classées.';
  end if;
  if p_rang is not null then
    update mf_pronostics set rang = null, modifie_le = now()
      where joueur_id = v_j and rang = p_rang and candidate_id <> p_candidate;
  end if;
  if p_rang is null then
    update mf_pronostics set rang = null, modifie_le = now()
      where joueur_id = v_j and candidate_id = p_candidate;
    delete from mf_pronostics
      where joueur_id = v_j and candidate_id = p_candidate
        and statut is null and not top5 and rang is null and essai is null;
  else
    insert into mf_pronostics (joueur_id, candidate_id, rang)
      values (v_j, p_candidate, p_rang)
    on conflict (joueur_id, candidate_id) do update
      set rang = excluded.rang, modifie_le = now();
  end if;
end;
$$;

-- Essais Miss France : l'essai Nº1 se joue en phase 1 (parmi les 30),
-- l'essai Nº2 en phase 2 (parmi les 15 encore en lice).
-- p_candidate à null pour effacer l'essai p_essai.
create or replace function public.mf_definir_essai(p_jeton uuid, p_essai int, p_candidate bigint)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  v_j bigint;
  v_phase text;
begin
  select id into v_j from mf_joueurs where jeton = p_jeton;
  if v_j is null then raise exception 'Session invalide, reconnecte-toi.'; end if;
  if p_essai not in (1, 2) then raise exception 'Essai inconnu.'; end if;
  select phase into v_phase from mf_config where id = 1;
  if p_essai = 1 and v_phase <> 'selection15' then
    raise exception 'L''essai Nº1 se joue pendant la phase 1 (sélection des 15).';
  end if;
  if p_essai = 2 and v_phase <> 'top5' then
    raise exception 'L''essai Nº2 se joue pendant la phase 2 (choix des 5).';
  end if;
  if exists (select 1 from mf_validations v where v.joueur_id = v_j and v.phase = v_phase) then
    raise exception 'Ton dossier est scellé chez l''huissier ! Récupère-le pour modifier.';
  end if;
  if p_essai = 2 and p_candidate is not null
     and not exists (select 1 from mf_candidates c where c.id = p_candidate and c.dans_top15) then
    raise exception 'Cette Miss n''est plus en lice — choisis parmi les 15 encore en course !';
  end if;
  update mf_pronostics set essai = null, modifie_le = now()
    where joueur_id = v_j and essai = p_essai
      and (p_candidate is null or candidate_id <> p_candidate);
  delete from mf_pronostics
    where joueur_id = v_j and statut is null and not top5 and rang is null and essai is null;
  if p_candidate is not null then
    insert into mf_pronostics (joueur_id, candidate_id, essai)
      values (v_j, p_candidate, p_essai)
    on conflict (joueur_id, candidate_id) do update
      set essai = excluded.essai, modifie_le = now();
  end if;
end;
$$;

-- Sceller sa sélection chez l'huissier (phase en cours, complétude exigée).
create or replace function public.mf_figer(p_jeton uuid)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  v_j bigint;
  v_phase text;
  v_nb int;
begin
  select id into v_j from mf_joueurs where jeton = p_jeton;
  if v_j is null then raise exception 'Session invalide, reconnecte-toi.'; end if;
  select phase into v_phase from mf_config where id = 1;
  if v_phase = 'selection15' then
    select count(*) into v_nb from mf_pronostics
      where joueur_id = v_j and statut = 'top15';
    if v_nb <> 15 then
      raise exception 'L''huissier exige exactement 15 Miss dans ton équipe (tu en as %) !', v_nb;
    end if;
    if not exists (select 1 from mf_pronostics where joueur_id = v_j and essai = 1) then
      raise exception 'L''huissier exige aussi ton essai Miss France Nº1 !';
    end if;
  elsif v_phase = 'top5' then
    select count(*) into v_nb from mf_pronostics where joueur_id = v_j and top5;
    if v_nb <> 5 then
      raise exception 'L''huissier exige 5 finalistes (tu en as %) !', v_nb;
    end if;
    if not exists (select 1 from mf_pronostics where joueur_id = v_j and essai = 2) then
      raise exception 'L''huissier exige aussi ton essai Miss France Nº2 !';
    end if;
  elsif v_phase = 'ordre' then
    select count(*) into v_nb from mf_pronostics
      where joueur_id = v_j and rang is not null;
    if v_nb <> 5 then
      raise exception 'L''huissier exige un rang pour chacune des 5 finalistes (% posé(s)) !', v_nb;
    end if;
  else
    raise exception 'Rien à déposer chez l''huissier dans cette phase.';
  end if;
  insert into mf_validations (joueur_id, phase) values (v_j, v_phase)
    on conflict (joueur_id, phase) do nothing;
end;
$$;

-- Récupérer son dossier chez l'huissier (rouvre les modifications).
create or replace function public.mf_defiger(p_jeton uuid)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  v_j bigint;
  v_phase text;
begin
  select id into v_j from mf_joueurs where jeton = p_jeton;
  if v_j is null then raise exception 'Session invalide, reconnecte-toi.'; end if;
  select phase into v_phase from mf_config where id = 1;
  delete from mf_validations where joueur_id = v_j and phase = v_phase;
end;
$$;

-- Où en sont les autres joueurs (compteurs uniquement, jamais les choix).
drop function if exists public.mf_avancement();
create function public.mf_avancement()
returns table (nom_affiche text, photo_url text, nb_top15 int, nb_top5 int, nb_ordre int, nb_essais int, fige boolean)
language sql
security definer set search_path = public
as $$
  select j.nom_affiche, j.photo_url,
    (select count(*)::int from mf_pronostics p where p.joueur_id = j.id and p.statut = 'top15'),
    (select count(*)::int from mf_pronostics p where p.joueur_id = j.id and p.top5),
    (select count(*)::int from mf_pronostics p where p.joueur_id = j.id and p.rang is not null),
    (select count(*)::int from mf_pronostics p where p.joueur_id = j.id and p.essai is not null),
    exists (select 1 from mf_validations v, mf_config c
            where c.id = 1 and v.joueur_id = j.id and v.phase = c.phase)
  from mf_joueurs j
  order by j.nom_affiche;
$$;

-- Résultats complets + scores de tous les joueurs.
-- Ouvert à tous en phase "resultats" ; aux admins dès la clôture
-- (pour vérifier pendant la soirée).
create or replace function public.mf_resultats(p_jeton uuid default null)
returns json
language plpgsql
security definer set search_path = public
as $$
declare
  cfg record;
  v_admin boolean := false;
  v_out json;
begin
  select * into cfg from mf_config where id = 1;
  if p_jeton is not null then
    select coalesce(est_admin, false) into v_admin from mf_joueurs where jeton = p_jeton;
    v_admin := coalesce(v_admin, false);
  end if;
  if cfg.phase <> 'resultats' and not v_admin then
    raise exception 'Le Benchmark ouvrira quand les résultats seront publiés !';
  end if;

  select json_agg(row_to_json(t)) into v_out
  from (
    select
      j.id, j.pseudo, j.nom_affiche, j.photo_url,
      j.points_qcm as pts_qcm,
      cfg.pts_top15 * (select count(*) from mf_pronostics p join mf_candidates c on c.id = p.candidate_id
        where p.joueur_id = j.id and p.statut = 'top15' and c.dans_top15) as pts_15,
      cfg.pts_top5 * (select count(*) from mf_pronostics p join mf_candidates c on c.id = p.candidate_id
        where p.joueur_id = j.id and p.top5 and c.est_finaliste) as pts_5,
      cfg.pts_ordre * (select count(*) from mf_pronostics p join mf_candidates c on c.id = p.candidate_id
        where p.joueur_id = j.id and p.rang = c.rang_final) as pts_ordre,
      case when exists (select 1 from mf_pronostics p join mf_candidates c on c.id = p.candidate_id
        where p.joueur_id = j.id and p.essai = 1 and c.rang_final = 1) then cfg.pts_essai1 else 0 end as pts_essai1,
      case when exists (select 1 from mf_pronostics p join mf_candidates c on c.id = p.candidate_id
        where p.joueur_id = j.id and p.essai = 2 and c.rang_final = 1) then cfg.pts_essai2 else 0 end as pts_essai2,
      (select coalesce(json_agg(json_build_object(
           'candidate_id', p.candidate_id, 'nom', c.nom, 'region', c.region,
           'statut', p.statut, 'top5', p.top5, 'rang', p.rang, 'essai', p.essai,
           'dans_top15', c.dans_top15, 'est_finaliste', c.est_finaliste, 'rang_final', c.rang_final)), '[]'::json)
         from mf_pronostics p join mf_candidates c on c.id = p.candidate_id
         where p.joueur_id = j.id) as pronostics
    from mf_joueurs j
  ) t;

  return coalesce(v_out, '[]'::json);
end;
$$;

-- ------------------------------------------------------------
-- 4. Fonctions admin (réservées aux joueurs est_admin = true)
-- ------------------------------------------------------------

create or replace function public.mf_admin_id(p_jeton uuid)
returns bigint
language plpgsql
security definer set search_path = public
as $$
declare
  v_j bigint;
begin
  select id into v_j from mf_joueurs where jeton = p_jeton and est_admin;
  if v_j is null then raise exception 'Accès réservé à l''organisateur.'; end if;
  return v_j;
end;
$$;

-- Changer la phase du jeu.
create or replace function public.mf_admin_phase(p_jeton uuid, p_phase text)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  perform mf_admin_id(p_jeton);
  update mf_config set phase = p_phase where id = 1;
end;
$$;

-- Saisir le résultat réel d'une Miss : top 15, finaliste (top 5
-- officiel annoncé pendant la soirée) et rang final 1 à 5.
-- Un rang donné est automatiquement retiré à toute autre Miss.
-- Finaliste implique top 15 ; un rang implique finaliste.
drop function if exists public.mf_admin_resultat(uuid, bigint, boolean, int);
create function public.mf_admin_resultat(p_jeton uuid, p_candidate bigint, p_dans_top15 boolean, p_est_finaliste boolean, p_rang int)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  perform mf_admin_id(p_jeton);
  if p_rang is not null then
    update mf_candidates set rang_final = null
      where rang_final = p_rang and id <> p_candidate;
  end if;
  update mf_candidates
    set dans_top15 = (p_dans_top15 or p_est_finaliste or p_rang is not null),
        est_finaliste = (p_est_finaliste or p_rang is not null),
        rang_final = p_rang
    where id = p_candidate;
end;
$$;

-- Saisir les points QCM d'un joueur.
create or replace function public.mf_admin_qcm(p_jeton uuid, p_joueur bigint, p_points numeric)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  perform mf_admin_id(p_jeton);
  update mf_joueurs set points_qcm = p_points where id = p_joueur;
end;
$$;

-- Liste des joueurs avec PIN et points QCM (page admin).
create or replace function public.mf_admin_joueurs(p_jeton uuid)
returns table (id bigint, pseudo text, nom_affiche text, pin text, points_qcm numeric, est_admin boolean)
language plpgsql
security definer set search_path = public
as $$
begin
  perform mf_admin_id(p_jeton);
  return query select j.id, j.pseudo, j.nom_affiche, j.pin, j.points_qcm, j.est_admin
    from mf_joueurs j order by j.nom_affiche;
end;
$$;

-- Ajouter/mettre à jour une candidate (clé = région).
create or replace function public.mf_admin_candidate_upsert(
  p_jeton uuid, p_nom text, p_region text,
  p_age int default null, p_taille text default null, p_profession text default null,
  p_photo_url text default null, p_photo_surprise_url text default null)
returns bigint
language plpgsql
security definer set search_path = public
as $fn$
declare
  v_id bigint;
begin
  perform mf_admin_id(p_jeton);
  select id into v_id from mf_candidates where region = p_region;
  if v_id is null then
    insert into mf_candidates (nom, region, age, taille, profession, photo_url, photo_surprise_url)
      values (p_nom, p_region, p_age, p_taille, p_profession, p_photo_url, p_photo_surprise_url)
      returning id into v_id;
  else
    update mf_candidates
      set nom = p_nom,
          age = coalesce(p_age, age),
          taille = coalesce(p_taille, taille),
          profession = coalesce(p_profession, profession),
          photo_url = coalesce(p_photo_url, photo_url),
          photo_surprise_url = coalesce(p_photo_surprise_url, photo_surprise_url)
      where id = v_id;
  end if;
  return v_id;
end;
$fn$;

-- Supprimer une candidate (p_candidate) ou tout le plateau (null).
create or replace function public.mf_admin_candidate_supprimer(p_jeton uuid, p_candidate bigint default null)
returns void
language plpgsql
security definer set search_path = public
as $fn$
begin
  perform mf_admin_id(p_jeton);
  if p_candidate is null then
    delete from mf_candidates;
  else
    delete from mf_candidates where id = p_candidate;
  end if;
end;
$fn$;

-- ------------------------------------------------------------
-- 5. Les 11 joueurs (PIN par défaut, modifiables dans Table Editor)
--    Mister Gamboy color = organisateur (est_admin).
-- ------------------------------------------------------------

insert into public.mf_joueurs (pseudo, nom_affiche, pin, est_admin) values
  ('gamboy-color',     'Mister Gamboy color',       '4821', true),
  ('adibou',           'Mister Adibou',             '7365', false),
  ('britney-spears',   'Miss Britney spears',       '1594', false),
  ('kmaro',            'Mister Kmaro',              '6072', false),
  ('loana-petrucciani','Mister Loana Petrucciani',  '2918', false),
  ('mel-b',            'Miss Mel B',                '8437', false),
  ('minikeums',        'Mister Minikeums',          '5140', false),
  ('msn-messenger',    'Miss MSN Messenger',        '9263', false),
  ('nokia-3310',       'Mister Nokia 3310',         '3706', false),
  ('pussycat-dolls',   'Miss Pussycat dolls',       '6589', false),
  ('tokio-hotel',      'Tokio Hotel',               '1428', false)
on conflict (pseudo) do nothing;

-- ------------------------------------------------------------
-- 6. Modèle d'ajout des candidates (à adapter puis exécuter,
--    ou à saisir directement dans Table Editor → mf_candidates)
-- ------------------------------------------------------------
-- insert into public.mf_candidates (nom, region, age, taille, profession, photo_url, photo_surprise_url) values
--   ('Prénom Nom', 'Normandie', 21, '1,75 m', 'Étudiante en droit',
--    'https://vqzvwihmyzjnoqnqrtsv.supabase.co/storage/v1/object/public/photos/normandie.jpg',
--    'https://vqzvwihmyzjnoqnqrtsv.supabase.co/storage/v1/object/public/photos/normandie-surprise.jpg');
