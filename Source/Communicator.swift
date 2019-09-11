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

public enum CommunicatorError: Error {
  case invalidResponse
}

public class Communicator {
  public static let shared = Communicator()
  
  public var baseMetadataURL = "https://eumetadata.3shapecommunicate.com"
  
  private init() {}
  
  private struct CommunicateObservable {
    weak var observer: CommunicateObserver?
  }
  
  public var redirectionURI: String {
    set {
      Settings.shared.redirectionURI = newValue
    }
    get {
      return Settings.shared.redirectionURI
    }
  }
  
  public var clientId: String {
    set {
      Settings.shared.clientId = newValue
    }
    get {
      return Settings.shared.clientId
    }
  }
  
  public var clientSecret: String {
    set {
      Settings.shared.clientSecret = newValue
    }
    get {
      return Settings.shared.clientSecret
    }
  }
  
  public var isSignedIn: Bool { return Settings.shared.isSignedIn }
  
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
      //      print(Settings.shared.authenticationToken)
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
  
  func requestToken(authCode: String, completion: @escaping (CommunicateStatus)->()) {
    var req = URLRequest(url: Settings.shared.tokenRequestURL)
    req.addBasicAuthorization()
    req.httpBody = "grant_type=authorization_code&redirect_uri=\(Settings.shared.redirectionURI)&code=\(authCode)&scope=offline_access".data(using: .utf8)
    req.httpMethod = "POST"
    
    let task = URLSession.shared.dataTask(with: req, completionHandler: { (data, response, error) in
      
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
  
  public func logout() {
    Settings.shared.refreshToken = ""
    Settings.shared.authenticationToken = ""
    Settings.shared.tokenExpiration = Date()
  }

  
  public func refreshToken(completion: @escaping (CommunicateStatus)->()) {
    var req = URLRequest(url: Settings.shared.tokenRequestURL)
    
    req.addBasicAuthorization()
    
    req.httpBody = "grant_type=refresh_token&refresh_token=\(Settings.shared.refreshToken)&redirect_uri=\(Settings.shared.redirectionURI)&scope=offline_access".data(using: .utf8)
    req.httpMethod = "POST"
    
    let task = URLSession.shared.dataTask(with: req, completionHandler: { (data, response, error) in
      
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
            
            Settings.shared.authenticationToken = authenticationToken
            Settings.shared.refreshToken = refreshToken
            Settings.shared.tokenExpiration = Date(timeIntervalSinceNow: Double(validTime))
            completion(.signedIn)
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
    
    req.addAccessTokenAuthorization()
    
    let task = URLSession.shared.dataTask(with: req, completionHandler: { (data, response, error) in
      
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
  
  /// Retireves all Cases that are available for the logged in user
  public func retrieveCases(completion: @escaping (Result<[CommunicateCase], Error>)->()) {
 
    var req = URLRequest(url: URL(string: baseMetadataURL + "/api/cases")!)
    req.addAccessTokenAuthorization()
    req.httpMethod = "GET"
    
    let task = URLSession.shared.dataTask(with: req, completionHandler: { (data, response, error) in
      if let err = error {
        err.localizedDescription
        guard let resp = response as? HTTPURLResponse else { return }
        if resp.statusCode == 401 {
          self.signIn(vc: nil, completion: { status in
            if status == .signedIn {
              self.retrieveCases(completion: completion)
            } else {
              completion(.failure(err))
            }
          })
        }
//        do {
//          let jsonData = try JSONSerialization.data(withJSONObject: casesArray, options: [])
//
//        } catch {
//          
//        }

      }
      guard let data = data, let json = try? JSONSerialization.jsonObject(with: data, options: []) as? NSDictionary, let casesArray = json["Cases"] as? NSArray  else {
        return completion(.failure(CommunicatorError.invalidResponse))
      }
      
      do {
        let jsonData = try JSONSerialization.data(withJSONObject: casesArray, options: [])        
        let cases = try jsonData.decodeCommunicateCase()
        completion(.success(cases))
        
      } catch {
        print("Unexpected error: \(error).")
        return completion(.failure(error))
      }
    })
    task.resume()
  }
  
  public func downloadAttachments(ofCase cCase: CommunicateCase, toDirectoryURL path:URL, completion: @escaping (Bool)->()) {
    let taskGroup = DispatchGroup()
    var successfullyDownloadedAll = true
    for attachement in cCase.attachments {
      taskGroup.enter()
      download(resource: attachement.href) { data in
        // here the extension is added again though it's already appended to the name
        // let fileURL = path.appendingPathComponent(attachement.name).appendingPathExtension(attachement.fileType)
        let fileURL = path.appendingPathComponent(attachement.name)
        // TODO: remove debug messages in a later commit
        print("--- resource: attachement.href = ", attachement.href.absoluteString)
        print("--- downloadAttachments: fileURL = ", fileURL.path)
        do {
          try data?.write(to: fileURL)
          taskGroup.leave()
        } catch {
          successfullyDownloadedAll = false
          taskGroup.leave()
        }
      }
    }
    taskGroup.notify(queue: DispatchQueue.main, work: DispatchWorkItem(block: {
      completion(successfullyDownloadedAll)
    }))
  }
  
  public func downloadAttachments(ofCase cCase: CommunicateCase, toDirectoryURL path:URL,
                                  completeOne: @escaping ()->(), completion: @escaping (Bool)->()) {
    let taskGroup = DispatchGroup()
    var successfullyDownloadedAll = true
    for attachement in cCase.attachments {
      taskGroup.enter()
      download(resource: attachement.href) { data in
        // here the extension is added again though it's already appended to the name
        // let fileURL = path.appendingPathComponent(attachement.name).appendingPathExtension(attachement.fileType)
        let fileURL = path.appendingPathComponent(attachement.name)
        // TODO: remove debug messages in a later commit
        print("--- resource: attachement.href = ", attachement.href.absoluteString)
        print("--- downloadAttachments: fileURL = ", fileURL.path)
        do {
          try data?.write(to: fileURL)
          completeOne()
          taskGroup.leave()
        } catch {
          successfullyDownloadedAll = false
          taskGroup.leave()
        }
      }
    }
    taskGroup.notify(queue: DispatchQueue.main, work: DispatchWorkItem(block: {
      completion(successfullyDownloadedAll)
    }))
  }
  
  public func download(resource: URL, completion: @escaping (Data?)->()) {
    var req = URLRequest(url:resource)
    req.addAccessTokenAuthorization()
    req.httpMethod = "GET"
    
    let task = URLSession.shared.dataTask(with: req) { (data, response, error) in
      completion(data)
    }
    task.resume()
  }
  
  public func download(resource: URL, toPath path:URL, completion: @escaping (URL?)->()) {
    var req = URLRequest(url:resource)
    req.addAccessTokenAuthorization()
    req.httpMethod = "GET"
    
    let task = URLSession.shared.downloadTask(with: req) { (storedURL, response, error) in
      completion(storedURL)
    }
    task.resume()
  }
  
  public func getCaseModel(forCase cCase: CommunicateCase, completion: @escaping (CommunicateCaseModel?)->()) {
    guard let caseModelAttachement = (cCase.attachments.first {$0.name == "TreatmentSimulation-IvoSmile.json"}) else {
      completion(nil)
      return
    }
    var req = URLRequest(url: caseModelAttachement.href)
    // TODO: remove debug messages in a later commit
    print("--- caseModelAttachement.name: ", caseModelAttachement.name)
    print("--- getCaseModel: caseModelAttachement.href = ", caseModelAttachement.href.absoluteString)
    req.addAccessTokenAuthorization()
    req.httpMethod = "GET"
    
    let task = URLSession.shared.dataTask(with: req, completionHandler: { (data, response, error) in
      guard let data = data else {completion(nil); return}
      do {
        let caseModel = try JSONDecoder().decode(CommunicateCaseModel.self, from: data)
        completion(caseModel)
      } catch {
        print("Unexpected error: \(error.localizedDescription).")
        return
      }
    })
    task.resume()
  }
}

extension URLRequest {
  mutating func addAccessTokenAuthorization() {
    self.addValue("Bearer \(Settings.shared.authenticationToken)", forHTTPHeaderField: "Authorization")
  }
  mutating func addBasicAuthorization() {
    let authValue = "\(Settings.shared.clientId):\(Settings.shared.clientSecret)"
    self.addValue("Basic \(authValue.data(using: .utf8)!.base64EncodedString())", forHTTPHeaderField: "Authorization")
  }
}
