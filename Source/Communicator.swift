//
//  Communicator.swift
//  CommunicateSwift
//
//  Created by Nicolas Degen on 18.06.19.
//  Copyright © 2019 Kapanu AG. All rights reserved.
//

import UIKit
import CommonCrypto

public enum CommunicateStatus {
  case error
  case signedIn
  case signedOut
  case cancelled
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

public class Communicator: NSObject {
  public static let shared = Communicator()
    
  private override init() {}
  
  struct CommunicateObservable {
    weak var observer: CommunicateObserver?
  }
  
  struct UpdateMetadataError: Error {
    let message: String
    
    init(_ message: String) { self.message = message }

    public var localizedDescription: String { return message }
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
  public var hasRefreshToken: Bool { return !Settings.shared.refreshToken.isEmpty }

  
  var observers = [ObjectIdentifier : CommunicateObservable]()
  
  public func addObserver(_ observer: CommunicateObserver) {
    let id = ObjectIdentifier(observer)
    observers[id] = CommunicateObservable(observer: observer)
  }
  private var authVC = AuthenticationViewController()
  
  @objc func cancelAuthentication() {
    dismissAuthenticationVC()
    authVC.completionCallback?(.cancelled)
  }
  
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
    navVC.presentationController?.delegate = self
    authVC.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelAuthentication))
    rootVC.present(navVC, animated: true)
  }
  
  public func updateMetadataURL(success: ((String)->())? = nil, failure: ((String)->())? = nil) {
    var req = URLRequest(url: URL(string: "https://eumetadata.3shapecommunicate.com/api/servers")!)
    
    req.addAccessTokenAuthorization()
    
    let task = URLSession.shared.dataTask(with: req, completionHandler: { (data, response, error) in
      guard let data = data else {
        failure?("Data not available")
        return
      }
      guard let urls = try? JSONDecoder().decode([URL].self, from: data) else {
        failure?("URLs not available")
        return
      }
      if let url = urls.first {
        Settings.shared.baseMetaDataURL = url.absoluteString
        success?(url.absoluteString)
      }
    })
    task.resume()
  }
  
  func requestToken(authCode: String, completion: @escaping (CommunicateStatus)->()) {
    var req = URLRequest(url: Settings.shared.tokenRequestURL)
    req.addBasicAuthorization()
    req.httpBody = "grant_type=authorization_code&redirect_uri=\(Settings.shared.redirectionURI)&code=\(authCode)&scope=openid+api+offline_access+communicate.connections.read_only+data.companies.read_only+data.users.read_only".data(using: .utf8)
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
  
  /// Retrieves last 10 cases by default that are available for the logged in user
  public func retrieveCasesBasic(forIvosmile: Bool = false, completion: @escaping (Result<[CommunicateCase], Error>)->()) {
    updateMetadataURL(success: { _ in
      self.retrieveCasesInAPage(pageNumber: 0, forIvosmile: forIvosmile) { cases in
        completion(cases)
      }
    }, failure: { errorMessage in
      completion(.failure(UpdateMetadataError(errorMessage)))
    })
  }
  
  /// Retrieves cases between a range of pages, cases that are available for the logged in user
  public func retrieveCases(forIvosmile: Bool = false, fromPage: Int = 0, toPage: Int = 10, completion: @escaping (Result<[CommunicateCase], Error>)->()) {
    updateMetadataURL(success: { _ in
      // Change page number in the request to see older cases, e.g. cases?page=2
      var pageNumber = fromPage
      var cases: [CommunicateCase] = []

      let group = DispatchGroup()
      while pageNumber < toPage {
        group.enter()

        self.retrieveCasesInAPage(pageNumber: pageNumber, forIvosmile: forIvosmile) { pageCases in
          switch pageCases {
          case .success(let pageCases):
            cases += pageCases

            group.leave()
          case .failure:
            group.leave()
          }
        }

        pageNumber += 1
      }
      group.notify(queue: DispatchQueue.main, work: DispatchWorkItem(block: {
        // sort cases based on updated date
        cases.sort(by: {$0.updatedOn > $1.updatedOn})
        completion(.success(cases))
      }))
      
    }, failure: { errorMessage in
      completion(.failure(UpdateMetadataError(errorMessage)))
    })
  }
  
  private func retrieveCasesInAPage(pageNumber: Int = 0, forIvosmile: Bool = false, completion: @escaping (Result<[CommunicateCase], Error>)->()) {
    var req = URLRequest(url: URL(string: Settings.shared.baseMetaDataURL + "cases?page=" + String(pageNumber))!)
    req.addAccessTokenAuthorization()
    req.httpMethod = "GET"
    
    let task = URLSession.shared.dataTask(with: req, completionHandler: { (data, response, error) in
      if let err = error {
        guard let resp = response as? HTTPURLResponse else { return }
        if resp.statusCode == 401 {
          self.signIn(vc: nil, completion: { status in
            if status == .signedIn {
              self.retrieveCasesInAPage(pageNumber: pageNumber, forIvosmile: forIvosmile, completion: completion)
            } else {
              completion(.failure(err))
            }
          })
        }
      }
      guard let data = data, let json = try? JSONSerialization.jsonObject(with: data, options: []) as? NSDictionary, let casesArray = json["Cases"] as? NSArray  else {
        return completion(.failure(CommunicatorError.invalidResponse))
      }
      
      var cases: [CommunicateCase] = []
      for `case` in casesArray {
        do {
          let jsonData = try JSONSerialization.data(withJSONObject: `case`, options: [])
          let caseThreeshape = try jsonData.decodeCommunicateCase()
          if (forIvosmile) {
            let scansExist = caseThreeshape.scans.count > 0
            for attach in caseThreeshape.attachments {
              if (attach.name == "model.ply" && scansExist) {
                cases.append(caseThreeshape)
                break
              }
            }
          } else {
            // heuristic to select Ortho cases: check if "TreatmentSimulation-IvoSmile.json" exists in the attachments
            for attach in caseThreeshape.attachments {
              if attach.name == "TreatmentSimulation-IvoSmile.json" {
                cases.append(caseThreeshape)
                break
              }
            }
          }
        } catch {
          print("Unexpected error: \(error).")
        }
      }
      completion(.success(cases))
    })
    task.resume()
  }
  
  public func getConnectedUsers(completion: @escaping (Bool, String, [CommunicateConnection], [String]) -> ()) {
    var req = URLRequest(url: URL(string: "https://users.3shapecommunicate.com/api/users/me")!)
    req.addAccessTokenAuthorization()
    req.httpMethod = "GET"
    
    let task = URLSession.shared.dataTask(with: req) {(data, response, error) in
      // check for fundamental networking error
      guard let response = response as? HTTPURLResponse, error == nil else {
        completion(false, error?.localizedDescription ?? "Unknown error", [], [])
        return
      }
      // check for http errors
      guard (200 ... 299) ~= response.statusCode else {
        completion(false, response.description + ", status code: " + String(response.statusCode), [], [])
        return
      }
      guard let data = data, let json = try? JSONSerialization.jsonObject(with: data, options: []) as? NSDictionary, let connectionsArray = json["Connections"] as? NSArray, let selfID = json["Id"] as? String, let connectedUsersIdsArray = json["ConnectedUsers"] as? NSArray else {
        completion(false, "Data cannot be accessed", [], [])
        return
      }
      var connections: [CommunicateConnection] = []
      for connection in connectionsArray {
        do {
          let jsonData = try JSONSerialization.data(withJSONObject: connection, options: [])
          let connectionThreeshape = try JSONDecoder().decode(CommunicateConnection.self, from: jsonData)
          connections.append(connectionThreeshape)
        } catch {
          print("Unexpected error: \(error).")
        }
      }
      if let connectedUsersIds = connectedUsersIdsArray as? [String] {
        completion(true, selfID, connections, connectedUsersIds)
      } else {
        completion(false, "Could not convert connectedUsersIds", [], [])
      }
    }
    task.resume()
  }
  
  public func exportMultipleFilesTo3Shape(fileURLs: [URL], metadata: [String: String], completion: @escaping (Bool, String) -> ()) {
    updateMetadataURL(success: { _ in
      // Step 1. Prepare post request url and authorization
      let url = URL(string: Settings.shared.baseMetaDataURL + "cases?caseType=common")!
      var request = URLRequest(url: url)
      request.addAccessTokenAuthorization()
      
      // Step 2. Prepare post request header and set type as 'POST'
      let makeRandom = { UInt32.random(in: (.min)...(.max)) }
      let boundary = String(format: "------------------------%08X%08X", makeRandom(), makeRandom())
      request.setValue("multipart/form-data; boundary=" + boundary, forHTTPHeaderField: "Content-Type")
      request.httpMethod = "POST"
      
      // Step 3. Prepare the data which will be put in the body of the request
      var patientDictStr: String = "{\r\n"
      for (index, element) in metadata.enumerated() {
        if (index != metadata.count - 1) {
          patientDictStr += element.key + ": \"" + element.value + "\",\r\n"
        } else {
          patientDictStr += element.key + ": \"" + element.value + "\"\r\n}"
        }
      }
      var parameters: [String: Any] = ["model": patientDictStr]
      var dataObjects: [Data] = []
      do {
        for fileURL in fileURLs {
          let data = try Data(contentsOf: fileURL)
          dataObjects.append(data)
        }
      } catch {
        completion(false, error.localizedDescription)
        return
      }
      parameters["file"] = dataObjects
      
      // Step 4. Put the data in the request's body while wrapping it properly with the metadata information necessary for the post request
      let httpBody = NSMutableData()
      for (key, value) in parameters {
        if (!httpBody.isEmpty) {
          httpBody.append("\r\n".data(using: .utf8)!)
        }
        if (key == "file") {
          for (i, val) in (value as! [Data]).enumerated() {
            httpBody.append("--\(boundary)\r\n".data(using: .utf8)!)
            httpBody.append("Content-Disposition: form-data; name=\"\(key)\"; filename=\"\(fileURLs[i].lastPathComponent)\"\r\n".data(using: .utf8)!)
            httpBody.append("Content-Type: application/item3Dmodel\r\n\r\n".data(using: .utf8)!)
            httpBody.append(val)
            httpBody.append("\r\n".data(using:. utf8)!)
          }
        } else {
          httpBody.append("--\(boundary)\r\n".data(using: .utf8)!)
          httpBody.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
          httpBody.append("\(value)\r\n".data(using: .utf8)!)
        }
      }
      httpBody.append("--\(boundary)--\r\n".data(using: .utf8)!)
      request.setValue(String(httpBody.length), forHTTPHeaderField: "Content-Length")
      request.httpBody = httpBody as Data
      
      // Step 5. Send the post request and handle the possible responses
      let task = URLSession.shared.dataTask(with: request) { data, response, error in
        // check for fundamental networking error
        guard let response = response as? HTTPURLResponse, error == nil else {
          completion(false, error?.localizedDescription ?? "Unknown error")
          return
        }
        // check for http errors
        guard (200 ... 299) ~= response.statusCode else {
          completion(false, response.description + ", status code: " + String(response.statusCode))
          return
        }
        // the request looks to have been carried on succesfully
        completion(true, "")
      }
      task.resume()
    }, failure: { (error) in
      completion(false, error)
    })
  }
  
}

extension Communicator: UIAdaptivePresentationControllerDelegate {
  public func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
    cancelAuthentication()
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

extension Dictionary {
    func percentEscaped() -> String {
        return map { (key, value) in
            let escapedKey = "\(key)".addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? ""
            let escapedValue = "\(value)".addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? ""
            return escapedKey + "=" + escapedValue
        }
        .joined(separator: "&")
    }
}

extension CharacterSet {
    static let urlQueryValueAllowed: CharacterSet = {
        let generalDelimitersToEncode = ":#[]@" // does not include "?" or "/" due to RFC 3986 - Section 3.4
        let subDelimitersToEncode = "!$&'()*+,;="

        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "\(generalDelimitersToEncode)\(subDelimitersToEncode)")
        return allowed
    }()
}
