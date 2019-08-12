//
//  CommunicateCase.swift
//  Communicate
//
//  Created by Nicolas Degen on 09.08.19.
//  Copyright © 2019 Kapanu AG. All rights reserved.
//

import Foundation

public struct CommunicateAttachment: Codable {
  public var Id: String
  public var Name: String
  public var Hash: String
  public var FileType: String
  public var Created: String
  public var Updated: String
  public var Href: URL
  public var `Type`: String
}

public class CommunicateCasePatient: Codable {
  public var FirstName: String
  public var LastName: String
  public var ExternalId: String?
  public var PatientRefNo: String?
}

public class CommunicateCaseActor: Codable {
  public var Id: String
  public var Roles: [String]
  public var Email: String
  public var Name: String
}

public class CommunicateCase: Codable {
  public var Id: String
  public var Version: Int
  public var PatientName: String
  public var Patient: CommunicateCasePatient
  
  public var Created: String
  public var UpdatedOn: String
  public var ReceivedOn: String
  public var CreatorId: String
  public var State: String
  
  public var StateFlag: String?
  public var DeliveryDate: String?
  public var OperatorId: String?
  public var ScanSource: String?
  public var Application: String?
  public var ThreeShapeOrderNo: String?
  public var ManufacturingProductionTag: String?
  public var Model3D: String?
  public var Actors: [CommunicateCaseActor]
  public var Attachments: [CommunicateAttachment]
  public var Comments: [String]
  public var ModelElements: [String]
  public var Scans: [String]
  public var Designs: [String]
}

