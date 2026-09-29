import AppKit

enum DecodedAnimationPixelCounter {
    static func pixels(
        in animation: LoadedAnimation
    ) -> Int {
        animation.frames.reduce(into: 0) { total, image in
            let dimensions = pixelDimensions(
                for: image
            )
            total += dimensions.width * dimensions.height
        }
    }

    private static func pixelDimensions(
        for image: NSImage
    ) -> (width: Int, height: Int) {
        let representation = image.representations.max { lhs, rhs in
            lhs.pixelsWide * lhs.pixelsHigh
                < rhs.pixelsWide * rhs.pixelsHigh
        }
        if let representation {
            let width = representation.pixelsWide
            let height = representation.pixelsHigh

            if width > 0, height > 0 {
                return (width, height)
            }
        }

        return (
            max(Int(image.size.width.rounded(.up)), 1),
            max(Int(image.size.height.rounded(.up)), 1)
        )
    }
}
