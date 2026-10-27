#!/usr/bin/env python3
"""Historique des sujets traités, sans relire les fichiers en entier.

Fichiers (branche `historique`, récupérée dans le dossier historique/ du dépôt) :
- quotidien.txt : AAAA-MM-JJ | rubrique | sujet | villes      (60 jours)
- hebdo.txt     : AAAA-MM-JJ | etiquette | sujet               (6 mois)
- pistes.txt    : AAAA-MM-JJ | thème | piste | url             (14 jours) sujets de fond repérés pour le dimanche

Usage :
  historique.py notions                 sujets récents des rubriques à notion (Comprendre, IA technique,
                                        Carte expliquée, Architecture) et dossiers des 6 derniers mois
  historique.py verifier base.json      signale les rubriques proches d'un sujet déjà traité
  historique.py ajouter base.json       ajoute une ligne par rubrique et retire les lignes trop anciennes
  historique.py ajouter hebdo-base.json --semaine
  historique.py piste "thème" "piste" [url]
  historique.py pistes                  pistes des 7 derniers jours (le dimanche)
  historique.py envoyer                 commit et push de la branche historique
  historique.py journal "étape" "état ou cause"   trace d'exécution (journal.txt, 30 jours), poussée aussitôt
"""
import datetime as dt
import json
import os
import re
import subprocess
import sys
import unicodedata

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DOSSIER = os.path.join(RACINE, "historique")
DUREES = {"quotidien.txt": 60, "hebdo.txt": 183, "pistes.txt": 14, "journal.txt": 30}
A_NOTION = {"Comprendre", "IA, technique", "Carte expliquée", "Architecture", "comprendre", "ia, technique"}
VIDES = set("""avec dans pour sans sous entre leur leurs mais plus moins comme apres avant depuis contre
vers chez dont elle elles ils sont etre avoir fait faire cette celle ceux tout tous toute toutes
the and for with from that this into over under after their about para pela pelo como mais entre""".split())


def mots(texte):
    """Mots significatifs d'un texte, sans accents ni majuscules."""
    t = unicodedata.normalize("NFD", texte.lower())
    t = "".join(c for c in t if unicodedata.category(c) != "Mn")
    return {m for m in re.findall(r"[a-z0-9]{4,}", t) if m not in VIDES}


def lire(nom):
    chemin = os.path.join(DOSSIER, nom)
    if not os.path.isfile(chemin):
        return [], []
    entete, lignes = [], []
    for l in open(chemin, encoding="utf-8").read().splitlines():
        (entete if l.startswith("#") or not l.strip() else lignes).append(l)
    return entete, lignes


def ecrire(nom, entete, lignes):
    limite = (dt.date.today() - dt.timedelta(days=DUREES[nom])).isoformat()
    gardees = [l for l in lignes if l[:10] >= limite]
    with open(os.path.join(DOSSIER, nom), "w", encoding="utf-8") as f:
        f.write("\n".join(entete + gardees) + "\n")
    return len(lignes) - len(gardees)


def champs(ligne):
    return [c.strip() for c in ligne.split("|")]


def sujets_recents():
    """(rubrique, sujet, mots) pour l'historique quotidien et hebdomadaire."""
    out = []
    for nom in ("quotidien.txt", "hebdo.txt"):
        for l in lire(nom)[1]:
            c = champs(l)
            if len(c) >= 3:
                out.append((c[1], c[2], mots(c[2] + " " + (c[3] if len(c) > 3 else ""))))
    return out


def deja_traite(texte, sujets=None, seuil=0.5):
    """Sujet récent le plus proche si le recouvrement de mots dépasse le seuil, sinon None."""
    m = mots(texte)
    if len(m) < 2:
        return None
    meilleur = None
    for rub, sujet, ms in sujets if sujets is not None else sujets_recents():
        if not ms:
            continue
        r = len(m & ms) / min(len(m), len(ms))
        if r >= seuil and (meilleur is None or r > meilleur[0]):
            meilleur = (r, rub, sujet)
    return meilleur


def liste_de(ed):
    return ed.get("rubriques") or ed.get("sujets") or []


def villes(r):
    v = []
    for b in r.get("blocs", []):
        for e in [b] + b.get("elements", []):
            if e.get("type") == "carte" or ("ville" in e and "lat" in e):
                v.append(e["ville"])
    return ", ".join(dict.fromkeys(v))


def date_de(ed):
    sys.path.insert(0, os.path.join(RACINE, "outils"))
    from publier import date_iso
    return date_iso(ed["date_texte"], ed.get("langue", "fr"))


def main(args):
    if not args:
        sys.exit(__doc__)
    action = args[0]
    if action == "notions":
        for l in lire("quotidien.txt")[1]:
            c = champs(l)
            if len(c) >= 3 and c[1] in A_NOTION:
                print(f"{c[0]} | {c[1]} | {c[2]}")
        for l in lire("hebdo.txt")[1]:
            print(l)
    elif action == "verifier":
        ed = json.load(open(args[1], encoding="utf-8"))
        sujets = sujets_recents()
        alertes = 0
        for r in liste_de(ed):
            p = deja_traite(f"{r['titre']} {r.get('chapo', '')}", sujets)
            if p:
                alertes += 1
                print(f"PROCHE ({p[0]:.0%}) : [{r['etiquette']}] {r['titre']}\n   déjà : [{p[1]}] {p[2]}")
        print(f"{alertes} rubrique(s) proche(s) d'un sujet récent" if alertes else "aucun sujet déjà traité")
    elif action == "ajouter":
        ed = json.load(open(args[1], encoding="utf-8"))
        semaine = "--semaine" in args
        nom = "hebdo.txt" if semaine else "quotidien.txt"
        date = date_de(ed)
        entete, lignes = lire(nom)
        lignes = [l for l in lignes if not l.startswith(date)]  # relance le même jour : on remplace
        if not semaine and ed.get("une"):
            lignes.append(f"{date} | une | {ed['une']['texte'][:120]} |")
        for r in liste_de(ed):
            lignes.append(f"{date} | {r['etiquette']} | {r['titre']}" + ("" if semaine else f" | {villes(r)}"))
        retirees = ecrire(nom, entete, lignes)
        print(f"{nom} : {len(liste_de(ed))} ligne(s) ajoutée(s), {retirees} ancienne(s) retirée(s)")
    elif action == "piste":
        if len(args) < 3:
            sys.exit("usage : historique.py piste \"thème\" \"piste\" [url]")
        entete, lignes = lire("pistes.txt")
        if not entete:
            entete = ["# Sujets de fond repérés pendant la semaine, pour l'édition du dimanche (14 jours)",
                      "# Format : AAAA-MM-JJ | thème | piste | url"]
        lignes.append(f"{dt.date.today().isoformat()} | {args[1]} | {args[2]} | {args[3] if len(args) > 3 else ''}")
        ecrire("pistes.txt", entete, lignes)
    elif action == "pistes":
        limite = (dt.date.today() - dt.timedelta(days=7)).isoformat()
        for l in lire("pistes.txt")[1]:
            if l[:10] >= limite:
                print(l)
    elif action == "journal":
        if len(args) < 3:
            sys.exit('usage : historique.py journal "étape" "état ou cause"')
        entete, lignes = lire("journal.txt")
        if not entete:
            entete = ["# Journal d'exécution de la tâche Actualités (30 jours)",
                      "# Format : AAAA-MM-JJ HH:MM (Paris) | étape | état ou cause"]
        heure = dt.datetime.now(dt.timezone(dt.timedelta(hours=1))).strftime("%Y-%m-%d %H:%M")
        lignes.append(f"{heure} | {args[1]} | {' '.join(args[2:])[:300]}")
        ecrire("journal.txt", entete, lignes)
        main(["envoyer"])
    elif action == "envoyer":
        def git(*a, check=True):
            return subprocess.run(["git", *a], cwd=DOSSIER, check=check, capture_output=True, text=True)
        git("add", "-A")
        if not git("status", "--porcelain").stdout.strip():
            return print("historique : rien à envoyer")
        git("-c", "user.name=Actualités", "-c", "user.email=adrien.etks@gmail.com",
            "commit", "-q", "-m", f"Historique du {dt.date.today().isoformat()}")
        for _ in range(3):
            if git("push", "-q", "origin", "historique", check=False).returncode == 0:
                return print("historique envoyé")
            git("pull", "-q", "--rebase", "origin", "historique", check=False)
        sys.exit("ERREUR : push de l'historique refusé trois fois")
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main(sys.argv[1:])
