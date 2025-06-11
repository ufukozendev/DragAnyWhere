//
//  AnyDragApp.swift
//  AnyDrag
//
//  Created by ufukozendev on 11.06.2025.
//

import Cocoa

@main
struct AnyDragApp {
    static func main() {
        // Create NSApplication instance
        let app = NSApplication.shared

        // Set up app delegate
        let delegate = BackgroundAppDelegate()
        app.delegate = delegate

        // Run the app
        app.run()
    }
}
