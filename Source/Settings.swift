//
//  Settings.swift
//  CommunicateSwift
//
//  Created by Nicolas Degen on 17.06.19.
//  Copyright © 2019 Kapanu AG. All rights reserved.
//

import Foundation

public class Settings {
  public static let shared = Settings()
  
  private init() {}
  
  public var redirectionURI: String = ""
  public var clientId: String = ""
  public var clientSecret: String = ""
  public let tokenRequestURL: URL =  URL(string: "https://identity.3shape.com/connect/token")!
  // TODO: Use Keychain for token storage
  public var authenticationToken: String {
    set {
      UserDefaults.standard.set(newValue, forKey: "CommunicateAuthenticationToken")
    }

    get {
      return UserDefaults.standard.string(forKey: "CommunicateAuthenticationToken") ?? ""
    }
  }
  
  public var tokenExpiration: Date {
    set {
      UserDefaults.standard.set(newValue, forKey: "CommunicateAuthenticationTokenExpiration")
    }
    
    get {
      return UserDefaults.standard.object(forKey: "CommunicateAuthenticationTokenExpiration") as? Date ?? Date()
    }
  }
  
}
