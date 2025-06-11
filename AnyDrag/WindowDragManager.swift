//
//  WindowDragManager.swift
//  AnyDrag
//
//  Created by ufukozendev on 11.06.2025.
//

import Cocoa
import ApplicationServices

// MARK: - Coordinate System Utilities for Multi-Monitor Support

extension CGPoint {
    /// Converts NSEvent.mouseLocation (Cocoa coordinates) to CGWindow coordinates (Quartz coordinates)
    /// This is essential for multi-monitor setups where coordinate systems differ
    func convertCocoaToQuartz() -> CGPoint {
        // Get the primary screen (index 0) which defines the coordinate system
        guard let primaryScreen = NSScreen.screens.first else {
            return self
        }

        // In Cocoa: origin is bottom-left of primary screen
        // In Quartz: origin is top-left of primary screen
        // Formula: quartzY = primaryScreenHeight - cocoaY
        return CGPoint(
            x: self.x,
            y: primaryScreen.frame.height - self.y
        )
    }

    /// Converts CGWindow coordinates (Quartz coordinates) to NSEvent coordinates (Cocoa coordinates)
    func convertQuartzToCocoa() -> CGPoint {
        guard let primaryScreen = NSScreen.screens.first else {
            return self
        }

        return CGPoint(
            x: self.x,
            y: primaryScreen.frame.height - self.y
        )
    }
}

struct WindowInfo {
    let windowID: CGWindowID
    let bounds: CGRect
    let ownerPID: pid_t
    let ownerName: String
    let windowName: String?
    let layer: Int
    let isOnScreen: Bool
    var axElement: AXUIElement?
}

class WindowDragManager: ObservableObject {
    private var globalMonitor: Any?
    private var isDragging = false
    private var dragStartPoint: CGPoint = .zero
    private var draggedWindow: AXUIElement?
    private var draggedWindowStartPosition: CGPoint = .zero

    // Pencere cache sistemi
    private var windowCache: [WindowInfo] = []
    private var lastCacheUpdate: Date = Date.distantPast
    private let cacheUpdateInterval: TimeInterval = 0.1 // 100ms - daha hızlı güncelleme

    // Performance tracking
    private var lastEventTime: Date = Date()
    private let minEventInterval: TimeInterval = 0.008 // ~120 FPS - daha responsive

    @Published var isEnabled = false
    @Published var hasAccessibilityPermission = false

    init() {
        checkAccessibilityPermission()
    }

    deinit {
        stopMonitoring()
    }
    
    // MARK: - Accessibility Permission
    
    func checkAccessibilityPermission() {
        let previousState = hasAccessibilityPermission
        hasAccessibilityPermission = AXIsProcessTrusted()

        print("🔍 Accessibility permission check: \(hasAccessibilityPermission ? "✅ GRANTED" : "❌ DENIED")")

        // Notify if permission state changed
        if previousState != hasAccessibilityPermission {
            print("📢 Accessibility permission state changed: \(previousState) -> \(hasAccessibilityPermission)")
            NotificationCenter.default.post(name: NSNotification.Name("AccessibilityPermissionChanged"), object: self)
        }

        if !hasAccessibilityPermission {
            print("⚠️ Requesting accessibility permission...")
            requestAccessibilityPermission()
        } else {
            print("✅ Accessibility permission is available")
        }
    }
    
    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }
    
    // MARK: - Event Monitoring
    
    func startMonitoring() {
        print("🎯 Attempting to start monitoring...")
        print("📋 Current state - hasAccessibilityPermission: \(hasAccessibilityPermission), isEnabled: \(isEnabled)")

        // Re-check permission before starting
        checkAccessibilityPermission()

        guard hasAccessibilityPermission else {
            print("❌ Cannot start monitoring: Accessibility permission required")
            print("💡 Please grant accessibility permission in System Preferences > Security & Privacy > Privacy > Accessibility")
            return
        }

        stopMonitoring()

        // Mouse hareket, modifier key değişiklikleri ve mouse button eventlerini izle
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .flagsChanged, .leftMouseDown, .leftMouseUp]) { [weak self] event in
            self?.handleGlobalEvent(event)
        }

        if globalMonitor != nil {
            isEnabled = true
            print("🚀 Window drag monitoring started successfully!")
            print("📖 Instructions: Hold Cmd and move mouse to drag windows")

            // Notify observers of state change
            NotificationCenter.default.post(name: NSNotification.Name("WindowDragManagerStateChanged"), object: self)
        } else {
            print("❌ Failed to create global event monitor")
        }
    }

    func stopMonitoring() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        isEnabled = false
        isDragging = false
        print("⏹️ Window drag monitoring stopped")

        // Notify observers of state change
        NotificationCenter.default.post(name: NSNotification.Name("WindowDragManagerStateChanged"), object: self)
    }
    
    // MARK: - Event Handling

    private func handleGlobalEvent(_ event: NSEvent) {
        // Performance throttling - minimum interval between events
        let now = Date()
        if now.timeIntervalSince(lastEventTime) < minEventInterval {
            return
        }
        lastEventTime = now

        let modifierFlags = event.modifierFlags
        let hasCommandKey = modifierFlags.contains(.command)

        switch event.type {
        case .flagsChanged:
            handleFlagsChanged(hasCommandKey: hasCommandKey)
        case .mouseMoved:
            if hasCommandKey {
                handleMouseMovedWithCmd(event)
            } else {
                handleMouseMovedWithoutCmd()
            }
        default:
            break
        }
    }

    private func handleFlagsChanged(hasCommandKey: Bool) {
        if hasCommandKey && !isDragging {
            print("⌨️ Cmd key pressed - bringing window to front and preparing for drag")
            // Cmd tuşu basıldı, mouse altındaki pencereyi en üste getir ve sürüklemeye hazırla
            bringWindowToFrontAndPrepareForDrag()
        } else if !hasCommandKey && isDragging {
            print("⌨️ Cmd key released - stopping drag")
            // Cmd tuşu bırakıldı, sürüklemeyi durdur
            stopDragging()
        }
    }

    private func handleMouseMovedWithCmd(_ event: NSEvent) {
        if !isDragging {
            // Henüz sürükleme başlamamışsa, mouse altındaki pencereyi bul
            startDragIfPossible()
        } else {
            // Zaten sürükleme devam ediyorsa, pencereyi hareket ettir
            handleMouseDragged(event)
        }
    }

    private func handleMouseMovedWithoutCmd() {
        if isDragging {
            stopDragging()
        }
    }

    private func bringWindowToFrontAndPrepareForDrag() {
        let screenLocation = NSEvent.mouseLocation

        // Pencere cache'ini güncelle
        updateWindowCacheIfNeeded()

        // Mouse altındaki pencereyi bul
        if let windowInfo = getWindowUnderPointHybrid(screenLocation),
           let axElement = windowInfo.axElement {

            // Hemen pencereyi en üste getir (Cmd tuşuna basıldığında)
            // WindowInfo'dan PID bilgisini kullanarak daha etkili bring-to-front
            bringWindowToFrontWithPID(axElement, pid: windowInfo.ownerPID)

            // Sürükleme için hazırla
            draggedWindow = axElement

            // Mevcut pencere pozisyonunu al
            var position: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(axElement, kAXPositionAttribute as CFString, &position)

            if result == .success, let positionValue = position {
                var point = CGPoint.zero
                AXValueGetValue(positionValue as! AXValue, AXValueType.cgPoint, &point)
                draggedWindowStartPosition = point

                dragStartPoint = screenLocation
                isDragging = true

                print("✅ Window brought to front and ready for dragging: \(windowInfo.ownerName) - \(windowInfo.windowName ?? "Untitled")")
            }
        }
    }

    private func startDragIfPossible() {
        let screenLocation = NSEvent.mouseLocation

        // Pencere cache'ini güncelle
        updateWindowCacheIfNeeded()

        // Mouse altındaki pencereyi bul
        if let windowInfo = getWindowUnderPointHybrid(screenLocation),
           let axElement = windowInfo.axElement {

            draggedWindow = axElement

            // Mevcut pencere pozisyonunu al
            var position: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(axElement, kAXPositionAttribute as CFString, &position)

            if result == .success, let positionValue = position {
                var point = CGPoint.zero
                AXValueGetValue(positionValue as! AXValue, AXValueType.cgPoint, &point)
                draggedWindowStartPosition = point

                dragStartPoint = screenLocation
                isDragging = true

                print("✅ Started dragging window: \(windowInfo.ownerName) - \(windowInfo.windowName ?? "Untitled")")
            }
        }
    }

    private func stopDragging() {
        if isDragging {
            print("✅ Stopped dragging window")
            isDragging = false
            draggedWindow = nil
        }
    }
    
    private func handleMouseDragged(_ event: NSEvent) {
        guard isDragging, let window = draggedWindow else { return }

        // Global mouse pozisyonunu al
        let screenLocation = NSEvent.mouseLocation

        let deltaX = screenLocation.x - dragStartPoint.x
        let deltaY = screenLocation.y - dragStartPoint.y

        // ÖNEMLİ: macOS'ta mouse events ve window positions farklı koordinat sistemleri kullanır
        // Mouse events: origin sol üstte (0,0 sol üst köşe)
        // Window positions: origin sol altta (0,0 sol alt köşe)
        // Bu yüzden deltaY'yi tersine çevirmemiz gerekiyor
        let newPosition = CGPoint(
            x: draggedWindowStartPosition.x + deltaX,
            y: draggedWindowStartPosition.y - deltaY  // Y eksenini ters çevir
        )

        // Debug bilgisi
        if abs(deltaX) > 5 || abs(deltaY) > 5 {
            print("🔄 Dragging: delta(\(Int(deltaX)), \(Int(deltaY))) -> new position(\(Int(newPosition.x)), \(Int(newPosition.y)))")
        }

        moveWindow(window: window, to: newPosition)
    }
    
    // MARK: - Window Cache Management

    private func updateWindowCacheIfNeeded() {
        let now = Date()
        if now.timeIntervalSince(lastCacheUpdate) > cacheUpdateInterval {
            updateWindowCache()
            lastCacheUpdate = now
        }
    }

    private func updateWindowCache() {
        windowCache.removeAll()

        // CGWindowListCopyWindowInfo kullanarak tüm pencereleri al
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        let windowListInfo = CGWindowListCopyWindowInfo(options, kCGNullWindowID)

        guard let windowList = windowListInfo as? [[String: Any]] else {
            print("❌ Failed to get window list")
            return
        }

        for windowDict in windowList {
            guard let windowID = windowDict[kCGWindowNumber as String] as? CGWindowID,
                  let bounds = windowDict[kCGWindowBounds as String] as? [String: Any],
                  let ownerPID = windowDict[kCGWindowOwnerPID as String] as? pid_t,
                  let ownerName = windowDict[kCGWindowOwnerName as String] as? String,
                  let layer = windowDict[kCGWindowLayer as String] as? Int,
                  let isOnScreen = windowDict[kCGWindowIsOnscreen as String] as? Bool else {
                continue
            }

            // Bounds'u CGRect'e çevir
            guard let x = bounds["X"] as? CGFloat,
                  let y = bounds["Y"] as? CGFloat,
                  let width = bounds["Width"] as? CGFloat,
                  let height = bounds["Height"] as? CGFloat else {
                continue
            }

            let windowBounds = CGRect(x: x, y: y, width: width, height: height)
            let windowName = windowDict[kCGWindowName as String] as? String

            // Filter very small windows (probably UI elements)
            if windowBounds.width < 50 || windowBounds.height < 30 {
                continue
            }

            // Filter system-level windows
            if layer > 0 || ownerName == "Window Server" || ownerName == "Dock" {
                continue
            }

            let windowInfo = WindowInfo(
                windowID: windowID,
                bounds: windowBounds,
                ownerPID: ownerPID,
                ownerName: ownerName,
                windowName: windowName,
                layer: layer,
                isOnScreen: isOnScreen,
                axElement: nil // This will be loaded lazily later
            )

            windowCache.append(windowInfo)
        }

        print("📋 Updated window cache: \(windowCache.count) windows")
    }

    private func getWindowUnderPointHybrid(_ point: CGPoint) -> WindowInfo? {
        // CRITICAL: Convert NSEvent.mouseLocation (Cocoa) to CGWindow coordinates (Quartz)
        // This is the key fix for multi-monitor support
        let quartzPoint = point.convertCocoaToQuartz()

        // Cache'den mouse pozisyonundaki pencereyi bul (en üstteki pencereyi bul)
        var candidateWindows: [WindowInfo] = []

        for windowInfo in windowCache {
            // Use the converted Quartz coordinates to match CGWindow bounds
            if windowInfo.bounds.contains(quartzPoint) {
                candidateWindows.append(windowInfo)
            }
        }

        // Layer'a göre sırala (en üstteki pencere en düşük layer'a sahip)
        candidateWindows.sort { $0.layer < $1.layer }

        // En üstteki pencere için AX element'i yükle
        for var windowInfo in candidateWindows {
            if let axElement = getAXElementForWindow(windowInfo) {
                windowInfo.axElement = axElement
                return windowInfo
            }
        }

        // Fallback: Eski yöntemi kullan (bu da Cocoa koordinatlarını kullanır)
        if let axElement = getWindowUnderPoint(point) {
            return WindowInfo(
                windowID: 0,
                bounds: .zero,
                ownerPID: 0,
                ownerName: "Unknown",
                windowName: nil,
                layer: 0,
                isOnScreen: true,
                axElement: axElement
            )
        }

        return nil
    }

    private func getAXElementForWindow(_ windowInfo: WindowInfo) -> AXUIElement? {
        // PID'den application element'i al
        let appElement = AXUIElementCreateApplication(windowInfo.ownerPID)

        // Application'ın pencerelerini al
        var windowsValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsValue)

        if result == .success, let windows = windowsValue as? [AXUIElement] {
            for window in windows {
                // Pencere pozisyonunu kontrol et
                var positionValue: CFTypeRef?
                let posResult = AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionValue)

                var sizeValue: CFTypeRef?
                let sizeResult = AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeValue)

                if posResult == .success && sizeResult == .success,
                   let posValue = positionValue, let szValue = sizeValue {

                    var position = CGPoint.zero
                    var size = CGSize.zero

                    AXValueGetValue(posValue as! AXValue, AXValueType.cgPoint, &position)
                    AXValueGetValue(szValue as! AXValue, AXValueType.cgSize, &size)

                    let axBounds = CGRect(origin: position, size: size)

                    // Bounds'ları karşılaştır (küçük toleransla)
                    if abs(axBounds.origin.x - windowInfo.bounds.origin.x) < 5 &&
                       abs(axBounds.origin.y - windowInfo.bounds.origin.y) < 5 &&
                       abs(axBounds.size.width - windowInfo.bounds.size.width) < 5 &&
                       abs(axBounds.size.height - windowInfo.bounds.size.height) < 5 {

                        // Sürüklenebilir olup olmadığını kontrol et
                        if isWindowDraggable(window) {
                            return window
                        }
                    }
                }
            }
        }

        return nil
    }

    // MARK: - Window Management (Legacy)

    private func getWindowUnderPoint(_ point: CGPoint) -> AXUIElement? {
        let systemWideElement = AXUIElementCreateSystemWide()
        var elementRef: AXUIElement?

        let result = AXUIElementCopyElementAtPosition(systemWideElement, Float(point.x), Float(point.y), &elementRef)

        if result == .success, let element = elementRef {
            // Eğer bu bir pencere değilse, ebeveyn (parent) penceresini bulmaya çalış
            var windowElement: AXUIElement?
            var currentElement = element
            var searchDepth = 0
            let maxSearchDepth = 10 // Sonsuz döngüyü önlemek için

            // Pencere rolüne sahip olan üst öğeyi bulana kadar yukarı çık
            while searchDepth < maxSearchDepth {
                var roleValue: CFTypeRef?
                let roleResult = AXUIElementCopyAttributeValue(currentElement, kAXRoleAttribute as CFString, &roleValue)

                if roleResult == .success, let role = roleValue as? String {
                    // Farklı pencere türlerini kontrol et
                    if role == kAXWindowRole ||
                       role == "AXDialog" ||
                       role == "AXSheet" ||
                       role == "AXFloatingWindow" {

                        // Pencerenin sürüklenebilir olup olmadığını kontrol et
                        if isWindowDraggable(currentElement) {
                            windowElement = currentElement
                            break
                        }
                    }
                }

                // Parent'a git
                var parentValue: CFTypeRef?
                let parentResult = AXUIElementCopyAttributeValue(currentElement, kAXParentAttribute as CFString, &parentValue)

                if parentResult == .success, let parent = parentValue {
                    currentElement = parent as! AXUIElement
                    searchDepth += 1
                } else {
                    break
                }
            }

            return windowElement
        }

        return nil
    }

    private func isWindowDraggable(_ window: AXUIElement) -> Bool {
        // Pencerenin position attribute'una sahip olup olmadığını kontrol et
        var positionValue: CFTypeRef?
        let positionResult = AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionValue)

        if positionResult != .success {
            return false
        }

        // Pencerenin position attribute'unun settable olup olmadığını kontrol et
        var isSettable: DarwinBoolean = false
        let settableResult = AXUIElementIsAttributeSettable(window, kAXPositionAttribute as CFString, &isSettable)

        return settableResult == .success && isSettable.boolValue
    }
    
    private func moveWindow(window: AXUIElement, to point: CGPoint) {
        // Serbest hareket - hiçbir kısıtlama yok, çoklu monitör desteği
        var position = point
        let positionValue = AXValueCreate(AXValueType.cgPoint, &position)

        if let positionValue = positionValue {
            let result = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, positionValue)
            if result != .success {
                print("❌ Failed to move window: \(result.rawValue)")
            }
        }
    }

    private func bringWindowToFront(_ window: AXUIElement) {
        // Multi-monitör desteği için gelişmiş pencere en üste getirme
        print("🔝 Attempting to bring window to front with multi-monitor support...")

        // 1. Önce pencereyi minimize durumundan çıkar (eğer minimize ise)
        var minimizedValue: CFTypeRef?
        let minimizedResult = AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &minimizedValue)

        if minimizedResult == .success,
           let isMinimized = minimizedValue as? Bool,
           isMinimized {
            print("📤 Window is minimized, unminimizing first...")
            let unminimizeResult = AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
            if unminimizeResult == .success {
                print("✅ Window unminimized successfully")
            } else {
                print("⚠️ Failed to unminimize window: \(unminimizeResult.rawValue)")
            }
        }

        // 2. Pencereyi aktif hale getir (focus)
        let focusResult = AXUIElementSetAttributeValue(window, kAXFocusedAttribute as CFString, kCFBooleanTrue)
        if focusResult == .success {
            print("🎯 Window focused successfully")
        } else {
            print("⚠️ Failed to focus window: \(focusResult.rawValue)")
        }

        // 3. Bring window to front (raise)
        let raiseResult = AXUIElementPerformAction(window, kAXRaiseAction as CFString)
        if raiseResult == .success {
            print("⬆️ Window raised successfully")
        } else {
            print("⚠️ Failed to raise window: \(raiseResult.rawValue)")
        }

        // 4. Activate application (critical for multi-monitor)
        var appValue: CFTypeRef?
        let appResult = AXUIElementCopyAttributeValue(window, kAXParentAttribute as CFString, &appValue)

        if appResult == .success, appValue != nil {
            let appElement = appValue as! AXUIElement
            // Bring application to front
            let appRaiseResult = AXUIElementPerformAction(appElement, kAXRaiseAction as CFString)
            if appRaiseResult == .success {
                print("🚀 Application raised successfully")
            } else {
                print("⚠️ Failed to raise application: \(appRaiseResult.rawValue)")
            }

            // Activate application
            let appFocusResult = AXUIElementSetAttributeValue(appElement, kAXFocusedAttribute as CFString, kCFBooleanTrue)
            if appFocusResult == .success {
                print("🎯 Application focused successfully")
            }
        }

        // 5. Finally, bring window to front again (double-raise technique)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            let finalRaiseResult = AXUIElementPerformAction(window, kAXRaiseAction as CFString)
            if finalRaiseResult == .success {
                print("✅ Final window raise successful - multi-monitor bring-to-front completed")
            } else {
                print("⚠️ Final window raise failed: \(finalRaiseResult.rawValue)")
            }
        }
    }

    private func bringWindowToFrontWithPID(_ window: AXUIElement, pid: pid_t) {
        // More effective multi-monitor bring-to-front with PID information
        print("🔝 Bringing window to front with PID-based approach for multi-monitor support...")

        // 1. First perform standard bring-to-front operation
        bringWindowToFront(window)

        // 2. Create application element from PID (more reliable)
        let appElement = AXUIElementCreateApplication(pid)

        // 3. Activate application (critical for multi-monitor)
        let appRaiseResult = AXUIElementPerformAction(appElement, kAXRaiseAction as CFString)
        if appRaiseResult == .success {
            print("🚀 Application raised successfully via PID")
        } else {
            print("⚠️ Failed to raise application via PID: \(appRaiseResult.rawValue)")
        }

        // 4. Focus application
        let appFocusResult = AXUIElementSetAttributeValue(appElement, kAXFocusedAttribute as CFString, kCFBooleanTrue)
        if appFocusResult == .success {
            print("🎯 Application focused successfully via PID")
        }

        // 5. Activate application using NSWorkspace (system level)
        let runningApps = NSWorkspace.shared.runningApplications
        if let targetApp = runningApps.first(where: { $0.processIdentifier == pid }) {
            // Compatible activation for macOS 14+
            let activateResult: Bool
            if #available(macOS 14.0, *) {
                activateResult = targetApp.activate()
            } else {
                activateResult = targetApp.activate(options: [.activateIgnoringOtherApps])
            }

            if activateResult {
                print("🌟 Application activated via NSWorkspace - this should bring it to front across all monitors")
            } else {
                print("⚠️ Failed to activate application via NSWorkspace")
            }
        }

        // 6. Finally, bring window to front again (delayed double-raise)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let finalRaiseResult = AXUIElementPerformAction(window, kAXRaiseAction as CFString)
            if finalRaiseResult == .success {
                print("✅ Final window raise successful - multi-monitor bring-to-front completed with PID approach")
            }
        }
    }

    private func getWindowInfo(_ window: AXUIElement) -> String {
        var info: [String] = []

        // Get window title
        var titleValue: CFTypeRef?
        if AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleValue) == .success,
           let title = titleValue as? String, !title.isEmpty {
            info.append("Title: '\(title)'")
        }

        // Get application name
        var appValue: CFTypeRef?
        if AXUIElementCopyAttributeValue(window, kAXParentAttribute as CFString, &appValue) == .success,
           let app = appValue {
            var appTitleValue: CFTypeRef?
            if AXUIElementCopyAttributeValue(app as! AXUIElement, kAXTitleAttribute as CFString, &appTitleValue) == .success,
               let appTitle = appTitleValue as? String {
                info.append("App: '\(appTitle)'")
            }
        }

        // Get window role
        var roleValue: CFTypeRef?
        if AXUIElementCopyAttributeValue(window, kAXRoleAttribute as CFString, &roleValue) == .success,
           let role = roleValue as? String {
            info.append("Role: '\(role)'")
        }

        return info.isEmpty ? "Unknown Window" : info.joined(separator: ", ")
    }
}