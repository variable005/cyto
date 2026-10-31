import Foundation
import CoreGraphics

public final class CytoEntity {
    public var position: CGPoint
    public var velocity: CGVector
    public var size: CGSize
    public var state: CytoState
    public var mood: CytoMood
    public var focusTier: FocusTier
    public var character: CharacterID
    
    public var facingDirection: CGFloat // -1.0 = left, 1.0 = right
    public var eyeTarget: CGPoint
    public var eyeOffset: CGPoint
    public var blinkFactor: CGFloat // 0.0 open, 1.0 fully closed
    public var squishX: CGFloat
    public var squishY: CGFloat
    
    public var stateTimer: TimeInterval
    public var stateDuration: TimeInterval
    public var blinkTimer: TimeInterval
    public var breathPhase: CGFloat
    public var walkPhase: CGFloat
    public var tailPhase: CGFloat
    
    // Anime & Curious Typing Dynamics
    public var isTypingObserved: Bool = false
    public var typingTimer: TimeInterval = 0.0
    public var curiousTilt: CGFloat = 0.0
    public var earTwitchPhase: CGFloat = 0.0
    public var speechBubbleText: String? = nil
    public var speechBubbleTimer: TimeInterval = 0.0
    
    public var currentLedgeY: CGFloat?
    public var isBeingInteractedWith: Bool = false
    public var affection: CGFloat = 0.5
    public var energy: CGFloat = 0.8
    
    public init(initialPosition: CGPoint) {
        self.position = initialPosition
        self.velocity = CGVector(dx: 0, dy: 0)
        self.size = CGSize(width: 104, height: 96)
        self.state = .falling
        self.mood = .calm
        self.focusTier = .steady
        self.character = .rin
        
        self.facingDirection = 1.0
        self.eyeTarget = .zero
        self.eyeOffset = .zero
        self.blinkFactor = 0.0
        self.squishX = 1.0
        self.squishY = 1.0
        
        self.stateTimer = 0.0
        self.stateDuration = 4.0
        self.blinkTimer = Double.random(in: 2.0...5.0)
        self.breathPhase = 0.0
        self.walkPhase = 0.0
        self.tailPhase = 0.0
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
    
    public func say(_ text: String, duration: TimeInterval = 2.8) {
        self.speechBubbleText = text
        self.speechBubbleTimer = duration
    }
    
    public func registerUserTyping() {
        self.isTypingObserved = true
        self.typingTimer = 1.6
        self.earTwitchPhase += 0.8
        
        if abs(curiousTilt) < 0.01 {
            curiousTilt = Bool.random() ? 0.08 : -0.08
        }
    }
    
    public func registerEnterPressed() {
        let quotes = character.enterQuotes
        let chosen = quotes.randomElement() ?? "LGTM!"
        say(chosen, duration: 2.8)
        
        if state.isGrounded {
            self.velocity.dy = 190.0
            self.transition(to: .falling, duration: 0.5)
            self.applySquish(x: 0.88, y: 1.15)
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
        case .walking:
            self.walkPhase = 0.0
        case .petted:
            self.affection = min(1.0, affection + 0.1)
            self.mood = .happy
        case .mischievous:
            self.mood = .playful
        default:
            break
        }
    }
}
