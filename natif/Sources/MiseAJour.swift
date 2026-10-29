import Foundation
import AppKit

/// Mise à jour de l'app au lancement, depuis la release GitHub "mac".
/// mac-version.txt (quelques octets) donne la version publiée ; le zip (1 Mo) n'est téléchargé que si elle diffère
/// de ActualitesBuild (Info.plist, écrit par construire-mac.sh), c'est-à-dire quand le code de l'app a changé.
/// Sans effet si l'app n'est pas modifiable (lancée depuis le dossier Téléchargements par Gatekeeper, dossier protégé).
enum MiseAJour {
    private static let release = URL(string: "https://github.com/adrienrochestudio/actualites/releases/download/mac/")!

    static func verifier() async {
        guard let locale = Bundle.main.object(forInfoDictionaryKey: "ActualitesBuild") as? String, !locale.isEmpty else { return }
        let app = Bundle.main.bundleURL
        let fm = FileManager.default
        guard !app.path.contains("/AppTranslocation/"),
              fm.isWritableFile(atPath: app.deletingLastPathComponent().path),
              fm.isWritableFile(atPath: app.path) else { return }

        let c = URLSessionConfiguration.ephemeral
        c.timeoutIntervalForRequest = 30
        let session = URLSession(configuration: c)
        do {
            let (v, rv) = try await session.data(from: release.appendingPathComponent("mac-version.txt"))
            guard (rv as? HTTPURLResponse)?.statusCode == 200,
                  let distante = String(data: v, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !distante.isEmpty, distante != locale else { return }

            let (zip, rz) = try await session.data(from: release.appendingPathComponent("Actualites-mac.zip"))
            guard (rz as? HTTPURLResponse)?.statusCode == 200 else { return }
            let dossier = fm.temporaryDirectory.appendingPathComponent("Actualites-maj-\(UUID().uuidString)", isDirectory: true)
            try fm.createDirectory(at: dossier, withIntermediateDirectories: true)
            let archive = dossier.appendingPathComponent("Actualites-mac.zip")
            try zip.write(to: archive)
            guard executer("/usr/bin/ditto", ["-x", "-k", archive.path, dossier.path]),
                  let nouvelle = try fm.contentsOfDirectory(at: dossier, includingPropertiesForKeys: nil)
                      .first(where: { $0.pathExtension == "app" }) else { return }

            // Contrôles avant remplacement : version annoncée et signature intacte.
            guard let info = NSDictionary(contentsOf: nouvelle.appendingPathComponent("Contents/Info.plist")),
                  info["ActualitesBuild"] as? String == distante,
                  executer("/usr/bin/codesign", ["--verify", "--deep", nouvelle.path]) else { return }
            await remplacer(app, par: nouvelle)
        } catch {
            return
        }
    }

    /// Un script attend la fin de l'app, échange les deux versions (l'ancienne est remise en place si l'échange échoue)
    /// puis relance l'app.
    @MainActor
    private static func remplacer(_ app: URL, par nouvelle: URL) {
        let script = """
        while kill -0 \(ProcessInfo.processInfo.processIdentifier) 2>/dev/null; do sleep 0.2; done
        ancienne="$1.ancienne"
        rm -rf "$ancienne"
        if mv "$1" "$ancienne" && mv "$2" "$1"; then rm -rf "$ancienne"; else [ -d "$1" ] || mv "$ancienne" "$1"; fi
        open "$1"
        """
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/sh")
        p.arguments = ["-c", script, "sh", app.path, nouvelle.path]
        guard (try? p.run()) != nil else { return }
        NSApp.terminate(nil)
    }

    private static func executer(_ outil: String, _ arguments: [String]) -> Bool {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: outil)
        p.arguments = arguments
        do { try p.run() } catch { return false }
        p.waitUntilExit()
        return p.terminationStatus == 0
    }
}
