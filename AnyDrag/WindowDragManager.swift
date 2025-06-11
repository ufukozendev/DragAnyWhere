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
            print("Accessibility permission required")
            return
        }
        
        stopMonitoring()
        
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp]) { [weak self] event in
            self?.handleGlobalEvent(event)
        }
        
        isEnabled = true
        print("Window drag monitoring started")
    }
    
    func stopMonitoring() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        isEnabled = false
        isDragging = false
        print("Window drag monitoring stopped")
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
            }

            dragStartPoint = screenLocation
            isDragging = true

            print("Started dragging window at \(screenLocation)")
        }
    }
    
    private func handleMouseDragged(_ event: NSEvent) {
        guard isDragging, let window = draggedWindow else { return }

        // Global mouse pozisyonunu al
        let screenLocation = NSEvent.mouseLocation

        let deltaX = screenLocation.x - dragStartPoint.x
        let deltaY = screenLocation.y - dragStartPoint.y

        let newPosition = CGPoint(
            x: draggedWindowStartPosition.x + deltaX,
            y: draggedWindowStartPosition.y + deltaY
        )

        moveWindow(window: window, to: newPosition)
    }
    
    private func handleMouseUp(_ event: NSEvent) {
        if isDragging {
            print("Finished dragging window")
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
            // Eğer bu bir pencere değilse, parent window'u bul
            var windowElement: AXUIElement?
            var currentElement = element

            // Window role'ü olan elementi bul
            while true {
                var roleValue: CFTypeRef?
                let roleResult = AXUIElementCopyAttributeValue(currentElement, kAXRoleAttribute as CFString, &roleValue)

                if roleResult == .success, let role = roleValue as? String, role == kAXWindowRole {
                    windowElement = currentElement
                    break
                }

                // Parent'a git
                var parentValue: CFTypeRef?
                let parentResult = AXUIElementCopyAttributeValue(currentElement, kAXParentAttribute as CFString, &parentValue)

                if parentResult == .success, let parent = parentValue {
                    currentElement = parent as! AXUIElement
                } else {
                    break
                }
            }

            return windowElement
        }

        return nil
    }
    
    private func moveWindow(window: AXUIElement, to point: CGPoint) {
        var position = point
        let positionValue = AXValueCreate(AXValueType.cgPoint, &position)

        if let positionValue = positionValue {
            let result = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, positionValue)
            if result != .success {
                print("Failed to move window: \(result)")
            }
        }
    }
    

}
