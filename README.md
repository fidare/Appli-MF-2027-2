# Appli MF 2027 — Pronostics Miss France & mini-sondage

## Application principale : `site/miss/` — Les Pronostics Miss France 2027

Jeu de pronostics entre amis sur l'élection de Miss France, hébergé sur
GitHub Pages (`/miss/`) avec une base **Supabase**.

- `miss-france.sql` : script complet (tables, sécurité, fonctions, calcul
  des scores en cascade) à coller dans Supabase → *SQL Editor* → Run.
  Réexécutable sans risque.
- Identification : chaque joueur clique sur sa photo d'enfance puis tape
  son **PIN à 4 chiffres**. Les PIN sont visibles par l'organisateur
  (page « Régie » de l'appli, ou Table Editor → `mf_joueurs`) mais
  jamais exposés par l'API publique.
- Déroulé piloté par l'organisateur (page « Régie ») en phases :
  sélection des 15 → choix des 5 → ordre final → essais Miss France →
  clôture (élection en direct) → résultats.
- Le soir de l'élection, l'organisateur coche « Top 15 » et les rangs
  1 à 5 des Miss : tous les scores, graphiques et classements se
  recalculent instantanément chez tous les joueurs.
- Candidates et photos : Table Editor → `mf_candidates`, images dans
  Supabase Storage (bucket public `photos`).

## Mini-sondage — 2 questions, réponses stockées en base

Application de sondage à partager à 3 personnes.

## Version principale : `site/` (hébergée sur GitHub Pages)

- `site/index.html` : la page du sondage. À la validation, les réponses sont
  insérées dans une base **Supabase** (PostgreSQL) via son API REST.
- `supabase.sql` : script à coller dans Supabase → *SQL Editor* pour créer la
  table `reponses`, sécurisée en insertion seule (la clé publique `anon`
  embarquée dans la page ne permet ni lecture ni modification).
- `.github/workflows/pages.yml` : déploiement automatique sur GitHub Pages à
  chaque mise à jour de `site/` (nécessite Pages activé : *Settings → Pages →
  Source : GitHub Actions*).

Configuration : renseigner `SUPABASE.url` et `SUPABASE.anonKey` en tête du
script dans `site/index.html`. Les réponses se consultent dans Supabase →
*Table Editor* → `reponses` (export CSV possible).

## Variantes conservées

- `server.js` + `public/` : version auto-hébergée (Node ≥ 22.13, aucune
  dépendance, base SQLite locale). `ADMIN_KEY=secret node server.js`, réponses
  sur `/admin?cle=secret`.
- `sondage.html` : version autonome sans serveur (réponses renvoyées par
  e-mail au lieu d'être stockées).
