import SwiftUI
import AppKit
import Combine

@main
struct ActualitesMac: App {
    @NSApplicationDelegateAdaptor(Delegue.self) var delegue
    @StateObject private var depot = Depot()
    /// Vérification régulière quand l'app reste ouverte (la tâche publie vers 6 h, heure de Paris).
    private let horloge = Timer.publish(every: 30 * 60, on: .main, in: .common).autoconnect()

    var body: some Scene {
        Window("Actualités", id: "journal") {
            Journal()
                .environmentObject(depot)
                .frame(minWidth: 720, minHeight: 600)
                .task { await depot.actualiser(force: true) }
                // scenePhase ne change pas de façon fiable sur macOS : on écoute directement le système.
                // Retour au premier plan : nouvelle vérification si la dernière date de plus de 10 min.
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                    Task { await depot.actualiser() }
                }
                // Sortie de veille et changement de jour : l'édition a pu changer, vérification immédiate.
                .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification)) { _ in
                    Task { await depot.actualiser(force: true) }
                }
                .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
                    Task { await depot.actualiser(force: true) }
                }
                .onReceive(horloge) { _ in
                    Task { await depot.actualiser() }
                }
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button(depot.profil.textes.actualiser) { Task { await depot.actualiser(force: true) } }
                    .keyboardShortcut("r")
            }
        }
    }
}

/// Plein écran dès l'ouverture, et l'app se ferme avec sa fenêtre.
final class Delegue: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            guard let w = NSApp.windows.first(where: { $0.canBecomeMain }) else { return }
            w.collectionBehavior.insert(.fullScreenPrimary)
            if !w.styleMask.contains(.fullScreen) { w.toggleFullScreen(nil) }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
