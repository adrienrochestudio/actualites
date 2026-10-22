import SwiftUI
import AppKit

@main
struct ActualitesMac: App {
    @NSApplicationDelegateAdaptor(Delegue.self) var delegue
    @StateObject private var depot = Depot()
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        Window("Actualités", id: "journal") {
            Journal()
                .environmentObject(depot)
                .frame(minWidth: 480, minHeight: 600)
                .task { await depot.actualiser(force: true) }
                .onChange(of: phase) { p in
                    if p == .active { Task { await depot.actualiser() } }
                }
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("Rechercher la nouvelle édition") { Task { await depot.actualiser(force: true) } }
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
