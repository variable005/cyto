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
        entity.applySquish(x: 0.88, y: 1.15)
        
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
    
    // MARK: - Character Rendering
    
    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        context.saveGState()
        
        let cx = bounds.midX
        let cy: CGFloat = 8.0
        let w = entity.size.width * entity.squishX
        let h = entity.size.height * entity.squishY
        
        let tilt = entity.isTypingObserved ? entity.curiousTilt : 0.0
        let breathScale = 1.0 + sin(entity.breathPhase) * 0.025
        let walkOffset = (entity.state == .walking) ? abs(sin(entity.walkPhase)) * 3.5 : 0.0
        let walkAngle = (entity.state == .walking) ? sin(entity.walkPhase) * 0.08 : 0.0
        
        context.translateBy(x: cx, y: cy + walkOffset)
        context.rotate(by: walkAngle + tilt)
        context.scaleBy(x: breathScale, y: breathScale)
        
        // Ground Shadow
        if entity.state.isGrounded {
            let shadowW = w * 0.86
            let shadowH: CGFloat = 6.0
            let shadowRect = CGRect(x: -shadowW / 2.0, y: -2.0, width: shadowW, height: shadowH)
            context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0.24))
            context.fillEllipse(in: shadowRect)
        }
        
        // Render according to selected Character Profile
        switch entity.character {
        case .rin:
            drawRin(context: context, w: w, h: h)
        case .haru:
            drawHaru(context: context, w: w, h: h)
        case .pamu:
            drawPamu(context: context, w: w, h: h)
        case .kota:
            drawKota(context: context, w: w, h: h)
        case .mochi:
            drawMochi(context: context, w: w, h: h)
        case .bit:
            drawBit(context: context, w: w, h: h)
        case .hikaru:
            drawHikaru(context: context, w: w, h: h)
        }
        
        context.restoreGState()
        
        // Manga Speech Bubble on Enter
        if let speech = entity.speechBubbleText, entity.speechBubbleTimer > 0 {
            drawSpeechBubble(context: context, text: speech, topY: cy + h + 8.0)
        }
    }
    
    // MARK: - 1. Rin (The Late-Night Coder)
    private func drawRin(context: CGContext, w: CGFloat, h: CGFloat) {
        // A. Cozy Oversized Hoodie (Dark Slate)
        let hoodieRect = CGRect(x: -w * 0.52, y: 0, width: w * 1.04, height: h * 0.65)
        context.setFillColor(CGColor(red: 0.16, green: 0.18, blue: 0.24, alpha: 0.98))
        let hoodiePath = CGPath(roundedRect: hoodieRect, cornerWidth: 16.0, cornerHeight: 16.0, transform: nil)
        context.addPath(hoodiePath)
        context.fillPath()
        
        // Sleeves resting over ledge (Titlebar Hug)
        let leftSleeve = CGRect(x: -w * 0.48, y: -1.0, width: w * 0.38, height: 14.0)
        let rightSleeve = CGRect(x: w * 0.10, y: -1.0, width: w * 0.38, height: 14.0)
        context.setFillColor(CGColor(red: 0.12, green: 0.14, blue: 0.20, alpha: 1.0))
        context.addPath(CGPath(roundedRect: leftSleeve, cornerWidth: 6.0, cornerHeight: 6.0, transform: nil))
        context.addPath(CGPath(roundedRect: rightSleeve, cornerWidth: 6.0, cornerHeight: 6.0, transform: nil))
        context.fillPath()
        
        // B. Anime Face & Skin
        let faceRect = CGRect(x: -w * 0.35, y: h * 0.22, width: w * 0.70, height: h * 0.54)
        context.setFillColor(CGColor(red: 1.0, green: 0.92, blue: 0.88, alpha: 1.0))
        context.addPath(CGPath(roundedRect: faceRect, cornerWidth: w * 0.32, cornerHeight: h * 0.26, transform: nil))
        context.fillPath()
        
        // C. Studio Headphones (Dark metallic with silver cups)
        // Headband
        context.setStrokeColor(CGColor(red: 0.10, green: 0.11, blue: 0.15, alpha: 1.0))
        context.setLineWidth(5.0)
        context.beginPath()
        context.addArc(center: CGPoint(x: 0, y: h * 0.62), radius: w * 0.44, startAngle: .pi * 0.15, endAngle: .pi * 0.85, clockwise: false)
        context.strokePath()
        
        // Earcups
        let cupW: CGFloat = 11.0
        let cupH: CGFloat = 20.0
        context.setFillColor(CGColor(red: 0.12, green: 0.13, blue: 0.18, alpha: 1.0))
        context.fillEllipse(in: CGRect(x: -w * 0.48 - cupW * 0.5, y: h * 0.38, width: cupW, height: cupH))
        context.fillEllipse(in: CGRect(x: w * 0.48 - cupW * 0.5, y: h * 0.38, width: cupW, height: cupH))
        
        // D. Messy Anime Bangs (Dark Indigo / Black)
        context.setFillColor(CGColor(red: 0.13, green: 0.14, blue: 0.20, alpha: 1.0))
        let hairTop = CGRect(x: -w * 0.40, y: h * 0.54, width: w * 0.80, height: h * 0.28)
        context.fillEllipse(in: hairTop)
        
        // Bang strands
        let bangs = CGMutablePath()
        bangs.move(to: CGPoint(x: -w * 0.35, y: h * 0.62))
        bangs.addLine(to: CGPoint(x: -w * 0.22, y: h * 0.44))
        bangs.addLine(to: CGPoint(x: -w * 0.08, y: h * 0.62))
        bangs.addLine(to: CGPoint(x: w * 0.05, y: h * 0.42))
        bangs.addLine(to: CGPoint(x: w * 0.18, y: h * 0.60))
        bangs.addLine(to: CGPoint(x: w * 0.32, y: h * 0.46))
        bangs.addLine(to: CGPoint(x: w * 0.38, y: h * 0.62))
        bangs.closeSubpath()
        context.addPath(bangs)
        context.fillPath()
        
        // E. Blushing Cheeks
        drawBlush(context: context, y: h * 0.32, offset: w * 0.22)
        
        // F. Big Glossy Anime Eyes (Rin's Deep Violet Eyes)
        drawAnimeEyes(
            context: context,
            eyeY: h * 0.42,
            spacing: w * 0.20,
            irisColor: CGColor(red: 0.42, green: 0.28, blue: 0.65, alpha: 0.98)
        )
    }
    
    // MARK: - 2. Haru (The Study Partner)
    private func drawHaru(context: CGContext, w: CGFloat, h: CGFloat) {
        // Cream knit sweater
        let sweaterRect = CGRect(x: -w * 0.50, y: 0, width: w, height: h * 0.62)
        context.setFillColor(CGColor(red: 0.94, green: 0.90, blue: 0.84, alpha: 1.0))
        context.addPath(CGPath(roundedRect: sweaterRect, cornerWidth: 14.0, cornerHeight: 14.0, transform: nil))
        context.fillPath()
        
        // Soft peach face
        let faceRect = CGRect(x: -w * 0.34, y: h * 0.22, width: w * 0.68, height: h * 0.52)
        context.setFillColor(CGColor(red: 1.0, green: 0.92, blue: 0.88, alpha: 1.0))
        context.addPath(CGPath(roundedRect: faceRect, cornerWidth: w * 0.30, cornerHeight: h * 0.26, transform: nil))
        context.fillPath()
        
        // Warm brown hair with messy bun
        context.setFillColor(CGColor(red: 0.38, green: 0.24, blue: 0.16, alpha: 1.0))
        // Top bun
        context.fillEllipse(in: CGRect(x: -12.0, y: h * 0.74, width: 24.0, height: 20.0))
        // Hair top
        context.fillEllipse(in: CGRect(x: -w * 0.38, y: h * 0.52, width: w * 0.76, height: h * 0.28))
        
        // Round Glasses (Golden / Amber wire frames)
        context.setStrokeColor(CGColor(red: 0.78, green: 0.62, blue: 0.28, alpha: 0.95))
        context.setLineWidth(1.6)
        let glassR: CGFloat = 8.5
        let glassY = h * 0.42
        let glassSpacing = w * 0.18
        context.strokeEllipse(in: CGRect(x: -glassSpacing - glassR, y: glassY - glassR, width: glassR * 2.0, height: glassR * 2.0))
        context.strokeEllipse(in: CGRect(x: glassSpacing - glassR, y: glassY - glassR, width: glassR * 2.0, height: glassR * 2.0))
        // Bridge
        context.beginPath()
        context.move(to: CGPoint(x: -glassSpacing + glassR, y: glassY))
        context.addLine(to: CGPoint(x: glassSpacing - glassR, y: glassY))
        context.strokePath()
        
        drawBlush(context: context, y: h * 0.30, offset: w * 0.22)
        
        // Warm amber anime eyes
        drawAnimeEyes(
            context: context,
            eyeY: glassY,
            spacing: glassSpacing,
            irisColor: CGColor(red: 0.52, green: 0.32, blue: 0.16, alpha: 0.98)
        )
    }
    
    // MARK: - 3. Pamu (The Chill Red Panda)
    private func drawPamu(context: CGContext, w: CGFloat, h: CGFloat) {
        // Striped fluffy tail swaying
        let tailSway = sin(entity.tailPhase) * 14.0
        context.saveGState()
        context.beginPath()
        context.move(to: CGPoint(x: -w * 0.32, y: h * 0.2))
        context.addCurve(to: CGPoint(x: -w * 0.48 + tailSway, y: h * 0.55),
                          control1: CGPoint(x: -w * 0.48, y: h * 0.3),
                          control2: CGPoint(x: -w * 0.58 + tailSway, y: h * 0.4))
        context.setLineWidth(14.0)
        context.setLineCap(.round)
        context.setStrokeColor(CGColor(red: 0.78, green: 0.36, blue: 0.20, alpha: 1.0))
        context.strokePath()
        context.restoreGState()
        
        // Red panda ears
        context.setFillColor(CGColor(red: 0.78, green: 0.36, blue: 0.20, alpha: 1.0))
        context.fillEllipse(in: CGRect(x: -w * 0.46, y: h * 0.60, width: 18.0, height: 18.0))
        context.fillEllipse(in: CGRect(x: w * 0.46 - 18.0, y: h * 0.60, width: 18.0, height: 18.0))
        // White inner ear fluff
        context.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.95))
        context.fillEllipse(in: CGRect(x: -w * 0.42, y: h * 0.62, width: 12.0, height: 12.0))
        context.fillEllipse(in: CGRect(x: w * 0.42 - 12.0, y: h * 0.62, width: 12.0, height: 12.0))
        
        // Red coat body
        let bodyRect = CGRect(x: -w * 0.45, y: 0, width: w * 0.90, height: h * 0.72)
        context.setFillColor(CGColor(red: 0.82, green: 0.38, blue: 0.20, alpha: 1.0))
        context.addPath(CGPath(roundedRect: bodyRect, cornerWidth: w * 0.42, cornerHeight: h * 0.35, transform: nil))
        context.fillPath()
        
        // White facial markings (cheeks & brows)
        context.setFillColor(CGColor(red: 1.0, green: 0.98, blue: 0.95, alpha: 0.95))
        context.fillEllipse(in: CGRect(x: -w * 0.38, y: h * 0.22, width: 18.0, height: 22.0))
        context.fillEllipse(in: CGRect(x: w * 0.38 - 18.0, y: h * 0.22, width: 18.0, height: 22.0))
        // White muzzle
        context.fillEllipse(in: CGRect(x: -12.0, y: h * 0.18, width: 24.0, height: 18.0))
        
        // Paws draped over window ledge
        context.setFillColor(CGColor(red: 0.22, green: 0.16, blue: 0.14, alpha: 1.0))
        context.fillEllipse(in: CGRect(x: -w * 0.35, y: -2.0, width: 16.0, height: 12.0))
        context.fillEllipse(in: CGRect(x: w * 0.35 - 16.0, y: -2.0, width: 16.0, height: 12.0))
        
        // Cute dark eyes
        drawAnimeEyes(context: context, eyeY: h * 0.38, spacing: w * 0.20, irisColor: CGColor(red: 0.15, green: 0.12, blue: 0.10, alpha: 1.0))
    }
    
    // MARK: - 4. Kota (The Energetic Pup)
    private func drawKota(context: CGContext, w: CGFloat, h: CGFloat) {
        // Red bandana
        let bandana = CGMutablePath()
        bandana.move(to: CGPoint(x: -w * 0.35, y: h * 0.22))
        bandana.addLine(to: CGPoint(x: 0, y: -2.0))
        bandana.addLine(to: CGPoint(x: w * 0.35, y: h * 0.22))
        bandana.closeSubpath()
        context.setFillColor(CGColor(red: 0.90, green: 0.22, blue: 0.20, alpha: 1.0))
        context.addPath(bandana)
        context.fillPath()
        
        // Pointed Shiba ears
        context.setFillColor(CGColor(red: 0.88, green: 0.58, blue: 0.32, alpha: 1.0))
        let leftEar = CGMutablePath()
        leftEar.move(to: CGPoint(x: -w * 0.42, y: h * 0.55))
        leftEar.addLine(to: CGPoint(x: -w * 0.26, y: h * 0.88))
        leftEar.addLine(to: CGPoint(x: -w * 0.12, y: h * 0.62))
        leftEar.closeSubpath()
        
        let rightEar = CGMutablePath()
        rightEar.move(to: CGPoint(x: w * 0.12, y: h * 0.62))
        rightEar.addLine(to: CGPoint(x: w * 0.26, y: h * 0.88))
        rightEar.addLine(to: CGPoint(x: w * 0.42, y: h * 0.55))
        rightEar.closeSubpath()
        
        context.addPath(leftEar)
        context.addPath(rightEar)
        context.fillPath()
        
        // Golden Shiba head
        let headRect = CGRect(x: -w * 0.42, y: h * 0.12, width: w * 0.84, height: h * 0.58)
        context.addPath(CGPath(roundedRect: headRect, cornerWidth: w * 0.38, cornerHeight: h * 0.28, transform: nil))
        context.fillPath()
        
        // White cheeks & muzzle
        context.setFillColor(CGColor(red: 1.0, green: 0.98, blue: 0.94, alpha: 1.0))
        context.fillEllipse(in: CGRect(x: -w * 0.35, y: h * 0.14, width: 22.0, height: 22.0))
        context.fillEllipse(in: CGRect(x: w * 0.35 - 22.0, y: h * 0.14, width: 22.0, height: 22.0))
        context.fillEllipse(in: CGRect(x: -14.0, y: h * 0.16, width: 28.0, height: 20.0))
        
        // Happy open smiling mouth :D
        context.setFillColor(CGColor(red: 0.95, green: 0.38, blue: 0.48, alpha: 1.0))
        context.fillEllipse(in: CGRect(x: -6.0, y: h * 0.12, width: 12.0, height: 10.0))
        
        // Happy curved eyes
        drawAnimeEyes(context: context, eyeY: h * 0.40, spacing: w * 0.20, irisColor: CGColor(red: 0.22, green: 0.15, blue: 0.10, alpha: 1.0))
    }
    
    // MARK: - 5. Mochi (The Sleepy Cat)
    private func drawMochi(context: CGContext, w: CGFloat, h: CGFloat) {
        // Calico Cat curled / loafing on the window ledge
        let catRect = CGRect(x: -w * 0.46, y: 0, width: w * 0.92, height: h * 0.58)
        context.setFillColor(CGColor(red: 0.98, green: 0.96, blue: 0.92, alpha: 1.0))
        context.addPath(CGPath(roundedRect: catRect, cornerWidth: w * 0.42, cornerHeight: h * 0.28, transform: nil))
        context.fillPath()
        
        // Calico ginger and dark spots
        context.setFillColor(CGColor(red: 0.88, green: 0.48, blue: 0.22, alpha: 0.95))
        context.fillEllipse(in: CGRect(x: -w * 0.40, y: h * 0.32, width: 20.0, height: 18.0))
        context.setFillColor(CGColor(red: 0.24, green: 0.20, blue: 0.18, alpha: 0.95))
        context.fillEllipse(in: CGRect(x: w * 0.15, y: h * 0.28, width: 22.0, height: 16.0))
        
        // Cat ears
        context.setFillColor(CGColor(red: 0.88, green: 0.48, blue: 0.22, alpha: 1.0))
        let ear1 = CGMutablePath()
        ear1.move(to: CGPoint(x: -w * 0.38, y: h * 0.50))
        ear1.addLine(to: CGPoint(x: -w * 0.25, y: h * 0.72))
        ear1.addLine(to: CGPoint(x: -w * 0.12, y: h * 0.52))
        ear1.closeSubpath()
        context.addPath(ear1)
        context.fillPath()
        
        context.setFillColor(CGColor(red: 0.24, green: 0.20, blue: 0.18, alpha: 1.0))
        let ear2 = CGMutablePath()
        ear2.move(to: CGPoint(x: w * 0.12, y: h * 0.52))
        ear2.addLine(to: CGPoint(x: w * 0.25, y: h * 0.72))
        ear2.addLine(to: CGPoint(x: w * 0.38, y: h * 0.50))
        ear2.closeSubpath()
        context.addPath(ear2)
        context.fillPath()
        
        // Paws tucked under chin
        context.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0))
        context.fillEllipse(in: CGRect(x: -w * 0.28, y: -2.0, width: 16.0, height: 10.0))
        context.fillEllipse(in: CGRect(x: w * 0.12, y: -2.0, width: 16.0, height: 10.0))
        
        // Sleepy curved eyes & pink nose
        drawAnimeEyes(context: context, eyeY: h * 0.32, spacing: w * 0.18, irisColor: CGColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0))
    }
    
    // MARK: - 6. Bit (The Desktop Bot)
    private func drawBit(context: CGContext, w: CGFloat, h: CGFloat) {
        // Antenna
        context.setStrokeColor(CGColor(red: 0.35, green: 0.38, blue: 0.45, alpha: 1.0))
        context.setLineWidth(2.5)
        context.beginPath()
        context.move(to: CGPoint(x: 0, y: h * 0.68))
        context.addLine(to: CGPoint(x: 0, y: h * 0.88))
        context.strokePath()
        
        // Antenna LED ball
        let ledColor = entity.isTypingObserved
            ? CGColor(red: 0.15, green: 0.95, blue: 0.75, alpha: 1.0)
            : CGColor(red: 0.20, green: 0.80, blue: 1.0, alpha: 0.9)
        context.setFillColor(ledColor)
        context.fillEllipse(in: CGRect(x: -5.0, y: h * 0.86, width: 10.0, height: 10.0))
        
        // CRT Monitor Case (Beige/Retro Gray)
        let monitorRect = CGRect(x: -w * 0.44, y: h * 0.12, width: w * 0.88, height: h * 0.58)
        context.setFillColor(CGColor(red: 0.88, green: 0.88, blue: 0.85, alpha: 1.0))
        context.addPath(CGPath(roundedRect: monitorRect, cornerWidth: 10.0, cornerHeight: 10.0, transform: nil))
        context.fillPath()
        
        // Dark Curved Screen
        let screenRect = CGRect(x: -w * 0.36, y: h * 0.18, width: w * 0.72, height: h * 0.44)
        context.setFillColor(CGColor(red: 0.10, green: 0.12, blue: 0.18, alpha: 1.0))
        context.addPath(CGPath(roundedRect: screenRect, cornerWidth: 6.0, cornerHeight: 6.0, transform: nil))
        context.fillPath()
        
        // Cyan Pixel Eyes (^ ^ or O O)
        context.setFillColor(CGColor(red: 0.16, green: 0.94, blue: 0.98, alpha: 1.0))
        let eyeY = h * 0.38
        if entity.isTypingObserved {
            // O O pixel circles
            context.fillEllipse(in: CGRect(x: -w * 0.24, y: eyeY - 5.0, width: 10.0, height: 10.0))
            context.fillEllipse(in: CGRect(x: w * 0.24 - 10.0, y: eyeY - 5.0, width: 10.0, height: 10.0))
        } else {
            // ^ ^ pixel chevrons
            context.setStrokeColor(CGColor(red: 0.16, green: 0.94, blue: 0.98, alpha: 1.0))
            context.setLineWidth(2.5)
            context.setLineCap(.round)
            context.beginPath()
            context.move(to: CGPoint(x: -w * 0.26, y: eyeY - 3.0))
            context.addLine(to: CGPoint(x: -w * 0.18, y: eyeY + 4.0))
            context.addLine(to: CGPoint(x: -w * 0.10, y: eyeY - 3.0))
            context.strokePath()
            
            context.beginPath()
            context.move(to: CGPoint(x: w * 0.10, y: eyeY - 3.0))
            context.addLine(to: CGPoint(x: w * 0.18, y: eyeY + 4.0))
            context.addLine(to: CGPoint(x: w * 0.26, y: eyeY - 3.0))
            context.strokePath()
        }
        
        // Robot feet on ledge
        context.setFillColor(CGColor(red: 0.25, green: 0.28, blue: 0.34, alpha: 1.0))
        context.fillEllipse(in: CGRect(x: -w * 0.30, y: -2.0, width: 14.0, height: 10.0))
        context.fillEllipse(in: CGRect(x: w * 0.30 - 14.0, y: -2.0, width: 14.0, height: 10.0))
    }
    
    // MARK: - 7. Hikaru (The Tiny Spirit)
    private func drawHikaru(context: CGContext, w: CGFloat, h: CGFloat) {
        // Floating blue/purple spirit flame with bioluminescent glow
        let flamePath = CGMutablePath()
        flamePath.move(to: CGPoint(x: 0, y: h * 0.88))
        flamePath.addCurve(to: CGPoint(x: w * 0.38, y: h * 0.35),
                           control1: CGPoint(x: w * 0.25, y: h * 0.75),
                           control2: CGPoint(x: w * 0.42, y: h * 0.55))
        flamePath.addCurve(to: CGPoint(x: 0, y: 4.0),
                           control1: CGPoint(x: w * 0.34, y: h * 0.12),
                           control2: CGPoint(x: w * 0.15, y: 4.0))
        flamePath.addCurve(to: CGPoint(x: -w * 0.38, y: h * 0.35),
                           control1: CGPoint(x: -w * 0.15, y: 4.0),
                           control2: CGPoint(x: -w * 0.34, y: h * 0.12))
        flamePath.addCurve(to: CGPoint(x: 0, y: h * 0.88),
                           control1: CGPoint(x: -w * 0.42, y: h * 0.55),
                           control2: CGPoint(x: -w * 0.25, y: h * 0.75))
        flamePath.closeSubpath()
        
        // Outer soft aura
        context.saveGState()
        context.addPath(flamePath)
        context.setFillColor(CGColor(red: 0.45, green: 0.65, blue: 1.0, alpha: 0.90))
        context.fillPath()
        
        // Inner glowing core
        let coreRect = CGRect(x: -w * 0.22, y: h * 0.16, width: w * 0.44, height: h * 0.40)
        context.setFillColor(CGColor(red: 0.90, green: 0.96, blue: 1.0, alpha: 0.95))
        context.fillEllipse(in: coreRect)
        context.restoreGState()
        
        // Cute spirit eyes
        let eyeY = h * 0.36
        context.setFillColor(CGColor(red: 0.12, green: 0.20, blue: 0.45, alpha: 0.98))
        context.fillEllipse(in: CGRect(x: -12.0, y: eyeY, width: 5.5, height: 7.0))
        context.fillEllipse(in: CGRect(x: 6.5, y: eyeY, width: 5.5, height: 7.0))
    }
    
    // MARK: - Helpers: Blush & Anime Eyes
    private func drawBlush(context: CGContext, y: CGFloat, offset: CGFloat) {
        context.setStrokeColor(CGColor(red: 1.0, green: 0.42, blue: 0.58, alpha: 0.75))
        context.setLineWidth(1.5)
        context.setLineCap(.round)
        
        for i in 0..<3 {
            let ox = -offset + CGFloat(i) * 3.0
            context.beginPath()
            context.move(to: CGPoint(x: ox - 2.0, y: y - 2.5))
            context.addLine(to: CGPoint(x: ox + 2.0, y: y + 2.5))
            context.strokePath()
        }
        
        for i in 0..<3 {
            let ox = offset - CGFloat(i) * 3.0
            context.beginPath()
            context.move(to: CGPoint(x: ox - 2.0, y: y - 2.5))
            context.addLine(to: CGPoint(x: ox + 2.0, y: y + 2.5))
            context.strokePath()
        }
    }
    
    private func drawAnimeEyes(context: CGContext, eyeY: CGFloat, spacing: CGFloat, irisColor: CGColor) {
        let eyeW: CGFloat = 8.0
        let eyeH: CGFloat = 11.5
        
        let gazeX = entity.eyeOffset.x * 2.0
        let gazeY = entity.eyeOffset.y * 1.8
        
        let leftEyeCenter = CGPoint(x: -spacing + gazeX, y: eyeY + gazeY)
        let rightEyeCenter = CGPoint(x: spacing + gazeX, y: eyeY + gazeY)
        
        if entity.state == .sleeping || entity.blinkFactor > 0.6 {
            // Happy closed eyes ( > ω < )
            context.setStrokeColor(CGColor(red: 0.10, green: 0.12, blue: 0.22, alpha: 0.90))
            context.setLineWidth(2.2)
            context.setLineCap(.round)
            
            context.beginPath()
            context.addArc(center: CGPoint(x: -spacing, y: eyeY), radius: eyeW * 0.8, startAngle: .pi * 0.2, endAngle: .pi * 0.8, clockwise: false)
            context.strokePath()
            
            context.beginPath()
            context.addArc(center: CGPoint(x: spacing, y: eyeY), radius: eyeW * 0.8, startAngle: .pi * 0.2, endAngle: .pi * 0.8, clockwise: false)
            context.strokePath()
        } else {
            // White sclera
            context.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.98))
            context.fillEllipse(in: CGRect(x: leftEyeCenter.x - eyeW, y: leftEyeCenter.y - eyeH * 0.5, width: eyeW * 2.0, height: eyeH))
            context.fillEllipse(in: CGRect(x: rightEyeCenter.x - eyeW, y: rightEyeCenter.y - eyeH * 0.5, width: eyeW * 2.0, height: eyeH))
            
            // Iris
            let irisW = eyeW * 1.3
            let irisH = eyeH * 0.92
            context.setFillColor(irisColor)
            context.fillEllipse(in: CGRect(x: leftEyeCenter.x - irisW * 0.5, y: leftEyeCenter.y - irisH * 0.5, width: irisW, height: irisH))
            context.fillEllipse(in: CGRect(x: rightEyeCenter.x - irisW * 0.5, y: rightEyeCenter.y - irisH * 0.5, width: irisW, height: irisH))
            
            // Deep pupil
            let pupilW = irisW * 0.55
            let pupilH = irisH * 0.60
            context.setFillColor(CGColor(red: 0.05, green: 0.08, blue: 0.18, alpha: 0.98))
            context.fillEllipse(in: CGRect(x: leftEyeCenter.x - pupilW * 0.5, y: leftEyeCenter.y - pupilH * 0.5, width: pupilW, height: pupilH))
            context.fillEllipse(in: CGRect(x: rightEyeCenter.x - pupilW * 0.5, y: rightEyeCenter.y - pupilH * 0.5, width: pupilW, height: pupilH))
            
            // Primary Sparkling Glint (Top Right)
            let glintRadius: CGFloat = entity.isTypingObserved ? 2.5 : 2.0
            context.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.98))
            context.fillEllipse(in: CGRect(x: leftEyeCenter.x + 1.2, y: leftEyeCenter.y + 1.2, width: glintRadius * 2.0, height: glintRadius * 2.0))
            context.fillEllipse(in: CGRect(x: rightEyeCenter.x + 1.2, y: rightEyeCenter.y + 1.2, width: glintRadius * 2.0, height: glintRadius * 2.0))
            
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
