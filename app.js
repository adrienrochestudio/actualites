import { chargerEdition, enregistrer } from "./edition.js";
import { rendre, message, ligneEtat } from "./rendu.js";

const journal = document.getElementById("journal");
const RELECTURE_MIN_MS = 10 * 60 * 1000;

let dateAffichee = null;
let derniereVerif = 0;

const installee = matchMedia("(display-mode: standalone)").matches || navigator.standalone === true;

async function afficher({ silencieux = false } = {}) {
  derniereVerif = Date.now();
  const res = await chargerEdition();
  if (!res) {
    if (!dateAffichee) message(journal, "Aucune édition enregistrée sur cet appareil. Ouvrir l'app une fois avec une connexion.");
    return;
  }
  const { edition, source } = res;
  if (silencieux && edition.date === dateAffichee) return;

  const pied = rendre(journal, edition);
  if (dateAffichee && dateAffichee !== edition.date) scrollTo(0, 0);
  dateAffichee = edition.date;

  if (source === "cache") {
    ligneEtat(pied, "Hors ligne : dernière édition enregistrée sur cet appareil.");
  } else {
    ligneEtat(pied, "Enregistrement pour la lecture hors ligne.");
    const manquees = await enregistrer(edition);
    ligneEtat(pied, manquees
      ? `Édition enregistrée hors ligne, ${manquees} image(s) non enregistrée(s).`
      : "Édition enregistrée pour la lecture hors ligne.");
  }
  if (!installee) {
    pied.append(Object.assign(document.createElement("p"), {
      className: "note",
      textContent: "Installer : iPhone, Partager puis Sur l'écran d'accueil. Mac, dans Safari, Fichier puis Ajouter au Dock.",
    }));
  }
}

// Retour au premier plan (app restée ouverte depuis la veille) : chercher l'édition du jour.
document.addEventListener("visibilitychange", () => {
  if (document.visibilityState === "visible" && Date.now() - derniereVerif > RELECTURE_MIN_MS) {
    afficher({ silencieux: true });
  }
});

// Mise à jour de l'app elle-même (nouveau service worker).
if ("serviceWorker" in navigator) {
  navigator.serviceWorker.register("./sw.js").then((reg) => {
    const proposer = (sw) => {
      const bandeau = document.getElementById("maj");
      bandeau.hidden = false;
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
