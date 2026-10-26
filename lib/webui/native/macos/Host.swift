import AppKit
import WebKit

/// Shared snapshot for prelaunch discovery and authenticated in-window measurements.
func monitorSnapshot(active: NSScreen? = NSScreen.main) -> [String: Any] {
    let screens = NSScreen.screens
    let top = screens.first?.frame.maxY ?? 0
    return ["source": "native", "screens": screens.prefix(32).map { screen -> [String: Any] in
        let rect = screen.frame
        return ["x": Int(rect.minX.rounded()), "y": Int((top - rect.maxY).rounded()),
                "width": Int(rect.width.rounded()), "height": Int(rect.height.rounded()),
                "primary": screen === screens.first, "active": screen === active]
    }]
}

/// One process owns one WebUI window; Ruby retains process and owner lifetime.
/// Allows borderless windows to receive keyboard input like titled windows.
final class WebWindow: NSWindow {
    /// Permits keyboard focus even when the window has no title bar.
    override var canBecomeKey: Bool { true }
    /// Permits main-window status for the borderless presentation variant.
    override var canBecomeMain: Bool { true }
}

/// Hosts one loopback page with native presentation and a nonpersistent WebKit store.
final class Host: NSObject, NSApplicationDelegate, NSWindowDelegate, WKNavigationDelegate,
                  WKUIDelegate, WKScriptMessageHandler {
    let launchURL: URL
    let geometry: [String: Any]
    var window: WebWindow!
    var web: WKWebView!
    var revealed = false
    var lastMinimizedRequest: Bool?
    var lastMinimizedRevision: Int?
    /// Reference edge for converting AppKit coordinates to browser top-left coordinates.
    var primaryTop: CGFloat { NSScreen.screens.first?.frame.maxY ?? 0 }

    /// Retains launch configuration without creating or showing a window.
    /// - Parameters:
    ///   - url: Validated loopback launch URL, including its private launch token.
    ///   - geometry: Initial outer dimensions and optional desktop position.
    init(url: URL, geometry: [String: Any]) {
        launchURL = url
        self.geometry = geometry
    }

    /// Builds the hidden window and main-frame bridge, then loads the authenticated page.
    /// The first presentation message reveals it after the renderer supplies its settings.
    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let path = Bundle.main.path(forResource: "window", ofType: "js"),
              let bridge = try? String(contentsOfFile: path, encoding: .utf8) else {
            fail("Missing window bridge")
            return
        }
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        // Hidden script windows still receive server requests to reveal themselves.
        // Suspending their JavaScript would also suspend that control channel.
        config.preferences.inactiveSchedulingPolicy = .none
        config.userContentController.add(self, name: "lichWindow")
        config.userContentController.addUserScript(WKUserScript(source: bridge,
            injectionTime: .atDocumentStart, forMainFrameOnly: true))
        web = WKWebView(frame: .zero, configuration: config)
        web.navigationDelegate = self
        web.uiDelegate = self
        let width = dimension(geometry["width"]) ?? 800
        let height = dimension(geometry["height"]) ?? 600
        window = WebWindow(contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.contentView = web
        window.hidesOnDeactivate = false
        window.setFrame(NSRect(x: 0, y: 0, width: width, height: height), display: false)
        window.center()
        if let position = geometry["position"] as? [Double], position.count == 2 {
            move(x: position[0], y: position[1])
        }
        // Publish measurements before the renderer applies its first content
        // size request; later native resize/move events update the same bridge.
        config.userContentController.addUserScript(WKUserScript(source: geometryScript(),
            injectionTime: .atDocumentStart, forMainFrameOnly: true))
        installMenu()
        web.load(URLRequest(url: launchURL))
    }

    /// Checks exact origin equality with the launch URL, including its loopback port.
    /// - Parameter url: Navigation or script-message origin to check.
    /// - Returns: False for missing URLs or any scheme, host or port mismatch.
    func trusted(_ url: URL?) -> Bool {
        guard let url = url else { return false }
        return url.scheme == launchURL.scheme && url.host == launchURL.host && url.port == launchURL.port
    }

    /// User-activated HTTP(S) help links open in the system browser. They never
    /// navigate the privileged WebView or inherit its bridge/cookies. Scripted
    /// redirects, subframes, credentials and same-host cross-port links stay blocked.
    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if ExternalLinks.permits(action.request.url, source: action.sourceFrame.request.url,
                                 launch: launchURL, mainFrame: action.sourceFrame.isMainFrame,
                                 userActivated: action.navigationType == .linkActivated), let url = action.request.url {
            NSWorkspace.shared.open(url)
            decisionHandler(.cancel)
            return
        }
        decisionHandler(trusted(action.request.url) && action.targetFrame?.isMainFrame == true ? .allow : .cancel)
    }

    /// Applies bounded window operations from the trusted main frame only.
    /// Unknown actions and malformed payloads are ignored; presentation preserves focus.
    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.frameInfo.isMainFrame, trusted(message.frameInfo.request.url),
              let value = message.body as? [String: Any] else { return }
        switch value["action"] as? String {
        case "resize":
            if let width = dimension(value["width"]), let height = dimension(value["height"]) {
                var frame = window.frame
                frame.origin.y += frame.height - height
                frame.size = NSSize(width: width, height: height)
                if frame != window.frame { window.setFrame(frame, display: true) }
            }
        case "move":
            if let x = coordinate(value["x"]), let y = coordinate(value["y"]) { move(x: x, y: y) }
        case "close": closeWindow(nil)
        case "present":
            window.title = String((value["title"] as? String ?? "Lich WebUI").prefix(512))
            // Gtk::Window opacity affects the complete OS window, including
            // its frame. The renderer must not multiply this with a CSS fade.
            let opacity = (value["opacity"] as? Double) ?? 1
            window.alphaValue = opacity.isFinite ? min(1, max(0.1, opacity)) : 1
            let above = value["always_on_top"] as? Bool ?? false
            window.level = NSWindow.Level(rawValue: NSWindow.Level.normal.rawValue + (above ? 1 : 0))
            // Stay above ordinary windows in this Space without following the
            // user onto other desktops or another app's full-screen Space.
            window.collectionBehavior = []
            let borderless = value["borderless"] as? Bool ?? false
            let mask: NSWindow.StyleMask = borderless ? [.borderless, .miniaturizable, .resizable] : [.titled, .closable, .miniaturizable, .resizable]
            if window.styleMask != mask {
                let content = window.contentRect(forFrameRect: window.frame)
                window.styleMask = mask
                window.setFrame(window.frameRect(forContentRect: content), display: true)
            }
            window.contentMinSize = NSSize(width: dimension(value["min_width"]) ?? 1,
                                           height: dimension(value["min_height"]) ?? 1)
            if value["hidden"] as? Bool == true {
                window.orderOut(nil)
                revealed = false
            } else if !revealed {
                revealed = true
                NSApplication.shared.unhideWithoutActivation()
                window.orderFrontRegardless()
            }
            let revision = value["minimized_revision"] as? Int
            if let minimized = value["minimized"] as? Bool,
               minimized != lastMinimizedRequest || revision != lastMinimizedRevision {
                lastMinimizedRequest = minimized
                lastMinimizedRevision = revision
                if minimized && !window.isMiniaturized { window.miniaturize(nil) }
                if !minimized && window.isMiniaturized { window.deminiaturize(nil) }
            }
            reportGeometry()
        default: break
        }
    }

    /// Accepts finite desktop coordinates within the host's supported range.
    /// - Returns: The coordinate, or nil for an invalid or out-of-range value.
    func coordinate(_ value: Any?) -> Double? {
        guard let number = value as? Double, number.isFinite, abs(number) <= 65536 else { return nil }
        return number
    }
    /// Restricts window dimensions to positive values within the coordinate range.
    /// - Returns: The dimension, or nil when it cannot describe a window size.
    func dimension(_ value: Any?) -> Double? {
        guard let number = coordinate(value), number >= 1 else { return nil }
        return number
    }
    /// Moves the outer top-left corner using browser-style desktop coordinates.
    /// Invalid coordinates leave the window in place.
    func move(x: Double, y: Double) {
        guard coordinate(x) != nil, coordinate(y) != nil else { return }
        let point = NSPoint(x: x, y: primaryTop - y)
        let screen = NSScreen.screens.first {
            x >= $0.frame.minX && x < $0.frame.maxX &&
            y >= primaryTop - $0.frame.maxY && y < primaryTop - $0.frame.minY
        } ?? window.screen ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return }
        // Best effort: keep the title edge visible without resizing oversized content.
        let left = min(max(point.x, visible.minX), max(visible.minX, visible.maxX - window.frame.width))
        let top = max(min(point.y, visible.maxY), min(visible.maxY, visible.minY + window.frame.height))
        window.setFrameTopLeftPoint(NSPoint(x: left, y: top))
    }
    /// Encodes native outer bounds for the renderer's browser-compatible geometry API.
    /// - Returns: A bridge update script, or an empty string if encoding fails.
    func geometryScript() -> String {
        let frame = window.frame
        let values: [String: Any] = ["outerWidth": frame.width, "outerHeight": frame.height,
                      "screenX": frame.minX, "screenY": primaryTop - frame.maxY,
                      "monitors": monitorSnapshot(active: window.screen), "minimized": window.isMiniaturized]
        guard let data = try? JSONSerialization.data(withJSONObject: values),
              let json = String(data: data, encoding: .utf8) else { return "" }
        return "window.lichNativeWindow?.update(\(json));"
    }
    /// Publishes current bounds without waiting for JavaScript evaluation to complete.
    func reportGeometry() { web.evaluateJavaScript(geometryScript(), completionHandler: nil) }
    /// Keeps renderer coordinates in sync after a native move.
    func windowDidMove(_ notification: Notification) { reportGeometry() }
    /// Keeps renderer dimensions in sync after a native resize.
    func windowDidResize(_ notification: Notification) { reportGeometry() }
    /// Publishes the user's native minimize action through the authenticated bridge.
    func windowDidMiniaturize(_ notification: Notification) { reportGeometry() }
    /// Publishes native restoration without inferring state from focus or occlusion.
    func windowDidDeminiaturize(_ notification: Notification) { reportGeometry() }
    /// Ends this window's helper so Ruby's process monitor observes its closure.
    func windowWillClose(_ notification: Notification) { NSApplication.shared.terminate(nil) }
    /// Closes titled and borderless windows through the same Cmd-W or bridge action.
    @objc func closeWindow(_ sender: Any?) { window.close() }
    /// Ends the helper if its renderer dies instead of leaving an inert native window.
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { fail("WebKit content process ended") }
    /// Reports failed initial navigation without exposing its authenticated URL.
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        fail("WebUI navigation failed")
    }

    /// Presents JavaScript confirmation as a native sheet and returns the user's choice.
    /// Only the OK button resolves true; cancellation never implies consent.
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let alert = NSAlert()
        alert.messageText = message
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        alert.beginSheetModal(for: window) { response in completionHandler(response == .alertFirstButtonReturn) }
    }

    /// Installs editing and close shortcuts even when accessory mode hides the menu bar.
    func installMenu() {
        let menu = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit Lich WebUI Window", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        menu.addItem(appItem)
        let edit = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        let editMenu = NSMenu(title: "Edit")
        for (title, action, key) in [("Undo", "undo:", "z"), ("Cut", "cut:", "x"),
                                    ("Copy", "copy:", "c"), ("Paste", "paste:", "v"), ("Select All", "selectAll:", "a")] {
            editMenu.addItem(withTitle: title, action: Selector(action), keyEquivalent: key)
        }
        edit.submenu = editMenu
        menu.addItem(edit)
        let windows = NSMenuItem(title: "Window", action: nil, keyEquivalent: "")
        let windowMenu = NSMenu(title: "Window")
        let closeItem = windowMenu.addItem(withTitle: "Close", action: #selector(closeWindow(_:)), keyEquivalent: "w")
        closeItem.target = self
        windows.submenu = windowMenu
        menu.addItem(windows)
        NSApplication.shared.mainMenu = menu
    }

    /// Writes a sanitized diagnostic and terminates this helper.
    /// - Parameter message: Static context without URLs, page contents or raw errors.
    func fail(_ message: String) {
        // Never print authenticated URLs, page contents or navigation errors.
        fputs("Lich WebUI: \(message)\n", stderr)
        NSApplication.shared.terminate(nil)
    }
}

#if !WEBUI_HOST_TEST
@main
struct WebUIHostMain {
    static func main() {
        let arguments = CommandLine.arguments
        if arguments.count == 2 && arguments[1] == "--monitors" {
            if let data = try? JSONSerialization.data(withJSONObject: monitorSnapshot()),
               let json = String(data: data, encoding: .utf8) { print(json) }
            return
        }
        // The parent owns this private file until process exit; credentials never enter argv.
        guard arguments.count == 3,
              let launchURL = try? String(contentsOfFile: arguments[1], encoding: .utf8),
              let url = URL(string: launchURL), url.scheme == "http",
              ["127.0.0.1", "localhost", "::1"].contains(url.host ?? ""), url.port != nil,
              let data = arguments[2].data(using: .utf8),
              let geometry = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            fputs("Lich WebUI: expected a private loopback launch file and geometry\n", stderr)
            exit(1)
        }
        let app = NSApplication.shared
        let host = Host(url: url, geometry: geometry)
        app.delegate = host
        // Script windows are accessory panels, not separate Dock applications. The
        // menu still supplies keyboard equivalents even though no menu bar is shown.
        app.setActivationPolicy(.accessory)
        app.run()
    }
}
#endif
