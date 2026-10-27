#!/usr/bin/env python3
"""Deux profils à partir d'une seule rédaction en français.

La tâche écrit une édition de base en français (base.json, même schéma que edition.json ou hebdo.json,
voir outils/publier.py), qui contient toutes les rubriques des deux profils. Ce script :
1. `preparer base.json` : écrit edition-fr.json (profil Adrien, rubriques fr dans l'ordre fr)
   et a-traduire.json : {"1": "texte", "2": "texte", ...}, uniquement les textes du profil pt.
   Les URL, crédits, sources et la structure n'y sont pas : seuls les textes sont traduits.
2. Claude traduit a-traduire.json en pt-BR dans traduit.json, mêmes clés, mêmes nombres d'entrées.
3. `assembler base.json traduit.json` : écrit edition-pt.json (profil Ana, ordre pt, dates en portugais).

Pour l'édition de la semaine, mêmes commandes avec --semaine (fichiers hebdo-fr.json et hebdo-pt.json).

Rubriques du jour : le profil se déduit de l'étiquette (listes ORDRE ci-dessous). Une rubrique ou un
dossier peut le préciser avec "profils": ["fr"], ["pt"] ou ["fr", "pt"] ; sans précision et pour une
étiquette inconnue, il va aux deux profils.
"""
import argparse
import datetime as dt
import json
import os
import sys

ORDRE = {
    "fr": ["Monde", "France", "Brésil", "Le chiffre", "Comprendre", "Finance", "Intelligence artificielle",
           "IA, technique", "Cinéma", "Environnement", "Carte expliquée"],
    "pt": ["Monde", "Brésil", "France", "Politique du Brésil", "Le chiffre", "Architecture", "Cinéma",
           "Environnement", "Carte expliquée"],
}
# Étiquettes et noms de brèves connus : traduits ici, sans passer par la traduction.
NOMS_PT = {
    "Monde": "Mundo", "France": "França", "Brésil": "Brasil", "Politique du Brésil": "Política brasileira",
    "Le chiffre": "O número", "Comprendre": "Entender", "Finance": "Finanças",
    "Intelligence artificielle": "Inteligência artificial", "IA, technique": "IA, técnica", "Cinéma": "Cinema",
    "Environnement": "Meio ambiente", "Architecture": "Arquitetura", "Carte expliquée": "Mapa explicado",
    "Géopolitique": "Geopolítica", "Géoéconomie": "Geoeconomia", "Économie": "Economia",
    "Énergie": "Energia", "Climat": "Clima", "Société": "Sociedade", "Science": "Ciência", "Culture": "Cultura",
    "Portugal": "Portugal", "Europe": "Europa", "Afrique": "África", "Amériques": "Américas",
    "Asie": "Ásia", "Océanie": "Oceania", "Moyen-Orient": "Oriente Médio",
}
JOURS_PT = ["Segunda-feira", "Terça-feira", "Quarta-feira", "Quinta-feira", "Sexta-feira", "Sábado", "Domingo"]
MOIS_PT = ["janeiro", "fevereiro", "março", "abril", "maio", "junho", "julho", "agosto",
           "setembro", "outubro", "novembro", "dezembro"]

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from publier import date_iso  # noqa: E402


def profils_de(r, liste):
    if r.get("profils"):
        return set(r["profils"])
    if liste == "rubriques":
        dans = {p for p, ordre in ORDRE.items() if r["etiquette"] in ordre}
        return dans or {"fr", "pt"}
    return {"fr", "pt"}


def selection(base, profil):
    """Copie de la base réduite au profil, rubriques dans l'ordre du profil."""
    liste = "rubriques" if "rubriques" in base else "sujets"
    ed = json.loads(json.dumps(base))
    gardees = [r for r in ed[liste] if profil in profils_de(r, liste)]
    if liste == "rubriques":
        rang = {e: i for i, e in enumerate(ORDRE[profil])}
        gardees.sort(key=lambda r: rang.get(r["etiquette"], len(rang)))
    for r in gardees:
        r.pop("profils", None)
    ed[liste] = gardees
    ed["langue"] = profil
    return ed, liste


def champs(ed, liste):
    """Tous les textes à traduire, dans un ordre fixe : (objet, clé) ou (liste, index)."""
    if ed.get("une"):
        yield ed["une"], "texte"
        if (ed["une"].get("image") or {}).get("legende"):
            yield ed["une"]["image"], "legende"

    def element(e):
        if e.get("legende"):
            yield e, "legende"

    for r in ed[liste]:
        if r["etiquette"] not in NOMS_PT:
            yield r, "etiquette"
        for cle in ("titre", "chapo"):
            if r.get(cle):
                yield r, cle
        if r.get("couverture"):
            yield from element(r["couverture"])
        for b in r["blocs"]:
            if b.get("texte"):
                yield b, "texte"
            for i in range(len(b.get("items", []))):
                yield b["items"], i
            yield from element(b)
            for e in b.get("elements", []):
                yield from element(e)
            for etape in b.get("etapes", []):
                for cle in ("boite", "fleche"):
                    if etape.get(cle):
                        yield etape, cle
        for cle in ("a_retenir", "note_sources"):
            if r.get(cle):
                yield r, cle
    for br in ed.get("breves", []):
        if br["rubrique"] not in NOMS_PT:
            yield br, "rubrique"
        for i in range(len(br.get("items", []))):
            yield br["items"], i


def date_pt(date_texte):
    d = dt.date.fromisoformat(date_iso(date_texte, "fr"))
    return d, f"{JOURS_PT[d.weekday()]}, {d.day} de {MOIS_PT[d.month - 1]} de {d.year}"


def ecrire(chemin, donnees):
    with open(chemin, "w", encoding="utf-8") as f:
        json.dump(donnees, f, ensure_ascii=False, indent=1)
    print(chemin)


def preparer(base_chemin, semaine):
    base = json.load(open(base_chemin, encoding="utf-8"))
    dossier = os.path.dirname(os.path.abspath(base_chemin))
    fr, _ = selection(base, "fr")
    ecrire(os.path.join(dossier, "hebdo-fr.json" if semaine else "edition-fr.json"), fr)
    pt, liste = selection(base, "pt")
    textes = {str(i + 1): (o[c]) for i, (o, c) in enumerate(champs(pt, liste))}
    ecrire(os.path.join(dossier, "a-traduire.json"), textes)
    print(f"{len(textes)} textes à traduire, {sum(len(t.split()) for t in textes.values())} mots")


def assembler(base_chemin, traduit_chemin, semaine):
    base = json.load(open(base_chemin, encoding="utf-8"))
    traduit = json.load(open(traduit_chemin, encoding="utf-8"))
    pt, liste = selection(base, "pt")
    emplacements = list(champs(pt, liste))  # avant toute modification : mêmes clés que preparer
    manquants = [str(i + 1) for i in range(len(emplacements)) if not str(i + 1) in traduit]
    if manquants or len(traduit) != len(emplacements):
        sys.exit(f"ERREUR : traduction incomplète ({len(traduit)} textes pour {len(emplacements)} attendus ; "
                 f"manquants : {', '.join(manquants[:20])})")
    for i, (o, c) in enumerate(emplacements):
        o[c] = traduit[str(i + 1)]
    for r in pt[liste]:
        r["etiquette"] = NOMS_PT.get(r["etiquette"], r["etiquette"])
    for br in pt.get("breves", []):
        br["rubrique"] = NOMS_PT.get(br["rubrique"], br["rubrique"])
    d, pt["date_texte"] = date_pt(base["date_texte"])
    if semaine:
        lundi = d + dt.timedelta(days=1)
        pt["date_texte_semaine"] = f"Semana de {lundi.day} de {MOIS_PT[lundi.month - 1]} de {lundi.year}"
    dossier = os.path.dirname(os.path.abspath(base_chemin))
    ecrire(os.path.join(dossier, "hebdo-pt.json" if semaine else "edition-pt.json"), pt)


if __name__ == "__main__":
    a = argparse.ArgumentParser()
    a.add_argument("action", choices=["preparer", "assembler"])
    a.add_argument("base")
    a.add_argument("traduit", nargs="?")
    a.add_argument("--semaine", action="store_true")
    x = a.parse_args()
    if x.action == "preparer":
        preparer(x.base, x.semaine)
    else:
        if not x.traduit:
            sys.exit("ERREUR : assembler base.json traduit.json")
        assembler(x.base, x.traduit, x.semaine)
