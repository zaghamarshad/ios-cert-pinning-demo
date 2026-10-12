import Foundation

/// Example usage of the pinning delegate.
///
/// Replace the host and pin hash with your own values. See PinningConfig for
/// how to compute the hash with openssl.
public enum Demo {

    public static func fetchSecurely() async throws -> Data {
        let config = PinningConfig(pins: [
            "api.example.com": [
                "<base64-encoded SHA-256 of the server public key>",
            ]
        ])

        let delegate = PinnedSessionDelegate(config: config)
        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)

        guard let url = URL(string: "https://api.example.com/v1/status") else {
            throw URLError(.badURL)
        }
        let (data, _) = try await session.data(from: url)
        return data
    }

    /// Same request through a default session: works fine through a proxy
    /// with an installed CA. Compare with fetchSecurely(), which refuses it.
    public static func fetchWithoutPinning() async throws -> Data {
        let session = VulnerableSession.make()
        guard let url = URL(string: "https://api.example.com/v1/status") else {
            throw URLError(.badURL)
        }
        let (data, _) = try await session.data(from: url)
        return data
    }
}
