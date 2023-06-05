//
//  OAuthHelper.swift
//  OsmAnd Maps
//
//  Created by nnngrach on 15.05.2023.
//  Copyright © 2023 OsmAnd. All rights reserved.
//

// OAuth version: 2.0
// Grant type: Authorization code

import SwiftUI
import Foundation
import AuthenticationServices

@objc class OAuthHelper : NSObject {

    //Override in sublcasses
    internal class var authURL: String { return "" }
    internal class var accessTokenURL: String { return "" }
    internal class var clientID: String { return "" }
    internal class var clientSecret: String { return "" }
    internal class var redirectURI: String { return "" }
    internal class var urlScheme: String { return "" }
    internal class var scopes: [String] { return [] }
    internal class var tokenSettingsKey: String { return "" }

    @objc public static func getToken() -> String? {
        return UserDefaults.standard.string(forKey: tokenSettingsKey)
        // TODO: if now() > expirationTime then refreshExpiredToken()
    }
    
    public static func setToken(token: String?) {
        UserDefaults.standard.setValue(token, forKey: tokenSettingsKey)
    }
    
    @available(iOS 16.4, *)
    public static func performOAuth(session: WebAuthenticationSession) async -> String? {
        do {
            let accessCodeRequestURL = buildAccessCodeRequestURL()

            // Show SwiftUI web-view with OAuth. It return URL with access code on complete.
            // Like this: "example.com?code=1234"
            let onCompleteURL = try await session.authenticate(
                using: URL(string: accessCodeRequestURL)!,
                callbackURLScheme: urlScheme,
                preferredBrowserSession: .ephemeral
            )
            
            guard let accessCode = trimAccessCodeFrom(fullResponseURL: onCompleteURL.absoluteString) else {throw CustomError.error("No access code")}

            guard let tokenJson = try await fetchToken(accessCode: accessCode) else {throw CustomError.error("No parsed token json")}

            if (tokenJson.token != nil && tokenJson.token!.count > 0) {
                setToken(token: tokenJson.token!)
            } else {
                throw CustomError.error("No parsed token")
            }

            if (tokenJson.expirationTimestamp != nil && tokenJson.expirationTimestamp!.count > 0) {
                // TODO: save expirationTimestamp
            }

            await onComplete()

            return tokenJson.token
            
        } catch {
            print("performOAuth() Error: \(error)")
            return nil
        }
    }
    
    private static func buildFullReditectURI() -> String {
        return urlScheme + "://" + redirectURI
    }
    
    private static func buildAccessCodeRequestURL() -> String {
        var scopesString = ""
        for scope in scopes {
            scopesString += scope + "+"
        }
        if scopesString.hasSuffix("+") {
            scopesString.removeLast()
        }
        return authURL + "?response_type=code&client_id=" + clientID + "&scope=" + scopesString + "&redirect_uri=" + buildFullReditectURI()
    }
    
    private static func trimAccessCodeFrom(fullResponseURL: String) -> String? {
        let substrings = fullResponseURL.components(separatedBy: "code=")
        if (substrings.count > 1) {
            return substrings[1]
        }
        return nil
    }
    
    private static func fetchToken(accessCode: String) async throws -> ParsedTokenResponce? {
        guard let url = URL(string: accessTokenURL) else { return nil }
        let headers = ["content-type": "application/x-www-form-urlencoded"]
        let httpBodyData = "grant_type=authorization_code&code=" + accessCode + "&client_id=" + clientID + "&client_secret=" + clientSecret + "&redirect_uri=" + buildFullReditectURI()
        
        var request = URLRequest(url: url,
                                 cachePolicy: .useProtocolCachePolicy,
                                 timeoutInterval: 10.0)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = headers
        request.httpBody = Data(httpBodyData.utf8)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        return parseTokenJSON(data: data)
    }
    
    // Override in subclasses
    class func parseTokenJSON(data: Data) -> ParsedTokenResponce? {
        do {
            struct AccessTokenModel: Codable {
                var access_token: String?
            }
            let parsedJSON = try JSONDecoder().decode(AccessTokenModel.self, from: data)
            return (token: parsedJSON.access_token!, expirationTimestamp: nil)
        } catch {
            print("parseTokenJSON() Error: \(error)")
        }
        return nil
    }
    
    // Override in subclasses
    class func onComplete() async {
        //do nothing
    }

    
    public enum CustomError: Error {
        case error(String)
    }
    
    typealias ParsedTokenResponce = (token: String?, expirationTimestamp: String?)

}
