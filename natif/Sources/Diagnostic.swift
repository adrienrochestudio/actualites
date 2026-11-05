import Foundation
import AppKit

/// Mesure du changement de langue, lancée seulement avec l'argument --diagnostic (compilation de contrôle sur GitHub).
/// Écrit sur la sortie standard : délai avant affichage de l'édition, plus long blocage du fil principal, puis quitte.
@MainActor
enum Diagnostic {
    static var actif: Bool { CommandLine.arguments.contains("--diagnostic") }

    /// Position des boutons de langue dans la fenêtre (coordonnées SwiftUI, origine en haut à gauche).
    static var cadres: [Profil: CGRect] = [:]

    /// Plus long délai observé (ms) entre deux battements du fil principal, mesuré depuis un fil secondaire.
    nonisolated(unsafe) private static var blocageMax = 0.0
    nonisolated(unsafe) private static var dernierBattement = Date()

    static func lancer(_ depot: Depot) {
        guard actif else { return }
        Thread.detachNewThread {
            while true {
                Thread.sleep(forTimeInterval: 0.02)
                let ecart = Date().timeIntervalSince(dernierBattement) * 1000
                if ecart > blocageMax { blocageMax = ecart }
            }
        }
        Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { _ in dernierBattement = Date() }
        Task {
            try? await Task.sleep(nanoseconds: 15_000_000_000)
            journal("départ", depot)
            // Vrai clic de souris sur chaque bouton de langue, envoyé par la file d'événements de l'app.
            for p in [Profil.pt, .fr] {
                cliquer(p, depot)
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                print("MESURE clic sur \(p.rawValue) : profil affiché \(depot.profil.rawValue)\(depot.profil == p ? " (OK)" : " (ÉCHEC)")")
                fflush(stdout)
            }
            for p in [Profil.pt, .fr, .pt, .fr] {
                blocageMax = 0
                let debut = Date()
                depot.changerProfil(p)
                let clic = Date().timeIntervalSince(debut) * 1000
                var affiche: Double? = nil
                while Date().timeIntervalSince(debut) < 25 {
                    try? await Task.sleep(nanoseconds: 50_000_000)
                    if affiche == nil, depot.edition != nil, depot.profil == p { affiche = Date().timeIntervalSince(debut) * 1000 }
                    if affiche != nil, !depot.enChargement, Date().timeIntervalSince(debut) > 8 { break }
                }
                print(String(format: "MESURE %@ : clic %.0f ms, édition affichée %@, blocage max %.0f ms, état %@",
                             p.rawValue, clic, affiche.map { String(format: "%.0f ms", $0) } ?? "jamais", blocageMax, "\(depot.etat)"))
                fflush(stdout)
            }
            NSApp.terminate(nil)
        }
    }

    private static func cliquer(_ p: Profil, _ depot: Depot) {
        guard let w = NSApp.windows.first(where: { $0.canBecomeMain }), let vue = w.contentView, let c = cadres[p] else {
            print("MESURE clic sur \(p.rawValue) : bouton introuvable"); return
        }
        let hauteur = vue.bounds.height
        let point = NSPoint(x: c.midX, y: hauteur - c.midY)
        let zoneLibre = w.contentLayoutRect
        let cible = vue.hitTest(point)
        print(String(format: "MESURE bouton %@ : centre y=%.0f depuis le haut, fenêtre %.0fx%.0f, plein écran %@, zone hors barre d'outils y<=%.0f depuis le haut, vue touchée %@",
                     p.rawValue, c.midY, vue.bounds.width, hauteur, w.styleMask.contains(.fullScreen) ? "oui" : "non",
                     hauteur - zoneLibre.maxY, cible.map { String(describing: type(of: $0)) } ?? "aucune"))
        for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
            if let e = NSEvent.mouseEvent(with: type, location: point, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                                          windowNumber: w.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1) {
                NSApp.postEvent(e, atStart: false)
            }
        }
    }

    private static func journal(_ etape: String, _ depot: Depot) {
        print("MESURE \(etape) : profil \(depot.profil.rawValue), édition \(depot.edition?.date ?? "aucune"), état \(depot.etat)")
        fflush(stdout)
    }
}
