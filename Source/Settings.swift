//
//  Settings.swift
//  CommunicateSwift
//
//  Created by Nicolas Degen on 17.06.19.
//  Copyright © 2019 Kapanu AG. All rights reserved.
//

import Foundation

class Settings {
  static let shared = Settings()
  
  private init() {}
  
  var redirectionURI: String = ""
  var clientId: String = ""
  var clientSecret: String = ""
  var tokenRequestURL: URL {
    if clientSecret == "hXzoGXVDsU1yh7J7HYNR" {
      return URL(string: "https://staging-identity.3shape.com/connect/token")!
    }
    return URL(string: "https://identity.3shape.com/connect/token")!
  }
  var identityURL: URL {
    // Check if we are using a staging identity. This is a hack as there could also be other client Secrets that are from a staging identity
    // Staging identity is meaning that this accoutn is not on the live server but on the test server (staging-identity)
    if clientSecret == "hXzoGXVDsU1yh7J7HYNR" {
      return URL(string: "https://staging-identity.3shape.com/connect/authorize?client_id=\(clientId)&response_type=code&scope=offline_access&redirect_uri=\(redirectionURI)")!
    }
    return URL(string: "https://identity.3shape.com/connect/authorize?client_id=\(clientId)&response_type=code&scope=offline_access&redirect_uri=\(redirectionURI)")!
  }
  
  // TODO: Use Keychain for token storage
  var authenticationToken: String {
    set {
      UserDefaults.standard.set(newValue, forKey: "CommunicateAuthenticationToken")
    }

    get {
      return UserDefaults.standard.string(forKey: "CommunicateAuthenticationToken") ?? ""
    }
  }
  
  var refreshToken: String {
    set {
      UserDefaults.standard.set(newValue, forKey: "CommunicateRefreshToken")
    }
    
    get {
      return UserDefaults.standard.string(forKey: "CommunicateRefreshToken") ?? ""
    }
  }
  
  var isSignedIn: Bool {
    return tokenExpiration.timeIntervalSinceNow > 0
  }
  
  var tokenExpiration: Date {
    set {
      UserDefaults.standard.set(newValue, forKey: "CommunicateAuthenticationTokenExpiration")
    }
    
    get {
      return UserDefaults.standard.object(forKey: "CommunicateAuthenticationTokenExpiration") as? Date ?? Date()
    }
  }
  
}
