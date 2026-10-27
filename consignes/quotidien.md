# Édition du jour : consignes

Seuls fichiers à lire : celui-ci et `consignes/ecriture.md`. Ne pas charger les skills : le skill `actualites-quotidiennes` ne sert qu'en cas d'échec git (voir la fin), le skill `sans-trace-ia` fournit seulement l'audit et, pour la traduction, `references/lexique-pt.md`.

## Deux profils, une seule rédaction

- `fr` : Adrien, en français. `pt` : Ana, en portugais du Brésil.
- On écrit une seule fois, en français, une édition de base (`base.json`) avec les rubriques des deux profils. La version d'Ana est la traduction de ses rubriques, faite à la fin. Recherche une seule fois pour les rubriques communes.

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

Dans `base.json`, l'ordre n'a pas d'importance : `outils/profils.py` répartit et ordonne selon l'étiquette, qui doit être exactement celle du tableau.

## Ligne éditoriale

- S'informer sans le flux des médias qui parlent sans cesse des mêmes figures et des mêmes guerres. Pas Trump, Bolsonaro, Ukraine, Iran, sauf événement exceptionnel.
- Privilégier ce qui a un impact réel et reste peu traité : décisions, budgets, technologies, matières premières, infrastructures, sciences, régions peu couvertes.
- Pas d'alarmisme ni de fin du monde à chaque rubrique. Une info grave se traite par les faits et par ce qui est fait pour y répondre. Inclure des avancées réelles quand elles existent, sans tomber dans le tout positif : l'utile d'abord.
- À la pointe sur la technologie et la finance : nouveautés de la veille ou de la semaine, expliquées jusqu'au mécanisme.
- Faits précis, chiffres, dates, noms. Jamais de généralités. "À retenir" : 2 phrases en fin de chaque rubrique sauf Le chiffre.

## Rubriques (longueurs indicatives en mots)

- **Une** (`une`, 60) : l'actualité brûlante du matin, factuelle, pas alarmiste. Pas un résumé de l'édition.
- **Monde** (450) : géopolitique ou géoéconomie hors du flux habituel. Préférer Afrique, Asie, Amérique latine, matières premières, accords commerciaux.
- **France** (350) : politique, économie, société, sciences ou régions ; une décision ou un fait à impact réel, hors polémiques du jour. Paris y entre quand c'est utile.
- **Brésil** (350) : société, économie, culture, sciences, environnement. Pas la politique nationale.
- **Politique du Brésil** (350, Ana) : institutions, lois, budget, décisions des ministères, États et villes. Les figures nationales seulement quand une décision en découle. Pas de petites phrases ni de sondages.
- **Le chiffre** (250) : une statistique de source fiable (AIE, Eurostat, INSEE, FMI, OCDE, Banque mondiale, BRI, Our World in Data). Le titre est le chiffre. Expliquer l'ordre de grandeur et ce qu'il dit.
- **Comprendre** (600) : une notion de finance ou de géoéconomie expliquée à partir d'une actu de la semaine, avec sous-titres, et un `schema` quand un circuit d'argent ou un montage s'y prête.
- **Finance** (350) : 3 ou 4 mouvements de marché de la veille ou de la semaine (indices, taux, pétrole, or, devises, une action) : niveau, variation, raison précise.
- **Intelligence artificielle** (400) : nouveauté Claude ou Anthropic en priorité (lire anthropic.com/news, qui n'a pas de flux), puis OpenAI, Mistral, modèles chinois, marché, matières premières de l'IA, ou article critique.
- **IA, technique** (550) : un mécanisme technique de l'IA expliqué à un non-ingénieur (refroidissement d'un data center, token, choix du mot suivant, skills et mods de Claude, MCP, quantification, entraînement contre inférence, GPU, InfiniBand, fenêtre de contexte...). Partir d'une situation concrète, définir chaque terme à sa première apparition, `schema` obligatoire, chiffres réels et sourcés (documentation officielle, Nvidia, Google, AIE, Uptime Institute, recherche).
- **Architecture** (350, Ana) : un projet, un bâtiment, un concours, un prix, l'urbanisme ou les matériaux, au Brésil ou ailleurs. Photo Wikimedia Commons obligatoire, architecte et année dans la légende.
- **Cinéma** (300) : industrie du cinéma et de l'audiovisuel, plutôt France (fréquentation, financement, tournages, festivals, métiers). Pas de classement du box-office.
- **Environnement** (350) : climat, énergie, biodiversité, pollution ; un fait mesuré et ce qu'il change. Les solutions qui fonctionnent ont leur place.
- **Carte expliquée** (350) : une seule carte, lue en détail : ce qu'elle représente, comment la lire, ce qu'on y voit d'étonnant, ce qui l'explique. Pleine largeur (`"largeur": 1100`), Our World in Data (`?tab=map`), Wikimedia Commons ou institution publique sous licence libre, avec `"lien"` vers la version interactive. Sans lien obligatoire avec l'actualité.
- **Brèves** (`breves`), dans cet ordre : Portugal, Europe, Afrique, Amériques, Asie, Océanie. 2 ou 3 items par zone, une zone sans info notable est omise. Chaque brève donne le contexte pour être comprise seule (qui est qui, pourquoi ça compte).

## Réseau et sources

- Le shell de la tâche n'atteint pas les sites de presse ni Wikimedia (proxy 403) : c'est normal. Seuls git, GitHub et les dépôts de paquets passent. Toute lecture du web passe par les outils WebSearch et WebFetch, qui fonctionnent.
- La veille (flux de `consignes/veille.txt`) tourne chaque nuit dans GitHub Actions et attend sur la branche `veille` (étape 2). Lire ensuite les articles retenus avec WebFetch, sur l'adresse directe de l'article (jamais une adresse de redirection Google).
- WebSearch : toujours `mode: "extended"` pour l'actualité datée (le mode standard ne renvoie que des liens). Requêtes précises (sujet, lieu, date), lancées en parallèle dans un seul tour.
- Compléments : anthropic.com/news et mistral.ai/news (IA) ; iea.org/reports, ec.europa.eu/eurostat, insee.fr, worldbank.org (chiffres) ; cnc.fr (fréquentation, début de mois) ; paris.fr ; consilium.europa.eu.
- Une page qui refuse la lecture : passer à une autre source, ne pas insister. Éviter les agrégateurs de faible qualité.

## Visuels

Viser un visuel utile dans 80 % des rubriques. Licences libres uniquement, chargées par `"url"` : jamais d'image de presse, d'affiche de film ni de photo de célébrité.
- Wikimedia Commons : avec WebFetch (pas curl), `https://commons.wikimedia.org/w/api.php?action=query&list=search&srsearch=NOM&srnamespace=6&srlimit=5&format=json`, puis `https://commons.wikimedia.org/w/api.php?action=query&prop=imageinfo&iiprop=url|extmetadata&iiurlwidth=1100&format=json&titles=File:...` sur le fichier choisi ; utiliser `thumburl`, créditer auteur et licence dans `credit`. Les images ne sont pas copiées dans le site (réseau du shell) : l'app les charge elle-même, c'est prévu.
- Our World in Data : `https://ourworldindata.org/grapher/<graphique>.png?tab=map` (ou `tab=chart`), `"lien"` vers la version interactive, crédit "Our World in Data, CC BY".
- Portrait : seulement une personne peu médiatisée, petit (`"largeur": 360`), seul ou dans un `duo` avec une carte.
- Mini-carte (`carte`) pour chaque ville peu connue citée dans une rubrique, sans limite ; pas pour une capitale évidente. Ville frontalière : préciser `"pays"` (nom Natural Earth).
- Graphique ou paysage en pleine largeur (`"largeur": 1100`). La légende dit ce qu'il faut regarder, pas seulement ce que c'est.
- Une carte de presse meilleure que tout ce qui existe en libre : un lien "voir la carte" dans la légende, jamais l'image.

## Déroulé

Dépendances : Pillow et matplotlib (`pip install pillow matplotlib` si l'import échoue). Schéma du JSON : en tête de `outils/publier.py`. Au plus 10 recherches web et 16 lectures de page : la veille remplace le reste.

1. Historique : `git fetch origin historique`, `git worktree add -B historique historique origin/historique`. Puis `python3 outils/historique.py notions` (notions et dossiers récents à ne pas refaire). Ne pas lire les fichiers de l'historique.
2. Veille : `git fetch origin veille && git worktree add veille FETCH_HEAD`, puis lire `veille/veille.txt` (sa première ligne donne l'heure de la veille). Choisir les sujets, `python3 outils/veille.py lien <numéros>` pour leurs adresses, lire les articles retenus avec WebFetch. Recherches web seulement pour ce que la veille ne couvre pas (Le chiffre, Carte expliquée, IA, technique, compléments).
   Si la branche `veille` manque ou date de plus de 12 heures : chercher l'actualité avec WebSearch en mode extended, une requête par rubrique, jusqu'à 18 recherches.
3. Pistes pour le dimanche : pour 1 à 3 sujets de fond repérés et non traités, `python3 outils/historique.py piste "thème" "sujet en une ligne" "url"`. Thèmes : Géopolitique, Environnement, Société, Finance, IA, Architecture, Politique du Brésil.
4. Rédaction de `base.json` en français, toutes les rubriques des deux profils et les brèves. Puis `python3 outils/historique.py verifier base.json` : changer de sujet si une rubrique reprend un sujet déjà traité.
5. Contrôle FR : `python3 outils/publier.py jour base.json --texte`, puis l'audit sur `base.txt` (`--lang fr`). Corriger les alertes rouges dans le JSON. Les alertes "de plus" dans une comparaison chiffrée sont acceptées.
6. `python3 outils/profils.py preparer base.json` : écrit `edition-fr.json` et `a-traduire.json` (les seuls textes d'Ana).
7. Traduction selon `consignes/ecriture.md` : écrire `traduit.json`, mêmes clés, même nombre d'entrées, chaque texte en pt-BR naturel. Ne rien ajouter, ne rien retirer.
8. `python3 outils/profils.py assembler base.json traduit.json` (écrit `edition-pt.json`), puis `python3 outils/publier.py jour edition-pt.json --texte` et l'audit sur `edition-pt.txt` (`--lang pt`). Corriger les alertes rouges dans `traduit.json` et réassembler.
9. Publication des deux profils en un envoi : `python3 outils/publier.py jour edition-fr.json edition-pt.json --pousser`. Une image "laissée distante" n'est pas une erreur. Si l'édition pt a échoué, publier `edition-fr.json` seul.
10. Historique : `python3 outils/historique.py ajouter base.json`, puis `python3 outils/historique.py envoyer`.

Le dimanche, après l'étape 10 : édition de la semaine selon `consignes/hebdo.md`.

## En cas d'échec

- Accès git refusé : produire quand même l'édition fr et l'envoyer par mail (étapes 6 et 7 du skill `actualites-quotidiennes` : render.py, build.py, Gmail `send_message` à adrien.etks@gmail.com, libellé Actualités). Puis un mail court à adrienroche6@gmail.com, objet "Actualités · app non mise à jour", avec le message d'erreur git exact.
- Aucune édition possible, seulement après avoir essayé la veille puis au moins 6 recherches WebSearch en mode extended : un seul mail court à adrienroche6@gmail.com, objet "Actualités · édition non produite", avec la cause en une phrase.
- Une rubrique sans matière fiable est omise ; une image qui échoue part sans image.
