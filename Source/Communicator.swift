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
  public var hasRefreshToken: Bool { return !Settings.shared.refreshToken.isEmpty }

  
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
  
  /// Retrieves all Cases that are available for the logged in user
  public func retrieveCases(forIvosmile: Bool = false, completion: @escaping (Result<[CommunicateCase], Error>)->()) {
    // Change page number in the request to see older cases, e.g. cases?page=2
    var req = URLRequest(url: URL(string: Settings.shared.baseMetaDataURL + "cases?page=0")!)
    req.addAccessTokenAuthorization()
    req.httpMethod = "GET"
    
    let task = URLSession.shared.dataTask(with: req, completionHandler: { (data, response, error) in
      if let err = error {
        guard let resp = response as? HTTPURLResponse else { return }
        if resp.statusCode == 401 {
          self.signIn(vc: nil, completion: { status in
            if status == .signedIn {
              self.retrieveCases(forIvosmile: forIvosmile, completion: completion)
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
            if (caseThreeshape.scans.count > 0) {
              cases.append(caseThreeshape)
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
        let fileURL = path.appendingPathComponent(attachement.name)
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
  
  public func downloadScans(ofCase cCase: CommunicateCase, toDirectoryURL path:URL,
                            completeOne: @escaping ()->(), completion: @escaping (Bool)->()) {
    let taskGroup = DispatchGroup()
    var successfullyDownloadedAll = true
    for (index, scan) in cCase.scans.enumerated() {
      taskGroup.enter()
      // Check if the scan object has a href and fileType before attempting the download
      if let scanURL = scan.href, let scanType = scan.fileType {
        download(resource: scanURL) { data in
          let scanId: String = scan.id ?? String(index)
          let fileURL = path.appendingPathComponent(scanId + "." + scanType)
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
    }
    taskGroup.notify(queue: DispatchQueue.main, work: DispatchWorkItem(block: {
      completion(successfullyDownloadedAll)
    }))
  }
  
  public func downloadColorizedScanOnly(ofCase cCase: CommunicateCase, toDirectoryURL path:URL,
                                        completeOne: @escaping ()->(), completion: @escaping (Bool)->()) {
    let taskGroup = DispatchGroup()
    var successfullyDownloadedAll = true
    for scan in cCase.scans {
      // Download only the ply of the colorized scan
      if let scanExtension = scan.fileType, scanExtension == "dcm", let scanType = scan.jawType, scanType == "upper", let scanHash = scan.hash {
        taskGroup.enter()
        let plyURL = URL(string: Settings.shared.baseMetaDataURL + "cases/" + cCase.id + "/attachments/" + scanHash + "/ply")!
        download(resource: plyURL) { data in
          let fileURL = path.appendingPathComponent(scanHash + ".ply")
          do {
            try data?.write(to: fileURL)
            taskGroup.leave()
          } catch {
            successfullyDownloadedAll = false
            taskGroup.leave()
          }
        }
      }
    }
    taskGroup.notify(queue: DispatchQueue.main, work: DispatchWorkItem(block: {
      completion(successfullyDownloadedAll)
    }))
  }
  
  public func countRestorationComponents(ofCase cCase: CommunicateCase) -> Int {
    var counter: Int = 0
    for scan in cCase.scans {
      if let scanExtension = scan.fileType, scanExtension == "dcm", let scanJawType = scan.jawType, scanJawType == "upper",
      let scanType = scan.type, scanType == "Preparation" {
        counter += 1
      }
    }
    for design in cCase.designs {
      if let _ = design.href, let designExtension = design.fileType, designExtension == "stl", let designType = design.type, !designType.contains("DigitalModel") {
        counter += 1
      }
    }
    for attachment in cCase.attachments {
      if (attachment.fileType == "png" && attachment.name.contains("original")) || attachment.name.contains("RefToPrep") || attachment.name.contains("model.ply") {
        counter += 1
      }
    }
    return counter
  }
  
  public func downloadRestorationComponents(ofCase cCase: CommunicateCase, toDirectoryURL path:URL,
                                            completeOne: @escaping ()->(), completion: @escaping (Bool)->()) {
    let taskGroup = DispatchGroup()
    var successfullyDownloadedAll = true
    for scan in cCase.scans {
      // Download only the ply of the colorized scan
      if let scanExtension = scan.fileType, scanExtension == "dcm", let scanJawType = scan.jawType, scanJawType == "upper", let scanHash = scan.hash,
        let scanType = scan.type, scanType == "Preparation" {
        taskGroup.enter()
        let plyURL = URL(string: Settings.shared.baseMetaDataURL + "cases/" + cCase.id + "/attachments/" + scanHash + "/ply")!
        download(resource: plyURL) { data in
          let fileURL = path.appendingPathComponent(scanHash + ".ply")
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
    }
    for (index, design) in cCase.designs.enumerated() {
      if let designURL = design.href, let designExtension = design.fileType, designExtension == "stl", let designType = design.type, !designType.contains("DigitalModel") {
        taskGroup.enter()
        download(resource: designURL) { data in
          let designId: String = design.id ?? String(index)
          let fileURL = path.appendingPathComponent(designId + "." + designExtension)
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
    }
    for attachment in cCase.attachments {
      if (attachment.fileType == "png" && attachment.name.contains("original")) || attachment.name.contains("RefToPrep") || attachment.name.contains("model.ply") {
        taskGroup.enter()
        download(resource: attachment.href) { data in
          let fileURL = path.appendingPathComponent(attachment.name)
          do {
            try data?.write(to: fileURL)
            taskGroup.leave()
          } catch {
            successfullyDownloadedAll = false
            taskGroup.leave()
          }
        }
      }
    }
    taskGroup.notify(queue: DispatchQueue.main, work: DispatchWorkItem(block: {
      completion(successfullyDownloadedAll)
    }))
  }
  
  public func downloadDesigns(ofCase cCase: CommunicateCase, toDirectoryURL path:URL,
                              completeOne: @escaping ()->(), completion: @escaping (Bool)->()) {
    let taskGroup = DispatchGroup()
    var successfullyDownloadedAll = true
    for (index, design) in cCase.designs.enumerated() {
      taskGroup.enter()
      if let designURL = design.href, let designType = design.fileType {
        download(resource: designURL) { data in
          let designId: String = design.id ?? String(index)
          let fileURL = path.appendingPathComponent(designId + "." + designType)
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
  
  private func getHash(data : Data) -> String {
    let hash = data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) -> [UInt8] in
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
        CC_SHA1(bytes.baseAddress, CC_LONG(data.count), &hash)
        return hash
    }
    return hash.map { String(format: "%02x", $0) }.joined()
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
      let hashed = self.getHash(data: data)
      if (hashed != caseModelAttachement.hash) {
        print("Received packages contains errors!.")
        completion(nil)
        return
      }
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
  
  public func exportMultipleFilesTo3Shape(fileURLs: [URL], metadata: [String: String], completion: @escaping (Bool, String) -> ()) {
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
  }
  
  public func exportProjectTo3Shape(zippedProjectPath: URL, patientFirstName: String = "Esmeralda", patientLastName: String = "Chisme", completion: @escaping (Bool, String) -> ()) {
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
    let patientDictStr: String = "{\r\nPatientFirstName: \"" + patientFirstName + "\",\r\nPatientLastName: \"" + patientLastName + "\"\r\n}"
    var parameters: [String: Any] = ["model": patientDictStr]
    do {
      let data = try Data(contentsOf: zippedProjectPath)
      parameters["file"] = data
    } catch {
      completion(false, error.localizedDescription)
      return
    }
    
    // Step 4. Put the data in the request's body while wrapping it properly with the metadata information necessary for the post request
    let httpBody = NSMutableData()
    for (key, value) in parameters {
      if (!httpBody.isEmpty) {
        httpBody.append("\r\n".data(using: .utf8)!)
      }
      httpBody.append("--\(boundary)\r\n".data(using: .utf8)!)
      if (key == "file") {
        httpBody.append("Content-Disposition: form-data; name=\"\(key)\"; filename=\"\(zippedProjectPath.lastPathComponent)\"\r\n".data(using: .utf8)!)
        httpBody.append("Content-Type: application/item3Dmodel\r\n\r\n".data(using: .utf8)!)
        httpBody.append(value as! Data)
        httpBody.append("\r\n".data(using:. utf8)!)
      } else {
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
