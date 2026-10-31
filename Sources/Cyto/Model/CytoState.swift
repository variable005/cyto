import Foundation

public enum CytoState: String, CaseIterable, Sendable {
    case idle
    case walking
    case sitting
    case sleeping
    case falling
    case bouncing
    case dragged
    case petted
    case curious
    case mischievous
    
    public var isGrounded: Bool {
        switch self {
        case .idle, .walking, .sitting, .sleeping, .petted, .curious, .mischievous:
            return true
        case .falling, .bouncing, .dragged:
            return false
        }
    }
    
    public var allowsDirectMotion: Bool {
        switch self {
        case .idle, .walking, .curious, .mischievous:
            return true
        case .sitting, .sleeping, .falling, .bouncing, .dragged, .petted:
            return false
        }
    }
}

public enum CytoMood: String, Sendable {
    case calm
    case happy
    case sleepy
    case playful
}

public enum FocusTier: String, Sendable {
    case inFlow
    case steady
    case wandering
    case idle
}
