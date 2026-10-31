import AppKit

public final class OverlayPanel: NSPanel {
    public static let defaultSize = CGSize(width: 136, height: 144)
    
    public init(initialPosition: CGPoint) {
        let contentRect = NSRect(
            x: initialPosition.x - Self.defaultSize.width / 2.0,
            y: initialPosition.y - 6.0,
            width: Self.defaultSize.width,
            height: Self.defaultSize.height
        )
        
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.level = .floating
        self.ignoresMouseEvents = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        self.isReleasedWhenClosed = false
        self.hidesOnDeactivate = false
    }
}
