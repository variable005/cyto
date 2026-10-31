import Foundation
import CoreGraphics

public final class ActivityEngine {
    private var lastKeyTimestamp: Date = Date()
    private var lastIdleSeconds: Double = 0.0
    
    public init() {}
    
    /// Queries the OS for seconds since last user input without intercepting any content.
    public func updateFocusTier() -> (tier: FocusTier, idleSeconds: Double) {
        let keyIdle = CGEventSource.secondsSinceLastEventType(
            .combinedSessionState,
            eventType: .keyDown
        )
        let mouseIdle = CGEventSource.secondsSinceLastEventType(
            .combinedSessionState,
            eventType: .mouseMoved
        )
        
        let minIdle = min(keyIdle, mouseIdle)
        self.lastIdleSeconds = minIdle
        
        let tier: FocusTier
        if minIdle < 2.5 {
            tier = .inFlow
        } else if minIdle < 15.0 {
            tier = .steady
        } else if minIdle < 60.0 {
            tier = .wandering
        } else {
            tier = .idle
        }
        
        return (tier, minIdle)
    }
}
