import { charger, enregistrer } from "./edition.js";
import { rendre, message, ligneEtat, activerZoom } from "./rendu.js";

const journal = document.getElementById("journal");
const RELECTURE_MIN_MS = 10 * 60 * 1000;

let affiche = { jour: null, semaine: null };
let contenus = { jour: null, semaine: null };
let derniereVerif = 0;
let vue = "jour";
try { if (localStorage.getItem("vue") === "semaine") vue = "semaine"; } catch {}

const installee = matchMedia("(display-mode: standalone)").matches || navigator.standalone === true;
const ligneDate = document.getElementById("date");
const boutons = [...document.querySelectorAll(".onglets button")];
let etat = "";

function dessiner() {
  for (const b of boutons) b.setAttribute("aria-pressed", String(b.dataset.vue === vue));
  const { jour, semaine } = contenus;
  ligneDate.textContent = vue === "jour"
    ? (jour?.donnees.date_texte ?? "")
    : (semaine?.donnees.date_texte_semaine ?? semaine?.donnees.date_texte ?? "");
  const pied = rendre(journal, vue, jour?.donnees, semaine?.donnees);
  if (etat) ligneEtat(pied, etat);
  if (!installee) {
    pied.append(Object.assign(document.createElement("p"), {
      className: "note",
      textContent: "Installer : iPhone, Partager puis Sur l'écran d'accueil.",
    }));
  }
  document.title = vue === "jour" ? "Actualités" : "Actualités, la semaine";
}

for (const b of boutons) {
  b.addEventListener("click", () => {
    if (b.dataset.vue === vue) return;
    vue = b.dataset.vue;
    try { localStorage.setItem("vue", vue); } catch {}
    dessiner();
    scrollTo(0, 0);
  });
}

async function afficher({ silencieux = false } = {}) {
  derniereVerif = Date.now();
  const [jour, semaine] = await Promise.all([charger("jour"), charger("semaine")]);
  if (!jour && !semaine) {
    if (!affiche.jour && !affiche.semaine) message(journal, "Aucune édition enregistrée sur cet appareil. Ouvrir l'app une fois avec une connexion.");
    return;
  }
  const dates = { jour: jour?.donnees.date ?? null, semaine: semaine?.donnees.date ?? null };
  if (silencieux && dates.jour === affiche.jour && dates.semaine === affiche.semaine) return;

  // Garder les dossiers ouverts quand on réaffiche la même semaine.
  const ouverts = dates.semaine === affiche.semaine
    ? [...journal.querySelectorAll("details[open]")].map((d) => d.id) : [];
  const nouveauJour = affiche.jour && affiche.jour !== dates.jour;
  contenus = { jour, semaine };
  affiche = dates;

  const enLigne = [jour, semaine].some((c) => c?.source === "reseau");
  etat = enLigne ? "Enregistrement pour la lecture hors ligne." : "Hors ligne : dernières éditions enregistrées sur cet appareil.";
  dessiner();
  for (const id of ouverts) document.getElementById(id)?.setAttribute("open", "");
  if (nouveauJour && vue === "jour") scrollTo(0, 0);

  if (enLigne) {
    const manquees = (await Promise.all([
      jour?.source === "reseau" ? enregistrer("jour", jour.donnees) : 0,
      semaine?.source === "reseau" ? enregistrer("semaine", semaine.donnees) : 0,
    ])).reduce((a, b) => a + b, 0);
    etat = manquees
      ? `Éditions enregistrées hors ligne, ${manquees} image(s) non enregistrée(s).`
      : "Éditions enregistrées pour la lecture hors ligne.";
    const pied = journal.querySelector(".pied");
    if (pied) ligneEtat(pied, etat);
  }
}

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

afficher();
