//
//  Communicator+Downloads.swift
//  Communicate
//
//  Created by Valentin Vasiliu on 19.06.20.
//  Copyright © 2020 Kapanu AG. All rights reserved.
//

extension Communicator {
  public enum DownloadError: Error {
    case failedFileDownload
    case timeout
    case other
  }
  
  public func download(resource: URL, timeoutInterval: Double? = nil, completion: @escaping (Data?, DownloadError?)->()) {
    var req = URLRequest(url: resource)
    req.addAccessTokenAuthorization()
    req.httpMethod = "GET"
    if let timeoutInterval = timeoutInterval { req.timeoutInterval = timeoutInterval }
    
    let task = URLSession.shared.dataTask(with: req) { (data, response, error) in
      if let error = error, error._code == NSURLErrorTimedOut {
        completion(data, .timeout)
        return
      }
      completion(data, nil)
    }
    task.resume()
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
      if ((attachment.fileType == "png" || attachment.fileType == "jpg") && attachment.name.contains("original")) || attachment.name.contains("RefToPrep") || attachment.name.contains("model.ply") ||
        (attachment.fileType == "xml" && (attachment.name.contains("camera_params") || attachment.name.contains("model_view_matrix"))) {
        counter += 1
      }
    }
    return counter
  }
  
  public func downloadRestorationComponents(ofCase cCase: CommunicateCase, toDirectoryURL path:URL,
                                            completeOne: @escaping ()->(), completion: @escaping (DownloadError?)->()) {
    let taskGroup = DispatchGroup()
    var successfullyDownloadedAll = true
    let timeoutInterval: Double = 30
    var isTimeoutError = false
    for scan in cCase.scans {
      if (isTimeoutError) { break }
      // Download only the ply of the colorized scan
      if let scanExtension = scan.fileType, scanExtension == "dcm", let scanJawType = scan.jawType, scanJawType == "upper", let scanHash = scan.hash,
        let scanType = scan.type, scanType == "Preparation" {
        taskGroup.enter()
        let plyURL = URL(string: Settings.shared.baseMetaDataURL + "cases/" + cCase.id + "/attachments/" + scanHash + "/ply")!
        download(resource: plyURL, timeoutInterval: timeoutInterval) { data, error in
          let fileURL = path.appendingPathComponent(scanHash + ".ply")
          do {
            try data?.write(to: fileURL)
            completeOne()
            taskGroup.leave()
          } catch {
            successfullyDownloadedAll = false
            taskGroup.leave()
          }
          if (error == .timeout) { isTimeoutError = true }
        }
      }
    }
    for (index, design) in cCase.designs.enumerated() {
      if (isTimeoutError) { break }
      if let designURL = design.href, let designExtension = design.fileType, designExtension == "stl", let designType = design.type, !designType.contains("DigitalModel") {
        taskGroup.enter()
        download(resource: designURL, timeoutInterval: timeoutInterval) { data, error in
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
          if (error == .timeout) { isTimeoutError = true }
        }
      }
    }
    for attachment in cCase.attachments {
      if (isTimeoutError) { break }
      if ((attachment.fileType == "png" || attachment.fileType == "jpg") && attachment.name.contains("original")) || attachment.name.contains("RefToPrep") || attachment.name.contains("model.ply") ||
        (attachment.fileType == "xml" && (attachment.name.contains("camera_params") || attachment.name.contains("model_view_matrix"))) {
        taskGroup.enter()
        download(resource: attachment.href) { data, error in
          let fileURL = path.appendingPathComponent(attachment.name)
          do {
            try data?.write(to: fileURL)
            taskGroup.leave()
          } catch {
            successfullyDownloadedAll = false
            taskGroup.leave()
          }
          if (error == .timeout) { isTimeoutError = true }
        }
      }
    }
    taskGroup.notify(queue: DispatchQueue.main, work: DispatchWorkItem(block: {
      if isTimeoutError {
        completion(.timeout)
      } else if successfullyDownloadedAll {
        completion(nil)
      } else {
        completion(.failedFileDownload)
      }
    }))
  }
}

/// Methods for debugging purposes. Not actively used.
extension Communicator {
  public func downloadAttachments(ofCase cCase: CommunicateCase, toDirectoryURL path:URL, completion: @escaping (Bool)->()) {
    let taskGroup = DispatchGroup()
    var successfullyDownloadedAll = true
    for attachement in cCase.attachments {
      taskGroup.enter()
      download(resource: attachement.href) { data, _ in
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
      download(resource: attachement.href) { data, _ in
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
        download(resource: scanURL) { data, _ in
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
        download(resource: plyURL) { data, _ in
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
  
  public func downloadDesigns(ofCase cCase: CommunicateCase, toDirectoryURL path:URL,
                              completeOne: @escaping ()->(), completion: @escaping (Bool)->()) {
    let taskGroup = DispatchGroup()
    var successfullyDownloadedAll = true
    for (index, design) in cCase.designs.enumerated() {
      taskGroup.enter()
      if let designURL = design.href, let designType = design.fileType {
        download(resource: designURL) { data, _ in
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
  
  public func downloadTestTimeout(ofCase cCase: CommunicateCase, toDirectoryURL path:URL,
                                  completeOne: @escaping ()->(), completion: @escaping (DownloadError?)->()) {
    let taskGroup = DispatchGroup()
    taskGroup.enter()
    let urlTest = URL(string: "https://httpstat.us/200?sleep=5000")!
    var req = URLRequest(url: urlTest)
    req.httpMethod = "GET"
    req.timeoutInterval = 4
    var errorTimeout = false
    let task = URLSession.shared.dataTask(with: req) { (data, response, error) in
      // check for http errors
      if let response = response as? HTTPURLResponse {
        print(">>> Response: " + response.description + ", status code: " + String(response.statusCode))
      }
      if let data = data {
        print(">>> Data: " + String(data: data, encoding: .utf8)!)
      } else {
        print(">>> Something went wrong!")
      }
      if let error = error, error._code == NSURLErrorTimedOut {
        print(">>> Request timeout!")
        errorTimeout = true
      }
      taskGroup.leave()
    }
    task.resume()
    
    taskGroup.notify(queue: DispatchQueue.main, work: DispatchWorkItem(block: {
      if errorTimeout {
        completion(.timeout)
      } else {
        completion(.other)
      }
    }))
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
  
}
