import Foundation
import CryptoKit
import SwiftUI

/// Récupère les éditions publiées sur GitHub Pages et les garde sur l'appareil.
/// En ligne : {profil}/edition/edition.json et {profil}/hebdo/hebdo.json.
/// Sur l'appareil : Application Support/Actualites/{profil}/{edition,hebdo}/ (fichier JSON + img/).
/// Un seul exemplaire de chaque, pour le seul profil choisi.
/// Articles gardés : Application Support/Actualites/gardes/{profil}/ (gardes.json + img/), conservés d'une édition à l'autre.
/// Rubriques lues et réponses au quiz : UserDefaults, par profil et date d'édition (quiz gardés 30 jours).
@MainActor
final class Depot: ObservableObject {
    enum Etat: Equatable {
        case vide, chargement, aJour, horsLigne, rien
    }

    @Published private(set) var profil: Profil
    @Published private(set) var edition: Edition? {
        didSet { chargerEtatsJour() }
    }
    @Published private(set) var semaine: Semaine?
    @Published private(set) var etat: Etat = .vide
    /// Vrai pendant une vérification réseau (le globe du logo accélère).
    @Published private(set) var enChargement = false
    /// Articles gardés du profil affiché, le plus récent en premier.
    @Published private(set) var gardes: [ArticleGarde] = []
    /// Ancres des rubriques lues de l'édition du jour ("une", "r1"..., "breves", "quiz").
    @Published private(set) var lus: Set<String> = []
    /// Réponses au quiz de l'édition du jour : index du choix fait, -1 si pas répondu.
    @Published private(set) var reponsesQuiz: [Int] = []
    /// Quiz terminés du profil affiché sur les 30 derniers jours, le plus récent en premier.
    @Published private(set) var historiqueQuiz: [ScoreQuiz] = []

    nonisolated static let base = URL(string: "https://adrienrochestudio.github.io/actualites/")!
    private static let cleProfil = "profil"
    private let agent = "ActualitesApp/1.0 (+https://github.com/adrienrochestudio/actualites)"
    private var derniereVerif = Date.distantPast
    private var chargements = 0

    private let racine: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Actualites", isDirectory: true)

    private lazy var session: URLSession = {
        let c = URLSessionConfiguration.default
        c.requestCachePolicy = .reloadIgnoringLocalCacheData
        c.timeoutIntervalForRequest = 20
        c.httpAdditionalHeaders = ["User-Agent": agent]
        return URLSession(configuration: c)
    }()

    init() {
        let p = Profil(rawValue: UserDefaults.standard.string(forKey: Self.cleProfil) ?? "") ?? .fr
        profil = p
        // Ancienne organisation (un seul profil, sans sous-dossier) : supprimée au premier lancement.
        let fm = FileManager.default
        for ancien in ["edition", "hebdo", "edition-tmp", "hebdo-tmp"] {
            let u = racine.appendingPathComponent(ancien, isDirectory: true)
            if fm.fileExists(atPath: u.path) { try? fm.removeItem(at: u) }
        }
        edition = lire(Edition.self, p, "edition", "edition.json")
        semaine = lire(Semaine.self, p, "hebdo", "hebdo.json")
        gardes = lireGardes(p)
        if edition != nil || semaine != nil { etat = .horsLigne }
        chargerEtatsJour() // les observateurs de propriété ne sont pas appelés dans init
    }

    /// Change de langue : affiche ce qui est déjà enregistré pour ce profil, puis télécharge.
    /// Les dossiers de l'autre profil sont supprimés une fois le nouveau téléchargé (voir actualiser).
    func changerProfil(_ p: Profil) {
        guard p != profil else { return }
        UserDefaults.standard.set(p.rawValue, forKey: Self.cleProfil)
        withAnimation(.easeInOut(duration: 0.3)) {
            profil = p
            edition = lire(Edition.self, p, "edition", "edition.json")
            semaine = lire(Semaine.self, p, "hebdo", "hebdo.json")
            gardes = lireGardes(p)
        }
        etat = (edition == nil && semaine == nil) ? .chargement : .horsLigne
        Task { await actualiser(force: true) }
    }

    /// Copie locale d'une image du profil affiché (nil si absente).
    func imageLocale(_ chemin: String) -> URL? {
        let nom = Self.nomLocal(chemin)
        for dossier in ["edition", "hebdo"] {
            let u = dossierProfil(profil).appendingPathComponent(dossier).appendingPathComponent("img").appendingPathComponent(nom)
            if FileManager.default.fileExists(atPath: u.path) { return u }
        }
        let g = dossierGardes(profil).appendingPathComponent("img").appendingPathComponent(nom)
        return FileManager.default.fileExists(atPath: g.path) ? g : nil
    }

    // MARK: - Articles gardés

    func estGarde(_ a: Article, date: String) -> Bool {
        let id = ArticleGarde.cle(profil.rawValue, date, a)
        return gardes.contains { $0.id == id }
    }

    /// Enregistre l'article complet et copie ses images, pour qu'il reste lisible après le remplacement de l'édition.
    func garder(_ a: Article, _ p: Provenance) {
        guard !estGarde(a, date: p.date) else { return }
        let fm = FileManager.default
        let img = dossierGardes(profil).appendingPathComponent("img", isDirectory: true)
        try? fm.createDirectory(at: img, withIntermediateDirectories: true)
        for chemin in a.images {
            let dest = img.appendingPathComponent(Self.nomLocal(chemin))
            if fm.fileExists(atPath: dest.path) { continue }
            if let src = imageLocale(chemin) { try? fm.copyItem(at: src, to: dest) }
        }
        gardes.insert(ArticleGarde(article: a, date: p.date, date_texte: p.dateTexte, profil: profil.rawValue), at: 0)
        enregistrerGardes()
    }

    func retirer(_ a: Article, date: String) {
        retirer(id: ArticleGarde.cle(profil.rawValue, date, a))
    }

    /// Retire un article gardé et les images qu'aucun autre article gardé n'utilise.
    func retirer(id: String) {
        guard let i = gardes.firstIndex(where: { $0.id == id }) else { return }
        let ancien = gardes.remove(at: i)
        let encore = Set(gardes.flatMap { $0.article.images })
        let img = dossierGardes(profil).appendingPathComponent("img", isDirectory: true)
        for chemin in ancien.article.images where !encore.contains(chemin) {
            try? FileManager.default.removeItem(at: img.appendingPathComponent(Self.nomLocal(chemin)))
        }
        enregistrerGardes()
    }

    private func dossierGardes(_ p: Profil) -> URL {
        racine.appendingPathComponent("gardes", isDirectory: true).appendingPathComponent(p.rawValue, isDirectory: true)
    }

    private func lireGardes(_ p: Profil) -> [ArticleGarde] {
        let u = dossierGardes(p).appendingPathComponent("gardes.json")
        guard let data = try? Data(contentsOf: u) else { return [] }
        return (try? JSONDecoder().decode([ArticleGarde].self, from: data)) ?? []
    }

    private func enregistrerGardes() {
        let dossier = dossierGardes(profil)
        try? FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(gardes) else { return }
        try? data.write(to: dossier.appendingPathComponent("gardes.json"), options: .atomic)
    }

    // MARK: - Rubriques lues et quiz de l'édition du jour

    private var cleJour: String? {
        edition.map { "\(profil.rawValue).\($0.date)" }
    }

    func marquerLu(_ id: String) {
        guard let cle = cleJour, !lus.contains(id) else { return }
        lus.insert(id)
        UserDefaults.standard.set(Array(lus).sorted(), forKey: "lus.\(cle)")
    }

    func repondre(_ question: Int, _ choix: Int) {
        guard let ed = edition, let cle = cleJour, reponsesQuiz.indices.contains(question), reponsesQuiz[question] < 0 else { return }
        reponsesQuiz[question] = choix
        enregistrerQuiz(ed, cle: cle)
        historiqueQuiz = lireHistoriqueQuiz()
    }

    /// Enregistre les réponses de l'édition affichée avec sa date en toutes lettres et son score.
    private func enregistrerQuiz(_ ed: Edition, cle: String) {
        let questions = ed.quiz ?? []
        let justes = questions.indices.filter { reponsesQuiz.indices.contains($0) && reponsesQuiz[$0] == questions[$0].reponse }.count
        let s = ScoreQuiz(date: ed.date, reponses: reponsesQuiz, date_texte: ed.date_texte, justes: justes, total: questions.count)
        UserDefaults.standard.set(s.dictionnaire, forKey: "quiz.\(cle)")
    }

    /// Quiz terminés du profil affiché sur les 30 derniers jours, du plus récent au plus ancien.
    private func lireHistoriqueQuiz() -> [ScoreQuiz] {
        let prefixe = "quiz.\(profil.rawValue)."
        let limite = Self.limiteQuiz
        var liste: [ScoreQuiz] = []
        for (k, v) in UserDefaults.standard.dictionaryRepresentation() where k.hasPrefix(prefixe) {
            let date = String(k.dropFirst(prefixe.count))
            guard date >= limite, let d = v as? [String: Any], let s = ScoreQuiz(date: date, dictionnaire: d), s.termine else { continue }
            liste.append(s)
        }
        return liste.sorted { $0.date > $1.date }
    }

    /// Date ISO d'il y a 30 jours : les quiz plus anciens sont supprimés.
    private static var limiteQuiz: String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date().addingTimeInterval(-30 * 86_400))
    }

    /// Relit l'état de l'édition affichée. Rubriques lues : celles des autres dates sont supprimées.
    /// Quiz : gardés 30 jours, pour l'historique des scores.
    private func chargerEtatsJour() {
        guard let ed = edition, let cle = cleJour else {
            lus = []
            reponsesQuiz = []
            historiqueQuiz = lireHistoriqueQuiz()
            return
        }
        let d = UserDefaults.standard
        lus = Set(d.stringArray(forKey: "lus.\(cle)") ?? [])
        let n = ed.quiz?.count ?? 0
        // Format actuel (dictionnaire), sinon ancien format (tableau d'Int) repris et réenregistré.
        var r: [Int] = []
        var ancien = false
        if let dict = d.dictionary(forKey: "quiz.\(cle)"), let s = ScoreQuiz(date: ed.date, dictionnaire: dict) {
            r = s.reponses
        } else if let a = d.array(forKey: "quiz.\(cle)") as? [Int] {
            r = a
            ancien = true
        }
        if r.count < n { r += Array(repeating: -1, count: n - r.count) }
        reponsesQuiz = Array(r.prefix(n))
        if ancien { enregistrerQuiz(ed, cle: cle) }
        // Clés "lus.{profil}.{date}" : autres dates du profil affiché, et dates plus anciennes de l'autre profil.
        // Clés "quiz.{profil}.{date}" : dates de plus de 30 jours, tous profils.
        let limite = Self.limiteQuiz
        for k in d.dictionaryRepresentation().keys where k.hasPrefix("lus.") || k.hasPrefix("quiz.") {
            let parties = k.split(separator: ".", maxSplits: 2).map(String.init)
            guard parties.count == 3, Profil(rawValue: parties[1]) != nil else { continue }
            let (p, date) = (parties[1], parties[2])
            if k.hasPrefix("quiz.") {
                if date < limite { d.removeObject(forKey: k) }
            } else if (p == profil.rawValue && date != ed.date) || (p != profil.rawValue && date < ed.date) {
                d.removeObject(forKey: k)
            }
        }
        historiqueQuiz = lireHistoriqueQuiz()
    }

    /// À l'ouverture, au retour au premier plan, avec le bouton Actualiser (⌘R).
    /// `force` ignore le délai minimal de 10 min entre deux vérifications.
    func actualiser(force: Bool = false) async {
        if !force, Date().timeIntervalSince(derniereVerif) < 600 { return }
        derniereVerif = Date()
        let p = profil
        if edition == nil && semaine == nil { etat = .chargement }
        chargements += 1
        enChargement = true
        defer {
            chargements -= 1
            enChargement = chargements > 0
        }
        async let j: Edition? = recuperer(Edition.self, p, "edition", "edition.json")
        async let s: Semaine? = recuperer(Semaine.self, p, "hebdo", "hebdo.json")
        let (nj, ns) = await (j, s)
        guard p == profil else { return } // profil changé pendant le chargement : un autre appel s'en charge

        // Nouvelle édition : fondu. Même version : rien ne bouge.
        let jourChange = nj.map { $0.version != edition?.version } ?? false
        let semaineChange = ns.map { $0.version != semaine?.version } ?? false
        if jourChange || semaineChange {
            withAnimation(.easeInOut(duration: 0.35)) {
                if jourChange { edition = nj }
                if semaineChange { semaine = ns }
            }
        }
        if nj != nil || ns != nil {
            etat = .aJour
            supprimerAutresProfils(que: p)
        } else {
            etat = (edition == nil && semaine == nil) ? .rien : .horsLigne
        }
    }

    private func dossierProfil(_ p: Profil) -> URL {
        racine.appendingPathComponent(p.rawValue, isDirectory: true)
    }

    /// On ne garde hors ligne que les éditions du profil choisi.
    /// Seuls les dossiers d'édition de l'autre profil sont supprimés : gardes/ reste intact.
    private func supprimerAutresProfils(que p: Profil) {
        let fm = FileManager.default
        for autre in Profil.allCases where autre != p {
            let u = dossierProfil(autre)
            guard fm.fileExists(atPath: u.path) else { continue }
            for dossier in ["edition", "hebdo", "edition-tmp", "hebdo-tmp"] {
                let d = u.appendingPathComponent(dossier, isDirectory: true)
                if fm.fileExists(atPath: d.path) { try? fm.removeItem(at: d) }
            }
            if let reste = try? fm.contentsOfDirectory(atPath: u.path), reste.allSatisfy({ $0.hasPrefix(".") }) {
                try? fm.removeItem(at: u)
            }
        }
    }

    private func lire<T: Decodable>(_ type: T.Type, _ p: Profil, _ dossier: String, _ fichier: String) -> T? {
        let u = dossierProfil(p).appendingPathComponent(dossier).appendingPathComponent(fichier)
        guard let data = try? Data(contentsOf: u) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    /// Télécharge une publication ; ne réécrit le disque que si elle a changé ou s'il manque des images.
    private func recuperer<T: Publication>(_ type: T.Type, _ p: Profil, _ dossier: String, _ fichier: String) async -> T? {
        do {
            let url = Self.base.appendingPathComponent(p.rawValue).appendingPathComponent(dossier).appendingPathComponent(fichier)
            let (data, rep) = try await session.data(from: url)
            guard (rep as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            let nouvelle = try JSONDecoder().decode(T.self, from: data)
            let enregistree = lire(T.self, p, dossier, fichier)
            if nouvelle.version != enregistree?.version || !imagesPresentes(nouvelle, p, dossier) {
                try await enregistrer(nouvelle, json: data, profil: p, dossier: dossier, fichier: fichier)
            }
            return nouvelle
        } catch {
            return nil
        }
    }

    private func imagesPresentes<T: Publication>(_ pub: T, _ p: Profil, _ dossier: String) -> Bool {
        let img = dossierProfil(p).appendingPathComponent(dossier).appendingPathComponent("img")
        return pub.images.allSatisfy {
            FileManager.default.fileExists(atPath: img.appendingPathComponent(Self.nomLocal($0)).path)
        }
    }

    /// Écrit dans un dossier temporaire puis remplace l'ancien exemplaire d'un bloc.
    /// Les "src" des images sont relatifs à la racine du site (ex. fr/edition/img/loc-durban.png).
    private func enregistrer<T: Publication>(_ pub: T, json: Data, profil p: Profil, dossier: String, fichier: String) async throws {
        let fm = FileManager.default
        let parent = dossierProfil(p)
        let cible = parent.appendingPathComponent(dossier, isDirectory: true)
        let tmp = parent.appendingPathComponent("\(dossier)-tmp", isDirectory: true)
        let img = tmp.appendingPathComponent("img")
        try? fm.removeItem(at: tmp)
        try fm.createDirectory(at: img, withIntermediateDirectories: true)

        await withTaskGroup(of: Void.self) { groupe in
            for chemin in pub.images {
                groupe.addTask { [session] in
                    guard let url = URL(string: chemin, relativeTo: Self.base)?.absoluteURL,
                          let reponse = try? await session.data(from: url),
                          (reponse.1 as? HTTPURLResponse)?.statusCode == 200 else { return }
                    try? reponse.0.write(to: img.appendingPathComponent(Self.nomLocal(chemin)))
                }
            }
        }
        try json.write(to: tmp.appendingPathComponent(fichier))
        try? fm.removeItem(at: cible)
        try fm.moveItem(at: tmp, to: cible)
    }

    nonisolated static func nomLocal(_ chemin: String) -> String {
        let h = SHA256.hash(data: Data(chemin.utf8)).prefix(8).map { String(format: "%02x", $0) }.joined()
        let ext = (chemin.split(separator: "?").first.map { ($0 as NSString).pathExtension } ?? "").lowercased()
        return ext.isEmpty ? h : "\(h).\(ext)"
    }
}
