import Foundation

enum BoundedRegularFileReader {
    static func read<E: Error>(
        from url: URL,
        maximumBytes: Int,
        notRegularFile: @autoclosure () -> E,
        fileTooLarge: (Int, Int) -> E
    ) throws -> Data {
        let values = try url.resourceValues(
            forKeys: [
                .fileSizeKey,
                .isRegularFileKey,
                .isSymbolicLinkKey
            ]
        )
        guard
            values.isRegularFile == true,
            values.isSymbolicLink != true,
            let fileSize = values.fileSize
        else {
            throw notRegularFile()
        }
        guard fileSize <= maximumBytes else {
            throw fileTooLarge(fileSize, maximumBytes)
        }

        return try Data(contentsOf: url)
    }
}
