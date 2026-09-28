import Foundation
import ImageIO
import UniformTypeIdentifiers

public struct ImageAssetValidationPolicy: Equatable, Sendable {
    public let maximumFileBytes: Int
    public let maximumPixelDimension: Int
    public let maximumPixelCount: Int
    public let allowsAnimation: Bool

    public init(
        maximumFileBytes: Int = 32 * 1024 * 1024,
        maximumPixelDimension: Int = 8192,
        maximumPixelCount: Int = 16_000_000,
        allowsAnimation: Bool = false
    ) {
        self.maximumFileBytes = max(maximumFileBytes, 1)
        self.maximumPixelDimension = max(maximumPixelDimension, 1)
        self.maximumPixelCount = max(maximumPixelCount, 1)
        self.allowsAnimation = allowsAnimation
    }
}

public struct ValidatedImageAsset: Equatable, Sendable {
    public let width: Int
    public let height: Int
    public let fileSize: Int
    public let frameCount: Int

    public init(
        width: Int,
        height: Int,
        fileSize: Int,
        frameCount: Int
    ) {
        self.width = width
        self.height = height
        self.fileSize = fileSize
        self.frameCount = frameCount
    }
}

public enum ImageAssetValidationError: Error, Equatable, LocalizedError {
    case symbolicLinkNotAllowed(URL)
    case sourceIsNotRegularFile(URL)
    case fileTooLarge(actual: Int, maximum: Int)
    case unreadableImage(URL)
    case unsupportedContentType(String?)
    case animatedImageNotSupported(frameCount: Int)
    case invalidDimensions(width: Int, height: Int)
    case dimensionTooLarge(width: Int, height: Int, maximum: Int)
    case pixelCountTooLarge(width: Int, height: Int, maximum: Int)

    public var errorDescription: String? {
        switch self {
        case let .symbolicLinkNotAllowed(url):
            "Symbolic links are not allowed for image imports: \(url.lastPathComponent)."
        case let .sourceIsNotRegularFile(url):
            "The selected image is not a regular file: \(url.lastPathComponent)."
        case let .fileTooLarge(actual, maximum):
            "The image is \(actual) bytes, exceeding the \(maximum)-byte import limit."
        case let .unreadableImage(url):
            "Could not inspect image metadata for \(url.lastPathComponent)."
        case let .unsupportedContentType(identifier):
            "The selected file is not PNG data (type: \(identifier ?? "unknown"))."
        case let .animatedImageNotSupported(frameCount):
            "Animated images are not supported by this importer (\(frameCount) frames)."
        case let .invalidDimensions(width, height):
            "The image has invalid dimensions: \(width)x\(height)."
        case let .dimensionTooLarge(width, height, maximum):
            "The image dimensions \(width)x\(height) exceed the \(maximum)-pixel dimension limit."
        case let .pixelCountTooLarge(width, height, maximum):
            "The image contains too many pixels: \(width)x\(height), limit \(maximum)."
        }
    }
}

public struct ImageAssetValidator: Sendable {
    public let policy: ImageAssetValidationPolicy

    public init(policy: ImageAssetValidationPolicy = .init()) {
        self.policy = policy
    }

    public func validate(url: URL) throws -> ValidatedImageAsset {
        let resourceValues = try url.resourceValues(
            forKeys: [.fileSizeKey, .isRegularFileKey, .isSymbolicLinkKey]
        )

        guard resourceValues.isSymbolicLink != true else {
            throw ImageAssetValidationError.symbolicLinkNotAllowed(url)
        }
        guard resourceValues.isRegularFile == true else {
            throw ImageAssetValidationError.sourceIsNotRegularFile(url)
        }

        let fileSize = resourceValues.fileSize ?? 0
        guard fileSize <= policy.maximumFileBytes else {
            throw ImageAssetValidationError.fileTooLarge(
                actual: fileSize,
                maximum: policy.maximumFileBytes
            )
        }

        let sourceOptions = [
            kCGImageSourceShouldCache: false
        ] as CFDictionary
        guard
            let imageSource = CGImageSourceCreateWithURL(
                url as CFURL,
                sourceOptions
            )
        else {
            throw ImageAssetValidationError.unreadableImage(url)
        }

        let typeIdentifier = CGImageSourceGetType(imageSource) as String?
        guard typeIdentifier == UTType.png.identifier else {
            throw ImageAssetValidationError.unsupportedContentType(typeIdentifier)
        }

        let frameCount = CGImageSourceGetCount(imageSource)
        guard policy.allowsAnimation || frameCount == 1 else {
            throw ImageAssetValidationError.animatedImageNotSupported(
                frameCount: frameCount
            )
        }

        let propertiesOptions = [
            kCGImageSourceShouldCache: false
        ] as CFDictionary
        guard
            let properties = CGImageSourceCopyPropertiesAtIndex(
                imageSource,
                0,
                propertiesOptions
            ) as? [CFString: Any],
            let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue,
            let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue
        else {
            throw ImageAssetValidationError.unreadableImage(url)
        }

        guard width > 0, height > 0 else {
            throw ImageAssetValidationError.invalidDimensions(
                width: width,
                height: height
            )
        }
        guard
            width <= policy.maximumPixelDimension,
            height <= policy.maximumPixelDimension
        else {
            throw ImageAssetValidationError.dimensionTooLarge(
                width: width,
                height: height,
                maximum: policy.maximumPixelDimension
            )
        }
        guard height <= policy.maximumPixelCount / width else {
            throw ImageAssetValidationError.pixelCountTooLarge(
                width: width,
                height: height,
                maximum: policy.maximumPixelCount
            )
        }

        return ValidatedImageAsset(
            width: width,
            height: height,
            fileSize: fileSize,
            frameCount: frameCount
        )
    }
}
