//
//  BackgroundService.swift
//  AnyDrag
//
//  Created by luckymac on 11.06.2025.
//

import Cocoa
import Foundation
import UserNotifications

class BackgroundService: NSObject {
    private let windowDragManager: WindowDragManager
    private let menuBarManager: MenuBarManager
    
    override init() {
        // Initialize window drag manager
        self.windowDragManager = WindowDragManager()
        
        // Initialize menu bar manager
        self.menuBarManager = MenuBarManager(windowDragManager: windowDragManager)
        
        super.init()
        
        setupService()
    }
    
    private func setupService() {
        print("🚀 AnyDrag Background Service starting...")

        // Check accessibility permission on startup
        windowDragManager.checkAccessibilityPermission()

        // Auto-start monitoring if permission is available
        if windowDragManager.hasAccessibilityPermission {
            // Small delay to ensure everything is initialized
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.windowDragManager.startMonitoring()
                print("✅ AnyDrag started automatically with accessibility permission")
            }
        } else {
            print("⚠️ AnyDrag started but accessibility permission is required")

            // Show notification about permission requirement
            showAccessibilityPermissionNotification()

            // Start periodic permission checking
            startPeriodicPermissionCheck()
        }

        // Setup observers for state changes
        setupObservers()
    }
    
    private func setupObservers() {
        // Observe accessibility permission changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(accessibilityPermissionChanged),
            name: NSNotification.Name("AccessibilityPermissionChanged"),
            object: nil
        )
        
        // Observe app termination
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillTerminate),
            name: NSApplication.willTerminateNotification,
            object: nil
        )
    }
    
    @objc private func accessibilityPermissionChanged() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if self.windowDragManager.hasAccessibilityPermission && !self.windowDragManager.isEnabled {
                // Permission granted, auto-start monitoring
                self.windowDragManager.startMonitoring()
                print("✅ Accessibility permission granted, auto-starting monitoring")
                
                // Show success notification
                self.showNotification(
                    title: "AnyDrag Active",
                    message: "Window dragging with Cmd key has been activated."
                )
            }
        }
    }
    
    @objc private func applicationWillTerminate() {
        print("🛑 AnyDrag Background Service stopping...")
        windowDragManager.stopMonitoring()
    }

    private func startPeriodicPermissionCheck() {
        // Check permission every 5 seconds until granted
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }

            self.windowDragManager.checkAccessibilityPermission()

            if self.windowDragManager.hasAccessibilityPermission {
                print("🎉 Accessibility permission detected! Starting monitoring...")
                self.windowDragManager.startMonitoring()
                timer.invalidate() // Stop checking once permission is granted
            }
        }
    }
    
    private func showAccessibilityPermissionNotification() {
        showNotification(
            title: "AnyDrag - Permission Required",
            message: "Accessibility permission required. Click the menu bar icon."
        )
    }
    
    private func showNotification(title: String, message: String) {
        let center = UNUserNotificationCenter.current()

        // Request permission first
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                let content = UNMutableNotificationContent()
                content.title = title
                content.body = message
                content.sound = UNNotificationSound.default

                let request = UNNotificationRequest(
                    identifier: UUID().uuidString,
                    content: content,
                    trigger: nil
                )

                center.add(request) { error in
                    if let error = error {
                        print("❌ Failed to show notification: \(error)")
                    }
                }
            }
        }
    }
    
    // MARK: - Public Interface
    
    func getWindowDragManager() -> WindowDragManager {
        return windowDragManager
    }
    
    func getMenuBarManager() -> MenuBarManager {
        return menuBarManager
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - App Delegate Extension for Background Service

class BackgroundAppDelegate: NSObject, NSApplicationDelegate {
    private var backgroundService: BackgroundService?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("🎯 AnyDrag launching as background service...")
        
        // Hide from dock and remove main window
        NSApp.setActivationPolicy(.accessory)
        
        // Initialize background service
        backgroundService = BackgroundService()
        
        // Prevent app from terminating when last window closes
        NSApp.setActivationPolicy(.accessory)
        
        print("✅ AnyDrag background service initialized")
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        print("👋 AnyDrag background service terminating...")
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Don't terminate when windows close - we're a background service
        return false
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Don't show windows when app is reopened - we're background only
        return false
    }
}
