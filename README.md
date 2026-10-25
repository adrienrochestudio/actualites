# Actualités

App de lecture de la newsletter quotidienne, installable sur iPhone et Mac, lisible hors ligne.

- `main` : code de l'app et outils de publication.
- `pages` : site publié (app + édition du jour + édition de la semaine), réécrit à chaque édition, servi par GitHub Pages.
- `historique` : sujets déjà traités (`quotidien.txt`, 60 jours ; `hebdo.txt`, 6 mois), mis à jour par la tâche.

Publier une édition : `python3 outils/publier.py [jour|semaine] chemin/edition.json --pousser` (schéma en tête du script).
Modifier l'app : changer `VERSION` dans `sw.js`, sinon les appareils gardent l'ancienne version.

Une seule tâche planifiée Claude Code, « Actualités », chaque jour à 6h47 avec ce dépôt attaché :
- Édition du jour (`edition/`), consignes dans `consignes/quotidien.md`.
- Le dimanche, en plus, l'édition de la semaine (`hebdo/`), en ligne jusqu'au dimanche suivant, consignes dans `consignes/hebdo.md`.

Skills utilisés par la tâche : `.claude/skills/actualites-quotidiennes` et `.claude/skills/sans-trace-ia`.

App Mac native : `natif/` (SwiftUI), construite par GitHub Actions, publiée dans la release `mac`.
