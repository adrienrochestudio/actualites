// Rendu des éditions (schémas : voir outils/publier.py).
// Tout le texte passe par textContent : aucun HTML venu des données n'est interprété.
// Textes de l'interface : textes.js, selon le profil choisi.

import { t } from "./textes.js";

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

// Un média ou une institution n'apparaît qu'une fois, sous son nom court (lien vers le premier article cité).
function sourcesUniques(sources) {
  const vus = new Set();
  return (sources ?? []).filter((s) => {
    const nom = (s.titre || "").trim().toLowerCase();
    if (!nom || vus.has(nom)) return false;
    vus.add(nom);
    return true;
  });
}

function ligneSources(toutes, apres) {
  const p = el("p", "note");
  const sources = sourcesUniques(toutes);
  if (!sources.length) return p;
  p.append(sources.length === 1 ? t("source") : t("sources"));
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
    c.append(lien({ url: element.lien }, t("versionInteractive")), ".");
  }
  if (element.credit) {
    if (c.textContent) c.append(" ");
    c.append(lien(element.credit), ".");
  }
  return c;
}

// Graphique Our World in Data : la version interactive s'ouvre à l'agrandissement.
function interactif(url) {
  try {
    const h = new URL(url).hostname;
    return h === "ourworldindata.org" || h.endsWith(".ourworldindata.org");
  } catch {
    return false;
  }
}

function image(element, { zoom = true } = {}) {
  const img = el("img");
  if (zoom && element.lien && interactif(element.lien)) img.dataset.interactif = element.lien;
  img.src = element.src || element.url;
  img.alt = element.type === "carte" ? `${t("carte")}${element.ville}` : (element.legende || "");
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
    case "barres":
      // Dessiné à la publication (outils/schema.py).
      return b.src ? figure({ ...b, type: "image", largeur: 1100 }, "large schema-image") : null;
    case "schema": {
      if (b.src) return figure({ ...b, type: "image", largeur: 1100 }, "large schema-image");
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

// Bouton "Garder" en fin d'article ; app.js en gère l'état (cle : "date|id").
function actions(cle, options) {
  const p = el("p", "note actions");
  if (!cle || !options.garder) return p;
  const b = el("button", "action-garder");
  b.type = "button";
  b.dataset.garder = cle;
  options.garder.etiqueter(b);
  p.append(b);
  return p;
}

function corps(r, cle, options = {}) {
  const frag = document.createDocumentFragment();
  for (const b of r.blocs ?? []) {
    const n = bloc(b);
    if (n) frag.append(n);
  }
  if (r.a_retenir) frag.append(el("h3", "sous-titre", t("aRetenir")), el("p", "texte", r.a_retenir));
  const fin = ligneSources(r.sources, r.note_sources);
  fin.classList.add("sources");
  frag.append(fin, actions(cle, options));
  return frag;
}

function une(ed) {
  const s = el("section", "une");
  s.id = "une";
  s.setAttribute("aria-labelledby", "une-titre");
  const titre = el("h2", "rubrique-nom", t("actu"));
  titre.id = "une-titre";
  s.append(titre, el("p", "une-texte", ed.une.texte));
  if (ed.une.image) s.append(bloc({ type: "image", largeur: 360, ...ed.une.image }));
  s.append(ligneSources(ed.une.sources));
  return s;
}

function rubrique(r, id, cle, options, nom = r.etiquette) {
  const s = el("article", "rubrique");
  s.id = id;
  s.append(el("p", "rubrique-nom", nom), el("h2", "titre", r.titre), corps(r, cle, options));
  return s;
}

// Quiz de fin d'édition : un choix par question, réponse et explication aussitôt.
function quiz(questions, etat) {
  const s = el("section", "quiz");
  s.id = "quiz";
  s.append(el("h2", "titre", t("quiz")));
  const reponses = etat.reponses.slice();
  const score = el("p", "note quiz-score");
  const majScore = () => {
    const faites = reponses.filter((r) => r >= 0).length;
    const justes = questions.filter((q, i) => reponses[i] === q.reponse).length;
    score.textContent = faites === questions.length ? t("sur")(justes, questions.length) : "";
  };
  questions.forEach((q, i) => {
    const bloc = el("div", "question");
    bloc.append(el("p", "texte question-texte", q.question));
    const liste = el("div", "choix");
    const suite = el("div", "reponse");
    const montrer = () => {
      const r = reponses[i];
      if (r < 0) return;
      [...liste.children].forEach((b, j) => {
        b.disabled = true;
        b.classList.toggle("juste", j === q.reponse);
        b.classList.toggle("faux", j === r && r !== q.reponse);
      });
      const verdict = el("p", "texte");
      verdict.append(el("strong", null, r === q.reponse ? t("exact") : t("non")));
      if (q.explication) verdict.append(" ", q.explication);
      suite.replaceChildren(verdict);
    };
    q.choix.forEach((c, j) => {
      const b = el("button", "choix-bouton", `${"ABCD"[j] ?? j + 1}. ${c}`);
      b.type = "button";
      b.addEventListener("click", () => {
        if (reponses[i] >= 0) return;
        reponses[i] = j;
        etat.enregistrer(reponses);
        montrer();
        majScore();
      });
      liste.append(b);
    });
    bloc.append(liste, suite);
    s.append(bloc);
    montrer();
  });
  majScore();
  s.append(score);
  return s;
}

function breves(liste) {
  const s = el("section", "breves");
  s.id = "breves";
  s.append(el("h2", "titre", t("enBref")));
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
function semaine(heb, options) {
  const s = el("section", "semaine");
  s.append(el("h2", "titre semaine-entete", t("dossiersSemaine")));
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
    textes.append(el("p", "note ouvrir", t("lireDossier")));
    resume.append(textes);
    const contenu = el("div", "dossier-corps");
    const l = sujet.couverture ? legende(sujet.couverture) : null;
    if (l) contenu.append(l);
    contenu.append(corps(sujet, heb.date ? `${heb.date}|s${i + 1}` : null, options));
    d.append(resume, contenu);
    d.addEventListener("toggle", () => {
      d.querySelector(".ouvrir").textContent = d.open ? t("replier") : t("lireDossier");
    });
    s.append(d);
  });
  return s;
}

// Date sans le jour de la semaine : "27 octobre 2026", "27 de outubro de 2026".
function sansJour(dateTexte) {
  return (dateTexte || "").replace(/^[^\s,]+,?\s+/, "");
}

// Affiche l'édition du jour ("jour"), de la semaine ("semaine") ou les articles gardés ("gardes").
// options : { garder: { etiqueter(bouton) }, gardes: [{ cle, date_texte, article }], quiz: { reponses, enregistrer } }
export function rendre(conteneur, vue, ed, heb, options = {}) {
  const frag = document.createDocumentFragment();
  const pied = el("footer", "pied");
  if (vue === "jour" && ed) {
    if (ed.une) frag.append(une(ed));
    (ed.rubriques ?? []).forEach((r, i) => frag.append(rubrique(r, `r${i + 1}`, ed.date ? `${ed.date}|r${i + 1}` : null, options)));
    if (ed.breves?.length) frag.append(breves(ed.breves));
    if (ed.quiz?.length && options.quiz) frag.append(quiz(ed.quiz, options.quiz));
  } else if (vue === "semaine" && heb?.sujets?.length) {
    frag.append(semaine(heb, options));
  } else if (vue === "gardes") {
    const liste = options.gardes ?? [];
    if (!liste.length) frag.append(el("p", "note vide", t("aucunGarde")));
    liste.forEach((g, i) => frag.append(rubrique(g.article, `g${i + 1}`, g.cle, options,
      `${g.article.etiquette} · ${sansJour(g.date_texte)}`)));
  } else {
    frag.append(el("p", "note", vue === "semaine" ? t("videSemaine") : t("videJour")));
  }
  frag.append(pied);
  conteneur.replaceChildren(frag);
  return pied;
}

// Entrées du menu "Rubriques" pour la vue affichée : { id, nom } dans l'ordre de lecture.
export function ancres(vue, ed, heb) {
  if (vue === "jour" && ed) {
    return [
      ...(ed.une ? [{ id: "une", nom: t("actu") }] : []),
      ...(ed.rubriques ?? []).map((r, i) => ({ id: `r${i + 1}`, nom: r.etiquette })),
      ...(ed.breves?.length ? [{ id: "breves", nom: t("enBref") }] : []),
      ...(ed.quiz?.length ? [{ id: "quiz", nom: t("quiz") }] : []),
    ];
  }
  if (vue === "semaine" && heb?.sujets) {
    return heb.sujets.map((s, i) => ({ id: `s${i + 1}`, nom: s.etiquette || s.titre }));
  }
  return [];
}

export function message(conteneur, texte) {
  conteneur.replaceChildren(el("p", "note", texte));
}

// Agrandissement d'une image au toucher ou au clic (cartes, graphiques, portraits).
// Graphique Our World in Data en ligne : sa version interactive (pays, années) remplace l'image.
export function activerZoom(racine, dialogue) {
  const vue = dialogue.querySelector("img");
  const texte = dialogue.querySelector("p");
  const cadre = dialogue.querySelector("iframe");
  const ouvrir = (img) => {
    const url = img.dataset.interactif;
    const enLigne = url && navigator.onLine;
    dialogue.classList.toggle("interactif", Boolean(enLigne));
    cadre.src = enLigne ? url : "about:blank";
    vue.src = img.currentSrc || img.src;
    vue.alt = img.alt;
    texte.textContent = img.closest("figure")?.querySelector("figcaption")?.textContent ?? "";
    dialogue.showModal();
  };
  dialogue.addEventListener("close", () => { cadre.src = "about:blank"; });
  dialogue.querySelector(".fermer-zoom").addEventListener("click", (e) => {
    e.stopPropagation();
    dialogue.close();
  });
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
  // Hors graphique interactif, toucher n'importe où referme ; sinon seulement le bouton Fermer.
  dialogue.addEventListener("click", () => { if (!dialogue.classList.contains("interactif")) dialogue.close(); });
}
