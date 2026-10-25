"""Rendu d'une édition Actualités : edition.json -> edition.html.

Claude n'écrit que le JSON. Toute la mise en page vit ici : chaque édition est identique
et la sortie de Claude reste courte.

Usage : python3 render.py editions/AAAA-MM-JJ/edition.json [sortie.html]
Arborescence : assets/ (logo, permanent), editions/AAAA-MM-JJ/{edition.json, images/} (une édition).

Schéma du JSON (textes en texte brut, échappés au rendu) :
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
Images : "url" = image publique sous licence libre, chargée par Gmail (coût nul en tokens) ;
"fichier" = image locale (images/...), jointe au mail. Les cartes sont toujours locales.
"""
import html
import json
import os
import re
import subprocess
import sys

ICI = os.path.dirname(os.path.abspath(__file__))
DOSSIER_EDITION = "."

# Système typographique : une police, deux couleurs, quatre tailles. Gmail lit le bloc <style>.
STYLE = (
    "body{margin:0;padding:0;background:#fff}"
    ".c{font-family:Georgia,'Times New Roman',serif;color:#121212}"
    ".t{font-size:24px;line-height:30px;font-weight:bold}"
    ".s{font-size:18px;line-height:26px;font-weight:bold;padding:6px 0}"
    ".x{font-size:16px;line-height:26px;margin:0 0 14px 0}"
    ".l{font-size:16px;line-height:26px;margin:0 0 8px 0;padding-left:14px}"
    ".n{font-size:13px;line-height:19px;color:#777}"
    ".n a{color:#777}"
    ".g{padding:6px 0 18px 0}"
    ".r{padding:26px 24px 0 24px}"
    ".f{padding-bottom:26px;border-bottom:1px solid #121212}"
    ".b{border:1px solid #121212;padding:10px;font-size:16px;line-height:22px;text-align:center}"
    ".i{display:block;max-width:100%;height:auto;border:0}"
)


def e(t):
    return html.escape(t, quote=True)


def lien(s):
    return f'<a href="{e(s["url"])}">{e(s["titre"])}</a>'


def ligne_sources(sources, apres=""):
    if not sources:
        return ""
    mot = "Source" if len(sources) == 1 else "Sources"
    return f"{mot} : " + ", ".join(lien(s) for s in sources) + (f". {e(apres)}" if apres else "")


def legende(el, classe="n g"):
    t = e(el.get("legende", ""))
    if el.get("credit"):
        t += (" " if t else "") + lien(el["credit"]) + "."
    return f'<div class="{classe}">{t}</div>' if t else ""


def slug(t):
    t = t.lower()
    for a, b in (("àâä", "a"), ("éèêë", "e"), ("îï", "i"), ("ôö", "o"), ("ùûü", "u"), ("ç", "c")):
        for c in a:
            t = t.replace(c, b)
    return re.sub(r"[^a-z0-9]+", "-", t).strip("-")


def carte(bloc):
    """Génère la mini-carte dans images/ si besoin, renvoie le chemin relatif."""
    rel = f"images/loc-{slug(bloc['ville'])}.png"
    cible = os.path.join(DOSSIER_EDITION, rel)
    if not os.path.exists(cible):
        os.makedirs(os.path.dirname(cible), exist_ok=True)
        cmd = [sys.executable, os.path.join(ICI, "locator.py"), bloc["ville"], str(bloc["lat"]), str(bloc["lon"]), cible]
        if bloc.get("pays"):
            cmd += ["--pays", bloc["pays"]]
        subprocess.run(cmd, check=True)
    return rel


def img(src, largeur, alt):
    w = "100%" if largeur >= 500 else f"{largeur}px"
    return f'<img class="i" src="{e(src)}" width="{largeur}" alt="{e(alt)}" style="width:{w}">'


def source_image(el):
    return el.get("url") or el["fichier"]


def bloc_html(b):
    t = b["type"]
    if t == "p":
        return f'<p class="x">{e(b["texte"])}</p>'
    if t == "sous_titre":
        return f'<div class="s">{e(b["texte"])}</div>'
    if t == "liste":
        return "".join(f'<p class="l">- {e(i)}</p>' for i in b["items"])
    if t == "image":
        balise = img(source_image(b), b.get("largeur", 552), b.get("legende", ""))
        if b.get("lien"):
            balise = f'<a href="{e(b["lien"])}">{balise}</a>'
        return balise + legende(b)
    if t == "carte":
        return img(carte(b), 260, f"Carte : {b['ville']}") + legende(b)
    if t == "duo":
        cellules = []
        for i, el in enumerate(b["elements"]):
            if el.get("type") == "carte":
                src, largeur, alt = carte(el), 260, f"Carte : {el['ville']}"
            else:
                src, largeur, alt = source_image(el), el.get("largeur", 220), el.get("legende", "")
            pad = ' style="padding-right:12px"' if i == 0 else ""
            cellules.append(f'<td width="50%" valign="top"{pad}>{img(src, largeur, alt)}{legende(el, "n")}</td>')
        return (f'<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="margin:0 0 16px 0">'
                f'<tr>{"".join(cellules)}</tr></table>')
    if t == "schema":
        lignes = []
        for etape in b["etapes"]:
            if "boite" in etape:
                lignes.append(f'<tr><td class="b">{"<br>".join(e(x) for x in etape["boite"].split(chr(10)))}</td></tr>')
            else:
                lignes.append(f'<tr><td class="n" align="center" style="padding:4px 0">{e(etape["fleche"])}</td></tr>')
        return (f'<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="margin:4px 0 6px 0">'
                f'{"".join(lignes)}</table>{legende(b)}')
    raise ValueError(f"type de bloc inconnu : {t}")


def rubrique(r):
    parts = [f'<div class="n">{e(r["etiquette"])}</div>',
             f'<div class="t" style="padding:4px 0 14px 0">{e(r["titre"])}</div>']
    parts += [bloc_html(b) for b in r["blocs"]]
    if r.get("a_retenir"):
        parts.append(f'<div class="s">À retenir</div><p class="x">{e(r["a_retenir"])}</p>')
    parts.append(f'<div class="n f">{ligne_sources(r.get("sources"), r.get("note_sources", ""))}</div>')
    return f'<tr><td class="r">{"".join(parts)}</td></tr>'


def breves(liste):
    if not liste:
        return ""
    parts = ['<div class="t" style="padding-bottom:12px">En bref</div>']
    for i, br in enumerate(liste):
        bas = ";border-bottom:1px solid #121212" if i == len(liste) - 1 else ""
        items = "".join(f'<p class="x" style="margin-bottom:10px">- {e(x)}</p>' for x in br["items"])
        parts.append(f'<div style="border-top:1px solid #121212;padding:12px 0{bas}">'
                     f'<div class="s">{e(br["rubrique"])}</div>{items}'
                     f'<div class="n">{ligne_sources(br.get("sources"))}</div></div>')
    return f'<tr><td class="r">{"".join(parts)}</td></tr>'


def rendre(ed):
    une = ed["une"]
    entete = (
        '<tr><td style="padding:0 24px">'
        '<table role="presentation" cellpadding="0" cellspacing="0" width="100%" style="border-top:1px solid #121212"><tr>'
        '<td width="48" valign="middle" style="padding-top:16px">'
        '<img class="i" src="assets/logo-96.png" width="40" height="40" alt="" style="width:40px;height:40px"></td>'
        '<td class="t" valign="middle" style="padding:16px 0 0 10px">Actualités</td></tr></table>'
        f'<div class="n" style="padding:2px 0 18px 0">{e(ed["date_texte"])}</div>'
        f'<p class="x" style="margin-bottom:6px">{e(une["texte"])}</p>'
        f'<div class="n" style="padding-bottom:22px;border-bottom:1px solid #121212">{ligne_sources(une.get("sources"))}</div>'
        '</td></tr>'
    )
    corps = "".join(rubrique(r) for r in ed["rubriques"])
    jour = ed["date_texte"].split(" ", 1)[1]
    pied = (f'<tr><td style="padding:22px 24px 30px 24px"><div class="n">'
            f'Rédigé par Claude à partir de sources publiques consultées le {e(jour)}.</div></td></tr>')
    return (
        '<!doctype html><html lang="fr"><head><meta charset="utf-8">'
        '<meta name="viewport" content="width=device-width,initial-scale=1">'
        f'<title>Actualités, {e(ed["date_texte"])}</title><style>{STYLE}</style></head><body>'
        '<table role="presentation" width="100%" cellpadding="0" cellspacing="0"><tr><td align="center" style="padding:24px 12px">'
        '<table class="c" role="presentation" width="600" cellpadding="0" cellspacing="0" style="width:100%;max-width:600px">'
        f'{entete}{corps}{breves(ed.get("breves"))}{pied}'
        '</table></td></tr></table></body></html>'
    )


if __name__ == "__main__":
    src = sys.argv[1]
    DOSSIER_EDITION = os.path.dirname(os.path.abspath(src))
    sortie = sys.argv[2] if len(sys.argv) > 2 else os.path.splitext(src)[0] + ".html"
    open(sortie, "w", encoding="utf-8").write(rendre(json.load(open(src, encoding="utf-8"))))
    print(sortie)
