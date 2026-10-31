import AppKit

public final class MenuBarController {
    private var statusItem: NSStatusItem?
    private let onSummon: () -> Void
    private let onToggleSleep: () -> Void
    private let onToggleInteractive: () -> Void
    private let onSelectCharacter: (CharacterID) -> Void
    private let onQuit: () -> Void
    
    private var moodItem: NSMenuItem?
    private var focusItem: NSMenuItem?
    private var sleepToggleItem: NSMenuItem?
    private var interactiveToggleItem: NSMenuItem?
    private var characterMenuItems: [CharacterID: NSMenuItem] = [:]
    
    public init(
        onSummon: @escaping () -> Void,
        onToggleSleep: @escaping () -> Void,
        onToggleInteractive: @escaping () -> Void,
        onSelectCharacter: @escaping (CharacterID) -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.onSummon = onSummon
        self.onToggleSleep = onToggleSleep
        self.onToggleInteractive = onToggleInteractive
        self.onSelectCharacter = onSelectCharacter
        self.onQuit = onQuit
        setupStatusBar()
    }
    
    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem?.button else { return }
        
        button.title = "cyto"
        button.font = NSFont.monospacedSystemFont(ofSize: 12.0, weight: .semibold)
        
        let menu = NSMenu()
        
        let titleItem = NSMenuItem(title: "Cyto Desktop Companion", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        menu.addItem(NSMenuItem.separator())
        
        let mood = NSMenuItem(title: "Mood: Calm", action: nil, keyEquivalent: "")
        mood.isEnabled = false
        menu.addItem(mood)
        self.moodItem = mood
        
        let focus = NSMenuItem(title: "Focus: Steady", action: nil, keyEquivalent: "")
        focus.isEnabled = false
        menu.addItem(focus)
        self.focusItem = focus
        
        menu.addItem(NSMenuItem.separator())
        
        // Character Roster Submenu organized by category
        let rosterMenu = NSMenu()
        let rosterItem = NSMenuItem(title: "Characters", action: nil, keyEquivalent: "")
        rosterItem.submenu = rosterMenu
        
        for category in CharacterCategory.allCases {
            let catHeader = NSMenuItem(title: category.rawValue, action: nil, keyEquivalent: "")
            catHeader.isEnabled = false
            rosterMenu.addItem(catHeader)
            
            let charactersInCategory = CharacterID.allCases.filter { $0.category == category }
            for char in charactersInCategory {
                let label = "\(char.name) — \(char.title)"
                let item = NSMenuItem(title: label, action: #selector(characterSelected(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = char
                rosterMenu.addItem(item)
                characterMenuItems[char] = item
            }
            rosterMenu.addItem(NSMenuItem.separator())
        }
        
        // Remove trailing separator if present
        if let lastItem = rosterMenu.items.last, lastItem.isSeparatorItem {
            rosterMenu.removeItem(lastItem)
        }
        
        menu.addItem(rosterItem)
        menu.addItem(NSMenuItem.separator())
        
        let interactiveItem = NSMenuItem(title: "Clickable: Enabled", action: #selector(interactiveClicked), keyEquivalent: "i")
        interactiveItem.target = self
        menu.addItem(interactiveItem)
        self.interactiveToggleItem = interactiveItem
        
        let summonItem = NSMenuItem(title: "Summon to Center", action: #selector(summonClicked), keyEquivalent: "s")
        summonItem.target = self
        menu.addItem(summonItem)
        
        let sleepItem = NSMenuItem(title: "Rest / Wake", action: #selector(sleepClicked), keyEquivalent: "r")
        sleepItem.target = self
        menu.addItem(sleepItem)
        self.sleepToggleItem = sleepItem
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit Cyto", action: #selector(quitClicked), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
    }
    
    public func update(mood: CytoMood, focus: FocusTier, character: CharacterID, isSleeping: Bool, isInteractive: Bool) {
        moodItem?.title = "Mood: \(mood.rawValue.capitalized)"
        focusItem?.title = "Focus: \(focus.rawValue.capitalized)"
        sleepToggleItem?.title = isSleeping ? "Wake Up" : "Put to Rest"
        interactiveToggleItem?.title = isInteractive ? "Clickable: Enabled" : "Clickable: Disabled (Pass-Through)"
        
        for (charID, menuItem) in characterMenuItems {
            menuItem.state = (charID == character) ? .on : .off
        }
    }
    
    @objc private func characterSelected(_ sender: NSMenuItem) {
        guard let char = sender.representedObject as? CharacterID else { return }
        onSelectCharacter(char)
    }
    
    @objc private func summonClicked() {
        onSummon()
    }
    
    @objc private func sleepClicked() {
        onToggleSleep()
    }
    
    @objc private func interactiveClicked() {
        onToggleInteractive()
    }
    
    @objc private func quitClicked() {
        onQuit()
    }
}
