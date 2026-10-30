import Foundation

/// A user gesture can leave WebUI only through the system browser. The source
/// must be the trusted main frame; the destination cannot reuse its host cookies.
enum ExternalLinks {
    static func permits(_ destination: URL?, source: URL?, launch: URL,
                        mainFrame: Bool, userActivated: Bool) -> Bool {
        guard mainFrame, userActivated, let source = source, let destination = destination,
              source.scheme == launch.scheme, source.host == launch.host, source.port == launch.port,
              ["http", "https"].contains(destination.scheme?.lowercased() ?? ""),
              let host = destination.host, !host.isEmpty,
              host.lowercased() != launch.host?.lowercased(),
              destination.user == nil, destination.password == nil else { return false }
        return true
    }
}
