import AppKit
import SchneeRunnerCore

@MainActor
final class CharacterPackClipRowView: NSView {
    private static let clipKinds: [CharacterPackClipKind] = [
        .singleImage,
        .spriteSheet4x2,
        .pngSequence,
        .gif,
        .apng,
        .webP
    ]

    let state: CharacterState

    var onChooseSource: ((
        CharacterState,
        CharacterPackClipKind
    ) -> Void)?

    private let localization: AppLocalization
    private let kindPopUp = NSPopUpButton(
        frame: .zero,
        pullsDown: false
    )
    private let sourceLabel = NSTextField(labelWithString: "")
    private let chooseButton = NSButton(
        title: "",
        target: nil,
        action: nil
    )
    private let clearButton = NSButton(
        title: "",
        target: nil,
        action: nil
    )

    private(set) var sourceURL: URL?

    init(
        state: CharacterState,
        localization: AppLocalization = .current
    ) {
        self.state = state
        self.localization = localization
        super.init(frame: .zero)
        configureView()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var buildClip: CharacterPackBuildClip? {
        guard let sourceURL else {
            return nil
        }

        return CharacterPackBuildClip(
            state: state,
            kind: selectedKind,
            sourceURL: sourceURL
        )
    }

    func setSourceURL(_ newURL: URL?) {
        sourceURL = newURL

        if let url = newURL {
            sourceLabel.stringValue = url.lastPathComponent
            sourceLabel.toolTip = url.path
            clearButton.isEnabled = true
        } else {
            sourceLabel.stringValue = localization.string(
                "characterPack.builder.noSource"
            )
            sourceLabel.toolTip = nil
            clearButton.isEnabled = false
        }
    }

    private var selectedKind: CharacterPackClipKind {
        let index = max(
            min(
                kindPopUp.indexOfSelectedItem,
                Self.clipKinds.count - 1
            ),
            0
        )
        return Self.clipKinds[index]
    }

    private func configureView() {
        translatesAutoresizingMaskIntoConstraints = false

        let stateLabel = NSTextField(
            labelWithString: localization.characterState(state)
        )
        stateLabel.font = .systemFont(
            ofSize: NSFont.systemFontSize,
            weight: .medium
        )

        for kind in Self.clipKinds {
            kindPopUp.addItem(
                withTitle: localization.string(
                    "characterKind.\(kind.rawValue)"
                )
            )
        }
        kindPopUp.target = self
        kindPopUp.action = #selector(kindChanged)

        sourceLabel.stringValue = localization.string(
            "characterPack.builder.noSource"
        )
        sourceLabel.lineBreakMode = .byTruncatingMiddle
        sourceLabel.textColor = .secondaryLabelColor

        chooseButton.title = localization.string(
            "characterPack.builder.choose"
        )
        chooseButton.target = self
        chooseButton.action = #selector(chooseSource)

        clearButton.title = localization.string(
            "characterPack.builder.clear"
        )
        clearButton.target = self
        clearButton.action = #selector(clearSource)
        clearButton.isEnabled = false

        let stack = NSStackView(
            views: [
                stateLabel,
                kindPopUp,
                sourceLabel,
                chooseButton,
                clearButton
            ]
        )
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stack)

        NSLayoutConstraint.activate([
            stateLabel.widthAnchor.constraint(equalToConstant: 60),
            kindPopUp.widthAnchor.constraint(equalToConstant: 145),
            chooseButton.widthAnchor.constraint(equalToConstant: 80),
            clearButton.widthAnchor.constraint(equalToConstant: 60),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 28)
        ])
    }

    @objc
    private func kindChanged() {
        setSourceURL(nil)
    }

    @objc
    private func chooseSource() {
        onChooseSource?(
            state,
            selectedKind
        )
    }

    @objc
    private func clearSource() {
        setSourceURL(nil)
    }
}
