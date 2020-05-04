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
  let tokenRequestURL: URL =  URL(string: "https://identity.3shape.com/connect/token")!
  
  // TODO: Use Keychain for token storage
  var authenticationToken: String {
    set {
      UserDefaults.standard.set(newValue, forKey: "CommunicateAuthenticationToken")
    }

    get {
      return UserDefaults.standard.string(forKey: "CommunicateAuthenticationToken") ?? ""
    }
  }
  
  var baseMetaDataURL: String {
    set {
      UserDefaults.standard.set(newValue, forKey: "CommunicateMetaDataURL")
    }

    get {
      return UserDefaults.standard.string(forKey: "CommunicateMetaDataURL") ?? "https://eumetadata.3shapecommunicate.com"
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
