import AppKit

public enum SpriteSheetLoadingError: Error, LocalizedError {
    case unreadableImage(URL)
    case missingBitmap(URL)
    case cropFailed(frameIndex: Int)

    public var errorDescription: String? {
        switch self {
        case let .unreadableImage(url):
            "Could not read an image from \(url.lastPathComponent)."
        case let .missingBitmap(url):
            "Could not decode bitmap data from \(url.lastPathComponent)."
        case let .cropFailed(frameIndex):
            "Could not crop sprite frame \(frameIndex + 1)."
        }
    }
}

public struct SpriteSheetLoader {
    private let grid: SpriteSheetGrid

    public init(grid: SpriteSheetGrid) {
        self.grid = grid
    }

    public func loadFrames(from url: URL) throws -> [NSImage] {
        guard let image = NSImage(contentsOf: url) else {
            throw SpriteSheetLoadingError.unreadableImage(url)
        }

        var proposedRect = NSRect(origin: .zero, size: image.size)
        guard let bitmap = image.cgImage(
            forProposedRect: &proposedRect,
            context: nil,
            hints: nil
        ) else {
            throw SpriteSheetLoadingError.missingBitmap(url)
        }

        let frameRects = try grid.frames(
            imageWidth: bitmap.width,
            imageHeight: bitmap.height
        )

        return try frameRects.enumerated().map { frameIndex, frame in
            let cropRect = CGRect(
                x: CGFloat(frame.x),
                y: CGFloat(frame.y),
                width: CGFloat(frame.width),
                height: CGFloat(frame.height)
            )

            guard let cropped = bitmap.cropping(to: cropRect) else {
                throw SpriteSheetLoadingError.cropFailed(frameIndex: frameIndex)
            }

            return NSImage(
                cgImage: cropped,
                size: NSSize(
                    width: CGFloat(frame.width),
                    height: CGFloat(frame.height)
                )
            )
        }
    }
}
