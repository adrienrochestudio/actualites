#!/usr/bin/env python3
"""Veille du matin : lit les flux de consignes/veille.txt et sort une liste compacte des articles récents,
groupés par rubrique, sans les sujets déjà traités (historique). Remplace la plupart des recherches web.

Le réseau de la tâche planifiée ne laisse pas passer les sites de presse : la veille tourne donc chaque nuit
dans GitHub Actions (.github/workflows/veille.yml) et sa sortie est publiée sur la branche `veille`
(veille.txt, liens.json ; le samedi et le dimanche, aussi semaine.txt et liens-semaine.json).
La tâche lit ces fichiers avec git ; `lien` les retrouve dans le dossier veille/ quand il existe.

Usage :
  python3 outils/veille.py                  dernières 30 heures, 5 articles au plus par flux
  python3 outils/veille.py --heures 168     la semaine (édition du dimanche)
  python3 outils/veille.py --rubrique Finance --max 12
  python3 outils/veille.py lien 12 31 40    adresses des articles retenus (numéros de la dernière veille)
Sortie : "[n] titre · source · JJ/MM HHhMM". Les adresses restent dans _veille.json, pour ne pas
alourdir la lecture. Les flux en échec sont listés à la fin.
"""
import argparse
import concurrent.futures as cf
import datetime as dt
import email.utils
import html
import json
import os
import re
import sys
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(RACINE, "outils"))
from historique import deja_traite, mots, sujets_recents  # noqa: E402

LIENS = os.path.join(RACINE, "_veille.json")
LIENS_BRANCHE = os.path.join(RACINE, "veille", "liens.json")
AGENT = "Mozilla/5.0 (compatible; ActualitesVeille/1.0; +https://github.com/adrienrochestudio/actualites)"
PARIS = dt.timezone(dt.timedelta(hours=1))  # heure d'hiver ; l'affichage n'a pas besoin de plus


def sources(rubrique=None):
    for l in open(os.path.join(RACINE, "consignes", "veille.txt"), encoding="utf-8"):
        if l.strip() and not l.startswith("#"):
            rub, nom, url = [c.strip() for c in l.split("|", 2)]
            if rubrique is None or rub.lower() == rubrique.lower():
                yield rub, nom, url


def lire_date(texte):
    if not texte:
        return None
    texte = texte.strip()
    try:
        d = email.utils.parsedate_to_datetime(texte)
    except (TypeError, ValueError):
        try:
            d = dt.datetime.fromisoformat(texte.replace("Z", "+00:00"))
        except ValueError:
            return None
    return d if d.tzinfo else d.replace(tzinfo=dt.timezone.utc)


def nettoyer_url(url):
    p = urllib.parse.urlsplit(url.strip())
    garder = [(k, v) for k, v in urllib.parse.parse_qsl(p.query) if not k.startswith(("utm_", "xtor", "at_"))]
    return urllib.parse.urlunsplit((p.scheme, p.netloc, p.path, urllib.parse.urlencode(garder), ""))


def articles(xml):
    """(titre, lien, date) pour RSS 2.0, RSS 1.0 (RDF) et Atom, sans dépendre des espaces de noms."""
    racine = ET.fromstring(xml)
    for el in racine.iter():
        tag = el.tag.rsplit("}", 1)[-1]
        if tag not in ("item", "entry"):
            continue
        champs = {}
        for c in el:
            nom = c.tag.rsplit("}", 1)[-1]
            if nom == "link" and c.get("href") and c.get("rel", "alternate") == "alternate":
                champs.setdefault("link", c.get("href"))
            elif c.text and nom not in champs:
                champs[nom] = c.text
        titre = html.unescape(re.sub(r"<[^>]+>", "", champs.get("title", ""))).strip()
        date = lire_date(champs.get("pubDate") or champs.get("published") or champs.get("updated") or champs.get("date"))
        if titre and champs.get("link"):
            yield titre, champs["link"], date


def lire_flux(source):
    rub, nom, url = source
    try:
        req = urllib.request.Request(url, headers={"User-Agent": AGENT})
        with urllib.request.urlopen(req, timeout=15) as rep:
            return source, list(articles(rep.read())), None
    except Exception as exc:  # réseau, statut, XML invalide : le flux est signalé, la veille continue
        return source, [], f"{exc.__class__.__name__}"


def main():
    if sys.argv[1:2] == ["lien"]:
        args = sys.argv[2:]
        fichier = LIENS_BRANCHE if os.path.isfile(LIENS_BRANCHE) else LIENS
        if args[:1] == ["--semaine"]:
            fichier = os.path.join(RACINE, "veille", "liens-semaine.json")
            args = args[1:]
        liens = json.load(open(fichier, encoding="utf-8"))
        for n in args:
            print(f"[{n}] {liens.get(n, 'numéro inconnu')}")
        return
    a = argparse.ArgumentParser()
    a.add_argument("--heures", type=int, default=30)
    a.add_argument("--max", type=int, default=5, help="articles au plus par flux")
    a.add_argument("--rubrique")
    a.add_argument("--liens", default=LIENS, help="fichier où écrire les adresses")
    x = a.parse_args()

    depuis = dt.datetime.now(dt.timezone.utc) - dt.timedelta(hours=x.heures)
    sujets = sujets_recents()
    vus = []
    liens = {}
    par_rubrique, echecs, ecartes = {}, [], 0
    with cf.ThreadPoolExecutor(12) as pool:
        resultats = list(pool.map(lire_flux, list(sources(x.rubrique))))
    for (rub, nom, _), arts, err in resultats:
        if err:
            echecs.append(f"{nom} ({err})")
            continue
        n = 0
        for titre, lien, date in sorted(arts, key=lambda t: t[2] or depuis, reverse=True):
            if n >= x.max or (date and date < depuis):
                continue
            m = mots(titre)
            if any(len(m & v) >= max(3, len(m) * 0.7) for v in vus):  # même info dans un autre flux
                continue
            if deja_traite(titre, sujets, seuil=0.6):
                ecartes += 1
                continue
            vus.append(m)
            quand = date.astimezone(PARIS).strftime("%d/%m %Hh%M") if date else "?"
            num = str(len(liens) + 1)
            liens[num] = nettoyer_url(lien)
            par_rubrique.setdefault(rub, []).append(f"[{num}] {titre[:140]} · {nom} · {quand}")
            n += 1
    json.dump(liens, open(x.liens, "w", encoding="utf-8"), ensure_ascii=False)
    print(f"Veille du {dt.datetime.now(PARIS).strftime('%d/%m/%Y %Hh%M')} (heure de Paris), {x.heures} dernières heures")
    for rub, lignes in par_rubrique.items():
        print(f"\n## {rub}")
        print("\n".join(lignes))
    print(f"\n{sum(map(len, par_rubrique.values()))} articles, {ecartes} écarté(s) car déjà traités"
          + (f" ; flux en échec : {', '.join(echecs)}" if echecs else ""))


if __name__ == "__main__":
    main()
