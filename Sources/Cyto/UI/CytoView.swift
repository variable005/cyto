import AppKit
import CoreGraphics

public final class CytoView: NSView {
    public let entity: CytoEntity
    private var dragStartMouseScreen: CGPoint = .zero
    private var dragStartEntityPos: CGPoint = .zero
    private var recentDragDeltas: [CGPoint] = []
    private var lastDragTime: Date = Date()
    private var petCounter: Int = 0
    
    public var onTimerTapped: (() -> Void)?
    public private(set) var activeBubbleRect: CGRect?
    public private(set) var activeTimerRect: CGRect?
    
    public init(frame frameRect: NSRect, entity: CytoEntity) {
        self.entity = entity
        super.init(frame: frameRect)
        self.wantsLayer = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Interactive Hit-Testing
    
    public override func hitTest(_ point: NSPoint) -> NSView? {
        if let timerRect = activeTimerRect, timerRect.contains(point) {
            return self
        }
        if let bubbleRect = activeBubbleRect, bubbleRect.contains(point) {
            return self
        }
        
        let cx = bounds.midX
        let isResting = (entity.state == .sleeping || entity.state == .sitting)
        let hoverBob = isResting ? 0.0 : (sin(entity.floatPhase) * 4.5)
        let cy = 6.0 + hoverBob + entity.size.height * 0.45
        let dist = hypot(point.x - cx, point.y - cy)
        
        // Accurate circular hit-test: clicks outside Jelly pass straight down to windows
        if dist <= 52.0 {
            return self
        }
        return nil
    }
    
    // MARK: - Mouse Interaction
    
    public override func mouseDown(with event: NSEvent) {
        let clickPoint = convert(event.locationInWindow, from: nil)
        if let timerRect = activeTimerRect, timerRect.contains(clickPoint) {
            onTimerTapped?()
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
            return
        }
        if let bubbleRect = activeBubbleRect, bubbleRect.contains(clickPoint) {
            entity.speechBubbleTimer = 0.0
            entity.speechBubbleText = nil
            needsDisplay = true
            return
        }
        
        dragStartMouseScreen = NSEvent.mouseLocation
        dragStartEntityPos = entity.position
        recentDragDeltas.removeAll()
        lastDragTime = Date()
        
        entity.isBeingInteractedWith = true
        entity.transition(to: .dragged)
        entity.velocity = .zero
        entity.applySquish(x: 0.88, y: 1.20)
        
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
        
        // Petting gesture
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
        
        let mouseScreen = NSEvent.mouseLocation
        let dragDist = hypot(mouseScreen.x - dragStartMouseScreen.x, mouseScreen.y - dragStartMouseScreen.y)
        
        if dragDist < 8.0 {
            // Direct tap / click on Jelly
            entity.registerDirectTap()
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        } else if !recentDragDeltas.isEmpty {
            let avgDx = recentDragDeltas.map { $0.x }.reduce(0, +) / CGFloat(recentDragDeltas.count)
            let avgDy = recentDragDeltas.map { $0.y }.reduce(0, +) / CGFloat(recentDragDeltas.count)
            
            let cappedDx = max(-950.0, min(950.0, avgDx * 0.85))
            let cappedDy = max(-750.0, min(950.0, avgDy * 0.85))
            entity.velocity = CGVector(dx: cappedDx, dy: cappedDy)
            entity.transition(to: .falling)
            entity.applySquish(x: 1.15, y: 0.85)
            NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
        } else {
            entity.velocity = .zero
            entity.transition(to: .falling)
            entity.applySquish(x: 1.15, y: 0.85)
        }
        
        needsDisplay = true
    }
    
    // MARK: - Drawing Jelly The Desktop Ghost
    
    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        context.saveGState()
        
        let cx = bounds.midX
        let isResting = (entity.state == .sleeping || entity.state == .sitting)
        // Levitating vertical hover oscillation (idle float keyframe, rests calmly when perched)
        let musicBob = (entity.isMusicPlaying && !isResting) ? (sin(entity.musicTempoPhase) * 2.8) : 0.0
        let hoverBob = isResting ? 0.0 : ((sin(entity.floatPhase) * 4.5) + musicBob)
        let cy: CGFloat = 6.0 + hoverBob
        let w = entity.size.width * entity.squishX
        let h = entity.size.height * entity.squishY
        
        let tilt = entity.isTypingObserved ? entity.curiousTilt : 0.0
        let musicTilt = entity.isMusicPlaying ? (sin(entity.musicTempoPhase) * 0.04) : 0.0
        let breathScale = 1.0 + sin(entity.breathPhase) * 0.02
        let walkAngle = (entity.state == .walking) ? sin(entity.walkPhase) * 0.07 : 0.0
        
        context.translateBy(x: cx, y: cy)
        context.rotate(by: walkAngle + tilt + musicTilt)
        context.scaleBy(x: breathScale, y: breathScale)
        
        // 1. Soft Lavender Drop Shadow on Window Titlebar
        if entity.state.isGrounded {
            let shadowW = w * 0.82
            let shadowH: CGFloat = isResting ? 7.0 : 5.5
            let shadowRect = CGRect(x: -shadowW / 2.0, y: -hoverBob - 2.0, width: shadowW, height: shadowH)
            context.setFillColor(CGColor(red: 0.24, green: 0.20, blue: 0.35, alpha: 0.25))
            context.fillEllipse(in: shadowRect)
        }
        
        // 2. Ghost Sheet Body (Lavender Ambient Shadows & Shading)
        drawGhostSheet(context: context, w: w, h: h)
        
        // 3. Studio Headphones with Glowing Neon Violet LED Ring
        drawHeadphones(context: context, w: w, h: h)
        
        // 4. Facial Expressions (Directly from Jelly's Design Sheet)
        drawJellyFace(context: context, w: w, h: h)
        
        // 5. Interactive Accessory Overlay (Coffee, Terminal)
        drawAccessory(context: context, w: w, h: h)
        
        // 6. Sleeping Zzz or Curious Sparkles or Floating Music Notes
        if entity.state == .sleeping || entity.expression == .sleepy {
            drawSleepingZzz(context: context, h: h)
        } else if entity.expression == .excited {
            drawExcitedSparkles(context: context, w: w, h: h)
        } else if entity.expression == .curious && entity.isTypingObserved {
            drawCuriousQuestionMark(context: context, w: w, h: h)
        }
        
        // 7. Floating Music Notes from Headphones
        if entity.isMusicPlaying {
            drawMusicNotes(context: context)
        }
        
        activeBubbleRect = nil
        activeTimerRect = nil
        
        context.restoreGState()
        
        // 9. Liquid Glass Speech Bubble
        if let speech = entity.speechBubbleText, entity.speechBubbleTimer > 0 {
            drawSpeechBubble(context: context, text: speech, baseY: cy + h + 10.0)
        }
    }
    
    // MARK: - Ghost Sheet Body
    private func drawGhostSheet(context: CGContext, w: CGFloat, h: CGFloat) {
        let path = CGMutablePath()
        
        // Clean rounded dome head
        let headR = w * 0.44
        let headCenterY = h - headR - 2.0
        
        path.addArc(center: CGPoint(x: 0, y: headCenterY), radius: headR, startAngle: 0, endAngle: .pi, clockwise: false)
        
        // Left side draping down
        let leftBottom = CGPoint(x: -headR - 2.0, y: 0)
        path.addLine(to: leftBottom)
        
        // Animated folds / ruffles along bottom hem
        let rippleCount = 4
        let segmentW = ((headR + 2.0) * 2.0) / CGFloat(rippleCount)
        let isResting = (entity.state == .sleeping || entity.state == .sitting)
        let waveAmp: CGFloat = isResting ? 1.5 : 4.5
        
        for i in 0..<rippleCount {
            let startX = -(headR + 2.0) + CGFloat(i) * segmentW
            let endX = startX + segmentW
            let midX = (startX + endX) / 2.0
            let rippleWave = sin(entity.wispPhase + CGFloat(i) * 1.4) * waveAmp
            path.addQuadCurve(to: CGPoint(x: endX, y: 0), control: CGPoint(x: midX, y: 4.0 + rippleWave))
        }
        
        // Right side closing up to dome
        path.addLine(to: CGPoint(x: headR, y: headCenterY))
        path.closeSubpath()
        
        context.saveGState()
        context.addPath(path)
        context.clip()
        
        // Soft Lavender / Nocturnal Twilight Gradient
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let topColor: CGColor
        let bottomColor: CGColor
        let strokeColor: CGColor
        
        if entity.isNightMode {
            // Ethereal midnight lavender / twilight luminescence
            topColor = CGColor(red: 0.94, green: 0.92, blue: 0.98, alpha: 0.97)
            bottomColor = CGColor(red: 0.72, green: 0.66, blue: 0.88, alpha: 0.96)
            strokeColor = CGColor(red: 0.62, green: 0.55, blue: 0.82, alpha: 0.95)
        } else {
            topColor = CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.98)
            bottomColor = CGColor(red: 0.85, green: 0.82, blue: 0.93, alpha: 0.96)
            strokeColor = CGColor(red: 0.74, green: 0.70, blue: 0.86, alpha: 0.90)
        }
        
        if let gradient = CGGradient(colorsSpace: colorSpace, colors: [topColor, bottomColor] as CFArray, locations: [0.0, 1.0]) {
            context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: h), end: CGPoint(x: 0, y: 0), options: [])
        }
        
        context.restoreGState()
        
        // Soft clean outline
        context.addPath(path)
        context.setStrokeColor(strokeColor)
        context.setLineWidth(1.6)
        context.strokePath()
    }
    
    // MARK: - Studio Headphones with Glowing Neon Violet Ring
    private func drawHeadphones(context: CGContext, w: CGFloat, h: CGFloat) {
        let headR = w * 0.44
        let headCenterY = h - headR - 2.0
        
        // Black Headband
        context.setStrokeColor(CGColor(red: 0.16, green: 0.14, blue: 0.22, alpha: 1.0)) // Deep obsidian
        context.setLineWidth(5.5)
        context.beginPath()
        context.addArc(center: CGPoint(x: 0, y: headCenterY + 2.0), radius: headR + 1.0, startAngle: .pi * 0.12, endAngle: .pi * 0.88, clockwise: false)
        context.strokePath()
        
        // Earcups Position
        let cupW: CGFloat = 13.0
        let cupH: CGFloat = 22.0
        let cupY = headCenterY - 6.0
        let leftCupRect = CGRect(x: -headR - cupW * 0.65, y: cupY, width: cupW, height: cupH)
        let rightCupRect = CGRect(x: headR - cupW * 0.35, y: cupY, width: cupW, height: cupH)
        
        // Dark Obsidian Earcups
        context.setFillColor(CGColor(red: 0.18, green: 0.16, blue: 0.25, alpha: 1.0))
        context.fillEllipse(in: leftCupRect)
        context.fillEllipse(in: rightCupRect)
        
        // Outer ear cushions
        context.setStrokeColor(CGColor(red: 0.10, green: 0.08, blue: 0.16, alpha: 1.0))
        context.setLineWidth(1.5)
        context.strokeEllipse(in: leftCupRect)
        context.strokeEllipse(in: rightCupRect)
        
        // Glowing Neon Violet LED Ring that pulses with music or ambient glow
        let glowAlpha: CGFloat
        let ringColor: CGColor
        if entity.isMusicPlaying {
            glowAlpha = 0.88 + sin(entity.musicTempoPhase * 2.0) * 0.12
            // Pulsing neon magenta / violet audio spectrum
            ringColor = CGColor(red: 0.96, green: 0.45, blue: 1.0, alpha: glowAlpha)
        } else {
            glowAlpha = 0.75 + sin(entity.headphoneGlowPhase) * 0.22
            ringColor = CGColor(red: 0.78, green: 0.52, blue: 1.0, alpha: glowAlpha)
        }
        
        context.saveGState()
        context.setShadow(offset: .zero, blur: entity.isMusicPlaying ? 10.0 : 7.0, color: ringColor)
        context.setStrokeColor(ringColor)
        context.setLineWidth(2.2)
        
        let ringInset: CGFloat = 2.8
        context.strokeEllipse(in: leftCupRect.insetBy(dx: ringInset, dy: ringInset))
        context.strokeEllipse(in: rightCupRect.insetBy(dx: ringInset, dy: ringInset))
        context.restoreGState()
    }
    

    
    // MARK: - Expressions (Exact Keyframes from Design Sheet)
    private func drawJellyFace(context: CGContext, w: CGFloat, h: CGFloat) {
        let eyeY = h * 0.52
        let spacing = w * 0.18
        
        // Blush marks
        drawBlush(context: context, y: eyeY - 6.0, offset: spacing + 12.0)
        
        context.saveGState()
        context.setStrokeColor(CGColor(red: 0.12, green: 0.10, blue: 0.18, alpha: 0.95))
        context.setLineWidth(2.4)
        context.setLineCap(.round)
        
        switch entity.expression {
        case .neutral:
            // Vertical capsule / pill anime eyes
            let eyeW: CGFloat = 5.0
            let eyeH: CGFloat = 9.5
            let gazeX = entity.eyeOffset.x * 1.8
            let gazeY = entity.eyeOffset.y * 1.5
            
            context.setFillColor(CGColor(red: 0.12, green: 0.10, blue: 0.18, alpha: 0.98))
            let leftEye = CGRect(x: -spacing + gazeX - eyeW / 2.0, y: eyeY + gazeY - eyeH / 2.0, width: eyeW, height: eyeH)
            let rightEye = CGRect(x: spacing + gazeX - eyeW / 2.0, y: eyeY + gazeY - eyeH / 2.0, width: eyeW, height: eyeH)
            context.addPath(CGPath(roundedRect: leftEye, cornerWidth: eyeW / 2.0, cornerHeight: eyeW / 2.0, transform: nil))
            context.addPath(CGPath(roundedRect: rightEye, cornerWidth: eyeW / 2.0, cornerHeight: eyeW / 2.0, transform: nil))
            context.fillPath()
            
        case .happy:
            // ^ ^ Closed smiling curved arcs
            let arcR: CGFloat = 6.0
            context.beginPath()
            context.addArc(center: CGPoint(x: -spacing, y: eyeY), radius: arcR, startAngle: .pi * 0.2, endAngle: .pi * 0.8, clockwise: false)
            context.strokePath()
            
            context.beginPath()
            context.addArc(center: CGPoint(x: spacing, y: eyeY), radius: arcR, startAngle: .pi * 0.2, endAngle: .pi * 0.8, clockwise: false)
            context.strokePath()
            
        case .excited:
            // Excited open eyes with tiny sparkles
            let eyeW: CGFloat = 6.0
            let eyeH: CGFloat = 10.0
            context.setFillColor(CGColor(red: 0.12, green: 0.10, blue: 0.18, alpha: 0.98))
            context.fillEllipse(in: CGRect(x: -spacing - eyeW / 2.0, y: eyeY - eyeH / 2.0, width: eyeW, height: eyeH))
            context.fillEllipse(in: CGRect(x: spacing - eyeW / 2.0, y: eyeY - eyeH / 2.0, width: eyeW, height: eyeH))
            
            // White glints
            context.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.95))
            context.fillEllipse(in: CGRect(x: -spacing - 1.0, y: eyeY + 1.5, width: 3.0, height: 3.0))
            context.fillEllipse(in: CGRect(x: spacing - 1.0, y: eyeY + 1.5, width: 3.0, height: 3.0))
            
        case .curious:
            // Curious arched eyes + head tilt
            let eyeW: CGFloat = 5.2
            let eyeH: CGFloat = 9.0
            let gazeY = entity.eyeOffset.y * 1.5 - 2.0 // Looking down at keyboard
            
            context.setFillColor(CGColor(red: 0.12, green: 0.10, blue: 0.18, alpha: 0.98))
            context.fillEllipse(in: CGRect(x: -spacing - eyeW / 2.0, y: eyeY + gazeY, width: eyeW, height: eyeH))
            context.fillEllipse(in: CGRect(x: spacing - eyeW / 2.0, y: eyeY + gazeY, width: eyeW, height: eyeH))
            
            // Raised curious eyebrow on right
            context.beginPath()
            context.move(to: CGPoint(x: spacing - 4.0, y: eyeY + eyeH + 3.0))
            context.addLine(to: CGPoint(x: spacing + 4.0, y: eyeY + eyeH + 5.5))
            context.strokePath()
            
        case .focused:
            // > < determined squint lines
            let squintR: CGFloat = 5.5
            // Left >
            context.beginPath()
            context.move(to: CGPoint(x: -spacing - squintR, y: eyeY + squintR))
            context.addLine(to: CGPoint(x: -spacing + squintR * 0.6, y: eyeY))
            context.addLine(to: CGPoint(x: -spacing - squintR, y: eyeY - squintR))
            context.strokePath()
            
            // Right <
            context.beginPath()
            context.move(to: CGPoint(x: spacing + squintR, y: eyeY + squintR))
            context.addLine(to: CGPoint(x: spacing - squintR * 0.6, y: eyeY))
            context.addLine(to: CGPoint(x: spacing + squintR, y: eyeY - squintR))
            context.strokePath()
            
        case .sleepy:
            // – – flat sleepy slits
            context.beginPath()
            context.move(to: CGPoint(x: -spacing - 5.0, y: eyeY))
            context.addLine(to: CGPoint(x: -spacing + 5.0, y: eyeY))
            context.strokePath()
            
            context.beginPath()
            context.move(to: CGPoint(x: spacing - 5.0, y: eyeY))
            context.addLine(to: CGPoint(x: spacing + 5.0, y: eyeY))
            context.strokePath()
            
        case .surprised:
            // Wide teardrop anime eyes
            let r: CGFloat = 5.0
            context.fillEllipse(in: CGRect(x: -spacing - r, y: eyeY - r, width: r * 2.0, height: r * 2.0))
            context.fillEllipse(in: CGRect(x: spacing - r, y: eyeY - r, width: r * 2.0, height: r * 2.0))
            // Small open mouth :o
            context.fillEllipse(in: CGRect(x: -2.5, y: eyeY - 8.0, width: 5.0, height: 6.0))
            
        case .confused:
            // Spiral or question eyes @ @
            let r: CGFloat = 5.0
            context.strokeEllipse(in: CGRect(x: -spacing - r, y: eyeY - r, width: r * 2.0, height: r * 2.0))
            context.strokeEllipse(in: CGRect(x: spacing - r, y: eyeY - r, width: r * 2.0, height: r * 2.0))
        }
        
        context.restoreGState()
    }
    
    // MARK: - Accessories Overlay
    private func drawAccessory(context: CGContext, w: CGFloat, h: CGFloat) {
        switch entity.accessory {
        case .coffee:
            // Holding cozy coffee mug in front
            let mugRect = CGRect(x: -10.0, y: h * 0.20, width: 20.0, height: 16.0)
            context.setFillColor(CGColor(red: 0.94, green: 0.90, blue: 0.85, alpha: 1.0))
            context.addPath(CGPath(roundedRect: mugRect, cornerWidth: 3.0, cornerHeight: 3.0, transform: nil))
            context.fillPath()
            
            // Coffee liquid
            context.setFillColor(CGColor(red: 0.45, green: 0.28, blue: 0.18, alpha: 1.0))
            context.fillEllipse(in: CGRect(x: -8.0, y: h * 0.20 + 10.0, width: 16.0, height: 4.0))
            
        case .coding:
            // Holding mini glowing terminal screen </>
            let screenRect = CGRect(x: -16.0, y: h * 0.16, width: 32.0, height: 20.0)
            context.setFillColor(CGColor(red: 0.12, green: 0.14, blue: 0.20, alpha: 1.0))
            context.addPath(CGPath(roundedRect: screenRect, cornerWidth: 4.0, cornerHeight: 4.0, transform: nil))
            context.fillPath()
            
            // </> code glyph
            let font = NSFont.monospacedSystemFont(ofSize: 8.0, weight: .bold)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: NSColor(calibratedRed: 0.2, green: 0.95, blue: 0.65, alpha: 1.0)
            ]
            let codeStr = NSString(string: "</>")
            codeStr.draw(at: NSPoint(x: -10.0, y: h * 0.16 + 4.0), withAttributes: attrs)
            

            
        case .none:
            break
        }
    }
    
    // MARK: - Details: Blush, Sparkles, Zzz
    private func drawBlush(context: CGContext, y: CGFloat, offset: CGFloat) {
        context.setStrokeColor(CGColor(red: 1.0, green: 0.42, blue: 0.62, alpha: 0.72))
        context.setLineWidth(1.4)
        context.setLineCap(.round)
        
        for i in 0..<2 {
            let ox = -offset + CGFloat(i) * 2.8
            context.beginPath()
            context.move(to: CGPoint(x: ox - 1.5, y: y - 2.0))
            context.addLine(to: CGPoint(x: ox + 1.5, y: y + 2.0))
            context.strokePath()
        }
        
        for i in 0..<2 {
            let ox = offset - CGFloat(i) * 2.8
            context.beginPath()
            context.move(to: CGPoint(x: ox - 1.5, y: y - 2.0))
            context.addLine(to: CGPoint(x: ox + 1.5, y: y + 2.0))
            context.strokePath()
        }
    }
    
    private func drawExcitedSparkles(context: CGContext, w: CGFloat, h: CGFloat) {
        let sparkleColor = CGColor(red: 1.0, green: 0.85, blue: 0.25, alpha: 0.95)
        context.setFillColor(sparkleColor)
        
        // Left star
        drawMiniStar(context: context, center: CGPoint(x: -w * 0.38, y: h * 0.70), size: 4.0)
        // Right star
        drawMiniStar(context: context, center: CGPoint(x: w * 0.38, y: h * 0.72), size: 5.0)
    }
    
    private func drawMiniStar(context: CGContext, center: CGPoint, size: CGFloat) {
        context.saveGState()
        context.beginPath()
        context.move(to: CGPoint(x: center.x, y: center.y + size))
        context.addLine(to: CGPoint(x: center.x + size * 0.3, y: center.y + size * 0.3))
        context.addLine(to: CGPoint(x: center.x + size, y: center.y))
        context.addLine(to: CGPoint(x: center.x + size * 0.3, y: center.y - size * 0.3))
        context.addLine(to: CGPoint(x: center.x, y: center.y - size))
        context.addLine(to: CGPoint(x: center.x - size * 0.3, y: center.y - size * 0.3))
        context.addLine(to: CGPoint(x: center.x - size, y: center.y))
        context.addLine(to: CGPoint(x: center.x - size * 0.3, y: center.y + size * 0.3))
        context.closePath()
        context.fillPath()
        context.restoreGState()
    }
    
    private func drawCuriousQuestionMark(context: CGContext, w: CGFloat, h: CGFloat) {
        let font = NSFont.systemFont(ofSize: 13.0, weight: .bold)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor(calibratedRed: 0.65, green: 0.52, blue: 0.92, alpha: 0.90)
        ]
        let qStr = NSString(string: "?")
        qStr.draw(at: NSPoint(x: w * 0.32, y: h * 0.68), withAttributes: attrs)
    }
    
    private func drawSleepingZzz(context: CGContext, h: CGFloat) {
        let zPhase = CGFloat(entity.stateTimer.truncatingRemainder(dividingBy: 3.0)) / 3.0
        let zY = h * 0.65 + (zPhase * 18.0)
        let zX = 14.0 + (zPhase * 5.0)
        let alpha = 1.0 - zPhase
        
        let font = NSFont.systemFont(ofSize: 11.5, weight: .bold)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor(calibratedRed: 0.72, green: 0.65, blue: 0.90, alpha: alpha)
        ]
        
        let zString = NSString(string: "z")
        zString.draw(at: NSPoint(x: zX, y: zY), withAttributes: attrs)
    }
    
    // MARK: - Floating Music Notes
    private func drawMusicNotes(context: CGContext) {
        guard !entity.musicNotes.isEmpty else { return }
        
        for note in entity.musicNotes {
            let progress = max(0.0, min(1.0, note.life / note.maxLife))
            let alpha = progress * 0.95
            guard alpha > 0.05 else { continue }
            
            let font = NSFont.systemFont(ofSize: 13.0, weight: .bold)
            let textColor = NSColor(calibratedRed: 0.92, green: 0.58, blue: 1.0, alpha: alpha)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: textColor
            ]
            let str = NSAttributedString(string: note.symbol, attributes: attrs)
            
            context.saveGState()
            context.setShadow(offset: .zero, blur: 5.0, color: CGColor(red: 0.92, green: 0.58, blue: 1.0, alpha: alpha * 0.8))
            str.draw(at: note.position)
            context.restoreGState()
        }
    }
    
    // MARK: - Animated Liquid Glass Speech Bubble
    private func drawSpeechBubble(context: CGContext, text: String, baseY: CGFloat) {
        let maxDuration = max(0.1, entity.speechBubbleMaxDuration)
        let timer = max(0.0, entity.speechBubbleTimer)
        let elapsed = maxDuration - timer
        
        // 1. Liquid Glass Fluid Spring Physics (Volume-Preserving Squash & Stretch)
        let popInDuration: CGFloat = 0.35
        let fadeOutDuration: CGFloat = 0.28
        let scaleX: CGFloat
        let scaleY: CGFloat
        let alpha: CGFloat
        let floatOffset: CGFloat
        
        if elapsed < popInDuration {
            // Harmonic fluid droplet oscillation
            let t = elapsed / popInDuration
            let decay = exp(-4.5 * t)
            let wobble = sin(t * .pi * 3.5) * decay * 0.28
            let baseScale = min(1.0, t * 1.5)
            scaleX = max(0.05, baseScale * (1.0 + wobble))
            scaleY = max(0.05, baseScale * (1.0 - wobble * 0.82))
            alpha = min(1.0, t * 2.5)
            floatOffset = (1.0 - t) * 6.0
        } else if timer < fadeOutDuration {
            // Liquid dissipation fade-out
            let t = timer / fadeOutDuration
            scaleX = 0.85 + 0.15 * t
            scaleY = 0.85 + 0.15 * t
            alpha = max(0.0, min(1.0, t * 1.4))
            floatOffset = -(1.0 - t) * 6.0
        } else {
            // Ambient liquid floating oscillation
            let pulse = sin(CGFloat(elapsed) * 2.5) * 0.015
            scaleX = 1.0 + pulse
            scaleY = 1.0 - pulse
            alpha = 1.0
            floatOffset = sin(CGFloat(elapsed) * 3.0) * 1.5
        }
        
        guard alpha > 0.02 else {
            activeBubbleRect = nil
            return
        }
        
        // 2. High-Legibility Typography with Multi-Line Auto-Wrapping
        let font = NSFont.systemFont(ofSize: 11.5, weight: .semibold)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineBreakMode = .byWordWrapping
        
        let textColor: NSColor
        if entity.isNightMode {
            textColor = NSColor(calibratedRed: 0.16, green: 0.12, blue: 0.28, alpha: alpha * 0.95)
        } else {
            textColor = NSColor(calibratedRed: 0.12, green: 0.10, blue: 0.22, alpha: alpha * 0.95)
        }
        
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: paragraphStyle
        ]
        
        let maxTextWidth: CGFloat = 236.0
        let boundingRect = (text as NSString).boundingRect(
            with: CGSize(width: maxTextWidth, height: 120),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attrs
        )
        let textWidth = ceil(boundingRect.width)
        let textHeight = ceil(boundingRect.height)
        
        let padX: CGFloat = 13.0
        let padY: CGFloat = 7.0
        let bubbleW = min(268.0, max(68.0, textWidth + padX * 2.0))
        let bubbleH = max(28.0, textHeight + padY * 2.0)
        
        let bubbleX = min(bounds.width - bubbleW - 8.0, max(8.0, bounds.midX - bubbleW / 2.0))
        let bubbleY = baseY + floatOffset + 6.0
        let bubbleRect = CGRect(x: bubbleX, y: bubbleY, width: bubbleW, height: bubbleH)
        let cornerR = min(bubbleH / 2.0, 13.0)
        
        // Active Hit-Testing Rect
        activeBubbleRect = CGRect(x: bubbleX, y: bubbleY - 4.0, width: bubbleW, height: bubbleH + 6.0)
        
        // 3. Fluid Droplet Capsule & Organic Stem
        let path = CGMutablePath()
        path.addRoundedRect(in: bubbleRect, cornerWidth: cornerR, cornerHeight: cornerR)
        
        let stemTip = CGPoint(x: bounds.midX, y: max(baseY - 2.0, bubbleY - 7.0))
        let stemLeft = CGPoint(x: bounds.midX - 5.5, y: bubbleY + 1.5)
        let stemRight = CGPoint(x: bounds.midX + 5.5, y: bubbleY + 1.5)
        
        let stemPath = CGMutablePath()
        stemPath.move(to: stemLeft)
        stemPath.addQuadCurve(to: stemTip, control: CGPoint(x: bounds.midX - 2.0, y: bubbleY - 4.0))
        stemPath.addQuadCurve(to: stemRight, control: CGPoint(x: bounds.midX + 2.0, y: bubbleY - 4.0))
        stemPath.closeSubpath()
        path.addPath(stemPath)
        
        context.saveGState()
        
        // Squash & Stretch around bubble center
        let centerX = bubbleRect.midX
        let centerY = bubbleRect.midY
        context.translateBy(x: centerX, y: centerY)
        context.scaleBy(x: scaleX, y: scaleY)
        context.translateBy(x: -centerX, y: -centerY)
        
        // 4. Ethereal Ambient Drop Shadow
        context.setShadow(
            offset: CGSize(width: 0, height: -3.5),
            blur: 12.0,
            color: CGColor(red: 0.16, green: 0.10, blue: 0.32, alpha: 0.22 * alpha)
        )
        
        // 5. Frosted Liquid Glass Multi-Stop Linear Gradient Fill
        context.saveGState()
        context.addPath(path)
        context.clip()
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let topColor: CGColor
        let midColor: CGColor
        let botColor: CGColor
        
        if entity.isNightMode {
            topColor = CGColor(red: 0.96, green: 0.94, blue: 1.0, alpha: 0.92 * alpha)
            midColor = CGColor(red: 0.86, green: 0.82, blue: 0.96, alpha: 0.84 * alpha)
            botColor = CGColor(red: 0.74, green: 0.69, blue: 0.88, alpha: 0.76 * alpha)
        } else {
            topColor = CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.94 * alpha)
            midColor = CGColor(red: 0.96, green: 0.94, blue: 1.0, alpha: 0.86 * alpha)
            botColor = CGColor(red: 0.91, green: 0.88, blue: 0.98, alpha: 0.78 * alpha)
        }
        
        if let gradient = CGGradient(
            colorsSpace: colorSpace,
            colors: [topColor, midColor, botColor] as CFArray,
            locations: [0.0, 0.45, 1.0]
        ) {
            context.drawLinearGradient(
                gradient,
                start: CGPoint(x: centerX, y: bubbleY + bubbleH),
                end: CGPoint(x: centerX, y: bubbleY - 5.0),
                options: []
            )
        }
        
        // 6. Inner Caustic Refraction (Top Edge Lens Highlight Sheen)
        let sheenRect = CGRect(x: bubbleX + 5.0, y: bubbleY + bubbleH - 6.5, width: bubbleW - 10.0, height: 4.5)
        let sheenPath = CGMutablePath()
        sheenPath.addRoundedRect(in: sheenRect, cornerWidth: 2.25, cornerHeight: 2.25)
        let sheenTop = CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.70 * alpha)
        let sheenBot = CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.05 * alpha)
        if let sheenGrad = CGGradient(colorsSpace: colorSpace, colors: [sheenTop, sheenBot] as CFArray, locations: [0.0, 1.0]) {
            context.saveGState()
            context.addPath(sheenPath)
            context.clip()
            context.drawLinearGradient(sheenGrad, start: CGPoint(x: centerX, y: sheenRect.maxY), end: CGPoint(x: centerX, y: sheenRect.minY), options: [])
            context.restoreGState()
        }
        
        // 7. Dynamic Liquid Shimmer Light Pass
        let shimmerPhase = CGFloat(fmod(Double(elapsed) * 0.45, 1.0))
        let shimmerX = bubbleX - 40.0 + (bubbleW + 80.0) * shimmerPhase
        let shimmerRect = CGRect(x: shimmerX, y: bubbleY, width: 28.0, height: bubbleH)
        let shimLeft = CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.0)
        let shimMid = CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.28 * alpha)
        let shimRight = CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.0)
        if let shimGrad = CGGradient(colorsSpace: colorSpace, colors: [shimLeft, shimMid, shimRight] as CFArray, locations: [0.0, 0.5, 1.0]) {
            context.saveGState()
            context.clip(to: shimmerRect)
            context.drawLinearGradient(shimGrad, start: CGPoint(x: shimmerX, y: bubbleY), end: CGPoint(x: shimmerX + 28.0, y: bubbleY), options: [])
            context.restoreGState()
        }
        
        context.restoreGState() // restore clip
        
        // 8. Specular Rim Stroke (Bending Light on Edge of Glass)
        context.saveGState()
        context.addPath(path)
        let rimColor = entity.isNightMode ?
            CGColor(red: 0.92, green: 0.88, blue: 1.0, alpha: 0.88 * alpha) :
            CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.92 * alpha)
        context.setStrokeColor(rimColor)
        context.setLineWidth(1.2)
        context.strokePath()
        context.restoreGState()
        
        // 9. Draw Formatted Text Centered
        let textRect = CGRect(
            x: bubbleX + (bubbleW - textWidth) / 2.0,
            y: bubbleY + (bubbleH - textHeight) / 2.0 - 0.5,
            width: textWidth,
            height: textHeight
        )
        let attrString = NSAttributedString(string: text, attributes: attrs)
        attrString.draw(with: textRect, options: [.usesLineFragmentOrigin, .usesFontLeading])
        
        context.restoreGState()
    }
}
