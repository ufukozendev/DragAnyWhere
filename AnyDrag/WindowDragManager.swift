//
//  WindowDragManager.swift
//  AnyDrag
//
//  Created by luckymac on 11.06.2025.
//

import Cocoa
import ApplicationServices

class WindowDragManager: ObservableObject {
    private var globalMonitor: Any?
    private var isDragging = false
    private var dragStartPoint: CGPoint = .zero
    private var draggedWindow: AXUIElement?
    private var draggedWindowStartPosition: CGPoint = .zero

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
        hasAccessibilityPermission = AXIsProcessTrusted()
        
        if !hasAccessibilityPermission {
            requestAccessibilityPermission()
        }
    }
    
    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }
    
    // MARK: - Event Monitoring
    
    func startMonitoring() {
        guard hasAccessibilityPermission else {
            print("❌ Accessibility permission required")
            return
        }

        stopMonitoring()

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp]) { [weak self] event in
            self?.handleGlobalEvent(event)
        }

        isEnabled = true
        print("🚀 Window drag monitoring started - Cmd+Click any window to drag")
    }

    func stopMonitoring() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        isEnabled = false
        isDragging = false
        print("⏹️ Window drag monitoring stopped")
    }
    
    // MARK: - Event Handling
    
    private func handleGlobalEvent(_ event: NSEvent) {
        let modifierFlags = event.modifierFlags
        let hasCommandKey = modifierFlags.contains(.command)
        
        // Sadece Cmd tuşu basılıyken işlem yap
        guard hasCommandKey else { return }
        
        switch event.type {
        case .leftMouseDown:
            handleMouseDown(event)
        case .leftMouseDragged:
            handleMouseDragged(event)
        case .leftMouseUp:
            handleMouseUp(event)
        default:
            break
        }
    }
    
    private func handleMouseDown(_ event: NSEvent) {
        // Global mouse pozisyonunu al
        let screenLocation = NSEvent.mouseLocation

        // Mouse altındaki pencereyi bul
        if let window = getWindowUnderPoint(screenLocation) {
            draggedWindow = window

            // Mevcut pencere pozisyonunu al
            var position: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &position)

            if result == .success, let positionValue = position {
                var point = CGPoint.zero
                AXValueGetValue(positionValue as! AXValue, AXValueType.cgPoint, &point)
                draggedWindowStartPosition = point

                dragStartPoint = screenLocation
                isDragging = true

                // Pencere bilgilerini al
                let windowInfo = getWindowInfo(window)
                print("✅ Started dragging window: \(windowInfo) at \(screenLocation)")
            } else {
                print("❌ Failed to get window position")
            }
        } else {
            print("⚠️ No draggable window found at \(screenLocation)")
        }
    }
    
    private func handleMouseDragged(_ event: NSEvent) {
        guard isDragging, let window = draggedWindow else { return }

        // Global mouse pozisyonunu al
        let screenLocation = NSEvent.mouseLocation

        let deltaX = screenLocation.x - dragStartPoint.x
        // Mouse olaylarının koordinat sistemi (orijin sol altta) ile pencere
        // pozisyonunun koordinat sistemi (orijin sol üstte) farklıdır.
        // Bu nedenle Y eksenindeki farkı tersine çevirmemiz gerekiyor.
        let deltaY = screenLocation.y - dragStartPoint.y

        let newPosition = CGPoint(
            x: draggedWindowStartPosition.x + deltaX,
            // DÜZELTME: Pencereyi doğru yönde hareket ettirmek için `deltaY` çıkarılır.
            y: draggedWindowStartPosition.y - deltaY
        )

        moveWindow(window: window, to: newPosition)
    }
    
    private func handleMouseUp(_ event: NSEvent) {
        if isDragging {
            print("✅ Finished dragging window")
            isDragging = false
            draggedWindow = nil
        }
    }
    
    // MARK: - Window Management

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
        var position = point
        let positionValue = AXValueCreate(AXValueType.cgPoint, &position)

        if let positionValue = positionValue {
            let result = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, positionValue)
            if result != .success {
                print("❌ Failed to move window: \(result)")
            }
        }
    }

    private func getWindowInfo(_ window: AXUIElement) -> String {
        var info: [String] = []

        // Pencere başlığını al
        var titleValue: CFTypeRef?
        if AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleValue) == .success,
           let title = titleValue as? String, !title.isEmpty {
            info.append("Title: '\(title)'")
        }

        // Uygulama adını al
        var appValue: CFTypeRef?
        if AXUIElementCopyAttributeValue(window, kAXParentAttribute as CFString, &appValue) == .success,
           let app = appValue {
            var appTitleValue: CFTypeRef?
            if AXUIElementCopyAttributeValue(app as! AXUIElement, kAXTitleAttribute as CFString, &appTitleValue) == .success,
               let appTitle = appTitleValue as? String {
                info.append("App: '\(appTitle)'")
            }
        }

        // Pencere rolünü al
        var roleValue: CFTypeRef?
        if AXUIElementCopyAttributeValue(window, kAXRoleAttribute as CFString, &roleValue) == .success,
           let role = roleValue as? String {
            info.append("Role: '\(role)'")
        }

        return info.isEmpty ? "Unknown Window" : info.joined(separator: ", ")
    }
}