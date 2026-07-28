# Suivi du projet — Pronostics Miss France 2027

Dernière mise à jour : 28/07/2026

## État : ✅ appli en ligne et fonctionnelle (en phase de test)

- Appli : https://fidare.github.io/Appli-MF-2027-2/miss/ (`site/miss/index.html`)
- Base : projet Supabase `vqzvwihmyzjnoqnqrtsv`, schéma créé via `miss-france.sql`
- Déploiement : automatique sur push de `site/**` vers `main` (`.github/workflows/pages.yml`)
- Connexion testée et validée par Romain (Mister Gamboy color, rôle Régie)
- Données de test : 15 candidates de l'édition précédente (`candidates-test.sql`)

## Fonctionnement

- Identification : photo d'enfance + PIN 4 chiffres (PIN visibles dans
  l'onglet Régie de l'appli et dans Table Editor → `mf_joueurs`)
- Phases pilotées depuis la Régie : préparation → sélection des 15 →
  choix des 5 → ordre final → essais MF → clôture (saisie des résultats
  réels en direct) → résultats (ouverture du Benchmark)
- Scores calculés en cascade côté Supabase dès que la Régie coche les
  résultats réels ; QCM saisi à la main dans la Régie
- Barème : 5 pts/Miss du top 15, 10 pts/top 5, 10 pts/bon rang,
  50 pts essai 1, 25 pts essai 2 (modifiable dans `mf_config`)

## ⚠️ À faire avant d'inviter les joueurs

1. **Changer tous les PIN** dans Table Editor → `mf_joueurs` : le dépôt
   est public, les PIN d'origine du fichier `miss-france.sql` sont donc
   lisibles par tout le monde (dont les copains). Le script ne les
   écrasera pas (`on conflict do nothing`).
2. Ajouter les photos d'enfance des joueurs (`mf_joueurs.photo_url`)
3. Corriger le pseudo « Tokio Hotel » (titre Mister/Miss inconnu)

## À faire quand le casting 2027 sera connu

1. `delete from public.mf_candidates;` (purge le test, garde les joueurs)
2. Insérer les vraies candidates (modèle en fin de `miss-france.sql`)
3. Photos des Miss : liens de presse acceptés dans `photo_url` /
   `photo_surprise_url` (attention aux liens qui meurent et aux sites
   anti-hotlink) — sinon bucket public `photos` dans Supabase Storage
4. Régie → phase « Sélection des 15 » et distribuer l'URL + les PIN

## Notes techniques

- Clé Supabase « publishable » (`sb_publishable_…`) : ne PAS l'envoyer en
  en-tête `Authorization: Bearer` (ce n'est pas un JWT) — `apikey` seul
- Tables verrouillées par RLS : toutes les écritures et lectures
  sensibles passent par les fonctions `mf_*` qui vérifient le jeton
- Les sessions Claude Code n'ont pas d'accès réseau vers Supabase ni les
  sites de presse : les scripts SQL sont à exécuter par Romain dans le
  SQL Editor
- Le sondage d'origine reste en ligne à la racine (`site/index.html`)
