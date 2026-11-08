-- Filtre de la régie : l'organisateur tape un texte (ex. « Martin ») et
-- la galerie de tous les joueurs ne montre plus que les Miss dont le nom
-- ou la région le contient. Vide = pas de filtre.
-- À exécuter une fois dans Supabase → SQL Editor (déjà inclus dans
-- miss-france.sql).
alter table public.mf_config
  add column if not exists filtre text not null default '';

create or replace function public.mf_admin_filtre(p_jeton uuid, p_filtre text)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  perform mf_admin_id(p_jeton);
  update mf_config set filtre = left(trim(coalesce(p_filtre, '')), 60) where id = 1;
end;
$$;
