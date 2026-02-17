import SwiftUI

@main
struct MountBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    private var mountManager = SMBMountManager()
    private var mountDaemon = MountDaemon.shared
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        PasswordManager.shared.requestKeychainAccess()
        
        // Start auto-mount timer immediately
        mountDaemon.start(with: mountManager)
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            if let image = NSImage(systemSymbolName: "server.rack", accessibilityDescription: "MountBar") {
                button.image = image
            } else {
                button.title = "📁"
            }
            button.action = #selector(togglePopover)
            button.target = self
        }
            
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 300, height: 400)
        popover?.behavior = .transient
        popover?.contentViewController = NSHostingController(rootView: MenuBarView(mountManager: mountManager, mountDaemon: mountDaemon))
        
        // Listen for app deactivation to close popover
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidDeactivate),
            name: NSApplication.didResignActiveNotification,
            object: nil
        )
        
        print("✅ MountBar menu bar item created successfully")
        print("👀 Look for the drive icon in your top-right menu bar")
    }
    
    @objc func togglePopover() {
        if let button = statusItem?.button {
            if let popover = popover {
                if popover.isShown {
                    popover.performClose(nil)
                } else {
                    popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                }
            }
        }
    }
    
    @objc func appDidDeactivate() {
        popover?.performClose(nil)
    }
}
