import AppKit

let size = 1024
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 3, hasAlpha: false, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
NSColor(white: 0.055, alpha: 1).setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: size, height: size)).fill()
let ring = NSBezierPath(ovalIn: NSRect(x: 159, y: 159, width: 706, height: 706))
NSColor(white: 1, alpha: 0.16).setStroke()
ring.lineWidth = 2
ring.stroke()
let left = NSBezierPath()
left.move(to: NSPoint(x: 360, y: 298))
left.line(to: NSPoint(x: 360, y: 726))
left.move(to: NSPoint(x: 237, y: 596))
left.line(to: NSPoint(x: 360, y: 726))
left.line(to: NSPoint(x: 483, y: 596))
left.lineWidth = 49
left.lineCapStyle = .round
left.lineJoinStyle = .round
NSColor.white.setStroke()
left.stroke()
let right = NSBezierPath()
right.move(to: NSPoint(x: 664, y: 726))
right.line(to: NSPoint(x: 664, y: 298))
right.move(to: NSPoint(x: 541, y: 428))
right.line(to: NSPoint(x: 664, y: 298))
right.line(to: NSPoint(x: 787, y: 428))
right.lineWidth = 49
right.lineCapStyle = .round
right.lineJoinStyle = .round
NSColor(white: 0.65, alpha: 1).setStroke()
right.stroke()
NSGraphicsContext.restoreGraphicsState()
let data = bitmap.representation(using: .png, properties: [:])!
try data.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
