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
| Le chiffre du jour | Politique du Brésil |
| Comprendre | Le chiffre du jour |
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
- Faits précis, chiffres, dates, noms. Jamais de généralités. Ne jamais écrire ce que les sources ne disent pas (« le chiffre n'est pas donné ») : chercher l'information ou ne pas en parler.
- Pas deux rubriques sur le même sujet, la même entreprise ou le même événement : une actualité dominante va dans une seule rubrique, les autres prennent d'autres sujets.
- Les longueurs sont des cibles à atteindre, pas des plafonds. `publier.py` refuse une rubrique sous 75 % de sa cible, moins de 80 % de rubriques illustrées, trop peu de données, de portraits ou de logos (voir Visuels), une zone de brèves à un seul item. "À retenir" : 2 phrases en fin de chaque rubrique sauf Le chiffre du jour.

## Rubriques (longueurs indicatives en mots)

- **Une** (`une`, 60) : l'actualité brûlante du matin, factuelle, pas alarmiste. Pas un résumé de l'édition.
- **Monde** (450) : géopolitique ou géoéconomie hors du flux habituel. Préférer Afrique, Asie, Amérique latine, matières premières, accords commerciaux.
- **France** (350) : politique, économie, société, sciences ou régions ; une décision ou un fait à impact réel, hors polémiques du jour. Paris y entre quand c'est utile.
- **Brésil** (350) : société, économie, culture, sciences, environnement. Pas la politique nationale.
- **Politique du Brésil** (350, Ana) : institutions, lois, budget, décisions des ministères, États et villes. Les figures nationales seulement quand une décision en découle. Pas de petites phrases ni de sondages.
- **Le chiffre du jour** (250, affiché en encart) : une statistique de source fiable (AIE, Eurostat, INSEE, FMI, OCDE, Banque mondiale, BRI, Our World in Data). Le titre est le chiffre. Expliquer l'ordre de grandeur et ce qu'il dit.
- **Comprendre** (600) : une notion de finance ou de géoéconomie expliquée à partir d'une actu de la semaine, avec sous-titres, et un `schema` quand un circuit d'argent ou un montage s'y prête.
- **Finance** (350) : 3 ou 4 mouvements de marché de la veille ou de la semaine (indices, taux, pétrole, or, devises, une action) : niveau, variation, raison précise.
- **Intelligence artificielle** (400) : nouveauté Claude ou Anthropic en priorité (lire anthropic.com/news, qui n'a pas de flux), puis OpenAI, Mistral, modèles chinois, marché, matières premières de l'IA, ou article critique.
- **IA, technique** (550) : un mécanisme technique de l'IA expliqué à un non-ingénieur (refroidissement d'un data center, token, choix du mot suivant, skills et mods de Claude, MCP, quantification, entraînement contre inférence, GPU, InfiniBand, fenêtre de contexte...). Partir d'une situation concrète, définir chaque terme à sa première apparition, `schema` obligatoire, chiffres réels et sourcés (documentation officielle, Nvidia, Google, AIE, Uptime Institute, recherche).
- **Architecture** (350, Ana) : un projet, un bâtiment, un concours, un prix, l'urbanisme ou les matériaux, au Brésil ou ailleurs. Photo Wikimedia Commons obligatoire, architecte et année dans la légende : choisir un sujet qui a une photo libre. Une nouveauté sans photo libre (cas fréquent des projets publiés par ArchDaily) passe en mention dans le texte, et la rubrique porte sur un bâtiment, un architecte ou un lieu lié qui en a une.
- **Cinéma** (300) : industrie du cinéma et de l'audiovisuel, plutôt France (fréquentation, financement, tournages, festivals, métiers). Pas de classement du box-office.
- **Environnement** (350) : climat, énergie, biodiversité, pollution ; un fait mesuré et ce qu'il change. Les solutions qui fonctionnent ont leur place.
- **Carte expliquée** (350) : une seule carte, lue en détail : ce qu'elle représente, comment la lire, ce qu'on y voit d'étonnant, ce qui l'explique. Pleine largeur (`"largeur": 1100`), Our World in Data (`?tab=map`), Wikimedia Commons ou institution publique sous licence libre, avec `"lien"` vers la version interactive. Sans lien obligatoire avec l'actualité.
- **Quiz** (`quiz`) : 10 questions sur l'édition du jour, en fin d'édition, au moins une par rubrique commune aux deux profils, le reste sur les brèves. Chaque question porte sur un fait ou un mécanisme expliqué dans une rubrique (un chiffre, un acteur, une cause), pas sur un détail anecdotique. 3 ou 4 choix plausibles, un seul juste (`reponse` : index à partir de 0, à varier d'une question à l'autre), `explication` en une ou deux phrases qui rappelle la rubrique. Les questions portent sur des rubriques présentes dans les deux profils (Une, Monde, France, Brésil, Le chiffre du jour, Cinéma, Environnement, Carte expliquée, brèves), pour que le quiz traduit corresponde à l'édition d'Ana.
- **Brèves** (`breves`), dans cet ordre : Portugal, Europe, Afrique, Amériques, Asie, Océanie. 2 ou 3 items par zone, une zone sans info notable est omise. Chaque brève donne le contexte pour être comprise seule (qui est qui, pourquoi ça compte).

## Réseau et sources

- Dans `sources`, `titre` est le nom court du média ou de l'institution (« Jerusalem Post », « CNBC », « FMI »), jamais une description de l'article. Un même média n'apparaît qu'une fois par rubrique.

- Le shell de la tâche n'atteint pas les sites de presse ni Wikimedia (proxy 403) : c'est normal. Seuls git, GitHub et les dépôts de paquets passent. Toute lecture du web passe par les outils WebSearch et WebFetch, qui fonctionnent.
- La veille (flux de `consignes/veille.txt`) tourne chaque nuit dans GitHub Actions et attend sur la branche `veille` (étape 2). Lire ensuite les articles retenus avec WebFetch, sur l'adresse directe de l'article (jamais une adresse de redirection Google).
- WebSearch : toujours `mode: "extended"` pour l'actualité datée (le mode standard ne renvoie que des liens). Requêtes précises (sujet, lieu, date), lancées en parallèle dans un seul tour.
- Compléments : anthropic.com/news et mistral.ai/news (IA) ; iea.org/reports, ec.europa.eu/eurostat, insee.fr, worldbank.org (chiffres) ; cnc.fr (fréquentation, début de mois) ; paris.fr ; consilium.europa.eu.
- Une page qui refuse la lecture : passer à une autre source, ne pas insister. Éviter les agrégateurs de faible qualité.

## Visuels

L'édition doit être très illustrée, avec des images qui apprennent quelque chose : un visage qu'on ne connaît pas, une donnée lisible d'un coup d'œil, un lieu qu'on ne situe pas. Une image décorative ne compte pas. Licences libres uniquement, chargées par `"url"` : jamais d'image de presse, d'affiche de film ni de photo de célébrité.

Chaque image porte `"nature"` : `portrait`, `logo`, `donnees`, `photo` ou `carte_lieu`. Minimums par édition de base, vérifiés par `publier.py` :
- 80 % des rubriques illustrées ;
- 3 visuels `donnees` au moins (graphiques et cartes Our World in Data, cartes thématiques Wikimedia), dont celui de Carte expliquée ;
- 2 `portrait` ou `logo` au moins.

Ce qu'on cherche, dans cet ordre :
- **Portraits des personnes importantes peu médiatisées** : le candidat de l'opposition, une ministre des Finances africaine, le dirigeant d'une entreprise peu connue, un chercheur, un architecte, un juge. Exemple : Gadi Eisenkot plutôt que Nétanyahou. Jamais Trump, Bolsonaro, Lula, Macron ni une figure vue partout. Petit (`"largeur": 360`), seul ou dans un `duo` avec une mini-carte ou un logo. Légende : nom, fonction, et pourquoi il compte aujourd'hui.
- **Logos des organisations dont on parle** quand elles sont peu connues du grand public (S&P Global Ratings, IMIP, FIAPF, une agence de l'ONU, une entreprise chinoise) : logo Wikimedia Commons (`PD-textlogo` ou licence libre), petit (`"largeur": 240`), de préférence dans un `duo`.
- **Données** : graphiques et cartes Our World in Data (`https://ourworldindata.org/grapher/<graphique>.png?tab=map` ou `tab=chart`, `"lien"` vers la version interactive, crédit "Our World in Data, CC BY"). Chercher le graphique avec WebFetch sur `https://ourworldindata.org/search?q=<sujet>`. Choisir celui qui montre le point de l'article (le pays dans son contexte, l'évolution, l'écart). Pleine largeur (`"largeur": 1100`). Cartes thématiques Wikimedia Commons aussi.
- **Mini-cartes** (`carte`, générées par `publier.py`) pour chaque ville ou région peu connue citée, sans limite ; pas pour une capitale évidente. Ville frontalière : préciser `"pays"` (nom Natural Earth).
- **Photos** Wikimedia Commons d'un lieu, d'un bâtiment, d'un objet technique (data center, puce, port, mine), en pleine largeur.
- **Schémas** (`schema`) pour un mécanisme, un circuit d'argent, un montage : de vrais schémas, pas une suite de cases. Des nœuds (acteurs, étapes, objets) avec leur `valeur` chiffrée quand elle existe et un `detail` court, et des `liens` libellés qui disent ce qui circule (argent, énergie, données, décisions) et combien. Au moins un embranchement ou une convergence quand le sujet en a ; `accent` sur le nœud central. 3 nœuds au plus par étage, textes courts (4 à 6 mots par nœud, 8 par lien). Format dans `outils/schema.py`, dessiné en image à la publication. L'ancien format `etapes` est refusé.
- **Barres** (`barres`) pour comparer 2 à 8 quantités quand Our World in Data n'a pas le bon graphique (dette par créancier, parts de marché, budgets) : chiffres sourcés, `accent` sur la barre dont parle l'article. Compte comme visuel de données.

La Une porte une image quand elle nomme une personne ou une organisation peu connue : `"une": {"texte": ..., "image": {...}, "sources": [...]}`.

Wikimedia Commons, avec WebFetch (pas curl) : `https://commons.wikimedia.org/w/api.php?action=query&list=search&srsearch=NOM&srnamespace=6&srlimit=5&format=json`, puis `https://commons.wikimedia.org/w/api.php?action=query&prop=imageinfo&iiprop=url|extmetadata&iiurlwidth=1100&format=json&titles=File:...` ; utiliser `thumburl` (`iiurlwidth=500` pour un portrait ou un logo), créditer auteur et licence dans `credit`. Les images ne sont pas copiées dans le site (réseau du shell) : l'app les charge elle-même, c'est prévu.

Légendes : dire ce qu'il faut regarder dans l'image (la zone, la courbe, l'écart), pas seulement ce que c'est. Une carte de presse meilleure que tout ce qui existe en libre (Les Échos, Le Monde) : un lien "voir la carte" dans la légende, jamais l'image.

## Déroulé

Dépendances : Pillow et matplotlib (`pip install pillow matplotlib` si l'import échoue). Schéma du JSON : en tête de `outils/publier.py`. Au plus 12 recherches web et 26 lectures de page : la veille remplace le reste.

0. Journal d'exécution : à chaque étape numérotée terminée, et à tout arrêt, `python3 outils/historique.py journal "<étape>" "<ok, ou cause exacte>"` (il pousse aussitôt). Il sert à comprendre un échec sans relancer. Ne jamais s'arrêter sans une ligne de journal qui donne la cause.
1. Historique : `git fetch origin historique`, `git worktree add -B historique historique origin/historique`. Puis `python3 outils/historique.py notions` (notions et dossiers récents à ne pas refaire). Ne pas lire les fichiers de l'historique.
2. Veille : `git fetch origin veille && git worktree add veille FETCH_HEAD`, puis lire `veille/veille.txt` (sa première ligne donne l'heure de la veille). Choisir les sujets, `python3 outils/veille.py lien <numéros>` pour leurs adresses, lire les articles retenus avec WebFetch. Recherches web seulement pour ce que la veille ne couvre pas (Le chiffre du jour, Carte expliquée, IA, technique, compléments).
   Si la branche `veille` manque ou date de plus de 12 heures : chercher l'actualité avec WebSearch en mode extended, une requête par rubrique, jusqu'à 18 recherches.
3. Pistes pour le dimanche : pour 1 à 3 sujets de fond repérés et non traités, `python3 outils/historique.py piste "thème" "sujet en une ligne" "url"`. Thèmes : Géopolitique, Environnement, Société, Finance, IA, Architecture, Politique du Brésil.
4. Rédaction de `base.json` en français, toutes les rubriques des deux profils et les brèves. Puis `python3 outils/historique.py verifier base.json` : changer de sujet si une rubrique reprend un sujet déjà traité.
5. Contrôle FR : `python3 outils/publier.py jour base.json --texte`. Compléter tout ce qu'il liste en MANQUES (relancer jusqu'à ce qu'il n'en liste plus), puis l'audit sur `base.txt` (`--lang fr`). Corriger les alertes rouges dans le JSON. Les alertes "de plus" dans une comparaison chiffrée sont acceptées.
6. `python3 outils/profils.py preparer base.json` : écrit `edition-fr.json` et `a-traduire.json` (les seuls textes d'Ana).
7. Traduction selon `consignes/ecriture.md` : écrire `traduit.json`, mêmes clés, même nombre d'entrées, chaque texte en pt-BR naturel. Ne rien ajouter, ne rien retirer.
8. `python3 outils/profils.py assembler base.json traduit.json` (écrit `edition-pt.json`), puis `python3 outils/publier.py jour edition-pt.json --texte` et l'audit sur `edition-pt.txt` (`--lang pt`). Corriger les alertes rouges dans `traduit.json` et réassembler.
9. Publication des deux profils en un envoi : `python3 outils/publier.py jour edition-fr.json edition-pt.json --pousser`. Une image "laissée distante" n'est pas une erreur. S'il refuse pour des MANQUES, compléter et relancer ; `--forcer` seulement après 7h40, heure de Paris, pour ne pas manquer 8h. Si l'édition pt a échoué, publier `edition-fr.json` seul.
10. Historique : `python3 outils/historique.py ajouter base.json`, puis `python3 outils/historique.py envoyer`.

Relance : une exécution lancée alors que l'édition du jour est déjà en ligne est une relance voulue par Adrien, pour obtenir une meilleure édition. Refaire tout le déroulé et remplacer l'édition en ligne, sans exception. Les sujets de l'édition remplacée peuvent être repris, en mieux ; `historique.py` ignore déjà les lignes du jour et `ajouter` les remplace.

Le dimanche, après l'étape 10 : édition de la semaine selon `consignes/hebdo.md`.

## En cas d'échec

Aucun mail, jamais : tout passe par l'app et par la notification de fin de tâche. Ne pas utiliser Gmail.
- Accès git refusé : ne rien publier ; terminer par une phrase qui donne le message d'erreur git exact (elle apparaît dans la notification).
- Aucune édition possible, seulement après avoir essayé la veille puis au moins 6 recherches WebSearch en mode extended : terminer par une phrase qui donne la cause. L'édition de la veille reste en ligne.
- Une rubrique sans matière fiable est omise ; une image qui échoue part sans image.
