---
name: actualites-quotidiennes
description: Produit et envoie chaque matin la newsletter "Actualités" d'Adrien (une du jour, monde, chiffre, comprendre, finance, IA, cinéma ou écologie, brèves) sur adrien.etks@gmail.com. Utiliser quand la tâche planifiée du matin se lance, ou quand Adrien demande de produire, relancer ou corriger une édition d'Actualités.
---

# Actualités : édition quotidienne

Une exécution = une édition envoyée par Gmail, puis l'historique mis à jour, puis la boîte nettoyée. Rien d'autre.

## Interdits (coût et encombrement)

- Pas d'artefact, pas de fichier envoyé dans la conversation, pas d'écriture en mémoire, pas d'agent secondaire.
- Pas de HTML écrit à la main : Claude écrit uniquement `edition.json`, les scripts font le reste.
- Pas de recherche en mode "standard" pour l'actualité datée (elle ne renvoie que des liens). Utiliser "extended" avec des requêtes précises, et lancer chaque vague de recherches en parallèle dans un seul tour.
- Au plus 14 recherches et 10 lectures de page (WebFetch) par édition.

## Déroulé

1. **Date et dossier.** Date du jour (outil d'heure, fuseau Europe/Paris). Créer `editions/AAAA-MM-JJ/` dans le dossier de travail.
2. **Historique.** Lire le fichier Drive `Actualités - historique.txt` (id `1SwEcnwcOn9Y1luH09HJFqkQqpCjPoy_x`). Ne pas reprendre un sujet ni une notion "Comprendre" déjà traités dans les 60 jours.
3. **Recherche, vague 1** (parallèle) : une du matin, monde, chiffre, comprendre, finance, IA, cinéma ou écologie. Voir "Rubriques" et "Sources".
4. **Recherche, vague 2** (parallèle) : lectures de pages retenues, brèves, images (voir "Images"), coordonnées des villes peu connues.
5. **Rédaction.** Charger le skill `sans-trace-ia` et appliquer ses règles. Écrire `editions/AAAA-MM-JJ/edition.json` selon le schéma documenté en tête de `scripts/render.py`. Modèle complet : `exemples/edition-2026-10-19.json`.
6. **Rendu et contrôles.**
   ```
   python3 <skill>/scripts/render.py editions/AAAA-MM-JJ/edition.json
   python3 <skill>/scripts/build.py editions/AAAA-MM-JJ/edition.html
   python3 <chemin du skill sans-trace-ia>/scripts/audit.py editions/AAAA-MM-JJ/edition.txt --lang fr
   ```
   `build.py` bloque si le mail dépasse les limites : corriger le JSON (retirer une carte, raccourcir) et relancer. Corriger toute alerte rouge de l'audit dans le JSON, puis relancer render et build. Les alertes "de plus" dans une comparaison chiffrée ("25 % de plus") sont acceptées.
7. **Envoi.** `send_message` Gmail :
   - `to` : ["adrien.etks@gmail.com"]
   - `subject` : `Actualités · lundi 19 octobre 2026` (jour en minuscule)
   - `htmlBody` : contenu exact de `edition-mail.html`
   - `body` : `Actualités du lundi 19 octobre 2026.`
   - `attachments` : la liste de `edition-pieces.json`, telle quelle (filename, mimeType, inline: true, content)
   Puis `label_message` avec le libellé `Actualités` (id `Label_1`).
8. **Historique.** Réécrire le fichier Drive (update_file) : garder l'en-tête, ajouter une ligne par rubrique du jour au format `AAAA-MM-JJ | rubrique | sujet | notion ou villes`, supprimer les lignes de plus de 60 jours.
9. **Nettoyage.** `search_threads` avec `label:Actualités older_than:30d`, puis `trash_thread` sur chaque fil trouvé. Gmail vide la corbeille seul après 30 jours.

## En cas d'échec

- Une rubrique sans matière fiable : on l'omet, l'édition part quand même.
- Une image ou une carte qui échoue : l'article part sans image.
- Échec complet (aucune édition possible) : un seul mail court, objet `Actualités · édition non produite`, avec la cause en une phrase.

## Rubriques (ordre fixe)

Édition longue assumée (environ 2 800 mots hors brèves). Faits précis, chiffres, dates, noms. Jamais de généralités.

- **Une** (`une`) : une seule info, l'actualité brûlante du matin, en 3 ou 4 lignes. Pas un résumé de l'édition. Factuelle, pas alarmiste.
- **Monde** : géopolitique ou géoéconomie internationale hors du flux habituel. Exclus sauf cas exceptionnel : bombardements en Iran ou en Ukraine, Trump. Préférer Afrique, Asie, Amérique latine, matières premières, accords commerciaux.
- **Le chiffre** : une statistique de source fiable (AIE, Eurostat, INSEE, FMI, OCDE, Banque mondiale, BRI, Our World in Data). Le titre est le chiffre lui-même. Expliquer l'ordre de grandeur et ce qu'il dit.
- **Comprendre** : le cœur. Une notion complexe de finance ou de géoéconomie, expliquée à partir d'une actu de la semaine, avec sous-titres. Un schéma (`schema`) quand un circuit d'argent ou un montage s'y prête.
- **Finance** : 3 ou 4 mouvements de marché de la semaine ou de la veille (indices, taux, pétrole, or, devises, une action). Pour chacun : niveau, variation, et la raison précise du mouvement.
- **Intelligence artificielle** : nouveauté Claude ou Anthropic en priorité, puis OpenAI, Mistral, modèles chinois, marché, matières premières de l'IA, ou article critique.
- **Cinéma** (par défaut) ou **Écologie** (si l'actu environnement du jour est plus forte) : industrie du cinéma et du divertissement, plutôt France.
- **À retenir** : 2 phrases en fin de chaque rubrique sauf Le chiffre.
- **Brèves** (`breves`), dans cet ordre : Paris, Portugal, Brésil, Europe, Afrique, Amériques, Asie, Océanie. 2 ou 3 items par rubrique, une rubrique sans info notable est omise. Chaque brève donne le contexte nécessaire pour être comprise seule (qui est qui, pourquoi ça compte), comme dans l'exemple pour Yasukuni ou le prix Sakharov.

## Sources qui ont fonctionné

- Revue de presse du jour : `https://www.presse-evasion.fr/article/revue-presse-JJ-MM-AAAA`
- Brèves par continent : The Rio Times, "Africa / Asia Intelligence Brief" et "LatAm Expat & Nomad Daily Guide" du jour ou de la veille (riotimesonline.com)
- Europe : `https://www.eubusiness.com/politics/eucalendar/` (agenda de la semaine), consilium.europa.eu
- Marchés : finance.yahoo.com "Markets News" du jour, investing.com (or, pétrole), cnbc.com
- Chiffres : iea.org/reports, ec.europa.eu/eurostat, insee.fr, worldbank.org
- IA : anthropic.com/news, mistral.ai/news, presse tech reconnue. Éviter les agrégateurs de faible qualité.
- Cinéma : cnc.fr (communiqués de fréquentation, début de mois), lefilmfrancais.com, ecrantotal.fr
- Paris : paris.fr ; Portugal : observador.pt, eco.sapo.pt ; Brésil : agenciabrasil.ebc.com.br, dgabc.com.br
- Certaines pages refusent la lecture (robots, erreur client) : passer à une autre source, ne pas insister.

## Images

Viser une illustration pour environ 60 % des rubriques, seulement si elle apporte quelque chose.

- **Licences libres uniquement**, chargées par URL (`"url"` dans le JSON, coût nul) : Wikimedia Commons, Our World in Data, institutions publiques sous CC BY. Jamais d'image de presse, d'affiche de film ou de photo de célébrité.
- **Portrait** : seulement d'une personne peu médiatisée (un président de petit pays, un ministre, un dirigeant d'entreprise peu connu). Jamais Trump ni une figure vue partout.
- **Wikimedia** : trouver le fichier via l'API, avec un User-Agent :
  `curl -s -A "ActualitesNewsletter/1.0" "https://commons.wikimedia.org/w/api.php?action=query&list=search&srsearch=NOM&srnamespace=6&format=json"`
  puis `prop=imageinfo&iiprop=url|extmetadata&iiurlwidth=500` sur le fichier choisi. Utiliser le `thumburl` à 500 px, créditer auteur et licence (`credit`).
- **Cartes de données** : Our World in Data, URL `https://ourworldindata.org/grapher/<graphique>.png?tab=map`, avec `"lien"` vers la version interactive et le crédit "Our World in Data, CC BY".
- **Mini-cartes** (`carte`) : pour toute ville peu connue citée dans une rubrique principale (Hangzhou, El Paso, Yanbu…), pas pour Paris, Londres, Pékin ou une capitale évidente. **3 au plus par édition** (elles sont jointes au mail, donc payées en tokens). Ville frontalière : préciser `"pays"` (nom Natural Earth, ex. "United States of America"). Légende : où se trouve la ville et pourquoi elle compte.
- Une carte de presse meilleure que tout ce qui existe en libre (Les Échos, Le Monde) : un lien "voir la carte" dans le texte ou la légende, jamais l'image.

## Écriture

- Skill `sans-trace-ia` obligatoire. Jamais de tiret cadratin. Pas de majuscules forcées.
- Mots bannis : plonger, souligner, significatif, crucial, de plus (sauf comparaison chiffrée), clé, essentiel, méticuleux, paysage (figuré), structurer (figuré), façonner, enrichir.
- Phrases courtes et directes. Chaque phrase porte un fait. Pas de ton alarmiste ni promotionnel.
- Toute affirmation vient d'une source lue ce jour-là ; les sources sont listées en fin de rubrique. Un calcul fait par la rédaction est signalé (`note_sources`).
- Titres non interrogatifs.

## Fichiers du skill

- `scripts/render.py` : JSON vers HTML, gabarit et typographie figés (schéma du JSON en tête du fichier)
- `scripts/build.py` : compression, contrôles de taille, versions aperçu, mail et texte
- `scripts/locator.py` : mini-cartes (gris et noir, serif)
- `scripts/logo.py` : régénère le logo (globe bordeaux #6B1D2A) dans `assets/`
- `assets/` : logo (96 px pour le mail, 512 px, SVG)
- `geo/pays.geojson` : frontières Natural Earth 1:50m allégées
- `exemples/edition-2026-10-19.json` : édition de référence validée par Adrien
