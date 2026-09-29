import Foundation

public struct SpriteSheetFrame: Equatable, Sendable {
    public let x: Int
    public let y: Int
    public let width: Int
    public let height: Int

    public init(x: Int, y: Int, width: Int, height: Int) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public enum SpriteSheetGridError: Error, Equatable, LocalizedError {
    case invalidGrid(columns: Int, rows: Int)
    case invalidImageSize(width: Int, height: Int)

    public var errorDescription: String? {
        switch self {
        case let .invalidGrid(columns, rows):
            "The sprite sheet grid must be positive. Received \(columns)x\(rows)."
        case let .invalidImageSize(width, height):
            "The sprite sheet image must be positive. Received \(width)x\(height) pixels."
        }
    }
}

public struct SpriteSheetGrid: Sendable {
    public let columns: Int
    public let rows: Int

    public init(columns: Int = 4, rows: Int = 2) throws {
        guard columns > 0, rows > 0 else {
            throw SpriteSheetGridError.invalidGrid(columns: columns, rows: rows)
        }

        self.columns = columns
        self.rows = rows
    }

    public func frames(imageWidth: Int, imageHeight: Int) throws -> [SpriteSheetFrame] {
        guard imageWidth > 0, imageHeight > 0 else {
            throw SpriteSheetGridError.invalidImageSize(width: imageWidth, height: imageHeight)
        }

        var result: [SpriteSheetFrame] = []
        result.reserveCapacity(columns * rows)

        for row in 0 ..< rows {
            let yStart = row * imageHeight / rows
            let yEnd = (row + 1) * imageHeight / rows

            for column in 0 ..< columns {
                let xStart = column * imageWidth / columns
                let xEnd = (column + 1) * imageWidth / columns

                result.append(
                    SpriteSheetFrame(
                        x: xStart,
                        y: yStart,
                        width: xEnd - xStart,
                        height: yEnd - yStart
                    )
                )
            }
        }

        return result
    }
}
