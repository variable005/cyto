import Foundation
import AppKit
import IOKit.ps

public enum ActiveAppCategory: String, Sendable, CaseIterable {
    case developerIDE = "Developer IDE"
    case creativeAudio = "Music & Creative"
    case webBrowser = "Web Browser"
    case communication = "Communication"
    case other = "Desktop Workspace"
}

public struct SystemContext: Sendable {
    public let isNight: Bool
    public let isDarkMode: Bool
    public let isLowBattery: Bool
    public let batteryPercentage: Int?
    public let isPluggedIn: Bool
    public let activeAppCategory: ActiveAppCategory
    public let activeAppName: String?
}

public final class SystemContextEngine: @unchecked Sendable {
    private var lastQueryTime: Date = .distantPast
    private var cachedContext: SystemContext
    
    public init() {
        self.cachedContext = SystemContext(
            isNight: false,
            isDarkMode: false,
            isLowBattery: false,
            batteryPercentage: nil,
            isPluggedIn: true,
            activeAppCategory: .other,
            activeAppName: nil
        )
        self.cachedContext = sample()
    }
    
    public func updateContext() -> SystemContext {
        let now = Date()
        if now.timeIntervalSince(lastQueryTime) > 1.8 {
            cachedContext = sample()
            lastQueryTime = now
        }
        return cachedContext
    }
    
    private func sample() -> SystemContext {
        // 1. Circadian Rhythm (Hour of day)
        let hour = Calendar.current.component(.hour, from: Date())
        let isNight = (hour >= 20 || hour < 6)
        
        // 2. macOS System Appearance (Dark Mode)
        let isDarkMode: Bool
        if let bestMatch = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) {
            isDarkMode = (bestMatch == .darkAqua)
        } else {
            isDarkMode = isNight
        }
        
        // 3. Hardware Battery Metrics via IOKit
        var isLowBattery = false
        var batteryPct: Int? = nil
        var isPluggedIn = true
        
        if let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
           let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] {
            for ps in sources {
                if let desc = IOPSGetPowerSourceDescription(snapshot, ps)?.takeUnretainedValue() as? [String: Any] {
                    let current = desc[kIOPSCurrentCapacityKey] as? Int
                    let maxCap = desc[kIOPSMaxCapacityKey] as? Int
                    let powerSource = desc[kIOPSPowerSourceStateKey] as? String
                    let isAC = (powerSource == kIOPSACPowerValue)
                    isPluggedIn = isAC
                    
                    if let cur = current, let max = maxCap, max > 0 {
                        let pct = Int((Double(cur) / Double(max)) * 100.0)
                        batteryPct = pct
                        if pct <= 20 && !isAC {
                            isLowBattery = true
                        }
                    }
                }
            }
        }
        
        // 4. Frontmost Workspace Application Context
        let frontApp = NSWorkspace.shared.frontmostApplication
        let appName = frontApp?.localizedName
        let bundleID = (frontApp?.bundleIdentifier ?? "").lowercased()
        let nameLower = (appName ?? "").lowercased()
        
        let category: ActiveAppCategory
        if bundleID.contains("xcode") || bundleID.contains("vscode") || bundleID.contains("cursor") ||
           bundleID.contains("terminal") || bundleID.contains("iterm") || bundleID.contains("intellij") ||
           bundleID.contains("sublime") || nameLower.contains("terminal") || nameLower.contains("code") ||
           nameLower.contains("xcode") || nameLower.contains("cursor") {
            category = .developerIDE
        } else if bundleID.contains("spotify") || bundleID.contains("music") ||
                  bundleID.contains("logic") || bundleID.contains("ableton") ||
                  nameLower.contains("spotify") || nameLower.contains("music") {
            category = .creativeAudio
        } else if bundleID.contains("safari") || bundleID.contains("chrome") ||
                  bundleID.contains("arc") || bundleID.contains("firefox") ||
                  bundleID.contains("edge") || bundleID.contains("brave") {
            category = .webBrowser
        } else if bundleID.contains("slack") || bundleID.contains("discord") ||
                  bundleID.contains("telegram") || bundleID.contains("messages") ||
                  bundleID.contains("teams") {
            category = .communication
        } else {
            category = .other
        }
        
        return SystemContext(
            isNight: isNight,
            isDarkMode: isDarkMode,
            isLowBattery: isLowBattery,
            batteryPercentage: batteryPct,
            isPluggedIn: isPluggedIn,
            activeAppCategory: category,
            activeAppName: appName
        )
    }
}
