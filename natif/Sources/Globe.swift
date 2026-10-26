import SwiftUI
import Foundation

/// Contours des terres (geo/terre.json, copié dans Contents/Resources) : liste d'anneaux,
/// chaque anneau = [lon, lat, lon, lat, ...] en degrés. Décodé une seule fois.
enum Terre {
    static let anneaux: [[Double]] = {
        guard let u = Bundle.main.url(forResource: "terre", withExtension: "json"),
              let d = try? Data(contentsOf: u),
              let a = try? JSONDecoder().decode([[Double]].self, from: d) else { return [] }
        return a
    }()
}

/// Angle du globe, intégré dans le temps : la vitesse change en douceur, l'angle ne saute jamais.
final class Rotation {
    static let vitesseRepos = 360.0 / 90 // degrés par seconde : un tour en 90 s
    static let vitesseCharge = 360.0 / 6 // un tour en 6 s pendant un chargement

    private(set) var angle = 0.0
    private var vitesse = Rotation.vitesseRepos
    private var precedent: Date?

    func avancer(_ date: Date, rapide: Bool) -> Double {
        let dt = precedent.map { min(0.1, max(0, date.timeIntervalSince($0))) } ?? 0
        precedent = date
        let cible = rapide ? Self.vitesseCharge : Self.vitesseRepos
        vitesse += (cible - vitesse) * min(1, dt * 2.5) // accélère et ralentit sans à-coup
        angle = (angle + vitesse * dt).truncatingRemainder(dividingBy: 360)
        return angle
    }
}

/// Globe du logo, dessiné en direct (même dessin que logo.py et globe.js de l'app web) :
/// disque blanc, graticule fin tous les 30°, terres pleines bordeaux, contour épais,
/// projection orthographique centrée à 22° de latitude ; la terre tourne d'ouest en est.
/// "Réduire les animations" : globe immobile.
struct Globe: View {
    let taille: CGFloat
    /// Chargement en cours : le globe accélère.
    let rapide: Bool

    @Environment(\.accessibilityReduceMotion) private var reduit
    @State private var rotation = Rotation()

    var body: some View {
        // 15 images/s au repos ; cadence de l'écran pendant un chargement.
        TimelineView(.animation(minimumInterval: rapide ? nil : 1.0 / 15, paused: reduit)) { contexte in
            let angle: Double = reduit ? 0 : rotation.avancer(contexte.date, rapide: rapide)
            Canvas { ctx, size in
                Globe.dessiner(ctx, size, angle: angle)
            }
        }
        .frame(width: taille, height: taille)
        .accessibilityHidden(true)
    }

    private static let lat0 = 22.0 * Double.pi / 180
    private static let lonDepart = 12.0

    static func dessiner(_ ctx: GraphicsContext, _ size: CGSize, angle: Double) {
        let s = Double(min(size.width, size.height))
        let r = s / 2 - max(1, s * 0.02)
        let cx = Double(size.width) / 2
        let cy = Double(size.height) / 2
        let disque = Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: 2 * r, height: 2 * r))
        let lon0 = (lonDepart - angle) * Double.pi / 180
        let sinLat0 = sin(lat0)
        let cosLat0 = cos(lat0)

        /// Projection orthographique ; un point caché est ramené sur le bord du disque.
        func projeter(_ lon: Double, _ lat: Double) -> (CGPoint, Bool) {
            let phi = lat * Double.pi / 180
            let dl = lon * Double.pi / 180 - lon0
            let cp = cos(phi)
            var x = cp * sin(dl)
            var y = cosLat0 * sin(phi) - sinLat0 * cp * cos(dl)
            let visible = sinLat0 * sin(phi) + cosLat0 * cp * cos(dl) > 0
            if !visible {
                let n = hypot(x, y)
                let d = n > 0 ? n : 1
                x /= d
                y /= d
            }
            return (CGPoint(x: cx + x * r, y: cy - y * r), visible)
        }

        var g = ctx
        g.fill(disque, with: .color(.white))
        g.clip(to: disque)

        // Graticule tous les 30 degrés : seuls les morceaux visibles sont tracés.
        var grille = Path()
        func tracer(_ points: [(Double, Double)]) {
            var enCours = false
            for (lon, lat) in points {
                let (p, v) = projeter(lon, lat)
                if !v { enCours = false; continue }
                if enCours { grille.addLine(to: p) } else { grille.move(to: p) }
                enCours = true
            }
        }
        for lat in stride(from: -60.0, through: 60.0, by: 30.0) {
            tracer(stride(from: -180.0, through: 180.0, by: 4.0).map { ($0, lat) })
        }
        for lon in stride(from: -180.0, to: 180.0, by: 30.0) {
            tracer(stride(from: -90.0, through: 90.0, by: 4.0).map { (lon, $0) })
        }
        g.stroke(grille, with: .color(Style.marque), lineWidth: max(0.5, s * 0.006))

        // Terres pleines, découpées au disque.
        for anneau in Terre.anneaux where anneau.count >= 6 {
            var p = Path()
            var vu = false
            var i = 0
            while i + 1 < anneau.count {
                let (pt, v) = projeter(anneau[i], anneau[i + 1])
                vu = vu || v
                if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
                i += 2
            }
            if !vu { continue }
            p.closeSubpath()
            g.fill(p, with: .color(Style.marque))
        }

        // Contour du disque, épais, par-dessus.
        ctx.stroke(disque, with: .color(Style.marque), lineWidth: max(1, s * 0.035))
    }
}
