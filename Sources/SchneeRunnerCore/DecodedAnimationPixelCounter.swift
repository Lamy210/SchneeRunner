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
        if
            let representation,
            representation.pixelsWide > 0,
            representation.pixelsHigh > 0
        {
            return (
                representation.pixelsWide,
                representation.pixelsHigh
            )
        }

        return (
            max(Int(image.size.width.rounded(.up)), 1),
            max(Int(image.size.height.rounded(.up)), 1)
        )
    }
}
