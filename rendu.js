// Rendu des éditions (schémas : voir outils/publier.py).
// Tout le texte passe par textContent : aucun HTML venu des données n'est interprété.

function el(balise, classe, texte) {
  const n = document.createElement(balise);
  if (classe) n.className = classe;
  if (texte != null) n.textContent = texte;
  return n;
}

function lien(source, texte) {
  const a = el("a", null, texte ?? source.titre);
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
  if (!element.legende && !element.credit && !element.lien) return null;
  const c = el("figcaption", "note", element.legende || "");
  if (element.lien) {
    if (c.textContent) c.append(" ");
    c.append(lien({ url: element.lien }, "Version interactive"), ".");
  }
  if (element.credit) {
    if (c.textContent) c.append(" ");
    c.append(lien(element.credit), ".");
  }
  return c;
}

function image(element, { zoom = true } = {}) {
  const img = el("img");
  img.src = element.src || element.url;
  img.alt = element.type === "carte" ? `Carte : ${element.ville}` : (element.legende || "");
  img.loading = "lazy";
  img.decoding = "async";
  if (zoom) {
    img.tabIndex = 0;
    img.dataset.zoom = "";
  }
  return img;
}

function figure(element, classe) {
  const f = el("figure", [element.type === "carte" ? "carte" : "photo", classe].filter(Boolean).join(" "));
  const img = image(element);
  img.addEventListener("error", () => f.remove(), { once: true });
  f.append(img);
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
      return figure(b, b.type === "image" && (b.largeur ?? 552) >= 500 ? "large" : null);
    case "duo": {
      const d = el("div", "duo");
      for (const e of b.elements ?? []) d.append(figure(e));
      return d;
    }
    case "schema": {
      const d = el("figure", "schema");
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

function corps(r) {
  const frag = document.createDocumentFragment();
  for (const b of r.blocs ?? []) {
    const n = bloc(b);
    if (n) frag.append(n);
  }
  if (r.a_retenir) frag.append(el("h3", "sous-titre", "À retenir"), el("p", "texte", r.a_retenir));
  const fin = ligneSources(r.sources, r.note_sources);
  fin.classList.add("sources");
  frag.append(fin);
  return frag;
}

function une(ed) {
  const s = el("section", "une");
  s.setAttribute("aria-labelledby", "une-titre");
  const t = el("h2", "rubrique-nom", "Actu");
  t.id = "une-titre";
  s.append(t, el("p", "une-texte", ed.une.texte), ligneSources(ed.une.sources));
  return s;
}

function rubrique(r, i) {
  const s = el("article", "rubrique");
  s.id = `r${i + 1}`;
  s.append(el("p", "rubrique-nom", r.etiquette), el("h2", "titre", r.titre), corps(r));
  return s;
}

function breves(liste) {
  const s = el("section", "breves");
  s.id = "breves";
  s.append(el("h2", "titre", "En bref"));
  const l = el("div", "breves-liste");
  for (const br of liste) {
    const d = el("div", "breve");
    d.append(el("h3", "rubrique-nom", br.rubrique));
    for (const item of br.items ?? []) d.append(el("p", "texte", `- ${item}`));
    d.append(ligneSources(br.sources));
    l.append(d);
  }
  s.append(l);
  return s;
}

// Dossiers de la semaine : repliés, représentés par leur image, ouverts au toucher.
function semaine(heb) {
  const s = el("section", "semaine");
  s.append(el("h2", "titre semaine-entete", "Dossiers de la semaine"));
  heb.sujets.forEach((sujet, i) => {
    const d = el("details", "dossier");
    d.id = `s${i + 1}`;
    const resume = el("summary");
    if (sujet.couverture) {
      const c = image(sujet.couverture, { zoom: false });
      c.className = "couverture";
      c.alt = "";
      c.addEventListener("error", () => c.remove(), { once: true });
      resume.append(c);
    }
    const textes = el("div", "dossier-entete");
    textes.append(el("p", "rubrique-nom", sujet.etiquette), el("h3", "titre", sujet.titre));
    if (sujet.chapo) textes.append(el("p", "chapo", sujet.chapo));
    textes.append(el("p", "note ouvrir", "Lire le dossier"));
    resume.append(textes);
    const contenu = el("div", "dossier-corps");
    const l = sujet.couverture ? legende(sujet.couverture) : null;
    if (l) contenu.append(l);
    contenu.append(corps(sujet));
    d.append(resume, contenu);
    d.addEventListener("toggle", () => {
      d.querySelector(".ouvrir").textContent = d.open ? "Replier" : "Lire le dossier";
    });
    s.append(d);
  });
  return s;
}

// Affiche l'édition du jour ("jour") ou de la semaine ("semaine"). Renvoie le pied de page,
// que app.js complète avec l'état hors ligne.
export function rendre(conteneur, vue, ed, heb) {
  const frag = document.createDocumentFragment();
  const pied = el("footer", "pied");
  if (vue === "jour" && ed) {
    if (ed.une) frag.append(une(ed));
    (ed.rubriques ?? []).forEach((r, i) => frag.append(rubrique(r, i)));
    if (ed.breves?.length) frag.append(breves(ed.breves));
    const jour = (ed.date_texte || "").split(" ").slice(1).join(" ");
    pied.append(el("p", "note", `Rédigé par Claude à partir de sources publiques consultées le ${jour}.`));
  } else if (vue === "semaine" && heb?.sujets?.length) {
    frag.append(semaine(heb));
    pied.append(el("p", "note", "Dossiers rédigés par Claude à partir de sources publiques, publiés chaque lundi."));
  } else {
    frag.append(el("p", "note", vue === "semaine"
      ? "Pas encore d'édition de la semaine sur cet appareil."
      : "Pas encore d'édition du jour sur cet appareil."));
  }
  frag.append(pied);
  conteneur.replaceChildren(frag);
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

// Agrandissement d'une image au toucher ou au clic (cartes, graphiques, portraits).
export function activerZoom(racine, dialogue) {
  const vue = dialogue.querySelector("img");
  const texte = dialogue.querySelector("p");
  const ouvrir = (img) => {
    vue.src = img.currentSrc || img.src;
    vue.alt = img.alt;
    texte.textContent = img.closest("figure")?.querySelector("figcaption")?.textContent ?? "";
    dialogue.showModal();
  };
  racine.addEventListener("click", (e) => {
    const img = e.target.closest?.("img[data-zoom]");
    if (img) ouvrir(img);
  });
  racine.addEventListener("keydown", (e) => {
    if ((e.key === "Enter" || e.key === " ") && e.target.matches?.("img[data-zoom]")) {
      e.preventDefault();
      ouvrir(e.target);
    }
  });
  dialogue.addEventListener("click", () => dialogue.close());
}
