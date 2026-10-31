import AppKit

public final class MenuBarController {
    private var statusItem: NSStatusItem?
    private let onSummon: () -> Void
    private let onToggleSleep: () -> Void
    private let onToggleInteractive: () -> Void
    private let onSelectAura: (GhostAura) -> Void
    private let onQuit: () -> Void
    
    private var moodItem: NSMenuItem?
    private var focusItem: NSMenuItem?
    private var sleepToggleItem: NSMenuItem?
    private var interactiveToggleItem: NSMenuItem?
    private var auraMenuItems: [GhostAura: NSMenuItem] = [:]
    
    public init(
        onSummon: @escaping () -> Void,
        onToggleSleep: @escaping () -> Void,
        onToggleInteractive: @escaping () -> Void,
        onSelectAura: @escaping (GhostAura) -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.onSummon = onSummon
        self.onToggleSleep = onToggleSleep
        self.onToggleInteractive = onToggleInteractive
        self.onSelectAura = onSelectAura
        self.onQuit = onQuit
        setupStatusBar()
    }
    
    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem?.button else { return }
        
        button.title = "cyto"
        button.font = NSFont.monospacedSystemFont(ofSize: 12.0, weight: .semibold)
        
        let menu = NSMenu()
        
        let titleItem = NSMenuItem(title: "Cyto Ghost Companion", action: nil, keyEquivalent: "")
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
        
        // Ghost Aura Menu
        let auraMenu = NSMenu()
        let auraItem = NSMenuItem(title: "Ghost Aura", action: nil, keyEquivalent: "")
        auraItem.submenu = auraMenu
        
        for aura in GhostAura.allCases {
            let item = NSMenuItem(title: aura.displayName, action: #selector(auraSelected(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = aura
            auraMenu.addItem(item)
            auraMenuItems[aura] = item
        }
        menu.addItem(auraItem)
        
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
    
    public func update(mood: CytoMood, focus: FocusTier, aura: GhostAura, isSleeping: Bool, isInteractive: Bool) {
        moodItem?.title = "Mood: \(mood.rawValue.capitalized)"
        focusItem?.title = "Focus: \(focus.rawValue.capitalized)"
        sleepToggleItem?.title = isSleeping ? "Wake Up" : "Put to Rest"
        interactiveToggleItem?.title = isInteractive ? "Clickable: Enabled" : "Clickable: Disabled (Pass-Through)"
        
        for (itemAura, menuItem) in auraMenuItems {
            menuItem.state = (itemAura == aura) ? .on : .off
        }
    }
    
    @objc private func auraSelected(_ sender: NSMenuItem) {
        guard let aura = sender.representedObject as? GhostAura else { return }
        onSelectAura(aura)
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
