# Édition du jour : consignes de l'app

Ces consignes complètent le skill `actualites-quotidiennes` et priment sur lui quand ils diffèrent.

## Ce qui change par rapport au skill

- Publication dans l'app, pas de mail : `python3 outils/publier.py jour edition.json --pousser`. Pas de render.py, pas de build.py, pas d'artefact, pas de nettoyage Gmail.
- Mini-cartes : plus de limite par édition. Une mini-carte pour chaque ville peu connue citée dans une rubrique principale.
- Schéma du JSON : en tête de `outils/publier.py`.

## Rubriques (ordre fixe)

Une, Monde, Le chiffre, Comprendre, Finance, Intelligence artificielle, **IA, technique**, Cinéma ou Écologie, puis les brèves. Les règles de chaque rubrique sont celles du skill, sauf la nouvelle :

**IA, technique** (`"etiquette": "IA, technique"`) : un mécanisme technique de l'IA, expliqué à quelqu'un qui n'est pas ingénieur. Exemples de sujets : comment un data center refroidit ses puces, ce qu'est un token et pourquoi on paie au token, comment un modèle choisit le mot suivant, ce que sont les skills et les mods dans Claude, le protocole MCP, la quantification d'un modèle, l'entraînement contre l'inférence, pourquoi les GPU et pas les CPU, ce que fait un réseau InfiniBand, la fenêtre de contexte.
- 500 à 700 mots, avec sous-titres.
- Partir d'une situation concrète, puis descendre dans le mécanisme. Une comparaison avec un objet du quotidien au plus, quand elle éclaire vraiment.
- Chaque terme technique est défini à sa première apparition, en une phrase.
- Un schéma (`schema`) obligatoire : le circuit des données, de l'énergie ou des étapes.
- Chiffres réels et sourcés (puissance, consommation, latence, nombre de paramètres), jamais d'ordre de grandeur inventé.
- Sources : documentation officielle (docs.anthropic.com, docs.claude.com, blogs techniques des fabricants, Nvidia, Google, Meta), AIE, Uptime Institute, articles de recherche, presse tech reconnue.
- Sujet tiré de l'actualité de la semaine quand c'est possible, sinon un sujet de fond. Pas de sujet déjà traité dans l'historique des 60 jours (ligne `IA, technique`).

## Visuels

Viser au moins un visuel dans 80 % des rubriques principales, toujours utile :
- graphiques Our World in Data (`?tab=map` ou `?tab=chart`), avec `"lien"` vers la version interactive ;
- photos et portraits Wikimedia Commons, demandés en 1100 px de large (`iiurlwidth=1100`) ;
- mini-cartes pour les villes peu connues ;
- schémas pour les montages et les mécanismes.
Un graphique ou une photo de paysage prend la largeur entière (`"largeur": 1100`). Un portrait reste petit (`"largeur": 360`), seul ou dans un `duo` avec une carte.
La légende dit ce qu'il faut regarder dans l'image (la zone, la courbe, l'écart), pas seulement ce que c'est.

## Historique

Fichier Drive `Actualités - historique.txt` (id dans le skill) : ajouter aussi une ligne pour `IA, technique`.
