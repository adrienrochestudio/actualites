import Foundation
import CryptoKit
import SwiftUI

/// Récupère les éditions publiées sur GitHub Pages et les garde sur l'appareil.
/// En ligne : {profil}/edition/edition.json et {profil}/hebdo/hebdo.json.
/// Sur l'appareil : Application Support/Actualites/{profil}/{edition,hebdo}/ (fichier JSON + img/).
/// Un seul exemplaire de chaque, pour le seul profil choisi.
@MainActor
final class Depot: ObservableObject {
    enum Etat: Equatable {
        case vide, chargement, aJour, horsLigne, rien
    }

    @Published private(set) var profil: Profil
    @Published private(set) var edition: Edition?
    @Published private(set) var semaine: Semaine?
    @Published private(set) var etat: Etat = .vide
    /// Vrai pendant une vérification réseau (le globe du logo accélère).
    @Published private(set) var enChargement = false

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
        if edition != nil || semaine != nil { etat = .horsLigne }
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
        return nil
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

    /// On ne garde hors ligne que le profil choisi.
    private func supprimerAutresProfils(que p: Profil) {
        let fm = FileManager.default
        for autre in Profil.allCases where autre != p {
            let u = dossierProfil(autre)
            if fm.fileExists(atPath: u.path) { try? fm.removeItem(at: u) }
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
