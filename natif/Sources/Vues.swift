import SwiftUI
#if os(macOS)
import AppKit
typealias ImagePlateforme = NSImage
func chargerImage(_ url: URL) -> ImagePlateforme? { NSImage(contentsOf: url) }
func vueImage(_ i: ImagePlateforme) -> Image { Image(nsImage: i) }
#else
import UIKit
typealias ImagePlateforme = UIImage
func chargerImage(_ url: URL) -> ImagePlateforme? { UIImage(contentsOfFile: url.path) }
func vueImage(_ i: ImagePlateforme) -> Image { Image(uiImage: i) }
#endif

// Référence : mise en page de quotidien imprimé, reprise de la newsletter validée.
// Georgia, deux couleurs, quatre tailles. Mêmes règles que styles.css de l'app web.
enum Style {
    static let encre = Color(red: 0x12 / 255, green: 0x12 / 255, blue: 0x12 / 255)
    static let note = Color(red: 0x6b / 255, green: 0x6b / 255, blue: 0x6b / 255)
    static let fond = Color.white
    static let colonne: CGFloat = 660
    static func titre() -> Font { .custom("Georgia-Bold", size: 24) }
    static func sousTitre() -> Font { .custom("Georgia-Bold", size: 18) }
    static func texte() -> Font { .custom("Georgia", size: 17) }
    static func petit() -> Font { .custom("Georgia", size: 13) }
}

// Ouverture d'une image en grand, fournie par Journal.
private struct CleZoom: EnvironmentKey { static let defaultValue: (Element) -> Void = { _ in } }
extension EnvironmentValues {
    var zoom: (Element) -> Void {
        get { self[CleZoom.self] }
        set { self[CleZoom.self] = newValue }
    }
}

struct Filet: View {
    var body: some View { Rectangle().fill(Style.encre).frame(height: 1) }
}

struct Note: View {
    let contenu: AttributedString
    init(_ t: String) { contenu = AttributedString(t) }
    init(attribue: AttributedString) { contenu = attribue }
    var body: some View {
        Text(contenu).font(Style.petit()).foregroundStyle(Style.note).lineSpacing(3).tint(Style.note)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct Paragraphe: View {
    let t: String
    var taille: CGFloat = 17
    var body: some View {
        Text(t).font(.custom("Georgia", size: taille)).foregroundStyle(Style.encre).lineSpacing(taille * 0.6)
            .fixedSize(horizontal: false, vertical: true)
            .textSelection(.enabled)
    }
}

func lien(_ s: Source, texte: String? = nil) -> AttributedString {
    var a = AttributedString(texte ?? s.titre)
    a.link = URL(string: s.url)
    a.underlineStyle = .single
    return a
}

func ligneSources(_ sources: [Source]?, apres: String? = nil) -> AttributedString? {
    guard let sources, !sources.isEmpty else { return nil }
    var r = AttributedString(sources.count == 1 ? "Source : " : "Sources : ")
    for (i, s) in sources.enumerated() {
        if i > 0 { r += AttributedString(", ") }
        r += lien(s)
    }
    if let apres, !apres.isEmpty { r += AttributedString(". \(apres)") }
    return r
}

func legende(_ e: Element) -> AttributedString? {
    var r = AttributedString(e.legende ?? "")
    if let l = e.lien {
        if !r.characters.isEmpty { r += AttributedString(" ") }
        r += lien(Source(titre: "", url: l), texte: "Version interactive") + AttributedString(".")
    }
    if let c = e.credit {
        if !r.characters.isEmpty { r += AttributedString(" ") }
        r += lien(c) + AttributedString(".")
    }
    return r.characters.isEmpty ? nil : r
}

/// Image enregistrée sur l'appareil, ou rien si elle manque.
struct ImageLocale: View {
    @EnvironmentObject var depot: Depot
    let chemin: String?
    var remplir = false
    var body: some View {
        if let chemin, let url = depot.imageLocale(chemin), let img = chargerImage(url) {
            vueImage(img).resizable().aspectRatio(contentMode: remplir ? .fill : .fit)
        }
    }
}

struct Figure: View {
    @EnvironmentObject var depot: Depot
    @Environment(\.zoom) var zoom
    let element: Element

    var body: some View {
        if let chemin = element.chemin, depot.imageLocale(chemin) != nil {
            VStack(alignment: .leading, spacing: 7) {
                ImageLocale(chemin: chemin)
                    .frame(maxWidth: largeurMax, alignment: .leading)
                    .overlay(element.estCarte ? Rectangle().stroke(Color(white: 0.9), lineWidth: 1) : nil)
                    .contentShape(Rectangle())
                    .onTapGesture { zoom(element) }
                    .accessibilityLabel(element.estCarte ? "Carte : \(element.ville ?? "")" : (element.legende ?? ""))
                    .accessibilityAddTraits(.isButton)
                if let l = legende(element) { Note(attribue: l) }
            }
            .padding(.vertical, 6)
        }
    }

    private var largeurMax: CGFloat? {
        if element.estCarte { return 420 }
        return element.estLarge ? nil : 360
    }
}

struct VueBloc: View {
    let b: Bloc
    var body: some View {
        switch b.type {
        case "p":
            Paragraphe(t: b.texte ?? "")
        case "sous_titre":
            Text(b.texte ?? "").font(Style.sousTitre()).foregroundStyle(Style.encre).padding(.top, 10)
                .fixedSize(horizontal: false, vertical: true)
        case "liste":
            VStack(alignment: .leading, spacing: 8) {
                ForEach(b.items ?? [], id: \.self) { Paragraphe(t: "- \($0)").padding(.leading, 14) }
            }
        case "image", "carte":
            Figure(element: b.commeElement)
        case "duo":
            HStack(alignment: .top, spacing: 14) {
                ForEach(b.elements ?? [], id: \.self) { e in
                    Figure(element: Element(type: e.type, url: e.url, src: e.src, largeur: 1100,
                                            legende: e.legende, lien: e.lien, credit: e.credit, ville: e.ville))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        case "schema":
            VStack(spacing: 5) {
                ForEach(Array((b.etapes ?? []).enumerated()), id: \.offset) { _, e in
                    if let boite = e.boite {
                        Text(boite).font(.custom("Georgia", size: 16)).foregroundStyle(Style.encre)
                            .multilineTextAlignment(.center).lineSpacing(4)
                            .frame(maxWidth: .infinity).padding(.vertical, 10).padding(.horizontal, 12)
                            .overlay(Rectangle().stroke(Style.encre, lineWidth: 1))
                    } else if let f = e.fleche {
                        Note(f).multilineTextAlignment(.center)
                    }
                }
                if let l = legende(b.commeElement) { Note(attribue: l).frame(maxWidth: .infinity, alignment: .leading) }
            }
            .padding(.vertical, 8)
        default:
            EmptyView()
        }
    }
}

/// Corps commun aux rubriques du jour et aux dossiers de la semaine.
struct CorpsArticle: View {
    let a: Article
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(a.blocs.enumerated()), id: \.offset) { _, b in VueBloc(b: b) }
            if let r = a.a_retenir {
                Text("À retenir").font(Style.sousTitre()).foregroundStyle(Style.encre).padding(.top, 10)
                Paragraphe(t: r)
            }
            if let s = ligneSources(a.sources, apres: a.note_sources) { Note(attribue: s).padding(.top, 6) }
        }
    }
}

struct VueRubrique: View {
    let r: Article
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Note(r.etiquette)
                Text(r.titre).font(Style.titre()).foregroundStyle(Style.encre).fixedSize(horizontal: false, vertical: true)
            }
            CorpsArticle(a: r)
            Filet().padding(.top, 16)
        }
        .padding(.top, 34)
    }
}

struct VueBreves: View {
    let breves: [Breve]
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("En bref").font(Style.titre()).foregroundStyle(Style.encre).padding(.bottom, 12)
            ForEach(breves) { br in
                Filet()
                VStack(alignment: .leading, spacing: 10) {
                    Text(br.rubrique).font(Style.sousTitre()).foregroundStyle(Style.encre)
                    ForEach(br.items, id: \.self) { Paragraphe(t: "- \($0)") }
                    if let s = ligneSources(br.sources) { Note(attribue: s) }
                }
                .padding(.vertical, 12)
            }
            Filet()
        }
        .padding(.top, 34)
    }
}

/// Dossiers de la semaine : repliés, chacun représenté par son image, ouverts au clic.
struct VueSemaine: View {
    let semaine: Semaine
    @State private var ouverts: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Dossiers de la semaine").font(Style.titre()).foregroundStyle(Style.encre)
            Note(semaine.date_texte_semaine ?? semaine.date_texte).padding(.top, 2).padding(.bottom, 14)
            ForEach(semaine.sujets) { s in
                Filet()
                dossier(s).id("dossier-\(s.id)")
            }
            Filet()
        }
        .padding(.top, 40)
        .onChange(of: semaine.date) { _ in ouverts = [] }
    }

    @ViewBuilder
    private func dossier(_ s: Article) -> some View {
        let ouvert = ouverts.contains(s.id)
        VStack(alignment: .leading, spacing: 14) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if ouvert { ouverts.remove(s.id) } else { ouverts.insert(s.id) }
                }
            } label: {
                HStack(alignment: .top, spacing: 20) {
                    if let c = s.couverture?.chemin {
                        ImageLocale(chemin: c, remplir: true)
                            .frame(width: 280, height: 210)
                            .clipped()
                            .background(Color(white: 0.93))
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Note(s.etiquette)
                        Text(s.titre).font(Style.titre()).foregroundStyle(Style.encre)
                            .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                        if let ch = s.chapo { Paragraphe(t: ch) }
                        Text(ouvert ? "Replier" : "Lire le dossier").font(Style.petit()).foregroundStyle(Style.note)
                            .underline(!ouvert)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(ouvert ? "Replier le dossier" : "Ouvrir le dossier")

            if ouvert {
                if let c = s.couverture, let l = legende(c) { Note(attribue: l) }
                CorpsArticle(a: s)
            }
        }
        .padding(.vertical, 16)
    }
}

struct Journal: View {
    @EnvironmentObject var depot: Depot
    @State private var agrandie: Element?

    var body: some View {
        ZStack {
            Style.fond.ignoresSafeArea()
            if depot.edition != nil || depot.semaine != nil {
                contenu
            } else {
                switch depot.etat {
                case .erreur(let m): Note(m)
                default: Note("Chargement de l'édition.")
                }
            }
            if let e = agrandie { zoom(e) }
        }
        .environment(\.colorScheme, .light)
        .environment(\.zoom, { e in withAnimation(.easeOut(duration: 0.15)) { agrandie = e } })
    }

    private var contenu: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let ed = depot.edition {
                        entete(ed)
                        sommaire(ed, proxy: proxy)
                        ForEach(Array(ed.rubriques.enumerated()), id: \.offset) { i, r in VueRubrique(r: r).id("r\(i)") }
                        if let b = ed.breves, !b.isEmpty { VueBreves(breves: b).id("breves") }
                    }
                    if let s = depot.semaine, !s.sujets.isEmpty { VueSemaine(semaine: s).id("semaine") }
                    pied
                }
                .frame(maxWidth: Style.colonne, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.vertical, 48)
                .frame(maxWidth: .infinity)
                .id("haut")
            }
            .onChange(of: depot.edition?.date) { _ in proxy.scrollTo("haut", anchor: .top) }
        }
    }

    private func entete(_ ed: Edition) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Filet()
            HStack(spacing: 10) {
                if let u = Bundle.main.url(forResource: "logo", withExtension: "png"), let i = chargerImage(u) {
                    vueImage(i).resizable().frame(width: 40, height: 40)
                }
                Text("Actualités").font(Style.titre()).foregroundStyle(Style.encre)
            }
            .padding(.top, 16)
            Note(ed.date_texte).padding(.top, 2).padding(.bottom, 20)
            if let une = ed.une {
                Filet()
                VStack(alignment: .leading, spacing: 8) {
                    Note("Actu")
                    Paragraphe(t: une.texte, taille: 19)
                    if let s = ligneSources(une.sources) { Note(attribue: s) }
                }
                .padding(.top, 14).padding(.bottom, 20)
                Filet()
            }
        }
    }

    private func entreeSommaire(_ etiquette: String?, _ titre: String, cible: String, proxy: ScrollViewProxy) -> some View {
        Button { withAnimation { proxy.scrollTo(cible, anchor: .top) } } label: {
            VStack(alignment: .leading, spacing: 2) {
                if let etiquette { Note(etiquette) }
                Text(titre).font(Style.texte()).foregroundStyle(Style.encre)
                    .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func sommaire(_ ed: Edition, proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Note("Sommaire").padding(.bottom, 4)
            ForEach(Array(ed.rubriques.enumerated()), id: \.offset) { i, r in
                entreeSommaire(r.etiquette, r.titre, cible: "r\(i)", proxy: proxy)
            }
            if ed.breves?.isEmpty == false { entreeSommaire(nil, "En bref", cible: "breves", proxy: proxy) }
            if depot.semaine?.sujets.isEmpty == false {
                entreeSommaire(nil, "Dossiers de la semaine", cible: "semaine", proxy: proxy)
            }
            Filet().padding(.top, 14)
        }
        .padding(.top, 16)
    }

    private var pied: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let ed = depot.edition {
                let jour = ed.date_texte.split(separator: " ").dropFirst().joined(separator: " ")
                Note("Rédigé par Claude à partir de sources publiques consultées le \(jour).")
            }
            switch depot.etat {
            case .horsLigne: Note("Hors ligne : dernières éditions enregistrées sur cet appareil.")
            case .aJour: Note("Éditions enregistrées pour la lecture hors ligne.")
            case .chargement: Note("Recherche des nouvelles éditions.")
            default: EmptyView()
            }
        }
        .padding(.top, 26)
    }

    /// Image agrandie sur fond blanc ; un clic ou Échap referme.
    private func zoom(_ e: Element) -> some View {
        ZStack {
            Style.fond.ignoresSafeArea()
            VStack(spacing: 12) {
                ImageLocale(chemin: e.chemin).padding(.horizontal, 24)
                if let l = legende(e) { Note(attribue: l).frame(maxWidth: Style.colonne, alignment: .leading) }
            }
            .padding(32)
        }
        .contentShape(Rectangle())
        .onTapGesture { withAnimation(.easeOut(duration: 0.15)) { agrandie = nil } }
        #if os(macOS)
        .onExitCommand { agrandie = nil }
        #endif
        .transition(.opacity)
    }
}
