-- Nombre d'abonnés Instagram des Miss (affiché sur la page Recrues
-- et dans la fiche). À exécuter dans Supabase → SQL Editor.
alter table public.mf_candidates add column if not exists followers int;

-- Mise à jour (une ligne par Miss, chiffres à relever sur Instagram) :
-- update public.mf_candidates set followers = 12400 where region = 'Alsace';
