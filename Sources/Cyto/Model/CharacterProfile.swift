import Foundation
import CoreGraphics

public enum CharacterCategory: String, Sendable, CaseIterable {
    case anime = "Anime Companions"
    case pet = "Pets"
    case techAndSpirit = "Tech & Spirits"
}

public enum CharacterID: String, CaseIterable, Sendable {
    // Anime Companions
    case rin = "rin"
    case haru = "haru"
    
    // Pets
    case pamu = "pamu"
    case kota = "kota"
    case mochi = "mochi"
    
    // Tech & Spirits
    case bit = "bit"
    case hikaru = "hikaru"
    
    public var name: String {
        switch self {
        case .rin: return "Rin"
        case .haru: return "Haru"
        case .pamu: return "Pamu"
        case .kota: return "Kota"
        case .mochi: return "Mochi"
        case .bit: return "Bit"
        case .hikaru: return "Hikaru"
        }
    }
    
    public var title: String {
        switch self {
        case .rin: return "The Late-Night Coder"
        case .haru: return "The Study Partner"
        case .pamu: return "The Chill Panda"
        case .kota: return "The Energetic Pup"
        case .mochi: return "The Sleepy Cat"
        case .bit: return "The Desktop Bot"
        case .hikaru: return "The Tiny Spirit"
        }
    }
    
    public var category: CharacterCategory {
        switch self {
        case .rin, .haru: return .anime
        case .pamu, .kota, .mochi: return .pet
        case .bit, .hikaru: return .techAndSpirit
        }
    }
    
    public var enterQuotes: [String] {
        switch self {
        case .rin:
            return [
                "LGTM!",
                "Clean logic.",
                "Another one shipped!",
                "Drink some water~",
                "Keep cooking!",
                "Commit & push?",
                "Sugoi, coder-kun!"
            ]
        case .haru:
            return [
                "Good progress!",
                "Focus looks solid.",
                "Taking notes...",
                "Nice work!",
                "One line at a time.",
                "Proud of you!"
            ]
        case .pamu:
            return [
                "Mmm, cozy...",
                "Chill coding.",
                "Take it easy~",
                "Snack break soon?",
                "Nice and steady."
            ]
        case .kota:
            return [
                "Woof! Let's go!",
                "You're the best!",
                "Bork! Ship it!",
                "10/10 code!",
                "Tail wagging mode!",
                "Pawsome!"
            ]
        case .mochi:
            return [
                "Purrrr...",
                "Meow~",
                "Warm titlebar...",
                "Zzz... good job.",
                "Don't wake me yet..."
            ]
        case .bit:
            return [
                "EXECUTE: 100%",
                "BEEP BOOP!",
                "RETURN DETECTED",
                "STATUS: NOMINAL",
                "SYSTEM HAPPY",
                "01001111!"
            ]
        case .hikaru:
            return [
                "Sparkle~",
                "Aura boosted!",
                "Warm thoughts.",
                "Flowing along...",
                "Float with it."
            ]
        }
    }
}
