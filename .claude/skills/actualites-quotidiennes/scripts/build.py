"""Emballe une édition rendue : compresse les images, contrôle les limites, produit l'aperçu et la version mail.

Entrée : HTML rendu ; images en assets/... (racine du projet) ou images/... (dossier de l'édition)
Sorties (dans le dossier de l'entrée) :
- <nom>-apercu.html : images en base64, pour l'aperçu
- <nom>-mail.html   : images en cid:, pour l'envoi Gmail
- <nom>-pieces.json : pièces jointes inline (filename, mimeType, inline, content base64)
- <nom>.txt         : texte brut, pour l'audit sans-trace-ia

Images externes (https://, licence libre) : laissées telles quelles dans le mail, chargées par Gmail,
intégrées dans l'aperçu seulement si le téléchargement réussit.
Images locales (logo, cartes) : compressées puis jointes en cid:.

Contrôles bloquants : HTML mail < 90 Ko (Gmail tronque à 102 Ko), image jointe <= 40 Ko, total joint <= 120 Ko.
Le script affiche une estimation des tokens de l'appel d'envoi (HTML + pièces en base64).

Usage : python3 build.py editions/AAAA-MM-JJ/edition.html
"""
import base64
import io
import json
import os
import re
import sys
import urllib.request

from PIL import Image

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # racine du skill, où vit assets/
LIMITE_HTML = 90 * 1024
LIMITE_IMAGE = 40 * 1024   # images jointes : leur base64 passe dans l'appel d'envoi, donc en tokens
LIMITE_TOTAL = 120 * 1024
LARGEUR_MAX = 1104  # 552 px affichés en 2x


def compresser(chemin):
    """Renvoie (octets, mime) : JPEG pour les photos, PNG à palette réduite pour cartes et logos."""
    im = Image.open(chemin)
    if im.width > LARGEUR_MAX:
        im = im.resize((LARGEUR_MAX, round(im.height * LARGEUR_MAX / im.width)), Image.LANCZOS)
    tampon = io.BytesIO()
    if chemin.lower().endswith((".jpg", ".jpeg")):
        im.convert("RGB").save(tampon, "JPEG", quality=78, optimize=True, progressive=True)
        return tampon.getvalue(), "image/jpeg"
    transparent = im.mode in ("RGBA", "LA") or "transparency" in im.info
    if transparent:
        im.convert("RGBA").quantize(colors=16, method=Image.FASTOCTREE).save(tampon, "PNG", optimize=True)
    else:
        im.convert("RGB").quantize(colors=16).save(tampon, "PNG", optimize=True)
    return tampon.getvalue(), "image/png"


def main(source):
    base = os.path.dirname(os.path.abspath(source))
    nom = os.path.splitext(os.path.basename(source))[0]
    html = open(source, encoding="utf-8").read()
    html = re.sub(r"<!--.*?-->\n?", "", html, flags=re.S)

    apercu, mail, pieces, erreurs, total = html, html, [], [], 0
    for chemin in sorted(set(re.findall(r'src="((?:assets|images)/[^"]+)"', html))):
        racine = RACINE if chemin.startswith("assets/") else base
        octets, mime = compresser(os.path.join(racine, chemin))
        total += len(octets)
        if len(octets) > LIMITE_IMAGE:
            erreurs.append(f"image trop lourde : {chemin} ({len(octets) // 1024} Ko)")
        donnees = base64.b64encode(octets).decode()
        nom_fichier = os.path.basename(chemin)
        apercu = apercu.replace(f'src="{chemin}"', f'src="data:{mime};base64,{donnees}"')
        mail = mail.replace(f'src="{chemin}"', f'src="cid:{nom_fichier}"')
        pieces.append({"filename": nom_fichier, "mimeType": mime, "inline": True, "content": donnees})

    for url in sorted(set(re.findall(r'src="(https://[^"]+)"', html))):
        try:
            requete = urllib.request.Request(url.replace("&amp;", "&"), headers={"User-Agent": "ActualitesNewsletter/1.0"})
            octets = urllib.request.urlopen(requete, timeout=20).read()
            mime = "image/jpeg" if octets[:2] == b"\xff\xd8" else "image/png"
            apercu = apercu.replace(f'src="{url}"', f'src="data:{mime};base64,{base64.b64encode(octets).decode()}"')
        except Exception as exc:
            print(f"aperçu : image externe non intégrée ({exc.__class__.__name__}) {url[:70]}")

    taille_mail = len(mail.encode())
    if taille_mail > LIMITE_HTML:
        erreurs.append(f"HTML mail trop lourd : {taille_mail // 1024} Ko")
    if total > LIMITE_TOTAL:
        erreurs.append(f"images trop lourdes au total : {total // 1024} Ko")

    texte = re.sub(r"<(?:p|div|tr|br)[^>]*>", "\n", re.sub(r"<style.*?</style>", "", html, flags=re.S))
    texte = re.sub(r"\n\s*\n+", "\n\n", __import__("html").unescape(re.sub(r"<[^>]+>", "", texte)))
    open(os.path.join(base, f"{nom}.txt"), "w", encoding="utf-8").write(texte)  # pour l'audit sans-trace-ia
    open(os.path.join(base, f"{nom}-apercu.html"), "w", encoding="utf-8").write(apercu)
    open(os.path.join(base, f"{nom}-mail.html"), "w", encoding="utf-8").write(mail)
    json.dump(pieces, open(os.path.join(base, f"{nom}-pieces.json"), "w"))
    b64 = sum(len(p["content"]) for p in pieces)
    print(f"{len(pieces)} images jointes ({total // 1024} Ko), HTML mail {taille_mail // 1024} Ko, "
          f"appel d'envoi estimé à {round((taille_mail / 3.5 + b64 / 2.2) / 1000)} k tokens")
    if erreurs:
        print("ERREURS :\n- " + "\n- ".join(erreurs))
        sys.exit(1)
    print("contrôles OK")


if __name__ == "__main__":
    main(sys.argv[1])
