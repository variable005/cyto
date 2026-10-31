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
    private var keyMonitor: Any?
    private var lastFrameTime: Date = Date()
    private var cachedLedges: [Ledge] = []
    private var lastLedgeQueryTime: Date = Date()
    private var isInteractive: Bool = true
    
    // Zero-permission hardware keystroke & cadence tracking
    private var previousKeyIdle: Double = 999.0
    private var lastKeyRegisteredTime: Date = .distantPast
    private var typingBurstStartTime: Date = Date()
    private var burstKeystrokeCount: Int = 0
    private var hasCelebratedCurrentBurst: Bool = false
    private var lastSpokenTime: Date = Date()
    
    public init() {
        let initialPoint = CGPoint(x: 450, y: 550)
        self.entity = CytoEntity(initialPosition: initialPoint)
        self.windowTracker = WindowTracker()
        self.physicsEngine = PhysicsEngine()
        self.activityEngine = ActivityEngine()
    }
    
    public func start() {
        let panel = OverlayPanel(initialPosition: entity.position)
        let view = CytoView(
            frame: NSRect(origin: .zero, size: OverlayPanel.defaultSize),
            entity: entity
        )
        
        panel.contentView = view
        panel.orderFrontRegardless()
        
        self.overlayPanel = panel
        self.cytoView = view
        
        // Setup menu bar controller for Jelly
        self.menuBarController = MenuBarController(
            onSummon: { [weak self] in self?.summonToCenter() },
            onToggleSleep: { [weak self] in self?.toggleSleep() },
            onToggleInteractive: { [weak self] in self?.toggleInteractive() },
            onSelectExpression: { [weak self] expr in self?.selectExpression(expr) },
            onSelectAccessory: { [weak self] acc in self?.selectAccessory(acc) },
            onQuit: { NSApp.terminate(nil) }
        )
        
        // Listen globally for typing cadence and Enter key
        setupKeyObserver()
        
        // Initial ledge calculation
        refreshLedges()
        
        // Start simulation loop (60Hz timer)
        self.lastFrameTime = Date()
        self.displayTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }
    
    private func setupKeyObserver() {
        keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self = self else { return }
            
            // Check for Enter / Return (keyCode 36 is Return, 76 is numpad Enter)
            if event.keyCode == 36 || event.keyCode == 76 {
                let now = Date()
                if now.timeIntervalSince(self.lastSpokenTime) > 12.0 {
                    self.lastSpokenTime = now
                    self.entity.registerEnterPressed()
                }
            }
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
        
        guard let screen = NSScreen.main, let view = cytoView, let panel = overlayPanel else { return }
        
        // 1. Periodically refresh walkable window ledges (every 0.5s)
        if now.timeIntervalSince(lastLedgeQueryTime) > 0.5 {
            refreshLedges()
        }
        
        // 2. Zero-permission real-time typing cadence & emotion cycling engine
        let keyIdle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .keyDown)
        let keyJustPressed = (keyIdle < previousKeyIdle && keyIdle < 1.0) ||
                             (keyIdle < 0.05 && now.timeIntervalSince(lastKeyRegisteredTime) > 0.04)
        
        if keyJustPressed {
            if burstKeystrokeCount == 0 {
                typingBurstStartTime = now
            }
            lastKeyRegisteredTime = now
            burstKeystrokeCount += 1
            hasCelebratedCurrentBurst = false
            
            // Rolling Keystrokes Per Second (KPS)
            let sessionDuration = max(0.2, now.timeIntervalSince(typingBurstStartTime))
            let kps = Double(burstKeystrokeCount) / sessionDuration
            
            // Dynamic Emotion Cycling based on typing progression & velocity:
            if burstKeystrokeCount <= 3 {
                // Phase 1: Waking up / Curious initial glance
                entity.transitionToTypingEmotion(.curious)
            } else if burstKeystrokeCount <= 12 {
                // Phase 2: Steady attentiveness
                entity.transitionToTypingEmotion(.focused)
            } else {
                // Phase 3: Flow acceleration
                if kps > 3.2 {
                    entity.transitionToTypingEmotion(.excited) // Fast rhythm!
                } else {
                    entity.transitionToTypingEmotion(.focused) // Sustained focus
                }
            }
        } else if burstKeystrokeCount > 0 {
            let pauseDuration = now.timeIntervalSince(lastKeyRegisteredTime)
            
            if pauseDuration >= 0.35 && pauseDuration < 1.2 {
                // Phase 4: Mid-flow pause / Thinking hesitation
                if burstKeystrokeCount > 16 {
                    entity.transitionToTypingEmotion(.surprised) // High-speed sudden pause
                } else if burstKeystrokeCount > 6 {
                    entity.transitionToTypingEmotion(.confused) // Thinking pause
                }
            } else if pauseDuration >= 1.2 && pauseDuration < 3.5 {
                // Phase 5: Thought / Sentence completed - warm happy smile
                entity.transitionToTypingEmotion(.happy)
                
                // Occasional praise bubble after a genuine 25+ key session (with 50s cooldown)
                if !hasCelebratedCurrentBurst && burstKeystrokeCount >= 25 {
                    if now.timeIntervalSince(lastSpokenTime) > 50.0 {
                        lastSpokenTime = now
                        hasCelebratedCurrentBurst = true
                        entity.registerTypingBurstCompleted()
                    }
                }
            } else if pauseDuration >= 3.5 {
                // Phase 6: Session completed: return smoothly to neutral gaze tracking
                burstKeystrokeCount = 0
                hasCelebratedCurrentBurst = false
                entity.isTypingObserved = false
                entity.curiousTilt = 0.0
                if entity.state != .sleeping && entity.state != .sitting {
                    entity.expression = .neutral
                }
            }
        }
        
        previousKeyIdle = keyIdle
        
        // Query focus tier
        let (focusTier, _) = activityEngine.updateFocusTier()
        entity.focusTier = focusTier
        
        // 3. Typing Curiosity Timers
        if entity.typingTimer > 0 {
            entity.typingTimer -= Double(dt)
            if entity.typingTimer <= 0 {
                entity.isTypingObserved = false
                entity.curiousTilt = 0.0
                if entity.state != .sleeping && entity.state != .sitting {
                    entity.expression = .neutral
                }
            }
        }
        
        // 4. Speech Bubble Timer
        if entity.speechBubbleTimer > 0 {
            entity.speechBubbleTimer -= Double(dt)
            if entity.speechBubbleTimer <= 0 {
                entity.speechBubbleText = nil
                if !entity.isTypingObserved && entity.state != .sleeping && entity.state != .sitting {
                    entity.expression = .neutral
                }
            }
        }
        
        // 5. Eye Gaze Tracking (look towards mouse cursor or look down intently when user types)
        if entity.isTypingObserved {
            entity.eyeOffset = CGPoint(x: 0, y: -2.2)
        } else {
            let mouseLoc = NSEvent.mouseLocation
            let dx = mouseLoc.x - entity.position.x
            let dy = mouseLoc.y - (entity.position.y + entity.size.height * 0.5)
            let dist = max(1.0, hypot(dx, dy))
            let maxGaze: CGFloat = 3.5
            entity.eyeOffset = CGPoint(
                x: (dx / dist) * min(maxGaze, dist * 0.05),
                y: (dy / dist) * min(maxGaze, dist * 0.05)
            )
        }
        
        // 6. Natural Blinking Loop
        entity.blinkTimer -= Double(dt)
        if entity.blinkTimer <= 0 {
            entity.blinkFactor = 1.0
            entity.blinkTimer = Double.random(in: 2.5...6.0)
        } else if entity.blinkFactor > 0 {
            entity.blinkFactor = max(0.0, entity.blinkFactor - CGFloat(dt * 6.0))
        }
        
        // 7. Behavioral Decision State Machine
        entity.stateTimer += Double(dt)
        if entity.stateTimer >= entity.stateDuration && entity.state.allowsDirectMotion && !entity.isBeingInteractedWith {
            decideNextBehavior()
        }
        
        // 8. Kinematics & Physics Step (Floaty Ghost Gravity)
        physicsEngine.update(entity: entity, deltaTime: dt, ledges: cachedLedges, screenBounds: screen.frame)
        
        // 9. Synchronize Window Origin with Entity Physics Position
        let targetOrigin = NSPoint(
            x: entity.position.x - OverlayPanel.defaultSize.width / 2.0,
            y: entity.position.y - 6.0
        )
        panel.setFrameOrigin(targetOrigin)
        
        // 10. Sync Menu Bar Status
        menuBarController?.update(
            mood: entity.mood,
            focus: entity.focusTier,
            expression: entity.expression,
            accessory: entity.accessory,
            isSleeping: entity.state == .sleeping,
            isInteractive: isInteractive
        )
        
        // 11. Trigger redraw
        view.needsDisplay = true
    }
    
    private func decideNextBehavior() {
        switch entity.focusTier {
        case .inFlow:
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
        entity.velocity.dx = dir * CGFloat.random(in: 28.0...55.0)
        entity.transition(to: .walking, duration: Double.random(in: 2.0...5.0))
    }
    
    public func selectExpression(_ expression: JellyExpression) {
        entity.expression = expression
        entity.applySquish(x: 1.15, y: 0.88)
    }
    
    public func selectAccessory(_ accessory: JellyAccessory) {
        entity.accessory = accessory
        entity.applySquish(x: 1.12, y: 0.90)
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
    
    public func toggleInteractive() {
        isInteractive.toggle()
        overlayPanel?.ignoresMouseEvents = !isInteractive
    }
    
    deinit {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
