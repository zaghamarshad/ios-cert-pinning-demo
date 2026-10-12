import Foundation
import Security
import CryptoKit

/// URLSessionDelegate that enforces TLS public-key pinning.
///
/// For every host in the config, the server's public key must match one of
/// the pinned SHA-256 hashes. Anything else is rejected. This stops
/// man-in-the-middle proxies (Burp, mitmproxy) that present their own
/// certificate, even when their CA is installed on the device.
///
/// Unknown hosts fail closed: if a host has no pins configured, the
/// connection is refused rather than silently falling back to default trust.
public final class PinnedSessionDelegate: NSObject, URLSessionDelegate {

    private let config: PinningConfig

    public init(config: PinningConfig) {
        self.config = config
    }

    public func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            // Not a server-trust challenge: refuse it.
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // Basic chain validation first: expiry, hostname, chain of trust.
        var evalError: CFError?
        guard SecTrustEvaluateWithError(serverTrust, &evalError) else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        let host = challenge.protectionSpace.host
        guard let pinnedHashes = config.pinnedKeyHashes(for: host) else {
            // No pins for this host: fail closed, never fall back silently.
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        if publicKeyMatchesPin(in: serverTrust, pinnedHashes: pinnedHashes) {
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }

    /// Returns true when any certificate in the chain has a public key whose
    /// SHA-256 hash matches a pinned hash. The whole chain is checked, not
    /// just the leaf, so you can pin an intermediate or root CA as a backup.
    private func publicKeyMatchesPin(in trust: SecTrust, pinnedHashes: Set<Data>) -> Bool {
        guard let chain = SecTrustCopyCertificateChain(trust) as? [SecCertificate] else {
            return false
        }
        for certificate in chain {
            guard let publicKey = SecCertificateCopyKey(certificate),
                  let keyData = SecKeyCopyExternalRepresentation(publicKey, nil) as Data? else {
                continue
            }
            let hash = Data(SHA256.hash(data: keyData))
            if pinnedHashes.contains(hash) {
                return true
            }
        }
        return false
    }
}
