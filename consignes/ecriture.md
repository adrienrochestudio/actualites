# Écriture : règles de la newsletter (français et portugais du Brésil)

Condensé du skill `.claude/skills/sans-trace-ia`, à appliquer en écrivant. L'audit (`python3 .claude/skills/sans-trace-ia/scripts/audit.py fichier.txt --lang fr` ou `--lang pt`) contrôle le lexique et le rythme : ne pas charger le skill ni ses lexiques, sauf `references/lexique-pt.md` au moment de la traduction.

## Fond

- Chaque phrase porte un fait : nom, chiffre, date, lieu. Jamais "un rôle majeur", "les experts", "de nombreux observateurs".
- Ne pas dire pourquoi un sujet est important : les faits le montrent. Pas de phrase finale "défis et perspectives", pas de conclusion morale.
- Toute affirmation vient d'une source lue le jour même, listée dans `sources`. Un calcul de la rédaction est signalé dans `note_sources`. Jamais un chiffre, une citation ou une source inventés.
- Pas de ton alarmiste ni promotionnel, pas de superlatif non chiffré. Titres non interrogatifs.

## Phrases

- Chaque phrase a un sujet et un verbe conjugué. Pas de groupe nominal posé comme une phrase ("Trois jours, dix-neuf pays.").
- Longueurs variées : des phrases de 5 mots à côté de phrases de 30. Pas trois phrases de suite qui commencent par le sujet.
- Pas de groupes de trois par réflexe. "Est", "a" plutôt que "constitue", "se positionne comme", "offre".
- Nommer le référent plutôt que l'anaphore vague ("ici", "dans ce cadre"). Répéter un mot plutôt que chercher un synonyme.
- Une énumération se présente en `liste`.

## Typographie

- Jamais de tiret cadratin. Pas de gras dans le texte, pas de majuscules forcées.
- Français : espace avant : ; ? !, guillemets « », 12 500, 3,5 %, 1,5 milliard.
- Mots bannis : plonger, souligner, significatif, crucial, de plus (sauf comparaison chiffrée), clé (figuré), essentiel, méticuleux, paysage (figuré), structurer (figuré), façonner, enrichir, et les autres alertes rouges de l'audit.

## Traduction FR vers pt-BR (profil Ana)

- Lire `references/lexique-pt.md` avant de traduire. Le texte doit se lire comme écrit par un journaliste de la Folha ou de Piauí, pas comme une traduction.
- Traduire le sens, puis réécrire chaque phrase à la brésilienne : sujet et verbe tôt, actif quand l'agent est connu, pas de connecteurs imposés par le français (en effet, ainsi, or).
- À éviter : « é que » en cascade, « de fato », « o fato de que », « ao nível de », « se trata de » mal placé, article oublié devant un pays.
- Ne changent pas : chiffres, noms, titres d'œuvres, dates, sources. Aucun arrondi, aucune source ajoutée ou retirée.
- Institutions françaises : garder le nom ou le sigle et l'expliquer au premier emploi (« o CNC, o Centro Nacional do Cinema francês »). Équivalent évident traduit directement (Senado, Ministério da Cultura), avec « francês » si besoin. Partis et médias gardent leur nom, avec une glose courte.
- Formats : 12.500 ; 4,2% ; 1,5 bilhão, 2 bilhões (jamais « mil milhões ») ; « 26 de outubro », jours et mois en minuscule ; 14h30 ; guillemets “ ”. Un montant en euros reste en euros ; équivalent en reais seulement si la source le donne (« R$ 210 milhões »), jamais calculé.
- Brésil : « você », orthographe de l'Accord de 1990.
