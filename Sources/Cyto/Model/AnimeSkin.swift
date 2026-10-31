import Foundation

public enum AnimeSkin: String, CaseIterable, Sendable {
    case chibiNeko = "Chibi Neko (Cat)"
    case chibiSlime = "Chibi Slime (Spirit)"
    case chibiKitsune = "Chibi Kitsune (Fox)"
    
    public var displayName: String {
        return self.rawValue
    }
}
