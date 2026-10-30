import AppKit
import WebKit

// Compile with Host.swift, ExternalLinks.swift and -DWEBUI_HOST_TEST.
// Observe native transitions without polling or waking the hidden WebView.
final class PresentationChecks: NSObject, NSApplicationDelegate {
    let host: Host
    let steps: [String]
    var next = 0
    var titleObservation: NSKeyValueObservation?
    var observations: [NSObjectProtocol] = []

    init(url: URL, steps: [String]) {
        host = Host(url: url, geometry: ["width": 320, "height": 200])
        self.steps = steps
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        host.applicationDidFinishLaunching(notification)
        titleObservation = host.window.observe(\.title) { [weak self] _, _ in
            DispatchQueue.main.async { self?.check() }
        }
        for name in [NSWindow.didChangeOcclusionStateNotification,
                     NSWindow.didMiniaturizeNotification, NSWindow.didDeminiaturizeNotification] {
            observations.append(NotificationCenter.default.addObserver(forName: name,
                object: host.window, queue: .main) { [weak self] _ in self?.check() })
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 60) { [self] in
            fputs("Native presentation timed out at \(steps[next]); title=\(host.window.title), visible=\(host.window.isVisible), minimized=\(host.window.isMiniaturized)\n", stderr)
            exit(1)
        }
    }

    func check() {
        guard next < steps.count, host.window.title == "phase-\(next)" else { return }
        let window = host.window!
        let state = steps[next]
        let matches = state == "hidden" ? !window.isVisible && !window.isMiniaturized
            : state == "minimized" ? window.isMiniaturized
            : window.isVisible && !window.isMiniaturized
        guard matches else { return }
        print("Verified \(state) at phase \(next)")
        fflush(stdout)
        next += 1
        if next == steps.count { exit(0) }
    }
}

@main
struct NativePresentationChecks {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let checks = PresentationChecks(url: URL(string: CommandLine.arguments[1])!,
            steps: CommandLine.arguments[2].split(separator: ",").map(String.init))
        app.delegate = checks
        withExtendedLifetime(checks) { app.run() }
    }
}
