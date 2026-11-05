import Foundation
import AppKit

/// Journal technique temporaire : enquête sur les clics du menu de langue qui restent sans effet.
/// Écrit dans ~/Documents/Actualités diagnostic/journal.txt (200 Ko au plus, l'ancien contenu est remplacé).
/// À retirer une fois la cause trouvée.
@MainActor
enum JournalTechnique {
    private static let dossier = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Actualités diagnostic", isDirectory: true)
    private static var fichier: URL { dossier.appendingPathComponent("journal.txt") }
    private static var moniteur: Any?

    static func ecrire(_ ligne: String) {
        let fm = FileManager.default
        try? fm.createDirectory(at: dossier, withIntermediateDirectories: true)
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        let texte = "\(f.string(from: Date())) \(ligne)\n"
        if let taille = (try? fm.attributesOfItem(atPath: fichier.path))?[.size] as? Int, taille > 200_000 {
            try? fm.removeItem(at: fichier)
        }
        if let h = try? FileHandle(forWritingTo: fichier) {
            h.seekToEndOfFile()
            h.write(Data(texte.utf8))
            try? h.close()
        } else {
            try? Data(texte.utf8).write(to: fichier)
        }
    }

    static func demarrer(_ depot: Depot) {
        guard moniteur == nil else { return }
        let version = Bundle.main.object(forInfoDictionaryKey: "ActualitesBuild") as? String ?? "?"
        ecrire("lancement : app \(version), \(ProcessInfo.processInfo.operatingSystemVersionString), écran \(NSScreen.main.map { "\(Int($0.frame.width))x\(Int($0.frame.height))" } ?? "?"), profil \(depot.profil.rawValue), vue \(UserDefaults.standard.string(forKey: "vue") ?? "?"), gardés \(depot.gardes.count)")
        moniteur = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .leftMouseUp]) { e in
            MainActor.assumeIsolated { noter(e, depot) }
            return e
        }
    }

    private static func noter(_ e: NSEvent, _ depot: Depot) {
        guard let w = e.window, let vue = w.contentView else {
            ecrire("clic hors fenêtre (\(e.type == .leftMouseDown ? "appui" : "relâche"))")
            return
        }
        let p = e.locationInWindow
        let haut = vue.bounds.height - p.y
        let touche = vue.hitTest(vue.convert(p, from: nil)).map { String(describing: type(of: $0)) } ?? "aucune"
        let bouton = Diagnostic.cadres.first { $0.value.contains(CGPoint(x: p.x, y: haut)) }?.key.rawValue ?? "-"
        let cadres = Profil.allCases.map { pr in Diagnostic.cadres[pr].map { "\(pr.rawValue)@\(Int($0.minX)),\(Int($0.minY)) \(Int($0.width))x\(Int($0.height))" } ?? "\(pr.rawValue)@?" }.joined(separator: " ")
        ecrire("\(e.type == .leftMouseDown ? "appui" : "relâche") x=\(Int(p.x)) y=\(Int(haut)) depuis le haut, app active \(NSApp.isActive), clé \(w.isKeyWindow), plein écran \(w.styleMask.contains(.fullScreen)), fenêtre \(Int(vue.bounds.width))x\(Int(vue.bounds.height)), vue touchée \(touche), bouton langue \(bouton), boutons [\(cadres)], profil \(depot.profil.rawValue)")
    }
}
