//
//  Communicator+Downloads.swift
//  Communicate
//
//  Created by Valentin Vasiliu on 19.06.20.
//  Copyright © 2020 Kapanu AG. All rights reserved.
//

import Foundation

extension Communicator {
  public func download(resource: URL, completion: @escaping (Data?)->()) {
    var req = URLRequest(url:resource)
    req.addAccessTokenAuthorization()
    req.httpMethod = "GET"
    
    let task = URLSession.shared.dataTask(with: req) { (data, response, error) in
      completion(data)
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
      if ((attachment.fileType == "png" || attachment.fileType == "jpg") && attachment.name.contains("original")) || attachment.name.contains("RefToPrep") || attachment.name.contains("model.ply") ||
        (attachment.fileType == "xml" && (attachment.name.contains("camera_params") || attachment.name.contains("model_view_matrix"))) {
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
}

/// Methods for debugging purposes. Not actively used.
extension Communicator {
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
