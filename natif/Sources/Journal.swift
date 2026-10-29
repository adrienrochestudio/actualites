import SwiftUI

/// Quotidien, Hebdomadaire, ou articles gardés (aucun onglet actif).
enum Vue: String { case jour, semaine, gardes }

/// Entrée de la liste des rubriques du menu ; `id` est l'ancre de défilement dans la colonne de lecture.
struct Rubrique: Identifiable, Hashable {
    let id: String
    let nom: String
}

/// Position du haut de chaque rubrique dans la colonne de lecture, pour savoir laquelle est en cours.
struct PositionsRubriques: PreferenceKey {
    static let defaultValue: [String: CGFloat] = [:]
    static func reduce(value: inout [String: CGFloat], nextValue: () -> [String: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

/// Position du bas de chaque rubrique : passé dans la fenêtre de lecture, la rubrique est lue.
struct BasRubriques: PreferenceKey {
    static let defaultValue: [String: CGFloat] = [:]
    static func reduce(value: inout [String: CGFloat], nextValue: () -> [String: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

extension View {
    /// Ancre de défilement (ScrollViewReader) qui signale aussi sa position (haut et bas) au menu.
    func ancre(_ id: String) -> some View {
        self
            .background(GeometryReader { g in
                let cadre = g.frame(in: .named("lecture"))
                Color.clear
                    .preference(key: PositionsRubriques.self, value: [id: cadre.minY])
                    .preference(key: BasRubriques.self, value: [id: cadre.maxY])
            })
            .id(id)
    }
}

struct Journal: View {
    @EnvironmentObject var depot: Depot
    @Environment(\.accessibilityReduceMotion) private var reduit
    @State private var agrandie: Element?
    @AppStorage("vue") private var vue: Vue = .jour
    @State private var colonnes: NavigationSplitViewVisibility = .all
    /// Rubrique demandée dans le menu (défilement), et rubrique en cours de lecture.
    @State private var cible: String?
    @State private var active: String?

    private var t: Textes { depot.profil.textes }

    var body: some View {
        NavigationSplitView(columnVisibility: $colonnes) {
            menu
                .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 300)
        } detail: {
            lecture
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            Task { await depot.actualiser(force: true) }
                        } label: {
                            Text(t.actualiser).font(Style.serif(14))
                        }
                        .help(t.actualiser + " (⌘R)")
                        .disabled(depot.enChargement)
                    }
                }
        }
        .overlay {
            if let e = agrandie {
                VueZoom(e: e, fermer: { withAnimation(.easeOut(duration: 0.15)) { agrandie = nil } })
                    .id(e)
                    .transition(.opacity)
            }
        }
        .environment(\.textes, t)
        .environment(\.colorScheme, .light)
        .preferredColorScheme(.light)
        .environment(\.zoom, { e in withAnimation(.easeOut(duration: 0.15)) { agrandie = e } })
    }

    // MARK: - Menu latéral : édition, langue, rubriques

    private var menu: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                titreMenu(t.langue, premier: true)
                ForEach(Profil.allCases) { p in
                    choix(p.textes.nomLangue, actif: depot.profil == p) { depot.changerProfil(p) }
                }
                if !rubriques.isEmpty {
                    titreMenu(t.rubriques)
                    ForEach(rubriques) { r in
                        choix(r.nom, actif: active == r.id, lu: vue == .jour && depot.lus.contains(r.id)) { cible = r.id }
                    }
                }
                if !depot.gardes.isEmpty {
                    titreMenu(t.gardes)
                    ForEach(depot.gardes) { g in
                        choix(g.article.titre, actif: vue == .gardes && active == ancreGarde(g)) { ouvrirGarde(g) }
                    }
                }
            }
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Style.fond)
    }

    private func titreMenu(_ texte: String, premier: Bool = false) -> some View {
        Text(texte)
            .font(Style.serif(13))
            .foregroundStyle(Style.note)
            .padding(.horizontal, 18)
            .padding(.top, premier ? 0 : 20)
            .padding(.bottom, 4)
            .accessibilityAddTraits(.isHeader)
    }

    /// Entrée du menu : active en bordeaux, lue en gris, sinon en encre.
    private func choix(_ texte: String, actif: Bool, lu: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(texte)
                .font(Style.serif(16, gras: actif))
                .foregroundStyle(actif ? Style.marque : (lu ? Style.note : Style.encre))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: 30, alignment: .leading)
                .padding(.horizontal, 18)
                .padding(.vertical, 3)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(actif ? .isSelected : [])
    }

    private func changerVue(_ v: Vue) {
        guard v != vue else { return }
        vue = v
        active = nil
    }

    private func ancreGarde(_ g: ArticleGarde) -> String { "g|" + g.id }

    /// Affiche la vue des articles gardés, puis va à l'article choisi.
    private func ouvrirGarde(_ g: ArticleGarde) {
        let id = ancreGarde(g)
        if vue == .gardes {
            cible = id
        } else {
            changerVue(.gardes)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { cible = id }
        }
    }

    /// Rubriques de la vue en cours, dans l'ordre de lecture.
    private var rubriques: [Rubrique] {
        switch vue {
        case .jour:
            guard let ed = depot.edition else { return [] }
            var l: [Rubrique] = []
            if ed.une != nil { l.append(Rubrique(id: "une", nom: t.actu)) }
            for (i, r) in ed.rubriques.enumerated() { l.append(Rubrique(id: "r\(i + 1)", nom: r.etiquette)) }
            if let b = ed.breves, !b.isEmpty { l.append(Rubrique(id: "breves", nom: t.enBref)) }
            if let q = ed.quiz, !q.isEmpty { l.append(Rubrique(id: "quiz", nom: t.quiz)) }
            return l
        case .semaine:
            guard let s = depot.semaine else { return [] }
            return s.sujets.enumerated().map { i, sujet in
                Rubrique(id: "s\(i + 1)", nom: sujet.etiquette.isEmpty ? sujet.titre : sujet.etiquette)
            }
        case .gardes:
            return []
        }
    }

    /// Rubrique en cours : la dernière dont le haut est passé au-dessus du premier quart de la colonne.
    private func majActive(_ positions: [String: CGFloat], hauteur: CGFloat) {
        let liste = vue == .gardes ? depot.gardes.map { ancreGarde($0) } : rubriques.map(\.id)
        var courante = liste.first
        for id in liste {
            if let y = positions[id], y < hauteur / 4 { courante = id }
        }
        if courante != active { active = courante }
    }

    /// Quotidien : une rubrique est lue quand le bas de son contenu est passé dans la fenêtre de lecture.
    private func majLus(_ bas: [String: CGFloat], hauteur: CGFloat) {
        guard vue == .jour else { return }
        for r in rubriques where !depot.lus.contains(r.id) {
            if let y = bas[r.id], y <= hauteur { depot.marquerLu(r.id) }
        }
    }

    // MARK: - Colonne de lecture

    /// Identifie ce qui est affiché : un changement (nouvelle édition, autre langue, autre vue) remplace le contenu en fondu.
    private var cleContenu: String {
        switch vue {
        case .jour: return "jour|\(depot.profil.rawValue)|\(depot.edition?.version ?? "")"
        case .semaine: return "semaine|\(depot.profil.rawValue)|\(depot.semaine?.version ?? "")"
        case .gardes: return "gardes|\(depot.profil.rawValue)"
        }
    }

    private var lecture: some View {
        ZStack {
            Style.fond.ignoresSafeArea()
            GeometryReader { geo in
                let grand = geo.size.width >= 960
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 0) {
                            manchette.padding(.horizontal, grand ? Style.marge : 24)
                            VStack(alignment: .leading, spacing: 0) {
                                contenu
                                pied
                            }
                            // Lecture sur presque toute la largeur de la fenêtre, marges latérales seulement.
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, grand ? Style.marge : 24)
                            .padding(.bottom, 56)
                            .id(cleContenu)
                            .transition(.opacity)
                        }
                        .frame(maxWidth: .infinity)
                        .id("haut")
                    }
                    .coordinateSpace(name: "lecture")
                    .onPreferenceChange(PositionsRubriques.self) { positions in
                        let hauteur = geo.size.height
                        Task { @MainActor in majActive(positions, hauteur: hauteur) }
                    }
                    .onPreferenceChange(BasRubriques.self) { bas in
                        let hauteur = geo.size.height
                        Task { @MainActor in majLus(bas, hauteur: hauteur) }
                    }
                    .onChange(of: vue) { _ in proxy.scrollTo("haut", anchor: .top) }
                    .onChange(of: depot.profil) { _ in proxy.scrollTo("haut", anchor: .top) }
                    .onChange(of: depot.edition?.version) { _ in
                        if vue == .jour { proxy.scrollTo("haut", anchor: .top) }
                    }
                    .onChange(of: depot.semaine?.version) { _ in
                        if vue == .semaine { proxy.scrollTo("haut", anchor: .top) }
                    }
                    .onChange(of: cible) { c in
                        guard let c else { return }
                        if reduit {
                            proxy.scrollTo(c, anchor: .top)
                        } else {
                            withAnimation(.easeInOut(duration: 0.35)) { proxy.scrollTo(c, anchor: .top) }
                        }
                        cible = nil
                    }
                }
                .environment(\.grandEcran, grand)
            }
        }
    }

    /// Globe et titre du journal centrés, filet, date.
    private var manchette: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Globe(taille: 42, rapide: depot.enChargement)
                Text("Actualités").font(Style.manchette()).foregroundStyle(Style.encre)
            }
            .padding(.top, 40)
            // Onglets Quotidien / Hebdomadaire, comme l'app web.
            HStack(spacing: 32) {
                onglet(t.quotidien, .jour)
                onglet(t.hebdomadaire, .semaine)
            }
            .padding(.top, 16)
            Rectangle().fill(Color(white: 0.89)).frame(height: 1)
            Note(ligneDate).padding(.top, 14)
        }
        .frame(maxWidth: .infinity)
    }

    private func onglet(_ texte: String, _ v: Vue) -> some View {
        Button { changerVue(v) } label: {
            VStack(spacing: 8) {
                Text(texte).font(Style.serif(16, gras: vue == v)).foregroundStyle(vue == v ? Style.encre : Style.note)
                Rectangle().fill(vue == v ? Style.encre : Color.clear).frame(height: 2)
            }
            .fixedSize()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(vue == v ? .isSelected : [])
    }

    private var ligneDate: String {
        switch vue {
        case .jour: return depot.edition?.date_texte ?? ""
        case .semaine: return depot.semaine?.date_texte_semaine ?? depot.semaine?.date_texte ?? ""
        case .gardes: return t.articlesGardes
        }
    }

    @ViewBuilder
    private var contenu: some View {
        switch vue {
        case .jour:
            if let ed = depot.edition {
                if let une = ed.une {
                    VStack(alignment: .leading, spacing: 10) {
                        NomRubrique(t: t.actu)
                        Paragraphe(t: une.texte, taille: 18)
                        if let i = une.image {
                            // Portrait ou logo : petit par défaut, comme dans l'app web.
                            Figure(element: Element(type: i.type, url: i.url, src: i.src, largeur: i.largeur ?? 360,
                                                    legende: i.legende, lien: i.lien, credit: i.credit, ville: i.ville, nature: i.nature))
                        }
                        if let s = ligneSources(une.sources, t) { Note(attribue: s) }
                    }
                    .encart()
                    .padding(.top, 30)
                    .ancre("une")
                }
                ForEach(Array(ed.rubriques.enumerated()), id: \.offset) { i, r in
                    VueRubrique(r: r, provenance: Provenance(date: ed.date, dateTexte: ed.date_texte)).ancre("r\(i + 1)")
                }
                if let b = ed.breves, !b.isEmpty { VueBreves(breves: b).ancre("breves") }
                if let q = ed.quiz, !q.isEmpty { VueQuiz(questions: q).ancre("quiz") }
            } else {
                vide(t.videJour)
            }
        case .semaine:
            if let s = depot.semaine, !s.sujets.isEmpty {
                VueSemaine(semaine: s)
            } else {
                vide(t.videSemaine)
            }
        case .gardes:
            if depot.gardes.isEmpty {
                Note(t.aucunGarde).padding(.top, 28)
            } else {
                ForEach(depot.gardes) { g in
                    VueGarde(g: g).ancre(ancreGarde(g))
                }
            }
        }
    }

    private func vide(_ texte: String) -> some View {
        VStack(alignment: .leading) {
            switch depot.etat {
            case .chargement: Note(t.chargement)
            case .rien: Note(t.rien)
            default: Note(texte)
            }
        }
        .padding(.top, 28)
    }

    /// Marge de fin de lecture (plus de mention de rédaction ni d'état hors ligne).
    private var pied: some View {
        Color.clear.frame(height: 64)
    }
}
