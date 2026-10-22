import Foundation

// Schéma de edition.json (voir outils/publier.py). Les champs inconnus sont ignorés.

struct Source: Codable, Hashable {
    let titre: String
    let url: String
}

struct Une: Codable {
    let texte: String
    let sources: [Source]?
}

struct Etape: Codable, Hashable {
    let boite: String?
    let fleche: String?
}

struct Element: Codable, Hashable {
    let type: String?
    let url: String?
    let src: String?
    let largeur: Double?
    let legende: String?
    let lien: String?
    let credit: Source?
    let ville: String?

    var estCarte: Bool { type == "carte" }
    /// Chemin publié : local au site (src) en priorité, sinon image libre externe (url).
    var chemin: String? { src ?? url }
}

struct Bloc: Codable, Hashable {
    let type: String
    let texte: String?
    let items: [String]?
    let elements: [Element]?
    let etapes: [Etape]?
    let legende: String?
    // Champs d'image ou de carte quand le bloc en est une
    let url: String?
    let src: String?
    let largeur: Double?
    let lien: String?
    let credit: Source?
    let ville: String?

    var commeElement: Element {
        Element(type: type, url: url, src: src, largeur: largeur, legende: legende, lien: lien, credit: credit, ville: ville)
    }
}

struct Rubrique: Codable, Hashable, Identifiable {
    let etiquette: String
    let titre: String
    let blocs: [Bloc]
    let a_retenir: String?
    let sources: [Source]?
    let note_sources: String?
    var id: String { etiquette + titre }
}

struct Breve: Codable, Hashable, Identifiable {
    let rubrique: String
    let items: [String]
    let sources: [Source]?
    var id: String { rubrique }
}

struct Edition: Codable {
    let date: String
    let date_texte: String
    let une: Une?
    let rubriques: [Rubrique]
    let breves: [Breve]?

    /// Tous les chemins d'images cités par l'édition.
    var images: [String] {
        var liste: [String] = []
        for r in rubriques {
            for b in r.blocs {
                if b.type == "duo" {
                    liste += (b.elements ?? []).compactMap(\.chemin)
                } else if let c = b.commeElement.chemin, b.type == "image" || b.type == "carte" {
                    liste.append(c)
                }
            }
        }
        return Array(Set(liste))
    }
}
