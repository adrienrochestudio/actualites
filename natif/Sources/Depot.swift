import Foundation
import CryptoKit

/// Récupère les éditions publiées sur GitHub Pages et les garde sur l'appareil.
/// Dossier : Application Support/Actualites/{edition,hebdo}/ (fichier JSON + img/). Un seul exemplaire de chaque.
@MainActor
final class Depot: ObservableObject {
    enum Etat: Equatable {
        case vide, chargement, aJour, horsLigne
        case erreur(String)
    }

    @Published private(set) var edition: Edition?
    @Published private(set) var semaine: Semaine?
    @Published private(set) var etat: Etat = .vide

    nonisolated static let base = URL(string: "https://adrienrochestudio.github.io/actualites/")!
    private let agent = "ActualitesApp/1.0 (+https://github.com/adrienrochestudio/actualites)"
    private var derniereVerif = Date.distantPast

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
        edition = lire(Edition.self, "edition", "edition.json")
        semaine = lire(Semaine.self, "hebdo", "hebdo.json")
        if edition != nil || semaine != nil { etat = .horsLigne }
    }

    /// Copie locale d'une image (nil si absente).
    func imageLocale(_ chemin: String) -> URL? {
        for dossier in ["edition", "hebdo"] {
            let u = racine.appendingPathComponent(dossier).appendingPathComponent("img").appendingPathComponent(Self.nomLocal(chemin))
            if FileManager.default.fileExists(atPath: u.path) { return u }
        }
        return nil
    }

    /// À l'ouverture et au retour au premier plan. `force` ignore le délai minimal entre deux vérifications.
    func actualiser(force: Bool = false) async {
        if !force, Date().timeIntervalSince(derniereVerif) < 600 { return }
        derniereVerif = Date()
        if edition == nil && semaine == nil { etat = .chargement }
        async let j: Edition? = recuperer(Edition.self, "edition", "edition.json", actuelle: edition)
        async let s: Semaine? = recuperer(Semaine.self, "hebdo", "hebdo.json", actuelle: semaine)
        let (nj, ns) = await (j, s)
        if let nj { edition = nj }
        if let ns { semaine = ns }
        if nj != nil || ns != nil {
            etat = .aJour
        } else {
            etat = (edition == nil && semaine == nil)
                ? .erreur("Aucune édition sur cet appareil. Ouvrir l'app avec une connexion.") : .horsLigne
        }
    }

    private func lire<T: Decodable>(_ type: T.Type, _ dossier: String, _ fichier: String) -> T? {
        let u = racine.appendingPathComponent(dossier).appendingPathComponent(fichier)
        guard let data = try? Data(contentsOf: u) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    /// Télécharge une publication ; ne réécrit le disque que si elle a changé ou s'il manque des images.
    private func recuperer<T: Publication>(_ type: T.Type, _ dossier: String, _ fichier: String, actuelle: T?) async -> T? {
        do {
            let url = Self.base.appendingPathComponent(dossier).appendingPathComponent(fichier)
            let (data, rep) = try await session.data(from: url)
            guard (rep as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            let nouvelle = try JSONDecoder().decode(T.self, from: data)
            if nouvelle.date != actuelle?.date || !nouvelle.images.allSatisfy({ imageLocale($0) != nil }) {
                try await enregistrer(nouvelle, json: data, dossier: dossier, fichier: fichier)
            }
            return nouvelle
        } catch {
            return nil
        }
    }

    /// Écrit dans un dossier temporaire puis remplace l'ancien exemplaire d'un bloc.
    private func enregistrer<T: Publication>(_ pub: T, json: Data, dossier: String, fichier: String) async throws {
        let fm = FileManager.default
        let cible = racine.appendingPathComponent(dossier, isDirectory: true)
        let tmp = racine.appendingPathComponent("\(dossier)-tmp", isDirectory: true)
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
