import Foundation

/// Profil de lecture = langue de l'interface et des éditions : fr (Adrien), pt (Ana, portugais du Brésil).
/// Publications : {profil}/edition/edition.json et {profil}/hebdo/hebdo.json.
enum Profil: String, CaseIterable, Identifiable {
    case fr, pt
    var id: String { rawValue }
    var textes: Textes { self == .pt ? .pt : .fr }
}

/// Textes de l'interface, une table par profil (même contenu que textes.js de l'app web).
/// Le titre "Actualités" est le nom du journal : il ne se traduit pas.
struct Textes {
    let nomLangue: String
    let quotidien: String
    let hebdomadaire: String
    let edition: String
    let langue: String
    let rubriques: String
    let actu: String
    let enBref: String
    let aRetenir: String
    let source: String
    let sources: String
    let versionInteractive: String
    let carte: String
    let dossiersSemaine: String
    let lireDossier: String
    let replier: String
    let ouvrirLeDossier: String
    let replierLeDossier: String
    let actualiser: String
    let chargement: String
    /// "{date}" est remplacé par la date de l'édition.
    let piedJourModele: String
    let piedSemaine: String
    let videJour: String
    let videSemaine: String
    let rien: String
    let horsLigne: String
    let enregistrees: String

    func piedJour(_ date: String) -> String { piedJourModele.replacingOccurrences(of: "{date}", with: date) }

    static let fr = Textes(
        nomLangue: "Français",
        quotidien: "Quotidien",
        hebdomadaire: "Hebdomadaire",
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
        ouvrirLeDossier: "Ouvrir le dossier",
        replierLeDossier: "Replier le dossier",
        actualiser: "Actualiser",
        chargement: "Chargement de l'édition.",
        piedJourModele: "Rédigé par Claude à partir de sources publiques consultées le {date}.",
        piedSemaine: "Dossiers rédigés par Claude à partir de sources publiques, publiés chaque dimanche.",
        videJour: "Pas encore d'édition du jour sur cet appareil.",
        videSemaine: "Pas encore d'édition de la semaine sur cet appareil.",
        rien: "Aucune édition enregistrée sur cet appareil. Ouvrir l'app une fois avec une connexion.",
        horsLigne: "Hors ligne : dernières éditions enregistrées.",
        enregistrees: "Éditions enregistrées pour la lecture hors ligne."
    )

    static let pt = Textes(
        nomLangue: "Português",
        quotidien: "Diário",
        hebdomadaire: "Semanal",
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
        ouvrirLeDossier: "Abrir o dossiê",
        replierLeDossier: "Recolher o dossiê",
        actualiser: "Atualizar",
        chargement: "Carregando a edição.",
        piedJourModele: "Escrito por Claude a partir de fontes públicas consultadas em {date}.",
        piedSemaine: "Dossiês escritos por Claude a partir de fontes públicas, publicados todo domingo.",
        videJour: "Ainda não há edição do dia neste aparelho.",
        videSemaine: "Ainda não há edição da semana neste aparelho.",
        rien: "Nenhuma edição salva neste aparelho. Abra o app uma vez com conexão.",
        horsLigne: "Sem conexão: últimas edições salvas.",
        enregistrees: "Edições salvas para leitura sem conexão."
    )
}
