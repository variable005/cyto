import AppKit
import CoreGraphics

public final class CytoController: @unchecked Sendable {
    private let entity: CytoEntity
    private let windowTracker: WindowTracker
    private let physicsEngine: PhysicsEngine
    private let activityEngine: ActivityEngine
    
    private var overlayPanel: OverlayPanel?
    private var cytoView: CytoView?
    private var menuBarController: MenuBarController?
    
    private var displayTimer: Timer?
    private var lastFrameTime: Date = Date()
    private var cachedLedges: [Ledge] = []
    private var lastLedgeQueryTime: Date = Date()
    
    public init() {
        let initialPoint = CGPoint(x: 400, y: 600)
        self.entity = CytoEntity(initialPosition: initialPoint)
        self.windowTracker = WindowTracker()
        self.physicsEngine = PhysicsEngine()
        self.activityEngine = ActivityEngine()
    }
    
    public func start() {
        guard let screen = NSScreen.main else { return }
        
        let screenFrame = screen.frame
        let panel = OverlayPanel(contentRect: screenFrame)
        let view = CytoView(frame: NSRect(origin: .zero, size: screenFrame.size), entity: entity)
        
        panel.contentView = view
        panel.orderFrontRegardless()
        
        self.overlayPanel = panel
        self.cytoView = view
        
        // Setup menu bar controller
        self.menuBarController = MenuBarController(
            onSummon: { [weak self] in self?.summonToCenter() },
            onToggleSleep: { [weak self] in self?.toggleSleep() },
            onQuit: { NSApp.terminate(nil) }
        )
        
        // Initial ledge calculation
        refreshLedges()
        
        // Start simulation loop (60Hz timer)
        self.lastFrameTime = Date()
        self.displayTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }
    
    private func refreshLedges() {
        guard let screen = NSScreen.main else { return }
        let selfWindowID = overlayPanel.map { CGWindowID($0.windowNumber) }
        self.cachedLedges = windowTracker.fetchWalkableLedges(excludingWindowID: selfWindowID, screen: screen)
        self.lastLedgeQueryTime = Date()
    }
    
    private func tick() {
        let now = Date()
        let dt = CGFloat(min(0.05, now.timeIntervalSince(lastFrameTime)))
        lastFrameTime = now
        
        guard let screen = NSScreen.main, let view = cytoView else { return }
        
        // 1. Periodically refresh walkable window ledges (every 0.5s)
        if now.timeIntervalSince(lastLedgeQueryTime) > 0.5 {
            refreshLedges()
        }
        
        // 2. Query activity & focus cadence
        let (focusTier, _) = activityEngine.updateFocusTier()
        entity.focusTier = focusTier
        
        // 3. Eye Gaze Tracking (look towards mouse cursor)
        let mouseLoc = NSEvent.mouseLocation
        let dx = mouseLoc.x - entity.position.x
        let dy = mouseLoc.y - (entity.position.y + entity.size.height * 0.5)
        let dist = max(1.0, hypot(dx, dy))
        let maxGaze: CGFloat = 3.5
        entity.eyeOffset = CGPoint(
            x: (dx / dist) * min(maxGaze, dist * 0.05),
            y: (dy / dist) * min(maxGaze, dist * 0.05)
        )
        
        // 4. Natural Blinking Loop
        entity.blinkTimer -= Double(dt)
        if entity.blinkTimer <= 0 {
            entity.blinkFactor = 1.0
            entity.blinkTimer = Double.random(in: 2.5...6.0)
        } else if entity.blinkFactor > 0 {
            entity.blinkFactor = max(0.0, entity.blinkFactor - CGFloat(dt * 6.0))
        }
        
        // 5. Behavioral Decision State Machine
        entity.stateTimer += Double(dt)
        if entity.stateTimer >= entity.stateDuration && entity.state.allowsDirectMotion && !entity.isBeingInteractedWith {
            decideNextBehavior()
        }
        
        // 6. Kinematics & Physics Step
        physicsEngine.update(entity: entity, deltaTime: dt, ledges: cachedLedges, screenBounds: screen.frame)
        
        // 7. Sync Menu Bar Status
        menuBarController?.update(
            mood: entity.mood,
            focus: entity.focusTier,
            isSleeping: entity.state == .sleeping
        )
        
        // 8. Trigger redraw
        view.needsDisplay = true
    }
    
    private func decideNextBehavior() {
        // Behavioral branching influenced by user focus state
        switch entity.focusTier {
        case .inFlow:
            // Soothed by continuous rhythm: rest, sleep, or gentle idle
            let roll = Double.random(in: 0...1)
            if roll < 0.45 {
                entity.transition(to: .sleeping, duration: Double.random(in: 12.0...30.0))
            } else if roll < 0.75 {
                entity.transition(to: .sitting, duration: Double.random(in: 6.0...12.0))
            } else {
                entity.transition(to: .idle, duration: Double.random(in: 3.0...6.0))
            }
            
        case .steady:
            let roll = Double.random(in: 0...1)
            if roll < 0.40 {
                startWalking()
            } else if roll < 0.75 {
                entity.transition(to: .idle, duration: Double.random(in: 3.0...7.0))
            } else {
                entity.transition(to: .sitting, duration: Double.random(in: 4.0...8.0))
            }
            
        case .wandering, .idle:
            // Curious or restless wandering when idle
            let roll = Double.random(in: 0...1)
            if roll < 0.60 {
                startWalking()
            } else if roll < 0.85 {
                entity.transition(to: .curious, duration: Double.random(in: 4.0...8.0))
            } else {
                entity.transition(to: .mischievous, duration: Double.random(in: 4.0...7.0))
            }
        }
    }
    
    private func startWalking() {
        let dir: CGFloat = Bool.random() ? 1.0 : -1.0
        entity.facingDirection = dir
        entity.velocity.dx = dir * CGFloat.random(in: 35.0...65.0)
        entity.transition(to: .walking, duration: Double.random(in: 2.0...5.0))
    }
    
    public func summonToCenter() {
        guard let screen = NSScreen.main else { return }
        let center = CGPoint(x: screen.frame.midX, y: screen.frame.midY)
        entity.position = center
        entity.velocity = .zero
        entity.transition(to: .falling)
        entity.applySquish(x: 1.25, y: 0.75)
    }
    
    public func toggleSleep() {
        if entity.state == .sleeping {
            entity.transition(to: .idle, duration: 4.0)
            entity.mood = .calm
        } else {
            entity.transition(to: .sleeping, duration: 60.0)
        }
    }
}
