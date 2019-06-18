//
//  Communicator.swift
//  CommunicateSwift
//
//  Created by Nicolas Degen on 18.06.19.
//  Copyright © 2019 Kapanu AG. All rights reserved.
//

import UIKit

public struct CommunicateStatus {
  let message: String
}

public protocol CommunicateObserver: class {
  func didSignIn()
  func didSignOut()
}

extension CommunicateObserver {
  func didSignIn() {}
  func didSignOut() {}
}


public class Communicator {
  public static let shared = Communicator()
  
  private init() {}
  
  private struct CommunicateObservable {
    weak var observer: CommunicateObserver?
  }
  
  private var observers = [ObjectIdentifier : CommunicateObservable]()
  
  public func addObserver(_ observer: CommunicateObserver) {
    let id = ObjectIdentifier(observer)
    observers[id] = CommunicateObservable(observer: observer)
  }
  private let authVC = AuthenticationViewController()
  
  @objc func dismissAuthenticationVC() {
    authVC.dismiss(animated: true)
  }
  
  public func signIn(completion: ((CommunicateStatus)->())? = nil) {
    if Settings.shared.isSignedIn {
      print(Settings.shared.authenticationToken)
      completion?(CommunicateStatus.init(message: "AlreadySignedIn"))
      return
    }
    guard let rootVC = UIApplication.shared.delegate?.window??.rootViewController else {
      completion?(CommunicateStatus.init(message: "Error"))
      return
    }
    authVC.completionCallback = completion
    let navVC = UINavigationController(rootViewController: authVC)
    navVC.modalPresentationStyle = .formSheet
    
    authVC.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(dismissAuthenticationVC))
    rootVC.present(navVC, animated: true)
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
          
          if let authenticationToken = json["access_token"] as? String, let validTime = json["expires_in"] as? Int {
            completion(authenticationToken)
            Settings.shared.authenticationToken = authenticationToken
            Settings.shared.tokenExpiration = Date(timeIntervalSinceNow: Double(validTime))
            for (_, observable) in self.observers {
              observable.observer?.didSignIn()
            }
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
  
  public func queryCurrentUserData(completion: @escaping (CommunicateUser)->()) {
    var req = URLRequest(url: URL(string: "https://users.3shapecommunicate.com/api/users/me")!)
    
    req.addValue("Bearer \(Settings.shared.authenticationToken)", forHTTPHeaderField: "Authorization")
    req.httpMethod = "GET"
    
    let sesh = URLSession(configuration: URLSessionConfiguration.default)
    let task = sesh.dataTask(with: req, completionHandler: { (data, response, error) in
      
      guard let data = data else {
        return
      }
      
      do {
        let user = try JSONDecoder().decode(CommunicateUser.self, from: data)
        completion(user)
        return
      } catch {
        print("Unexpected error: \(error).")
        return
      }
    })
    task.resume()
  }
}
