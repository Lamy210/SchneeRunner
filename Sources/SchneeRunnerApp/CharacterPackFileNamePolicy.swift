enum CharacterPackFileNamePolicy {
    private static let fileExtension = ".schneerunner"

    static func fileName(for suggestedName: String) -> String {
        let sanitizedName = suggestedName
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")

        if sanitizedName.lowercased().hasSuffix(fileExtension) {
            return sanitizedName
        }

        return sanitizedName + fileExtension
    }
}
