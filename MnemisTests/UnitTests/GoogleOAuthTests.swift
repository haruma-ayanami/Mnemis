import Foundation
import Testing
@testable import Mnemis

/// Проверки OAuth-потока Google: PKCE, адрес входа и проверка ответа (ABOUT.md, раздел 18).
struct GoogleOAuthTests {
    private let client = GoogleOAuthClient(clientID: "123-abc.apps.googleusercontent.com")

    @Test func pkceChallengeMatchesRFC7636Example() {
        // Пример из RFC 7636, приложение B.
        let codes = PKCECodes(verifier: "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk")
        #expect(codes.challenge == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
    }

    @Test func generatedVerifierIsBase64URLWithoutPadding() {
        let codes = PKCECodes.make()
        #expect(codes.verifier.count == 43)
        #expect(!codes.verifier.contains("+"))
        #expect(!codes.verifier.contains("/"))
        #expect(!codes.verifier.contains("="))
        #expect(codes.challenge.count == 43)
    }

    @Test func callbackSchemeIsReversedClientID() {
        #expect(client.callbackScheme == "com.googleusercontent.apps.123-abc")
        #expect(client.redirectURI == "com.googleusercontent.apps.123-abc:/oauth2redirect")
    }

    @Test func authorizationURLCarriesPKCEAndState() throws {
        let codes = PKCECodes(verifier: "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk")
        let url = client.authorizationURL(pkce: codes, state: "state-1")
        let items = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        let values = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })

        #expect(values["client_id"] == "123-abc.apps.googleusercontent.com")
        #expect(values["response_type"] == "code")
        #expect(values["code_challenge"] == codes.challenge)
        #expect(values["code_challenge_method"] == "S256")
        #expect(values["state"] == "state-1")
        #expect(values["scope"] == "openid email profile")
    }

    @Test func extractsCodeWhenStateMatches() throws {
        let callback = try #require(URL(string: "com.googleusercontent.apps.123-abc:/oauth2redirect?state=s1&code=c1"))
        #expect(try client.authorizationCode(from: callback, expectedState: "s1") == "c1")
    }

    @Test func rejectsCallbackWithForeignState() throws {
        let callback = try #require(URL(string: "com.googleusercontent.apps.123-abc:/oauth2redirect?state=other&code=c1"))
        #expect(throws: GoogleOAuthError.stateMismatch) {
            try client.authorizationCode(from: callback, expectedState: "s1")
        }
    }

    @Test func reportsProviderErrorBeforeStateCheck() throws {
        let callback = try #require(URL(string: "com.googleusercontent.apps.123-abc:/oauth2redirect?error=access_denied"))
        #expect(throws: GoogleOAuthError.providerRejected("access_denied")) {
            try client.authorizationCode(from: callback, expectedState: "s1")
        }
    }

    @Test func rejectsCallbackWithoutCode() throws {
        let callback = try #require(URL(string: "com.googleusercontent.apps.123-abc:/oauth2redirect?state=s1"))
        #expect(throws: GoogleOAuthError.missingCode) {
            try client.authorizationCode(from: callback, expectedState: "s1")
        }
    }
}
