# Édition de la semaine : consignes

Cinq dossiers de fond par profil, publiés chaque dimanche par la tâche quotidienne, après l'édition du jour, et affichés jusqu'au dimanche suivant dans l'onglet Hebdomadaire, repliés derrière leur image. Le lecteur les ouvre quand il a le temps : ce sont des articles longs, qui expliquent un sujet complexe jusqu'au bout.

Comme pour le jour : une seule rédaction en français (`hebdo-base.json`), les dossiers d'Ana traduits à la fin. Ligne éditoriale : celle de `consignes/quotidien.md`.

## Déroulé

1. Lire `consignes/ecriture.md` (règles d'écriture et de traduction) ; sources et visuels : sections du même nom dans `consignes/quotidien.md`. Ne pas charger les skills.
2. Date du jour (dimanche), fuseau Europe/Paris. `date_texte` : la date du dimanche, "Dimanche 1 novembre 2026". `date_texte_semaine` : la semaine qui commence le lendemain, "Semaine du 2 novembre 2026".
3. Point de départ : `python3 outils/historique.py pistes` (sujets de fond repérés pendant la semaine) et `python3 outils/historique.py notions` (dossiers des 6 derniers mois et notions récentes, à ne pas refaire). Compléter au besoin avec `python3 outils/veille.py --heures 168 --max 8`.
4. Choix de 7 sujets, un par thème. Chaque dossier porte `"profils"` :
   - Géopolitique ou géoéconomie (hors du flux habituel : pas Iran, Ukraine, Trump ou Bolsonaro sauf cas exceptionnel) : `["fr", "pt"]`
   - Énergie, climat ou environnement : `["fr", "pt"]`
   - Société, science ou culture (dont cinéma et industrie audiovisuelle, plutôt France) : `["fr", "pt"]`
   - Finance ou économie (un mécanisme : dette, monnaie, marchés, fiscalité, assurance, commerce) : `["fr"]`
   - IA et technologie (industrie, matières premières, énergie, puces, régulation, usages) : `["fr"]`
   - Architecture ou urbanisme : `["pt"]`
   - Politique du Brésil (institutions, lois, budget, réformes ; pas de petites phrases) : `["pt"]`
   Chaque sujet part d'un fait des 7 derniers jours, mais traite la question de fond qui est derrière.
5. Recherche : partir des pistes, vagues parallèles, au plus 30 recherches web et 32 lectures de page au total. Sources primaires en priorité (institutions, rapports, données), presse de référence ensuite.
6. Rédaction de `hebdo-base.json` en français selon le schéma en tête de `outils/publier.py`, avec le champ `profils` de chaque dossier.
7. Contrôle FR : `python3 outils/publier.py semaine hebdo-base.json --texte`, puis l'audit sans-trace-ia sur le .txt (`--lang fr`). Corriger les alertes rouges.
8. `python3 outils/profils.py preparer hebdo-base.json --semaine` (écrit `hebdo-fr.json` et `a-traduire.json`), traduction dans `traduit.json` (mêmes règles que pour le jour), puis `python3 outils/profils.py assembler hebdo-base.json traduit.json --semaine` (écrit `hebdo-pt.json`). Contrôle `--texte` et audit `--lang pt` sur `hebdo-pt.json`.
9. Publication des deux profils en un envoi : `python3 outils/publier.py semaine hebdo-fr.json hebdo-pt.json --pousser`. Le script reprend les éditions du jour déjà en ligne.
10. Historique : `python3 outils/historique.py ajouter hebdo-base.json --semaine`, puis `python3 outils/historique.py envoyer`.

## Chaque dossier

- 1 200 à 1 800 mots, en 4 à 6 parties avec sous-titres.
- `chapo` : deux phrases qui disent l'enjeu et donnent envie d'ouvrir. Pas de question.
- `couverture` obligatoire : une photo Wikimedia Commons en 1100 px, un graphique Our World in Data ou une mini-carte. Elle doit représenter le sujet (le lieu, l'objet, la donnée), jamais une image d'illustration générique.
- Au moins deux autres visuels dans le corps (graphique, carte, photo, schéma). Un schéma dès qu'il y a un mécanisme ou un circuit d'argent.
- Structure type : le fait de la semaine, le contexte et l'histoire, le mécanisme expliqué pas à pas, les acteurs et leurs intérêts, les chiffres qui comptent, ce qui peut se passer ensuite.
- Chaque notion technique est définie à sa première apparition.
- Faits précis : chiffres, dates, noms, lieux. Toute affirmation vient d'une source lue cette semaine, listée dans `sources`. Un calcul fait par la rédaction est signalé dans `note_sources`.
- `a_retenir` : trois phrases.
- Écriture : `consignes/ecriture.md`, phrases courtes, pas de tiret cadratin, pas de ton alarmiste ni promotionnel, titres non interrogatifs.

## En cas d'échec

- Un dossier sans matière fiable : le profil concerné en publie quatre.
- Échec complet : un seul mail court via Gmail `send_message` à adrienroche6@gmail.com, objet "Actualités · édition de la semaine non produite", avec la cause en une phrase. L'édition de la semaine précédente reste en ligne. L'édition du jour, déjà publiée, n'est pas concernée.
