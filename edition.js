// Accès à l'édition : réseau d'abord, copie locale ensuite. Seul module qui touche au cache des éditions.
// Une seule édition est gardée hors ligne : enregistrer() supprime les précédentes.

const URL_EDITION = new URL("./edition/edition.json", location.href).href;
const PREFIXE = "edition-";
const DELAI_RESEAU_MS = 8000;

async function depuisReseau() {
  const ctrl = new AbortController();
  const minuteur = setTimeout(() => ctrl.abort(), DELAI_RESEAU_MS);
  try {
    const rep = await fetch(URL_EDITION, { cache: "no-store", signal: ctrl.signal });
    if (!rep.ok) return null;
    return await rep.json();
  } catch {
    return null;
  } finally {
    clearTimeout(minuteur);
  }
}

async function depuisCache() {
  if (!("caches" in self)) return null;
  const rep = await caches.match(URL_EDITION);
  return rep ? rep.json() : null;
}

// Renvoie { edition, source: "reseau" | "cache" } ou null si rien n'est disponible.
export async function chargerEdition() {
  const enLigne = await depuisReseau();
  if (enLigne) return { edition: enLigne, source: "reseau" };
  const locale = await depuisCache();
  return locale ? { edition: locale, source: "cache" } : null;
}

export async function dateEnregistree() {
  const locale = await depuisCache();
  return locale?.date ?? null;
}

// Toutes les images citées par l'édition (fichiers du dépôt et images libres externes).
export function imagesDe(edition) {
  const urls = new Set();
  const visiter = (bloc) => {
    if (!bloc || typeof bloc !== "object") return;
    if (Array.isArray(bloc.elements)) bloc.elements.forEach(visiter);
    const src = bloc.src || bloc.url;
    if (src) urls.add(src);
  };
  for (const r of edition.rubriques ?? []) (r.blocs ?? []).forEach(visiter);
  return [...urls].map((u) => new URL(u, location.href).href);
}

// Enregistre l'édition et ses images pour la lecture hors ligne. Renvoie le nombre d'images manquées.
export async function enregistrer(edition) {
  if (!("caches" in self) || !edition?.date) return 0;
  const nom = PREFIXE + edition.date;
  const cache = await caches.open(nom);
  await cache.put(URL_EDITION, new Response(JSON.stringify(edition), {
    headers: { "Content-Type": "application/json; charset=utf-8" },
  }));

  let manquees = 0;
  await Promise.all(imagesDe(edition).map(async (url) => {
    try {
      if (await cache.match(url)) return;
      // CORS d'abord (Wikimedia et Our World in Data l'acceptent) pour vérifier le statut.
      // Repli no-cors : réponse opaque, statut invisible, gardée faute de mieux.
      let rep;
      try {
        rep = await fetch(url, { mode: "cors" });
      } catch {
        rep = await fetch(url, { mode: "no-cors" });
      }
      if (rep.type !== "opaque" && !rep.ok) throw new Error(String(rep.status));
      await cache.put(url, rep);
    } catch {
      manquees += 1;
    }
  }));

  const noms = await caches.keys();
  await Promise.all(noms.filter((n) => n.startsWith(PREFIXE) && n !== nom).map((n) => caches.delete(n)));
  return manquees;
}
