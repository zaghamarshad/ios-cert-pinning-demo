# iOS Certificate Pinning Demo

A small Swift package showing TLS public-key pinning on iOS: the pinned version that rejects man-in-the-middle proxies, and the default version that does not.

## What certificate pinning is

Normally your app trusts any certificate the OS trusts. If someone installs their own CA on the device (or on a network the device uses), they can present a valid-looking certificate for your API and read or modify the traffic. This is exactly what security testers do with Burp Suite, and what attackers do with rogue Wi-Fi.

Certificate pinning fixes this by hard-coding which server keys your app accepts. Even with a trusted rogue CA on the device, the connection fails because the key does not match your pins.

## How the demo works

- `PinnedSessionDelegate` is a `URLSessionDelegate` that intercepts the server-trust challenge. It validates the certificate chain, then compares the SHA-256 hash of each public key in the chain against your pinned hashes. Match: the request proceeds. No match, or no pins for the host: the connection is cancelled. Unknown hosts fail closed on purpose.
- `PinningConfig` holds your pins: host names mapped to base64-encoded SHA-256 hashes of DER-encoded public keys. Pin at least two keys per host (current + backup kept offline).
- `VulnerableSession` builds a plain `URLSession` with default trust evaluation, for contrast.
- `Demo.swift` shows both in use with async/await.

The whole chain is checked, not just the leaf certificate, so you can pin an intermediate or root CA as your backup pin.

## How to run it

1. Open the package in Xcode 15+ (File > Open, select the folder).
2. Get your server's public-key pin:
   ```
   openssl s_client -connect api.example.com:443 -servername api.example.com 2>/dev/null \
     | openssl x509 -pubkey -noout \
     | openssl pkey -pubin -outform DER \
     | openssl dgst -sha256 -binary | base64
   ```
3. Put the host and hash into `Demo.fetchSecurely()` and call it from your app or a test target.

### Getting a backup pin from the intermediate CA

The leaf key changes on every certificate renewal, so a leaf-only pin means shipping an app update at each renewal. Pin the intermediate CA's public key as the backup: it survives renewals issued by the same CA.

1. Save the server's certificate chain:
   ```
   openssl s_client -connect api.example.com:443 -servername api.example.com -showcerts </dev/null 2>/dev/null > chain.pem
   ```
2. Open `chain.pem` and copy the SECOND `-----BEGIN CERTIFICATE-----` block into a new file called `intermediate.pem`.
3. Hash its public key with the same pipeline:
   ```
   openssl x509 -in intermediate.pem -pubkey -noout \
     | openssl pkey -pubin -outform DER \
     | openssl dgst -sha256 -binary | base64
   ```
4. Add that hash to `PinningConfig` next to the leaf pin, so every host has at least two pins.

## Try it yourself

1. Install Burp Suite's CA certificate on a test iPhone.
2. Point the phone's Wi-Fi proxy at Burp.
3. Call `Demo.fetchWithoutPinning()`: the request succeeds and you see the traffic in Burp.
4. Call `Demo.fetchSecurely()` with correct pins: the request fails with a cancelled authentication challenge, and Burp sees nothing usable. That is pinning doing its job.

## Tradeoffs to know

- **Pin rotation.** If you pin one key and it gets replaced (key compromise, CA change), every installed app breaks until users update. Always ship a backup pin.
- **Pinning is defense in depth.** It does not replace proper TLS validation; this delegate still evaluates the chain first. It also does not stop an attacker who controls the device itself (jailbreak + SSL kill switch tools bypass pinning at runtime).
- **Where to pin.** Pin your sensitive endpoints (auth, payments, PII). Pinning every third-party SDK domain creates maintenance work for little gain.
- **Leaf vs CA pinning.** Pinning the leaf key is strictest but breaks on every cert renewal. Pinning the public key (which survives renewals from the same CA) or an intermediate CA is the usual balance. This demo pins public keys for that reason.
- **Fail closed, and log the failure.** This demo cancels the connection on a mismatch. In a real app, log the host and the hash that was presented, with no user data attached, so a bad pin rotation shows up in your reports instead of arriving as silent support tickets.
- **Test pins before release.** Check a new pin set against a staging host first, and confirm both the current pin and the backup pin are in the build before shipping. A pin set tested only in production can lock every user out at once.
- **One pin set per host.** Keep pins scoped to the host they were taken from. Copying another host's pin set into a new host entry will make valid connections fail, and it hides which host is missing a backup pin.
