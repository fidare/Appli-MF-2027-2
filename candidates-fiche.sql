-- Fiche détaillée des candidates : à exécuter une fois dans
-- Supabase → SQL Editor (déjà inclus dans miss-france.sql).
alter table public.mf_candidates
  add column if not exists poids text,
  add column if not exists mensurations text,
  add column if not exists photos text[] not null default '{}',
  add column if not exists instagram text,
  add column if not exists tiktok text,
  add column if not exists facebook text,
  add column if not exists youtube text,
  add column if not exists x text,
  add column if not exists followers int;

-- Exemple de remplissage (une ligne par Miss, adapter la région) :
-- update public.mf_candidates set
--   taille = '1,75 m',
--   poids = '55 kg',
--   mensurations = '85-60-90',
--   profession = 'Étudiante en droit',
--   instagram = '@prenom.nom',
--   tiktok = '@prenom.nom',
--   photos = array[
--     'https://exemple.fr/photo-2.jpg',
--     'https://exemple.fr/photo-3.jpg'
--   ]
-- where region = 'Normandie';
