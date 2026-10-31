import AppKit

public final class SpriteManager {
    public static let shared = SpriteManager()
    private var cache: [CharacterID: NSImage] = [:]
    
    private init() {
        preloadSprites()
    }
    
    public func preloadSprites() {
        for char in CharacterID.allCases {
            if let img = loadSprite(name: char.rawValue) {
                cache[char] = img
            }
        }
    }
    
    public func image(for character: CharacterID) -> NSImage? {
        if let cached = cache[character] {
            return cached
        }
        if let img = loadSprite(name: character.rawValue) {
            cache[character] = img
            return img
        }
        return nil
    }
    
    private func loadSprite(name: String) -> NSImage? {
        let filename = "\(name).png"
        
        // 1. Check relative to current working directory
        let cwdPath = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Resources/Characters")
            .appendingPathComponent(filename).path
        if FileManager.default.fileExists(atPath: cwdPath), let img = NSImage(contentsOfFile: cwdPath) {
            return img
        }
        
        // 2. Check hardcoded project path
        let projectPath = "/Users/hariom/Documents/shigoto/mac softwares/cyto/Resources/Characters/\(filename)"
        if FileManager.default.fileExists(atPath: projectPath), let img = NSImage(contentsOfFile: projectPath) {
            return img
        }
        
        // 3. Check relative to executable binary
        let execURL = URL(fileURLWithPath: CommandLine.arguments[0])
        let execParent = execURL.deletingLastPathComponent()
        let relativePaths = [
            execParent.appendingPathComponent("Resources/Characters/\(filename)").path,
            execParent.deletingLastPathComponent().appendingPathComponent("Resources/Characters/\(filename)").path,
            execParent.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Resources/Characters/\(filename)").path
        ]
        for path in relativePaths {
            if FileManager.default.fileExists(atPath: path), let img = NSImage(contentsOfFile: path) {
                return img
            }
        }
        
        // 4. Bundle resources
        if let bundleURL = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "Characters"),
           let img = NSImage(contentsOf: bundleURL) {
            return img
        }
        
        return nil
    }
}
