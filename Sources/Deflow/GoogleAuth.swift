import AppKit
import AuthenticationServices
import CryptoKit
import Foundation
import Security

/// Google OAuth as a public client: PKCE + a custom-scheme redirect, so the app ships no client secret.
/// Only the refresh token is stored, in the login Keychain.
@MainActor
final class GoogleAuth: NSObject, ASWebAuthenticationPresentationContextProviding {
    enum Failure: LocalizedError {
        case signedOut, denied(String), server(String)

        var errorDescription: String? {
            switch self {
            case .signedOut: "Google sign-in expired. Connect again."
            case .denied(let why): "Google sign-in was not completed (\(why))."
            case .server(let why): why
            }
        }
    }

    /// iOS-type OAuth client (bundle ID dev.deflow.app). Public by design: it has no secret.
    static let clientID = "514507253900-1qdksnfaeilb3ofjvebfj135l28s2th6.apps.googleusercontent.com"
    static let scope = "https://www.googleapis.com/auth/calendar.readonly"
    static let scheme = "com.googleusercontent.apps."
        + clientID.replacingOccurrences(of: ".apps.googleusercontent.com", with: "")
    static let redirect = "\(scheme):/oauth2redirect"

    private var refreshToken: String? = Keychain.load() {
        didSet { Keychain.save(refreshToken) }
    }
    private var access: (token: String, expires: Date)?
    private var session: ASWebAuthenticationSession?
    private lazy var anchor = NSWindow()

    var isSignedIn: Bool { refreshToken != nil }

    func signOut() {
        refreshToken = nil
        access = nil
    }

    func signIn() async throws {
        let verifier = Self.randomToken()
        let state = Self.randomToken()
        let challenge = Data(SHA256.hash(data: Data(verifier.utf8))).base64URL

        var c = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        c.queryItems = [
            .init(name: "client_id", value: Self.clientID),
            .init(name: "redirect_uri", value: Self.redirect),
            .init(name: "response_type", value: "code"),
            .init(name: "scope", value: Self.scope),
            .init(name: "code_challenge", value: challenge),
            .init(name: "code_challenge_method", value: "S256"),
            .init(name: "state", value: state),
        ]

        let callback = try await authorize(c.url!)
        let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let params = Dictionary(items.compactMap { i in i.value.map { (i.name, $0) } }) { a, _ in a }
        guard params["state"] == state else { throw Failure.denied("state mismatch") }
        guard let code = params["code"] else { throw Failure.denied(params["error"] ?? "no code") }

        let token = try await tokenRequest([
            "grant_type": "authorization_code",
            "code": code,
            "code_verifier": verifier,
            "redirect_uri": Self.redirect,
            "client_id": Self.clientID,
        ])
        guard let refresh = token.refresh_token else { throw Failure.server("Google returned no refresh token.") }
        refreshToken = refresh
        remember(token)
    }

    /// A valid access token, refreshed when needed.
    func accessToken() async throws -> String {
        if let access, access.expires > Date().addingTimeInterval(60) { return access.token }
        guard let refreshToken else { throw Failure.signedOut }
        let token = try await tokenRequest([
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": Self.clientID,
        ])
        remember(token)
        return token.access_token ?? ""
    }

    func invalidateAccessToken() { access = nil }

    // MARK: - Internals

    /// Shows the system sign-in sheet and returns the redirect URL Google sends back.
    private func authorize(_ url: URL) async throws -> URL {
        session?.cancel()
        return try await withCheckedThrowingContinuation { cont in
            let session = ASWebAuthenticationSession(url: url, callback: .customScheme(Self.scheme)) { url, error in
                if let url {
                    cont.resume(returning: url)
                } else {
                    let cancelled = (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin
                    cont.resume(throwing: Failure.denied(cancelled ? "cancelled" : error?.localizedDescription ?? "unknown"))
                }
            }
            session.presentationContextProvider = self
            self.session = session
            NSApp.activate(ignoringOtherApps: true)
            if !session.start() {
                cont.resume(throwing: Failure.denied("could not open the sign-in window"))
            }
        }
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        NSApp.keyWindow ?? anchor
    }

    private struct TokenResponse: Decodable {
        let access_token: String?
        let expires_in: Double?
        let refresh_token: String?
        let error: String?
        let error_description: String?
    }

    private func remember(_ t: TokenResponse) {
        guard let token = t.access_token else { return }
        access = (token, Date().addingTimeInterval(t.expires_in ?? 3000))
    }

    private func tokenRequest(_ form: [String: String]) async throws -> TokenResponse {
        var req = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let unreserved = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
        req.httpBody = form
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: unreserved) ?? "")" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, _) = try await URLSession.shared.data(for: req)
        guard let t = try? JSONDecoder().decode(TokenResponse.self, from: data) else {
            throw Failure.server("Unreadable response from Google's token endpoint.")
        }
        if let error = t.error {
            if error == "invalid_grant" {   // refresh token revoked or expired
                signOut()
                throw Failure.signedOut
            }
            throw Failure.server(t.error_description ?? error)
        }
        guard t.access_token != nil else { throw Failure.server("Google returned no access token.") }
        return t
    }

    private static func randomToken() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64URL
    }
}

private extension Data {
    var base64URL: String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

private enum Keychain {
    private static func query(_ account: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: "dev.deflow.app",
         kSecAttrAccount as String: account]
    }
    private static let account = "google-refresh-token"

    static func load() -> String? {
        // Earlier builds kept a Desktop OAuth client (with its secret) here; it is no longer used.
        SecItemDelete(query("google-oauth") as CFDictionary)
        var q = query(account)
        q[kSecReturnData as String] = true
        var out: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let data = out as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func save(_ value: String?) {
        SecItemDelete(query(account) as CFDictionary)
        guard let value else { return }
        var q = query(account)
        q[kSecValueData as String] = Data(value.utf8)
        SecItemAdd(q as CFDictionary, nil)
    }
}
