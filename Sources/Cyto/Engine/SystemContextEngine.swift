import Foundation
import AppKit
import IOKit.ps

public struct SystemContext: Sendable {
    public let isNight: Bool
    public let isDarkMode: Bool
    public let isLowBattery: Bool
    public let batteryPercentage: Int?
    public let isPluggedIn: Bool
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
            isPluggedIn: true
        )
        self.cachedContext = sample()
    }
    
    public func updateContext() -> SystemContext {
        let now = Date()
        if now.timeIntervalSince(lastQueryTime) > 10.0 {
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
        
        return SystemContext(
            isNight: isNight,
            isDarkMode: isDarkMode,
            isLowBattery: isLowBattery,
            batteryPercentage: batteryPct,
            isPluggedIn: isPluggedIn
        )
    }
}
