import Foundation

// Compile with ExternalLinks.swift. No browser, credentials or network is used.
@main
struct NativeLinkPolicyChecks {
    static func main() {
        let origin = URL(string: "http://127.0.0.1:8080/")!
        let external = URL(string: "https://example.org/help")!
        func allowed(_ url: URL?, source: URL? = origin, main: Bool = true, gesture: Bool = true) -> Bool {
            ExternalLinks.permits(url, source: source, launch: origin, mainFrame: main, userActivated: gesture)
        }
        precondition(allowed(external))
        precondition(allowed(URL(string: "http://example.org/help")))
        precondition(!allowed(external, source: URL(string: "http://127.0.0.1:9090/")))
        precondition(!allowed(external, source: nil))
        precondition(!allowed(external, main: false))
        precondition(!allowed(external, gesture: false))
        for text in ["http://127.0.0.1:9090/help", "https://127.0.0.1/help",
                     "javascript:alert(1)", "file:///tmp/test", "https://user:pass@example.org/help"] {
            precondition(!allowed(URL(string: text)))
        }
        precondition(!allowed(nil))
        print("Native link policy: 12 checks passed")
    }
}
