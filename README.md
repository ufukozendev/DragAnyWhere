# DragAnyWhere - Universal macOS Window Dragging Service

AnyDrag is a background service for macOS that enables you to drag any window from anywhere on the window. Simply hold the Cmd key and move your mouse to drag any application window freely across all monitors.

## Features

- 🖱️ **Universal Window Dragging**: Drag any window from any position on the window
- ⌨️ **Simple Control**: Just hold Cmd key and move your mouse
- 🔄 **Background Service**: Runs automatically at startup, invisible in dock
- 📱 **Menu Bar Control**: Easy control via menu bar icon
- 🖥️ **Multi-Monitor Support**: Free movement across all monitors with global bring-to-front
- ⚡ **Low Resource Usage**: Minimal system resource consumption
- 🔒 **Secure**: Uses only necessary permissions
- 🌟 **Instant Window Focus**: Windows come to front immediately when Cmd is pressed

## Demo

<div align="center">
  <img src="./DragAnyWhere.gif" alt="AnyDrag Demo - Universal macOS Window Dragging" width="800">
</div>

*Hold Cmd key and move your mouse to drag any window from anywhere on the window surface*

## Installation

1. **Download the Project**:
   ```bash
   git clone https://github.com/ufukozendev/DragAnyWhere.git
   cd DragAnyWhere
   ```

2. **Open with Xcode**:
   ```bash
   open AnyDrag.xcodeproj
   ```

3. **Build and Run**:
   - Build and run the project in Xcode with `Cmd+R`
   - Or from terminal:
   ```bash
   xcodebuild -project AnyDrag.xcodeproj -scheme AnyDrag -configuration Release build
   ```

## Initial Setup

1. **Grant Accessibility Permission**:
   - The app will request Accessibility permission on first launch
   - Go to System Preferences > Security & Privacy > Privacy > Accessibility
   - Find AnyDrag in the list and check the box next to it

2. **Menu Bar Icon**:
   - When the app is running, an icon will appear in the menu bar
   - Click the icon to control the service

## Usage

1. **Window Dragging**:
   - Hold the Cmd key
   - Move your mouse
   - The window under the mouse will automatically follow
   - Release the Cmd key to stop dragging
   - Windows instantly come to front across all monitors when Cmd is pressed

2. **Menu Controls**:
   - **Start/Stop**: Enable/disable the service
   - **Accessibility Permission**: Check permission status
   - **How to Use**: View help information
   - **Launch at Login**: Enable/disable automatic startup
   - **Quit**: Completely exit the application

## Auto-Launch at Startup

To make the app automatically run at system startup:

1. Click the menu bar icon
2. Check "Launch at Login" option
3. This will create a launch agent in `~/Library/LaunchAgents/` directory

To manually disable:
```bash
launchctl unload ~/Library/LaunchAgents/com.ufukozen.AnyDrag.plist
rm ~/Library/LaunchAgents/com.ufukozen.AnyDrag.plist
```

## Connect with Me

- 🌐 **Website**: [ufukozen.com](https://ufukozen.com)
- 💼 **LinkedIn**: [@ufukozendev](https://linkedin.com/in/ufukozendev)
- 🐦 **X (Twitter)**: [@ufukozendev](https://x.com/ufukozendev)
- 💻 **GitHub**: [@ufukozendev](https://github.com/ufukozendev)

## Technical Details

### Architecture
- **NSApplication**: Runs as a background service
- **WindowDragManager**: Global event monitoring and window manipulation
- **MenuBarManager**: Menu bar control and user interface
- **BackgroundService**: Service coordination and lifecycle management

### Permissions Required
- **Accessibility**: Required to modify window positions and bring windows to front
- **Global Event Monitoring**: Required to monitor Cmd key and mouse movements

### Performance Optimizations
- Event throttling (~120 FPS) for optimal performance
- Window cache system for fast window detection
- Minimal CPU and memory usage
- Multi-monitor coordinate system handling

### Multi-Monitor Support
- Global window bring-to-front across all monitors
- Proper coordinate system conversion between Cocoa and Quartz
- PID-based application activation for reliable cross-monitor focus
- NSWorkspace integration for system-level window management

## Troubleshooting

### Accessibility Permission Issues
```bash
# Check permission status
sudo sqlite3 /Library/Application\ Support/com.apple.TCC/TCC.db "SELECT * FROM access WHERE service='kTCCServiceAccessibility';"

# Restart the application
killall AnyDrag
```

### Launch Agent Issues
```bash
# Check launch agent status
launchctl list | grep com.ufukozen.AnyDrag

# Manual loading
launchctl load ~/Library/LaunchAgents/com.ufukozen.AnyDrag.plist
```

### Debug Mode
Run the app from terminal to see debug output:
```bash
/path/to/AnyDrag.app/Contents/MacOS/AnyDrag
```

### Multi-Monitor Issues
If windows don't come to front properly across monitors:
1. Ensure Accessibility permission is granted
2. Try restarting the service from menu bar
3. Check Console.app for any error messages

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under a Non-Commercial License - see the [LICENSE](LICENSE) file for details.

**Non-Commercial Use Only**: This software is free for personal, educational, and research use. Commercial use is strictly prohibited without explicit written permission.

**Copyright Notice**: This source code is the intellectual property of Ufuk Özen. All rights reserved. For commercial licensing inquiries, contact: info@ufukozen.com

## Contact

- GitHub: [@ufukozendev](https://github.com/ufukozendev)
- Project: [DragAnyWhere](https://github.com/ufukozendev/DragAnyWhere)

## Acknowledgments

- Apple's Accessibility APIs
- macOS developer community
- All contributors

## Disclaimer

This source code is provided "as is" without warranty of any kind. Use at your own risk. The author is not responsible for any damage or data loss that may occur from using this code.
