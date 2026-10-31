import Foundation
import CoreGraphics

public enum JellyExpression: String, CaseIterable, Sendable {
    case neutral = "Neutral"
    case happy = "Happy"
    case excited = "Excited"
    case curious = "Curious"
    case sleepy = "Sleepy"
    case focused = "Focused"
    case surprised = "Surprised"
    case confused = "Confused"
}

public enum JellyAccessory: String, CaseIterable, Sendable {
    case none = "None"
    case coffee = "Coffee Mug"
    case coding = "Mini Terminal </>"
}
