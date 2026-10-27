import { charger, enregistrer } from "./edition.js";
import { rendre, message, activerZoom, ancres } from "./rendu.js";
import { t, PROFILS, profilActuel, changerProfil, nomLangue } from "./textes.js";
import { globe, pendantChargement } from "./globe.js";

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

function dessiner() {
  for (const b of boutonsVue) b.setAttribute("aria-pressed", String(b.dataset.vue === vue));
  const { jour, semaine } = contenus;
  ligneDate.textContent = vue === "jour"
    ? (jour?.donnees.date_texte ?? "")
    : (semaine?.donnees.date_texte_semaine ?? semaine?.donnees.date_texte ?? "");
  rendre(journal, vue, jour?.donnees, semaine?.donnees);
  document.title = vue === "jour" ? "Actualités" : t("titreSemaine");
}

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

// Menu latéral : édition, langue (= profil), rubriques de la vue affichée.
const menu = document.getElementById("menu");
const listeLangues = document.getElementById("menu-langues");
const listeRubriques = document.getElementById("menu-rubriques");

function bouton(texte, actif, action) {
  const li = document.createElement("li");
  const b = Object.assign(document.createElement("button"), { type: "button", textContent: texte });
  if (actif) b.setAttribute("aria-current", "true");
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
  const liste = ancres(vue, contenus.jour?.donnees, contenus.semaine?.donnees);
  const courante = rubriqueCourante(liste);
  listeRubriques.replaceChildren(...liste.map(({ id, nom }) => bouton(nom, id === courante, () => {
    menu.close();
    document.getElementById(id)?.scrollIntoView({ block: "start" });
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
globe(document.getElementById("logo"), matchMedia("(min-width: 960px)").matches ? 42 : 34);
globe(tirer.querySelector("canvas"), 28);
afficher();
