import Foundation
import CoreGraphics
import AppKit

public struct Ledge: Sendable {
    public let rect: CGRect
    public let topY: CGFloat
    public let minX: CGFloat
    public let maxX: CGFloat
    
    public init(rect: CGRect) {
        self.rect = rect
        self.topY = rect.maxY
        self.minX = rect.minX
        self.maxX = rect.maxX
    }
}

public final class WindowTracker {
    public init() {}
    
    public func fetchWalkableLedges(excludingWindowID: CGWindowID? = nil, screen: NSScreen) -> [Ledge] {
        var ledges: [Ledge] = []
        let primaryScreenHeight = NSScreen.screens.first?.frame.height ?? screen.frame.height
        
        // 1. Bottom of the screen (the ground floor / Dock floor)
        let visibleFrame = screen.visibleFrame
        let groundRect = CGRect(
            x: visibleFrame.minX,
            y: visibleFrame.minY,
            width: visibleFrame.width,
            height: 2.0
        )
        ledges.append(Ledge(rect: groundRect))
        
        // 2. Query visible on-screen windows from Quartz Window Server
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let infoList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return ledges
        }
        
        for dict in infoList {
            // Filter window layer (layer 0 is standard application window)
            guard let layer = dict[kCGWindowLayer as String] as? Int, layer == 0 else {
                continue
            }
            
            // Skip self window if known
            if let windowNumber = dict[kCGWindowNumber as String] as? CGWindowID,
               let targetID = excludingWindowID,
               windowNumber == targetID {
                continue
            }
            
            // Parse bounds in Quartz coordinates (origin at top-left)
            guard let boundsDict = dict[kCGWindowBounds as String] as? [String: Any],
                  let x = boundsDict["X"] as? CGFloat,
                  let y = boundsDict["Y"] as? CGFloat,
                  let width = boundsDict["Width"] as? CGFloat,
                  let height = boundsDict["Height"] as? CGFloat else {
                continue
            }
            
            // Discard miniscule or off-screen panels
            guard width > 120, height > 80 else { continue }
            
            // Convert from Quartz (top-left) to Cocoa (bottom-left) coordinates
            let cocoaY = primaryScreenHeight - (y + height)
            let cocoaRect = CGRect(x: x, y: cocoaY, width: width, height: height)
            
            // Ensure window intersects target screen
            if cocoaRect.intersects(screen.frame) {
                ledges.append(Ledge(rect: cocoaRect))
            }
        }
        
        // Return sorted by descending topY (highest windows first)
        return ledges.sorted(by: { $0.topY > $1.topY })
    }
}
