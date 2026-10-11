import AppKit
import SchneeRunnerCore

@MainActor
final class CharacterStateMenuController: NSObject {
    let rootItem: NSMenuItem

    var onSelection: ((CharacterState?) -> Void)?

    private let localization: AppLocalization
    private let stateMenu: NSMenu
    private let automaticItem: NSMenuItem
    private var stateItems: [CharacterState: NSMenuItem] = [:]

    init(localization: AppLocalization = .current) {
        self.localization = localization
        rootItem = NSMenuItem(
            title: localization.string("characterState.root"),
            action: nil,
            keyEquivalent: ""
        )
        stateMenu = NSMenu(title: localization.string("characterState.root"))
        automaticItem = NSMenuItem(
            title: localization.string("characterState.automatic"),
            action: nil,
            keyEquivalent: ""
        )
        super.init()
        configureMenu()
        setSelection(nil)
    }

    func setSelection(_ state: CharacterState?) {
        automaticItem.state = state == nil ? .on : .off

        for (candidate, item) in stateItems {
            item.state = candidate == state ? .on : .off
        }
    }

    private func configureMenu() {
        automaticItem.target = self
        automaticItem.action = #selector(selectAutomatic)
        stateMenu.addItem(automaticItem)
        stateMenu.addItem(.separator())

        for state in CharacterState.allCases {
            let item = NSMenuItem(
                title: localization.characterState(state),
                action: #selector(selectState(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = state.rawValue
            stateItems[state] = item
            stateMenu.addItem(item)
        }

        rootItem.submenu = stateMenu
    }

    @objc
    private func selectAutomatic() {
        onSelection?(nil)
    }

    @objc
    private func selectState(_ sender: NSMenuItem) {
        guard
            let rawValue = sender.representedObject as? String,
            let state = CharacterState(rawValue: rawValue)
        else {
            return
        }

        onSelection?(state)
    }
}
