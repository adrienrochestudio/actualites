import Foundation

// Schémas de edition.json et hebdo.json (voir outils/publier.py). Les champs inconnus sont ignorés.
// Publiés par profil : {profil}/edition/edition.json et {profil}/hebdo/hebdo.json ; "langue" ("fr" ou "pt") est facultatif.

struct Source: Codable, Hashable {
    let titre: String
    let url: String
}

struct Une: Codable {
    let texte: String
    /// Portrait, logo ou photo d'une personne ou d'une organisation citée (facultatif).
    let image: Element?
    let sources: [Source]?
}

struct Etape: Codable, Hashable {
    let boite: String?
    let fleche: String?
}

/// Image, carte ou élément de duo.
struct Element: Codable, Hashable {
    let type: String?
    let url: String?
    let src: String?
    let largeur: Double?
    let legende: String?
    let lien: String?
    let credit: Source?
    let ville: String?
    let nature: String?

    var estCarte: Bool { type == "carte" }
    /// Chemin publié : copie du site (src) en priorité, sinon image libre externe (url).
    var chemin: String? { src ?? url }
    /// Graphique ou photo de paysage : toute la largeur. Portrait : petit.
    var estLarge: Bool { !estCarte && (largeur ?? 552) >= 500 }
}

struct Bloc: Codable, Hashable {
    let type: String
    let texte: String?
    let items: [String]?
    let elements: [Element]?
    let etapes: [Etape]?
    let legende: String?
    let url: String?
    let src: String?
    let largeur: Double?
    let lien: String?
    let credit: Source?
    let ville: String?
    let nature: String?

    var commeElement: Element {
        Element(type: type, url: url, src: src, largeur: largeur, legende: legende, lien: lien, credit: credit, ville: ville, nature: nature)
    }
}

/// Rubrique du jour ou dossier de la semaine (chapo et couverture : dossiers seulement).
struct Article: Codable, Hashable, Identifiable {
    let etiquette: String
    let titre: String
    let chapo: String?
    let couverture: Element?
    let blocs: [Bloc]
    let a_retenir: String?
    let sources: [Source]?
    let note_sources: String?
    var id: String { etiquette + titre }

    var images: [String] {
        var liste = couverture?.chemin.map { [$0] } ?? []
        for b in blocs {
            if b.type == "duo" {
                liste += (b.elements ?? []).compactMap(\.chemin)
            } else if ["image", "carte", "schema", "barres"].contains(b.type), let c = b.commeElement.chemin {
                liste.append(c)
            }
        }
        return liste
    }
}

struct Breve: Codable, Hashable, Identifiable {
    let rubrique: String
    let items: [String]
    let sources: [Source]?
    var id: String { rubrique }
}

/// Question du quiz de fin d'édition ; `reponse` est l'index (à partir de 0) du bon choix.
struct Question: Codable, Hashable {
    let question: String
    let choix: [String]
    let reponse: Int
    let explication: String?
}

struct Edition: Codable {
    let date: String
    let publie: String?
    let langue: String?
    let date_texte: String
    let une: Une?
    let rubriques: [Article]
    let breves: [Breve]?
    let quiz: [Question]?
}

struct Semaine: Codable {
    let date: String
    let publie: String?
    let langue: String?
    let date_texte: String
    let date_texte_semaine: String?
    let sujets: [Article]
}

/// Ce que l'app sait télécharger et garder : l'édition du jour ou celle de la semaine.
protocol Publication: Codable {
    var date: String { get }
    var publie: String? { get }
    var images: [String] { get }
}

extension Publication {
    /// Identifie une publication : date et horodatage de publication (une édition corrigée le même jour compte comme nouvelle).
    var version: String { date + "|" + (publie ?? "") }
}

extension Edition: Publication {
    var images: [String] { Array(Set(rubriques.flatMap(\.images) + (une?.image?.chemin.map { [$0] } ?? []))) }
}

/// Édition d'où vient un article : date ISO et date en toutes lettres.
struct Provenance: Hashable {
    let date: String
    let dateTexte: String
}

/// Article gardé par le lecteur : enregistré complet, avec la date de son édition et le profil,
/// dans Application Support/Actualites/gardes/{profil}/gardes.json.
struct ArticleGarde: Codable, Hashable, Identifiable {
    let article: Article
    let date: String
    let date_texte: String
    let profil: String
    var id: String { Self.cle(profil, date, article) }

    static func cle(_ profil: String, _ date: String, _ article: Article) -> String {
        profil + "|" + date + "|" + article.id
    }

    /// "27 octobre 2026" : date en toutes lettres sans le jour de la semaine.
    var dateCourte: String {
        guard let i = date_texte.firstIndex(where: \.isNumber) else { return date_texte }
        return String(date_texte[i...])
    }
}

extension Semaine: Publication {
    var images: [String] { Array(Set(sujets.flatMap(\.images))) }
}
