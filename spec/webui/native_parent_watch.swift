import AppKit
import Foundation

// Compile with Host.swift, ExternalLinks.swift and -DWEBUI_HOST_TEST.
// Checks that the helper's parent watch fires when the watched process exits
// (including SIGKILL), when the live parent identity changes, and when the
// helper starts already orphaned.
func waitFor(_ label: String, seconds: TimeInterval, _ done: () -> Bool) {
    let limit = Date().addingTimeInterval(seconds)
    while !done() {
        if Date() > limit {
            fputs("Parent watch timed out: \(label)\n", stderr)
            exit(1)
        }
        RunLoop.main.run(until: Date().addingTimeInterval(0.02))
    }
}

@main
struct ParentWatchChecks {
    static func main() {
        let child = Process()
        child.executableURL = URL(fileURLWithPath: "/bin/sleep")
        child.arguments = ["30"]
        do { try child.run() } catch {
            fputs("Could not start the watched process\n", stderr)
            exit(1)
        }
        var exitCount = 0
        let pid = child.processIdentifier
        let killed = ParentWatch(parent: pid, currentParent: { pid }) { exitCount += 1 }
        killed.start(interval: .seconds(60))
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        if exitCount != 0 {
            fputs("Parent watch fired while the parent was alive\n", stderr)
            exit(1)
        }
        kill(pid, SIGKILL)
        waitFor("SIGKILL exit event", seconds: 5) { exitCount == 1 }
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        if exitCount != 1 {
            fputs("Parent watch fired \(exitCount) times\n", stderr)
            exit(1)
        }

        var reparented = 0
        let changed = ParentWatch(parent: getpid(), currentParent: { 1 }) { reparented += 1 }
        changed.start(interval: .milliseconds(50))
        waitFor("changed parent identity", seconds: 5) { reparented == 1 }

        var orphaned = 0
        let orphan = ParentWatch(parent: 1) { orphaned += 1 }
        orphan.start()
        waitFor("launchd parent at startup", seconds: 5) { orphaned == 1 }
        withExtendedLifetime([killed, changed, orphan]) {}
        print("parent watch ready")
    }
}
