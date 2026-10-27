import { charger, enregistrer } from "./edition.js";
import { rendre, message, activerZoom, ancres } from "./rendu.js";
import { t, PROFILS, profilActuel, changerProfil, nomLangue, retirerParametreLangue } from "./textes.js";
import { globe, pendantChargement } from "./globe.js";
import * as suivi from "./suivi.js";

const journal = document.getElementById("journal");
const RELECTURE_MIN_MS = 10 * 60 * 1000;

let affiche = { jour: null, semaine: null };
let contenus = { jour: null, semaine: null };
let derniereVerif = 0;
let vue = "jour";
try { if (localStorage.getItem("vue") === "semaine") vue = "semaine"; } catch {}

const installee = matchMedia("(display-mode: standalone)").matches || navigator.standalone === true;
const ligneDate = document.getElementById("date");
const boutonsVue = [...document.querySelectorAll("[data-vue]")];

// Textes fixes de la page (attributs data-t et data-t-label), dans la langue du profil.
function traduirePage() {
  document.documentElement.lang = t("htmlLang");
  for (const n of document.querySelectorAll("[data-t]")) n.textContent = t(n.dataset.t);
  for (const n of document.querySelectorAll("[data-t-label]")) n.setAttribute("aria-label", t(n.dataset.tLabel));
}

// Rubriques lues de l'édition du jour affichée.
let lecture = null;
const observateur = "IntersectionObserver" in window ? new IntersectionObserver((entrees) => {
  for (const e of entrees) {
    // Fin visible, ou déjà passée au-dessus de l'écran (lecture rapide, saut par le menu).
    if ((e.isIntersecting || e.boundingClientRect.bottom < 0) && lecture?.marquer(e.target.dataset.fin)) observateur.unobserve(e.target);
  }
}, { rootMargin: "0px 0px -10% 0px" }) : null;

// Une rubrique est lue quand sa fin (sources, dernière brève, score du quiz) est passée à l'écran.
function suivreLecture() {
  observateur?.disconnect();
  const ed = contenus.jour?.donnees;
  if (vue !== "jour" || !ed?.date || !observateur) return;
  lecture = suivi.lus(profilActuel(), ed.date);
  for (const { id } of ancres("jour", ed)) {
    const fin = document.getElementById(id)?.lastElementChild;
    if (!fin || lecture.ids.has(id)) continue;
    fin.dataset.fin = id;
    observateur.observe(fin);
  }
}

const sansJourSemaine = (d) => (d || "").replace(/^[^\s,]+,?\s+/, "");

const etiqueterGarde = (b) => {
  b.textContent = suivi.estGarde(profilActuel(), b.dataset.garder) ? `${t("garde")} · ${t("retirer")}` : t("garder");
};

function dessiner() {
  for (const b of boutonsVue) b.setAttribute("aria-pressed", String(b.dataset.vue === vue));
  const { jour, semaine } = contenus;
  const ed = jour?.donnees;
  ligneDate.textContent = vue === "jour" ? (ed?.date_texte ?? "")
    : vue === "semaine" ? (semaine?.donnees.date_texte_semaine ?? semaine?.donnees.date_texte ?? "")
    : t("articlesGardes");
  rendre(journal, vue, ed, semaine?.donnees, {
    garder: { etiqueter: etiqueterGarde },
    gardes: suivi.gardes(profilActuel()),
    quiz: ed?.quiz?.length && ed.date ? suivi.reponsesQuiz(profilActuel(), ed, sansJourSemaine(ed.date_texte)) : null,
  });
  suivreLecture();
  document.title = vue === "semaine" ? t("titreSemaine") : "Actualités";
}

// Garder ou retirer un article (bouton en fin de rubrique ou de dossier).
journal.addEventListener("click", async (e) => {
  const b = e.target.closest?.("button[data-garder]");
  if (!b) return;
  const cle = b.dataset.garder;
  const profil = profilActuel();
  if (suivi.estGarde(profil, cle)) {
    await suivi.retirer(profil, cle);
    if (vue === "gardes") return dessiner();
  } else {
    const [, id] = cle.split("|");
    const source = id.startsWith("s") ? contenus.semaine?.donnees : contenus.jour?.donnees;
    const liste = id.startsWith("s") ? source?.sujets : source?.rubriques;
    const article = liste?.[Number(id.slice(1)) - 1];
    if (!article) return;
    await suivi.garder(profil, cle, source, article);
  }
  etiqueterGarde(b);
});

function changerVue(v) {
  if (v === vue) return;
  vue = v;
  try { localStorage.setItem("vue", vue); } catch {}
  dessiner();
  scrollTo(0, 0);
}

for (const b of document.querySelectorAll(".onglets [data-vue]")) b.addEventListener("click", () => changerVue(b.dataset.vue));

// Charge les éditions du profil. silencieux : ne redessine que si une édition a changé.
// Renvoie true si l'affichage a changé.
async function afficher({ silencieux = false } = {}) {
  derniereVerif = Date.now();
  const profil = profilActuel();
  const [jour, semaine] = await pendantChargement(Promise.all([charger("jour", profil), charger("semaine", profil)]));
  if (profil !== profilActuel()) return false; // profil changé pendant le chargement
  if (!jour && !semaine) {
    if (!affiche.jour && !affiche.semaine) message(journal, t("rien"));
    return false;
  }
  const dates = { jour: jour?.donnees.date ?? null, semaine: semaine?.donnees.date ?? null };
  if (silencieux && dates.jour === affiche.jour && dates.semaine === affiche.semaine) return false;

  // Garder les dossiers ouverts quand on réaffiche la même semaine.
  const ouverts = dates.semaine === affiche.semaine
    ? [...journal.querySelectorAll("details[open]")].map((d) => d.id) : [];
  const nouveauJour = affiche.jour && affiche.jour !== dates.jour;
  contenus = { jour, semaine };
  affiche = dates;

  const enLigne = [jour, semaine].some((c) => c?.source === "reseau");
  dessiner();
  for (const id of ouverts) document.getElementById(id)?.setAttribute("open", "");
  if (nouveauJour && vue === "jour") scrollTo(0, 0);

  if (enLigne) {
    const manquees = (await Promise.all([
      jour?.source === "reseau" ? enregistrer("jour", profil, jour.donnees) : 0,
      semaine?.source === "reseau" ? enregistrer("semaine", profil, semaine.donnees) : 0,
    ])).reduce((a, b) => a + b, 0);
    if (manquees) console.info(`${manquees} image(s) non enregistrée(s) pour la lecture hors ligne`);
  }
  return true;
}

// Menu latéral : langue (= profil), rubriques de la vue affichée, articles gardés.
const menu = document.getElementById("menu");
const listeLangues = document.getElementById("menu-langues");
const listeRubriques = document.getElementById("menu-rubriques");
const titreRubriques = document.getElementById("menu-rubriques-titre");
const listeGardes = document.getElementById("menu-gardes");
const titreGardes = document.getElementById("menu-gardes-titre");

function bouton(texte, actif, action, lu = false) {
  const li = document.createElement("li");
  const b = Object.assign(document.createElement("button"), { type: "button", textContent: texte });
  if (actif) b.setAttribute("aria-current", "true");
  if (lu) b.classList.add("lu");
  b.addEventListener("click", action);
  li.append(b);
  return li;
}

// Rubrique en cours de lecture : la dernière dont le haut est passé sous le premier quart de l'écran.
function rubriqueCourante(liste) {
  let courante = liste[0]?.id;
  for (const { id } of liste) {
    const n = document.getElementById(id);
    if (n && n.getBoundingClientRect().top < innerHeight / 4) courante = id;
  }
  return courante;
}

function remplirMenu() {
  listeLangues.replaceChildren(...PROFILS.map((p) => bouton(nomLangue(p), p === profilActuel(), () => {
    if (p === profilActuel()) return menu.close();
    changerProfil(p);
    traduirePage();
    affiche = { jour: null, semaine: null };
    contenus = { jour: null, semaine: null };
    message(journal, t("chargement"));
    menu.close();
    scrollTo(0, 0);
    afficher();
  })));
  const liste = vue === "gardes" ? [] : ancres(vue, contenus.jour?.donnees, contenus.semaine?.donnees);
  const courante = rubriqueCourante(liste);
  const lues = vue === "jour" && lecture ? lecture.ids : new Set();
  titreRubriques.hidden = !liste.length;
  titreRubriques.textContent = t("rubriques");
  listeRubriques.replaceChildren(...liste.map(({ id, nom }) => bouton(nom, id === courante, () => {
    menu.close();
    document.getElementById(id)?.scrollIntoView({ block: "start" });
  }, lues.has(id))));
  const gardes = suivi.gardes(profilActuel());
  titreGardes.hidden = !gardes.length;
  listeGardes.replaceChildren(...gardes.map((g, i) => bouton(g.article.titre, false, () => {
    menu.close();
    changerVue("gardes");
    document.getElementById(`g${i + 1}`)?.scrollIntoView({ block: "start" });
  })));
}

document.getElementById("ouvrir-menu").addEventListener("click", () => {
  remplirMenu();
  menu.showModal();
});
menu.querySelector(".fermer-menu").addEventListener("click", () => menu.close());
// Toucher le fond (hors du panneau) ferme le menu.
menu.addEventListener("click", (e) => { if (e.target === menu) menu.close(); });

// Tirer vers le bas en haut de page pour actualiser (téléphone).
const tirer = document.getElementById("tirer");
const tirerTexte = tirer.querySelector("p");
const SEUIL = 72;
let depart = null;
let distance = 0;
let actualisation = false;

function poserTirage(d) {
  document.documentElement.style.setProperty("--decalage", `${d}px`);
  tirer.classList.toggle("visible", d > 24 || actualisation);
}

addEventListener("touchstart", (e) => {
  if (actualisation || scrollY > 0 || menu.open || e.touches.length !== 1) return;
  depart = e.touches[0].clientY;
  distance = 0;
}, { passive: true });

addEventListener("touchmove", (e) => {
  if (depart == null) return;
  const brut = e.touches[0].clientY - depart;
  if (brut <= 0 || scrollY > 0) { distance = 0; poserTirage(0); return; }
  distance = Math.min(120, brut * 0.5); // résistance
  document.documentElement.classList.add("glisse");
  tirerTexte.textContent = distance >= SEUIL ? t("relacher") : t("tirer");
  poserTirage(distance);
}, { passive: true });

addEventListener("touchend", async () => {
  if (depart == null) return;
  depart = null;
  document.documentElement.classList.remove("glisse");
  if (distance < SEUIL) { poserTirage(0); return; }
  actualisation = true;
  tirerTexte.textContent = t("actualisation");
  poserTirage(SEUIL);
  const debut = Date.now();
  const change = await afficher({ silencieux: true });
  if (!change) tirerTexte.textContent = t("aJour");
  // Laisser le globe tourner au moins un instant, pour que l'actualisation se voie.
  await new Promise((r) => setTimeout(r, Math.max(0, 700 - (Date.now() - debut))));
  actualisation = false;
  poserTirage(0);
});

// Bouton du menu : caché quand on descend dans la lecture, visible en haut de page ou dès qu'on remonte.
const boutonMenu = document.getElementById("ouvrir-menu");
let dernierY = scrollY;
addEventListener("scroll", () => {
  const y = scrollY;
  if (Math.abs(y - dernierY) < 6) return;
  boutonMenu.classList.toggle("cache", y > 80 && y > dernierY);
  dernierY = y;
}, { passive: true });

// Retour au premier plan (app restée ouverte depuis la veille) : chercher l'édition du jour.
document.addEventListener("visibilitychange", () => {
  if (document.visibilityState === "visible" && Date.now() - derniereVerif > RELECTURE_MIN_MS) {
    afficher({ silencieux: true });
  }
});

activerZoom(journal, document.getElementById("zoom"));

// Mise à jour de l'app elle-même (nouveau service worker).
if ("serviceWorker" in navigator) {
  navigator.serviceWorker.register("./sw.js").then((reg) => {
    const proposer = (sw) => {
      document.getElementById("maj").hidden = false;
      document.getElementById("maj-bouton").onclick = () => sw.postMessage("activer");
    };
    if (reg.waiting && navigator.serviceWorker.controller) proposer(reg.waiting);
    reg.addEventListener("updatefound", () => {
      const nouveau = reg.installing;
      nouveau?.addEventListener("statechange", () => {
        if (nouveau.state === "installed" && navigator.serviceWorker.controller) proposer(nouveau);
      });
    });
  });
  let recharge = false;
  navigator.serviceWorker.addEventListener("controllerchange", () => {
    if (!recharge) { recharge = true; location.reload(); }
  });
}

// Demande à garder les données (accordé plus facilement à une app installée).
if (installee) navigator.storage?.persist?.();

traduirePage();
retirerParametreLangue();
globe(document.getElementById("logo"), matchMedia("(min-width: 960px)").matches ? 42 : 34);
globe(tirer.querySelector("canvas"), 28);
afficher();
