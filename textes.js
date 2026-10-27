// Textes de l'interface, par profil. Le contenu des éditions arrive déjà dans la bonne langue.
// fr : profil Adrien. pt : profil Ana (portugais du Brésil).

export const PROFILS = ["fr", "pt"];

const TEXTES = {
  fr: {
    langueNom: "Français",
    htmlLang: "fr",
    quotidien: "Quotidien",
    hebdomadaire: "Hebdomadaire",
    menu: "Menu",
    fermer: "Fermer",
    langue: "Langue",
    rubriques: "Rubriques",
    actu: "Actu",
    enBref: "En bref",
    aRetenir: "À retenir",
    source: "Source : ",
    sources: "Sources : ",
    versionInteractive: "Version interactive",
    carte: "Carte : ",
    dossiersSemaine: "Dossiers de la semaine",
    lireDossier: "Lire le dossier",
    replier: "Replier",
    chargement: "Chargement de l'édition.",
    nouvelleVersion: "Nouvelle version de l'app.",
    recharger: "Recharger",
    tirer: "Tirer pour actualiser",
    relacher: "Relâcher pour actualiser",
    actualisation: "Actualisation",
    aJour: "Édition à jour",
    videJour: "Pas encore d'édition du jour sur cet appareil.",
    videSemaine: "Pas encore d'édition de la semaine sur cet appareil.",
    rien: "Aucune édition enregistrée sur cet appareil. Ouvrir l'app une fois avec une connexion.",
    titreSemaine: "Actualités, la semaine",
    garder: "Garder",
    garde: "Gardé",
    retirer: "Retirer",
    gardes: "Gardés",
    articlesGardes: "Articles gardés",
    aucunGarde: "Aucun article gardé.",
    quiz: "Quiz",
    exact: "Exact.",
    non: "Non.",
    sur: (n, total) => `${n} sur ${total}`,
    historiqueQuiz: "Scores des 30 derniers jours",
    aucunScore: "Aucun quiz terminé ces 30 derniers jours.",
  },
  pt: {
    langueNom: "Português",
    htmlLang: "pt-BR",
    quotidien: "Diário",
    hebdomadaire: "Semanal",
    menu: "Menu",
    fermer: "Fechar",
    langue: "Idioma",
    rubriques: "Seções",
    actu: "Destaque",
    enBref: "Em resumo",
    aRetenir: "Para guardar",
    source: "Fonte: ",
    sources: "Fontes: ",
    versionInteractive: "Versão interativa",
    carte: "Mapa: ",
    dossiersSemaine: "Dossiês da semana",
    lireDossier: "Ler o dossiê",
    replier: "Recolher",
    chargement: "Carregando a edição.",
    nouvelleVersion: "Nova versão do app.",
    recharger: "Recarregar",
    tirer: "Puxe para atualizar",
    relacher: "Solte para atualizar",
    actualisation: "Atualizando",
    aJour: "Edição atualizada",
    videJour: "Ainda não há edição do dia neste aparelho.",
    videSemaine: "Ainda não há edição da semana neste aparelho.",
    rien: "Nenhuma edição salva neste aparelho. Abra o app uma vez com conexão.",
    titreSemaine: "Actualités, a semana",
    garder: "Guardar",
    garde: "Guardado",
    retirer: "Remover",
    gardes: "Guardados",
    articlesGardes: "Artigos guardados",
    aucunGarde: "Nenhum artigo guardado.",
    quiz: "Quiz",
    exact: "Certo.",
    non: "Não.",
    sur: (n, total) => `${n} de ${total}`,
    historiqueQuiz: "Pontuação dos últimos 30 dias",
    aucunScore: "Nenhum quiz terminado nos últimos 30 dias.",
  },
};

let profil = "fr";
let retenu = null;
try {
  retenu = localStorage.getItem("profil");
  if (PROFILS.includes(retenu)) profil = retenu;
} catch {}

// Lien d'installation par profil : ?langue=pt ouvre l'app en portugais au premier lancement.
// Le manifeste du profil fait démarrer l'app installée sur la même langue (stockage séparé de Safari sur iPhone).
// Ensuite, la langue choisie dans le menu prime.
const demande = new URLSearchParams(location.search).get("langue");
if (PROFILS.includes(demande) && !PROFILS.includes(retenu)) {
  profil = demande;
  try { localStorage.setItem("profil", demande); } catch {}
}
if (profil === "pt") document.querySelector('link[rel="manifest"]')?.setAttribute("href", "./manifest-pt.webmanifest");

export function retirerParametreLangue() {
  if (!demande) return;
  // L'adresse garde ?langue tant que l'app n'est pas installée (Partager, Sur l'écran d'accueil).
  if (matchMedia("(display-mode: standalone)").matches || navigator.standalone === true) {
    history.replaceState(null, "", location.pathname);
  }
}

export function profilActuel() {
  return profil;
}

export function changerProfil(p) {
  if (!PROFILS.includes(p)) return;
  profil = p;
  try { localStorage.setItem("profil", p); } catch {}
}

export function t(cle) {
  return TEXTES[profil][cle] ?? TEXTES.fr[cle];
}

export function nomLangue(p) {
  return TEXTES[p].langueNom;
}
