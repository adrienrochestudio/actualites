import SwiftUI
import WebKit

/// Image agrandie sur fond blanc ; un clic ou Échap referme.
/// Graphique Our World in Data (lien vers ourworldindata.org) : la version interactive remplace l'image,
/// avec un bouton Fermer ; hors ligne, retour à l'image.
struct VueZoom: View {
    @Environment(\.textes) var t
    let e: Element
    let fermer: () -> Void
    @State private var echec = false

    private var urlWeb: URL? {
        guard let l = e.lien, let u = URL(string: l), let h = u.host?.lowercased(),
              h == "ourworldindata.org" || h.hasSuffix(".ourworldindata.org") else { return nil }
        return u
    }

    var body: some View {
        if let u = urlWeb, !echec {
            // Pas de fermeture au clic : la vue web se manipule à la souris.
            ZStack(alignment: .topTrailing) {
                Style.fond.ignoresSafeArea()
                VStack(spacing: 12) {
                    VueWeb(url: u) { echec = true }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.horizontal, 24)
                    if let l = legende(e, t) { Note(attribue: l, italique: true).frame(maxWidth: Style.colonne, alignment: .leading) }
                }
                .padding(32)
                Button(action: fermer) {
                    Text(t.fermer).underline().font(Style.serif(14)).foregroundStyle(Style.encre)
                        .padding(.horizontal, 24).padding(.vertical, 12)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
            }
            .onExitCommand(perform: fermer)
        } else {
            ZStack {
                Style.fond.ignoresSafeArea()
                VStack(spacing: 12) {
                    ImageLocale(chemin: e.chemin).padding(.horizontal, 24)
                    if let l = legende(e, t) { Note(attribue: l, italique: true).frame(maxWidth: Style.colonne, alignment: .leading) }
                }
                .padding(32)
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: fermer)
            .onExitCommand(perform: fermer)
        }
    }
}

/// WKWebView chargée sur une adresse ; `echec` est appelé si la page ne se charge pas.
struct VueWeb: NSViewRepresentable {
    let url: URL
    let echec: () -> Void

    func makeCoordinator() -> Coordinateur { Coordinateur(echec: echec) }

    func makeNSView(context: Context) -> WKWebView {
        let w = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        w.navigationDelegate = context.coordinator
        w.load(URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 15))
        return w
    }

    func updateNSView(_ w: WKWebView, context: Context) {}

    final class Coordinateur: NSObject, WKNavigationDelegate {
        let echec: () -> Void
        private var signale = false

        init(echec: @escaping () -> Void) { self.echec = echec }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            signaler(error)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            signaler(error)
        }

        /// Une navigation annulée (redirection, nouveau chargement) n'est pas un échec.
        private func signaler(_ error: Error) {
            let e = error as NSError
            if e.domain == NSURLErrorDomain && e.code == NSURLErrorCancelled { return }
            guard !signale else { return }
            signale = true
            DispatchQueue.main.async { self.echec() }
        }
    }
}
