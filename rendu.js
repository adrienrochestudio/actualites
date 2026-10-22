// Rendu d'une édition (schéma de edition.json : voir outils/publier.py).
// Tout le texte passe par textContent : aucun HTML venu des données n'est interprété.

function el(balise, classe, texte) {
  const n = document.createElement(balise);
  if (classe) n.className = classe;
  if (texte != null) n.textContent = texte;
  return n;
}

function lien(source) {
  const a = el("a", null, source.titre);
  a.href = source.url;
  a.target = "_blank";
  a.rel = "noopener noreferrer";
  return a;
}

function ligneSources(sources, apres) {
  const p = el("p", "note");
  if (!sources?.length) return p;
  p.append(sources.length === 1 ? "Source : " : "Sources : ");
  sources.forEach((s, i) => {
    if (i) p.append(", ");
    p.append(lien(s));
  });
  if (apres) p.append(`. ${apres}`);
  return p;
}

function legende(element) {
  if (!element.legende && !element.credit) return null;
  const c = el("figcaption", "note", element.legende || "");
  if (element.credit) {
    if (element.legende) c.append(" ");
    c.append(lien(element.credit), ".");
  }
  return c;
}

function figure(element) {
  const estCarte = element.type === "carte";
  const f = el("figure", estCarte ? "carte" : null);
  const img = el("img");
  img.src = element.src || element.url;
  img.alt = estCarte ? `Carte : ${element.ville}` : (element.legende || "");
  img.loading = "lazy";
  img.decoding = "async";
  if (!estCarte && element.largeur && element.largeur < 500) img.style.width = `${element.largeur}px`;
  img.addEventListener("error", () => f.remove(), { once: true });
  if (element.lien) {
    const a = el("a");
    a.href = element.lien;
    a.target = "_blank";
    a.rel = "noopener noreferrer";
    a.append(img);
    f.append(a);
  } else {
    f.append(img);
  }
  const l = legende(element);
  if (l) f.append(l);
  return f;
}

function bloc(b) {
  switch (b.type) {
    case "p":
      return el("p", "texte", b.texte);
    case "sous_titre":
      return el("h3", "sous-titre", b.texte);
    case "liste": {
      const d = el("div");
      for (const item of b.items ?? []) d.append(el("p", "texte liste", `- ${item}`));
      return d;
    }
    case "image":
    case "carte":
      return figure(b);
    case "duo": {
      const d = el("div", "duo");
      for (const e of b.elements ?? []) d.append(figure(e));
      return d;
    }
    case "schema": {
      const d = el("div", "schema");
      for (const etape of b.etapes ?? []) {
        if ("boite" in etape) {
          const boite = el("div", "boite");
          etape.boite.split("\n").forEach((ligne, i) => {
            if (i) boite.append(el("br"));
            boite.append(ligne);
          });
          d.append(boite);
        } else {
          d.append(el("p", "note fleche", etape.fleche));
        }
      }
      const l = legende(b);
      if (l) d.append(l);
      return d;
    }
    default:
      return null;
  }
}

function ancre(i) {
  return `r${i + 1}`;
}

function entete(ed) {
  const h = el("header", "entete");
  const marque = el("div", "marque");
  const logo = el("img");
  logo.src = "./icons/logo-96.png";
  logo.alt = "";
  marque.append(logo, el("h1", "titre", "Actualités"));
  h.append(marque, el("p", "note date", ed.date_texte));
  if (ed.une) {
    const une = el("section", "une");
    une.setAttribute("aria-label", "À la une");
    une.append(el("p", "texte", ed.une.texte), ligneSources(ed.une.sources));
    h.append(une);
  }
  return h;
}

function sommaire(ed) {
  const nav = el("nav", "sommaire");
  nav.setAttribute("aria-label", "Sommaire");
  nav.append(el("h2", "note", "Sommaire"));
  const ol = el("ol");
  (ed.rubriques ?? []).forEach((r, i) => {
    const a = el("a");
    a.href = `#${ancre(i)}`;
    a.append(el("span", "note", r.etiquette), r.titre);
    const li = el("li");
    li.append(a);
    ol.append(li);
  });
  if (ed.breves?.length) {
    const a = el("a", null, "En bref");
    a.href = "#breves";
    const li = el("li");
    li.append(a);
    ol.append(li);
  }
  nav.append(ol);
  return nav;
}

function rubrique(r, i) {
  const s = el("article", "rubrique");
  s.id = ancre(i);
  s.append(el("p", "note", r.etiquette), el("h2", "titre", r.titre));
  for (const b of r.blocs ?? []) {
    const n = bloc(b);
    if (n) s.append(n);
  }
  if (r.a_retenir) s.append(el("h3", "sous-titre", "À retenir"), el("p", "texte", r.a_retenir));
  const fin = ligneSources(r.sources, r.note_sources);
  fin.classList.add("fin");
  s.append(fin);
  return s;
}

function breves(liste) {
  const s = el("section", "breves");
  s.id = "breves";
  s.append(el("h2", "titre", "En bref"));
  const conteneur = el("div");
  conteneur.style.marginTop = "12px";
  for (const br of liste) {
    const d = el("div", "breve");
    d.append(el("h3", "sous-titre", br.rubrique));
    for (const item of br.items ?? []) d.append(el("p", "texte", `- ${item}`));
    d.append(ligneSources(br.sources));
    conteneur.append(d);
  }
  s.append(conteneur);
  return s;
}

// Renvoie le nœud du pied de page, que app.js complète avec l'état hors ligne.
export function rendre(conteneur, ed) {
  const frag = document.createDocumentFragment();
  frag.append(entete(ed), sommaire(ed));
  (ed.rubriques ?? []).forEach((r, i) => frag.append(rubrique(r, i)));
  if (ed.breves?.length) frag.append(breves(ed.breves));
  const pied = el("footer", "pied");
  const jour = (ed.date_texte || "").split(" ").slice(1).join(" ");
  pied.append(el("p", "note", `Rédigé par Claude à partir de sources publiques consultées le ${jour}.`));
  frag.append(pied);
  conteneur.replaceChildren(frag);
  document.title = `Actualités, ${ed.date_texte}`;
  return pied;
}

export function message(conteneur, texte) {
  conteneur.replaceChildren(el("p", "note", texte));
}

export function ligneEtat(pied, texte) {
  let p = pied.querySelector("[data-etat]");
  if (!p) {
    p = el("p", "note");
    p.dataset.etat = "";
    pied.append(p);
  }
  p.textContent = texte;
}
