import AppKit

// Gera o iconset do app: quadrado arredondado com gradiente e um glifo SF Symbol.
// Roda como script no build, para não versionar binários de imagem.
func render(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else { image.unlockFocus(); return image }

    // macOS aplica sua própria máscara; deixamos margem para o ícone não encostar na borda.
    let inset = size * 0.06
    let rect = CGRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
    let radius = rect.width * 0.225

    let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
    ctx.saveGState()
    ctx.addPath(path)
    ctx.clip()

    let colors = [
        NSColor(srgbRed: 0.16, green: 0.55, blue: 0.98, alpha: 1).cgColor,
        NSColor(srgbRed: 0.11, green: 0.75, blue: 0.62, alpha: 1).cgColor,
    ]
    if let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                             colors: colors as CFArray, locations: [0, 1]) {
        ctx.drawLinearGradient(grad,
                               start: CGPoint(x: rect.minX, y: rect.maxY),
                               end: CGPoint(x: rect.maxX, y: rect.minY),
                               options: [])
    }
    ctx.restoreGState()

    let glyphSize = size * 0.52
    let config = NSImage.SymbolConfiguration(pointSize: glyphSize, weight: .semibold)
    if let symbol = NSImage(systemSymbolName: "sparkles", accessibilityDescription: nil)?
        .withSymbolConfiguration(config) {
        let tinted = NSImage(size: symbol.size)
        tinted.lockFocus()
        NSColor.white.set()
        let r = NSRect(origin: .zero, size: symbol.size)
        symbol.draw(in: r)
        r.fill(using: .sourceAtop)
        tinted.unlockFocus()

        let box = NSRect(x: (size - tinted.size.width) / 2,
                         y: (size - tinted.size.height) / 2,
                         width: tinted.size.width, height: tinted.size.height)
        tinted.draw(in: box)
    }

    image.unlockFocus()
    return image
}

func writePNG(_ image: NSImage, to url: URL) throws {
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let data = rep.representation(using: .png, properties: [:])
    else { throw NSError(domain: "icon", code: 1) }
    try data.write(to: url)
}

let out = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Faxina.iconset")
try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let px = CGFloat(base * scale)
        let name = scale == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
        try writePNG(render(size: px), to: out.appendingPathComponent(name))
    }
}
print("iconset em \(out.path)")
