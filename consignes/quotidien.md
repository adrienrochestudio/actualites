# Édition du jour : consignes de l'app

Ces consignes complètent les skills `.claude/skills/actualites-quotidiennes` (sources, images, règles d'écriture) et `.claude/skills/sans-trace-ia`, et priment sur eux quand ils diffèrent. Dans le skill actualites-quotidiennes, ignorer tout ce qui concerne Gmail, render.py, build.py et le fichier Drive.

## Deux profils, une seule rédaction

- `fr` : Adrien, en français. `pt` : Ana, en portugais du Brésil.
- On écrit une seule fois, en français, une édition de base (`base.json`) qui contient les rubriques des deux profils. La version d'Ana est une traduction de ses rubriques, faite à la fin.
- Recherche une seule fois pour les rubriques communes.

## Rubriques (ordre fixe par profil)

| Adrien (fr) | Ana (pt) |
|---|---|
| Une | Une |
| Monde | Monde |
| France | Brésil |
| Brésil | France |
| Le chiffre | Politique du Brésil |
| Comprendre | Le chiffre |
| Finance | Architecture |
| Intelligence artificielle | Cinéma |
| IA, technique | Environnement |
| Cinéma | Carte expliquée |
| Environnement | brèves |
| Carte expliquée | |
| brèves | |

Dans `base.json`, l'ordre des rubriques n'a pas d'importance : `outils/profils.py` répartit et ordonne selon l'étiquette. Les étiquettes doivent être exactement celles du tableau.

## Ligne éditoriale (toutes rubriques)

- Le but : s'informer sans le flux des médias qui parlent sans cesse des mêmes figures et des mêmes guerres. Pas Trump, Bolsonaro, Ukraine, Iran, sauf événement exceptionnel.
- Privilégier ce qui a un impact réel sur le monde et reste peu traité : décisions, budgets, technologies, matières premières, infrastructures, sciences, régions peu couvertes.
- Pas d'alarmisme et pas de fin du monde à chaque rubrique. Une info grave se traite par les faits et par ce qui est fait pour y répondre. Inclure des avancées réelles quand elles existent (un progrès mesuré, une solution qui marche), sans tomber dans le tout positif : l'utile d'abord.
- Être à la pointe sur la technologie et la finance : nouveautés de la veille ou de la semaine, expliquées jusqu'au mécanisme.

## Règles par rubrique

Les règles des rubriques déjà existantes (Une, Monde, Le chiffre, Comprendre, Finance, Intelligence artificielle) sont celles du skill. Longueurs indicatives en mots.

- **France** (350) : politique, économie, société, sciences ou régions, une décision ou un fait à impact réel, hors polémiques du jour. Les sujets de Paris y entrent quand ils comptent.
- **Brésil** (350) : société, économie, culture, sciences, environnement. Pas la politique nationale, traitée à part pour Ana.
- **Politique du Brésil** (350, Ana) : institutions, lois, budget, décisions des ministères, États et villes. Les figures nationales seulement quand une décision en découle. Pas de petites phrases ni de sondages.
- **Architecture** (350, Ana) : un projet, un bâtiment, un concours, un prix, l'urbanisme ou les matériaux, au Brésil ou ailleurs. Une photo Wikimedia Commons obligatoire, avec l'architecte et l'année dans la légende.
- **IA, technique** (550) : un mécanisme technique de l'IA, expliqué à quelqu'un qui n'est pas ingénieur (refroidissement d'un data center, token, choix du mot suivant, skills et mods de Claude, MCP, quantification, entraînement contre inférence, GPU, InfiniBand, fenêtre de contexte...). Sous-titres. Partir d'une situation concrète, puis descendre dans le mécanisme. Chaque terme technique défini à sa première apparition. Un schéma (`schema`) obligatoire. Chiffres réels et sourcés. Sources : documentation officielle (docs.claude.com, Nvidia, Google, Meta), AIE, Uptime Institute, recherche, presse tech reconnue.
- **Cinéma** (300) : industrie du cinéma et de l'audiovisuel, plutôt France (fréquentation, financement, tournages, festivals, métiers). Pas de classement du box-office.
- **Environnement** (350) : climat, énergie, biodiversité, pollution ; un fait mesuré et ce qu'il change. Les solutions qui fonctionnent ont leur place.
- **Carte expliquée** (350) : une seule carte, lue en détail. Ce qu'elle représente, comment la lire, ce qu'on y voit d'étonnant, ce qui l'explique. Carte en pleine largeur (`"largeur": 1100`) : Our World in Data (`?tab=map`), Wikimedia Commons ou institution publique sous licence libre. Lien vers la version interactive quand elle existe. Sujet sans lien obligatoire avec l'actualité du jour.
- **Brèves**, dans cet ordre : Portugal, Europe, Afrique, Amériques, Asie, Océanie. Paris passe dans France, le Brésil dans Brésil. 2 ou 3 items par zone, une zone sans info notable est omise.

## Visuels

Viser au moins un visuel dans 80 % des rubriques, toujours utile :
- graphiques Our World in Data (`?tab=map` ou `?tab=chart`), avec `"lien"` vers la version interactive ;
- photos et portraits Wikimedia Commons, demandés en 1100 px de large (`iiurlwidth=1100`) ;
- mini-cartes pour les villes peu connues citées dans une rubrique, sans limite ;
- schémas pour les montages et les mécanismes.
Un graphique ou une photo de paysage prend la largeur entière (`"largeur": 1100`). Un portrait reste petit (`"largeur": 360`), seul ou dans un `duo` avec une carte. La légende dit ce qu'il faut regarder dans l'image, pas seulement ce que c'est.

## Déroulé

Dépendances : Pillow et matplotlib (`pip install pillow matplotlib` si l'import échoue). Schéma du JSON : en tête de `outils/publier.py`. Au plus 22 recherches et 16 lectures de page.

1. Historique : `git fetch origin historique`, `git worktree add -B historique historique origin/historique`, lire `historique/quotidien.txt`. Aucun sujet ni aucune notion "Comprendre", "IA, technique" ou "Carte expliquée" déjà traités dans les 60 jours.
2. Recherche en vagues parallèles, puis rédaction de `base.json` en français, avec toutes les rubriques des deux profils et les brèves.
3. Contrôle FR : `python3 outils/publier.py jour base.json --texte`, puis l'audit sans-trace-ia sur `base.txt` (`--lang fr`). Corriger les alertes rouges dans le JSON. Les alertes "de plus" dans une comparaison chiffrée sont acceptées.
4. `python3 outils/profils.py preparer base.json` : écrit `edition-fr.json` et `a-traduire.json` (les seuls textes du profil pt).
5. Traduction : charger `references/lexique-pt.md` et la section FR vers pt-BR de `references/traduction.md` du skill sans-trace-ia. Écrire `traduit.json` : mêmes clés, même nombre d'entrées, chaque texte en portugais du Brésil naturel. Ne rien ajouter, ne rien retirer.
6. `python3 outils/profils.py assembler base.json traduit.json` : écrit `edition-pt.json`. Puis `python3 outils/publier.py jour edition-pt.json --texte` et l'audit sur `edition-pt.txt` (`--lang pt`). Corriger les alertes rouges dans `traduit.json` et réassembler.
7. Publication des deux profils en un envoi : `python3 outils/publier.py jour edition-fr.json edition-pt.json --pousser`. S'il s'arrête sur une erreur, corriger le JSON et relancer. Une image "laissée distante" n'est pas une erreur.
8. Historique : une ligne par rubrique de `base.json` au format `AAAA-MM-JJ | rubrique | sujet | notion ou villes`, supprimer les lignes de plus de 60 jours (garder l'en-tête), puis dans `historique/` : `git add quotidien.txt`, `git commit`, `git push origin historique`. Si le push est refusé parce que la branche a bougé : `git pull --rebase origin historique` et relancer.

Si la traduction ou l'édition pt échoue, publier quand même `edition-fr.json` seul : le profil pt garde l'édition de la veille.

## Le dimanche

Après la publication et l'historique du jour, produire l'édition de la semaine selon `consignes/hebdo.md`.

## En cas d'échec

- Accès git refusé : produire quand même l'édition fr et l'envoyer par mail (étapes 6 et 7 du skill `actualites-quotidiennes` : render.py, build.py, Gmail `send_message` à adrien.etks@gmail.com, libellé Actualités). Puis un mail court à adrienroche6@gmail.com, objet "Actualités · app non mise à jour", avec le message d'erreur git exact.
- Aucune édition possible : un seul mail court à adrienroche6@gmail.com, objet "Actualités · édition non produite", avec la cause en une phrase.
