//
//  CommunicateCase.swift
//  Communicate
//
//  Created by Nicolas Degen on 09.08.19.
//  Copyright © 2019 Kapanu AG. All rights reserved.
//

import Foundation

extension DateFormatter {
  static let iso8601ThreeDecimal: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
    formatter.calendar = Calendar(identifier: .iso8601)
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    return formatter
  }()
  
  static let iso8601: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
    formatter.calendar = Calendar(identifier: .iso8601)
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    return formatter
  }()
  
  static let iso8601withoutZ: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
    formatter.calendar = Calendar(identifier: .iso8601)
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    return formatter
  }()
}

public class CommunicateCase: Codable {
  public class Actor: Codable {
    public var id: String
    public var roles: [String]
    public var email: String
    public var name: String
    
    enum CodingKeys: String, CodingKey {
      case id = "Id"
      case roles = "Roles"
      case name = "Name"
      case email = "Email"
    }
  }
  
  public struct Attachment: Codable {
    public var id: String
    public var name: String
    public var hash: String
    public var fileType: String
    public var created: Date
    public var updated: Date
    public var href: URL
    public var type: String
    
    enum CodingKeys: String, CodingKey {
      case id = "Id"
      case name = "Name"
      case hash = "Hash"
      case fileType = "FileType"
      case created = "Created"
      case updated = "Updated"
      case href = "Href"
      case type = "Type"
    }
  }
  
  public class Patient: Codable {
    public var firstName: String
    public var lastName: String?
    public var externalId: String?
    public var refererenceNumber: String?
    
    enum CodingKeys: String, CodingKey {
      case firstName = "FirstName"
      case lastName = "LastName"
      case externalId = "ExternalId"
      case refererenceNumber = "PatientRefNo"
    }
  }
  
  public class ModelElement: Codable {
    public class Restoration: Codable {
      public var globalImplantConnectionId: String?
      public var implantDiameter: String?
      public var unn: String?
      public var implantManufacturer: String?
      public var practiceRestorationType: String?
      public var implantLength: String?
      public var restorationType: String?
      public var implantPlatformType: String?
      public var implantSystem: String?
      
      enum CodingKeys: String, CodingKey {
        case globalImplantConnectionId = "GlobalImplantConnectionId"
        case implantDiameter = "ImplantDiameter"
        case unn = "Unn"
        case implantManufacturer = "ImplantManufacturer"
        case practiceRestorationType = "PracticeRestorationType"
        case implantLength = "ImplantLength"
        case restorationType = "RestorationType"
        case implantPlatformType = "ImplantPlatformType"
        case implantSystem = "ImplantSystem"
      }
    }
    
    public var bridgeType: String?
    public var restorations: [Restoration]
    public var modelElementIndex: String?
    public var ponticBaseShape: String?
    public var shade: String?
    public var processStatus: String?
    public var materialDisplayName: String?
    public var preparationLineFileName: String?
    public var shadeDisplayName: String?
    public var deliveryDate: Date?
    public var material: String?
    
    enum CodingKeys: String, CodingKey {
      case bridgeType = "BridgeType"
      case restorations = "Restorations"
      case modelElementIndex = "ModelElementIndex"
      case ponticBaseShape = "PonticBaseShape"
      case shade = "Shade"
      case processStatus = "ProcessStatus"
      case materialDisplayName = "MaterialDisplayName"
      case preparationLineFileName = "PreparationLineFileName"
      case shadeDisplayName = "ShadeDisplayName"
      case deliveryDate = "DeliveryDate"
      case material = "Material"
    }
  }
  
  public class Scan: Codable {
    public var id: String?
    public var href: URL?
    public var fileType: String?
    public var scanTimestamp: String?
    public var jawType: String?
    public var type: String?
    public var hash: String?
    
    enum CodingKeys: String, CodingKey {
      case id = "Id"
      case href = "Href"
      case fileType = "FileType"
      case scanTimestamp = "ScanTimestamp"
      case jawType = "JawType"
      case type = "Type"
      case hash = "Hash"
    }
  }
  
  public class Design: Codable {
    public var hash: String?
    public var type: String?
    public var href: URL?
    public var fileType: String?
    public var id: String?
    
    enum CodingKeys: String, CodingKey {
      case hash = "Hash"
      case type = "Type"
      case href = "Href"
      case fileType = "FileType"
      case id = "Id"
    }
  }
  
  public var id: String
  public var version: Int
  public var patientName: String
  public var patient: Patient
  
  public var created: Date
  public var updatedOn: Date
  public var receivedOn: Date
  public var creatorId: String
  public var state: String
  
  public var stateFlag: String?
  public var deliveryDate: Date?
  public var operatorId: String?
  public var scanSource: String?
  public var application: String?
  public var threeShapeOrderNo: String?
  public var manufacturingProductionTag: String?
  public var model3D: String?
  public var actors: [Actor]
  public var attachments: [Attachment]
  public var comments: [String]
  public var modelElements: [ModelElement]
  public var scans: [Scan]
  public var designs: [Design]
  
  enum CodingKeys: String, CodingKey {
    case id = "Id"
    case version = "Version"
    case patientName = "PatientName"
    case patient = "Patient"
    case created = "Created"
    case updatedOn = "UpdatedOn"
    case receivedOn = "ReceivedOn"
    case creatorId = "CreatorId"
    case state = "State"
    case stateFlag = "StateFlag"
    case deliveryDate = "DeliveryDate"
    case operatorId = "OperatorId"
    case scanSource = "ScanSource"
    case application = "Application"
    case threeShapeOrderNo = "ThreeShapeOrderNo"
    case manufacturingProductionTag = "ManufacturingProductionTag"
    case model3D = "Model3D"
    case actors = "Actors"
    case attachments = "Attachments"
    case comments = "Comments"
    case modelElements = "ModelElements"
    case scans = "Scans"
    case designs = "Designs"
  }
}
