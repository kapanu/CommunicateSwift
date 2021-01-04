//
//  Communicator+Extra.swift
//  CommunicateSwift
//
//  Created by Valentin Vasiliu on 19.06.20.
//  Copyright © 2020 Kapanu AG. All rights reserved.
//

import CommonCrypto

/// Not actively used functions by Kapanu apps.
extension Communicator {
  
  public func refreshTokenIfNeeded(completion: @escaping (CommunicateStatus)->()) {
    guard isSignedIn == false else { return completion(.signedIn) }
    guard hasRefreshToken else { return completion(.signedOut) }
    refreshToken(completion: completion)
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
        completion(nil)
        return
      }
    })
    task.resume()
  }
  
  public func exportProjectTo3Shape(zippedProjectPath: URL, patientFirstName: String = "Esmeralda", patientLastName: String = "Chisme", completion: @escaping (Bool, String) -> ()) {
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
    }, failure: { (error) in
    completion(false, error)
    })
  }
  
}
