import AppKit
import SchneeRunnerCore

@MainActor
final class CharacterPackBuilderPresenter: NSObject, NSWindowDelegate {
    private let localization: AppLocalization
    private let sourcePicker: CharacterPackBuilderSourcePicker

    private var panel: NSPanel?
    private var nameField: NSTextField?
    private var defaultStatePopUp: NSPopUpButton?
    private var rows: [CharacterState: CharacterPackClipRowView] = [:]
    private var result: CharacterPackBuildRequest?

    init(localization: AppLocalization = .current) {
        self.localization = localization
        sourcePicker = CharacterPackBuilderSourcePicker(
            localization: localization
        )
        super.init()
    }

    func chooseBuildRequest() -> CharacterPackBuildRequest? {
        result = nil
        rows = [:]

        let panel = makePanel()
        self.panel = panel
        panel.contentView = makeContentView()
        panel.center()
        panel.makeKeyAndOrderFront(nil)

        NSApplication.shared.runModal(for: panel)
        panel.orderOut(nil)

        self.panel = nil
        nameField = nil
        defaultStatePopUp = nil
        rows = [:]

        return result
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: 720,
                height: 400
            ),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        panel.title = localization.string("characterPack.builder.title")
        panel.isReleasedWhenClosed = false
        panel.delegate = self
        return panel
    }

    private func makeContentView() -> NSView {
        let contentView = NSView()

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        stack.addArrangedSubview(makeNameRow())
        stack.addArrangedSubview(makeDefaultStateRow())

        let divider = NSBox()
        divider.boxType = .separator
        stack.addArrangedSubview(divider)

        for state in CharacterState.allCases {
            let row = CharacterPackClipRowView(
                state: state,
                localization: localization
            )
            row.onChooseSource = { [weak self] state, kind in
                self?.chooseSource(
                    for: state,
                    kind: kind
                )
            }
            rows[state] = row
            stack.addArrangedSubview(row)
            row.widthAnchor.constraint(
                equalTo: stack.widthAnchor
            ).isActive = true
        }

        stack.addArrangedSubview(makeButtonRow())
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor,
                constant: 20
            ),
            stack.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor,
                constant: -20
            ),
            stack.topAnchor.constraint(
                equalTo: contentView.topAnchor,
                constant: 20
            ),
            stack.bottomAnchor.constraint(
                lessThanOrEqualTo: contentView.bottomAnchor,
                constant: -20
            )
        ])

        return contentView
    }

    private func makeNameRow() -> NSView {
        let label = formLabel(
            localization.string("characterPack.builder.name")
        )
        let field = NSTextField(string: "My Runner")
        field.placeholderString = localization.string(
            "characterPack.builder.namePlaceholder"
        )
        nameField = field

        let stack = NSStackView(
            views: [label, field]
        )
        stack.orientation = .horizontal
        stack.spacing = 8
        label.widthAnchor.constraint(
            equalToConstant: 100
        ).isActive = true
        return stack
    }

    private func makeDefaultStateRow() -> NSView {
        let label = formLabel(
            localization.string("characterPack.builder.defaultState")
        )
        let popUp = NSPopUpButton(
            frame: .zero,
            pullsDown: false
        )
        popUp.addItems(
            withTitles: CharacterState.allCases.map {
                localization.characterState($0)
            }
        )
        if let runIndex = CharacterState.allCases.firstIndex(
            of: .run
        ) {
            popUp.selectItem(at: runIndex)
        }
        defaultStatePopUp = popUp

        let stack = NSStackView(
            views: [label, popUp]
        )
        stack.orientation = .horizontal
        stack.spacing = 8
        label.widthAnchor.constraint(
            equalToConstant: 100
        ).isActive = true
        return stack
    }

    private func makeButtonRow() -> NSView {
        let spacer = NSView()

        let cancelButton = NSButton(
            title: localization.string("action.cancel"),
            target: self,
            action: #selector(cancel)
        )
        cancelButton.keyEquivalent = "\u{1B}"

        let buildButton = NSButton(
            title: localization.string("characterPack.builder.build"),
            target: self,
            action: #selector(build)
        )
        buildButton.keyEquivalent = "\r"

        let stack = NSStackView(
            views: [
                spacer,
                cancelButton,
                buildButton
            ]
        )
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 8
        return stack
    }

    private func formLabel(_ text: String) -> NSTextField {
        let label = NSTextField(
            labelWithString: text
        )
        label.font = .systemFont(
            ofSize: NSFont.systemFontSize,
            weight: .medium
        )
        return label
    }

    private func chooseSource(
        for state: CharacterState,
        kind: CharacterPackClipKind
    ) {
        guard
            let row = rows[state],
            let selectedURL = sourcePicker.chooseSource(
                for: state,
                kind: kind
            )
        else {
            return
        }

        row.setSourceURL(selectedURL)
    }

    private func makeRequest() -> CharacterPackBuildRequest? {
        guard
            let nameField,
            let defaultStatePopUp
        else {
            return nil
        }

        let name = nameField.stringValue.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let clips = CharacterState.allCases.compactMap {
            rows[$0]?.buildClip
        }
        guard !name.isEmpty, !clips.isEmpty else {
            presentValidationWarning(
                localization.string("characterPack.builder.validation.nameAndClip")
            )
            return nil
        }

        let defaultIndex = defaultStatePopUp.indexOfSelectedItem
        guard CharacterState.allCases.indices.contains(
            defaultIndex
        ) else {
            return nil
        }
        let defaultState = CharacterState.allCases[
            defaultIndex
        ]
        guard clips.contains(where: { $0.state == defaultState }) else {
            presentValidationWarning(
                localization.string("characterPack.builder.validation.defaultClip")
            )
            return nil
        }

        return CharacterPackBuildRequest(
            name: name,
            defaultState: defaultState,
            clips: clips
        )
    }

    private func presentValidationWarning(_ message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = localization.string("characterPack.builder.incomplete")
        alert.informativeText = message
        alert.runModal()
    }

    @objc
    private func build() {
        guard let request = makeRequest() else {
            return
        }

        result = request
        NSApplication.shared.stopModal(
            withCode: .OK
        )
    }

    @objc
    private func cancel() {
        result = nil
        NSApplication.shared.stopModal(
            withCode: .cancel
        )
    }

    func windowWillClose(_ notification: Notification) {
        guard
            let closingPanel = notification.object as? NSPanel,
            closingPanel === panel,
            NSApplication.shared.modalWindow === closingPanel
        else {
            return
        }

        result = nil
        NSApplication.shared.stopModal(
            withCode: .cancel
        )
    }
}
