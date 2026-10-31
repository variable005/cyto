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
        entity.applySquish(x: 0.92, y: 1.10)
        
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
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
        
        let instantaneousVelocity = CGPoint(
            x: (newX - entity.position.x) / dt,
            y: (newY - entity.position.y) / dt
        )
        recentDragDeltas.append(instantaneousVelocity)
        if recentDragDeltas.count > 5 {
            recentDragDeltas.removeFirst()
        }
        
        entity.position = CGPoint(x: newX, y: newY)
        
        if abs(dx) < 12 && abs(dy) < 12 {
            petCounter += 1
            if petCounter > 6 {
                petCounter = 0
                entity.transition(to: .petted, duration: 2.0)
                NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
            }
        }
        
        needsDisplay = true
    }
    
    public override func mouseUp(with event: NSEvent) {
        entity.isBeingInteractedWith = false
        
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
        entity.applySquish(x: 1.12, y: 0.88)
        
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
        needsDisplay = true
    }
    
    // MARK: - Rendering: High-Resolution Sprite or Procedural Fallback
    
    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        context.saveGState()
        
        let cx = bounds.midX
        let cy: CGFloat = 6.0
        let w = entity.size.width * entity.squishX
        let h = entity.size.height * entity.squishY
        
        let tilt = entity.isTypingObserved ? entity.curiousTilt : 0.0
        let breathScale = 1.0 + sin(entity.breathPhase) * 0.02
        let walkOffset = (entity.state == .walking) ? abs(sin(entity.walkPhase)) * 3.0 : 0.0
        let walkAngle = (entity.state == .walking) ? sin(entity.walkPhase) * 0.06 : 0.0
        
        context.translateBy(x: cx, y: cy + walkOffset)
        context.rotate(by: walkAngle + tilt)
        context.scaleBy(x: breathScale, y: breathScale)
        
        // Ground Shadow
        if entity.state.isGrounded {
            let shadowW = w * 0.88
            let shadowH: CGFloat = 6.0
            let shadowRect = CGRect(x: -shadowW / 2.0, y: -2.0, width: shadowW, height: shadowH)
            context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0.22))
            context.fillEllipse(in: shadowRect)
        }
        
        // Try rendering High-Res Illustrated Sprite Asset
        if let sprite = SpriteManager.shared.image(for: entity.character) {
            drawSprite(context: context, image: sprite, w: w, h: h)
        } else {
            drawProceduralFallback(context: context, w: w, h: h)
        }
        
        context.restoreGState()
        
        // Manga Speech Bubble on Enter
        if let speech = entity.speechBubbleText, entity.speechBubbleTimer > 0 {
            drawSpeechBubble(context: context, text: speech, topY: cy + h + 8.0)
        }
    }
    
    private func drawSprite(context: CGContext, image: NSImage, w: CGFloat, h: CGFloat) {
        let drawRect = CGRect(x: -w / 2.0, y: 0, width: w, height: h)
        
        // Enable high-quality bicubic image interpolation
        context.interpolationQuality = .high
        
        if let cgImg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            context.draw(cgImg, in: drawRect)
        } else {
            image.draw(in: drawRect, from: .zero, operation: .sourceOver, fraction: 1.0)
        }
    }
    
    // MARK: - Procedural Fallback
    private func drawProceduralFallback(context: CGContext, w: CGFloat, h: CGFloat) {
        let bodyRect = CGRect(x: -w * 0.44, y: 0, width: w * 0.88, height: h * 0.65)
        context.setFillColor(CGColor(red: 0.18, green: 0.58, blue: 0.92, alpha: 0.95))
        context.addPath(CGPath(roundedRect: bodyRect, cornerWidth: w * 0.35, cornerHeight: h * 0.25, transform: nil))
        context.fillPath()
        
        // Cute eyes
        context.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.95))
        context.fillEllipse(in: CGRect(x: -18.0, y: h * 0.32, width: 12.0, height: 14.0))
        context.fillEllipse(in: CGRect(x: 6.0, y: h * 0.32, width: 12.0, height: 14.0))
        
        context.setFillColor(CGColor(red: 0.1, green: 0.12, blue: 0.25, alpha: 0.95))
        context.fillEllipse(in: CGRect(x: -14.0, y: h * 0.34, width: 7.0, height: 8.0))
        context.fillEllipse(in: CGRect(x: 8.0, y: h * 0.34, width: 7.0, height: 8.0))
    }
    
    // MARK: - Manga Speech Bubble on Enter
    private func drawSpeechBubble(context: CGContext, text: String, topY: CGFloat) {
        let font = NSFont.systemFont(ofSize: 11.5, weight: .bold)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.black
        ]
        
        let attrString = NSAttributedString(string: text, attributes: attrs)
        let textSize = attrString.size()
        
        let padX: CGFloat = 10.0
        let padY: CGFloat = 5.0
        let bubbleW = max(54.0, textSize.width + padX * 2.0)
        let bubbleH = textSize.height + padY * 2.0
        
        let bubbleX = bounds.midX - bubbleW / 2.0
        let bubbleY = topY
        
        let bubbleRect = CGRect(x: bubbleX, y: bubbleY, width: bubbleW, height: bubbleH)
        let bubblePath = CGMutablePath()
        bubblePath.addRoundedRect(in: bubbleRect, cornerWidth: 8.0, cornerHeight: 8.0)
        
        // Pointer arrow pointing down to head
        let pointerTip = CGPoint(x: bounds.midX, y: topY - 5.0)
        bubblePath.move(to: CGPoint(x: bounds.midX - 5.0, y: topY))
        bubblePath.addLine(to: pointerTip)
        bubblePath.addLine(to: CGPoint(x: bounds.midX + 5.0, y: topY))
        bubblePath.closeSubpath()
        
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: -2), blur: 5.0, color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.25))
        context.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.98))
        context.addPath(bubblePath)
        context.fillPath()
        
        context.setStrokeColor(CGColor(red: 0.15, green: 0.18, blue: 0.32, alpha: 0.90))
        context.setLineWidth(1.5)
        context.addPath(bubblePath)
        context.strokePath()
        context.restoreGState()
        
        let textPoint = CGPoint(
            x: bubbleX + (bubbleW - textSize.width) / 2.0,
            y: bubbleY + (bubbleH - textSize.height) / 2.0
        )
        attrString.draw(at: textPoint)
    }
}
