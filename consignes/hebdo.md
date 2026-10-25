# Édition de la semaine : consignes

Cinq dossiers de fond publiés chaque dimanche par la tâche quotidienne, après l'édition du jour, et affichés jusqu'au dimanche suivant en bas de l'app, repliés derrière leur image. Le lecteur les ouvre quand il a le temps : ce sont des articles longs, qui expliquent un sujet complexe jusqu'au bout.

## Déroulé

1. Charger le skill `.claude/skills/actualites-quotidiennes` (sources, images, règles d'écriture) et le skill `.claude/skills/sans-trace-ia`.
2. Date du jour (dimanche), fuseau Europe/Paris. `date_texte` : la date du dimanche, "Dimanche 1 novembre 2026". `date_texte_semaine` : la semaine qui commence le lendemain, "Semaine du 2 novembre 2026".
3. Historique : lire `historique/hebdo.txt` (branche `historique`, déjà récupérée par l'édition du jour). Lire aussi `historique/quotidien.txt` pour ne pas refaire un "Comprendre" récent. Aucun sujet déjà traité dans les 6 derniers mois.
4. Choix des 5 sujets, un par thème :
   - Géopolitique ou géoéconomie (hors du flux habituel : pas Iran, Ukraine ou Trump sauf cas exceptionnel)
   - Finance ou économie (un mécanisme : dette, monnaie, marchés, fiscalité, assurance, commerce)
   - IA et technologie (industrie, matières premières, énergie, puces, régulation, usages)
   - Énergie, climat ou environnement
   - Société, science ou culture (dont cinéma et industrie audiovisuelle, plutôt France)
   Chaque sujet part d'un fait des 7 derniers jours, mais traite la question de fond qui est derrière.
5. Recherche : vagues parallèles, au plus 40 recherches et 25 lectures de page au total. Sources primaires en priorité (institutions, rapports, données), presse de référence ensuite.
6. Rédaction de `hebdo.json` selon le schéma en tête de `outils/publier.py`.
7. Contrôle : `python3 outils/publier.py semaine hebdo.json --texte`, puis l'audit du skill sans-trace-ia sur le .txt (`--lang fr`). Corriger les alertes rouges.
8. Publication : `python3 outils/publier.py semaine hebdo.json --pousser`. Le script reprend l'édition du jour déjà en ligne.
9. Historique : ajouter les 5 lignes à `historique/hebdo.txt` au format `AAAA-MM-JJ | etiquette | sujet`, supprimer les lignes de plus de 6 mois (garder l'en-tête), puis commit et `git push origin historique`.

## Chaque dossier

- 1 200 à 1 800 mots, en 4 à 6 parties avec sous-titres.
- `chapo` : deux phrases qui disent l'enjeu et donnent envie d'ouvrir. Pas de question.
- `couverture` obligatoire : une photo Wikimedia Commons en 1100 px, un graphique Our World in Data ou une mini-carte. Elle doit représenter le sujet (le lieu, l'objet, la donnée), jamais une image d'illustration générique.
- Au moins deux autres visuels dans le corps (graphique, carte, photo, schéma). Un schéma dès qu'il y a un mécanisme ou un circuit d'argent.
- Structure type : le fait de la semaine, le contexte et l'histoire, le mécanisme expliqué pas à pas, les acteurs et leurs intérêts, les chiffres qui comptent, ce qui peut se passer ensuite.
- Chaque notion technique est définie à sa première apparition.
- Faits précis : chiffres, dates, noms, lieux. Toute affirmation vient d'une source lue cette semaine, listée dans `sources`. Un calcul fait par la rédaction est signalé dans `note_sources`.
- `a_retenir` : trois phrases.
- Écriture : skill sans-trace-ia, phrases courtes, pas de tiret cadratin, pas de ton alarmiste ni promotionnel, titres non interrogatifs.

## En cas d'échec

- Un dossier sans matière fiable : en publier quatre.
- Échec complet : un seul mail court via Gmail `send_message` à adrienroche6@gmail.com, objet "Actualités · édition de la semaine non produite", avec la cause en une phrase. L'édition de la semaine précédente reste en ligne. L'édition du jour, déjà publiée, n'est pas concernée.
