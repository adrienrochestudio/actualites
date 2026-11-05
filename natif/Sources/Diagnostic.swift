import Foundation
import AppKit

/// Mesure du changement de langue, lancée seulement avec l'argument --diagnostic (compilation de contrôle sur GitHub).
/// Écrit sur la sortie standard : délai avant affichage de l'édition, plus long blocage du fil principal, puis quitte.
@MainActor
enum Diagnostic {
    static var actif: Bool { CommandLine.arguments.contains("--diagnostic") }

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

    private static func journal(_ etape: String, _ depot: Depot) {
        print("MESURE \(etape) : profil \(depot.profil.rawValue), édition \(depot.edition?.date ?? "aucune"), état \(depot.etat)")
        fflush(stdout)
    }
}
