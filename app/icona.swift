// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 Edoardo Maria Montagna
//
// Disegna l'icona dell'app (sistema solare stilizzato) e crea app/AppIcon.icns.
// Uso: swift app/icona.swift      (serve solo se si vuole modificare l'icona)
import AppKit

// Tutte le misure sono pensate su una tela di 1024 punti, come la griglia delle icone macOS
func drawIcon(size: Int) -> CGImage {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                        space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)
    let small = size <= 32 // alle dimensioni minime si tengono solo gli elementi essenziali
    let color = { (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) in CGColor(srgbRed: r, green: g, blue: b, alpha: a) }

    // Fondo: quadrato arrotondato con ombra, come le icone di sistema
    let tile = CGPath(roundedRect: CGRect(x: 100, y: 100, width: 824, height: 824), cornerWidth: 185, cornerHeight: 185, transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: color(0, 0, 0, 0.45))
    ctx.addPath(tile)
    ctx.setFillColor(color(0.03, 0.04, 0.1, 1))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(tile)
    ctx.clip()
    let sky = CGGradient(colorsSpace: space, colors: [color(0.13, 0.17, 0.38, 1), color(0.03, 0.04, 0.11, 1)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(sky, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])

    let center = CGPoint(x: 512, y: 500)

    // Stelle (posizioni fisse, generate con un pseudo-casuale ripetibile)
    if !small {
        var seed: UInt64 = 7
        func rnd() -> CGFloat {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return CGFloat(seed >> 33) / CGFloat(UInt64(1) << 31)
        }
        for _ in 0..<70 {
            let p = CGPoint(x: 110 + rnd() * 804, y: 110 + rnd() * 804)
            let r = 1.2 + pow(rnd(), 4) * 3.5
            ctx.setFillColor(color(0.9, 0.93, 1, 0.25 + rnd() * 0.6))
            ctx.fillEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r))
        }
    }

    // Orbite viste in prospettiva: ellissi schiacciate e leggermente ruotate
    let tilt: CGFloat = -0.32
    let squash: CGFloat = 0.42
    let orbits: [CGFloat] = small ? [170, 300] : [150, 245, 345]
    func onOrbit(_ radius: CGFloat, _ angleDeg: CGFloat) -> CGPoint {
        let a = angleDeg * .pi / 180
        let x = cos(a) * radius, y = sin(a) * radius * squash
        return CGPoint(x: center.x + x * cos(tilt) - y * sin(tilt), y: center.y + x * sin(tilt) + y * cos(tilt))
    }
    ctx.setLineWidth(small ? 22 : 5)
    ctx.setStrokeColor(color(0.72, 0.8, 1, small ? 0.55 : 0.4))
    for radius in orbits {
        ctx.saveGState()
        ctx.translateBy(x: center.x, y: center.y)
        ctx.rotate(by: tilt)
        ctx.strokeEllipse(in: CGRect(x: -radius, y: -radius * squash, width: 2 * radius, height: 2 * radius * squash))
        ctx.restoreGState()
    }

    // Sole con alone
    let glow = CGGradient(colorsSpace: space, colors: [color(1, 0.78, 0.35, 0.55), color(1, 0.6, 0.2, 0)] as CFArray, locations: [0, 1])!
    ctx.drawRadialGradient(glow, startCenter: center, startRadius: 0, endCenter: center, endRadius: small ? 230 : 210, options: [])
    let sun = CGGradient(colorsSpace: space, colors: [color(1, 0.98, 0.88, 1), color(1, 0.8, 0.32, 1), color(1, 0.55, 0.15, 1)] as CFArray, locations: [0, 0.55, 1])!
    let sunR: CGFloat = small ? 120 : 82
    ctx.saveGState()
    ctx.addEllipse(in: CGRect(x: center.x - sunR, y: center.y - sunR, width: 2 * sunR, height: 2 * sunR))
    ctx.clip()
    ctx.drawRadialGradient(sun, startCenter: CGPoint(x: center.x - sunR * 0.3, y: center.y + sunR * 0.3), startRadius: 0, endCenter: center, endRadius: sunR, options: [.drawsAfterEndLocation])
    ctx.restoreGState()

    // Pianeta illuminato dal lato rivolto al Sole
    func planet(at p: CGPoint, radius r: CGFloat, light: CGColor, dark: CGColor) {
        let dx = center.x - p.x, dy = center.y - p.y
        let len = max(hypot(dx, dy), 1)
        let lit = CGPoint(x: p.x + dx / len * r * 0.45, y: p.y + dy / len * r * 0.45)
        let shade = CGGradient(colorsSpace: space, colors: [light, dark] as CFArray, locations: [0, 1])!
        ctx.saveGState()
        ctx.addEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r))
        ctx.clip()
        ctx.drawRadialGradient(shade, startCenter: lit, startRadius: 0, endCenter: p, endRadius: r * 1.25, options: [.drawsAfterEndLocation])
        ctx.restoreGState()
    }

    if small {
        planet(at: onOrbit(300, 205), radius: 62, light: color(0.55, 0.8, 1, 1), dark: color(0.08, 0.25, 0.6, 1))
    } else {
        planet(at: onOrbit(150, 160), radius: 22, light: color(1, 0.92, 0.75, 1), dark: color(0.55, 0.45, 0.3, 1))
        // Terra con la Luna
        let earth = onOrbit(245, 200)
        planet(at: earth, radius: 34, light: color(0.55, 0.8, 1, 1), dark: color(0.06, 0.2, 0.5, 1))
        planet(at: CGPoint(x: earth.x - 50, y: earth.y + 34), radius: 10, light: color(0.95, 0.95, 0.92, 1), dark: color(0.4, 0.4, 0.42, 1))
        // Pianeta con anelli
        let giant = onOrbit(345, 30)
        ctx.saveGState()
        ctx.translateBy(x: giant.x, y: giant.y)
        ctx.rotate(by: -0.35)
        ctx.setLineWidth(9)
        ctx.setStrokeColor(color(0.95, 0.85, 0.65, 0.8))
        ctx.strokeEllipse(in: CGRect(x: -78, y: -20, width: 156, height: 40))
        ctx.restoreGState()
        planet(at: giant, radius: 44, light: color(1, 0.88, 0.62, 1), dark: color(0.6, 0.4, 0.22, 1))
        // la parte anteriore dell'anello passa davanti al pianeta
        ctx.saveGState()
        ctx.translateBy(x: giant.x, y: giant.y)
        ctx.rotate(by: -0.35)
        ctx.addRect(CGRect(x: -90, y: -40, width: 180, height: 40))
        ctx.clip()
        ctx.setLineWidth(9)
        ctx.setStrokeColor(color(0.95, 0.85, 0.65, 0.9))
        ctx.strokeEllipse(in: CGRect(x: -78, y: -20, width: 156, height: 40))
        ctx.restoreGState()
    }
    ctx.restoreGState()
    return ctx.makeImage()!
}

func writePNG(_ image: CGImage, to url: URL) {
    let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
}

let appDir = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    writePNG(drawIcon(size: base), to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    writePNG(drawIcon(size: base * 2), to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
writePNG(drawIcon(size: 1024), to: appDir.appendingPathComponent("AppIcon-1024.png"))

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", appDir.appendingPathComponent("AppIcon.icns").path]
try! iconutil.run()
iconutil.waitUntilExit()
print(iconutil.terminationStatus == 0 ? "Creata \(appDir.path)/AppIcon.icns" : "iconutil non riuscito")
