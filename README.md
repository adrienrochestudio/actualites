# Actualités

App de lecture de la newsletter quotidienne, installable sur iPhone et Mac, lisible hors ligne.

- `main` : code de l'app et outils de publication.
- `pages` : site publié, réécrit à chaque édition, servi par GitHub Pages : l'app + pour chaque profil (`fr` Adrien, `pt` Ana) l'édition du jour (`{profil}/edition/`) et celle de la semaine (`{profil}/hebdo/`).
- `historique` : sujets déjà traités (`quotidien.txt`, 60 jours ; `hebdo.txt`, 6 mois), mis à jour par la tâche.

Publier : `python3 outils/publier.py [jour|semaine] edition-fr.json edition-pt.json --pousser` (schéma en tête du script).
Deux profils, une rédaction : `outils/profils.py` répartit une édition de base en français entre les profils et prépare la traduction pt-BR.
Globe animé du logo : `globe.js`, contours des terres dans `geo/terre.json` (régénérés par `outils/terre.py`).
Modifier l'app : changer `VERSION` dans `sw.js`, sinon les appareils gardent l'ancienne version.

Une seule tâche planifiée Claude Code, « Actualités », chaque jour à 5h53 avec ce dépôt attaché :
- Édition du jour des deux profils, consignes dans `consignes/quotidien.md`.
- Le dimanche, en plus, l'édition de la semaine des deux profils, en ligne jusqu'au dimanche suivant, consignes dans `consignes/hebdo.md`.

Skills utilisés par la tâche : `.claude/skills/actualites-quotidiennes` et `.claude/skills/sans-trace-ia` (fr, en, pt-BR).

App Mac native : `natif/` (SwiftUI), construite par GitHub Actions, publiée dans la release `mac`.
