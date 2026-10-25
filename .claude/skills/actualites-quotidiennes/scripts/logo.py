"""Logo de la newsletter Actualités : un globe bordeaux, vue orthographique centrée sur l'Europe et l'Afrique.

Sorties : assets/logo.svg, assets/logo-512.png, assets/logo-96.png (en-tête du mail)
Usage : python3 logo.py
"""
import json
import math
import os

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Circle, Polygon

ICI = os.path.dirname(os.path.abspath(__file__))
BORDEAUX = "#6B1D2A"
FOND = "#FFFFFF"
LAT0, LON0 = math.radians(22), math.radians(12)  # centre de la vue


def projeter(lon, lat):
    """Projection orthographique ; un point caché est ramené sur le bord du disque."""
    phi, lam = math.radians(lat), math.radians(lon)
    x = math.cos(phi) * math.sin(lam - LON0)
    y = math.cos(LAT0) * math.sin(phi) - math.sin(LAT0) * math.cos(phi) * math.cos(lam - LON0)
    visible = math.sin(LAT0) * math.sin(phi) + math.cos(LAT0) * math.cos(phi) * math.cos(lam - LON0) > 0
    if not visible:
        r = math.hypot(x, y) or 1.0
        x, y = x / r, y / r
    return x, y, visible


SEUIL_ILE = 0.0006  # aire minimale d'une terre, en unités du disque (rayon 1)


def aire(xy):
    return abs(sum(x1 * y2 - x2 * y1 for (x1, y1), (x2, y2) in zip(xy, xy[1:] + xy[:1]))) / 2


def trait(points, ax, largeur):
    seg = []
    for lon, lat in points:
        x, y, v = projeter(lon, lat)
        if v:
            seg.append((x, y))
        elif seg:
            ax.plot(*zip(*seg), color=BORDEAUX, linewidth=largeur, solid_capstyle="round")
            seg = []
    if len(seg) > 1:
        ax.plot(*zip(*seg), color=BORDEAUX, linewidth=largeur, solid_capstyle="round")


def dessiner(chemin, taille_px, finesse):
    pays = json.load(open(os.path.join(os.path.dirname(ICI), "geo", "pays.geojson"), encoding="utf-8"))["features"]
    fig, ax = plt.subplots(figsize=(4, 4), dpi=taille_px / 4)
    fig.patch.set_alpha(0)
    ax.set_xlim(-1.08, 1.08)
    ax.set_ylim(-1.08, 1.08)
    ax.set_aspect("equal")
    ax.axis("off")

    ax.add_patch(Circle((0, 0), 1, facecolor=FOND, edgecolor="none", zorder=0))

    # Graticule tous les 30 degrés
    for lat in range(-60, 61, 30):
        trait([(lon, lat) for lon in range(-180, 181, 2)], ax, 0.9 * finesse)
    for lon in range(-180, 180, 30):
        trait([(lon, lat) for lat in range(-90, 91, 2)], ax, 0.9 * finesse)

    # Terres pleines
    for p in pays:
        g = p["geometry"]
        if not g:
            continue
        polys = [g["coordinates"]] if g["type"] == "Polygon" else g["coordinates"]
        for poly in polys:
            anneau = poly[0][::3] if len(poly[0]) > 90 else poly[0]
            pts = [projeter(lon, lat) for lon, lat in anneau]
            if not any(v for _, _, v in pts):
                continue
            xy = [(round(x, 4), round(y, 4)) for x, y, _ in pts]
            if aire(xy) < SEUIL_ILE:  # on retire les îlots, illisibles à petite taille
                continue
            ax.add_patch(Polygon(xy, closed=True, facecolor=BORDEAUX, edgecolor=BORDEAUX,
                                 linewidth=1.0 * finesse, zorder=2))

    ax.add_patch(Circle((0, 0), 1, facecolor="none", edgecolor=BORDEAUX, linewidth=3.2 * finesse, zorder=3))
    plt.subplots_adjust(0, 0, 1, 1)
    fig.savefig(chemin, transparent=True)
    plt.close(fig)


if __name__ == "__main__":
    A = os.path.join(os.path.dirname(ICI), "assets")
    os.makedirs(A, exist_ok=True)
    dessiner(os.path.join(A, "logo.svg"), 512, 1.0)
    dessiner(os.path.join(A, "logo-512.png"), 512, 1.0)
    dessiner(os.path.join(A, "logo-96.png"), 96 * 2, 0.9)  # affiché à 48 px, rendu 2x pour les écrans Retina
    print("ok")
