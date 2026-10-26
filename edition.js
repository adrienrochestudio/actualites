// Accès aux contenus publiés : réseau d'abord, copie locale ensuite.
// Deux contenus indépendants par profil (fr, pt) : l'édition du jour et l'édition de la semaine,
// publiés dans {profil}/edition/edition.json et {profil}/hebdo/hebdo.json.
// Hors ligne, un seul exemplaire de chacun et pour le seul profil choisi : enregistrer() supprime
// les précédents, ceux de l'autre profil et ceux de l'ancienne organisation (caches "edition-AAAA-MM-JJ").

const CHEMINS = { jour: ["edition", "edition.json"], semaine: ["hebdo", "hebdo.json"] };

function contenu(cle, profil) {
  const [dossier, fichier] = CHEMINS[cle];
  return {
    url: new URL(`./${profil}/${dossier}/${fichier}`, location.href).href,
    prefixe: `${dossier}-`,
    nom: (date) => `${dossier}-${profil}-${date}`,
  };
}
const DELAI_RESEAU_MS = 8000;

async function depuisReseau(url) {
  const ctrl = new AbortController();
  const minuteur = setTimeout(() => ctrl.abort(), DELAI_RESEAU_MS);
  try {
    const rep = await fetch(url, { cache: "no-store", signal: ctrl.signal });
    if (!rep.ok) return null;
    return await rep.json();
  } catch {
    return null;
  } finally {
    clearTimeout(minuteur);
  }
}

async function depuisCache(url) {
  if (!("caches" in self)) return null;
  const rep = await caches.match(url);
  return rep ? rep.json() : null;
}

// Renvoie { donnees, source: "reseau" | "cache" } ou null si rien n'est disponible.
export async function charger(cle, profil) {
  const { url } = contenu(cle, profil);
  const enLigne = await depuisReseau(url);
  if (enLigne) return { donnees: enLigne, source: "reseau" };
  const locale = await depuisCache(url);
  return locale ? { donnees: locale, source: "cache" } : null;
}

// Toutes les images citées (blocs, éléments de duo, couvertures des sujets de la semaine).
export function imagesDe(donnees) {
  const urls = new Set();
  const visiter = (bloc) => {
    if (!bloc || typeof bloc !== "object") return;
    if (Array.isArray(bloc.elements)) bloc.elements.forEach(visiter);
    const src = bloc.src || bloc.url;
    if (src) urls.add(src);
  };
  for (const r of [...(donnees.rubriques ?? []), ...(donnees.sujets ?? [])]) {
    visiter(r.couverture);
    (r.blocs ?? []).forEach(visiter);
  }
  return [...urls].map((u) => new URL(u, location.href).href);
}

// Enregistre le contenu et ses images pour la lecture hors ligne. Renvoie le nombre d'images manquées.
export async function enregistrer(cle, profil, donnees) {
  if (!("caches" in self) || !donnees?.date) return 0;
  const { url, prefixe, nom: nommer } = contenu(cle, profil);
  const nom = nommer(donnees.date);
  const cache = await caches.open(nom);
  await cache.put(url, new Response(JSON.stringify(donnees), {
    headers: { "Content-Type": "application/json; charset=utf-8" },
  }));

  let manquees = 0;
  await Promise.all(imagesDe(donnees).map(async (img) => {
    try {
      if (await cache.match(img)) return;
      // CORS d'abord (Wikimedia et Our World in Data l'acceptent) pour vérifier le statut.
      // Repli no-cors : réponse opaque, statut invisible, gardée faute de mieux.
      let rep;
      try {
        rep = await fetch(img, { mode: "cors" });
      } catch {
        rep = await fetch(img, { mode: "no-cors" });
      }
      if (rep.type !== "opaque" && !rep.ok) throw new Error(String(rep.status));
      await cache.put(img, rep);
    } catch {
      manquees += 1;
    }
  }));

  const noms = await caches.keys();
  await Promise.all(noms.filter((n) => n.startsWith(prefixe) && n !== nom).map((n) => caches.delete(n)));
  return manquees;
}
