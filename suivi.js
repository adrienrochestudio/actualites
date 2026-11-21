// État de lecture propre à cet appareil : rubriques lues, réponses au quiz, articles gardés.
// Rangé dans le stockage local, par profil ; chaque accès est protégé (stockage parfois indisponible).

import { imagesDe } from "./edition.js";

const CACHE_GARDES = "gardes";

function lire(cle, defaut) {
  try {
    const v = localStorage.getItem(cle);
    return v ? JSON.parse(v) : defaut;
  } catch {
    return defaut;
  }
}

function ecrire(cle, valeur) {
  try {
    localStorage.setItem(cle, JSON.stringify(valeur));
  } catch {}
}

// Ne garde que les clés du jour pour un préfixe donné ("lus.fr.", "quiz.fr.").
function nettoyer(prefixe, garder) {
  try {
    for (let i = localStorage.length - 1; i >= 0; i--) {
      const k = localStorage.key(i);
      if (k?.startsWith(prefixe) && k !== garder) localStorage.removeItem(k);
    }
  } catch {}
}

// Rubriques lues : { ids: Set, marquer(id) } pour une édition donnée.
export function lus(profil, date) {
  const cle = `lus.${profil}.${date}`;
  nettoyer(`lus.${profil}.`, cle);
  const ids = new Set(lire(cle, []));
  return {
    ids,
    marquer(id) {
      if (ids.has(id)) return false;
      ids.add(id);
      ecrire(cle, [...ids]);
      return true;
    },
  };
}

// Quiz : une entrée par édition, gardée 30 jours pour l'historique des scores.
// { reponses: [index ou -1], date_texte, justes, total }
const JOURS_QUIZ = 30;

export function reponsesQuiz(profil, edition, dateTexte) {
  const cle = `quiz.${profil}.${edition.date}`;
  const limite = new Date(Date.now() - JOURS_QUIZ * 864e5).toISOString().slice(0, 10);
  try {
    for (let i = localStorage.length - 1; i >= 0; i--) {
      const k = localStorage.key(i);
      if (k?.startsWith(`quiz.${profil}.`) && k.slice(-10) < limite) localStorage.removeItem(k);
    }
  } catch {}
  const brut = lire(cle, {});
  const r = Array.isArray(brut) ? brut : brut.reponses ?? []; // ancien format : tableau seul
  const questions = edition.quiz;
  return {
    reponses: questions.map((_, i) => (Number.isInteger(r[i]) ? r[i] : -1)),
    enregistrer: (liste) => ecrire(cle, {
      reponses: liste,
      date_texte: dateTexte,
      total: questions.length,
      justes: questions.filter((q, i) => liste[i] === q.reponse).length,
    }),
    historique: () => historiqueQuiz(profil),
  };
}

// Quiz terminés des 30 derniers jours, du plus récent au plus ancien.
export function historiqueQuiz(profil) {
  const jours = [];
  try {
    for (let i = 0; i < localStorage.length; i++) {
      const k = localStorage.key(i);
      if (!k?.startsWith(`quiz.${profil}.`)) continue;
      const v = lire(k, null);
      if (v && !Array.isArray(v) && v.reponses?.every((x) => x >= 0)) jours.push({ date: k.slice(-10), ...v });
    }
  } catch {}
  return jours.sort((a, b) => b.date.localeCompare(a.date));
}

// Articles gardés : [{ cle, date, date_texte, article }], du plus récent au plus ancien.
export function gardes(profil) {
  return lire(`gardes.${profil}`, []);
}

export function estGarde(profil, cle) {
  return gardes(profil).some((g) => g.cle === cle);
}

export async function garder(profil, cle, edition, article) {
  const liste = gardes(profil).filter((g) => g.cle !== cle);
  liste.unshift({ cle, date: edition.date, date_texte: edition.date_texte, article });
  ecrire(`gardes.${profil}`, liste);
  // Images de l'article : copie dans un cache à part, qui survit au remplacement de l'édition.
  if (!("caches" in self)) return;
  try {
    const cache = await caches.open(CACHE_GARDES);
    await Promise.all(imagesDe({ rubriques: [article] }).map(async (url) => {
      if (await cache.match(url)) return;
      const rep = (await caches.match(url)) || (await fetch(url, { mode: "no-cors" }));
      await cache.put(url, rep.clone());
    }));
  } catch {}
}

export async function retirer(profil, cle) {
  const liste = gardes(profil);
  const g = liste.find((x) => x.cle === cle);
  const reste = liste.filter((x) => x.cle !== cle);
  ecrire(`gardes.${profil}`, reste);
  if (!g || !("caches" in self)) return;
  // Retirer les images qui ne servent plus à aucun article gardé (tous profils).
  try {
    const utiles = new Set(["fr", "pt"].flatMap((p) => gardes(p)).flatMap((x) => imagesDe({ rubriques: [x.article] })));
    const cache = await caches.open(CACHE_GARDES);
    await Promise.all(imagesDe({ rubriques: [g.article] }).filter((u) => !utiles.has(u)).map((u) => cache.delete(u)));
  } catch {}
}
