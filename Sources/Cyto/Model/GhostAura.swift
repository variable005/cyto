import Foundation

public enum GhostAura: String, CaseIterable, Sendable {
    case moonlight = "Moonlight Cyan"
    case phantom = "Phantom Violet"
    case ectoMint = "Ecto Mint"
    case emberGold = "Ember Gold"
    
    public var displayName: String {
        return self.rawValue
    }
}
