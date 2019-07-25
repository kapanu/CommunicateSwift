//
//  Communicator.swift
//  CommunicateSwift
//
//  Created by Nicolas Degen on 18.06.19.
//  Copyright © 2019 Kapanu AG. All rights reserved.
//

import UIKit

public enum CommunicateStatus {
  case error
  case signedIn
  case signedOut
  case undefined
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
  private var authVC = AuthenticationViewController()
  
  @objc func dismissAuthenticationVC() {
    authVC.dismiss(animated: true)
  }
  
  public func signIn(vc:UIViewController? = nil, completion: ((CommunicateStatus)->())? = nil) {
    authVC = AuthenticationViewController()
    if Settings.shared.isSignedIn {
      print(Settings.shared.authenticationToken)
      completion?(.signedIn)
      return
    }
    var rootVC: UIViewController!
    if (vc != nil) {
      rootVC = vc!
    } else {
      if (UIApplication.shared.delegate?.window??.rootViewController != nil) {
        rootVC = UIApplication.shared.delegate?.window??.rootViewController!
      } else {
        completion?(.error)
        return
      }
    }
    authVC.completionCallback = completion
    let navVC = UINavigationController(rootViewController: authVC)
    navVC.modalPresentationStyle = .formSheet
    
    authVC.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(dismissAuthenticationVC))
    rootVC.present(navVC, animated: true)
  }
  
  var authenticationString: String {
    let authValue = "\(Settings.shared.clientId):\(Settings.shared.clientSecret)"
    return "Basic \(authValue.data(using: .utf8)!.base64EncodedString())"
  }
  
  func requestToken(authCode: String, completion: @escaping (CommunicateStatus)->()) {
    var req = URLRequest(url: Settings.shared.tokenRequestURL)
    
    req.addValue(authenticationString, forHTTPHeaderField: "Authorization")
    req.httpBody = "grant_type=authorization_code&redirect_uri=\(Settings.shared.redirectionURI)&code=\(authCode)&scope=offline_access".data(using: .utf8)
    req.httpMethod = "POST"
    
    
    let sesh = URLSession(configuration: URLSessionConfiguration.default)
    
    let task = sesh.dataTask(with: req, completionHandler: { (data, response, error) in
      
      if let error = error {
        print(error.localizedDescription)
        completion(.error)
        return
      }
      
      if let data = data {
        do {
          guard let json = try JSONSerialization.jsonObject(with: data, options: [.allowFragments]) as? [String: Any] else {
            return
          }
          
          if let authenticationToken = json["access_token"] as? String, let validTime = json["expires_in"] as? Int,
             let refreshToken = json["refresh_token"] as? String {
            completion(.signedIn)
            Settings.shared.authenticationToken = authenticationToken
            Settings.shared.refreshToken = refreshToken
            Settings.shared.tokenExpiration = Date(timeIntervalSinceNow: Double(validTime))
            for (_, observable) in self.observers {
              observable.observer?.didSignIn()
            }
          } else {
            print("Error")
          }
          
        } catch {
          print("Error")
        }
      }
    })
    task.resume()
  }
  
  func refreshToken(completion: @escaping (CommunicateStatus)->()) {
    var req = URLRequest(url: Settings.shared.tokenRequestURL)
    
    req.addValue(authenticationString, forHTTPHeaderField: "Authorization")

    req.httpBody = "grant_type=refresh_token&refresh_token=\(Settings.shared.refreshToken)&redirect_uri=\(Settings.shared.redirectionURI)&scope=offline_access".data(using: .utf8)
    req.httpMethod = "POST"
    
    print(Settings.shared.authenticationToken)
    print(Settings.shared.refreshToken)
    
    let sesh = URLSession(configuration: URLSessionConfiguration.default)
    
    let task = sesh.dataTask(with: req, completionHandler: { (data, response, error) in
      
      if let error = error {
        print(error.localizedDescription)
        completion(.error)
        return
      }
      
      if let data = data {
        do {
          guard let json = try JSONSerialization.jsonObject(with: data, options: [.allowFragments]) as? [String: Any] else {
            return
          }
          
          if let authenticationToken = json["access_token"] as? String,
            let validTime = json["expires_in"] as? Int,
            let refreshToken = json["refresh_token"] as? String {
            completion(.signedIn)
            
            Settings.shared.authenticationToken = authenticationToken
            Settings.shared.authenticationToken = refreshToken
            Settings.shared.tokenExpiration = Date(timeIntervalSinceNow: Double(validTime))
            for (_, observable) in self.observers {
              observable.observer?.didSignIn()
            }
          } else {
            print(json["error"] as? String ?? "Error")
            completion(.error)
          }
          
        } catch {
          print("Error: could not parse json")
          completion(.error)
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