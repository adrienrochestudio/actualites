// Textes de l'interface, par profil. Le contenu des éditions arrive déjà dans la bonne langue.
// fr : profil Adrien. pt : profil Ana (portugais du Brésil).

export const PROFILS = ["fr", "pt"];

const TEXTES = {
  fr: {
    langueNom: "Français",
    htmlLang: "fr",
    quotidien: "Quotidien",
    hebdomadaire: "Hebdomadaire",
    editions: "Éditions",
    menu: "Menu",
    fermer: "Fermer",
    edition: "Édition",
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
    piedJour: (jour) => `Rédigé par Claude à partir de sources publiques consultées le ${jour}.`,
    piedSemaine: "Dossiers rédigés par Claude à partir de sources publiques, publiés chaque dimanche.",
    videJour: "Pas encore d'édition du jour sur cet appareil.",
    videSemaine: "Pas encore d'édition de la semaine sur cet appareil.",
    rien: "Aucune édition enregistrée sur cet appareil. Ouvrir l'app une fois avec une connexion.",
    enregistrement: "Enregistrement pour la lecture hors ligne.",
    horsLigne: "Hors ligne : dernières éditions enregistrées sur cet appareil.",
    enregistrees: "Éditions enregistrées pour la lecture hors ligne.",
    manquees: (n) => `Éditions enregistrées hors ligne, ${n} image(s) non enregistrée(s).`,
    installer: "Installer : iPhone, Partager puis Sur l'écran d'accueil.",
    titreSemaine: "Actualités, la semaine",
  },
  pt: {
    langueNom: "Português",
    htmlLang: "pt-BR",
    quotidien: "Diário",
    hebdomadaire: "Semanal",
    editions: "Edições",
    menu: "Menu",
    fermer: "Fechar",
    edition: "Edição",
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
    piedJour: (jour) => `Escrito por Claude a partir de fontes públicas consultadas em ${jour}.`,
    piedSemaine: "Dossiês escritos por Claude a partir de fontes públicas, publicados todo domingo.",
    videJour: "Ainda não há edição do dia neste aparelho.",
    videSemaine: "Ainda não há edição da semana neste aparelho.",
    rien: "Nenhuma edição salva neste aparelho. Abra o app uma vez com conexão.",
    enregistrement: "Salvando para leitura sem conexão.",
    horsLigne: "Sem conexão: últimas edições salvas neste aparelho.",
    enregistrees: "Edições salvas para leitura sem conexão.",
    manquees: (n) => `Edições salvas sem conexão, ${n} imagem(ns) não salva(s).`,
    installer: "Instalar: iPhone, Compartilhar e depois Adicionar à Tela de Início.",
    titreSemaine: "Actualités, a semana",
  },
};

let profil = "fr";
try {
  const p = localStorage.getItem("profil");
  if (PROFILS.includes(p)) profil = p;
} catch {}

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
