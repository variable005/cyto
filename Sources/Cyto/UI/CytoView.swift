import AppKit
import CoreGraphics

public final class CytoView: NSView {
    public let entity: CytoEntity
    private var dragStartMouseScreen: CGPoint = .zero
    private var dragStartEntityPos: CGPoint = .zero
    private var recentDragDeltas: [CGPoint] = []
    private var lastDragTime: Date = Date()
    private var petCounter: Int = 0
    
    public init(frame frameRect: NSRect, entity: CytoEntity) {
        self.entity = entity
        super.init(frame: frameRect)
        self.wantsLayer = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Mouse Interaction
    
    public override func mouseDown(with event: NSEvent) {
        dragStartMouseScreen = NSEvent.mouseLocation
        dragStartEntityPos = entity.position
        recentDragDeltas.removeAll()
        lastDragTime = Date()
        
        entity.isBeingInteractedWith = true
        entity.transition(to: .dragged)
        entity.velocity = .zero
        entity.applySquish(x: 0.85, y: 1.2)
        
        // Gentle pick-up haptic feedback
        NSHapticFeedbackManager.defaultPerformer.perform(
            .alignment,
            performanceTime: .now
        )
        needsDisplay = true
    }
    
    public override func mouseDragged(with event: NSEvent) {
        let currentMouseScreen = NSEvent.mouseLocation
        let dx = currentMouseScreen.x - dragStartMouseScreen.x
        let dy = currentMouseScreen.y - dragStartMouseScreen.y
        
        let now = Date()
        let dt = CGFloat(max(0.001, now.timeIntervalSince(lastDragTime)))
        lastDragTime = now
        
        let newX = dragStartEntityPos.x + dx
        let newY = dragStartEntityPos.y + dy
        
        // Track recent velocity for toss kinetics
        let instantaneousVelocity = CGPoint(
            x: (newX - entity.position.x) / dt,
            y: (newY - entity.position.y) / dt
        )
        recentDragDeltas.append(instantaneousVelocity)
        if recentDragDeltas.count > 5 {
            recentDragDeltas.removeFirst()
        }
        
        entity.position = CGPoint(x: newX, y: newY)
        
        // Detect subtle wiggles as petting
        if abs(dx) < 12 && abs(dy) < 12 {
            petCounter += 1
            if petCounter > 6 {
                petCounter = 0
                entity.transition(to: .petted, duration: 2.0)
                NSHapticFeedbackManager.defaultPerformer.perform(
                    .generic,
                    performanceTime: .now
                )
            }
        }
        
        needsDisplay = true
    }
    
    public override func mouseUp(with event: NSEvent) {
        entity.isBeingInteractedWith = false
        
        // Calculate fling / toss velocity from recent drag history
        if !recentDragDeltas.isEmpty {
            let avgDx = recentDragDeltas.map { $0.x }.reduce(0, +) / CGFloat(recentDragDeltas.count)
            let avgDy = recentDragDeltas.map { $0.y }.reduce(0, +) / CGFloat(recentDragDeltas.count)
            
            let cappedDx = max(-1100.0, min(1100.0, avgDx * 0.85))
            let cappedDy = max(-900.0, min(1100.0, avgDy * 0.85))
            entity.velocity = CGVector(dx: cappedDx, dy: cappedDy)
        } else {
            entity.velocity = .zero
        }
        
        entity.transition(to: .falling)
        entity.applySquish(x: 1.15, y: 0.85)
        
        NSHapticFeedbackManager.defaultPerformer.perform(
            .levelChange,
            performanceTime: .now
        )
        needsDisplay = true
    }
    
    // MARK: - Procedural Rendering in Local Coordinates
    
    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        context.saveGState()
        
        // Render relative to view bounds (centered horizontally, foot at bottom padding)
        let cx = bounds.midX
        let cy: CGFloat = 8.0
        let w = entity.size.width * entity.squishX
        let h = entity.size.height * entity.squishY
        
        // Subtle walking waddle or breathing scale
        let breathScale = 1.0 + sin(entity.breathPhase) * 0.035
        let walkOffset = (entity.state == .walking) ? abs(sin(entity.walkPhase)) * 3.5 : 0.0
        let walkAngle = (entity.state == .walking) ? sin(entity.walkPhase) * 0.08 : 0.0
        
        context.translateBy(x: cx, y: cy + walkOffset)
        context.rotate(by: walkAngle)
        context.scaleBy(x: breathScale, y: breathScale)
        
        let bodyRect = CGRect(x: -w / 2.0, y: 0, width: w, height: h)
        
        // 1. Shadow beneath entity
        if entity.state.isGrounded {
            let shadowWidth = w * 0.85
            let shadowHeight: CGFloat = 6.0
            let shadowRect = CGRect(x: -shadowWidth / 2.0, y: -2.0, width: shadowWidth, height: shadowHeight)
            context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0.22))
            context.fillEllipse(in: shadowRect)
        }
        
        // 2. Cellular Membrane (Outer Body)
        let bodyPath = CGPath(roundedRect: bodyRect, cornerWidth: w * 0.46, cornerHeight: h * 0.46, transform: nil)
        
        // Dynamic color scheme based on mood and focus
        let topColor: CGColor
        let bottomColor: CGColor
        
        switch entity.mood {
        case .happy, .playful:
            // Vibrant neon mint / cyan
            topColor = CGColor(red: 0.16, green: 0.94, blue: 0.78, alpha: 0.95)
            bottomColor = CGColor(red: 0.08, green: 0.62, blue: 0.90, alpha: 0.95)
        case .sleepy:
            // Soothing lavender / dusk violet
            topColor = CGColor(red: 0.65, green: 0.58, blue: 0.95, alpha: 0.90)
            bottomColor = CGColor(red: 0.35, green: 0.28, blue: 0.72, alpha: 0.90)
        case .bored:
            // Muted slate teal
            topColor = CGColor(red: 0.42, green: 0.68, blue: 0.75, alpha: 0.90)
            bottomColor = CGColor(red: 0.20, green: 0.38, blue: 0.48, alpha: 0.90)
        default:
            // Signature Cyto Electric Cyan
            topColor = CGColor(red: 0.10, green: 0.88, blue: 0.92, alpha: 0.95)
            bottomColor = CGColor(red: 0.18, green: 0.42, blue: 0.96, alpha: 0.95)
        }
        
        context.addPath(bodyPath)
        context.clip()
        
        // Body gradient fill
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        if let gradient = CGGradient(colorsSpace: colorSpace, colors: [topColor, bottomColor] as CFArray, locations: [0.0, 1.0]) {
            context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: h), end: CGPoint(x: 0, y: 0), options: [])
        }
        
        // 3. Inner Cellular Nucleus (Glowing core)
        let nucleusSize = CGSize(width: w * 0.38, height: h * 0.38)
        let nucleusRect = CGRect(x: -nucleusSize.width / 2.0, y: h * 0.28, width: nucleusSize.width, height: nucleusSize.height)
        context.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.28))
        context.fillEllipse(in: nucleusRect)
        
        context.resetClip()
        
        // 4. Membrane Outline Glow
        context.addPath(bodyPath)
        context.setStrokeColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.55))
        context.setLineWidth(2.0)
        context.strokePath()
        
        // 5. Expressive Eyes
        drawEyes(context: context, bodyWidth: w, bodyHeight: h)
        
        // 6. State indicators (e.g., Zzz bubbles when sleeping)
        if entity.state == .sleeping {
            drawSleepingZzz(context: context, bodyHeight: h)
        }
        
        context.restoreGState()
    }
    
    private func drawEyes(context: CGContext, bodyWidth: CGFloat, bodyHeight: CGFloat) {
        let eyeSpacing = bodyWidth * 0.24
        let eyeY = bodyHeight * 0.52
        let eyeRadius: CGFloat = 5.5
        
        let gazeX = entity.eyeOffset.x * 2.5
        let gazeY = entity.eyeOffset.y * 2.0
        
        let leftEyeCenter = CGPoint(x: -eyeSpacing + gazeX, y: eyeY + gazeY)
        let rightEyeCenter = CGPoint(x: eyeSpacing + gazeX, y: eyeY + gazeY)
        
        if entity.state == .sleeping || entity.blinkFactor > 0.6 {
            context.setStrokeColor(CGColor(red: 0.1, green: 0.15, blue: 0.35, alpha: 0.85))
            context.setLineWidth(2.2)
            context.setLineCap(.round)
            
            context.beginPath()
            context.addArc(center: CGPoint(x: -eyeSpacing, y: eyeY), radius: eyeRadius, startAngle: .pi * 0.2, endAngle: .pi * 0.8, clockwise: false)
            context.strokePath()
            
            context.beginPath()
            context.addArc(center: CGPoint(x: eyeSpacing, y: eyeY), radius: eyeRadius, startAngle: .pi * 0.2, endAngle: .pi * 0.8, clockwise: false)
            context.strokePath()
        } else {
            // Sclera
            context.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.95))
            context.fillEllipse(in: CGRect(x: leftEyeCenter.x - eyeRadius, y: leftEyeCenter.y - eyeRadius, width: eyeRadius * 2.0, height: eyeRadius * 2.0))
            context.fillEllipse(in: CGRect(x: rightEyeCenter.x - eyeRadius, y: rightEyeCenter.y - eyeRadius, width: eyeRadius * 2.0, height: eyeRadius * 2.0))
            
            // Pupils
            let pupilRadius: CGFloat = 3.2
            context.setFillColor(CGColor(red: 0.08, green: 0.12, blue: 0.28, alpha: 0.95))
            context.fillEllipse(in: CGRect(x: leftEyeCenter.x - pupilRadius, y: leftEyeCenter.y - pupilRadius, width: pupilRadius * 2.0, height: pupilRadius * 2.0))
            context.fillEllipse(in: CGRect(x: rightEyeCenter.x - pupilRadius, y: rightEyeCenter.y - pupilRadius, width: pupilRadius * 2.0, height: pupilRadius * 2.0))
            
            // Glints
            let glintRadius: CGFloat = 1.2
            context.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.9))
            context.fillEllipse(in: CGRect(x: leftEyeCenter.x - glintRadius + 1.0, y: leftEyeCenter.y + glintRadius, width: glintRadius * 2.0, height: glintRadius * 2.0))
            context.fillEllipse(in: CGRect(x: rightEyeCenter.x - glintRadius + 1.0, y: rightEyeCenter.y + glintRadius, width: glintRadius * 2.0, height: glintRadius * 2.0))
        }
    }
    
    private func drawSleepingZzz(context: CGContext, bodyHeight: CGFloat) {
        let zPhase = CGFloat(entity.stateTimer.truncatingRemainder(dividingBy: 3.0)) / 3.0
        let zY = bodyHeight + (zPhase * 20.0)
        let zX = 14.0 + (zPhase * 6.0)
        let alpha = 1.0 - zPhase
        
        let font = NSFont.systemFont(ofSize: 11.0, weight: .bold)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor(calibratedRed: 0.8, green: 0.85, blue: 1.0, alpha: alpha)
        ]
        
        let zString = NSString(string: "z")
        zString.draw(at: NSPoint(x: zX, y: zY), withAttributes: attrs)
    }
}
