import AppKit

public enum ProceduralImageFrameGeneratorError: Error, Equatable, LocalizedError {
    case unreadableImage(URL)
    case invalidSourceSize
    case frameRenderingFailed

    public var errorDescription: String? {
        switch self {
        case let .unreadableImage(url):
            "Could not read an image from \(url.lastPathComponent)."
        case .invalidSourceSize:
            "The source image must have a positive width and height."
        case .frameRenderingFailed:
            "Could not render the procedural animation frames."
        }
    }
}

public struct ProceduralImageFrameGenerator {
    private let outputHeight: CGFloat

    public init(outputHeight: CGFloat = 64) {
        self.outputHeight = max(outputHeight, 16)
    }

    public func frames(from url: URL) throws -> [NSImage] {
        guard let image = NSImage(contentsOf: url) else {
            throw ProceduralImageFrameGeneratorError.unreadableImage(url)
        }

        return try frames(from: image)
    }

    public func frames(from image: NSImage) throws -> [NSImage] {
        guard image.size.width > 0, image.size.height > 0 else {
            throw ProceduralImageFrameGeneratorError.invalidSourceSize
        }

        let layout = frameLayout(for: image.size)

        return try ProceduralRunCycle.frames.map { motion in
            try renderFrame(
                source: image,
                layout: layout,
                motion: motion
            )
        }
    }

    private func frameLayout(for sourceSize: NSSize) -> FrameLayout {
        let aspectRatio = sourceSize.width / sourceSize.height
        let maximumContentWidth = outputHeight * 1.6

        var contentHeight = outputHeight * 0.76
        var contentWidth = contentHeight * aspectRatio

        if contentWidth > maximumContentWidth {
            contentWidth = maximumContentWidth
            contentHeight = contentWidth / aspectRatio
        }

        let canvasWidth = max(contentWidth * 1.18, outputHeight * 0.75)

        return FrameLayout(
            canvasSize: NSSize(width: canvasWidth, height: outputHeight),
            contentSize: NSSize(width: contentWidth, height: contentHeight),
            baseline: outputHeight * 0.08
        )
    }

    private func renderFrame(
        source: NSImage,
        layout: FrameLayout,
        motion: ProceduralMotionFrame
    ) throws -> NSImage {
        let bitmap = try makeBitmap(size: layout.canvasSize)
        guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
            throw ProceduralImageFrameGeneratorError.frameRenderingFailed
        }

        let previousContext = NSGraphicsContext.current
        NSGraphicsContext.current = context
        context.cgContext.saveGState()
        defer {
            context.cgContext.restoreGState()
            NSGraphicsContext.current = previousContext
        }

        context.imageInterpolation = .high
        context.cgContext.clear(
            CGRect(origin: .zero, size: layout.canvasSize)
        )

        let drawSize = NSSize(
            width: layout.contentSize.width * motion.horizontalScale,
            height: layout.contentSize.height * motion.verticalScale
        )
        let anchorY = layout.baseline + layout.canvasSize.height * motion.lift
        let transform = NSAffineTransform()
        transform.translateX(by: layout.canvasSize.width / 2, yBy: anchorY)
        transform.rotate(byDegrees: motion.rotationDegrees)
        transform.translateX(by: -drawSize.width / 2, yBy: 0)
        transform.concat()

        source.draw(
            in: NSRect(origin: .zero, size: drawSize),
            from: .zero,
            operation: .sourceOver,
            fraction: 1,
            respectFlipped: true,
            hints: nil
        )

        let image = NSImage(size: layout.canvasSize)
        image.addRepresentation(bitmap)
        return image
    }

    private func makeBitmap(size: NSSize) throws -> NSBitmapImageRep {
        let width = max(Int(size.width.rounded(.up)), 1)
        let height = max(Int(size.height.rounded(.up)), 1)

        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            throw ProceduralImageFrameGeneratorError.frameRenderingFailed
        }

        bitmap.size = size
        return bitmap
    }
}

private struct FrameLayout {
    let canvasSize: NSSize
    let contentSize: NSSize
    let baseline: CGFloat
}
