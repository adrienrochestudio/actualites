# Actualités

App de lecture de la newsletter quotidienne, installable sur iPhone et Mac, lisible hors ligne.

- `main` : code de l'app et outils de publication.
- `pages` : site publié (app + édition du jour), réécrit à chaque édition, servi par GitHub Pages.

Publier une édition : `python3 outils/publier.py chemin/edition.json --pousser` (schéma en tête du script).
Modifier l'app : changer `VERSION` dans `sw.js`, sinon les appareils gardent l'ancienne version.

Contenus publiés :
- Édition du jour (`edition/`), tâche quotidienne de 7h35, consignes dans `consignes/quotidien.md`.
- Édition de la semaine (`hebdo/`), tâche du lundi, consignes dans `consignes/hebdo.md`.

App Mac native : `natif/` (SwiftUI), construite par GitHub Actions, publiée dans la release `mac`.
