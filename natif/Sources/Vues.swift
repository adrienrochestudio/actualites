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

// Référence : apps de quotidiens de qualité (NYT, The Economist, FT), mêmes règles que styles.css :
// titres en graisse moyenne et coupe display, séparation par l'espace plutôt que par des filets.
// Coupes statiques de Source Serif 4 embarquées : Texte (taille optique 20), Titre (48), Manchette (60).
enum Style {
    static let encre = Color(red: 0x12 / 255, green: 0x12 / 255, blue: 0x12 / 255)
    static let note = Color(red: 0x66 / 255, green: 0x66 / 255, blue: 0x66 / 255)
    static let marque = Color(red: 0x6b / 255, green: 0x1d / 255, blue: 0x2a / 255)
    static let fond = Color.white
    static let colonne: CGFloat = 640
    static func serif(_ taille: CGFloat, gras: Bool = false, italique: Bool = false) -> Font {
        .custom(gras ? "ActualitesTexte-Semibold" : (italique ? "ActualitesTexte-Italic" : "ActualitesTexte-Regular"), size: taille)
    }
    static func titre(_ taille: CGFloat = 31) -> Font { .custom("ActualitesTitre-Medium", size: taille) }
    static func manchette() -> Font { .custom("ActualitesManchette-Semibold", size: 54) }
    static func sousTitre() -> Font { serif(19, gras: true) }
    static func texte() -> Font { serif(18) }
    static func petit(italique: Bool = false) -> Font { serif(13, italique: italique) }
}

// Ouverture d'une image en grand, fournie par Journal.
private struct CleZoom: EnvironmentKey { static let defaultValue: (Element) -> Void = { _ in } }
extension EnvironmentValues {
    var zoom: (Element) -> Void {
        get { self[CleZoom.self] }
        set { self[CleZoom.self] = newValue }
    }
}

struct NomRubrique: View {
    let t: String
    var body: some View { Text(t).font(Style.serif(14, gras: true)).foregroundStyle(Style.marque) }
}

struct Filet: View {
    var body: some View { Rectangle().fill(Style.encre).frame(height: 1) }
}

struct Note: View {
    let contenu: AttributedString
    var italique = false
    init(_ t: String, italique: Bool = false) { contenu = AttributedString(t); self.italique = italique }
    init(attribue: AttributedString, italique: Bool = false) { contenu = attribue; self.italique = italique }
    var body: some View {
        Text(contenu).font(Style.petit(italique: italique)).foregroundStyle(Style.note).lineSpacing(3).tint(Style.note)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct Paragraphe: View {
    let t: String
    var taille: CGFloat = 18
    var italique = false
    var body: some View {
        Text(t).font(Style.serif(taille, italique: italique)).foregroundStyle(Style.encre).lineSpacing(taille * 0.6)
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
                if let l = legende(element) { Note(attribue: l, italique: true) }
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
                        Text(boite).font(Style.serif(16)).foregroundStyle(Style.encre)
                            .multilineTextAlignment(.center).lineSpacing(4)
                            .frame(maxWidth: .infinity).padding(.vertical, 10).padding(.horizontal, 12)
                            .overlay(Rectangle().stroke(Style.encre, lineWidth: 1))
                    } else if let f = e.fleche {
                        Note(f, italique: true).multilineTextAlignment(.center)
                    }
                }
                if let l = legende(b.commeElement) { Note(attribue: l, italique: true).frame(maxWidth: .infinity, alignment: .leading) }
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
            VStack(alignment: .leading, spacing: 6) {
                NomRubrique(t: r.etiquette)
                Text(r.titre).font(Style.titre()).foregroundStyle(Style.encre).fixedSize(horizontal: false, vertical: true)
            }
            CorpsArticle(a: r)
        }
        .padding(.top, 64)
    }
}

struct VueBreves: View {
    let breves: [Breve]
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("En bref").font(Style.titre()).foregroundStyle(Style.encre).padding(.bottom, 6)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 32, alignment: .top), GridItem(.flexible(), alignment: .top)],
                      alignment: .leading, spacing: 0) {
                ForEach(breves) { br in
                    VStack(alignment: .leading, spacing: 10) {
                        NomRubrique(t: br.rubrique)
                        ForEach(br.items, id: \.self) { Paragraphe(t: "- \($0)", taille: 17) }
                        if let s = ligneSources(br.sources) { Note(attribue: s) }
                    }
                    .padding(.top, 22)
                }
            }
        }
        .padding(.top, 72)
    }
}

/// Dossiers de la semaine : repliés, chacun représenté par son image, ouverts au clic.
struct VueSemaine: View {
    let semaine: Semaine
    @State private var ouverts: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Dossiers de la semaine").font(Style.titre()).foregroundStyle(Style.encre)
                .padding(.top, 36).padding(.bottom, 8)
            ForEach(semaine.sujets) { s in
                dossier(s).id("dossier-\(s.id)")
            }
        }
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
                            .frame(width: 300, height: 225)
                            .clipped()
                            .background(Color(white: 0.93))
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        NomRubrique(t: s.etiquette)
                        Text(s.titre).font(Style.titre()).foregroundStyle(Style.encre)
                            .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                        if let ch = s.chapo { Paragraphe(t: ch, italique: true) }
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
                if let c = s.couverture, let l = legende(c) { Note(attribue: l, italique: true) }
                CorpsArticle(a: s)
            }
        }
        .padding(.vertical, 24)
    }
}

enum Vue: String { case jour, semaine }

struct Journal: View {
    @EnvironmentObject var depot: Depot
    @State private var agrandie: Element?
    @AppStorage("vue") private var vue: Vue = .jour

    var body: some View {
        ZStack {
            Style.fond.ignoresSafeArea()
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        manchette
                        VStack(alignment: .leading, spacing: 0) {
                            contenu
                            pied
                        }
                        .frame(maxWidth: Style.colonne, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 56)
                    }
                    .frame(maxWidth: .infinity)
                    .id("haut")
                }
                .onChange(of: vue) { _ in proxy.scrollTo("haut", anchor: .top) }
                .onChange(of: depot.edition?.date) { _ in if vue == .jour { proxy.scrollTo("haut", anchor: .top) } }
            }
            if let e = agrandie { zoom(e) }
        }
        .environment(\.colorScheme, .light)
        .environment(\.zoom, { e in withAnimation(.easeOut(duration: 0.15)) { agrandie = e } })
    }

    /// Titre du journal centré, double filet, onglets Quotidien / Hebdomadaire, date.
    private var manchette: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                if let u = Bundle.main.url(forResource: "logo", withExtension: "png"), let i = chargerImage(u) {
                    vueImage(i).resizable().frame(width: 42, height: 42)
                }
                Text("Actualités").font(Style.manchette()).foregroundStyle(Style.encre)
            }
            .padding(.top, 40)
            HStack(spacing: 32) {
                onglet("Quotidien", .jour)
                onglet("Hebdomadaire", .semaine)
            }
            .padding(.top, 16)
            Rectangle().fill(Color(white: 0.89)).frame(height: 1)
            Note(ligneDate).padding(.top, 14)
        }
        .frame(maxWidth: 880)
        .padding(.horizontal, 24)
    }

    private var ligneDate: String {
        vue == .jour ? (depot.edition?.date_texte ?? "")
            : (depot.semaine?.date_texte_semaine ?? depot.semaine?.date_texte ?? "")
    }

    private func onglet(_ titre: String, _ v: Vue) -> some View {
        Button { vue = v } label: {
            Text(titre)
                .font(Style.serif(16, gras: vue == v))
                .foregroundStyle(vue == v ? Style.encre : Style.note)
                .padding(.vertical, 12)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(vue == v ? Style.encre : .clear).frame(height: 2)
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(vue == v ? .isSelected : [])
    }

    @ViewBuilder
    private var contenu: some View {
        switch vue {
        case .jour:
            if let ed = depot.edition {
                if let une = ed.une {
                    VStack(alignment: .leading, spacing: 10) {
                        NomRubrique(t: "Actu")
                        Paragraphe(t: une.texte, taille: 22)
                        if let s = ligneSources(une.sources) { Note(attribue: s) }
                    }
                    .padding(.top, 30)
                }
                ForEach(Array(ed.rubriques.enumerated()), id: \.offset) { _, r in VueRubrique(r: r) }
                if let b = ed.breves, !b.isEmpty { VueBreves(breves: b) }
            } else {
                vide("Pas encore d'édition du jour sur cet appareil.")
            }
        case .semaine:
            if let s = depot.semaine, !s.sujets.isEmpty {
                VueSemaine(semaine: s)
            } else {
                vide("Pas encore d'édition de la semaine sur cet appareil.")
            }
        }
    }

    private func vide(_ texte: String) -> some View {
        VStack(alignment: .leading) {
            switch depot.etat {
            case .chargement: Note("Chargement de l'édition.")
            case .erreur(let m): Note(m)
            default: Note(texte)
            }
        }
        .padding(.top, 28)
    }

    private var pied: some View {
        VStack(alignment: .leading, spacing: 6) {
            if vue == .jour, let ed = depot.edition {
                let jour = ed.date_texte.split(separator: " ").dropFirst().joined(separator: " ")
                Note("Rédigé par Claude à partir de sources publiques consultées le \(jour).")
            } else if vue == .semaine, depot.semaine != nil {
                Note("Dossiers rédigés par Claude à partir de sources publiques, publiés chaque lundi.")
            }
            switch depot.etat {
            case .horsLigne: Note("Hors ligne : dernières éditions enregistrées sur cet appareil.")
            case .aJour: Note("Éditions enregistrées pour la lecture hors ligne.")
            case .chargement: Note("Recherche des nouvelles éditions.")
            default: EmptyView()
            }
        }
        .padding(.top, 64)
    }

    /// Image agrandie sur fond blanc ; un clic ou Échap referme.
    private func zoom(_ e: Element) -> some View {
        ZStack {
            Style.fond.ignoresSafeArea()
            VStack(spacing: 12) {
                ImageLocale(chemin: e.chemin).padding(.horizontal, 24)
                if let l = legende(e) { Note(attribue: l, italique: true).frame(maxWidth: Style.colonne, alignment: .leading) }
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
