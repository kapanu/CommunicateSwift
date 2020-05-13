//
//  CommunicateConnection.swift
//  Communicate
//
//  Created by Valentin Vasiliu on 12.05.20.
//  Copyright © 2020 Kapanu AG. All rights reserved.
//

import Foundation

public struct CommunicateConnection: Codable {
  public var id: String?
  public var remoteUserName: String?
  public var connectionAccepted: Bool?
  public var inviterUserEmail: String?
  public var inviterUserId: String?
  public var inviterUserName: String?
  public var remoteUser: [String: String]?
  public var remoteUserEmail: String?
  public var remoteUserType: String?
  public var remoteUserId: String?
  public var inviterUser: [String: String]?
  public var inviterUserType: String?
  
  enum CodingKeys: String, CodingKey {
    case id = "Id"
    case remoteUserName = "RemoteUserName"
    case connectionAccepted = "ConnectionAccepted"
    case inviterUserEmail = "InviterUserEmail"
    case inviterUserId = "InviterUserId"
    case inviterUserName = "InviterUserName"
    // case remoteUser = "RemoteUser"
    case remoteUserEmail = "RemoteUserEmail"
    case remoteUserType = "RemoteUserType"
    case remoteUserId = "RemoteUserId"
    // case inviterUser = "InviterUser"
    case inviterUserType = "InviterUserType"
  }
}
