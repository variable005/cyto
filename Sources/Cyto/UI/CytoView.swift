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
    
    // MARK: - Drawing Jelly The Desktop Ghost
    
    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        context.saveGState()
        
        let cx = bounds.midX
        // Levitating vertical hover oscillation (idle float keyframe)
        let hoverBob = entity.isPuddleLoaf ? 0.0 : (sin(entity.floatPhase) * 4.5)
        let cy: CGFloat = 6.0 + hoverBob
        let w = entity.size.width * entity.squishX
        let h = entity.size.height * entity.squishY
        
        let tilt = entity.isTypingObserved ? entity.curiousTilt : 0.0
        let breathScale = 1.0 + sin(entity.breathPhase) * 0.02
        let walkAngle = (entity.state == .walking) ? sin(entity.walkPhase) * 0.07 : 0.0
        
        context.translateBy(x: cx, y: cy)
        context.rotate(by: walkAngle + tilt)
        context.scaleBy(x: breathScale, y: breathScale)
        
        // 1. Soft Lavender Drop Shadow on Window Titlebar
        if entity.state.isGrounded {
            let shadowW = w * 0.82
            let shadowH: CGFloat = entity.isPuddleLoaf ? 8.0 : 5.5
            let shadowRect = CGRect(x: -shadowW / 2.0, y: -hoverBob - 2.0, width: shadowW, height: shadowH)
            context.setFillColor(CGColor(red: 0.24, green: 0.20, blue: 0.35, alpha: 0.25))
            context.fillEllipse(in: shadowRect)
        }
        
        // 2. Trailing Scarf Tail (Back Layer)
        drawScarfTail(context: context, w: w, h: h, inFront: false)
        
        // 3. Ghost Sheet Body (Lavender Ambient Shadows & Shading)
        drawGhostSheet(context: context, w: w, h: h)
        
        // 4. Knitted Scarf (Neck Wrap & Front Flutter Knot)
        drawScarfNeck(context: context, w: w, h: h)
        drawScarfTail(context: context, w: w, h: h, inFront: true)
        
        // 5. Studio Headphones with Glowing Neon Violet LED Ring
        drawHeadphones(context: context, w: w, h: h)
        
        // 6. Facial Expressions (Directly from Jelly's Design Sheet)
        drawJellyFace(context: context, w: w, h: h)
        
        // 7. Interactive Accessory Overlay (Coffee, Terminal, Nightcap)
        drawAccessory(context: context, w: w, h: h)
        
        // 8. Sleeping Zzz or Curious Sparkles
        if entity.isPuddleLoaf || entity.expression == .sleepy {
            drawSleepingZzz(context: context, h: h)
        } else if entity.expression == .excited {
            drawExcitedSparkles(context: context, w: w, h: h)
        } else if entity.expression == .curious && entity.isTypingObserved {
            drawCuriousQuestionMark(context: context, w: w, h: h)
        }
        
        context.restoreGState()
        
        // 9. Manga Speech Bubble on Enter
        if let speech = entity.speechBubbleText, entity.speechBubbleTimer > 0 {
            drawSpeechBubble(context: context, text: speech, topY: cy + h + 10.0)
        }
    }
    
    // MARK: - Ghost Sheet Body
    private func drawGhostSheet(context: CGContext, w: CGFloat, h: CGFloat) {
        let path = CGMutablePath()
        
        if entity.isPuddleLoaf {
            // Puddle Loaf (Sleep - Long Idle keyframe from design sheet)
            let puddleRect = CGRect(x: -w * 0.52, y: 0, width: w * 1.04, height: h * 0.85)
            path.addRoundedRect(in: puddleRect, cornerWidth: w * 0.45, cornerHeight: h * 0.38)
        } else {
            // Floating Ghost Sheet
            let headR = w * 0.44
            let headCenterY = h - headR - 2.0
            
            // Rounded dome head
            path.addArc(center: CGPoint(x: 0, y: headCenterY), radius: headR, startAngle: 0, endAngle: .pi, clockwise: false)
            
            // Left side draping down
            let leftBottom = CGPoint(x: -headR - 2.0, y: 0)
            path.addLine(to: leftBottom)
            
            // 4 animated folds / ruffles along bottom hem
            let rippleCount = 4
            let segmentW = ((headR + 2.0) * 2.0) / CGFloat(rippleCount)
            
            for i in 0..<rippleCount {
                let startX = -(headR + 2.0) + CGFloat(i) * segmentW
                let endX = startX + segmentW
                let midX = (startX + endX) / 2.0
                let rippleWave = sin(entity.wispPhase + CGFloat(i) * 1.4) * 4.5
                path.addQuadCurve(to: CGPoint(x: endX, y: 0), control: CGPoint(x: midX, y: 4.0 + rippleWave))
            }
            
            // Right side closing up to dome
            path.addLine(to: CGPoint(x: headR, y: headCenterY))
            path.closeSubpath()
        }
        
        context.saveGState()
        context.addPath(path)
        context.clip()
        
        // Soft Lavender / Purple Shadow Gradient (Matches Palette: #FFFFFF to #D8D0E8)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let topColor = CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.98)
        let bottomColor = CGColor(red: 0.85, green: 0.82, blue: 0.93, alpha: 0.96) // Soft lavender mist
        
        if let gradient = CGGradient(colorsSpace: colorSpace, colors: [topColor, bottomColor] as CFArray, locations: [0.0, 1.0]) {
            context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: h), end: CGPoint(x: 0, y: 0), options: [])
        }
        
        // Deep purple ambient shadow fold under the neck
        let neckShadowRect = CGRect(x: -w * 0.36, y: h * 0.28, width: w * 0.72, height: h * 0.25)
        context.setFillColor(CGColor(red: 0.76, green: 0.72, blue: 0.88, alpha: 0.55))
        context.fillEllipse(in: neckShadowRect)
        
        context.restoreGState()
        
        // Soft clean outline
        context.addPath(path)
        context.setStrokeColor(CGColor(red: 0.74, green: 0.70, blue: 0.86, alpha: 0.90))
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
        
        // Glowing Neon Violet LED Ring (#C084FC) that pulses softly
        let glowAlpha = 0.75 + sin(entity.headphoneGlowPhase) * 0.22
        let ringColor = CGColor(red: 0.78, green: 0.52, blue: 1.0, alpha: glowAlpha)
        
        context.saveGState()
        context.setShadow(offset: .zero, blur: 7.0, color: ringColor)
        context.setStrokeColor(ringColor)
        context.setLineWidth(2.2)
        
        let ringInset: CGFloat = 2.8
        context.strokeEllipse(in: leftCupRect.insetBy(dx: ringInset, dy: ringInset))
        context.strokeEllipse(in: rightCupRect.insetBy(dx: ringInset, dy: ringInset))
        context.restoreGState()
    }
    
    // MARK: - Knitted Scarf (Neck Wrap & Fluttering Tail)
    private func drawScarfNeck(context: CGContext, w: CGFloat, h: CGFloat) {
        let scarfY = h * 0.34
        let scarfW = w * 0.72
        let scarfH: CGFloat = 12.0
        let scarfRect = CGRect(x: -scarfW / 2.0, y: scarfY, width: scarfW, height: scarfH)
        
        // Deep Indigo Purple Scarf (#3E3259)
        context.setFillColor(CGColor(red: 0.24, green: 0.20, blue: 0.35, alpha: 1.0))
        let scarfPath = CGPath(roundedRect: scarfRect, cornerWidth: 6.0, cornerHeight: 6.0, transform: nil)
        context.addPath(scarfPath)
        context.fillPath()
        
        // Knot detail
        let knotRect = CGRect(x: -w * 0.18, y: scarfY - 2.0, width: 14.0, height: 16.0)
        context.setFillColor(CGColor(red: 0.20, green: 0.16, blue: 0.30, alpha: 1.0))
        context.fillEllipse(in: knotRect)
    }
    
    private func drawScarfTail(context: CGContext, w: CGFloat, h: CGFloat, inFront: Bool) {
        // Scarf tail fluttering to the side
        let flutter = sin(entity.scarfFlutterPhase) * 6.5
        let startX = -w * 0.14
        let startY = h * 0.35
        
        let tailPath = CGMutablePath()
        tailPath.move(to: CGPoint(x: startX, y: startY))
        
        let endX = startX - 22.0 - abs(entity.velocity.dx) * 0.08
        let endY = startY - 20.0 + flutter
        
        tailPath.addQuadCurve(to: CGPoint(x: endX, y: endY), control: CGPoint(x: startX - 16.0 + flutter * 0.4, y: startY - 8.0))
        tailPath.addLine(to: CGPoint(x: endX + 8.0, y: endY - 4.0))
        tailPath.addQuadCurve(to: CGPoint(x: startX + 10.0, y: startY), control: CGPoint(x: startX - 6.0 + flutter * 0.4, y: startY - 10.0))
        tailPath.closeSubpath()
        
        if inFront {
            context.setFillColor(CGColor(red: 0.26, green: 0.22, blue: 0.38, alpha: 1.0))
            context.addPath(tailPath)
            context.fillPath()
        }
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
            
        case .nightcap:
            // Soft purple sleeping nightcap
            let capPath = CGMutablePath()
            capPath.move(to: CGPoint(x: -w * 0.35, y: h * 0.75))
            capPath.addQuadCurve(to: CGPoint(x: w * 0.42, y: h * 0.95), control: CGPoint(x: 0, y: h * 0.98))
            capPath.addLine(to: CGPoint(x: w * 0.48, y: h * 0.72))
            capPath.closeSubpath()
            context.setFillColor(CGColor(red: 0.45, green: 0.35, blue: 0.65, alpha: 1.0))
            context.addPath(capPath)
            context.fillPath()
            
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
