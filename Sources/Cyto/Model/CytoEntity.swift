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
    public var eyeTarget: CGPoint
    public var eyeOffset: CGPoint
    public var blinkFactor: CGFloat // 0.0 open, 1.0 closed
    public var squishX: CGFloat
    public var squishY: CGFloat
    
    // Floating & Headphone Dynamics
    public var floatPhase: CGFloat
    public var wispPhase: CGFloat
    public var headphoneGlowPhase: CGFloat
    
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
    
    public var currentLedgeY: CGFloat?
    public var isBeingInteractedWith: Bool = false
    public var affection: CGFloat = 0.5
    public var energy: CGFloat = 0.95
    
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
        self.eyeTarget = .zero
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
    
    public var boundingBox: CGRect {
        CGRect(
            x: position.x - (size.width * squishX) / 2.0,
            y: position.y,
            width: size.width * squishX,
            height: size.height * squishY
        )
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
    
    public func registerUserTyping(isFast: Bool = false) {
        self.isTypingObserved = true
        self.typingTimer = 2.2
        
        // Wake up immediately if sleeping
        if state == .sleeping {
            self.state = .idle
            self.mood = .calm
        }
        
        // Tilt head curiously towards keyboard
        if abs(curiousTilt) < 0.01 {
            curiousTilt = Bool.random() ? 0.12 : -0.12
        }
        
        // Expression responds to typing flow
        if isFast || focusTier == .inFlow {
            self.expression = .focused // > < focused coder face
        } else {
            self.expression = .curious // cute curious head tilt
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
