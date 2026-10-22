import Foundation
import CryptoKit

/// Récupère l'édition publiée sur GitHub Pages et la garde sur l'appareil.
/// Dossier : Application Support/Actualites/edition/ (edition.json + img/). Une seule édition est conservée.
@MainActor
final class Depot: ObservableObject {
    enum Etat: Equatable {
        case vide
        case chargement
        case aJour
        case horsLigne
        case erreur(String)
    }

    @Published private(set) var edition: Edition?
    @Published private(set) var etat: Etat = .vide

    nonisolated static let base = URL(string: "https://adrienrochestudio.github.io/actualites/")!
    private let agent = "ActualitesApp/1.0 (+https://github.com/adrienrochestudio/actualites)"
    private var derniereVerif = Date.distantPast

    private let dossier: URL = {
        let racine = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return racine.appendingPathComponent("Actualites/edition", isDirectory: true)
    }()
    private var fichierJSON: URL { dossier.appendingPathComponent("edition.json") }
    private var dossierImages: URL { dossier.appendingPathComponent("img", isDirectory: true) }

    private lazy var session: URLSession = {
        let c = URLSessionConfiguration.default
        c.requestCachePolicy = .reloadIgnoringLocalCacheData
        c.timeoutIntervalForRequest = 20
        c.httpAdditionalHeaders = ["User-Agent": agent]
        return URLSession(configuration: c)
    }()

    init() {
        if let data = try? Data(contentsOf: fichierJSON),
           let ed = try? JSONDecoder().decode(Edition.self, from: data) {
            edition = ed
            etat = .horsLigne
        }
    }

    /// Copie locale d'une image de l'édition (nil si absente).
    func imageLocale(_ chemin: String) -> URL? {
        let u = dossierImages.appendingPathComponent(Self.nomLocal(chemin))
        return FileManager.default.fileExists(atPath: u.path) ? u : nil
    }

    /// À l'ouverture et au retour au premier plan. `force` ignore le délai minimal entre deux vérifications.
    func actualiser(force: Bool = false) async {
        if !force, Date().timeIntervalSince(derniereVerif) < 600 { return }
        derniereVerif = Date()
        if edition == nil { etat = .chargement }
        do {
            let url = Self.base.appendingPathComponent("edition/edition.json")
            let (data, rep) = try await session.data(from: url)
            guard (rep as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
            let nouvelle = try JSONDecoder().decode(Edition.self, from: data)
            if nouvelle.date != edition?.date || !imagesCompletes(nouvelle) {
                try await enregistrer(nouvelle, json: data)
            }
            edition = nouvelle
            etat = .aJour
        } catch {
            etat = edition == nil ? .erreur("Aucune édition sur cet appareil. Ouvrir l'app avec une connexion.") : .horsLigne
        }
    }

    private func imagesCompletes(_ ed: Edition) -> Bool {
        ed.images.allSatisfy { imageLocale($0) != nil }
    }

    /// Écrit l'édition dans un dossier temporaire puis remplace l'ancienne d'un bloc.
    private func enregistrer(_ ed: Edition, json: Data) async throws {
        let fm = FileManager.default
        let tmp = dossier.deletingLastPathComponent().appendingPathComponent("edition-tmp", isDirectory: true)
        try? fm.removeItem(at: tmp)
        try fm.createDirectory(at: tmp.appendingPathComponent("img"), withIntermediateDirectories: true)

        await withTaskGroup(of: Void.self) { groupe in
            for chemin in ed.images {
                groupe.addTask { [session] in
                    guard let url = URL(string: chemin, relativeTo: Self.base)?.absoluteURL,
                          let reponse = try? await session.data(from: url),
                          (reponse.1 as? HTTPURLResponse)?.statusCode == 200 else { return }
                    try? reponse.0.write(to: tmp.appendingPathComponent("img").appendingPathComponent(Self.nomLocal(chemin)))
                }
            }
        }
        try json.write(to: tmp.appendingPathComponent("edition.json"))
        try? fm.removeItem(at: dossier)
        try fm.moveItem(at: tmp, to: dossier)
    }

    nonisolated static func nomLocal(_ chemin: String) -> String {
        let h = SHA256.hash(data: Data(chemin.utf8)).prefix(8).map { String(format: "%02x", $0) }.joined()
        let ext = (chemin.split(separator: "?").first.map { ($0 as NSString).pathExtension } ?? "").lowercased()
        return ext.isEmpty ? h : "\(h).\(ext)"
    }
}
