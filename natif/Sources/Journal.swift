import SwiftUI

enum Vue: String { case jour, semaine }

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

extension View {
    /// Ancre de défilement (ScrollViewReader) qui signale aussi sa position au menu.
    func ancre(_ id: String) -> some View {
        self
            .background(GeometryReader { g in
                Color.clear.preference(key: PositionsRubriques.self, value: [id: g.frame(in: .named("lecture")).minY])
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
        .overlay { if let e = agrandie { zoom(e) } }
        .environment(\.textes, t)
        .environment(\.colorScheme, .light)
        .preferredColorScheme(.light)
        .environment(\.zoom, { e in withAnimation(.easeOut(duration: 0.15)) { agrandie = e } })
    }

    // MARK: - Menu latéral : édition, langue, rubriques

    private var menu: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                titreMenu(t.edition, premier: true)
                choix(t.quotidien, actif: vue == .jour) { changerVue(.jour) }
                choix(t.hebdomadaire, actif: vue == .semaine) { changerVue(.semaine) }
                titreMenu(t.langue)
                ForEach(Profil.allCases) { p in
                    choix(p.textes.nomLangue, actif: depot.profil == p) { depot.changerProfil(p) }
                }
                if !rubriques.isEmpty {
                    titreMenu(t.rubriques)
                    ForEach(rubriques) { r in
                        choix(r.nom, actif: active == r.id) { cible = r.id }
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

    private func choix(_ texte: String, actif: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(texte)
                .font(Style.serif(16, gras: actif))
                .foregroundStyle(actif ? Style.marque : Style.encre)
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

    /// Rubriques de la vue en cours, dans l'ordre de lecture.
    private var rubriques: [Rubrique] {
        switch vue {
        case .jour:
            guard let ed = depot.edition else { return [] }
            var l: [Rubrique] = []
            if ed.une != nil { l.append(Rubrique(id: "une", nom: t.actu)) }
            for (i, r) in ed.rubriques.enumerated() { l.append(Rubrique(id: "r\(i + 1)", nom: r.etiquette)) }
            if let b = ed.breves, !b.isEmpty { l.append(Rubrique(id: "breves", nom: t.enBref)) }
            return l
        case .semaine:
            guard let s = depot.semaine else { return [] }
            return s.sujets.enumerated().map { i, sujet in
                Rubrique(id: "s\(i + 1)", nom: sujet.etiquette.isEmpty ? sujet.titre : sujet.etiquette)
            }
        }
    }

    /// Rubrique en cours : la dernière dont le haut est passé au-dessus du premier quart de la colonne.
    private func majActive(_ positions: [String: CGFloat], hauteur: CGFloat) {
        let liste = rubriques
        var courante = liste.first?.id
        for r in liste {
            if let y = positions[r.id], y < hauteur / 4 { courante = r.id }
        }
        if courante != active { active = courante }
    }

    // MARK: - Colonne de lecture

    /// Identifie ce qui est affiché : un changement (nouvelle édition, autre langue, autre vue) remplace le contenu en fondu.
    private var cleContenu: String {
        vue == .jour
            ? "jour|\(depot.profil.rawValue)|\(depot.edition?.version ?? "")"
            : "semaine|\(depot.profil.rawValue)|\(depot.semaine?.version ?? "")"
    }

    private var lecture: some View {
        ZStack {
            Style.fond.ignoresSafeArea()
            GeometryReader { geo in
                let grand = geo.size.width >= 960
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
            Rectangle().fill(Color(white: 0.89)).frame(height: 1).padding(.top, 20)
            Note(ligneDate).padding(.top, 14)
        }
        .frame(maxWidth: Style.large)
        .padding(.horizontal, 24)
    }

    private var ligneDate: String {
        vue == .jour ? (depot.edition?.date_texte ?? "")
            : (depot.semaine?.date_texte_semaine ?? depot.semaine?.date_texte ?? "")
    }

    @ViewBuilder
    private var contenu: some View {
        switch vue {
        case .jour:
            if let ed = depot.edition {
                if let une = ed.une {
                    VStack(alignment: .leading, spacing: 10) {
                        NomRubrique(t: t.actu)
                        Paragraphe(t: une.texte, taille: 23)
                        if let s = ligneSources(une.sources, t) { Note(attribue: s) }
                    }
                    .padding(.top, 30)
                    .ancre("une")
                }
                ForEach(Array(ed.rubriques.enumerated()), id: \.offset) { i, r in
                    VueRubrique(r: r).ancre("r\(i + 1)")
                }
                if let b = ed.breves, !b.isEmpty { VueBreves(breves: b).ancre("breves") }
            } else {
                vide(t.videJour)
            }
        case .semaine:
            if let s = depot.semaine, !s.sujets.isEmpty {
                VueSemaine(semaine: s)
            } else {
                vide(t.videSemaine)
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

    private var pied: some View {
        VStack(alignment: .leading, spacing: 6) {
            if vue == .jour, let ed = depot.edition {
                // "Lundi 26 octobre 2026" -> "26 octobre 2026" ; "Segunda-feira, 26 de outubro de 2026" -> "26 de outubro de 2026"
                let jour = ed.date_texte.replacingOccurrences(of: #"^[^\s,]+,?\s+"#, with: "", options: .regularExpression)
                Note(t.piedJour(jour))
            } else if vue == .semaine, depot.semaine != nil {
                Note(t.piedSemaine)
            }
            switch depot.etat {
            case .horsLigne: Note(t.horsLigne)
            case .aJour: Note(t.enregistrees)
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
                if let l = legende(e, t) { Note(attribue: l, italique: true).frame(maxWidth: Style.colonne, alignment: .leading) }
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
