-- ============================================================
-- Casting complet Miss France 2026 (30 Miss régionales, photos
-- officielles via voici.fr) + fonctions de gestion des candidates
-- pour la Régie (permettent ensuite de gérer le casting à distance
-- via l'API, sans repasser par le SQL Editor).
--
-- À coller dans Supabase → SQL Editor → Run.
-- ⚠️ Ce script VIDE d'abord la table des candidates (et donc les
-- pronostics existants) : c'est une remise à zéro du plateau.
-- ============================================================

-- 1. Fonctions Régie : ajouter/mettre à jour une candidate (clé = région)
create or replace function public.mf_admin_candidate_upsert(
  p_jeton uuid, p_nom text, p_region text,
  p_age int default null, p_taille text default null, p_profession text default null,
  p_photo_url text default null, p_photo_surprise_url text default null)
returns bigint
language plpgsql
security definer set search_path = public
as $fn$
declare
  v_id bigint;
begin
  perform mf_admin_id(p_jeton);
  select id into v_id from mf_candidates where region = p_region;
  if v_id is null then
    insert into mf_candidates (nom, region, age, taille, profession, photo_url, photo_surprise_url)
      values (p_nom, p_region, p_age, p_taille, p_profession, p_photo_url, p_photo_surprise_url)
      returning id into v_id;
  else
    update mf_candidates
      set nom = p_nom,
          age = coalesce(p_age, age),
          taille = coalesce(p_taille, taille),
          profession = coalesce(p_profession, profession),
          photo_url = coalesce(p_photo_url, photo_url),
          photo_surprise_url = coalesce(p_photo_surprise_url, photo_surprise_url)
      where id = v_id;
  end if;
  return v_id;
end;
$fn$;

-- Supprimer une candidate (p_candidate) ou tout le plateau (null).
create or replace function public.mf_admin_candidate_supprimer(p_jeton uuid, p_candidate bigint default null)
returns void
language plpgsql
security definer set search_path = public
as $fn$
begin
  perform mf_admin_id(p_jeton);
  if p_candidate is null then
    delete from mf_candidates;
  else
    delete from mf_candidates where id = p_candidate;
  end if;
end;
$fn$;

-- 2. Remise à zéro du plateau puis insertion du casting 2026
delete from public.mf_candidates;

insert into public.mf_candidates (nom, region, photo_url) values
  ('Julie Decroix', 'Alsace', 'https://www.voici.fr/imgre/fit/~1~voi~2025~11~14~589caed8-6571-4237-84b1-4394b6b2e1fa.jpeg/620x925/quality/63/crop-from/center/focus-point/998%2C640/crop-zone/0%2C116-2000x1245/image.avif'),
  ('Ainhoa Lahitete', 'Aquitaine', 'https://www.voici.fr/imgre/fit/~1~voi~2025~11~14~2b088570-2687-4994-afb7-29316b6dd9f9.jpeg/620x925/quality/63/crop-from/center/focus-point/895%2C689/crop-zone/0%2C109-2000x1287/image.avif'),
  ('Alice De Lima Guimaraes', 'Auvergne', 'https://www.voici.fr/imgre/fit/~1~voi~2025~11~14~912128a1-5536-4586-b786-2ea28aa62763.jpeg/620x925/quality/63/crop-from/center/focus-point/1096%2C501/crop-zone/8%2C0-1992x1339/image.avif'),
  ('Charlène Laurin', 'Bourgogne', 'https://www.voici.fr/imgre/fit/~1~voi~2025~11~14~b621bd13-fdb8-4fb3-a796-db160a6eb525.jpeg/620x925/quality/63/crop-from/center/focus-point/1000%2C970/crop-zone/0%2C37-2000x1248/image.avif'),
  ('Ninon Crolas', 'Bretagne', 'https://www.voici.fr/imgre/fit/~1~voi~2025~11~14~e566b358-555a-4381-ba1e-fde61d2f8ef4.jpeg/620x925/quality/63/crop-from/center/focus-point/1092%2C577/crop-zone/0%2C139-2000x1188/image.avif'),
  ('Anna Valero', 'Centre-Val-de-Loire', 'https://www.voici.fr/imgre/fit/~1~voi~2025~11~14~181451a0-e670-4d1a-bcd3-018a06803f43.jpeg/1200x675/focus-point/1000%2C1168/miss-france-2026-miss-centre-val-de-loire-2025-anna-valero.jpg'),
  ('Ynes Lallemand', 'Champagne-Ardenne', 'https://www.voici.fr/imgre/fit/~1~voi~2025~11~14~98c99c0e-1ded-419e-9c36-fbd03f8523ca.jpeg/620x925/quality/63/crop-from/center/focus-point/1181%2C909/crop-zone/0%2C381-2000x1311/image.avif'),
  ('Manon Mateus', 'Corse', 'https://www.voici.fr/imgre/fit/~1~voi~2025~11~14~7499d2eb-361f-4dfe-a123-b753d5aa11ba.jpeg/620x925/quality/63/crop-from/center/focus-point/913%2C654/crop-zone/0%2C111-2000x1373/image.avif'),
  ('Luna Maiolino', 'Côte d''Azur', 'https://www.voici.fr/imgre/fit/~1~voi~2025~11~14~c39211e0-1cf3-4e08-94e6-da9dd3993489.jpeg/620x925/quality/63/crop-from/center/focus-point/904%2C703/crop-zone/0%2C231-2000x1106/image.avif'),
  ('Jade Cholley', 'Franche-Comté', 'https://www.voici.fr/imgre/fit/~1~voi~2025~11~14~82efc71c-e44a-4f59-bd96-1cb7c56d09ff.jpeg/620x925/quality/63/crop-from/center/focus-point/1213%2C721/crop-zone/0%2C104-2000x1421/image.avif'),
  ('Naomi Torrent', 'Guadeloupe', 'https://www.voici.fr/imgre/fit/~1~voi~2025~11~14~1bd9190f-5620-4789-9d21-1ff55410c94e.jpeg/620x925/quality/63/crop-from/center/focus-point/993%2C698/crop-zone/0%2C266-1955x1155/image.avif'),
  ('Alicia Mertosetiko', 'Guyane', 'https://www.voici.fr/imgre/fit/~1~voi~2025~11~14~edec0a16-3ef7-4e55-a1a0-d20946d7634e.jpeg/620x925/quality/63/crop-from/center/focus-point/1145%2C770/crop-zone/0%2C180-2000x1180/image.avif'),
  ('Mareva Michel', 'Ile-de-France', 'https://www.voici.fr/imgre/fit/~1~voi~2025~11~14~44dc9a43-767e-41e8-81ae-58cea74bfa13.jpeg/620x925/quality/63/crop-from/center/focus-point/993%2C497/crop-zone/0%2C0-2000x1160/image.avif'),
  ('Lou Lambert', 'Languedoc', 'https://www.voici.fr/imgre/fit/~1~voi~2025~11~14~7f9b8043-4142-4cda-8a94-f96339f324c1.jpeg/620x925/quality/63/crop-from/center/focus-point/1060%2C582/crop-zone/0%2C0-2000x1297/image.avif'),
  ('Aloice Sejotte', 'Limousin', 'https://www.voici.fr/imgre/fit/~1~voi~2025~11~14~ab27d07c-1eff-424c-af27-a06603171208.jpeg/620x925/quality/63/crop-from/center/focus-point/1000%2C1117/crop-zone/0%2C0-2000x1117/image.avif'),
  ('Camille L''Etang', 'Lorraine', 'https://www.voici.fr/imgre/fit/~1~voi~2025~11~14~3a56c0f9-640b-4779-90ca-838c96bd821f.jpeg/620x925/quality/63/crop-from/center/focus-point/1000%2C1267/crop-zone/183%2C285-1817x1027/image.avif'),
  ('Léaline Patry', 'Martinique', 'https://www.voici.fr/imgre/fit/~1~voi~2025~11~14~8b2a78c8-b230-4260-b2c6-e10a9eb5e471.jpeg/620x925/quality/63/crop-from/center/focus-point/1101%2C698/crop-zone/0%2C101-2000x1316/image.avif'),
  ('Kamillat Hervian', 'Mayotte', 'https://www.voici.fr/imgre/fit/~1~voi~2025~11~14~ddcab6aa-328d-4d98-8ddf-a08499fb4add.jpeg/620x925/quality/63/crop-from/center/focus-point/984%2C662/crop-zone/0%2C210-2000x1181/image.avif'),
  ('Léa Chabrel', 'Midi-Pyrénées', 'https://www.voici.fr/imgre/fit/~1~voi~2025~11~14~177cdaff-05d4-4d6a-a27a-813441156cde.jpeg/620x925/quality/63/crop-from/center/focus-point/1016%2C940/crop-zone/0%2C456-1805x970/image.avif'),
  ('Lola Lachère', 'Nord-Pas-de-Calais', 'https://www.voici.fr/imgre/fit/~1~voi~2025~11~14~d54127f6-325f-4d0d-a480-35d88cb34287.jpeg/1200x675/focus-point/794%2C707/miss-france-2026-miss-nord-pas-de-calais-2025-lola-lachere.jpg'),
  ('Victoire Dupuis', 'Normandie', 'https://www.voici.fr/imgre/fit/~1~voi~2025~11~14~fb38a9ae-cd99-4ef3-a86f-ee99900fcf7c.jpeg/620x925/quality/63/crop-from/center/focus-point/1119%2C662/crop-zone/0%2C119-2000x1211/image.avif'),
  ('Juliette Collet', 'Nouvelle-Calédonie', 'https://www.voici.fr/imgre/fit/~1~voi~2025~11~14~bdae09c3-11c2-49e6-bbb6-69f9f58ceccf.jpeg/620x925/quality/63/crop-from/center/focus-point/971%2C801/crop-zone/0%2C238-2000x1244/image.avif'),
  ('Lola Winter', 'Pays-de-la-Loire', 'https://www.voici.fr/imgre/fit/~1~voi~2025~11~14~985383fc-5995-4aaa-b9bd-8c65e12f3503.jpeg/620x925/quality/63/crop-from/center/focus-point/50%2C50/crop-zone//image.avif'),
  ('Emma Boivin', 'Picardie', 'https://www.voici.fr/imgre/fit/~1~voi~2025~11~14~3d87592d-0ba8-40af-8c16-94231fe1c026.jpeg/620x925/quality/63/crop-from/center/focus-point/1226%2C662/crop-zone/106%2C205-1894x1117/image.avif'),
  ('Agathe Michelet', 'Poitou-Charentes', 'https://www.voici.fr/imgre/fit/~1~voi~2025~11~14~415fa831-bb74-4187-82b9-0214705f3890.jpeg/620x925/quality/63/crop-from/center/focus-point/1226%2C819/crop-zone/223%2C260-1777x1134/image.avif'),
  ('Julie Zitouni', 'Provence', 'https://www.voici.fr/imgre/fit/~1~voi~2025~11~14~9f4c3939-a28b-48e8-9ea5-fc3e6940c1d5.jpeg/620x925/quality/63/crop-from/center/focus-point/1015%2C752/crop-zone/0%2C265-1999x1327/image.avif'),
  ('Noémie Baimonte', 'Rhône-Alpes', 'https://www.voici.fr/imgre/fit/~1~voi~2025~11~14~da023a20-5571-48a7-804b-69362197b8cb.jpeg/620x925/quality/63/crop-from/center/focus-point/1047%2C654/crop-zone/0%2C50-2000x1243/image.avif'),
  ('Déborah Adelin-Chabal', 'Roussillon', 'https://www.voici.fr/imgre/fit/~1~voi~2025~11~14~4e4d3122-466c-4b2c-b643-b1746942f8b7.jpeg/620x925/quality/63/crop-from/center/focus-point/953%2C819/crop-zone/0%2C459-2000x1047/image.avif'),
  ('Priya Padavatan', 'Réunion', 'https://www.voici.fr/imgre/fit/~1~voi~2025~11~14~34ec0f73-109e-49e1-883d-d569ebad1ce6.jpeg/620x925/quality/63/crop-from/center/focus-point/935%2C913/crop-zone/0%2C253-2000x1345/image.avif'),
  ('Hinaupoko Deveze', 'Tahiti', 'https://www.voici.fr/imgre/fit/~1~voi~2025~11~14~7710c830-b713-4e3a-9db9-fef3f8328dbf.jpeg/620x925/quality/63/crop-from/center/focus-point/944%2C537/crop-zone/0%2C0-2000x1431/image.avif');
