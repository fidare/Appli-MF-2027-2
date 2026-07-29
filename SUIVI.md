# Suivi du projet — Pronostics Miss France 2027

Dernière mise à jour : 29/07/2026

## État : ✅ appli complète, designée et fonctionnelle (données de test)

- Appli : https://fidare.github.io/Appli-MF-2027-2/miss/ (`site/miss/index.html`)
- Base : projet Supabase `vqzvwihmyzjnoqnqrtsv`, schéma créé via `miss-france.sql`
- Déploiement : automatique sur push de `site/**` vers `main` (`.github/workflows/pages.yml`)
- Données de test : casting complet 2026, 30 candidates avec photos
  voici.fr (`candidates-test.sql`)
- Design mobile-first « soirée de gala » : nuit étoilée or/rose,
  Playfair Display + Outfit (Google Fonts), icônes SVG maison, dock de
  navigation flottant, lever de rideau après le PIN, paillettes (votes,
  huissier, sacre), animations respectant prefers-reduced-motion

## Fonctionnement

- Identification : photo d'enfance + PIN 4 chiffres (PIN visibles dans
  l'onglet Régie de l'appli et dans Table Editor → `mf_joueurs`)
- 3 phases de jeu pilotées depuis la Régie :
  1. `selection15` : son équipe de 15 (parmi les 30) + essai MF Nº1
  2. `top5` : le vrai top 15 est coché en Régie → choix de ses 5 parmi
     ces 15 + essai Nº2 (galerie filtrée : les éliminées disparaissent)
  3. `ordre` : les 5 finalistes officielles cochées → chacun les classe
     de 1 (sa Miss France) à 5 (galerie réduite aux 5)
- Galerie « Jeunettes » : réduite aux 5 finalistes dès qu'elles sont
  connues et jusqu'à la fin (`ordre`, `cloture`, `resultats`) ; en
  `resultats`, un bouton rouvre le rideau sur les éliminées, affichées
  en dessous des finalistes
  puis `cloture` (résultats des Miss saisis dans l'ordre des annonces,
  **aucun point visible par les joueurs**) et `resultats` (dévoilement du
  classement place par place, piloté par la Régie)
- Dévoilement final : `mf_config.reveal_n` = nombre de places déjà
  annoncées, en partant de la **dernière**. La Régie clique « Dévoiler la
  Nº X » ; le serveur ne renvoie que les places annoncées (les autres ne
  sortent pas de la base). Un joueur voit son détail quand sa place est
  appelée ; les graphiques du Benchmark n'apparaissent qu'une fois les
  N places annoncées (paillettes de sacre à ce moment-là)
- Huissier de justice : à chaque phase, sélection complète exigée pour
  sceller son dossier (verrouillage serveur, récupérable tant que la
  phase est ouverte) ; badge « scellé » visible des autres
- Régie : tableau complet compact avec recherche, compteurs Top 15 x/15
  et Finalistes x/5, enregistrement groupé en un clic, saisie QCM,
  bouton « Réinitialiser le jeu » (double confirmation, conserve
  joueurs et candidates)
- Scores calculés en cascade côté Supabase dès que la Régie enregistre
  les résultats réels ; QCM saisi à la main dans la Régie
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
