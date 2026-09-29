import AppKit
import Foundation

public enum PNGSequenceLoaderError: Error, Equatable, LocalizedError {
    case insufficientFrames(actual: Int)
    case tooManyFrames(actual: Int, maximum: Int)
    case totalFileSizeTooLarge(actual: Int, maximum: Int)
    case totalPixelCountTooLarge(actual: Int, maximum: Int)
    case inconsistentDimensions(
        expectedWidth: Int,
        expectedHeight: Int,
        actualWidth: Int,
        actualHeight: Int,
        fileName: String
    )
    case unreadableFrame(URL)

    public var errorDescription: String? {
        switch self {
        case let .insufficientFrames(actual):
            "PNG sequences require at least two frames. Received \(actual)."
        case let .tooManyFrames(actual, maximum):
            "PNG sequence contains \(actual) frames, exceeding the \(maximum)-frame limit."
        case let .totalFileSizeTooLarge(actual, maximum):
            "PNG sequence uses \(actual) bytes, exceeding the \(maximum)-byte total limit."
        case let .totalPixelCountTooLarge(actual, maximum):
            "PNG sequence contains \(actual) total pixels, exceeding the \(maximum)-pixel limit."
        case let .inconsistentDimensions(
            expectedWidth,
            expectedHeight,
            actualWidth,
            actualHeight,
            fileName
        ):
            "Frame \(fileName) is \(actualWidth)x\(actualHeight); expected \(expectedWidth)x\(expectedHeight)."
        case let .unreadableFrame(url):
            "Could not decode PNG sequence frame: \(url.lastPathComponent)."
        }
    }
}

public struct PNGSequenceLoader {
    public let maximumFrameCount: Int
    public let maximumTotalFileBytes: Int
    public let maximumTotalPixelCount: Int

    private let validator: ImageAssetValidator

    public init(
        maximumFrameCount: Int = 120,
        maximumTotalFileBytes: Int = 64 * 1024 * 1024,
        maximumTotalPixelCount: Int = 16_000_000,
        validator: ImageAssetValidator = .init()
    ) {
        self.maximumFrameCount = max(maximumFrameCount, 2)
        self.maximumTotalFileBytes = max(maximumTotalFileBytes, 1)
        self.maximumTotalPixelCount = max(maximumTotalPixelCount, 1)
        self.validator = validator
    }

    public func frames(from sourceURLs: [URL]) throws -> [NSImage] {
        let orderedURLs = try validatedOrderedURLs(sourceURLs)

        return try orderedURLs.map { url in
            guard let image = NSImage(contentsOf: url) else {
                throw PNGSequenceLoaderError.unreadableFrame(url)
            }

            return image
        }
    }

    func validatedOrderedURLs(_ sourceURLs: [URL]) throws -> [URL] {
        try validateFrameCount(sourceURLs.count)

        let orderedURLs = orderedSourceURLs(sourceURLs)
        let firstMetadata = try validator.validate(url: orderedURLs[0])
        var totalFileBytes = firstMetadata.fileSize

        for url in orderedURLs.dropFirst() {
            let metadata = try validator.validate(url: url)
            try validateDimensions(
                metadata,
                expected: firstMetadata,
                fileName: url.lastPathComponent
            )
            totalFileBytes += metadata.fileSize
        }

        try validateAggregateLimits(
            metadata: firstMetadata,
            frameCount: orderedURLs.count,
            totalFileBytes: totalFileBytes
        )
        return orderedURLs
    }

    func orderedSourceURLs(_ sourceURLs: [URL]) -> [URL] {
        sourceURLs.sorted { lhs, rhs in
            lhs.lastPathComponent.compare(
                rhs.lastPathComponent,
                options: [.numeric, .caseInsensitive],
                range: nil,
                locale: Locale(identifier: "en_US_POSIX")
            ) == .orderedAscending
        }
    }

    private func validateFrameCount(_ count: Int) throws {
        guard count >= 2 else {
            throw PNGSequenceLoaderError.insufficientFrames(
                actual: count
            )
        }
        guard count <= maximumFrameCount else {
            throw PNGSequenceLoaderError.tooManyFrames(
                actual: count,
                maximum: maximumFrameCount
            )
        }
    }

    private func validateDimensions(
        _ metadata: ValidatedImageAsset,
        expected: ValidatedImageAsset,
        fileName: String
    ) throws {
        guard
            metadata.width == expected.width,
            metadata.height == expected.height
        else {
            throw PNGSequenceLoaderError.inconsistentDimensions(
                expectedWidth: expected.width,
                expectedHeight: expected.height,
                actualWidth: metadata.width,
                actualHeight: metadata.height,
                fileName: fileName
            )
        }
    }

    private func validateAggregateLimits(
        metadata: ValidatedImageAsset,
        frameCount: Int,
        totalFileBytes: Int
    ) throws {
        guard totalFileBytes <= maximumTotalFileBytes else {
            throw PNGSequenceLoaderError.totalFileSizeTooLarge(
                actual: totalFileBytes,
                maximum: maximumTotalFileBytes
            )
        }

        let pixelsPerFrame = metadata.width * metadata.height
        let totalPixelCount = pixelsPerFrame * frameCount
        guard totalPixelCount <= maximumTotalPixelCount else {
            throw PNGSequenceLoaderError.totalPixelCountTooLarge(
                actual: totalPixelCount,
                maximum: maximumTotalPixelCount
            )
        }
    }
}
