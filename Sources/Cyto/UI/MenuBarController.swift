import AppKit
import ApplicationServices

public final class MenuBarController {
    private var statusItem: NSStatusItem?
    private let onSummon: () -> Void
    private let onToggleSleep: () -> Void
    private let onToggleInteractive: () -> Void
    private let onSelectExpression: (JellyExpression) -> Void
    private let onSelectAccessory: (JellyAccessory) -> Void
    private let onQuit: () -> Void
    
    private var moodItem: NSMenuItem?
    private var focusItem: NSMenuItem?
    private var sleepToggleItem: NSMenuItem?
    private var interactiveToggleItem: NSMenuItem?
    private var accessibilityItem: NSMenuItem?
    private var expressionMenuItems: [JellyExpression: NSMenuItem] = [:]
    private var accessoryMenuItems: [JellyAccessory: NSMenuItem] = [:]
    
    public init(
        onSummon: @escaping () -> Void,
        onToggleSleep: @escaping () -> Void,
        onToggleInteractive: @escaping () -> Void,
        onSelectExpression: @escaping (JellyExpression) -> Void,
        onSelectAccessory: @escaping (JellyAccessory) -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.onSummon = onSummon
        self.onToggleSleep = onToggleSleep
        self.onToggleInteractive = onToggleInteractive
        self.onSelectExpression = onSelectExpression
        self.onSelectAccessory = onSelectAccessory
        self.onQuit = onQuit
        setupStatusBar()
    }
    
    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem?.button else { return }
        
        button.title = "cyto"
        button.font = NSFont.monospacedSystemFont(ofSize: 12.0, weight: .semibold)
        
        let menu = NSMenu()
        
        let titleItem = NSMenuItem(title: "Cyto The Desktop Ghost", action: nil, keyEquivalent: "")
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
        
        // Expressions Submenu
        let exprMenu = NSMenu()
        let exprItem = NSMenuItem(title: "Expression", action: nil, keyEquivalent: "")
        exprItem.submenu = exprMenu
        
        for expr in JellyExpression.allCases {
            let item = NSMenuItem(title: expr.rawValue, action: #selector(expressionSelected(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = expr
            exprMenu.addItem(item)
            expressionMenuItems[expr] = item
        }
        menu.addItem(exprItem)
        
        // Accessories Submenu
        let accMenu = NSMenu()
        let accItem = NSMenuItem(title: "Accessory", action: nil, keyEquivalent: "")
        accItem.submenu = accMenu
        
        for acc in JellyAccessory.allCases {
            let item = NSMenuItem(title: acc.rawValue, action: #selector(accessorySelected(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = acc
            accMenu.addItem(item)
            accessoryMenuItems[acc] = item
        }
        menu.addItem(accItem)
        
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
        
        let axTrusted = AXIsProcessTrusted()
        let axTitle = axTrusted ? "Enter Key Reactions: Enabled" : "Enable Enter Key Reactions (Accessibility)..."
        let axItem = NSMenuItem(title: axTitle, action: #selector(accessibilityClicked), keyEquivalent: "")
        axItem.target = self
        menu.addItem(axItem)
        self.accessibilityItem = axItem
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit Cyto", action: #selector(quitClicked), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
    }
    
    public func update(
        mood: CytoMood,
        focus: FocusTier,
        expression: JellyExpression,
        accessory: JellyAccessory,
        isSleeping: Bool,
        isInteractive: Bool
    ) {
        moodItem?.title = "Mood: \(mood.rawValue.capitalized)"
        focusItem?.title = "Focus: \(focus.rawValue.capitalized)"
        sleepToggleItem?.title = isSleeping ? "Wake Up" : "Put to Rest"
        interactiveToggleItem?.title = isInteractive ? "Clickable: Enabled" : "Clickable: Disabled (Pass-Through)"
        
        for (itemExpr, menuItem) in expressionMenuItems {
            menuItem.state = (itemExpr == expression) ? .on : .off
        }
        for (itemAcc, menuItem) in accessoryMenuItems {
            menuItem.state = (itemAcc == accessory) ? .on : .off
        }
    }
    
    @objc private func expressionSelected(_ sender: NSMenuItem) {
        guard let expr = sender.representedObject as? JellyExpression else { return }
        onSelectExpression(expr)
    }
    
    @objc private func accessorySelected(_ sender: NSMenuItem) {
        guard let acc = sender.representedObject as? JellyAccessory else { return }
        onSelectAccessory(acc)
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
    
    @objc private func accessibilityClicked() {
        if !AXIsProcessTrusted() {
            let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
            _ = AXIsProcessTrustedWithOptions(options)
        }
        let isTrusted = AXIsProcessTrusted()
        accessibilityItem?.title = isTrusted ? "Enter Key Reactions: Enabled" : "Enable Enter Key Reactions (Accessibility)..."
    }
    
    @objc private func quitClicked() {
        onQuit()
    }
}
