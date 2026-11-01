import Foundation
import CoreGraphics

public final class PhysicsEngine {
    // Ethereal floaty ghost gravity
    public var gravity: CGFloat = -680.0
    public var terminalVelocity: CGFloat = -750.0
    public var bounceElasticity: CGFloat = 0.45
    public var groundFriction: CGFloat = 0.90
    public var airFriction: CGFloat = 0.97
    
    public init() {}
    
    public func update(entity: CytoEntity, deltaTime: CGFloat, ledges: [Ledge], screenBounds: CGRect) {
        // 1. Recover squish back to normal (ectoplasm elasticity)
        let springConstant: CGFloat = 12.0
        let targetSquishX: CGFloat = 1.0
        let targetSquishY: CGFloat = 1.0
        
        entity.squishX += (targetSquishX - entity.squishX) * min(1.0, springConstant * deltaTime)
        entity.squishY += (targetSquishY - entity.squishY) * min(1.0, springConstant * deltaTime)
        
        // 2. Oscillations for Float, Wisp ripples, and Headphone LED pulse
        entity.floatPhase += deltaTime * 2.8
        if entity.floatPhase > .pi * 2.0 {
            entity.floatPhase -= .pi * 2.0
        }
        
        entity.wispPhase += deltaTime * 5.2
        if entity.wispPhase > .pi * 2.0 {
            entity.wispPhase -= .pi * 2.0
        }
        
        // Headphone LED pulsing glow
        entity.headphoneGlowPhase += deltaTime * 3.2
        if entity.headphoneGlowPhase > .pi * 2.0 {
            entity.headphoneGlowPhase -= .pi * 2.0
        }
        
        // 3. Skip kinematic simulation if manually dragged
        if entity.state == .dragged {
            entity.currentLedgeY = nil
            return
        }
        
        // 4. In-air / floating simulation
        if !entity.state.isGrounded {
            entity.velocity.dy += gravity * deltaTime
            if entity.velocity.dy < terminalVelocity {
                entity.velocity.dy = terminalVelocity
            }
            
            // Air drag (gliding)
            entity.velocity.dx *= pow(airFriction, deltaTime * 60.0)
            
            // Position step
            entity.position.x += entity.velocity.dx * deltaTime
            entity.position.y += entity.velocity.dy * deltaTime
            
            // Wall collisions (left/right screen borders with soft rebound)
            let halfWidth = (entity.size.width * entity.squishX) / 2.0
            if entity.position.x - halfWidth < screenBounds.minX {
                entity.position.x = screenBounds.minX + halfWidth
                entity.velocity.dx = abs(entity.velocity.dx) * bounceElasticity
                entity.applySquish(x: 0.82, y: 1.18)
            } else if entity.position.x + halfWidth > screenBounds.maxX {
                entity.position.x = screenBounds.maxX - halfWidth
                entity.velocity.dx = -abs(entity.velocity.dx) * bounceElasticity
                entity.applySquish(x: 0.82, y: 1.18)
            }
            
            // Ledge collision check (hovering down onto window headers)
            if entity.velocity.dy <= 0 {
                let footX = entity.position.x
                let footY = entity.position.y
                
                for ledge in ledges {
                    if footX >= ledge.minX && footX <= ledge.maxX {
                        let tolerance: CGFloat = max(18.0, abs(entity.velocity.dy * deltaTime) + 6.0)
                        if footY >= ledge.topY - 6.0 && footY <= ledge.topY + tolerance {
                            entity.position.y = ledge.topY
                            entity.currentLedgeY = ledge.topY
                            entity.perchedWindowID = ledge.windowID
                            entity.perchedLedgeRect = ledge.rect
                            
                            if abs(entity.velocity.dy) > 220.0 {
                                entity.applySquish(x: 1.25, y: 0.75)
                                entity.transition(to: .bouncing, duration: 0.25)
                                entity.velocity.dy = -entity.velocity.dy * bounceElasticity
                                if abs(entity.velocity.dy) < 50.0 {
                                    entity.velocity.dy = 0
                                    entity.transition(to: .idle)
                                }
                            } else {
                                entity.velocity.dy = 0
                                entity.velocity.dx *= groundFriction
                                entity.applySquish(x: 1.12, y: 0.88)
                                entity.transition(to: .idle)
                            }
                            return
                        }
                    }
                }
            }
        } else {
            // Grounded state (hovering gracefully along the ledge)
            var stillSupported = false
            let footX = entity.position.x
            let footY = entity.position.y
            
            for ledge in ledges {
                if footX >= ledge.minX && footX <= ledge.maxX {
                    if abs(footY - ledge.topY) < 8.0 {
                        stillSupported = true
                        entity.position.y = ledge.topY
                        entity.perchedWindowID = ledge.windowID
                        entity.perchedLedgeRect = ledge.rect
                        break
                    }
                }
            }
            
            if !stillSupported {
                // Window moved or closed! Ghost floats gently downward
                entity.currentLedgeY = nil
                entity.perchedWindowID = nil
                entity.perchedLedgeRect = nil
                entity.transition(to: .falling)
                entity.velocity.dy = -60.0
                entity.applySquish(x: 0.90, y: 1.10)
                return
            }
            
            // Horizontal glide friction
            entity.velocity.dx *= pow(groundFriction, deltaTime * 60.0)
            entity.position.x += entity.velocity.dx * deltaTime
            
            if entity.state == .walking {
                entity.walkPhase += deltaTime * 6.0
            }
        }
    }
}
