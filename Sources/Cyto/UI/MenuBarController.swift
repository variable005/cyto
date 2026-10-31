import AppKit

public final class MenuBarController {
    private var statusItem: NSStatusItem?
    private let onSummon: () -> Void
    private let onToggleSleep: () -> Void
    private let onToggleInteractive: () -> Void
    private let onSelectSkin: (AnimeSkin) -> Void
    private let onQuit: () -> Void
    
    private var moodItem: NSMenuItem?
    private var focusItem: NSMenuItem?
    private var sleepToggleItem: NSMenuItem?
    private var interactiveToggleItem: NSMenuItem?
    private var skinMenuItems: [AnimeSkin: NSMenuItem] = [:]
    
    public init(
        onSummon: @escaping () -> Void,
        onToggleSleep: @escaping () -> Void,
        onToggleInteractive: @escaping () -> Void,
        onSelectSkin: @escaping (AnimeSkin) -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.onSummon = onSummon
        self.onToggleSleep = onToggleSleep
        self.onToggleInteractive = onToggleInteractive
        self.onSelectSkin = onSelectSkin
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
        
        // Anime Skins Submenu
        let skinsMenu = NSMenu()
        let skinsItem = NSMenuItem(title: "Anime Design", action: nil, keyEquivalent: "")
        skinsItem.submenu = skinsMenu
        
        for skin in AnimeSkin.allCases {
            let item = NSMenuItem(title: skin.displayName, action: #selector(skinSelected(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = skin
            skinsMenu.addItem(item)
            skinMenuItems[skin] = item
        }
        menu.addItem(skinsItem)
        
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
    
    public func update(mood: CytoMood, focus: FocusTier, skin: AnimeSkin, isSleeping: Bool, isInteractive: Bool) {
        moodItem?.title = "Mood: \(mood.rawValue.capitalized)"
        focusItem?.title = "Focus: \(focus.rawValue.capitalized)"
        sleepToggleItem?.title = isSleeping ? "Wake Up" : "Put to Rest"
        interactiveToggleItem?.title = isInteractive ? "Clickable: Enabled" : "Clickable: Disabled (Pass-Through)"
        
        // Update checkmarks on skins
        for (itemSkin, menuItem) in skinMenuItems {
            menuItem.state = (itemSkin == skin) ? .on : .off
        }
    }
    
    @objc private func skinSelected(_ sender: NSMenuItem) {
        guard let skin = sender.representedObject as? AnimeSkin else { return }
        onSelectSkin(skin)
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
