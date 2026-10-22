#!/usr/bin/env python3
"""Publie une édition d'Actualités dans l'app (branche `pages`, servie par GitHub Pages).

Usage :
  python3 outils/publier.py [jour|semaine] chemin.json             construit _site/ et contrôle
  python3 outils/publier.py [jour|semaine] chemin.json --pousser   idem puis publie sur `pages`
  python3 outils/publier.py [jour|semaine] chemin.json --texte     écrit le .txt (audit sans-trace-ia)
  Sans genre : "jour".

Le dépôt garde deux branches :
- main  : le code de l'app et ces outils.
- pages : le site publié = l'app + l'édition du jour (edition/) + l'édition de la semaine (hebdo/).
          Un unique commit, réécrit à chaque publication : l'historique ne grossit pas.
          Publier l'un reprend l'autre tel qu'il est en ligne ; si pages change pendant la
          construction (les deux tâches en même temps), la publication recommence.

Schéma de edition.json (textes en texte brut) :
{
  "date_texte": "Lundi 19 octobre 2026",
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
    "icons/icon-512-maskable.png",
]
TYPES = {"p", "sous_titre", "liste", "image", "duo", "carte", "schema"}
MOIS = ["janvier", "février", "mars", "avril", "mai", "juin", "juillet", "août",
        "septembre", "octobre", "novembre", "décembre"]
LIMITE_SITE = 5 * 1024 * 1024
MAX_IMAGE = 4 * 1024 * 1024
LARGEUR_MAX = 1100
AGENT = "ActualitesApp/1.0 (+https://github.com/adrienrochestudio/actualites)"


def erreur(msg):
    sys.exit(f"ERREUR : {msg}")


def date_iso(date_texte):
    m = re.fullmatch(r"\s*\w+\s+(\d{1,2})(?:er)?\s+(\w+)\s+(\d{4})\s*", date_texte.lower())
    if not m or m.group(2) not in MOIS:
        erreur(f"date_texte illisible : {date_texte!r} (attendu : 'Lundi 19 octobre 2026')")
    return dt.date(int(m.group(3)), MOIS.index(m.group(2)) + 1, int(m.group(1))).isoformat()


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
    rel = f"{GENRES[genre]['dossier']}/img"
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


def reprendre_en_ligne(site, genre):
    """Copie dans le site l'autre contenu tel qu'il est publié sur la branche pages. Renvoie le commit lu."""
    autre = GENRES["semaine" if genre == "jour" else "jour"]["dossier"]
    tmp = os.path.join(RACINE, "_pages")
    shutil.rmtree(tmp, ignore_errors=True)
    r = subprocess.run(["git", "clone", "-q", "--depth", "1", "--branch", "pages", distant(), tmp],
                       capture_output=True, text=True)
    if r.returncode != 0:
        return None  # branche pages absente : premier déploiement
    sha = subprocess.run(["git", "rev-parse", "HEAD"], cwd=tmp, capture_output=True, text=True).stdout.strip()
    if os.path.isdir(os.path.join(tmp, autre)):
        shutil.copytree(os.path.join(tmp, autre), os.path.join(site, autre))
    shutil.rmtree(tmp, ignore_errors=True)
    return sha


def construire(chemin_json, genre, reprendre=True):
    ed = json.load(open(chemin_json, encoding="utf-8"))
    verifier(ed, genre)
    ed["date"] = date_iso(ed["date_texte"])
    ed["publie"] = dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds")

    site = os.path.join(RACINE, "_site")
    shutil.rmtree(site, ignore_errors=True)
    for f in FICHIERS_APP:
        cible = os.path.join(site, f)
        os.makedirs(os.path.dirname(cible), exist_ok=True)
        shutil.copyfile(os.path.join(RACINE, f), cible)
    open(os.path.join(site, ".nojekyll"), "w").close()

    base = reprendre_en_ligne(site, genre) if reprendre else None
    g = GENRES[genre]
    preparer(ed, genre, os.path.dirname(os.path.abspath(chemin_json)), site)
    with open(os.path.join(site, g["dossier"], g["fichier"]), "w", encoding="utf-8") as f:
        json.dump(ed, f, ensure_ascii=False, separators=(",", ":"))

    total = sum(os.path.getsize(os.path.join(d, x)) for d, _, fs in os.walk(site) for x in fs)
    if total > LIMITE_SITE:
        erreur(f"site trop lourd : {total // 1024} Ko (limite {LIMITE_SITE // 1024} Ko)")
    nb_cartes = sum(1 for el in images(ed, genre) if el.get("type") == "carte")
    print(f"{'Édition' if genre == 'jour' else 'Semaine'} {ed['date']} : {len(ed[g['liste']])} articles, "
          f"{nb_cartes} carte(s), site {total // 1024} Ko")
    return site, ed["date"], base


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
    a.add_argument("edition")
    a.add_argument("--pousser", action="store_true")
    a.add_argument("--texte", action="store_true", help="écrit le .txt à côté du JSON et s'arrête")
    x = a.parse_args()
    if x.texte:
        sortie = os.path.splitext(x.edition)[0] + ".txt"
        open(sortie, "w", encoding="utf-8").write(texte(json.load(open(x.edition, encoding="utf-8"))))
        sys.exit(print(sortie))
    for essai in range(3):
        site, date, base = construire(x.edition, x.genre, reprendre=x.pousser)
        if not x.pousser:
            break
        if pousser(site, date, x.genre, base):
            print(f"Publié sur la branche pages : {x.genre} du {date}")
            break
        print("  la branche pages a changé pendant la construction, nouvel essai")
        time.sleep(5)
    else:
        erreur("publication refusée trois fois")
