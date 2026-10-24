-- Photos (miniatures) des joueurs, hébergées sur GitHub Pages
-- (site/miss/joueurs/). À exécuter dans Supabase → SQL Editor.

update public.mf_joueurs
  set photo_url = 'https://fidare.github.io/Appli-MF-2027-2/miss/joueurs/britney-spears.jpg'
  where pseudo = 'britney-spears';

update public.mf_joueurs
  set photo_url = 'https://fidare.github.io/Appli-MF-2027-2/miss/joueurs/gamboy-color.jpg'
  where pseudo = 'gamboy-color';

update public.mf_joueurs
  set photo_url = 'https://fidare.github.io/Appli-MF-2027-2/miss/joueurs/mel-b.jpg'
  where pseudo = 'mel-b';

update public.mf_joueurs
  set photo_url = 'https://fidare.github.io/Appli-MF-2027-2/miss/joueurs/minikeums.jpg'
  where pseudo = 'minikeums';

update public.mf_joueurs
  set photo_url = 'https://fidare.github.io/Appli-MF-2027-2/miss/joueurs/kmaro.jpg'
  where pseudo = 'kmaro';
