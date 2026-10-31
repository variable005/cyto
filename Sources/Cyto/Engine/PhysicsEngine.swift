import Foundation
import CoreGraphics

public final class PhysicsEngine {
    public var gravity: CGFloat = -1100.0 // points/sec^2
    public var terminalVelocity: CGFloat = -1400.0
    public var bounceElasticity: CGFloat = 0.35
    public var groundFriction: CGFloat = 0.88
    public var airFriction: CGFloat = 0.985
    
    public init() {}
    
    public func update(entity: CytoEntity, deltaTime: CGFloat, ledges: [Ledge], screenBounds: CGRect) {
        // 1. Recover squish back to neutral (spring physics)
        let springConstant: CGFloat = 14.0
        entity.squishX += (1.0 - entity.squishX) * min(1.0, springConstant * deltaTime)
        entity.squishY += (1.0 - entity.squishY) * min(1.0, springConstant * deltaTime)
        
        // 2. Breathing oscillation
        entity.breathPhase += deltaTime * 2.5
        if entity.breathPhase > .pi * 2.0 {
            entity.breathPhase -= .pi * 2.0
        }
        
        // 3. Skip kinematic simulation if manually dragged
        if entity.state == .dragged {
            entity.currentLedgeY = nil
            return
        }
        
        // 4. In-air / falling simulation
        if !entity.state.isGrounded {
            // Apply gravity
            entity.velocity.dy += gravity * deltaTime
            if entity.velocity.dy < terminalVelocity {
                entity.velocity.dy = terminalVelocity
            }
            
            // Air drag
            entity.velocity.dx *= pow(airFriction, deltaTime * 60.0)
            
            // Position step
            entity.position.x += entity.velocity.dx * deltaTime
            entity.position.y += entity.velocity.dy * deltaTime
            
            // Wall collisions (left/right screen borders)
            let halfWidth = (entity.size.width * entity.squishX) / 2.0
            if entity.position.x - halfWidth < screenBounds.minX {
                entity.position.x = screenBounds.minX + halfWidth
                entity.velocity.dx = abs(entity.velocity.dx) * bounceElasticity
                entity.applySquish(x: 0.75, y: 1.25)
            } else if entity.position.x + halfWidth > screenBounds.maxX {
                entity.position.x = screenBounds.maxX - halfWidth
                entity.velocity.dx = -abs(entity.velocity.dx) * bounceElasticity
                entity.applySquish(x: 0.75, y: 1.25)
            }
            
            // Ledge collision check (only when moving downwards)
            if entity.velocity.dy <= 0 {
                let footX = entity.position.x
                let footY = entity.position.y
                
                for ledge in ledges {
                    // Check horizontal inclusion
                    if footX >= ledge.minX && footX <= ledge.maxX {
                        // Check if foot is within landing tolerance above or just crossed the ledge
                        let tolerance: CGFloat = max(16.0, abs(entity.velocity.dy * deltaTime) + 4.0)
                        if footY >= ledge.topY - 8.0 && footY <= ledge.topY + tolerance {
                            // Land on this ledge
                            entity.position.y = ledge.topY
                            entity.currentLedgeY = ledge.topY
                            
                            if abs(entity.velocity.dy) > 300.0 {
                                // Impact bounce and squish
                                entity.applySquish(x: 1.4, y: 0.6)
                                entity.transition(to: .bouncing, duration: 0.25)
                                entity.velocity.dy = -entity.velocity.dy * bounceElasticity
                                if abs(entity.velocity.dy) < 60.0 {
                                    entity.velocity.dy = 0
                                    entity.transition(to: .idle)
                                }
                            } else {
                                entity.velocity.dy = 0
                                entity.velocity.dx *= groundFriction
                                entity.applySquish(x: 1.2, y: 0.8)
                                entity.transition(to: .idle)
                            }
                            return
                        }
                    }
                }
            }
        } else {
            // Grounded state
            // Verify current ledge still exists under its feet
            var stillSupported = false
            let footX = entity.position.x
            let footY = entity.position.y
            
            for ledge in ledges {
                if footX >= ledge.minX && footX <= ledge.maxX {
                    if abs(footY - ledge.topY) < 6.0 {
                        stillSupported = true
                        entity.position.y = ledge.topY
                        break
                    }
                }
            }
            
            if !stillSupported {
                // Window moved or closed! Cyto falls off
                entity.currentLedgeY = nil
                entity.transition(to: .falling)
                entity.velocity.dy = -100.0
                entity.applySquish(x: 0.85, y: 1.15)
                return
            }
            
            // Horizontal friction on ground
            entity.velocity.dx *= pow(groundFriction, deltaTime * 60.0)
            entity.position.x += entity.velocity.dx * deltaTime
            
            // Walking animation phase step
            if entity.state == .walking {
                entity.walkPhase += deltaTime * 8.0
            }
        }
    }
}
