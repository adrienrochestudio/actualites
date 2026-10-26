"""Génère geo/terre.json : contours des terres allégés pour le globe animé du logo (web et Mac).

Format : liste d'anneaux, chaque anneau = liste plate [lon, lat, lon, lat, ...] arrondie au degré.
Usage : python3 outils/terre.py
"""
import json
import math
import os

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
AIRE_MIN = 6.0  # degrés carrés (pondérés par cos(lat)) : retire les îlots, invisibles à 40 px


def aire(anneau):
    s = 0.0
    for (x1, y1), (x2, y2) in zip(anneau, anneau[1:] + anneau[:1]):
        s += (x1 * y2 - x2 * y1) * math.cos(math.radians((y1 + y2) / 2))
    return abs(s) / 2


pays = json.load(open(os.path.join(RACINE, "geo", "pays.geojson"), encoding="utf-8"))["features"]
anneaux = []
for p in pays:
    g = p["geometry"]
    if not g:
        continue
    for poly in ([g["coordinates"]] if g["type"] == "Polygon" else g["coordinates"]):
        a = poly[0]
        if aire(a) < AIRE_MIN:
            continue
        pas = max(1, len(a) // 40)
        a = a[::pas]
        anneaux.append([round(v) for pt in a for v in pt])
sortie = os.path.join(RACINE, "geo", "terre.json")
json.dump(anneaux, open(sortie, "w"), separators=(",", ":"))
print(f"{len(anneaux)} anneaux, {os.path.getsize(sortie) // 1024} Ko")
