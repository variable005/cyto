import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: CytoController?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        let cyto = CytoController()
        cyto.start()
        self.controller = cyto
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
