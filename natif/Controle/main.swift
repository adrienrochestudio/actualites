import Foundation

// Contrôle de lecture : décode les éditions publiées avec le modèle de l'app Mac (Sources/Modele.swift)
// et échoue si un bloc, une rubrique ou une question est ignoré, signe que le modèle n'a pas suivi le format.
// Usage : controle edition.json|hebdo.json ...

func compte(_ json: Any?, _ cle: String) -> Int { ((json as? [String: Any])?[cle] as? [Any])?.count ?? 0 }

var erreurs = 0
for chemin in CommandLine.arguments.dropFirst() {
    let data = try Data(contentsOf: URL(fileURLWithPath: chemin))
    let brut = try JSONSerialization.jsonObject(with: data)
    let liste = chemin.hasSuffix("hebdo.json") ? "sujets" : "rubriques"
    let articles = (brut as? [String: Any])?[liste] as? [Any] ?? []
    let blocsBruts = articles.reduce(0) { $0 + compte($1, "blocs") }
    do {
        let (lus, blocs, quiz): (Int, Int, Int)
        if liste == "sujets" {
            let s = try JSONDecoder().decode(Semaine.self, from: data)
            (lus, blocs, quiz) = (s.sujets.count, s.sujets.reduce(0) { $0 + $1.blocs.count }, 0)
        } else {
            let e = try JSONDecoder().decode(Edition.self, from: data)
            (lus, blocs, quiz) = (e.rubriques.count, e.rubriques.reduce(0) { $0 + $1.blocs.count }, e.quiz?.count ?? 0)
        }
        let quizBrut = liste == "rubriques" ? compte(brut, "quiz") : 0
        if lus != articles.count || blocs != blocsBruts || quiz != quizBrut {
            print("ÉCART \(chemin) : \(liste) \(lus)/\(articles.count), blocs \(blocs)/\(blocsBruts), quiz \(quiz)/\(quizBrut)")
            erreurs += 1
        } else {
            print("OK \(chemin) : \(lus) \(liste), \(blocs) blocs")
        }
    } catch {
        print("ILLISIBLE \(chemin) : \(error)")
        erreurs += 1
    }
}
exit(erreurs == 0 ? 0 : 1)
