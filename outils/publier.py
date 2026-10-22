#!/usr/bin/env python3
"""Publie une édition d'Actualités dans l'app (branche `pages`, servie par GitHub Pages).

Usage :
  python3 outils/publier.py chemin/edition.json            construit _site/ et contrôle
  python3 outils/publier.py chemin/edition.json --pousser  idem puis publie (force push sur `pages`)

Le dépôt garde deux branches :
- main  : le code de l'app et ces outils.
- pages : le site publié = l'app + la seule édition du jour. Un unique commit, réécrit à chaque
          publication : l'historique ne grossit pas, une seule édition existe en ligne.

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


def verifier(ed):
    for cle in ("date_texte", "rubriques"):
        if cle not in ed:
            erreur(f"champ manquant : {cle}")
    for r in ed["rubriques"]:
        for cle in ("etiquette", "titre", "blocs"):
            if cle not in r:
                erreur(f"rubrique sans {cle} : {r.get('titre', r.get('etiquette'))}")
        for b in r["blocs"]:
            if b.get("type") not in TYPES:
                erreur(f"type de bloc inconnu : {b.get('type')} ({r['etiquette']})")
    for url in re.findall(r'"url":\s*"([^"]+)"', json.dumps(ed)):
        if not url.startswith("https://"):
            erreur(f"URL non https : {url}")


def images(ed):
    """Tous les blocs et éléments qui portent une image ou une carte."""
    for r in ed["rubriques"]:
        for b in r["blocs"]:
            if b["type"] in ("image", "carte"):
                yield b
            elif b["type"] == "duo":
                yield from b.get("elements", [])


def compresser(png):
    im = Image.open(png).convert("RGB").quantize(colors=32, method=Image.Quantize.MEDIANCUT)
    im.save(png, optimize=True)


def preparer(ed, dossier_json, site):
    dossier_img = os.path.join(site, "edition", "img")
    os.makedirs(dossier_img, exist_ok=True)
    for el in images(ed):
        if el.get("type") == "carte":
            nom = f"loc-{slug(el['ville'])}.png"
            cible = os.path.join(dossier_img, nom)
            if not os.path.exists(cible):
                locator.carte(el["ville"], float(el["lat"]), float(el["lon"]), cible, nom_pays=el.get("pays"))
                compresser(cible)
            el["src"] = f"edition/img/{nom}"
        elif el.get("fichier"):
            source = os.path.join(dossier_json, el["fichier"])
            nom = os.path.basename(el["fichier"])
            shutil.copyfile(source, os.path.join(dossier_img, nom))
            el["src"] = f"edition/img/{nom}"
            el.pop("fichier")
        elif el.get("url"):
            nom = telecharger(el["url"], dossier_img)
            if nom:
                el["src"] = f"edition/img/{nom}"
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


def construire(chemin_json):
    ed = json.load(open(chemin_json, encoding="utf-8"))
    verifier(ed)
    ed["date"] = date_iso(ed["date_texte"])
    ed["publie"] = dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds")

    site = os.path.join(RACINE, "_site")
    shutil.rmtree(site, ignore_errors=True)
    for f in FICHIERS_APP:
        cible = os.path.join(site, f)
        os.makedirs(os.path.dirname(cible), exist_ok=True)
        shutil.copyfile(os.path.join(RACINE, f), cible)
    open(os.path.join(site, ".nojekyll"), "w").close()

    preparer(ed, os.path.dirname(os.path.abspath(chemin_json)), site)
    with open(os.path.join(site, "edition", "edition.json"), "w", encoding="utf-8") as f:
        json.dump(ed, f, ensure_ascii=False, separators=(",", ":"))

    total = sum(os.path.getsize(os.path.join(d, x)) for d, _, fs in os.walk(site) for x in fs)
    if total > LIMITE_SITE:
        erreur(f"site trop lourd : {total // 1024} Ko (limite {LIMITE_SITE // 1024} Ko)")
    nb_cartes = sum(1 for el in images(ed) if el.get("type") == "carte")
    print(f"Édition {ed['date']} : {len(ed['rubriques'])} rubriques, {nb_cartes} carte(s), site {total // 1024} Ko")
    return site, ed["date"]


def git(*args, cwd):
    subprocess.run(["git", *args], cwd=cwd, check=True)


def pousser(site, date):
    distant = subprocess.run(["git", "remote", "get-url", "origin"], cwd=RACINE, check=True,
                             capture_output=True, text=True).stdout.strip()
    git("init", "-q", "-b", "pages", cwd=site)
    git("add", "-A", cwd=site)
    git("-c", "user.name=Actualités", "-c", "user.email=adrien.etks@gmail.com",
        "commit", "-q", "-m", f"Édition du {date}", cwd=site)
    git("push", "-q", "--force", distant, "pages:pages", cwd=site)
    shutil.rmtree(os.path.join(site, ".git"), ignore_errors=True)
    print(f"Publié sur la branche pages : édition du {date}")


if __name__ == "__main__":
    a = argparse.ArgumentParser()
    a.add_argument("edition")
    a.add_argument("--pousser", action="store_true")
    x = a.parse_args()
    site, date = construire(x.edition)
    if x.pousser:
        pousser(site, date)
