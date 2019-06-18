//
//  Communicator.swift
//  CommunicateSwift
//
//  Created by Nicolas Degen on 18.06.19.
//  Copyright © 2019 Kapanu AG. All rights reserved.
//

import UIKit

public class Communicator {
  public static let shared = Communicator()
  
  private init() {}
  
  public func signIn() {
    guard let rootVC = UIApplication.shared.delegate?.window??.rootViewController else {
      return
    }
    let authVC = AuthenticationViewController()
    authVC.modalPresentationStyle = .formSheet
    rootVC.present(authVC, animated: true)
  }
  
  func requestToken(authCode: String, completion: @escaping (String)->()) {
    var req = URLRequest(url: Settings.shared.tokenRequestURL)
    
    let authValue = "\(Settings.shared.clientId):\(Settings.shared.clientSecret)"
    let authString = "Basic \(authValue.data(using: .utf8)!.base64EncodedString())"
    
    req.addValue(authString, forHTTPHeaderField: "Authorization")
    req.httpBody = "grant_type=authorization_code&redirect_uri=\(Settings.shared.redirectionURI)&code=\(authCode)&scope=offline_access".data(using: .utf8)
    req.httpMethod = "POST"
    
    
    let sesh = URLSession(configuration: URLSessionConfiguration.default)
    
    let task = sesh.dataTask(with: req, completionHandler: { (data, response, error) in
      if let data = data {
        do {
          guard let json = try JSONSerialization.jsonObject(with: data, options: [.allowFragments]) as? [String: Any] else {
            return
          }
          
          if let authenticationToken = json["access_token"] as? String {
            completion(authenticationToken)
            Settings.shared.authenticationToken = authenticationToken
          } else {
            print("Error")
          }
          if let validTime = json["expires_in"] as? Int {
            Settings.shared.tokenExpiration = Date(timeIntervalSinceNow: Double(validTime))
          } else {
            print("Error")
          }
          
        } catch {
          print("error")
        }
      }
    })
    task.resume()
  }
  
  func queryCurrentUserData(completion: @escaping ([String: Any])->()) {
    var req = URLRequest(url: URL(string: "https://users.3shapecommunicate.com/api/users/me")!)
    
    req.addValue("Bearer \(Settings.shared.authenticationToken)", forHTTPHeaderField: "Authorization")
    req.httpMethod = "GET"
    
    let sesh = URLSession(configuration: URLSessionConfiguration.default)
    let task = sesh.dataTask(with: req, completionHandler: { (data, response, error) in
      do {
        guard let json = try JSONSerialization.jsonObject(with: data!, options: [.allowFragments]) as? [String: Any] else {
          return
        }
        completion(json)
      } catch {
        return
      }
    })
    task.resume()
  }
}
