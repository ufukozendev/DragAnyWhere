//
//  MenuBarManager.swift
//  AnyDrag
//
//  Created by luckymac on 11.06.2025.
//

import Cocoa
import SwiftUI

class MenuBarManager: NSObject {
    private var statusItem: NSStatusItem?
    private var windowDragManager: WindowDragManager
    
    init(windowDragManager: WindowDragManager) {
        self.windowDragManager = windowDragManager
        super.init()
        setupMenuBar()
    }
    
    private func setupMenuBar() {
        // Create status item in menu bar
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem?.button {
            // Try to load the dedicated menu bar icon
            if let menuBarIcon = NSImage(named: "MenuBarIcon") {
                menuBarIcon.size = NSSize(width: 16, height: 16)
                button.image = menuBarIcon
                button.image?.isTemplate = false // Don't use template mode to preserve colors
                print("✅ Loaded MenuBarIcon for menu bar")
            } else if let appIcon = NSImage(named: "AppIcon") {
                // Fallback: Create a smaller version from AppIcon
                let menuBarIcon = NSImage(size: NSSize(width: 16, height: 16))
                menuBarIcon.lockFocus()
                appIcon.draw(in: NSRect(x: 0, y: 0, width: 16, height: 16))
                menuBarIcon.unlockFocus()

                button.image = menuBarIcon
                button.image?.isTemplate = false // Don't use template mode
                print("✅ Created menu bar icon from AppIcon")
            } else {
                // Final fallback to SF Symbol
                button.image = NSImage(systemSymbolName: "cursor.rays", accessibilityDescription: "AnyDrag")
                button.image?.isTemplate = true
                print("⚠️ Using SF Symbol fallback for menu bar")
            }
            button.toolTip = "AnyDrag - Drag windows with Cmd+Mouse"
        }
        
        // Create menu
        let menu = NSMenu()
        
        // Status item
        let statusMenuItem = NSMenuItem()
        statusMenuItem.title = windowDragManager.isEnabled ? "✅ Active" : "⏸️ Stopped"
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)

        menu.addItem(NSMenuItem.separator())

        // Toggle enable/disable
        let toggleMenuItem = NSMenuItem(
            title: windowDragManager.isEnabled ? "Stop" : "Start",
            action: #selector(toggleDragService),
            keyEquivalent: ""
        )
        toggleMenuItem.target = self
        menu.addItem(toggleMenuItem)
        
        // Accessibility permission status
        let accessibilityMenuItem = NSMenuItem()
        accessibilityMenuItem.title = windowDragManager.hasAccessibilityPermission ?
            "✅ Accessibility Permission Granted" : "❌ Accessibility Permission Required"
        accessibilityMenuItem.isEnabled = false
        menu.addItem(accessibilityMenuItem)

        if !windowDragManager.hasAccessibilityPermission {
            let requestPermissionMenuItem = NSMenuItem(
                title: "Grant Permission...",
                action: #selector(requestAccessibilityPermission),
                keyEquivalent: ""
            )
            requestPermissionMenuItem.target = self
            menu.addItem(requestPermissionMenuItem)
        }
        
        menu.addItem(NSMenuItem.separator())
        
        // Help/Instructions
        let helpMenuItem = NSMenuItem(
            title: "How to Use?",
            action: #selector(showHelp),
            keyEquivalent: ""
        )
        helpMenuItem.target = self
        menu.addItem(helpMenuItem)

        menu.addItem(NSMenuItem.separator())

        // Auto-start option
        let autoStartMenuItem = NSMenuItem(
            title: "Launch at Login",
            action: #selector(toggleAutoStart),
            keyEquivalent: ""
        )
        autoStartMenuItem.target = self
        autoStartMenuItem.state = isAutoStartEnabled() ? .on : .off
        menu.addItem(autoStartMenuItem)

        menu.addItem(NSMenuItem.separator())

        // Social Media Links
        let socialMediaMenuItem = NSMenuItem(title: "Social Media", action: nil, keyEquivalent: "")
        let socialMediaSubmenu = NSMenu()

        // Website
        let websiteMenuItem = NSMenuItem(
            title: "Website - ufukozen.com",
            action: #selector(openWebsite),
            keyEquivalent: ""
        )
        websiteMenuItem.target = self
        if let websiteIcon = NSImage(named: "WebsiteIcon") {
            websiteIcon.size = NSSize(width: 16, height: 16)
            websiteMenuItem.image = websiteIcon
        }
        socialMediaSubmenu.addItem(websiteMenuItem)

        // LinkedIn
        let linkedinMenuItem = NSMenuItem(
            title: "LinkedIn - @ufukozendev",
            action: #selector(openLinkedIn),
            keyEquivalent: ""
        )
        linkedinMenuItem.target = self
        if let linkedinIcon = NSImage(named: "LinkedInIcon") {
            linkedinIcon.size = NSSize(width: 16, height: 16)
            linkedinMenuItem.image = linkedinIcon
        }
        socialMediaSubmenu.addItem(linkedinMenuItem)

        // X (Twitter)
        let xMenuItem = NSMenuItem(
            title: "X (Twitter) - @ufukozendev",
            action: #selector(openX),
            keyEquivalent: ""
        )
        xMenuItem.target = self
        if let xIcon = NSImage(named: "XIcon") {
            xIcon.size = NSSize(width: 16, height: 16)
            xMenuItem.image = xIcon
        }
        socialMediaSubmenu.addItem(xMenuItem)

        // GitHub
        let githubMenuItem = NSMenuItem(
            title: "GitHub - @ufukozendev",
            action: #selector(openGitHub),
            keyEquivalent: ""
        )
        githubMenuItem.target = self
        if let githubIcon = NSImage(named: "GitHubIcon") {
            githubIcon.size = NSSize(width: 16, height: 16)
            githubMenuItem.image = githubIcon
        }
        socialMediaSubmenu.addItem(githubMenuItem)

        socialMediaMenuItem.submenu = socialMediaSubmenu
        menu.addItem(socialMediaMenuItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitMenuItem = NSMenuItem(
            title: "Quit",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitMenuItem.target = self
        menu.addItem(quitMenuItem)
        
        statusItem?.menu = menu
        
        // Update menu when drag manager state changes
        setupObservers()
    }
    
    private func setupObservers() {
        // Observe changes in WindowDragManager
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateMenuStatus),
            name: NSNotification.Name("WindowDragManagerStateChanged"),
            object: nil
        )
    }
    
    @objc private func updateMenuStatus() {
        DispatchQueue.main.async { [weak self] in
            self?.updateMenu()
        }
    }
    
    private func updateMenu() {
        guard let menu = statusItem?.menu else { return }
        
        // Update status item
        if let statusMenuItem = menu.item(at: 0) {
            statusMenuItem.title = windowDragManager.isEnabled ? "✅ Active" : "⏸️ Stopped"
        }

        // Update toggle button
        if let toggleMenuItem = menu.item(at: 2) {
            toggleMenuItem.title = windowDragManager.isEnabled ? "Stop" : "Start"
        }

        // Update accessibility status
        if let accessibilityMenuItem = menu.item(at: 3) {
            accessibilityMenuItem.title = windowDragManager.hasAccessibilityPermission ?
                "✅ Accessibility Permission Granted" : "❌ Accessibility Permission Required"
        }
        
        // Update menu bar icon appearance based on status
        if let button = statusItem?.button {
            // Keep template mode off to preserve icon colors
            button.image?.isTemplate = false
            // Change appearance based on status
            if windowDragManager.isEnabled && windowDragManager.hasAccessibilityPermission {
                button.appearsDisabled = false
                button.alphaValue = 1.0
            } else {
                button.appearsDisabled = false // Don't use appearsDisabled as it makes icon invisible
                button.alphaValue = 0.6 // Use alpha to show disabled state
            }
        }
    }
    
    @objc private func toggleDragService() {
        print("🔄 Toggle drag service requested. Current state: \(windowDragManager.isEnabled)")

        // Re-check permission before toggling
        windowDragManager.checkAccessibilityPermission()

        if windowDragManager.isEnabled {
            windowDragManager.stopMonitoring()
        } else {
            if windowDragManager.hasAccessibilityPermission {
                windowDragManager.startMonitoring()
            } else {
                print("❌ Cannot start: Accessibility permission required")
                requestAccessibilityPermission()
            }
        }
        updateMenu()
    }
    
    @objc private func requestAccessibilityPermission() {
        windowDragManager.requestAccessibilityPermission()
        
        // Show alert with instructions
        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText = """
        AnyDrag requires Accessibility permission to function.

        Go to System Preferences > Security & Privacy > Privacy > Accessibility and grant permission to AnyDrag.

        Restart the application after granting permission.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open System Preferences")
        alert.addButton(withTitle: "OK")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // Open System Preferences
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        }
    }
    
    @objc private func showHelp() {
        let alert = NSAlert()
        alert.messageText = "How to Use AnyDrag?"
        alert.informativeText = """
        1. Grant Accessibility permission (if required)
        2. Select 'Start' from the menu bar
        3. Hold down the Cmd key
        4. Move your mouse - the window will automatically follow

        • You can drag any window from anywhere on it
        • Multi-monitor support is available
        • Dragging stops when you release the Cmd key
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    @objc private func toggleAutoStart() {
        let currentState = isAutoStartEnabled()
        setAutoStart(enabled: !currentState)
        updateMenu()
    }
    
    private func isAutoStartEnabled() -> Bool {
        // Check if launch agent is installed
        let launchAgentPath = getHomeDirectory().appendingPathComponent("Library/LaunchAgents/com.ufukozen.AnyDrag.plist")
        return FileManager.default.fileExists(atPath: launchAgentPath.path)
    }
    
    private func setAutoStart(enabled: Bool) {
        let launchAgentPath = getHomeDirectory().appendingPathComponent("Library/LaunchAgents/com.ufukozen.AnyDrag.plist")
        
        if enabled {
            createLaunchAgent(at: launchAgentPath)
        } else {
            removeLaunchAgent(at: launchAgentPath)
        }
    }
    
    private func getHomeDirectory() -> URL {
        return FileManager.default.homeDirectoryForCurrentUser
    }
    
    private func createLaunchAgent(at path: URL) {
        let appPath = Bundle.main.bundleURL.path
        
        let plistContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>com.ufukozen.AnyDrag</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(appPath)/Contents/MacOS/AnyDrag</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
            <key>KeepAlive</key>
            <false/>
            <key>LaunchOnlyOnce</key>
            <true/>
        </dict>
        </plist>
        """
        
        do {
            // Create LaunchAgents directory if it doesn't exist
            let launchAgentsDir = path.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: launchAgentsDir, withIntermediateDirectories: true)
            
            // Write plist file
            try plistContent.write(to: path, atomically: true, encoding: String.Encoding.utf8)
            
            // Load the launch agent
            let task = Process()
            task.launchPath = "/bin/launchctl"
            task.arguments = ["load", path.path]
            task.launch()
            task.waitUntilExit()
            
            print("✅ Auto-start enabled")
        } catch {
            print("❌ Failed to create launch agent: \(error)")
        }
    }
    
    private func removeLaunchAgent(at path: URL) {
        do {
            // Unload the launch agent first
            let task = Process()
            task.launchPath = "/bin/launchctl"
            task.arguments = ["unload", path.path]
            task.launch()
            task.waitUntilExit()
            
            // Remove the plist file
            try FileManager.default.removeItem(at: path)
            
            print("✅ Auto-start disabled")
        } catch {
            print("❌ Failed to remove launch agent: \(error)")
        }
    }
    
    // MARK: - Social Media Actions

    @objc private func openWebsite() {
        if let url = URL(string: "https://ufukozen.com") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func openLinkedIn() {
        if let url = URL(string: "https://linkedin.com/in/ufukozendev") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func openX() {
        if let url = URL(string: "https://x.com/ufukozendev") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func openGitHub() {
        if let url = URL(string: "https://github.com/ufukozendev") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func quitApp() {
        // Stop monitoring before quitting
        windowDragManager.stopMonitoring()
        NSApplication.shared.terminate(nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
