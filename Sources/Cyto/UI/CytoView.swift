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
        entity.applySquish(x: 0.85, y: 1.25) // Stretches like ectoplasm when picked up
        
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
        
        // Petting detection
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
            
            let cappedDx = max(-950.0, min(950.0, avgDx * 0.85))
            let cappedDy = max(-750.0, min(950.0, avgDy * 0.85))
            entity.velocity = CGVector(dx: cappedDx, dy: cappedDy)
        } else {
            entity.velocity = .zero
        }
        
        entity.transition(to: .falling)
        entity.applySquish(x: 1.15, y: 0.85)
        
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
        needsDisplay = true
    }
    
    // MARK: - Procedural Ghost Rendering
    
    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        context.saveGState()
        
        let cx = bounds.midX
        // Levitating vertical hover oscillation
        let hoverBob = sin(entity.floatPhase) * 5.0
        let cy: CGFloat = 6.0 + hoverBob
        let w = entity.size.width * entity.squishX
        let h = entity.size.height * entity.squishY
        
        let tilt = entity.isTypingObserved ? entity.curiousTilt : 0.0
        let breathScale = 1.0 + sin(entity.breathPhase) * 0.025
        let walkAngle = (entity.state == .walking) ? sin(entity.walkPhase) * 0.09 : 0.0
        
        context.translateBy(x: cx, y: cy)
        context.rotate(by: walkAngle + tilt)
        context.scaleBy(x: breathScale, y: breathScale)
        
        // 1. Soft Spectral Drop Shadow on Window Titlebar
        if entity.state.isGrounded {
            let shadowW = w * 0.75
            let shadowH: CGFloat = 6.0
            let shadowRect = CGRect(x: -shadowW / 2.0, y: -hoverBob - 2.0, width: shadowW, height: shadowH)
            context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0.20))
            context.fillEllipse(in: shadowRect)
        }
        
        // 2. Orbiting Spirit Flame: Behind pass
        let isOrbInFront = sin(entity.orbOrbitPhase) >= 0
        if !isOrbInFront {
            drawSpiritOrb(context: context, w: w, h: h)
        }
        
        // 3. Ghost Spectral Aura Glow
        drawSpectralAura(context: context, w: w, h: h)
        
        // 4. Ghost Ectoplasm Body with Animated Rippling Hem
        drawGhostBody(context: context, w: w, h: h)
        
        // 5. Ghost Nub Arms (Resting on ledge or floating)
        drawGhostArms(context: context, w: w, h: h)
        
        // 6. Facial Blush
        drawGhostBlush(context: context, w: w, h: h)
        
        // 7. Expressive Anime Eyes (Glossy with cursor gaze tracking)
        drawGhostEyes(context: context, w: w, h: h)
        
        // 8. Cute Ghost Mouth (Cat lip ω with tiny fang)
        drawGhostMouth(context: context, w: w, h: h)
        
        // 9. Orbiting Spirit Flame: Front pass
        if isOrbInFront {
            drawSpiritOrb(context: context, w: w, h: h)
        }
        
        context.restoreGState()
        
        // 10. Manga Speech Bubble on Enter
        if let speech = entity.speechBubbleText, entity.speechBubbleTimer > 0 {
            drawSpeechBubble(context: context, text: speech, topY: cy + h + 10.0)
        }
    }
    
    // MARK: - Spectral Aura Glow
    private func drawSpectralAura(context: CGContext, w: CGFloat, h: CGFloat) {
        context.saveGState()
        
        let auraColor: CGColor
        switch entity.aura {
        case .moonlight:
            auraColor = CGColor(red: 0.25, green: 0.88, blue: 1.0, alpha: 0.28)
        case .phantom:
            auraColor = CGColor(red: 0.72, green: 0.45, blue: 1.0, alpha: 0.28)
        case .ectoMint:
            auraColor = CGColor(red: 0.20, green: 1.0, blue: 0.65, alpha: 0.28)
        case .emberGold:
            auraColor = CGColor(red: 1.0, green: 0.75, blue: 0.25, alpha: 0.28)
        }
        
        let auraRect = CGRect(x: -w * 0.54, y: 0, width: w * 1.08, height: h * 0.98)
        context.setFillColor(auraColor)
        context.setShadow(offset: .zero, blur: 16.0, color: auraColor)
        context.fillEllipse(in: auraRect)
        
        context.restoreGState()
    }
    
    // MARK: - Ectoplasm Body with Animated Multi-Point Ripple Hem
    private func drawGhostBody(context: CGContext, w: CGFloat, h: CGFloat) {
        let path = CGMutablePath()
        
        let headR = w * 0.46
        let headCenterY = h - headR
        
        // Dome top (Head)
        path.addArc(center: CGPoint(x: 0, y: headCenterY), radius: headR, startAngle: 0, endAngle: .pi, clockwise: false)
        
        // Left side tapering down
        let leftBottom = CGPoint(x: -headR, y: 0)
        path.addLine(to: leftBottom)
        
        // Animated rippling ruffles across the bottom hem
        // 4 fluid ectoplasm ripples moving with wispPhase
        let rippleCount = 4
        let segmentW = (headR * 2.0) / CGFloat(rippleCount)
        
        for i in 0..<rippleCount {
            let startX = -headR + CGFloat(i) * segmentW
            let endX = startX + segmentW
            let midX = (startX + endX) / 2.0
            
            // Dynamic wave offset using sine oscillation
            let waveOffset = sin(entity.wispPhase + CGFloat(i) * 1.4) * 5.0
            let dipY = 3.0 + waveOffset
            
            path.addQuadCurve(to: CGPoint(x: endX, y: 0), control: CGPoint(x: midX, y: dipY))
        }
        
        // Right side closing up to dome
        path.addLine(to: CGPoint(x: headR, y: headCenterY))
        path.closeSubpath()
        
        context.saveGState()
        context.addPath(path)
        context.clip()
        
        // Spectral gradient fill (Pure ethereal white down to translucent spectral tint)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let topColor: CGColor
        let bottomColor: CGColor
        
        switch entity.aura {
        case .moonlight:
            topColor = CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.98)
            bottomColor = CGColor(red: 0.82, green: 0.94, blue: 1.0, alpha: 0.88)
        case .phantom:
            topColor = CGColor(red: 1.0, green: 0.98, blue: 1.0, alpha: 0.98)
            bottomColor = CGColor(red: 0.90, green: 0.82, blue: 1.0, alpha: 0.88)
        case .ectoMint:
            topColor = CGColor(red: 1.0, green: 1.0, blue: 0.98, alpha: 0.98)
            bottomColor = CGColor(red: 0.80, green: 1.0, blue: 0.88, alpha: 0.88)
        case .emberGold:
            topColor = CGColor(red: 1.0, green: 0.99, blue: 0.96, alpha: 0.98)
            bottomColor = CGColor(red: 1.0, green: 0.90, blue: 0.78, alpha: 0.88)
        }
        
        if let gradient = CGGradient(colorsSpace: colorSpace, colors: [topColor, bottomColor] as CFArray, locations: [0.0, 1.0]) {
            context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: h), end: CGPoint(x: 0, y: 0), options: [])
        }
        
        // Inner glowing soul core
        let coreY = h * 0.38
        let coreSize = CGSize(width: w * 0.38, height: h * 0.35)
        context.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.45))
        context.fillEllipse(in: CGRect(x: -coreSize.width / 2.0, y: coreY, width: coreSize.width, height: coreSize.height))
        
        context.restoreGState()
        
        // Soft ethereal outer edge stroke
        context.addPath(path)
        context.setStrokeColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.85))
        context.setLineWidth(1.8)
        context.strokePath()
    }
    
    // MARK: - Ghost Nub Arms
    private func drawGhostArms(context: CGContext, w: CGFloat, h: CGFloat) {
        let armW: CGFloat = 13.0
        let armH: CGFloat = 8.5
        let armY = h * 0.28
        let armSpacing = w * 0.42
        
        context.setFillColor(CGColor(red: 0.94, green: 0.98, blue: 1.0, alpha: 0.95))
        context.setStrokeColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.90))
        context.setLineWidth(1.4)
        
        if entity.state.isGrounded {
            // Little hands resting flat over the titlebar edge!
            let leftHand = CGRect(x: -armSpacing - armW * 0.5, y: -2.0, width: armW, height: armH)
            let rightHand = CGRect(x: armSpacing - armW * 0.5, y: -2.0, width: armW, height: armH)
            
            context.fillEllipse(in: leftHand)
            context.strokeEllipse(in: leftHand)
            context.fillEllipse(in: rightHand)
            context.strokeEllipse(in: rightHand)
        } else {
            // Floating arms lifted like wings
            let leftArm = CGRect(x: -armSpacing - armW * 0.5, y: armY, width: armW, height: armH)
            let rightArm = CGRect(x: armSpacing - armW * 0.5, y: armY, width: armW, height: armH)
            
            context.fillEllipse(in: leftArm)
            context.strokeEllipse(in: leftArm)
            context.fillEllipse(in: rightArm)
            context.strokeEllipse(in: rightArm)
        }
    }
    
    // MARK: - Facial Blush
    private func drawGhostBlush(context: CGContext, w: CGFloat, h: CGFloat) {
        let blushY = h * 0.40
        let offset = w * 0.26
        
        context.setStrokeColor(CGColor(red: 1.0, green: 0.42, blue: 0.62, alpha: 0.70))
        context.setLineWidth(1.4)
        context.setLineCap(.round)
        
        for i in 0..<3 {
            let ox = -offset + CGFloat(i) * 2.8
            context.beginPath()
            context.move(to: CGPoint(x: ox - 1.5, y: blushY - 2.5))
            context.addLine(to: CGPoint(x: ox + 1.5, y: blushY + 2.5))
            context.strokePath()
        }
        
        for i in 0..<3 {
            let ox = offset - CGFloat(i) * 2.8
            context.beginPath()
            context.move(to: CGPoint(x: ox - 1.5, y: blushY - 2.5))
            context.addLine(to: CGPoint(x: ox + 1.5, y: blushY + 2.5))
            context.strokePath()
        }
    }
    
    // MARK: - Expressive Anime Ghost Eyes
    private func drawGhostEyes(context: CGContext, w: CGFloat, h: CGFloat) {
        let spacing = w * 0.22
        let eyeY = h * 0.52
        let eyeW: CGFloat = 8.5
        let eyeH: CGFloat = 12.0
        
        let gazeX = entity.eyeOffset.x * 2.2
        let gazeY = entity.eyeOffset.y * 1.8
        
        let leftEyeCenter = CGPoint(x: -spacing + gazeX, y: eyeY + gazeY)
        let rightEyeCenter = CGPoint(x: spacing + gazeX, y: eyeY + gazeY)
        
        if entity.state == .sleeping || entity.blinkFactor > 0.6 {
            // Happy closed eyes ( > ω < )
            context.setStrokeColor(CGColor(red: 0.12, green: 0.18, blue: 0.35, alpha: 0.90))
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
            
            // Deep Indigo / Midnight Iris
            let irisW = eyeW * 1.3
            let irisH = eyeH * 0.92
            context.setFillColor(CGColor(red: 0.10, green: 0.18, blue: 0.42, alpha: 0.96))
            context.fillEllipse(in: CGRect(x: leftEyeCenter.x - irisW * 0.5, y: leftEyeCenter.y - irisH * 0.5, width: irisW, height: irisH))
            context.fillEllipse(in: CGRect(x: rightEyeCenter.x - irisW * 0.5, y: rightEyeCenter.y - irisH * 0.5, width: irisW, height: irisH))
            
            // Pupil
            let pupilW = irisW * 0.55
            let pupilH = irisH * 0.60
            context.setFillColor(CGColor(red: 0.04, green: 0.06, blue: 0.16, alpha: 0.98))
            context.fillEllipse(in: CGRect(x: leftEyeCenter.x - pupilW * 0.5, y: leftEyeCenter.y - pupilH * 0.5, width: pupilW, height: pupilH))
            context.fillEllipse(in: CGRect(x: rightEyeCenter.x - pupilW * 0.5, y: rightEyeCenter.y - pupilH * 0.5, width: pupilW, height: pupilH))
            
            // Primary Sparkling Celestial Glint (Top Right)
            let glintR: CGFloat = entity.isTypingObserved ? 2.6 : 2.0
            context.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.98))
            context.fillEllipse(in: CGRect(x: leftEyeCenter.x + 1.2, y: leftEyeCenter.y + 1.2, width: glintR * 2.0, height: glintR * 2.0))
            context.fillEllipse(in: CGRect(x: rightEyeCenter.x + 1.2, y: rightEyeCenter.y + 1.2, width: glintR * 2.0, height: glintR * 2.0))
            
            // Secondary Micro Glint (Bottom Left)
            let microGlint: CGFloat = 1.1
            context.fillEllipse(in: CGRect(x: leftEyeCenter.x - 3.2, y: leftEyeCenter.y - 2.8, width: microGlint * 2.0, height: microGlint * 2.0))
            context.fillEllipse(in: CGRect(x: rightEyeCenter.x - 3.2, y: rightEyeCenter.y - 2.8, width: microGlint * 2.0, height: microGlint * 2.0))
            
            // Upper Eyelash Line
            context.setStrokeColor(CGColor(red: 0.08, green: 0.10, blue: 0.22, alpha: 0.95))
            context.setLineWidth(2.0)
            context.beginPath()
            context.addArc(center: CGPoint(x: leftEyeCenter.x, y: leftEyeCenter.y + 1.0), radius: eyeW, startAngle: .pi * 0.15, endAngle: .pi * 0.85, clockwise: false)
            context.strokePath()
            
            context.beginPath()
            context.addArc(center: CGPoint(x: rightEyeCenter.x, y: rightEyeCenter.y + 1.0), radius: eyeW, startAngle: .pi * 0.15, endAngle: .pi * 0.85, clockwise: false)
            context.strokePath()
        }
    }
    
    // MARK: - Cute Ghost Mouth with Tiny Fang
    private func drawGhostMouth(context: CGContext, w: CGFloat, h: CGFloat) {
        let mouthY = h * 0.38
        context.setStrokeColor(CGColor(red: 0.10, green: 0.15, blue: 0.32, alpha: 0.85))
        context.setLineWidth(1.6)
        context.setLineCap(.round)
        
        if entity.isTypingObserved {
            // Little curious open mouth :o
            context.setFillColor(CGColor(red: 1.0, green: 0.45, blue: 0.58, alpha: 0.85))
            let mouthRect = CGRect(x: -3.5, y: mouthY - 3.0, width: 7.0, height: 6.5)
            context.fillEllipse(in: mouthRect)
            context.strokeEllipse(in: mouthRect)
        } else {
            // Cute kitten lip ω with tiny fang!
            let r: CGFloat = 2.6
            context.beginPath()
            context.addArc(center: CGPoint(x: -r, y: mouthY), radius: r, startAngle: .pi * 0.9, endAngle: .pi * 0.1, clockwise: true)
            context.strokePath()
            
            context.beginPath()
            context.addArc(center: CGPoint(x: r, y: mouthY), radius: r, startAngle: .pi * 0.9, endAngle: .pi * 0.1, clockwise: true)
            context.strokePath()
            
            // Tiny white fang
            context.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.95))
            let fangPath = CGMutablePath()
            fangPath.move(to: CGPoint(x: -1.0, y: mouthY - 1.0))
            fangPath.addLine(to: CGPoint(x: 1.0, y: mouthY - 1.0))
            fangPath.addLine(to: CGPoint(x: 0, y: mouthY - 4.2))
            fangPath.closeSubpath()
            context.addPath(fangPath)
            context.fillPath()
        }
    }
    
    // MARK: - Orbiting Spirit Flame (Hitodama)
    private func drawSpiritOrb(context: CGContext, w: CGFloat, h: CGFloat) {
        let orbitRadiusX = w * 0.58
        let orbitRadiusY = h * 0.22
        let orbX = cos(entity.orbOrbitPhase) * orbitRadiusX
        let orbY = sin(entity.orbOrbitPhase) * orbitRadiusY + (h * 0.52)
        
        let orbR: CGFloat = 6.0
        let orbRect = CGRect(x: orbX - orbR, y: orbY - orbR, width: orbR * 2.0, height: orbR * 2.0)
        
        context.saveGState()
        
        let flameColor: CGColor
        switch entity.aura {
        case .moonlight:
            flameColor = CGColor(red: 0.20, green: 0.88, blue: 1.0, alpha: 0.85)
        case .phantom:
            flameColor = CGColor(red: 0.78, green: 0.48, blue: 1.0, alpha: 0.85)
        case .ectoMint:
            flameColor = CGColor(red: 0.25, green: 1.0, blue: 0.65, alpha: 0.85)
        case .emberGold:
            flameColor = CGColor(red: 1.0, green: 0.78, blue: 0.25, alpha: 0.85)
        }
        
        // Glowing aura of the orb
        context.setShadow(offset: .zero, blur: 8.0, color: flameColor)
        context.setFillColor(flameColor)
        context.fillEllipse(in: orbRect)
        
        // Bright white center core
        let coreR: CGFloat = 2.4
        context.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.95))
        context.fillEllipse(in: CGRect(x: orbX - coreR, y: orbY - coreR, width: coreR * 2.0, height: coreR * 2.0))
        
        context.restoreGState()
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
        
        // Pointer arrow pointing down to ghost head
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
