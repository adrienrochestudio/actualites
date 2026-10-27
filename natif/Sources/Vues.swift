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
    /// Fond grisé des encarts : l'Actu, le chiffre du jour, le quiz.
    static let fondEncart = Color(red: 0xf3 / 255, green: 0xf2 / 255, blue: 0xef / 255)
    static let colonne: CGFloat = 680
    /// Largeur des graphiques larges sur grand écran : un peu plus que la colonne de texte.
    static let large: CGFloat = 920
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

private struct CleTextes: EnvironmentKey { static let defaultValue = Textes.fr }
extension EnvironmentValues {
    /// Textes de l'interface dans la langue du profil choisi.
    var textes: Textes {
        get { self[CleTextes.self] }
        set { self[CleTextes.self] = newValue }
    }
}

private struct CleGrandEcran: EnvironmentKey { static let defaultValue = false }
extension EnvironmentValues {
    /// Fenêtre d'au moins 960 pt : texte plus grand, graphiques larges débordant de la colonne, comme l'app web.
    var grandEcran: Bool {
        get { self[CleGrandEcran.self] }
        set { self[CleGrandEcran.self] = newValue }
    }
}

extension View {
    /// Encart sur fond grisé, angles droits, sans bordure ni ombre, sur toute la largeur de la colonne.
    func encart() -> some View {
        self
            .padding(.horizontal, 24)
            .padding(.vertical, 26)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Style.fondEncart)
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
    var gras = false
    var body: some View {
        Text(t).font(Style.serif(taille, gras: gras, italique: italique)).foregroundStyle(Style.encre).lineSpacing(taille * 0.6)
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

func ligneSources(_ toutes: [Source]?, _ t: Textes, apres: String? = nil) -> AttributedString? {
    // Un média n'apparaît qu'une fois, sous son nom court (lien vers le premier article cité).
    var vus = Set<String>()
    let sources = (toutes ?? []).filter { s in
        let nom = s.titre.trimmingCharacters(in: .whitespaces).lowercased()
        return !nom.isEmpty && vus.insert(nom).inserted
    }
    guard !sources.isEmpty else { return nil }
    var r = AttributedString(sources.count == 1 ? t.source : t.sources)
    for (i, s) in sources.enumerated() {
        if i > 0 { r += AttributedString(", ") }
        r += lien(s)
    }
    if let apres, !apres.isEmpty { r += AttributedString(". \(apres)") }
    return r
}

func legende(_ e: Element, _ t: Textes) -> AttributedString? {
    var r = AttributedString(e.legende ?? "")
    if let l = e.lien {
        if !r.characters.isEmpty { r += AttributedString(" ") }
        r += lien(Source(titre: "", url: l), texte: t.versionInteractive) + AttributedString(".")
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
    @Environment(\.textes) var t
    let element: Element

    var body: some View {
        if let chemin = element.chemin, depot.imageLocale(chemin) != nil {
            VStack(alignment: .leading, spacing: 7) {
                ImageLocale(chemin: chemin)
                    .frame(maxWidth: largeurMax, alignment: .leading)
                    .overlay(element.estCarte ? Rectangle().stroke(Color(white: 0.9), lineWidth: 1) : nil)
                    .contentShape(Rectangle())
                    .onTapGesture { zoom(element) }
                    .accessibilityLabel(element.estCarte ? "\(t.carte)\(element.ville ?? "")" : (element.legende ?? ""))
                    .accessibilityAddTraits(.isButton)
                if let l = legende(element, t) { Note(attribue: l, italique: true) }
            }
            .padding(.vertical, 6)
        }
    }

    @Environment(\.grandEcran) var grandEcran

    private var largeurMax: CGFloat? {
        if element.estPlan { return nil }
        if element.estPortrait { return Figure.largeurPortrait(grandEcran) }
        return element.estLarge ? nil : (grandEcran ? 420 : 360)
    }

    /// Largeur maximale d'un portrait ou d'un logo.
    static func largeurPortrait(_ grandEcran: Bool) -> CGFloat { grandEcran ? 200 : 170 }
}

struct VueBloc: View {
    @Environment(\.grandEcran) var grandEcran
    @Environment(\.textes) var t
    let b: Bloc
    var body: some View {
        switch b.type {
        case "p":
            Paragraphe(t: b.texte ?? "", taille: grandEcran ? 19 : 18)
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
            // Le portrait garde sa petite largeur ; l'autre élément prend le reste de la ligne.
            HStack(alignment: .top, spacing: 14) {
                ForEach(b.elements ?? [], id: \.self) { e in
                    if e.estPortrait {
                        Figure(element: e)
                            .frame(maxWidth: Figure.largeurPortrait(grandEcran), alignment: .leading)
                    } else {
                        Figure(element: Element(type: e.type, url: e.url, src: e.src, largeur: 1100,
                                                legende: e.legende, lien: e.lien, credit: e.credit, ville: e.ville, nature: e.nature))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        case "schema" where b.src != nil, "barres":
            // Dessinés à la publication (outils/schema.py) : une image large, agrandissable.
            Figure(element: Element(type: "image", url: nil, src: b.src, largeur: 1100, legende: b.legende,
                                    lien: b.lien, credit: b.credit, ville: nil, nature: "donnees"))
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
                if let l = legende(b.commeElement, t) { Note(attribue: l, italique: true).frame(maxWidth: .infinity, alignment: .leading) }
            }
            .padding(.vertical, 8)
        default:
            EmptyView()
        }
    }
}

/// Corps commun aux rubriques du jour et aux dossiers de la semaine.
struct CorpsArticle: View {
    @Environment(\.grandEcran) var grandEcran
    @Environment(\.textes) var t
    let a: Article
    /// Édition d'origine : présente, elle affiche le bouton Garder sous les sources.
    var provenance: Provenance? = nil
    /// Vue des articles gardés : seulement "Retirer".
    var seulRetirer = false
    /// Faux dans un encart : les graphiques larges restent dans l'encart.
    var deborder = true

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(a.blocs.enumerated()), id: \.offset) { _, b in
                if deborder && grandEcran && b.type == "image" && b.commeElement.estLarge {
                    // Graphique large : déborde de la colonne de part et d'autre.
                    VueBloc(b: b).padding(.horizontal, -(Style.large - Style.colonne) / 2)
                } else {
                    VueBloc(b: b)
                }
            }
            if let r = a.a_retenir {
                Text(t.aRetenir).font(Style.sousTitre()).foregroundStyle(Style.encre).padding(.top, 10)
                Paragraphe(t: r, taille: grandEcran ? 19 : 18)
            }
            if let s = ligneSources(a.sources, t, apres: a.note_sources) { Note(attribue: s).padding(.top, 6) }
            if let p = provenance { BoutonGarder(article: a, provenance: p, seulRetirer: seulRetirer) }
        }
    }
}

/// "Garder", puis "Gardé · Retirer" : petit bouton texte en fin d'article.
struct BoutonGarder: View {
    @EnvironmentObject var depot: Depot
    @Environment(\.textes) var t
    let article: Article
    let provenance: Provenance
    var seulRetirer = false

    var body: some View {
        let garde = seulRetirer || depot.estGarde(article, date: provenance.date)
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                if garde { depot.retirer(article, date: provenance.date) } else { depot.garder(article, provenance) }
            }
        } label: {
            libelle(garde)
                .font(Style.petit())
                .foregroundStyle(Style.note)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func libelle(_ garde: Bool) -> Text {
        if seulRetirer { return Text(t.retirer).underline() }
        if garde { return Text(t.garde + " · ") + Text(t.retirer).underline() }
        return Text(t.garder).underline()
    }
}

struct VueRubrique: View {
    @Environment(\.grandEcran) var grandEcran
    let r: Article
    var provenance: Provenance? = nil
    var body: some View {
        Group {
            if r.estChiffreDuJour {
                // Encart : le titre de la rubrique est le chiffre lui-même.
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        NomRubrique(t: r.etiquette)
                        Text(r.titre).font(Style.titre(grandEcran ? 54 : 44)).foregroundStyle(Style.encre).fixedSize(horizontal: false, vertical: true)
                    }
                    CorpsArticle(a: r, provenance: provenance, deborder: false)
                }
                .encart()
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        NomRubrique(t: r.etiquette)
                        Text(r.titre).font(Style.titre(grandEcran ? 36 : 31)).foregroundStyle(Style.encre).fixedSize(horizontal: false, vertical: true)
                    }
                    CorpsArticle(a: r, provenance: provenance)
                }
            }
        }
        .padding(.top, grandEcran ? 80 : 64)
    }
}

/// Article gardé : nom de rubrique suivi de la date de son édition, et bouton Retirer.
struct VueGarde: View {
    @Environment(\.grandEcran) var grandEcran
    @Environment(\.textes) var t
    let g: ArticleGarde

    var body: some View {
        let a = g.article
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                NomRubrique(t: [a.etiquette, g.dateCourte].filter { !$0.isEmpty }.joined(separator: " · "))
                Text(a.titre).font(Style.titre(grandEcran ? 36 : 31)).foregroundStyle(Style.encre).fixedSize(horizontal: false, vertical: true)
                if let ch = a.chapo { Paragraphe(t: ch, italique: true) }
            }
            if let c = a.couverture { Figure(element: c) }
            CorpsArticle(a: a, provenance: Provenance(date: g.date, dateTexte: g.date_texte), seulRetirer: true)
        }
        .padding(.top, grandEcran ? 80 : 64)
    }
}

struct VueBreves: View {
    @Environment(\.grandEcran) var grandEcran
    @Environment(\.textes) var t
    let breves: [Breve]

    /// Répartit les brèves en colonnes de longueur proche, dans l'ordre de lecture (comme des colonnes de journal).
    private func colonnes(_ n: Int) -> [[Breve]] {
        let poids = breves.map { $0.items.reduce(60) { $0 + $1.count } }
        let cible = Double(poids.reduce(0, +)) / Double(n)
        var res: [[Breve]] = [[]]
        var cumul = 0
        for (br, p) in zip(breves, poids) {
            if Double(cumul) >= cible * Double(res.count), res.count < n { res.append([]) }
            res[res.count - 1].append(br)
            cumul += p
        }
        return res
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(t.enBref).font(Style.titre()).foregroundStyle(Style.encre).padding(.bottom, 6)
            HStack(alignment: .top, spacing: 44) {
                ForEach(Array(colonnes(1).enumerated()), id: \.offset) { _, col in
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(col) { br in
                            VStack(alignment: .leading, spacing: 10) {
                                NomRubrique(t: br.rubrique)
                                ForEach(br.items, id: \.self) { Paragraphe(t: "- \($0)", taille: grandEcran ? 18 : 17) }
                                if let s = ligneSources(br.sources, t) { Note(attribue: s) }
                            }
                            .padding(.top, 22)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
        }
        .padding(.top, 72)
    }
}

/// Quiz de fin d'édition : un clic fige les choix, montre le bon et l'explication.
struct VueQuiz: View {
    @EnvironmentObject var depot: Depot
    @Environment(\.grandEcran) var grandEcran
    @Environment(\.textes) var t
    let questions: [Question]
    @State private var historiqueOuvert = false

    private static let filet = Color(red: 0xe3 / 255, green: 0xe3 / 255, blue: 0xe3 / 255)

    private func reponse(_ i: Int) -> Int {
        depot.reponsesQuiz.indices.contains(i) ? depot.reponsesQuiz[i] : -1
    }

    private var toutesRepondues: Bool {
        !questions.isEmpty && questions.indices.allSatisfy { reponse($0) >= 0 }
    }

    private var score: Int {
        questions.indices.filter { reponse($0) == questions[$0].reponse }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(t.quiz).font(Style.titre()).foregroundStyle(Style.encre).padding(.bottom, 6)
            ForEach(Array(questions.enumerated()), id: \.offset) { i, q in
                question(i, q).padding(.top, 22)
            }
            if toutesRepondues {
                Note(t.compte(score, questions.count)).padding(.top, 18)
                historique.padding(.top, 10)
            }
        }
        .encart()
        .padding(.top, 72)
    }

    /// Bouton qui déplie les scores des 30 derniers jours : "27 octobre 2026 · 7 sur 10", du plus récent au plus ancien.
    private var historique: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { historiqueOuvert.toggle() }
            } label: {
                Text(t.scoresTrenteJours).underline()
                    .font(Style.petit())
                    .foregroundStyle(Style.note)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if historiqueOuvert {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(depot.historiqueQuiz) { s in
                        Note("\(sansJourSemaine(s.date_texte)) · \(t.compte(s.justes, s.total))")
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    @ViewBuilder
    private func question(_ i: Int, _ q: Question) -> some View {
        let taille: CGFloat = grandEcran ? 19 : 18
        let r = reponse(i)
        VStack(alignment: .leading, spacing: 0) {
            Paragraphe(t: q.question, taille: taille, gras: true).padding(.bottom, 8)
            ForEach(Array(q.choix.enumerated()), id: \.offset) { j, c in
                if j > 0 { Rectangle().fill(Self.filet).frame(height: 1) }
                Button {
                    guard r < 0 else { return }
                    withAnimation(.easeOut(duration: 0.15)) { depot.repondre(i, j) }
                } label: {
                    choix(j, c, bon: r >= 0 && j == q.reponse, barre: r == j && j != q.reponse, taille: taille)
                }
                .buttonStyle(.plain)
            }
            if r >= 0 {
                Text(r == q.reponse ? t.exact : t.non).font(Style.serif(taille, gras: true)).foregroundStyle(Style.encre)
                    .padding(.top, 12)
                if let e = q.explication, !e.isEmpty { Paragraphe(t: e, taille: taille).padding(.top, 6) }
            }
        }
    }

    private func choix(_ j: Int, _ c: String, bon: Bool, barre: Bool, taille: CGFloat) -> some View {
        Text("\(Self.lettre(j)). \(c)")
            .strikethrough(barre)
            .font(Style.serif(taille, gras: bon))
            .foregroundStyle(bon ? Style.marque : Style.encre)
            .multilineTextAlignment(.leading)
            .lineSpacing(taille * 0.3)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
    }

    private static func lettre(_ j: Int) -> String {
        String(Character(Unicode.Scalar(UInt8(65 + min(j, 25)))))
    }
}

/// Dossiers de la semaine : repliés, chacun représenté par son image, ouverts au clic.
struct VueSemaine: View {
    @Environment(\.grandEcran) var grandEcran
    @Environment(\.textes) var t
    let semaine: Semaine
    @State private var ouverts: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(t.dossiersSemaine).font(Style.titre()).foregroundStyle(Style.encre)
                .padding(.top, 36).padding(.bottom, 8)
            ForEach(Array(semaine.sujets.enumerated()), id: \.offset) { i, s in
                dossier(s).ancre("s\(i + 1)")
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
                HStack(alignment: .top, spacing: grandEcran ? 28 : 20) {
                    if let c = s.couverture?.chemin {
                        ImageLocale(chemin: c, remplir: true)
                            .frame(width: grandEcran ? 320 : 300, height: grandEcran ? 240 : 225)
                            .clipped()
                            .background(Color(white: 0.93))
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        NomRubrique(t: s.etiquette)
                        Text(s.titre).font(Style.titre()).foregroundStyle(Style.encre)
                            .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                        if let ch = s.chapo { Paragraphe(t: ch, italique: true) }
                        Text(ouvert ? t.replier : t.lireDossier).font(Style.petit()).foregroundStyle(Style.note)
                            .underline(!ouvert)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(ouvert ? t.replierLeDossier : t.ouvrirLeDossier)

            if ouvert {
                if let c = s.couverture, let l = legende(c, t) { Note(attribue: l, italique: true) }
                CorpsArticle(a: s, provenance: Provenance(date: semaine.date, dateTexte: semaine.date_texte))
            }
        }
        .padding(.vertical, 24)
    }
}

