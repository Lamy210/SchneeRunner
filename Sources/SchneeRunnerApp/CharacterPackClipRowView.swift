import AppKit
import SchneeRunnerCore

@MainActor
final class CharacterPackClipRowView: NSView {
    private static let clipKinds: [CharacterPackClipKind] = [
        .singleImage,
        .spriteSheet4x2,
        .pngSequence,
        .gif
    ]

    let state: CharacterState

    var onChooseSource: ((
        CharacterState,
        CharacterPackClipKind
    ) -> Void)?

    private let kindPopUp = NSPopUpButton(
        frame: .zero,
        pullsDown: false
    )
    private let sourceLabel = NSTextField(labelWithString: "No source selected")
    private let chooseButton = NSButton(
        title: "Choose…",
        target: nil,
        action: nil
    )
    private let clearButton = NSButton(
        title: "Clear",
        target: nil,
        action: nil
    )

    private(set) var sourceURL: URL?

    init(state: CharacterState) {
        self.state = state
        super.init(frame: .zero)
        configureView()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
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
            sourceLabel.stringValue = "No source selected"
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
            labelWithString: state.displayName
        )
        stateLabel.font = .systemFont(
            ofSize: NSFont.systemFontSize,
            weight: .medium
        )

        for kind in Self.clipKinds {
            kindPopUp.addItem(
                withTitle: Self.title(for: kind)
            )
        }
        kindPopUp.target = self
        kindPopUp.action = #selector(kindChanged)

        sourceLabel.lineBreakMode = .byTruncatingMiddle
        sourceLabel.textColor = .secondaryLabelColor

        chooseButton.target = self
        chooseButton.action = #selector(chooseSource)

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

    private static func title(
        for kind: CharacterPackClipKind
    ) -> String {
        switch kind {
        case .singleImage:
            "Single Image"
        case .spriteSheet4x2:
            "4x2 Sprite"
        case .pngSequence:
            "PNG Sequence"
        case .gif:
            "GIF"
        }
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
