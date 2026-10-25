-- Nombre d'abonnés Instagram des Miss 2027 (page Recrues et fiche).
-- Relevé du 25/10/2026 (au-delà de 10 000, Instagram arrondit à la
-- centaine). À exécuter dans Supabase → SQL Editor, après
-- candidates-2027.sql.

alter table public.mf_candidates add column if not exists followers int;

update public.mf_candidates set instagram = 'may_haoues' where region = 'Côte d''Azur';

update public.mf_candidates c
  set followers = v.n
  from (values
    ('Alsace', 8141),
    ('Aquitaine', 9822),
    ('Auvergne', 7589),
    ('Bourgogne', 6401),
    ('Bretagne', 5423),
    ('Centre-Val de Loire', 8455),
    ('Champagne-Ardenne', 5499),
    ('Corse', 3515),
    ('Côte d''Azur', 6603),
    ('Franche-Comté', 6413),
    ('Guadeloupe', 8163),
    ('Guyane', 3880),
    ('Île-de-France', 21800),
    ('Languedoc', 15300),
    ('Limousin', 2477),
    ('Lorraine', 7729),
    ('Martinique', 6264),
    ('Mayotte', 4796),
    ('Midi-Pyrénées', 24300),
    ('Nord-Pas-de-Calais', 9710),
    ('Normandie', 12400),
    ('Nouvelle-Calédonie', 5554),
    ('Pays de la Loire', 9825),
    ('Picardie', 5485),
    ('Poitou-Charentes', 3977),
    ('Provence', 14000),
    ('Réunion', 12400),
    ('Rhône-Alpes', 10500),
    ('Roussillon', 4625),
    ('Saint-Martin et Saint-Barthélemy', 3253),
    ('Tahiti', 11700)
  ) as v(region, n)
  where c.region = v.region;
