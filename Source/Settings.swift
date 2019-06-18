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
  
}
