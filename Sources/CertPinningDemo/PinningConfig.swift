import Foundation

/// Holds the pinned public-key hashes, keyed by host.
///
/// Each hash is the base64-encoded SHA-256 of the DER-encoded public key.
/// Get one for your server with:
///
///     openssl s_client -connect api.example.com:443 -servername api.example.com 2>/dev/null \
///       | openssl x509 -pubkey -noout \
///       | openssl pkey -pubin -outform DER \
///       | openssl dgst -sha256 -binary | base64
///
/// Pin at least two hashes per host: your current key and a backup key kept
/// offline. If you only pin one key and it gets replaced, every installed app
/// breaks until users update.
public struct PinningConfig {

    private let pins: [String: Set<Data>]

    /// - Parameter pins: host names mapped to lists of base64-encoded
    ///   SHA-256 public-key hashes.
    public init(pins: [String: [String]]) {
        var decoded: [String: Set<Data>] = [:]
        for (host, hashes) in pins {
            let valid = hashes.compactMap { Data(base64Encoded: $0) }
            if !valid.isEmpty {
                decoded[host] = Set(valid)
            }
        }
        self.pins = decoded
    }

    /// Returns the pinned key hashes for a host, or nil when the host has no
    /// pins (or its pins failed to decode).
    func pinnedKeyHashes(for host: String) -> Set<Data>? {
        pins[host]
    }
}
