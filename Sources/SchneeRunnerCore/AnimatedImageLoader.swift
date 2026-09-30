import AppKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

public enum AnimatedImageFormat: String, Equatable, Sendable {
    case apng
    case webP

    public var displayName: String {
        switch self {
        case .apng:
            "APNG"
        case .webP:
            "WebP"
        }
    }

    public var canonicalFileExtension: String {
        switch self {
        case .apng:
            "png"
        case .webP:
            "webp"
        }
    }

    fileprivate var typeIdentifier: String {
        switch self {
        case .apng:
            UTType.png.identifier
        case .webP:
            UTType.webP.identifier
        }
    }

    fileprivate var propertyDictionaryKey: CFString {
        switch self {
        case .apng:
            kCGImagePropertyPNGDictionary
        case .webP:
            kCGImagePropertyWebPDictionary
        }
    }

    fileprivate var unclampedDelayKey: CFString {
        switch self {
        case .apng:
            kCGImagePropertyAPNGUnclampedDelayTime
        case .webP:
            kCGImagePropertyWebPUnclampedDelayTime
        }
    }

    fileprivate var delayKey: CFString {
        switch self {
        case .apng:
            kCGImagePropertyAPNGDelayTime
        case .webP:
            kCGImagePropertyWebPDelayTime
        }
    }
}

public struct AnimatedImagePolicy: Equatable, Sendable {
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

public enum AnimatedImageLoaderError: Error, Equatable, LocalizedError {
    case symbolicLinkNotAllowed(URL)
    case sourceIsNotRegularFile(URL)
    case fileSizeUnavailable(URL)
    case fileTooLarge(actual: Int, maximum: Int)
    case unreadableImage(URL)
    case unsupportedContentType(expected: String, actual: String?)
    case insufficientFrames(actual: Int)
    case tooManyFrames(actual: Int, maximum: Int)
    case invalidDimensions(width: Int, height: Int)
    case dimensionTooLarge(width: Int, height: Int, maximum: Int)
    case totalPixelCountTooLarge(actual: Int, maximum: Int)
    case frameDecodeFailed(index: Int)

    public var errorDescription: String? {
        switch self {
        case let .symbolicLinkNotAllowed(url):
            "Symbolic links are not allowed for animated image imports: \(url.lastPathComponent)."
        case let .sourceIsNotRegularFile(url):
            "The selected animation is not a regular file: \(url.lastPathComponent)."
        case let .fileSizeUnavailable(url):
            "Could not determine animation file size: \(url.lastPathComponent)."
        case let .fileTooLarge(actual, maximum):
            "Animation is \(actual) bytes, exceeding the \(maximum)-byte limit."
        case let .unreadableImage(url):
            "Could not inspect animated image data: \(url.lastPathComponent)."
        case let .unsupportedContentType(expected, actual):
            "Expected \(expected) data, received \(actual ?? "unknown")."
        case let .insufficientFrames(actual):
            "Animated images require at least two frames. Received \(actual)."
        case let .tooManyFrames(actual, maximum):
            "Animation contains \(actual) frames, exceeding the \(maximum)-frame limit."
        case let .invalidDimensions(width, height):
            "Animation has invalid dimensions: \(width)x\(height)."
        case let .dimensionTooLarge(width, height, maximum):
            "Animation dimensions \(width)x\(height) exceed the \(maximum)-pixel limit."
        case let .totalPixelCountTooLarge(actual, maximum):
            "Animation contains \(actual) decoded pixels, exceeding the \(maximum)-pixel total limit."
        case let .frameDecodeFailed(index):
            "Could not decode animated image frame \(index)."
        }
    }
}

public struct AnimatedImageLoader: Sendable {
    public let format: AnimatedImageFormat
    public let policy: AnimatedImagePolicy

    public init(
        format: AnimatedImageFormat,
        policy: AnimatedImagePolicy = .init()
    ) {
        self.format = format
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
            let image = try decodedFrame(
                source: source,
                index: index
            )
            try validateDecodedFrame(
                image,
                totalDecodedPixels: &totalDecodedPixels
            )
            frames.append(
                NSImage(
                    cgImage: image,
                    size: NSSize(
                        width: CGFloat(image.width),
                        height: CGFloat(image.height)
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
            throw AnimatedImageLoaderError.symbolicLinkNotAllowed(url)
        }
        guard values.isRegularFile == true else {
            throw AnimatedImageLoaderError.sourceIsNotRegularFile(url)
        }
        guard let fileSize = values.fileSize else {
            throw AnimatedImageLoaderError.fileSizeUnavailable(url)
        }
        guard fileSize <= policy.maximumFileBytes else {
            throw AnimatedImageLoaderError.fileTooLarge(
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
            throw AnimatedImageLoaderError.unreadableImage(url)
        }

        let actualType = CGImageSourceGetType(source) as String?
        guard actualType == format.typeIdentifier else {
            throw AnimatedImageLoaderError.unsupportedContentType(
                expected: format.typeIdentifier,
                actual: actualType
            )
        }

        return source
    }

    private func validateFrameCount(_ frameCount: Int) throws {
        guard frameCount >= 2 else {
            throw AnimatedImageLoaderError.insufficientFrames(
                actual: frameCount
            )
        }
        guard frameCount <= policy.maximumFrameCount else {
            throw AnimatedImageLoaderError.tooManyFrames(
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
            try validateDimensions(dimensions)

            let pixels = dimensions.width * dimensions.height
            guard totalPixels <= policy.maximumTotalPixelCount - pixels else {
                throw AnimatedImageLoaderError.totalPixelCountTooLarge(
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
            throw AnimatedImageLoaderError.unreadableImage(url)
        }

        return (width, height)
    }

    private func validateDimensions(
        _ dimensions: (width: Int, height: Int)
    ) throws {
        let width = dimensions.width
        let height = dimensions.height

        guard width > 0, height > 0 else {
            throw AnimatedImageLoaderError.invalidDimensions(
                width: width,
                height: height
            )
        }
        guard
            width <= policy.maximumPixelDimension,
            height <= policy.maximumPixelDimension
        else {
            throw AnimatedImageLoaderError.dimensionTooLarge(
                width: width,
                height: height,
                maximum: policy.maximumPixelDimension
            )
        }
    }

    private func decodedFrame(
        source: CGImageSource,
        index: Int
    ) throws -> CGImage {
        guard let image = CGImageSourceCreateImageAtIndex(
            source,
            index,
            [kCGImageSourceShouldCache: true] as CFDictionary
        ) else {
            throw AnimatedImageLoaderError.frameDecodeFailed(
                index: index
            )
        }

        return image
    }

    private func validateDecodedFrame(
        _ image: CGImage,
        totalDecodedPixels: inout Int
    ) throws {
        let width = image.width
        let height = image.height
        try validateDimensions(
            (width: width, height: height)
        )

        let pixels = width * height
        guard totalDecodedPixels <= policy.maximumTotalPixelCount - pixels else {
            throw AnimatedImageLoaderError.totalPixelCountTooLarge(
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
            let dictionary = properties[
                format.propertyDictionaryKey
            ] as? [CFString: Any]
        else {
            return policy.defaultFrameDuration
        }

        let values: [NSNumber?] = [
            dictionary[format.unclampedDelayKey] as? NSNumber,
            dictionary[format.delayKey] as? NSNumber
        ]
        var rawDuration = policy.defaultFrameDuration

        for number in values {
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
