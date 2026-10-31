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
        entity.applySquish(x: 1.15, y: 0.85)
        
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
        needsDisplay = true
    }
    
    // MARK: - Procedural Anime Rendering
    
    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        context.saveGState()
        
        let cx = bounds.midX
        let cy: CGFloat = 8.0
        let w = entity.size.width * entity.squishX
        let h = entity.size.height * entity.squishY
        
        // Head tilt when observing typing
        let tilt = entity.isTypingObserved ? entity.curiousTilt : 0.0
        let breathScale = 1.0 + sin(entity.breathPhase) * 0.03
        let walkOffset = (entity.state == .walking) ? abs(sin(entity.walkPhase)) * 3.5 : 0.0
        let walkAngle = (entity.state == .walking) ? sin(entity.walkPhase) * 0.08 : 0.0
        
        context.translateBy(x: cx, y: cy + walkOffset)
        context.rotate(by: walkAngle + tilt)
        context.scaleBy(x: breathScale, y: breathScale)
        
        // 1. Draw Tail (if Cat or Fox)
        drawTail(context: context, bodyWidth: w, bodyHeight: h)
        
        // 2. Shadow beneath entity
        if entity.state.isGrounded {
            let shadowWidth = w * 0.82
            let shadowHeight: CGFloat = 6.0
            let shadowRect = CGRect(x: -shadowWidth / 2.0, y: -2.0, width: shadowWidth, height: shadowHeight)
            context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0.22))
            context.fillEllipse(in: shadowRect)
        }
        
        // 3. Draw Ears (Cat or Fox or Slime Crest)
        drawEars(context: context, bodyWidth: w, bodyHeight: h)
        
        // 4. Main Chibi Body Membrane
        drawBody(context: context, bodyWidth: w, bodyHeight: h)
        
        // 5. Anime Whiskers & Facial Blush
        drawFaceDetails(context: context, bodyWidth: w, bodyHeight: h)
        
        // 6. Expressive Anime Eyes
        drawAnimeEyes(context: context, bodyWidth: w, bodyHeight: h)
        
        // 7. Cute Mouth
        drawAnimeMouth(context: context, bodyWidth: w, bodyHeight: h)
        
        context.restoreGState()
        
        // 8. Manga Speech Bubble on Enter
        if let speech = entity.speechBubbleText, entity.speechBubbleTimer > 0 {
            drawSpeechBubble(context: context, text: speech, topY: cy + h + 8.0)
        }
    }
    
    // MARK: - Anime Tail
    private func drawTail(context: CGContext, bodyWidth: CGFloat, bodyHeight: CGFloat) {
        guard entity.skin != .chibiSlime else { return }
        
        context.saveGState()
        let tailBaseX = -bodyWidth * 0.35 * entity.facingDirection
        let tailBaseY = bodyHeight * 0.25
        let tailSway = sin(entity.tailPhase) * 12.0
        
        context.beginPath()
        context.move(to: CGPoint(x: tailBaseX, y: tailBaseY))
        
        let control1 = CGPoint(x: tailBaseX - (20.0 * entity.facingDirection) + tailSway, y: tailBaseY + 15.0)
        let control2 = CGPoint(x: tailBaseX - (28.0 * entity.facingDirection) + tailSway * 1.4, y: tailBaseY + 30.0)
        let tip = CGPoint(x: tailBaseX - (16.0 * entity.facingDirection) + tailSway * 1.8, y: tailBaseY + 42.0)
        
        context.addCurve(to: tip, control1: control1, control2: control2)
        
        if entity.skin == .chibiKitsune {
            // Bushy fox tail
            context.setLineWidth(12.0)
            context.setLineCap(.round)
            context.setStrokeColor(CGColor(red: 0.95, green: 0.58, blue: 0.25, alpha: 0.95))
            context.strokePath()
            
            // White tip
            context.saveGState()
            context.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.95))
            context.fillEllipse(in: CGRect(x: tip.x - 6.0, y: tip.y - 6.0, width: 12.0, height: 12.0))
            context.restoreGState()
        } else {
            // Elegant cat tail
            context.setLineWidth(6.5)
            context.setLineCap(.round)
            context.setStrokeColor(CGColor(red: 0.16, green: 0.75, blue: 0.88, alpha: 0.95))
            context.strokePath()
        }
        
        context.restoreGState()
    }
    
    // MARK: - Anime Ears / Crest
    private func drawEars(context: CGContext, bodyWidth: CGFloat, bodyHeight: CGFloat) {
        let earTwitch = sin(entity.earTwitchPhase) * 3.0
        
        switch entity.skin {
        case .chibiNeko:
            // Pointed cat ears
            let earW = bodyWidth * 0.26
            let earH = bodyHeight * 0.36
            let leftEarBaseX = -bodyWidth * 0.42
            let rightEarBaseX = bodyWidth * 0.16
            let earY = bodyHeight * 0.72
            
            // Left ear
            let leftPath = CGMutablePath()
            leftPath.move(to: CGPoint(x: leftEarBaseX, y: earY))
            leftPath.addLine(to: CGPoint(x: leftEarBaseX + earW * 0.35 + earTwitch, y: earY + earH))
            leftPath.addLine(to: CGPoint(x: leftEarBaseX + earW, y: earY + 6.0))
            leftPath.closeSubpath()
            
            // Right ear
            let rightPath = CGMutablePath()
            rightPath.move(to: CGPoint(x: rightEarBaseX, y: earY + 6.0))
            rightPath.addLine(to: CGPoint(x: rightEarBaseX + earW * 0.65 - earTwitch, y: earY + earH))
            rightPath.addLine(to: CGPoint(x: rightEarBaseX + earW, y: earY))
            rightPath.closeSubpath()
            
            context.setFillColor(CGColor(red: 0.10, green: 0.85, blue: 0.92, alpha: 0.95))
            context.addPath(leftPath)
            context.addPath(rightPath)
            context.fillPath()
            
            // Inner ear pink fluff
            context.setFillColor(CGColor(red: 1.0, green: 0.58, blue: 0.72, alpha: 0.90))
            let innerLeft = CGMutablePath()
            innerLeft.move(to: CGPoint(x: leftEarBaseX + 3.0, y: earY + 2.0))
            innerLeft.addLine(to: CGPoint(x: leftEarBaseX + earW * 0.35 + earTwitch, y: earY + earH - 4.0))
            innerLeft.addLine(to: CGPoint(x: leftEarBaseX + earW - 3.0, y: earY + 6.0))
            innerLeft.closeSubpath()
            
            let innerRight = CGMutablePath()
            innerRight.move(to: CGPoint(x: rightEarBaseX + 3.0, y: earY + 6.0))
            innerRight.addLine(to: CGPoint(x: rightEarBaseX + earW * 0.65 - earTwitch, y: earY + earH - 4.0))
            innerRight.addLine(to: CGPoint(x: rightEarBaseX + earW - 3.0, y: earY + 2.0))
            innerRight.closeSubpath()
            
            context.addPath(innerLeft)
            context.addPath(innerRight)
            context.fillPath()
            
        case .chibiKitsune:
            // Tall alert fox ears with dark tips
            let earW = bodyWidth * 0.28
            let earH = bodyHeight * 0.44
            let leftEarBaseX = -bodyWidth * 0.44
            let rightEarBaseX = bodyWidth * 0.16
            let earY = bodyHeight * 0.70
            
            context.setFillColor(CGColor(red: 0.95, green: 0.58, blue: 0.25, alpha: 0.95))
            let leftFox = CGMutablePath()
            leftFox.move(to: CGPoint(x: leftEarBaseX, y: earY))
            leftFox.addLine(to: CGPoint(x: leftEarBaseX + earW * 0.4, y: earY + earH))
            leftFox.addLine(to: CGPoint(x: leftEarBaseX + earW, y: earY + 8.0))
            leftFox.closeSubpath()
            
            let rightFox = CGMutablePath()
            rightFox.move(to: CGPoint(x: rightEarBaseX, y: earY + 8.0))
            rightFox.addLine(to: CGPoint(x: rightEarBaseX + earW * 0.6, y: earY + earH))
            rightFox.addLine(to: CGPoint(x: rightEarBaseX + earW, y: earY))
            rightFox.closeSubpath()
            
            context.addPath(leftFox)
            context.addPath(rightFox)
            context.fillPath()
            
        case .chibiSlime:
            // Slime droplet crest on top
            let crestRect = CGRect(x: -8.0, y: bodyHeight * 0.88, width: 16.0, height: 16.0)
            context.setFillColor(CGColor(red: 0.25, green: 0.82, blue: 0.98, alpha: 0.95))
            context.fillEllipse(in: crestRect)
        }
    }
    
    // MARK: - Chibi Body
    private func drawBody(context: CGContext, bodyWidth: CGFloat, bodyHeight: CGFloat) {
        let bodyRect = CGRect(x: -bodyWidth / 2.0, y: 0, width: bodyWidth, height: bodyHeight)
        let bodyPath = CGPath(roundedRect: bodyRect, cornerWidth: bodyWidth * 0.46, cornerHeight: bodyHeight * 0.46, transform: nil)
        
        let topColor: CGColor
        let bottomColor: CGColor
        
        switch entity.skin {
        case .chibiNeko:
            topColor = CGColor(red: 0.16, green: 0.88, blue: 0.95, alpha: 0.95)
            bottomColor = CGColor(red: 0.10, green: 0.45, blue: 0.90, alpha: 0.95)
        case .chibiKitsune:
            topColor = CGColor(red: 0.98, green: 0.65, blue: 0.32, alpha: 0.95)
            bottomColor = CGColor(red: 0.88, green: 0.38, blue: 0.18, alpha: 0.95)
        case .chibiSlime:
            topColor = CGColor(red: 0.28, green: 0.88, blue: 0.98, alpha: 0.92)
            bottomColor = CGColor(red: 0.08, green: 0.52, blue: 0.88, alpha: 0.92)
        }
        
        context.saveGState()
        context.addPath(bodyPath)
        context.clip()
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        if let gradient = CGGradient(colorsSpace: colorSpace, colors: [topColor, bottomColor] as CFArray, locations: [0.0, 1.0]) {
            context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: bodyHeight), end: CGPoint(x: 0, y: 0), options: [])
        }
        
        // Belly patch
        let bellyRect = CGRect(x: -bodyWidth * 0.26, y: 2.0, width: bodyWidth * 0.52, height: bodyHeight * 0.42)
        context.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.30))
        context.fillEllipse(in: bellyRect)
        
        context.restoreGState()
        
        // Membrane outline
        context.addPath(bodyPath)
        context.setStrokeColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.6))
        context.setLineWidth(2.0)
        context.strokePath()
    }
    
    // MARK: - Facial Details (Blush & Whiskers)
    private func drawFaceDetails(context: CGContext, bodyWidth: CGFloat, bodyHeight: CGFloat) {
        // Anime Blush marks /// on cheeks
        let blushY = bodyHeight * 0.40
        let blushOffset = bodyWidth * 0.32
        
        context.setStrokeColor(CGColor(red: 1.0, green: 0.42, blue: 0.62, alpha: 0.75))
        context.setLineWidth(1.6)
        context.setLineCap(.round)
        
        // Left blush
        for i in 0..<3 {
            let ox = -blushOffset + CGFloat(i) * 3.5
            context.beginPath()
            context.move(to: CGPoint(x: ox - 2.0, y: blushY - 3.0))
            context.addLine(to: CGPoint(x: ox + 2.0, y: blushY + 3.0))
            context.strokePath()
        }
        
        // Right blush
        for i in 0..<3 {
            let ox = blushOffset - CGFloat(i) * 3.5
            context.beginPath()
            context.move(to: CGPoint(x: ox - 2.0, y: blushY - 3.0))
            context.addLine(to: CGPoint(x: ox + 2.0, y: blushY + 3.0))
            context.strokePath()
        }
    }
    
    // MARK: - Expressive Anime Eyes
    private func drawAnimeEyes(context: CGContext, bodyWidth: CGFloat, bodyHeight: CGFloat) {
        let eyeSpacing = bodyWidth * 0.25
        let eyeY = bodyHeight * 0.54
        let eyeW: CGFloat = 8.0
        let eyeH: CGFloat = 11.5
        
        let gazeX = entity.eyeOffset.x * 2.2
        let gazeY = entity.eyeOffset.y * 1.8
        
        let leftEyeCenter = CGPoint(x: -eyeSpacing + gazeX, y: eyeY + gazeY)
        let rightEyeCenter = CGPoint(x: eyeSpacing + gazeX, y: eyeY + gazeY)
        
        if entity.state == .sleeping || entity.blinkFactor > 0.6 {
            // Happy closed anime eyes ( > ω < )
            context.setStrokeColor(CGColor(red: 0.08, green: 0.12, blue: 0.28, alpha: 0.90))
            context.setLineWidth(2.4)
            context.setLineCap(.round)
            
            // Left eye arc
            context.beginPath()
            context.addArc(center: CGPoint(x: -eyeSpacing, y: eyeY), radius: eyeW * 0.8, startAngle: .pi * 0.2, endAngle: .pi * 0.8, clockwise: false)
            context.strokePath()
            
            // Right eye arc
            context.beginPath()
            context.addArc(center: CGPoint(x: eyeSpacing, y: eyeY), radius: eyeW * 0.8, startAngle: .pi * 0.2, endAngle: .pi * 0.8, clockwise: false)
            context.strokePath()
        } else {
            // Sclera / Base
            context.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.98))
            context.fillEllipse(in: CGRect(x: leftEyeCenter.x - eyeW, y: leftEyeCenter.y - eyeH * 0.5, width: eyeW * 2.0, height: eyeH))
            context.fillEllipse(in: CGRect(x: rightEyeCenter.x - eyeW, y: rightEyeCenter.y - eyeH * 0.5, width: eyeW * 2.0, height: eyeH))
            
            // Gradient Iris
            let irisColor = (entity.skin == .chibiKitsune)
                ? CGColor(red: 0.88, green: 0.38, blue: 0.15, alpha: 0.95)
                : CGColor(red: 0.10, green: 0.32, blue: 0.72, alpha: 0.95)
            
            let irisW = eyeW * 1.3
            let irisH = eyeH * 0.9
            context.setFillColor(irisColor)
            context.fillEllipse(in: CGRect(x: leftEyeCenter.x - irisW * 0.5, y: leftEyeCenter.y - irisH * 0.5, width: irisW, height: irisH))
            context.fillEllipse(in: CGRect(x: rightEyeCenter.x - irisW * 0.5, y: rightEyeCenter.y - irisH * 0.5, width: irisW, height: irisH))
            
            // Dark pupil center
            let pupilW = irisW * 0.55
            let pupilH = irisH * 0.6
            context.setFillColor(CGColor(red: 0.05, green: 0.08, blue: 0.18, alpha: 0.98))
            context.fillEllipse(in: CGRect(x: leftEyeCenter.x - pupilW * 0.5, y: leftEyeCenter.y - pupilH * 0.5, width: pupilW, height: pupilH))
            context.fillEllipse(in: CGRect(x: rightEyeCenter.x - pupilW * 0.5, y: rightEyeCenter.y - pupilH * 0.5, width: pupilW, height: pupilH))
            
            // Primary Sparkling Glint (Top Right)
            let glintRadius: CGFloat = entity.isTypingObserved ? 2.5 : 2.0
            context.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.98))
            context.fillEllipse(in: CGRect(x: leftEyeCenter.x + 1.0, y: leftEyeCenter.y + 1.2, width: glintRadius * 2.0, height: glintRadius * 2.0))
            context.fillEllipse(in: CGRect(x: rightEyeCenter.x + 1.0, y: rightEyeCenter.y + 1.2, width: glintRadius * 2.0, height: glintRadius * 2.0))
            
            // Secondary Micro Glint (Bottom Left)
            let microGlint: CGFloat = 1.0
            context.fillEllipse(in: CGRect(x: leftEyeCenter.x - 3.2, y: leftEyeCenter.y - 2.5, width: microGlint * 2.0, height: microGlint * 2.0))
            context.fillEllipse(in: CGRect(x: rightEyeCenter.x - 3.2, y: rightEyeCenter.y - 2.5, width: microGlint * 2.0, height: microGlint * 2.0))
            
            // Anime Upper Eyelash Line
            context.setStrokeColor(CGColor(red: 0.08, green: 0.10, blue: 0.22, alpha: 0.95))
            context.setLineWidth(2.2)
            context.beginPath()
            context.addArc(center: CGPoint(x: leftEyeCenter.x, y: leftEyeCenter.y + 1.0), radius: eyeW, startAngle: .pi * 0.15, endAngle: .pi * 0.85, clockwise: false)
            context.strokePath()
            
            context.beginPath()
            context.addArc(center: CGPoint(x: rightEyeCenter.x, y: rightEyeCenter.y + 1.0), radius: eyeW, startAngle: .pi * 0.15, endAngle: .pi * 0.85, clockwise: false)
            context.strokePath()
        }
    }
    
    // MARK: - Cute Anime Mouth (Cat ω lip)
    private func drawAnimeMouth(context: CGContext, bodyWidth: CGFloat, bodyHeight: CGFloat) {
        let mouthY = bodyHeight * 0.36
        context.setStrokeColor(CGColor(red: 0.08, green: 0.12, blue: 0.28, alpha: 0.85))
        context.setLineWidth(1.6)
        context.setLineCap(.round)
        
        if entity.isTypingObserved {
            // Little open mouth in curious awe :o
            context.setFillColor(CGColor(red: 1.0, green: 0.45, blue: 0.58, alpha: 0.85))
            let mouthRect = CGRect(x: -3.0, y: mouthY - 3.0, width: 6.0, height: 6.0)
            context.fillEllipse(in: mouthRect)
            context.strokeEllipse(in: mouthRect)
        } else {
            // Classic cat lip ω
            let r: CGFloat = 2.8
            context.beginPath()
            context.addArc(center: CGPoint(x: -r, y: mouthY), radius: r, startAngle: .pi * 0.9, endAngle: .pi * 0.1, clockwise: true)
            context.strokePath()
            
            context.beginPath()
            context.addArc(center: CGPoint(x: r, y: mouthY), radius: r, startAngle: .pi * 0.9, endAngle: .pi * 0.1, clockwise: true)
            context.strokePath()
        }
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
        let bubbleW = max(52.0, textSize.width + padX * 2.0)
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
        
        // Bubble shadow
        context.setShadow(offset: CGSize(width: 0, height: -2), blur: 5.0, color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.25))
        
        // Bubble fill
        context.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.96))
        context.addPath(bubblePath)
        context.fillPath()
        
        // Bubble outline
        context.setStrokeColor(CGColor(red: 0.15, green: 0.18, blue: 0.32, alpha: 0.90))
        context.setLineWidth(1.5)
        context.addPath(bubblePath)
        context.strokePath()
        
        context.restoreGState()
        
        // Draw Text inside Bubble
        let textPoint = CGPoint(
            x: bubbleX + (bubbleW - textSize.width) / 2.0,
            y: bubbleY + (bubbleH - textSize.height) / 2.0
        )
        attrString.draw(at: textPoint)
    }
}
