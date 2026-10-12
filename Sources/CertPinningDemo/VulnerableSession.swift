import Foundation

/// The default behavior, shown for contrast.
///
/// A plain URLSession trusts whatever the OS trusts. On a test device with a
/// proxy CA installed (Burp's CA, for example), traffic flows through the
/// proxy with no complaint from the app. That is convenient for debugging and
/// wrong for release builds talking to sensitive endpoints.
public enum VulnerableSession {

    /// A session with default trust evaluation: no pinning at all.
    public static func make() -> URLSession {
        URLSession(configuration: .default)
    }
}
