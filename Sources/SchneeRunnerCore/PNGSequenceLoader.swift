import AppKit
import Foundation

public enum PNGSequenceLoaderError: Error, Equatable, LocalizedError {
    case insufficientFrames(actual: Int)
    case tooManyFrames(actual: Int, maximum: Int)
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

    private let validator: ImageAssetValidator

    public init(
        maximumFrameCount: Int = 120,
        validator: ImageAssetValidator = .init()
    ) {
        self.maximumFrameCount = max(maximumFrameCount, 2)
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
        guard sourceURLs.count >= 2 else {
            throw PNGSequenceLoaderError.insufficientFrames(
                actual: sourceURLs.count
            )
        }
        guard sourceURLs.count <= maximumFrameCount else {
            throw PNGSequenceLoaderError.tooManyFrames(
                actual: sourceURLs.count,
                maximum: maximumFrameCount
            )
        }

        let orderedURLs = orderedSourceURLs(sourceURLs)
        let firstMetadata = try validator.validate(url: orderedURLs[0])

        for url in orderedURLs.dropFirst() {
            let metadata = try validator.validate(url: url)
            guard
                metadata.width == firstMetadata.width,
                metadata.height == firstMetadata.height
            else {
                throw PNGSequenceLoaderError.inconsistentDimensions(
                    expectedWidth: firstMetadata.width,
                    expectedHeight: firstMetadata.height,
                    actualWidth: metadata.width,
                    actualHeight: metadata.height,
                    fileName: url.lastPathComponent
                )
            }
        }

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
}
