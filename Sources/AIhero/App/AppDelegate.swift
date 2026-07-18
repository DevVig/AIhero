import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowManager: WindowManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let manager = WindowManager()
        manager.start()
        self.windowManager = manager
    }
}
