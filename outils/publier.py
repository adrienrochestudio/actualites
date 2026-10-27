#!/usr/bin/env python3
"""Publie une édition d'Actualités dans l'app (branche `pages`, servie par GitHub Pages).

Usage :
  python3 outils/publier.py [jour|semaine] a.json [b.json]             construit _site/ et contrôle
  python3 outils/publier.py [jour|semaine] a.json [b.json] --pousser   idem puis publie sur `pages`
  python3 outils/publier.py [jour|semaine] a.json --texte              écrit le .txt (audit sans-trace-ia)
  Sans genre : "jour". Le profil de chaque JSON vient de son champ "langue" ("fr" par défaut).
  Publier les deux profils en une commande : un seul envoi sur `pages`.

Le dépôt garde trois branches :
- main       : le code de l'app et ces outils.
- pages      : le site publié = l'app + pour chaque profil (fr : Adrien, pt : Ana) l'édition du jour
               ({profil}/edition/) et l'édition de la semaine ({profil}/hebdo/).
               Un unique commit, réécrit à chaque publication : l'historique ne grossit pas.
               Publier un contenu reprend les autres tels qu'ils sont en ligne ; si pages change pendant
               la construction, la publication recommence.
- historique : sujets déjà traités.

Schéma de edition.json (textes en texte brut) :
{
  "langue": "fr" ou "pt",
  "date_texte": "Lundi 19 octobre 2026" (pt : "Segunda-feira, 19 de outubro de 2026"),
  "une": {"texte": "...", "sources": [{"titre": "...", "url": "..."}]},
  "rubriques": [
    {"etiquette": "Monde", "titre": "...",
     "blocs": [
       {"type": "p", "texte": "..."},
       {"type": "sous_titre", "texte": "..."},
       {"type": "liste", "items": ["...", "..."]},
       {"type": "image", "url": "https://...", "largeur": 552, "legende": "...", "lien": "https://...",
        "credit": {"titre": "...", "url": "..."}},
       {"type": "duo", "elements": [{"url": "...", "largeur": 220, "legende": "..."}, {"type": "carte", ...}]},
       {"type": "carte", "ville": "El Paso", "lat": 31.76, "lon": -106.49, "pays": "United States of America", "legende": "..."},
       {"type": "schema", "etapes": [{"boite": "ligne 1\\nligne 2"}, {"fleche": "..."}], "legende": "..."}
     ],
     "a_retenir": "...",
     "sources": [{"titre": "...", "url": "..."}],
     "note_sources": "phrase facultative après les sources"}
  ],
  "breves": [{"rubrique": "Paris", "items": ["..."], "sources": [{"titre": "...", "url": "..."}]}]
}
Schéma de hebdo.json (édition de la semaine, mêmes blocs) :
{
  "date_texte": "Lundi 26 octobre 2026",
  "date_texte_semaine": "Semaine du 26 octobre 2026",
  "sujets": [
    {"etiquette": "Géoéconomie", "titre": "...", "chapo": "deux phrases qui donnent envie de lire",
     "couverture": {"url": "https://...", "legende": "...", "credit": {...}}  (ou une carte : {"type": "carte", "ville": ..., "lat": ..., "lon": ...}),
     "blocs": [...], "a_retenir": "...", "sources": [...], "note_sources": "..."}
  ]
}

Images : "url" = image publique sous licence libre (https), l'app l'enregistre pour le hors ligne ;
"fichier" = image locale relative au dossier du JSON, copiée dans le site. Les cartes sont générées ici.
Ajoutés par ce script : "date" (AAAA-MM-JJ), "publie" (horodatage), "src" sur les images locales et cartes.
"""
import argparse
import datetime as dt
import hashlib
import io
import json
import os
import re
import shutil
import subprocess
import sys
import time
import urllib.request

from PIL import Image

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(RACINE, "outils"))
import locator  # noqa: E402

FICHIERS_APP = [
    "index.html", "styles.css", "app.js", "edition.js", "rendu.js", "sw.js", "manifest.webmanifest",
    "icons/logo-96.png", "icons/icon-180.png", "icons/icon-192.png", "icons/icon-512.png",
    "icons/icon-512-maskable.png", "textes.js", "globe.js", "geo/terre.json",
    "fonts/source-serif-4-var.woff2", "fonts/source-serif-4-var-italic.woff2", "fonts/LICENSE-OFL.txt",
]
TYPES = {"p", "sous_titre", "liste", "image", "duo", "carte", "schema"}
MOIS = {
    "fr": ["janvier", "février", "mars", "avril", "mai", "juin", "juillet", "août",
           "septembre", "octobre", "novembre", "décembre"],
    "pt": ["janeiro", "fevereiro", "março", "abril", "maio", "junho", "julho", "agosto",
           "setembro", "outubro", "novembro", "dezembro"],
}
PROFILS = ("fr", "pt")
LIMITE_SITE = 10 * 1024 * 1024  # deux profils, chacun avec ses images
MOTS_DOSSIER = 1200
MAX_IMAGE = 4 * 1024 * 1024
LARGEUR_MAX = 1100
AGENT = "ActualitesApp/1.0 (+https://github.com/adrienrochestudio/actualites)"


def erreur(msg):
    sys.exit(f"ERREUR : {msg}")


def date_iso(date_texte, langue="fr"):
    m = re.fullmatch(r"\s*[\w-]+,?\s+(\d{1,2})(?:er|º)?\s+(?:de\s+)?(\w+)\s+(?:de\s+)?(\d{4})\s*", date_texte.lower())
    if not m or m.group(2) not in MOIS[langue]:
        erreur(f"date_texte illisible : {date_texte!r} (attendu : 'Lundi 19 octobre 2026' "
               f"ou 'Segunda-feira, 19 de outubro de 2026')")
    return dt.date(int(m.group(3)), MOIS[langue].index(m.group(2)) + 1, int(m.group(1))).isoformat()


def slug(t):
    t = t.lower()
    for a, b in (("àâä", "a"), ("éèêë", "e"), ("îï", "i"), ("ôö", "o"), ("ùûü", "u"), ("ç", "c")):
        for c in a:
            t = t.replace(c, b)
    return re.sub(r"[^a-z0-9]+", "-", t).strip("-")


# Les deux contenus publiés. Chaque publication remplace le sien et reprend l'autre tel qu'il est en ligne.
GENRES = {
    "jour": {"dossier": "edition", "fichier": "edition.json", "liste": "rubriques"},
    "semaine": {"dossier": "hebdo", "fichier": "hebdo.json", "liste": "sujets"},
}


def verifier(ed, genre):
    if ed.setdefault("langue", "fr") not in PROFILS:
        erreur(f"langue inconnue : {ed['langue']} (attendu : {', '.join(PROFILS)})")
    liste = GENRES[genre]["liste"]
    for cle in ("date_texte", liste):
        if cle not in ed:
            erreur(f"champ manquant : {cle}")
    for r in ed[liste]:
        for cle in ("etiquette", "titre", "blocs"):
            if cle not in r:
                erreur(f"{liste[:-1]} sans {cle} : {r.get('titre', r.get('etiquette'))}")
        if genre == "semaine" and not r.get("couverture"):
            erreur(f"sujet sans couverture : {r['titre']}")
        if genre == "semaine":
            mots = len(" ".join([b.get("texte", "") for b in r["blocs"]] + sum((b.get("items", []) for b in r["blocs"]), [])).split())
            if mots < MOTS_DOSSIER:
                erreur(f"dossier trop court ({mots} mots, minimum {MOTS_DOSSIER}) : {r['titre']}")
        for b in r["blocs"]:
            if b.get("type") not in TYPES:
                erreur(f"type de bloc inconnu : {b.get('type')} ({r['etiquette']})")
    for url in re.findall(r'"(?:url|lien)":\s*"([^"]+)"', json.dumps(ed)):
        if not url.startswith("https://"):
            erreur(f"URL non https : {url}")


def images(ed, genre):
    """Tous les blocs, éléments et couvertures qui portent une image ou une carte."""
    for r in ed[GENRES[genre]["liste"]]:
        if r.get("couverture"):
            yield r["couverture"]
        for b in r["blocs"]:
            if b["type"] in ("image", "carte"):
                yield b
            elif b["type"] == "duo":
                yield from b.get("elements", [])


def compresser(png):
    im = Image.open(png).convert("RGB").quantize(colors=48, method=Image.Quantize.MEDIANCUT)
    im.save(png, optimize=True)


def preparer(ed, genre, dossier_json, site):
    rel = f"{ed['langue']}/{GENRES[genre]['dossier']}/img"
    dossier_img = os.path.join(site, rel)
    os.makedirs(dossier_img, exist_ok=True)
    for el in images(ed, genre):
        if el.get("type") == "carte" or ("ville" in el and "lat" in el):
            nom = f"loc-{slug(el['ville'])}.png"
            cible = os.path.join(dossier_img, nom)
            if not os.path.exists(cible):
                locator.carte(el["ville"], float(el["lat"]), float(el["lon"]), cible, nom_pays=el.get("pays"))
                compresser(cible)
            el["type"] = el.get("type") or "carte"
            el["src"] = f"{rel}/{nom}"
        elif el.get("fichier"):
            source = os.path.join(dossier_json, el["fichier"])
            nom = os.path.basename(el["fichier"])
            shutil.copyfile(source, os.path.join(dossier_img, nom))
            el["src"] = f"{rel}/{nom}"
            el.pop("fichier")
        elif el.get("url"):
            nom = telecharger(el["url"], dossier_img)
            if nom:
                el["src"] = f"{rel}/{nom}"
        else:
            erreur(f"image sans url ni fichier : {el.get('legende', '')[:60]}")


def telecharger(url, dossier):
    """Copie locale d'une image libre. En cas d'échec, l'app la chargera elle-même sur l'appareil."""
    req = urllib.request.Request(url, headers={"User-Agent": AGENT})
    try:
        with urllib.request.urlopen(req, timeout=20) as rep:
            donnees = rep.read(MAX_IMAGE + 1)
        if len(donnees) > MAX_IMAGE:
            raise ValueError("image trop lourde")
        im = Image.open(io.BytesIO(donnees))
        im.load()
    except Exception as exc:  # réseau, statut HTTP, format : l'image reste distante
        print(f"  image laissée distante ({exc.__class__.__name__}) : {url[:90]}")
        return None
    if im.width > LARGEUR_MAX:
        im = im.resize((LARGEUR_MAX, round(im.height * LARGEUR_MAX / im.width)), Image.LANCZOS)
    nom = f"img-{hashlib.sha1(url.encode()).hexdigest()[:10]}"
    if im.mode in ("RGBA", "LA", "P"):
        nom += ".png"
        im.save(os.path.join(dossier, nom), optimize=True)
    else:
        nom += ".jpg"
        im.convert("RGB").save(os.path.join(dossier, nom), quality=82, optimize=True, progressive=True)
    return nom


def distant():
    return subprocess.run(["git", "remote", "get-url", "origin"], cwd=RACINE, check=True,
                          capture_output=True, text=True).stdout.strip()


def reprendre_en_ligne(site, publies):
    """Copie dans le site les contenus en ligne sur pages qui ne sont pas republiés maintenant.
    `publies` : ensemble de chemins "{profil}/{dossier}". Renvoie le commit lu (None si pages n'existe pas).
    Migration : un contenu de l'ancienne organisation (edition/, hebdo/ à la racine) devient fr/edition/, fr/hebdo/."""
    tmp = os.path.join(RACINE, "_pages")
    shutil.rmtree(tmp, ignore_errors=True)
    r = subprocess.run(["git", "clone", "-q", "--depth", "1", "--branch", "pages", distant(), tmp],
                       capture_output=True, text=True)
    if r.returncode != 0:
        return None  # branche pages absente : premier déploiement
    sha = subprocess.run(["git", "rev-parse", "HEAD"], cwd=tmp, capture_output=True, text=True).stdout.strip()
    for g in GENRES.values():
        for profil in PROFILS:
            chemin = f"{profil}/{g['dossier']}"
            if chemin in publies:
                continue
            source = os.path.join(tmp, chemin)
            ancien = os.path.join(tmp, g["dossier"])
            if os.path.isdir(source):
                shutil.copytree(source, os.path.join(site, chemin))
            elif profil == "fr" and os.path.isfile(os.path.join(ancien, g["fichier"])):
                shutil.copytree(ancien, os.path.join(site, chemin))
                f = os.path.join(site, chemin, g["fichier"])
                ed = json.load(open(f, encoding="utf-8"))
                ed["langue"] = "fr"
                brut = json.dumps(ed, ensure_ascii=False, separators=(",", ":"))
                open(f, "w", encoding="utf-8").write(brut.replace(f'"{g["dossier"]}/img/', f'"{chemin}/img/'))
    shutil.rmtree(tmp, ignore_errors=True)
    return sha


def copies_anciennes(site):
    """Transition (à retirer après le 30 novembre 2026) : les apps pas encore mises à jour lisent
    edition/edition.json et hebdo/hebdo.json. On y recopie le JSON du profil fr ; les images restent sous fr/."""
    for g in GENRES.values():
        source = os.path.join(site, "fr", g["dossier"], g["fichier"])
        if os.path.isfile(source):
            os.makedirs(os.path.join(site, g["dossier"]), exist_ok=True)
            shutil.copyfile(source, os.path.join(site, g["dossier"], g["fichier"]))


def construire(chemins_json, genre, reprendre=True):
    g = GENRES[genre]
    eds = []
    for chemin in chemins_json:
        ed = json.load(open(chemin, encoding="utf-8"))
        verifier(ed, genre)
        ed["date"] = date_iso(ed["date_texte"], ed["langue"])
        ed["publie"] = dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds")
        eds.append((chemin, ed))
    publies = {f"{ed['langue']}/{g['dossier']}" for _, ed in eds}
    if len(publies) != len(eds):
        erreur("deux éditions du même profil dans une seule publication")

    site = os.path.join(RACINE, "_site")
    shutil.rmtree(site, ignore_errors=True)
    for f in FICHIERS_APP:
        cible = os.path.join(site, f)
        os.makedirs(os.path.dirname(cible), exist_ok=True)
        shutil.copyfile(os.path.join(RACINE, f), cible)
    open(os.path.join(site, ".nojekyll"), "w").close()

    base = reprendre_en_ligne(site, publies) if reprendre else None
    resume = []
    for chemin, ed in eds:
        preparer(ed, genre, os.path.dirname(os.path.abspath(chemin)), site)
        with open(os.path.join(site, ed["langue"], g["dossier"], g["fichier"]), "w", encoding="utf-8") as f:
            json.dump(ed, f, ensure_ascii=False, separators=(",", ":"))
        nb_cartes = sum(1 for el in images(ed, genre) if el.get("type") == "carte")
        resume.append(f"{ed['langue']} {ed['date']} : {len(ed[g['liste']])} articles, {nb_cartes} carte(s)")
    copies_anciennes(site)

    total = sum(os.path.getsize(os.path.join(d, x)) for d, _, fs in os.walk(site) for x in fs)
    if total > LIMITE_SITE:
        erreur(f"site trop lourd : {total // 1024} Ko (limite {LIMITE_SITE // 1024} Ko)")
    print(f"{'Édition' if genre == 'jour' else 'Semaine'} : {' ; '.join(resume)} ; site {total // 1024} Ko")
    return site, max(ed["date"] for _, ed in eds), base


# Contrôle de l'édition du jour : longueurs (mots du corps), visuels, brèves, sources.
# Mêmes cibles pour le français et le portugais ; étiquettes des deux langues.
CIBLES = {
    "Monde": 450, "Mundo": 450, "France": 350, "França": 350, "Brésil": 350, "Brasil": 350,
    "Politique du Brésil": 350, "Política brasileira": 350, "Le chiffre": 250, "O número": 250,
    "Comprendre": 600, "Entender": 600, "Finance": 350, "Finanças": 350,
    "Intelligence artificielle": 400, "Inteligência artificial": 400, "IA, technique": 550, "IA, técnica": 550,
    "Architecture": 350, "Arquitetura": 350, "Cinéma": 300, "Cinema": 300,
    "Environnement": 350, "Meio ambiente": 350, "Carte expliquée": 350, "Mapa explicado": 350,
}
IMAGE_OBLIGATOIRE = {"Architecture", "Arquitetura", "Carte expliquée", "Mapa explicado"}
SCHEMA_OBLIGATOIRE = {"IA, technique", "IA, técnica"}
TAUX_LONGUEUR = 0.75
TAUX_VISUELS = 0.7


def mots_corps(r):
    return sum(len((b.get("texte") or "").split()) + sum(len(i.split()) for i in b.get("items", []))
               for b in r["blocs"])


def controler(ed):
    """Liste des manques d'une édition du jour (vide si tout va bien)."""
    manques = []
    rubriques = ed.get("rubriques", [])
    for r in rubriques:
        cible = CIBLES.get(r["etiquette"])
        n = mots_corps(r)
        if cible and n < cible * TAUX_LONGUEUR:
            manques.append(f"{r['etiquette']} : {n} mots, minimum {int(cible * TAUX_LONGUEUR)} (cible {cible})")
        types = {b["type"] for b in r["blocs"]}
        if r["etiquette"] in IMAGE_OBLIGATOIRE and not types & {"image", "duo"}:
            manques.append(f"{r['etiquette']} : image obligatoire (photo ou carte Wikimedia, Our World in Data)")
        if r["etiquette"] in SCHEMA_OBLIGATOIRE and "schema" not in types:
            manques.append(f"{r['etiquette']} : schéma obligatoire")
        if r["etiquette"] not in ("Carte expliquée", "Mapa explicado") and len(r.get("sources", [])) < 2:
            manques.append(f"{r['etiquette']} : au moins deux sources")
    avec = sum(1 for r in rubriques if any(b["type"] in ("image", "carte", "duo", "schema") for b in r["blocs"]))
    if rubriques and avec < TAUX_VISUELS * len(rubriques):
        manques.append(f"visuels : {avec} rubrique(s) illustrée(s) sur {len(rubriques)}, minimum {-(-int(TAUX_VISUELS * len(rubriques) * 10) // 10)}")
    for br in ed.get("breves", []):
        if len(br.get("items", [])) < 2:
            manques.append(f"brèves {br['rubrique']} : au moins 2 items, ou retirer la zone")
    return manques


def texte(ed):
    """Texte brut d'une édition (jour ou semaine), pour l'audit sans-trace-ia."""
    lignes = [ed["une"]["texte"]] if ed.get("une") else []
    for r in ed.get("rubriques", []) + ed.get("sujets", []):
        lignes += [r["titre"], r.get("chapo", ""), (r.get("couverture") or {}).get("legende", "")]
        for b in r["blocs"]:
            lignes += [b.get("texte", "")] + b.get("items", []) + [b.get("legende", "")]
            lignes += [e.get("legende", "") for e in b.get("elements", [])]
            lignes += [x.get("boite") or x.get("fleche", "") for x in b.get("etapes", [])]
        lignes.append(r.get("a_retenir", ""))
    for br in ed.get("breves", []):
        lignes += br["items"]
    return "\n\n".join(x for x in lignes if x)


def git(*args, cwd):
    subprocess.run(["git", *args], cwd=cwd, check=True)


def pousser(site, date, genre, base):
    """Un commit unique sur pages. Refusé si pages a bougé depuis la lecture (autre publication en cours)."""
    git("init", "-q", "-b", "pages", cwd=site)
    git("add", "-A", cwd=site)
    git("-c", "user.name=Actualités", "-c", "user.email=adrien.etks@gmail.com",
        "commit", "-q", "-m", f"{'Édition du' if genre == 'jour' else 'Semaine du'} {date}", cwd=site)
    bail = f"--force-with-lease=pages:{base}" if base else "--force"
    r = subprocess.run(["git", "push", "-q", bail, distant(), "pages:pages"], cwd=site, capture_output=True, text=True)
    shutil.rmtree(os.path.join(site, ".git"), ignore_errors=True)
    return r.returncode == 0


if __name__ == "__main__":
    a = argparse.ArgumentParser()
    a.add_argument("genre", nargs="?", choices=["jour", "semaine"], default="jour")
    a.add_argument("editions", nargs="+")
    a.add_argument("--pousser", action="store_true")
    a.add_argument("--texte", action="store_true", help="écrit le .txt à côté du JSON, contrôle et s'arrête")
    a.add_argument("--forcer", action="store_true",
                   help="publie malgré les manques (seulement après 7h40, heure de Paris)")
    x = a.parse_args()
    manques = {}
    if x.genre == "jour":
        for chemin in x.editions:
            m = controler(json.load(open(chemin, encoding="utf-8")))
            if m:
                manques[chemin] = m
    for chemin, m in manques.items():
        print(f"MANQUES dans {os.path.basename(chemin)} :\n" + "\n".join(f"  - {l}" for l in m))
    if x.texte:
        for chemin in x.editions:
            sortie = os.path.splitext(chemin)[0] + ".txt"
            open(sortie, "w", encoding="utf-8").write(texte(json.load(open(chemin, encoding="utf-8"))))
            print(sortie)
        sys.exit()
    if manques and not x.forcer:
        erreur("édition incomplète : compléter le JSON (voir MANQUES ci-dessus) et relancer")
    for essai in range(3):
        site, date, base = construire(x.editions, x.genre, reprendre=x.pousser)
        if not x.pousser:
            break
        if pousser(site, date, x.genre, base):
            print(f"Publié sur la branche pages : {x.genre} du {date}")
            break
        print("  la branche pages a changé pendant la construction, nouvel essai")
        time.sleep(5)
    else:
        erreur("publication refusée trois fois")
