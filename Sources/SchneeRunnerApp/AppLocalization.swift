import Foundation
import SchneeRunnerCore

struct AppLocalization {
    static var current: AppLocalization {
        AppLocalization()
    }

    private let localeIdentifier: String?
    private let resourceBundle: Bundle

    init(
        localeIdentifier: String? = nil,
        resourceBundle: Bundle = .module
    ) {
        self.localeIdentifier = localeIdentifier
        self.resourceBundle = resourceBundle
    }

    func string(
        _ key: String,
        arguments: CVarArg...
    ) -> String {
        let format = localizedString(forKey: key)
        guard !arguments.isEmpty else {
            return format
        }
        return String(
            format: format,
            locale: locale,
            arguments: arguments
        )
    }

    func characterState(_ state: CharacterState) -> String {
        string("characterState.\(state.rawValue)")
    }

    private var locale: Locale {
        guard let localeIdentifier else {
            return .current
        }
        return Locale(identifier: localeIdentifier)
    }

    private func localizedString(forKey key: String) -> String {
        if let localeIdentifier,
           let selectedBundle = localizedBundle(for: localeIdentifier)
        {
            let localized = selectedBundle.localizedString(
                forKey: key,
                value: key,
                table: nil
            )
            if localized != key {
                return localized
            }
            return englishString(forKey: key)
        }

        let localized = resourceBundle.localizedString(
            forKey: key,
            value: key,
            table: nil
        )
        if localized != key {
            return localized
        }
        return englishString(forKey: key)
    }

    private func englishString(forKey key: String) -> String {
        guard let englishBundle = localizedBundle(for: "en") else {
            return key
        }
        return englishBundle.localizedString(
            forKey: key,
            value: key,
            table: nil
        )
    }

    private func localizedBundle(for identifier: String) -> Bundle? {
        var candidates = [identifier]
        if let languageCode = identifier.split(separator: "-").first {
            let language = String(languageCode)
            if language != identifier {
                candidates.append(language)
            }
        }

        for candidate in candidates {
            guard
                let url = resourceBundle.url(
                    forResource: candidate,
                    withExtension: "lproj"
                ),
                let bundle = Bundle(url: url)
            else {
                continue
            }
            return bundle
        }
        return nil
    }
}
