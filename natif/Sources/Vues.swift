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

// Gabarit repris de la newsletter validée : Georgia, deux couleurs, quatre tailles.
enum Style {
    static let encre = Color(red: 0x12 / 255, green: 0x12 / 255, blue: 0x12 / 255)
    static let note = Color(red: 0x6b / 255, green: 0x6b / 255, blue: 0x6b / 255)
    static let fond = Color.white
    static func titre() -> Font { .custom("Georgia-Bold", size: 24) }
    static func sousTitre() -> Font { .custom("Georgia-Bold", size: 18) }
    static func texte() -> Font { .custom("Georgia", size: 17) }
    static func petit() -> Font { .custom("Georgia", size: 13) }
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
    var body: some View {
        Text(t).font(Style.texte()).foregroundStyle(Style.encre).lineSpacing(8)
            .fixedSize(horizontal: false, vertical: true)
            .textSelection(.enabled)
    }
}

func lien(_ s: Source) -> AttributedString {
    var a = AttributedString(s.titre)
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
    if let c = e.credit {
        if e.legende != nil { r += AttributedString(" ") }
        r += lien(c) + AttributedString(".")
    }
    return r.characters.isEmpty ? nil : r
}

struct ImageEdition: View {
    @EnvironmentObject var depot: Depot
    let element: Element

    var body: some View {
        if let chemin = element.chemin, let url = depot.imageLocale(chemin), let img = chargerImage(url) {
            VStack(alignment: .leading, spacing: 6) {
                vueImage(img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: largeurMax, alignment: .leading)
                    .accessibilityLabel(element.estCarte ? "Carte : \(element.ville ?? "")" : (element.legende ?? ""))
                if let l = legende(element) { Note(attribue: l) }
            }
        }
    }

    private var largeurMax: CGFloat? {
        if element.estCarte { return 260 }
        if let l = element.largeur, l < 500 { return l }
        return nil
    }
}

struct VueBloc: View {
    let b: Bloc
    var body: some View {
        switch b.type {
        case "p":
            Paragraphe(t: b.texte ?? "")
        case "sous_titre":
            Text(b.texte ?? "").font(Style.sousTitre()).foregroundStyle(Style.encre).padding(.top, 8)
                .fixedSize(horizontal: false, vertical: true)
        case "liste":
            VStack(alignment: .leading, spacing: 8) {
                ForEach(b.items ?? [], id: \.self) { Paragraphe(t: "- \($0)").padding(.leading, 14) }
            }
        case "image", "carte":
            ImageEdition(element: b.commeElement)
        case "duo":
            HStack(alignment: .top, spacing: 12) {
                ForEach(b.elements ?? [], id: \.self) { e in
                    ImageEdition(element: Element(type: e.type, url: e.url, src: e.src, largeur: nil,
                                                  legende: e.legende, lien: e.lien, credit: e.credit, ville: e.ville))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        case "schema":
            VStack(spacing: 4) {
                ForEach(Array((b.etapes ?? []).enumerated()), id: \.offset) { _, e in
                    if let boite = e.boite {
                        Text(boite).font(.custom("Georgia", size: 16)).foregroundStyle(Style.encre)
                            .multilineTextAlignment(.center).lineSpacing(4)
                            .frame(maxWidth: .infinity).padding(10)
                            .overlay(Rectangle().stroke(Style.encre, lineWidth: 1))
                    } else if let f = e.fleche {
                        Note(f).multilineTextAlignment(.center)
                    }
                }
                if let l = legende(b.commeElement) { Note(attribue: l).frame(maxWidth: .infinity, alignment: .leading) }
            }
        default:
            EmptyView()
        }
    }
}

struct VueRubrique: View {
    let r: Rubrique
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Note(r.etiquette)
                Text(r.titre).font(Style.titre()).foregroundStyle(Style.encre).fixedSize(horizontal: false, vertical: true)
            }
            ForEach(Array(r.blocs.enumerated()), id: \.offset) { _, b in VueBloc(b: b) }
            if let a = r.a_retenir {
                Text("À retenir").font(Style.sousTitre()).foregroundStyle(Style.encre).padding(.top, 8)
                Paragraphe(t: a)
            }
            if let s = ligneSources(r.sources, apres: r.note_sources) { Note(attribue: s) }
            Filet().padding(.top, 12)
        }
        .padding(.top, 30)
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
        .padding(.top, 30)
    }
}

struct Journal: View {
    @EnvironmentObject var depot: Depot

    var body: some View {
        Group {
            if let ed = depot.edition {
                contenu(ed)
            } else {
                VStack {
                    switch depot.etat {
                    case .erreur(let m): Note(m)
                    default: Note("Chargement de l'édition.")
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Style.fond)
        .environment(\.colorScheme, .light)
    }

    private func contenu(_ ed: Edition) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    entete(ed)
                    sommaire(ed, proxy: proxy)
                    ForEach(ed.rubriques) { r in VueRubrique(r: r).id(r.id) }
                    if let b = ed.breves, !b.isEmpty { VueBreves(breves: b).id("breves") }
                    pied(ed)
                }
                .frame(maxWidth: 640, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 32)
                .frame(maxWidth: .infinity)
                .id("haut")
            }
            .onChange(of: ed.date) { _ in proxy.scrollTo("haut", anchor: .top) }
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
            Note(ed.date_texte).padding(.top, 2).padding(.bottom, 18)
            if let une = ed.une {
                Paragraphe(t: une.texte).padding(.bottom, 6)
                if let s = ligneSources(une.sources) { Note(attribue: s) }
            }
            Filet().padding(.top, 22)
        }
    }

    private func sommaire(_ ed: Edition, proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Note("Sommaire").padding(.bottom, 8)
            ForEach(ed.rubriques) { r in
                Button { withAnimation { proxy.scrollTo(r.id, anchor: .top) } } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Note(r.etiquette)
                        Text(r.titre).font(Style.texte()).foregroundStyle(Style.encre)
                            .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            if ed.breves?.isEmpty == false {
                Button { withAnimation { proxy.scrollTo("breves", anchor: .top) } } label: {
                    Text("En bref").font(Style.texte()).foregroundStyle(Style.encre)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Filet().padding(.top, 12)
        }
        .padding(.top, 18)
    }

    private func pied(_ ed: Edition) -> some View {
        let jour = ed.date_texte.split(separator: " ").dropFirst().joined(separator: " ")
        return VStack(alignment: .leading, spacing: 6) {
            Note("Rédigé par Claude à partir de sources publiques consultées le \(jour).")
            switch depot.etat {
            case .horsLigne: Note("Hors ligne : dernière édition enregistrée sur cet appareil.")
            case .aJour: Note("Édition enregistrée pour la lecture hors ligne.")
            case .chargement: Note("Recherche de la nouvelle édition.")
            default: EmptyView()
            }
        }
        .padding(.top, 22)
    }
}
