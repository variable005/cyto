import Foundation
import CoreGraphics

public final class CytoEntity {
    public var position: CGPoint
    public var velocity: CGVector
    public var size: CGSize
    public var state: CytoState
    public var mood: CytoMood
    public var focusTier: FocusTier
    
    // Jelly Character Identity
    public var expression: JellyExpression
    public var accessory: JellyAccessory
    
    public var facingDirection: CGFloat // -1.0 = left, 1.0 = right
    public var eyeOffset: CGPoint
    public var blinkFactor: CGFloat // 0.0 open, 1.0 closed
    public var squishX: CGFloat
    public var squishY: CGFloat
    
    // Floating & Headphone Dynamics
    public var floatPhase: CGFloat
    public var wispPhase: CGFloat
    public var headphoneGlowPhase: CGFloat
    
    // Secondary Motion & Cloth Dynamics
    public var skirtClothSkew: CGFloat = 0.0
    public var headphoneSecondaryTilt: CGFloat = 0.0
    public var headphoneSecondaryVelocity: CGFloat = 0.0
    
    public var stateTimer: TimeInterval
    public var stateDuration: TimeInterval
    public var blinkTimer: TimeInterval
    public var breathPhase: CGFloat
    public var walkPhase: CGFloat
    
    // Typing Curiosity & Dialogue
    public var isTypingObserved: Bool = false
    public var typingTimer: TimeInterval = 0.0
    public var curiousTilt: CGFloat = 0.0
    public var speechBubbleText: String? = nil
    public var speechBubbleTimer: TimeInterval = 0.0
    public var speechBubbleMaxDuration: TimeInterval = 2.4
    
    // Music Synchronization & Notes
    public var isMusicPlaying: Bool = false
    public var musicTempoPhase: CGFloat = 0.0
    public var musicNoteTimer: Double = 0.0
    public var musicNotes: [MusicNoteParticle] = []
    
    // System Context & Circadian Rhythm
    public var isNightMode: Bool = false
    public var isLowBattery: Bool = false
    public var batteryPercentage: Int? = nil
    
    // Pomodoro Focus Timer & Micro-Breaks
    public var isFocusSessionActive: Bool = false
    public var focusSessionRemaining: TimeInterval = 0.0
    public var focusSessionTotalDuration: TimeInterval = 25.0 * 60.0
    public var isEyeBreakActive: Bool = false
    public var eyeBreakTimer: TimeInterval = 0.0
    
    public var currentLedgeY: CGFloat?
    public var perchedWindowID: CGWindowID?
    public var perchedLedgeRect: CGRect?
    public var isBeingInteractedWith: Bool = false
    public var affection: CGFloat = 0.5
    
    public init(initialPosition: CGPoint) {
        self.position = initialPosition
        self.velocity = CGVector(dx: 0, dy: 0)
        self.size = CGSize(width: 82, height: 88)
        self.state = .falling
        self.mood = .calm
        self.focusTier = .steady
        self.expression = .neutral
        self.accessory = .none
        
        self.facingDirection = 1.0
        self.eyeOffset = .zero
        self.blinkFactor = 0.0
        self.squishX = 1.0
        self.squishY = 1.0
        
        self.floatPhase = 0.0
        self.wispPhase = 0.0
        self.headphoneGlowPhase = 0.0
        
        self.stateTimer = 0.0
        self.stateDuration = 4.0
        self.blinkTimer = Double.random(in: 2.0...5.0)
        self.breathPhase = 0.0
        self.walkPhase = 0.0
    }
    
    public func applySquish(x: CGFloat, y: CGFloat) {
        self.squishX = x
        self.squishY = y
    }
    
    public func say(_ text: String, duration: TimeInterval = 2.4) {
        self.speechBubbleText = text
        self.speechBubbleTimer = duration
        self.speechBubbleMaxDuration = duration
    }
    
    public func transitionToTypingEmotion(_ emotion: JellyExpression) {
        self.isTypingObserved = true
        self.typingTimer = 2.8
        
        // Wake up immediately if sleeping
        if state == .sleeping {
            self.state = .idle
            self.mood = .calm
        }
        
        self.expression = emotion
        
        // Dynamic head tilt matching the emotion
        switch emotion {
        case .curious:
            self.curiousTilt = 0.12
        case .confused:
            self.curiousTilt = -0.14
        case .focused:
            self.curiousTilt = 0.05
        case .surprised:
            self.curiousTilt = 0.0
        case .happy, .excited:
            self.curiousTilt = 0.0
        default:
            self.curiousTilt = 0.0
        }
    }
    
    public func registerTypingBurstCompleted() {
        self.expression = .excited
        
        let praiseQuotes = [
            "You got this!",
            "Great rhythm!",
            "Keep it up!",
            "Super focus!",
            "So smooth~",
            "Floating along!",
            "Giggle~"
        ]
        say(praiseQuotes.randomElement() ?? "You got this!", duration: 2.4)
        
        // Joyful floaty hop
        if state.isGrounded {
            self.velocity.dy = 180.0
            self.transition(to: .falling, duration: 0.5)
            self.applySquish(x: 0.88, y: 1.18)
        }
    }
    
    public func registerDirectTap() {
        // Direct tap on Jelly
        let tapQuotes = [
            "Boo!",
            "Hehe~",
            "Here with you!",
            "Need a break?",
            "Feeling cozy~",
            "I'm listening~",
            "Stay hydrated!"
        ]
        say(tapQuotes.randomElement() ?? "Boo!", duration: 2.4)
        self.expression = .happy
        self.applySquish(x: 1.15, y: 0.86)
        if state.isGrounded {
            self.velocity.dy = 160.0
            self.transition(to: .falling, duration: 0.4)
        }
    }
    
    public func registerEnterPressed() {
        self.expression = .excited // Excited sparkling face!
        
        let jellyQuotes = [
            "Boo!",
            "You got this!",
            "Yay!",
            "Super clean!",
            "Wonderful~",
            "Giggle~",
            "Great work!",
            "Hehe~"
        ]
        
        let chosen = jellyQuotes.randomElement() ?? "You got this!"
        say(chosen, duration: 2.4)
        
        // Joyful floaty hop with headphone glow pulse
        if state.isGrounded {
            self.velocity.dy = 200.0
            self.transition(to: .falling, duration: 0.5)
            self.applySquish(x: 0.84, y: 1.22)
        }
    }
    
    public func transition(to newState: CytoState, duration: TimeInterval = 4.0) {
        guard state != newState else { return }
        self.state = newState
        self.stateTimer = 0.0
        self.stateDuration = duration
        
        switch newState {
        case .sleeping:
            self.mood = .sleepy
            self.expression = .sleepy
            self.applySquish(x: 1.03, y: 0.97) // Soft comfortable resting settle
        case .sitting:
            self.expression = .happy // ^ ^ sitting resting pose
        case .walking:
            self.walkPhase = 0.0
            self.expression = .neutral
        case .petted:
            self.affection = min(1.0, affection + 0.1)
            self.mood = .happy
            self.expression = .happy
        case .mischievous:
            self.mood = .playful
            self.expression = .excited
        case .dragged:
            self.expression = .surprised
        default:
            if !isTypingObserved {
                self.expression = .neutral
            }
        }
    }
}

public struct MusicNoteParticle: Sendable {
    public var position: CGPoint
    public var velocity: CGPoint
    public var symbol: String
    public var life: Double
    public var maxLife: Double
    public var scale: CGFloat
    
    public init(position: CGPoint, velocity: CGPoint, symbol: String, life: Double = 1.3) {
        self.position = position
        self.velocity = velocity
        self.symbol = symbol
        self.life = life
        self.maxLife = life
        self.scale = 1.0
    }
}

