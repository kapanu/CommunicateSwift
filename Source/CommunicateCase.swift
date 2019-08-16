//
//  CommunicateCase.swift
//  Communicate
//
//  Created by Nicolas Degen on 09.08.19.
//  Copyright © 2019 Kapanu AG. All rights reserved.
//

import Foundation


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
    public var created: String
    public var updated: String
    public var href: URL
    public var type: String
    
    enum CodingKeys: String, CodingKey {
      case id = "Id"
      case name = "Name"
      case hash = "Hash"
      case fileType = "FileType"
      case  created = "Created"
      case  updated = "Updated"
      case  href = "Href"
      case  type = "Type"
    }
  }
  
  public class Patient: Codable {
    public var firstName: String
    public var lastName: String
    public var externalId: String?
    public var refererenceNumber: String?
    
    enum CodingKeys: String, CodingKey {
      case firstName = "FirstName"
      case lastName = "LastName"
      case externalId = "ExternalId"
      case refererenceNumber = "PatientRefNo"
    }
  }
  
  public var id: String
  public var version: Int
  public var patientName: String
  public var patient: Patient
  
  public var created: String
  public var updatedOn: String
  public var receivedOn: String
  public var creatorId: String
  public var state: String
  
  public var stateFlag: String?
  public var deliveryDate: String?
  public var operatorId: String?
  public var scanSource: String?
  public var application: String?
  public var threeShapeOrderNo: String?
  public var manufacturingProductionTag: String?
  public var model3D: String?
  public var actors: [Actor]
  public var attachments: [Attachment]
  public var comments: [String]
  public var modelElements: [String]
  public var scans: [String]
  public var designs: [String]
  
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
