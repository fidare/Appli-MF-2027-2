-- Noms de héros des joueurs (le pseudo et le PIN ne changent pas).
-- À exécuter dans Supabase → SQL Editor.

update public.mf_joueurs j
  set nom_affiche = v.nom
  from (values
    ('gamboy-color', 'Drax'),
    ('adibou', 'Thor'),
    ('britney-spears', 'Iron Woman'),
    ('kmaro', 'Doctor Strange'),
    ('loana-petrucciani', 'Cyclope'),
    ('mel-b', 'Sylvie'),
    ('minikeums', 'Spider-Man'),
    ('nokia-3310', 'La Torche humaine'),
    ('pussycat-dolls', 'Captain America'),
    ('tokio-hotel', 'Natasha Romanoff')
  ) as v(pseudo, nom)
  where j.pseudo = v.pseudo;
