// Globe du logo, dessiné en direct : la terre tourne lentement d'ouest en est.
// Même dessin que le logo statique (outils de la newsletter, logo.py) : disque blanc, graticule fin,
// terres pleines bordeaux, contour épais, projection orthographique centrée à 22° de latitude.
// Un tour en 90 s au repos, en 6 s pendant un chargement. "Réduire les animations" : globe immobile.
// Une seule boucle d'animation pour tous les globes de la page, en pause quand l'app est cachée.

const BORDEAUX = "#6b1d2a";
const FOND = "#ffffff";
const LAT0 = (22 * Math.PI) / 180;
const LON_DEPART = 12;
const VITESSE_REPOS = 360 / 90; // degrés par seconde
const VITESSE_CHARGE = 360 / 6;
const IMAGE_REPOS_MS = 66; // environ 15 images par seconde au repos

const reduit = matchMedia("(prefers-reduced-motion: reduce)");
const globes = new Set();
let terres = null;
let angle = 0;
let vitesse = VITESSE_REPOS;
let chargements = 0;
let precedent = 0;
let dernierDessin = 0;
let boucle = 0;

fetch(new URL("./geo/terre.json", import.meta.url))
  .then((r) => (r.ok ? r.json() : null))
  .then((d) => {
    terres = d;
    toutDessiner();
  })
  .catch(() => {});

function projeter(lon, lat, lon0) {
  const phi = (lat * Math.PI) / 180;
  const dl = ((lon - lon0) * Math.PI) / 180;
  const cp = Math.cos(phi);
  let x = cp * Math.sin(dl);
  let y = Math.cos(LAT0) * Math.sin(phi) - Math.sin(LAT0) * cp * Math.cos(dl);
  const visible = Math.sin(LAT0) * Math.sin(phi) + Math.cos(LAT0) * cp * Math.cos(dl) > 0;
  if (!visible) {
    const r = Math.hypot(x, y) || 1;
    x /= r;
    y /= r;
  }
  return [x, y, visible];
}

function dessiner(g) {
  const { ctx, taille } = g;
  const r = taille / 2 - Math.max(1, taille * 0.02);
  const lon0 = LON_DEPART - angle;
  const fin = Math.max(0.5, taille * 0.006);
  ctx.setTransform(g.ratio, 0, 0, g.ratio, 0, 0);
  ctx.clearRect(0, 0, taille, taille);
  ctx.save();
  ctx.translate(taille / 2, taille / 2);
  ctx.beginPath();
  ctx.arc(0, 0, r, 0, Math.PI * 2);
  ctx.fillStyle = FOND;
  ctx.fill();
  ctx.clip();

  // Graticule tous les 30 degrés : seuls les morceaux visibles sont tracés.
  ctx.strokeStyle = BORDEAUX;
  ctx.lineWidth = fin;
  ctx.beginPath();
  const tracer = (points) => {
    let enCours = false;
    for (const [lon, lat] of points) {
      const [x, y, v] = projeter(lon, lat, lon0);
      if (!v) { enCours = false; continue; }
      if (enCours) ctx.lineTo(x * r, -y * r);
      else ctx.moveTo(x * r, -y * r);
      enCours = true;
    }
  };
  for (let lat = -60; lat <= 60; lat += 30) {
    const pts = [];
    for (let lon = -180; lon <= 180; lon += 4) pts.push([lon, lat]);
    tracer(pts);
  }
  for (let lon = -180; lon < 180; lon += 30) {
    const pts = [];
    for (let lat = -90; lat <= 90; lat += 4) pts.push([lon, lat]);
    tracer(pts);
  }
  ctx.stroke();

  // Terres pleines. Un point caché est ramené sur le bord du disque, le découpage fait le reste.
  if (terres) {
    ctx.fillStyle = BORDEAUX;
    for (const anneau of terres) {
      let vu = false;
      const xy = [];
      for (let i = 0; i < anneau.length; i += 2) {
        const [x, y, v] = projeter(anneau[i], anneau[i + 1], lon0);
        vu ||= v;
        xy.push(x * r, -y * r);
      }
      if (!vu) continue;
      ctx.beginPath();
      ctx.moveTo(xy[0], xy[1]);
      for (let i = 2; i < xy.length; i += 2) ctx.lineTo(xy[i], xy[i + 1]);
      ctx.fill();
    }
  }
  ctx.restore();

  ctx.save();
  ctx.translate(taille / 2, taille / 2);
  ctx.beginPath();
  ctx.arc(0, 0, r, 0, Math.PI * 2);
  ctx.strokeStyle = BORDEAUX;
  ctx.lineWidth = Math.max(1, taille * 0.035);
  ctx.stroke();
  ctx.restore();
}

function toutDessiner() {
  for (const g of globes) dessiner(g);
}

function tourner(t) {
  boucle = 0;
  if (document.hidden || reduit.matches || !globes.size) return;
  const dt = precedent ? Math.min(0.1, (t - precedent) / 1000) : 0;
  precedent = t;
  const cible = chargements > 0 ? VITESSE_CHARGE : VITESSE_REPOS;
  vitesse += (cible - vitesse) * Math.min(1, dt * 2.5); // accélère et ralentit sans à-coup
  angle = (angle + vitesse * dt) % 360;
  if (chargements > 0 || Math.abs(vitesse - VITESSE_REPOS) > 0.5 || t - dernierDessin >= IMAGE_REPOS_MS) {
    dernierDessin = t;
    toutDessiner();
  }
  boucle = requestAnimationFrame(tourner);
}

function relancer() {
  if (boucle || document.hidden || reduit.matches) return;
  precedent = 0;
  boucle = requestAnimationFrame(tourner);
}

document.addEventListener("visibilitychange", relancer);
reduit.addEventListener?.("change", () => { toutDessiner(); relancer(); });

// Transforme un <canvas> en globe animé de `taille` pixels CSS.
export function globe(canvas, taille) {
  const ratio = Math.min(3, window.devicePixelRatio || 1);
  canvas.width = Math.round(taille * ratio);
  canvas.height = Math.round(taille * ratio);
  canvas.style.width = `${taille}px`;
  canvas.style.height = `${taille}px`;
  const g = { ctx: canvas.getContext("2d"), taille, ratio };
  globes.add(g);
  dessiner(g);
  relancer();
}

// Encadre une opération asynchrone : le globe accélère pendant qu'elle dure.
export async function pendantChargement(promesse) {
  chargements += 1;
  relancer();
  try {
    return await promesse;
  } finally {
    chargements -= 1;
  }
}
