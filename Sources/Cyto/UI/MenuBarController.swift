import AppKit
import ApplicationServices

public final class MenuBarController {
    private var statusItem: NSStatusItem?
    
    private var moodItem: NSMenuItem?
    private var workspaceItem: NSMenuItem?
    private var focusItem: NSMenuItem?
    private var musicItem: NSMenuItem?
    private var environmentItem: NSMenuItem?
    private var focusSessionItem: NSMenuItem?
    private var sleepToggleItem: NSMenuItem?
    private var interactiveToggleItem: NSMenuItem?
    private var focusSessionToggleItem: NSMenuItem?
    private var accessibilityItem: NSMenuItem?
    private var expressionMenuItems: [JellyExpression: NSMenuItem] = [:]
    private var accessoryMenuItems: [JellyAccessory: NSMenuItem] = [:]
    
    private let onSummon: () -> Void
    private let onToggleSleep: () -> Void
    private let onToggleInteractive: () -> Void
    private let onToggleFocusSession: () -> Void
    private let onTriggerEyeBreak: () -> Void
    private let onDropTreat: () -> Void
    private let onSelectExpression: (JellyExpression) -> Void
    private let onSelectAccessory: (JellyAccessory) -> Void
    private let onQuit: () -> Void
    
    public init(
        onSummon: @escaping () -> Void,
        onToggleSleep: @escaping () -> Void,
        onToggleInteractive: @escaping () -> Void,
        onToggleFocusSession: @escaping () -> Void,
        onTriggerEyeBreak: @escaping () -> Void,
        onDropTreat: @escaping () -> Void,
        onSelectExpression: @escaping (JellyExpression) -> Void,
        onSelectAccessory: @escaping (JellyAccessory) -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.onSummon = onSummon
        self.onToggleSleep = onToggleSleep
        self.onToggleInteractive = onToggleInteractive
        self.onToggleFocusSession = onToggleFocusSession
        self.onTriggerEyeBreak = onTriggerEyeBreak
        self.onDropTreat = onDropTreat
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
        
        let workspace = NSMenuItem(title: "Workspace: Desktop", action: nil, keyEquivalent: "")
        workspace.isEnabled = false
        menu.addItem(workspace)
        self.workspaceItem = workspace
        
        let focus = NSMenuItem(title: "Focus: Steady", action: nil, keyEquivalent: "")
        focus.isEnabled = false
        menu.addItem(focus)
        self.focusItem = focus
        
        let music = NSMenuItem(title: "Music: Idle", action: nil, keyEquivalent: "")
        music.isEnabled = false
        menu.addItem(music)
        self.musicItem = music
        
        let env = NSMenuItem(title: "Ambient: Daylight", action: nil, keyEquivalent: "")
        env.isEnabled = false
        menu.addItem(env)
        self.environmentItem = env
        
        let focusSprint = NSMenuItem(title: "Pomodoro: Inactive", action: nil, keyEquivalent: "")
        focusSprint.isEnabled = false
        menu.addItem(focusSprint)
        self.focusSessionItem = focusSprint
        
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
        
        let focusToggle = NSMenuItem(title: "Start 25m Pomodoro Sprint", action: #selector(focusSessionClicked), keyEquivalent: "f")
        focusToggle.target = self
        menu.addItem(focusToggle)
        self.focusSessionToggleItem = focusToggle
        
        let eyeBreak = NSMenuItem(title: "20s Eye Strain Break (20-20-20)", action: #selector(eyeBreakClicked), keyEquivalent: "e")
        eyeBreak.target = self
        menu.addItem(eyeBreak)
        
        let treatItem = NSMenuItem(title: "Drop Coffee Treat", action: #selector(treatClicked), keyEquivalent: "t")
        treatItem.target = self
        menu.addItem(treatItem)
        
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
        isInteractive: Bool,
        musicTrack: String? = nil,
        isNight: Bool = false,
        batteryPercent: Int? = nil,
        isLowBattery: Bool = false,
        isFocusActive: Bool = false,
        focusRemainingSeconds: TimeInterval = 0.0,
        activeAppName: String? = nil,
        activeAppCategory: ActiveAppCategory = .other
    ) {
        moodItem?.title = "Mood: \(mood.rawValue.capitalized)"
        if let appName = activeAppName, !appName.isEmpty {
            workspaceItem?.title = "Workspace: \(appName) (\(activeAppCategory.rawValue))"
        } else {
            workspaceItem?.title = "Workspace: \(activeAppCategory.rawValue)"
        }
        focusItem?.title = "Focus: \(focus.rawValue.capitalized)"
        
        if let track = musicTrack, !track.isEmpty {
            musicItem?.title = "Music: Playing (\(track))"
        } else {
            musicItem?.title = "Music: Idle"
        }
        
        var envDesc = isNight ? "Nocturnal Glow" : "Daylight"
        if let pct = batteryPercent {
            envDesc += " • \(pct)%"
        }
        if isLowBattery {
            envDesc += " (Low Power)"
        }
        environmentItem?.title = "Ambient: \(envDesc)"
        
        if isFocusActive {
            let mins = Int(focusRemainingSeconds) / 60
            let secs = Int(focusRemainingSeconds) % 60
            focusSessionItem?.title = String(format: "Pomodoro: %02d:%02d remaining", mins, secs)
            focusSessionToggleItem?.title = "Cancel Pomodoro Sprint"
        } else {
            focusSessionItem?.title = "Pomodoro: Inactive"
            focusSessionToggleItem?.title = "Start 25m Pomodoro Sprint"
        }
        
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
    
    @objc private func focusSessionClicked() {
        onToggleFocusSession()
    }
    
    @objc private func eyeBreakClicked() {
        onTriggerEyeBreak()
    }
    
    @objc private func treatClicked() {
        onDropTreat()
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
