-- ============================================================
-- Quiz Marvel Miss France : base de données
-- À coller tel quel dans Supabase → SQL Editor → Run.
-- Réexécutable sans risque : ne supprime aucune donnée.
--
-- Sécurité : aucune table n'est lisible ni modifiable via l'API
-- publique. Tout passe par les fonctions qz_* ci-dessous :
--   - les joueurs n'obtiennent que les questions (sans les réponses),
--     puis leur propre correction une fois leur quiz envoyé ;
--   - l'espace administrateur exige un jeton obtenu avec le mot de
--     passe, défini une seule fois dans le SQL Editor (voir la fin).
-- ============================================================

-- ------------------------------------------------------------
-- 1. Tables
-- ------------------------------------------------------------

create table if not exists public.qz_config (
  id int primary key default 1 check (id = 1),
  titre text not null default 'Le Quiz',
  intro text not null default '',
  ouvert boolean not null default true,
  email_obligatoire boolean not null default false,
  correction_visible boolean not null default true,
  admin_sel text,
  admin_hash text
);
insert into public.qz_config (id) values (1) on conflict do nothing;

-- Score affiché au joueur à la fin (la correction peut l'être sans lui).
alter table public.qz_config add column if not exists score_visible boolean not null default false;

create table if not exists public.qz_themes (
  id bigint generated always as identity primary key,
  ordre int not null default 0,
  titre text not null,
  intro text not null default ''
);

create table if not exists public.qz_questions (
  id bigint generated always as identity primary key,
  theme_id bigint not null references public.qz_themes (id) on delete cascade,
  ordre int not null default 0,
  type text not null check (type in ('qcm', 'libre')),
  enonce text not null,
  options text[] not null default '{}',
  bonne_option int,                       -- QCM : index (0 = 1re option)
  acceptees text[] not null default '{}', -- libre : réponses acceptées
  points numeric not null default 1 check (points >= 0)
);

create table if not exists public.qz_participations (
  id bigint generated always as identity primary key,
  jeton uuid not null unique default gen_random_uuid(),
  appareil text not null,
  prenom text not null,
  email text not null default '',
  debut timestamptz not null default now(),
  fin timestamptz,                        -- null : quiz en cours
  score numeric not null default 0
);
create index if not exists qz_participations_appareil on public.qz_participations (appareil);
create index if not exists qz_participations_email on public.qz_participations (email) where email <> '';

create table if not exists public.qz_reponses (
  participation_id bigint not null references public.qz_participations (id) on delete cascade,
  question_id bigint not null references public.qz_questions (id) on delete cascade,
  reponse text not null default '',
  auto_correct boolean not null default false, -- correction automatique
  force boolean,                               -- correction manuelle (prime si non nulle)
  maj timestamptz not null default now(),
  primary key (participation_id, question_id)
);

-- Décisions de l'écran « À valider » : réponse ajoutée aux réponses
-- acceptées (accepte = true) ou écartée de la liste (accepte = false).
create table if not exists public.qz_validations (
  id bigint generated always as identity primary key,
  question_id bigint not null references public.qz_questions (id) on delete cascade,
  norm text not null,
  reponse text not null,
  accepte boolean not null,
  date timestamptz not null default now(),
  unique (question_id, norm)
);

create table if not exists public.qz_admin_jetons (
  jeton uuid primary key default gen_random_uuid(),
  expire timestamptz not null default now() + interval '12 hours'
);

alter table public.qz_config enable row level security;
alter table public.qz_themes enable row level security;
alter table public.qz_questions enable row level security;
alter table public.qz_participations enable row level security;
alter table public.qz_reponses enable row level security;
alter table public.qz_validations enable row level security;
alter table public.qz_admin_jetons enable row level security;

do $$
declare r text;
begin
  foreach r in array array['anon', 'authenticated'] loop
    if exists (select 1 from pg_roles where rolname = r) then
      execute format('revoke all on public.qz_config, public.qz_themes, public.qz_questions, public.qz_participations, public.qz_reponses, public.qz_validations, public.qz_admin_jetons from %I', r);
    end if;
  end loop;
end $$;

-- ------------------------------------------------------------
-- 2. Correction automatique
-- ------------------------------------------------------------

-- Normalisation : minuscules, sans accents, tirets, ponctuation ni
-- espaces en trop.
create or replace function public.qz_norm(t text) returns text
language plpgsql immutable as $$
declare s text := lower(coalesce(t, ''));
begin
  s := replace(replace(replace(s, 'œ', 'oe'), 'æ', 'ae'), 'ß', 'ss');
  s := translate(s,
    'àáâãäåāăąçćčďèéêëēėęěìíîïīįłñńňòóôõöøōřśšşťùúûüūůýÿžźż',
    'aaaaaaaaacccdeeeeeeeeiiiiiilnnnooooooorsssstuuuuuuyyzzz');
  s := regexp_replace(s, '[^a-z0-9]+', ' ', 'g');
  return btrim(s);
end $$;

-- Distance de Levenshtein (nombre de lettres à ajouter, enlever ou
-- changer pour passer d'un mot à l'autre).
create or replace function public.qz_lev(a text, b text) returns int
language plpgsql immutable as $$
declare
  la int := length(a); lb int := length(b);
  prev int[]; cur int[]; i int; j int; c int;
begin
  if la = 0 then return lb; end if;
  if lb = 0 then return la; end if;
  prev := array(select generate_series(0, lb));
  for i in 1..la loop
    cur := array[i];
    for j in 1..lb loop
      c := case when substr(a, i, 1) = substr(b, j, 1) then 0 else 1 end;
      cur := cur || least(prev[j + 1] + 1, cur[j] + 1, prev[j] + c);
    end loop;
    prev := cur;
  end loop;
  return prev[lb + 1];
end $$;

-- Un mot donné est-il assez proche du mot attendu ? Fautes tolérées
-- selon la longueur du mot attendu : 0 jusqu'à 3 lettres, 1 de 4 à 7,
-- 2 au-delà. Les nombres doivent être exacts (1998 ≠ 1999).
create or replace function public.qz_mot_ok(r text, a text) returns boolean
language plpgsql immutable as $$
begin
  if r = a then return true; end if;
  if r ~ '[0-9]' or a ~ '[0-9]' then return false; end if;
  return public.qz_lev(r, a) <= case when length(a) < 4 then 0 when length(a) <= 7 then 1 else 2 end;
end $$;

-- Une réponse libre correspond-elle à une réponse acceptée ?
create or replace function public.qz_match(rep text, acc text) returns boolean
language plpgsql immutable as $$
declare
  r text := public.qz_norm(rep); a text := public.qz_norm(acc);
  rw text[]; aw text[]; i int;
begin
  if r = '' or a = '' then return false; end if;
  if r = a or replace(r, ' ', '') = replace(a, ' ', '') then return true; end if;
  rw := string_to_array(r, ' '); aw := string_to_array(a, ' ');
  if cardinality(rw) <> cardinality(aw) then return false; end if;
  for i in 1..cardinality(aw) loop
    if not public.qz_mot_ok(rw[i], aw[i]) then return false; end if;
  end loop;
  return true;
end $$;

-- Correction d'une réponse à une question.
create or replace function public.qz_eval(q public.qz_questions, rep text) returns boolean
language plpgsql stable set search_path = public as $$
begin
  if public.qz_norm(rep) = '' then return false; end if;
  if q.type = 'qcm' then
    return q.bonne_option is not null
      and public.qz_norm(rep) = public.qz_norm(q.options[q.bonne_option + 1]);
  end if;
  return exists (
    select 1 from unnest(q.acceptees || coalesce((select array_agg(v.reponse) from qz_validations v
                                                  where v.question_id = q.id and v.accepte), '{}')) x
    where public.qz_match(rep, x)
  );
end $$;

-- Recalculs.
create or replace function public.qz_recalc_scores() returns void
language sql security definer set search_path = public as $$
  update qz_participations p set score = coalesce((
    select sum(q.points) from qz_reponses r join qz_questions q on q.id = r.question_id
    where r.participation_id = p.id and coalesce(r.force, r.auto_correct)), 0);
$$;

create or replace function public.qz_recalc_question(p_qid bigint) returns void
language plpgsql security definer set search_path = public as $$
declare q qz_questions;
begin
  select * into q from qz_questions where id = p_qid;
  if found then
    update qz_reponses r set auto_correct = qz_eval(q, r.reponse) where r.question_id = p_qid;
  end if;
  perform qz_recalc_scores();
end $$;

-- ------------------------------------------------------------
-- 3. Fonctions joueurs
-- ------------------------------------------------------------

-- Questions du quiz, sans les réponses.
create or replace function public.qz_infos() returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'titre', c.titre, 'intro', c.intro, 'ouvert', c.ouvert,
    'email_obligatoire', c.email_obligatoire,
    'themes', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', t.id, 'titre', t.titre, 'intro', t.intro,
        'questions', coalesce((
          select jsonb_agg(jsonb_build_object(
            'id', q.id, 'type', q.type, 'enonce', q.enonce,
            'options', case when q.type = 'qcm' then to_jsonb(q.options) else '[]'::jsonb end,
            'points', q.points) order by q.ordre, q.id)
          from qz_questions q where q.theme_id = t.id), '[]'::jsonb)
      ) order by t.ordre, t.id)
      from qz_themes t where exists (select 1 from qz_questions q where q.theme_id = t.id)), '[]'::jsonb)
  ) from qz_config c where c.id = 1;
$$;

-- Correction détaillée d'une participation.
create or replace function public.qz_correction(p_pid bigint) returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', q.id, 'theme', t.titre, 'type', q.type, 'enonce', q.enonce,
    'reponse', coalesce(r.reponse, ''),
    'correct', coalesce(r.force, r.auto_correct, false),
    'points', q.points,
    'obtenus', case when coalesce(r.force, r.auto_correct, false) then q.points else 0 end,
    'bonne', case when q.type = 'qcm' then q.options[q.bonne_option + 1] else q.acceptees[1] end
  ) order by t.ordre, t.id, q.ordre, q.id), '[]'::jsonb)
  from qz_questions q join qz_themes t on t.id = q.theme_id
  left join qz_reponses r on r.question_id = q.id and r.participation_id = p_pid;
$$;

create or replace function public.qz_etat(p_jeton uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare p qz_participations; c qz_config;
begin
  select * into p from qz_participations where jeton = p_jeton;
  if not found then return null; end if;
  select * into c from qz_config where id = 1;
  return jsonb_build_object(
    'prenom', p.prenom, 'termine', p.fin is not null,
    'reponses', coalesce((select jsonb_object_agg(r.question_id::text, r.reponse)
                          from qz_reponses r where r.participation_id = p.id), '{}'::jsonb),
    'correction_visible', c.correction_visible,
    'score_visible', c.score_visible,
    'score', case when p.fin is not null and c.score_visible then p.score end,
    'score_max', case when p.fin is not null and c.score_visible then (select coalesce(sum(points), 0) from qz_questions) end,
    'correction', case when p.fin is not null and c.correction_visible then qz_correction(p.id) end
  );
end $$;

create or replace function public.qz_commencer(p_prenom text, p_email text, p_appareil text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  c qz_config; p qz_participations;
  v_prenom text := btrim(coalesce(p_prenom, ''));
  v_email text := lower(btrim(coalesce(p_email, '')));
  v_app text := btrim(coalesce(p_appareil, ''));
begin
  select * into c from qz_config where id = 1;
  if v_app = '' or length(v_app) > 100 then raise exception 'Appareil non reconnu, recharge la page.'; end if;

  -- Même appareil : reprise du quiz en cours, ou affichage du résultat.
  select * into p from qz_participations where appareil = v_app order by id limit 1;
  if found then return jsonb_build_object('jeton', p.jeton); end if;

  if not c.ouvert then raise exception 'Le quiz est fermé.'; end if;
  if v_prenom = '' then raise exception 'Indique ton prénom.'; end if;
  if length(v_prenom) > 60 then raise exception 'Prénom trop long.'; end if;
  if c.email_obligatoire and v_email = '' then raise exception 'Indique ton email.'; end if;
  if v_email <> '' and v_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then raise exception 'Email invalide.'; end if;

  -- Même email : reprise sur un autre appareil si le quiz est en cours.
  if v_email <> '' then
    select * into p from qz_participations where email = v_email order by id limit 1;
    if found then
      if p.fin is null then
        update qz_participations set appareil = v_app where id = p.id;
        return jsonb_build_object('jeton', p.jeton);
      end if;
      raise exception 'Tu as déjà participé à ce quiz avec cet email.';
    end if;
  end if;

  insert into qz_participations (appareil, prenom, email) values (v_app, v_prenom, v_email)
  returning * into p;
  return jsonb_build_object('jeton', p.jeton);
end $$;

-- Enregistre des réponses : p_reponses = { "id question": "réponse" }.
create or replace function public.qz_enregistrer(p_jeton uuid, p_reponses jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare p qz_participations; q qz_questions; k text; v text;
begin
  select * into p from qz_participations where jeton = p_jeton for update;
  if not found then raise exception 'Participation introuvable.'; end if;
  if p.fin is not null then raise exception 'Tes réponses ont déjà été envoyées.'; end if;
  if not (select ouvert from qz_config where id = 1) then raise exception 'Le quiz est fermé.'; end if;
  for k, v in select key, value from jsonb_each_text(coalesce(p_reponses, '{}'::jsonb)) loop
    if k !~ '^[0-9]+$' then continue; end if;
    select * into q from qz_questions where id = k::bigint;
    if not found then continue; end if;
    v := left(btrim(coalesce(v, '')), 500);
    insert into qz_reponses (participation_id, question_id, reponse, auto_correct)
    values (p.id, q.id, v, qz_eval(q, v))
    on conflict (participation_id, question_id) do update
      set reponse = excluded.reponse, auto_correct = excluded.auto_correct, maj = now();
  end loop;
  update qz_participations set score = coalesce((
    select sum(qq.points) from qz_reponses r join qz_questions qq on qq.id = r.question_id
    where r.participation_id = p.id and coalesce(r.force, r.auto_correct)), 0)
  where id = p.id;
  return jsonb_build_object('ok', true);
end $$;

create or replace function public.qz_terminer(p_jeton uuid, p_reponses jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  perform qz_enregistrer(p_jeton, p_reponses);
  update qz_participations set fin = now() where jeton = p_jeton;
  return qz_etat(p_jeton);
end $$;

-- ------------------------------------------------------------
-- 4. Fonctions administrateur
-- ------------------------------------------------------------

create or replace function public.qz_hash(p_sel text, p_mdp text) returns text
language sql immutable as $$
  select encode(sha256(convert_to(p_sel || ':' || p_mdp, 'UTF8')), 'hex');
$$;

-- À exécuter UNE fois dans le SQL Editor (non appelable depuis le site).
create or replace function public.qz_definir_mot_de_passe(p_mdp text) returns text
language plpgsql security definer set search_path = public as $$
declare v_sel text := gen_random_uuid()::text;
begin
  if length(coalesce(p_mdp, '')) < 8 then raise exception 'Au moins 8 caractères.'; end if;
  update qz_config set admin_sel = v_sel, admin_hash = qz_hash(v_sel, p_mdp) where id = 1;
  delete from qz_admin_jetons;
  return 'Mot de passe enregistré.';
end $$;

create or replace function public.qz_admin_connexion(p_mdp text) returns uuid
language plpgsql security definer set search_path = public as $$
declare c qz_config; j uuid;
begin
  select * into c from qz_config where id = 1;
  if c.admin_hash is null then
    raise exception 'Mot de passe administrateur non défini : exécuter qz_definir_mot_de_passe dans Supabase.';
  end if;
  if qz_hash(c.admin_sel, coalesce(p_mdp, '')) <> c.admin_hash then
    perform pg_sleep(1.5);
    raise exception 'Mot de passe incorrect.';
  end if;
  delete from qz_admin_jetons where expire < now();
  insert into qz_admin_jetons default values returning jeton into j;
  return j;
end $$;

create or replace function public.qz_admin_ok(p_jeton uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from qz_admin_jetons where jeton = p_jeton and expire > now()) then
    raise exception 'Session administrateur expirée, reconnecte-toi.';
  end if;
end $$;

-- Tout ce qu'il faut pour l'espace administrateur.
create or replace function public.qz_admin_donnees(p_jeton uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  perform qz_admin_ok(p_jeton);
  return jsonb_build_object(
    'config', (select jsonb_build_object('titre', titre, 'intro', intro, 'ouvert', ouvert,
                 'email_obligatoire', email_obligatoire, 'correction_visible', correction_visible, 'score_visible', score_visible)
               from qz_config where id = 1),
    'themes', coalesce((select jsonb_agg(jsonb_build_object('id', id, 'titre', titre, 'intro', intro)
               order by ordre, id) from qz_themes), '[]'::jsonb),
    'questions', coalesce((select jsonb_agg(jsonb_build_object(
                 'id', q.id, 'theme_id', q.theme_id, 'type', q.type, 'enonce', q.enonce,
                 'options', to_jsonb(q.options), 'bonne_option', q.bonne_option,
                 'acceptees', to_jsonb(q.acceptees), 'points', q.points,
                 'validees', coalesce((select jsonb_agg(v.reponse order by v.id) from qz_validations v
                                       where v.question_id = q.id and v.accepte), '[]'::jsonb))
               order by t.ordre, t.id, q.ordre, q.id)
               from qz_questions q join qz_themes t on t.id = q.theme_id), '[]'::jsonb),
    'participations', coalesce((select jsonb_agg(jsonb_build_object(
                 'id', p.id, 'prenom', p.prenom, 'email', p.email, 'debut', p.debut, 'fin', p.fin,
                 'score', p.score,
                 'reponses', coalesce((select jsonb_object_agg(r.question_id::text, jsonb_build_object(
                     'r', r.reponse, 'auto', r.auto_correct, 'force', r.force,
                     'ok', coalesce(r.force, r.auto_correct)))
                   from qz_reponses r where r.participation_id = p.id), '{}'::jsonb))
               order by p.score desc, p.fin nulls last, p.id)
               from qz_participations p), '[]'::jsonb),
    -- Réponses libres refusées par la correction automatique, regroupées.
    'a_valider', coalesce((select jsonb_agg(g order by g->>'ordre_q', (g->>'nb')::int desc) from (
                 select jsonb_build_object(
                   'question_id', q.id, 'ordre_q', lpad(t.ordre::text, 6, '0') || lpad(t.id::text, 9, '0') || lpad(q.ordre::text, 6, '0') || lpad(q.id::text, 9, '0'),
                   'norm', qz_norm(r.reponse),
                   'reponse', mode() within group (order by r.reponse),
                   'variantes', jsonb_agg(distinct r.reponse),
                   'nb', count(*),
                   'joueurs', jsonb_agg(p.prenom order by p.prenom)) g
                 from qz_reponses r
                 join qz_questions q on q.id = r.question_id and q.type = 'libre'
                 join qz_themes t on t.id = q.theme_id
                 join qz_participations p on p.id = r.participation_id
                 where not r.auto_correct and r.force is null and qz_norm(r.reponse) <> ''
                   and not exists (select 1 from qz_validations v
                                   where v.question_id = q.id and v.norm = qz_norm(r.reponse))
                 group by q.id, t.ordre, t.id, q.ordre, qz_norm(r.reponse)) s), '[]'::jsonb),
    'decisions', coalesce((select jsonb_agg(jsonb_build_object(
                 'id', v.id, 'question_id', v.question_id, 'reponse', v.reponse,
                 'accepte', v.accepte, 'date', v.date) order by v.date desc)
               from qz_validations v), '[]'::jsonb)
  );
end $$;

-- Valider (p_accepte = true) ou écarter (false) une réponse libre.
create or replace function public.qz_admin_decider(p_jeton uuid, p_question bigint, p_reponse text, p_accepte boolean)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform qz_admin_ok(p_jeton);
  if qz_norm(p_reponse) = '' then raise exception 'Réponse vide.'; end if;
  insert into qz_validations (question_id, norm, reponse, accepte)
  values (p_question, qz_norm(p_reponse), btrim(p_reponse), p_accepte)
  on conflict (question_id, norm) do update set reponse = excluded.reponse, accepte = excluded.accepte, date = now();
  perform qz_recalc_question(p_question);
end $$;

create or replace function public.qz_admin_annuler_decision(p_jeton uuid, p_id bigint)
returns void language plpgsql security definer set search_path = public as $$
declare v_q bigint;
begin
  perform qz_admin_ok(p_jeton);
  delete from qz_validations where id = p_id returning question_id into v_q;
  if v_q is not null then perform qz_recalc_question(v_q); end if;
end $$;

-- Correction manuelle d'une réponse : true, false, ou null (automatique).
create or replace function public.qz_admin_forcer(p_jeton uuid, p_participation bigint, p_question bigint, p_valeur boolean)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform qz_admin_ok(p_jeton);
  insert into qz_reponses (participation_id, question_id, reponse, auto_correct, force)
  values (p_participation, p_question, '', false, p_valeur)
  on conflict (participation_id, question_id) do update set force = excluded.force;
  perform qz_recalc_scores();
end $$;

create or replace function public.qz_admin_supprimer(p_jeton uuid, p_participation bigint)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform qz_admin_ok(p_jeton);
  delete from qz_participations where id = p_participation;
end $$;

create or replace function public.qz_admin_reglages(p_jeton uuid, p jsonb)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform qz_admin_ok(p_jeton);
  update qz_config set
    titre = coalesce(nullif(btrim(p->>'titre'), ''), titre),
    intro = coalesce(p->>'intro', intro),
    ouvert = coalesce((p->>'ouvert')::boolean, ouvert),
    email_obligatoire = coalesce((p->>'email_obligatoire')::boolean, email_obligatoire),
    correction_visible = coalesce((p->>'correction_visible')::boolean, correction_visible),
    score_visible = coalesce((p->>'score_visible')::boolean, score_visible)
  where id = 1;
end $$;

-- Import des questions.
-- p_themes = [{ "titre", "intro", "questions": [{ "type", "enonce",
--   "options": [], "bonne_option": 0, "acceptees": [], "points": 1 }] }]
-- p_remplacer = true : supprime d'abord toutes les questions (et les
-- réponses des joueurs à ces questions). false : ajoute à la suite,
-- dans le thème de même titre s'il existe.
create or replace function public.qz_admin_importer(p_jeton uuid, p_themes jsonb, p_remplacer boolean, p_intro text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare th jsonb; qu jsonb; v_tid bigint; v_ordre int; v_n int := 0; v_t int := 0;
begin
  perform qz_admin_ok(p_jeton);
  if p_remplacer then
    delete from qz_themes;
  end if;
  if p_intro is not null and btrim(p_intro) <> '' then
    update qz_config set intro = p_intro where id = 1;
  end if;
  for th in select value from jsonb_array_elements(coalesce(p_themes, '[]'::jsonb)) loop
    select id into v_tid from qz_themes where titre = btrim(th->>'titre') order by id limit 1;
    if v_tid is null then
      insert into qz_themes (titre, intro, ordre)
      values (btrim(th->>'titre'), coalesce(th->>'intro', ''), (select coalesce(max(ordre), 0) + 1 from qz_themes))
      returning id into v_tid;
      v_t := v_t + 1;
    elsif coalesce(th->>'intro', '') <> '' then
      update qz_themes set intro = th->>'intro' where id = v_tid;
    end if;
    select coalesce(max(ordre), 0) into v_ordre from qz_questions where theme_id = v_tid;
    for qu in select value from jsonb_array_elements(coalesce(th->'questions', '[]'::jsonb)) loop
      v_ordre := v_ordre + 1;
      insert into qz_questions (theme_id, ordre, type, enonce, options, bonne_option, acceptees, points)
      values (v_tid, v_ordre, qu->>'type', qu->>'enonce',
              coalesce(array(select jsonb_array_elements_text(qu->'options')), '{}'),
              (qu->>'bonne_option')::int,
              coalesce(array(select jsonb_array_elements_text(qu->'acceptees')), '{}'),
              coalesce((qu->>'points')::numeric, 1));
      v_n := v_n + 1;
    end loop;
    v_tid := null;
  end loop;
  perform qz_recalc_scores();
  return jsonb_build_object('themes', v_t, 'questions', v_n);
end $$;

-- Modifier une question (énoncé, options, réponses, barème).
create or replace function public.qz_admin_maj_question(p_jeton uuid, p_id bigint, p jsonb)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform qz_admin_ok(p_jeton);
  update qz_questions set
    enonce = coalesce(nullif(btrim(p->>'enonce'), ''), enonce),
    options = coalesce(array(select jsonb_array_elements_text(p->'options')), options),
    bonne_option = case when p ? 'bonne_option' then (p->>'bonne_option')::int else bonne_option end,
    acceptees = coalesce(array(select jsonb_array_elements_text(p->'acceptees')), acceptees),
    points = coalesce((p->>'points')::numeric, points)
  where id = p_id;
  perform qz_recalc_question(p_id);
end $$;

create or replace function public.qz_admin_suppr_question(p_jeton uuid, p_id bigint)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform qz_admin_ok(p_jeton);
  delete from qz_questions where id = p_id;
  delete from qz_themes t where not exists (select 1 from qz_questions q where q.theme_id = t.id);
  perform qz_recalc_scores();
end $$;

create or replace function public.qz_admin_maj_theme(p_jeton uuid, p_id bigint, p_titre text, p_intro text)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform qz_admin_ok(p_jeton);
  update qz_themes set titre = coalesce(nullif(btrim(p_titre), ''), titre), intro = coalesce(p_intro, intro)
  where id = p_id;
end $$;

-- ------------------------------------------------------------
-- 5. Droits : seules les fonctions prévues sont appelables depuis
--    le site.
-- ------------------------------------------------------------
do $$
declare f text; r text;
begin
  for f in select p.oid::regprocedure::text from pg_proc p
           where p.pronamespace = 'public'::regnamespace and p.proname like 'qz\_%' loop
    execute format('revoke all on function %s from public', f);
    foreach r in array array['anon', 'authenticated'] loop
      if exists (select 1 from pg_roles where rolname = r) then
        execute format('revoke all on function %s from %I', f, r);
        if f ~ '^qz_(infos|etat|commencer|enregistrer|terminer|admin_[a-z_]+)\(' then
          execute format('grant execute on function %s to %I', f, r);
        end if;
      end if;
    end loop;
  end loop;
end $$;

-- ------------------------------------------------------------
-- 6. Mot de passe administrateur (une seule fois, ici, dans le SQL
--    Editor, jamais dans un fichier du dépôt) :
--
--    select qz_definir_mot_de_passe('ton-mot-de-passe');
-- ------------------------------------------------------------
