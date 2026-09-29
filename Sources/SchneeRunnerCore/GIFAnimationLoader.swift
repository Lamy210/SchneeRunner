import AppKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

public struct GIFAnimationPolicy: Equatable, Sendable {
    public let maximumFileBytes: Int
    public let maximumFrameCount: Int
    public let maximumPixelDimension: Int
    public let maximumTotalPixelCount: Int
    public let defaultFrameDuration: Double
    public let minimumFrameDuration: Double
    public let maximumFrameDuration: Double

    public init(
        maximumFileBytes: Int = 32 * 1024 * 1024,
        maximumFrameCount: Int = 120,
        maximumPixelDimension: Int = 4096,
        maximumTotalPixelCount: Int = 16_000_000,
        defaultFrameDuration: Double = 0.1,
        minimumFrameDuration: Double = 0.02,
        maximumFrameDuration: Double = 10
    ) {
        self.maximumFileBytes = max(maximumFileBytes, 1)
        self.maximumFrameCount = max(maximumFrameCount, 2)
        self.maximumPixelDimension = max(maximumPixelDimension, 1)
        self.maximumTotalPixelCount = max(maximumTotalPixelCount, 1)
        self.defaultFrameDuration = max(defaultFrameDuration, 0.001)
        self.minimumFrameDuration = max(minimumFrameDuration, 0.001)
        self.maximumFrameDuration = max(
            maximumFrameDuration,
            self.minimumFrameDuration
        )
    }
}

public enum GIFAnimationLoaderError: Error, Equatable, LocalizedError {
    case symbolicLinkNotAllowed(URL)
    case sourceIsNotRegularFile(URL)
    case fileSizeUnavailable(URL)
    case fileTooLarge(actual: Int, maximum: Int)
    case unreadableGIF(URL)
    case unsupportedContentType(String?)
    case insufficientFrames(actual: Int)
    case tooManyFrames(actual: Int, maximum: Int)
    case invalidDimensions(width: Int, height: Int)
    case dimensionTooLarge(width: Int, height: Int, maximum: Int)
    case totalPixelCountTooLarge(actual: Int, maximum: Int)
    case frameDecodeFailed(index: Int)

    public var errorDescription: String? {
        switch self {
        case let .symbolicLinkNotAllowed(url):
            "Symbolic links are not allowed for GIF imports: \(url.lastPathComponent)."
        case let .sourceIsNotRegularFile(url):
            "The selected GIF is not a regular file: \(url.lastPathComponent)."
        case let .fileSizeUnavailable(url):
            "Could not determine GIF file size: \(url.lastPathComponent)."
        case let .fileTooLarge(actual, maximum):
            "GIF is \(actual) bytes, exceeding the \(maximum)-byte limit."
        case let .unreadableGIF(url):
            "Could not inspect GIF data: \(url.lastPathComponent)."
        case let .unsupportedContentType(identifier):
            "The selected file is not GIF data (type: \(identifier ?? "unknown"))."
        case let .insufficientFrames(actual):
            "Animated GIFs require at least two frames. Received \(actual)."
        case let .tooManyFrames(actual, maximum):
            "GIF contains \(actual) frames, exceeding the \(maximum)-frame limit."
        case let .invalidDimensions(width, height):
            "GIF has invalid dimensions: \(width)x\(height)."
        case let .dimensionTooLarge(width, height, maximum):
            "GIF dimensions \(width)x\(height) exceed the \(maximum)-pixel limit."
        case let .totalPixelCountTooLarge(actual, maximum):
            "GIF contains \(actual) decoded pixels, exceeding the \(maximum)-pixel total limit."
        case let .frameDecodeFailed(index):
            "Could not decode GIF frame \(index)."
        }
    }
}

public struct GIFAnimationLoader: Sendable {
    public let policy: GIFAnimationPolicy

    public init(policy: GIFAnimationPolicy = .init()) {
        self.policy = policy
    }

    public func load(from url: URL) throws -> LoadedAnimation {
        let source = try validatedSource(url: url)
        let frameCount = CGImageSourceGetCount(source)
        try validateFrameCount(frameCount)

        try validateFrameMetadata(
            source: source,
            frameCount: frameCount,
            url: url
        )

        var frames: [NSImage] = []
        var durations: [Double] = []
        var totalDecodedPixels = 0
        frames.reserveCapacity(frameCount)
        durations.reserveCapacity(frameCount)

        for index in 0 ..< frameCount {
            guard let cgImage = CGImageSourceCreateImageAtIndex(
                source,
                index,
                [kCGImageSourceShouldCache: true] as CFDictionary
            ) else {
                throw GIFAnimationLoaderError.frameDecodeFailed(index: index)
            }

            try validateDecodedFrame(
                cgImage,
                totalDecodedPixels: &totalDecodedPixels
            )

            frames.append(
                NSImage(
                    cgImage: cgImage,
                    size: NSSize(
                        width: CGFloat(cgImage.width),
                        height: CGFloat(cgImage.height)
                    )
                )
            )
            durations.append(
                frameDuration(
                    source: source,
                    index: index
                )
            )
        }

        return try LoadedAnimation(
            frames: frames,
            schedule: AnimationSchedule(
                frameDurations: durations
            )
        )
    }

    public func validate(url: URL) throws {
        let source = try validatedSource(url: url)
        let frameCount = CGImageSourceGetCount(source)
        try validateFrameCount(frameCount)
        try validateFrameMetadata(
            source: source,
            frameCount: frameCount,
            url: url
        )
    }

    private func validatedSource(url: URL) throws -> CGImageSource {
        let values = try url.resourceValues(
            forKeys: [.fileSizeKey, .isRegularFileKey, .isSymbolicLinkKey]
        )

        guard values.isSymbolicLink != true else {
            throw GIFAnimationLoaderError.symbolicLinkNotAllowed(url)
        }
        guard values.isRegularFile == true else {
            throw GIFAnimationLoaderError.sourceIsNotRegularFile(url)
        }
        guard let fileSize = values.fileSize else {
            throw GIFAnimationLoaderError.fileSizeUnavailable(url)
        }
        guard fileSize <= policy.maximumFileBytes else {
            throw GIFAnimationLoaderError.fileTooLarge(
                actual: fileSize,
                maximum: policy.maximumFileBytes
            )
        }

        let options = [
            kCGImageSourceShouldCache: false
        ] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(
            url as CFURL,
            options
        ) else {
            throw GIFAnimationLoaderError.unreadableGIF(url)
        }

        let typeIdentifier = CGImageSourceGetType(source) as String?
        guard typeIdentifier == UTType.gif.identifier else {
            throw GIFAnimationLoaderError.unsupportedContentType(
                typeIdentifier
            )
        }

        return source
    }

    private func validateFrameCount(_ frameCount: Int) throws {
        guard frameCount >= 2 else {
            throw GIFAnimationLoaderError.insufficientFrames(
                actual: frameCount
            )
        }
        guard frameCount <= policy.maximumFrameCount else {
            throw GIFAnimationLoaderError.tooManyFrames(
                actual: frameCount,
                maximum: policy.maximumFrameCount
            )
        }
    }

    private func validateFrameMetadata(
        source: CGImageSource,
        frameCount: Int,
        url: URL
    ) throws {
        var totalPixels = 0

        for index in 0 ..< frameCount {
            let dimensions = try frameDimensions(
                source: source,
                index: index,
                url: url
            )
            try validateFrameDimensions(dimensions)

            let pixels = dimensions.width * dimensions.height
            guard totalPixels <= policy.maximumTotalPixelCount - pixels else {
                throw GIFAnimationLoaderError.totalPixelCountTooLarge(
                    actual: totalPixels + pixels,
                    maximum: policy.maximumTotalPixelCount
                )
            }
            totalPixels += pixels
        }
    }

    private func frameDimensions(
        source: CGImageSource,
        index: Int,
        url: URL
    ) throws -> (width: Int, height: Int) {
        let options = [
            kCGImageSourceShouldCache: false
        ] as CFDictionary
        guard
            let properties = CGImageSourceCopyPropertiesAtIndex(
                source,
                index,
                options
            ) as? [CFString: Any],
            let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue,
            let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue
        else {
            throw GIFAnimationLoaderError.unreadableGIF(url)
        }

        return (width, height)
    }

    private func validateFrameDimensions(
        _ dimensions: (width: Int, height: Int)
    ) throws {
        let width = dimensions.width
        let height = dimensions.height

        guard width > 0, height > 0 else {
            throw GIFAnimationLoaderError.invalidDimensions(
                width: width,
                height: height
            )
        }
        guard
            width <= policy.maximumPixelDimension,
            height <= policy.maximumPixelDimension
        else {
            throw GIFAnimationLoaderError.dimensionTooLarge(
                width: width,
                height: height,
                maximum: policy.maximumPixelDimension
            )
        }
    }

    private func validateDecodedFrame(
        _ image: CGImage,
        totalDecodedPixels: inout Int
    ) throws {
        let width = image.width
        let height = image.height

        guard
            width <= policy.maximumPixelDimension,
            height <= policy.maximumPixelDimension
        else {
            throw GIFAnimationLoaderError.dimensionTooLarge(
                width: width,
                height: height,
                maximum: policy.maximumPixelDimension
            )
        }

        let pixels = width * height
        guard totalDecodedPixels <= policy.maximumTotalPixelCount - pixels else {
            throw GIFAnimationLoaderError.totalPixelCountTooLarge(
                actual: totalDecodedPixels + pixels,
                maximum: policy.maximumTotalPixelCount
            )
        }

        totalDecodedPixels += pixels
    }

    private func frameDuration(
        source: CGImageSource,
        index: Int
    ) -> Double {
        guard
            let properties = CGImageSourceCopyPropertiesAtIndex(
                source,
                index,
                nil
            ) as? [CFString: Any],
            let gif = properties[kCGImagePropertyGIFDictionary] as? [CFString: Any]
        else {
            return policy.defaultFrameDuration
        }

        let durations: [NSNumber?] = [
            gif[kCGImagePropertyGIFUnclampedDelayTime] as? NSNumber,
            gif[kCGImagePropertyGIFDelayTime] as? NSNumber
        ]

        var rawDuration = policy.defaultFrameDuration
        for number in durations {
            guard
                let value = number?.doubleValue,
                value.isFinite,
                value > 0
            else {
                continue
            }

            rawDuration = value
            break
        }

        return min(
            max(rawDuration, policy.minimumFrameDuration),
            policy.maximumFrameDuration
        )
    }
}
