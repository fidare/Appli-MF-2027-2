-- ============================================================
-- Données de TEST : les 15 candidates de l'édition précédente
-- (reprises des captures de l'ancienne appli, sans photos).
-- À coller dans Supabase → SQL Editor → Run.
--
-- Pour tout remettre à zéro avant le vrai casting 2027 :
--   delete from public.mf_candidates;
-- (les pronostics de test partent avec, les joueurs restent)
-- ============================================================

insert into public.mf_candidates (nom, region, age, taille, profession) values
  ('Hinaupoko Deveze',      'Tahiti',             23, null,     'Secrétaire administrative, organisatrice de séjours et mannequin'),
  ('Juliette Collet',       'Nouvelle-Calédonie', 23, null,     'Étudiante en scientifique'),
  ('Victoire Dupuis',       'Normandie',          19, '1,70 m', 'Étudiante en communication, marketing et publicité'),
  ('Naomi Torrent',         'Guadeloupe',         30, null,     'Double master en management'),
  ('Déborah Adelin-Chabal', 'Roussillon',         18, null,     'Étudiante en langues'),
  ('Priya Padavatan',       'Réunion',            null, null,   null),
  ('Julie Zitouni',         'Provence',           null, null,   null),
  ('Aïnhoa Lahitete',       'Aquitaine',          null, null,   null),
  ('Lou Lambert',           'Languedoc',          null, null,   null),
  ('Mareva Michel',         'Île-de-France',      null, null,   null),
  ('Alicia Mertosetiko',    'Guyane',             null, null,   null),
  ('Luna Maiolino',         'Côte d''Azur',       null, null,   null),
  ('Noémie Baiamonte',      'Rhône-Alpes',        null, null,   null),
  ('Lola Winter',           'Pays de la Loire',   null, null,   null),
  ('Agathe Michelet',       'Poitou-Charentes',   null, null,   null);
