-- Photos (miniatures) des joueurs, hébergées sur GitHub Pages
-- (site/miss/joueurs/). À exécuter dans Supabase → SQL Editor.

update public.mf_joueurs
  set photo_url = 'https://fidare.github.io/Appli-MF-2027-2/miss/joueurs/britney-spears.jpg'
  where pseudo = 'britney-spears';

-- Photo attribuée par erreur à Mister Gamboy color
update public.mf_joueurs
  set photo_url = null
  where pseudo = 'gamboy-color';
