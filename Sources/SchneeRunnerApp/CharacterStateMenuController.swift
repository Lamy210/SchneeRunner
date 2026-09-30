import AppKit
import SchneeRunnerCore

@MainActor
final class CharacterStateMenuController: NSObject {
    let rootItem = NSMenuItem(
        title: "Character State",
        action: nil,
        keyEquivalent: ""
    )

    var onSelection: ((CharacterState?) -> Void)?

    private let stateMenu = NSMenu(title: "Character State")
    private let automaticItem = NSMenuItem(
        title: "Automatic",
        action: nil,
        keyEquivalent: ""
    )
    private var stateItems: [CharacterState: NSMenuItem] = [:]

    override init() {
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
                title: state.displayName,
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
