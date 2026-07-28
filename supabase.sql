-- Base du mini-sondage : à coller tel quel dans Supabase → SQL Editor → Run.
-- Crée la table des réponses, sécurisée : le public peut uniquement INSÉRER
-- (personne ne peut lire ni modifier via l'API avec la clé anon).

create table if not exists public.reponses (
  id bigint generated always as identity primary key,
  prenom text not null check (char_length(prenom) between 1 and 60),
  q1 text not null check (char_length(q1) between 1 and 120),
  q2 text not null check (char_length(q2) between 1 and 2000),
  cree_le timestamptz not null default now()
);

alter table public.reponses enable row level security;

drop policy if exists "insertion publique" on public.reponses;
create policy "insertion publique" on public.reponses
  for insert to anon
  with check (true);
