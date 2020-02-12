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
      
      var cases: [CommunicateCase] = []
      for `case` in casesArray {
        do {
          let jsonData = try JSONSerialization.data(withJSONObject: `case`, options: [])
          let caseThreeshape = try jsonData.decodeCommunicateCase()
          cases.append(caseThreeshape)
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
  
  public func dummyPost() {
    // Note: test function for a "application/x-www-form-urlencoded" type POST request
    // let url = URL(string: "https://postman-echo.com/post")!
    let url = URL(string: "https://httpbin.org/post")!
    var request = URLRequest(url: url)
    // request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
    request.httpMethod = "POST"
    let parameters: [String: Any] = [
        "id": 13,
        "name": "Jack & Jill"
    ]
    request.httpBody = parameters.percentEscaped().data(using: .utf8)

    let task = URLSession.shared.dataTask(with: request) { data, response, error in
        guard let data = data,
            let response = response as? HTTPURLResponse,
            error == nil else {                                              // check for fundamental networking error
            print("error", error ?? "Unknown error")
            return
        }

        guard (200 ... 299) ~= response.statusCode else {                    // check for http errors
            print("statusCode should be 2xx, but is \(response.statusCode)")
            print("response = \(response)")
            return
        }

        let responseString = String(data: data, encoding: .utf8)
        print("responseString = \(String(describing: responseString))")
    }
    task.resume()
  }
  
  public func dummyPostMultipartForm() {
    // Note: Current function is a skeleton to test a multipart/form-data POST request.
    // It is successful in sending basic form data types.
    let url = URL(string: "https://httpbin.org/post")!
    var request = URLRequest(url: url)
    let makeRandom = { UInt32.random(in: (.min)...(.max)) }
    let boundary = String(format: "------------------------%08X%08X", makeRandom(), makeRandom())
    request.setValue("multipart/form-data; boundary=" + boundary, forHTTPHeaderField: "Content-Type")
    request.httpMethod = "POST"
    
    let patientDict: [String: String] = ["PatientFirstName": "PatientName", "PatientLastName": "LastName"]
    let parameters: [String: Any] = [
       "model": patientDict,
       "id": 13,
       "name": "Jack & Jill",
       "example": "Testy test"
    ]
    
    let httpBody = NSMutableData()
    for (key, value) in parameters {
      if (!httpBody.isEmpty) {
        httpBody.append("\r\n".data(using: .utf8)!)
      }
      
      httpBody.append("--\(boundary)\r\n".data(using: .utf8)!)
      httpBody.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
      // httpBody.append("Content-Type: Auto\r\n\r\n".data(using: .utf8)!)
      httpBody.append("\(value)".data(using: .utf8)!)
    }
    httpBody.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
    print("Data length count: ", httpBody.length)

    request.setValue(String(httpBody.length), forHTTPHeaderField: "Content-Length")
    request.httpBody = httpBody as Data
    print(">>> request.httpBody:", String(decoding: request.httpBody!, as: UTF8.self))
    
    let task = URLSession.shared.dataTask(with: request) { data, response, error in
        guard let data = data,
            let response = response as? HTTPURLResponse,
            error == nil else {                                              // check for fundamental networking error
            print("error", error ?? "Unknown error")
            return
        }

        guard (200 ... 299) ~= response.statusCode else {                    // check for http errors
            print("statusCode should be 2xx, but is \(response.statusCode)")
            print("response = \(response)")
            return
        }

        let responseString = String(data: data, encoding: .utf8)
        print("responseString = \(String(describing: responseString))")
    }
    task.resume()
  }
  
  public func dummy3ShapePostMultipartForm() {
    let url = URL(string: baseMetadataURL + "/api/cases?caseType=common")!
    var request = URLRequest(url: url)
    request.addAccessTokenAuthorization()
    // print(">>> Bearer \(Settings.shared.authenticationToken)") // <-- token needed to send requests via Postman
    
    let makeRandom = { UInt32.random(in: (.min)...(.max)) }
    let boundary = String(format: "------------------------%08X%08X", makeRandom(), makeRandom())
    request.setValue("multipart/form-data; boundary=" + boundary, forHTTPHeaderField: "Content-Type")
    request.httpMethod = "POST"
    
    let patientDictStr: String = "{\r\nPatientFirstName: \"Lizzie\",\r\nPatientLastName: \"Queen\"\r\n}"
    let parameters: [String: Any] = [
       "model": patientDictStr,
    ]
    
    let httpBody = NSMutableData()
    for (key, value) in parameters {
      if (!httpBody.isEmpty) {
        httpBody.append("\r\n".data(using: .utf8)!)
      }
      
      httpBody.append("--\(boundary)\r\n".data(using: .utf8)!)
      httpBody.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
      // httpBody.append("Content-Type: Auto\r\n\r\n".data(using: .utf8)!) // <-- will be needed when attaching files
      httpBody.append("\(value)".data(using: .utf8)!)
    }
    httpBody.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

    request.setValue(String(httpBody.length), forHTTPHeaderField: "Content-Length")
    request.httpBody = httpBody as Data

    let task = URLSession.shared.dataTask(with: request) { data, response, error in
        guard let data = data,
            let response = response as? HTTPURLResponse,
            error == nil else {                                              // check for fundamental networking error
            print("error", error ?? "Unknown error")
            return
        }

        guard (200 ... 299) ~= response.statusCode else {                    // check for http errors
            print("statusCode should be 2xx, but is \(response.statusCode)")
            print("response = \(response)")
            return
        }

        let responseString = String(data: data, encoding: .utf8)
        print("responseString = \(String(describing: responseString))")
    }
    task.resume()
  }
  
  public func dummy3ShapePostMultipartForm(with image: UIImage) {
    let url = URL(string: baseMetadataURL + "/api/cases?caseType=common")!
    var request = URLRequest(url: url)
    request.addAccessTokenAuthorization()
    // print(">>> Bearer \(Settings.shared.authenticationToken)") // <-- token needed to send requests via Postman
    
    let makeRandom = { UInt32.random(in: (.min)...(.max)) }
    let boundary = String(format: "------------------------%08X%08X", makeRandom(), makeRandom())
    request.setValue("multipart/form-data; boundary=" + boundary, forHTTPHeaderField: "Content-Type")
    request.httpMethod = "POST"
    
    let patientDictStr: String = "{\r\nPatientFirstName: \"Lizzie\",\r\nPatientLastName: \"Queen\"\r\n}"
    var parameters: [String: Any] = [
       "model": patientDictStr,
    ]
    guard let imageData = image.jpegData(compressionQuality: 1.0) else {
      print(">>> Getting jpeg data from image failed")
      return
    }
    parameters["file"] = imageData
    
    let httpBody = NSMutableData()
    for (key, value) in parameters {
      if (!httpBody.isEmpty) {
        httpBody.append("\r\n".data(using: .utf8)!)
      }
      
      httpBody.append("--\(boundary)\r\n".data(using: .utf8)!)
      if (key == "file") {
        httpBody.append("Content-Disposition: form-data; name=\"\(key)\"; filename=\"rendering.jpg\"\r\n".data(using: .utf8)!)
        httpBody.append("Content-Type: image/jpg\r\n\r\n".data(using: .utf8)!)
        httpBody.append(value as! Data)
        httpBody.append("\r\n".data(using:. utf8)!)
      } else {
        httpBody.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
        httpBody.append("\(value)\r\n".data(using: .utf8)!)
      }
    }
    httpBody.append("--\(boundary)--\r\n".data(using: .utf8)!)

    request.setValue(String(httpBody.length), forHTTPHeaderField: "Content-Length")
    print(">>> Content length: ", httpBody.length)
    request.httpBody = httpBody as Data

    let task = URLSession.shared.dataTask(with: request) { data, response, error in
        guard let data = data,
            let response = response as? HTTPURLResponse,
            error == nil else {                                              // check for fundamental networking error
            print("error", error ?? "Unknown error")
            return
        }

        guard (200 ... 299) ~= response.statusCode else {                    // check for http errors
            print("statusCode should be 2xx, but is \(response.statusCode)")
            print("response = \(response)")
            return
        }

        let responseString = String(data: data, encoding: .utf8)
        print("responseString = \(String(describing: responseString))")
    }
    task.resume()
  }
  
  public func dummy3ShapePostMultipartForm(with saveModelPath: URL) {
    // Note: to be completed once model contents are successfully passed
    let url = URL(string: baseMetadataURL + "/api/cases?caseType=common")!
    var request = URLRequest(url: url)
    request.addAccessTokenAuthorization()
    // print(">>> Bearer \(Settings.shared.authenticationToken)") // <-- token needed to send requests via Postman
    
    let makeRandom = { UInt32.random(in: (.min)...(.max)) }
    let boundary = String(format: "------------------------%08X%08X", makeRandom(), makeRandom())
    request.setValue("multipart/form-data; boundary=" + boundary, forHTTPHeaderField: "Content-Type")
    request.httpMethod = "POST"
    
    let patientDictStr: String = "{\r\nPatientFirstName: \"Tushy\",\r\nPatientLastName: \"McBootay\"\r\n}"
    var parameters: [String: Any] = [
       "model": patientDictStr,
    ]
    do {
      let data = try Data(contentsOf: saveModelPath)
      parameters["file"] = data
    } catch {
      print("Getting model data failed with error: \(error)")
      return
    }
    
    let httpBody = NSMutableData()
    for (key, value) in parameters {
      if (!httpBody.isEmpty) {
        httpBody.append("\r\n".data(using: .utf8)!)
      }
      
      httpBody.append("--\(boundary)\r\n".data(using: .utf8)!)
      if (key == "file") {
        httpBody.append("Content-Disposition: form-data; name=\"\(key)\"; filename=\"test.ply\"\r\n".data(using: .utf8)!)
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
    print(">>> Content length: ", httpBody.length)
    request.httpBody = httpBody as Data

    let task = URLSession.shared.dataTask(with: request) { data, response, error in
        guard let data = data,
            let response = response as? HTTPURLResponse,
            error == nil else {                                              // check for fundamental networking error
            print("error", error ?? "Unknown error")
            return
        }

        guard (200 ... 299) ~= response.statusCode else {                    // check for http errors
            print("statusCode should be 2xx, but is \(response.statusCode)")
            print("response = \(response)")
            return
        }

        let responseString = String(data: data, encoding: .utf8)
        print("responseString = \(String(describing: responseString))")
    }
    task.resume()
  }
  
  public func exportMultipleFiles3Shape(fileURLs: [URL], patientFirstName: String = "Dummy", patientLastName: String = "McSlow", completion: @escaping (Bool) -> ()) {
    // Note: to be completed once model contents are successfully passed
    let url = URL(string: baseMetadataURL + "/api/cases?caseType=common")!
    var request = URLRequest(url: url)
    request.addAccessTokenAuthorization()
    
    let makeRandom = { UInt32.random(in: (.min)...(.max)) }
    let boundary = String(format: "------------------------%08X%08X", makeRandom(), makeRandom())
    request.setValue("multipart/form-data; boundary=" + boundary, forHTTPHeaderField: "Content-Type")
    request.httpMethod = "POST"
    
    let patientDictStr: String = "{\r\nPatientFirstName: \"" + patientFirstName + "\",\r\nPatientLastName: \"" + patientLastName + "\"\r\n}"
    var parameters: [String: Any] = [
       "model": patientDictStr,
    ]
    
    var dataObjects: [Data] = []
    var filenames: [String] = []
    do {
      for fileURL in fileURLs {
        print(">>> fileURL: ", fileURL.path)
        let data = try Data(contentsOf: fileURL)
        dataObjects.append(data)
        let filename = fileURL.lastPathComponent
        filenames.append(filename)
      }
    } catch {
      print("Getting zipped project data failed with error: \(error)")
      completion(false)
      return
    }
    parameters["file"] = dataObjects
    
    let httpBody = NSMutableData()
    for (key, value) in parameters {
      if (!httpBody.isEmpty) {
        httpBody.append("\r\n".data(using: .utf8)!)
      }
      
      if (key == "file") {
        for (i, val) in (value as! [Data]).enumerated() {
          print(">>> filename: ", filenames[i])
          httpBody.append("--\(boundary)\r\n".data(using: .utf8)!)
          httpBody.append("Content-Disposition: form-data; name=\"\(key)\"; filename=\"\(filenames[i])\"\r\n".data(using: .utf8)!)
          httpBody.append("Content-Type: application/item3Dmodel\r\n\r\n".data(using: .utf8)!)
          httpBody.append(val)
          httpBody.append("\r\n".data(using:. utf8)!)
          print(">>> httpBody length: ", httpBody.length)
        }
      } else {
        httpBody.append("--\(boundary)\r\n".data(using: .utf8)!)
        httpBody.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
        httpBody.append("\(value)\r\n".data(using: .utf8)!)
      }
    }
    httpBody.append("--\(boundary)--\r\n".data(using: .utf8)!)
    
    request.setValue(String(httpBody.length), forHTTPHeaderField: "Content-Length")
    print(">>> Content length: ", httpBody.length)
    request.httpBody = httpBody as Data
    
    let task = URLSession.shared.dataTask(with: request) { data, response, error in
      guard let data = data,
          let response = response as? HTTPURLResponse,
          error == nil else {                                              // check for fundamental networking error
          print("error", error ?? "Unknown error")
          completion(false)
          return
      }

      guard (200 ... 299) ~= response.statusCode else {                    // check for http errors
          print("statusCode should be 2xx, but is \(response.statusCode)")
          print("response = \(response)")
          completion(false)
          return
      }

      let responseString = String(data: data, encoding: .utf8)
      print("responseString = \(String(describing: responseString))")
      completion(true)
    }
    task.resume()
  }
  
  public func exportProjectFor3Shape(zippedProjectPath: URL, patientFirstName: String = "Dummy", patientLastName: String = "McSlow", completion: @escaping (Bool) -> ()) {
    // Note: to be completed once model contents are successfully passed
    let url = URL(string: baseMetadataURL + "/api/cases?caseType=common")!
    var request = URLRequest(url: url)
    request.addAccessTokenAuthorization()
    
    let makeRandom = { UInt32.random(in: (.min)...(.max)) }
    let boundary = String(format: "------------------------%08X%08X", makeRandom(), makeRandom())
    request.setValue("multipart/form-data; boundary=" + boundary, forHTTPHeaderField: "Content-Type")
    request.httpMethod = "POST"
    
    let patientDictStr: String = "{\r\nPatientFirstName: \"" + patientFirstName + "\",\r\nPatientLastName: \"" + patientLastName + "\"\r\n}"
    var parameters: [String: Any] = [
       "model": patientDictStr,
    ]
    do {
      let data = try Data(contentsOf: zippedProjectPath)
      parameters["file"] = data
    } catch {
      print("Getting zipped project data failed with error: \(error)")
      completion(false)
      return
    }
    
    let httpBody = NSMutableData()
    for (key, value) in parameters {
      if (!httpBody.isEmpty) {
        httpBody.append("\r\n".data(using: .utf8)!)
      }
      
      httpBody.append("--\(boundary)\r\n".data(using: .utf8)!)
      if (key == "file") {
        httpBody.append("Content-Disposition: form-data; name=\"\(key)\"; filename=\"test.zip\"\r\n".data(using: .utf8)!)
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
    print(">>> Content length: ", httpBody.length)
    request.httpBody = httpBody as Data
    
    let task = URLSession.shared.dataTask(with: request) { data, response, error in
      guard let data = data,
          let response = response as? HTTPURLResponse,
          error == nil else {                                              // check for fundamental networking error
          print("error", error ?? "Unknown error")
          completion(false)
          return
      }

      guard (200 ... 299) ~= response.statusCode else {                    // check for http errors
          print("statusCode should be 2xx, but is \(response.statusCode)")
          print("response = \(response)")
          completion(false)
          return
      }

      let responseString = String(data: data, encoding: .utf8)
      print("responseString = \(String(describing: responseString))")
      completion(true)
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
