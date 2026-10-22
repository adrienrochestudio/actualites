# Actualités

App de lecture de la newsletter quotidienne, installable sur iPhone et Mac, lisible hors ligne.

- `main` : code de l'app et outils de publication.
- `pages` : site publié (app + édition du jour), réécrit à chaque édition, servi par GitHub Pages.

Publier une édition : `python3 outils/publier.py chemin/edition.json --pousser` (schéma en tête du script).
Modifier l'app : changer `VERSION` dans `sw.js`, sinon les appareils gardent l'ancienne version.
