# Mini-sondage — 2 questions, réponses stockées en base

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
