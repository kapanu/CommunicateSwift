//
//  CommunicateCaseModel.swift
//  Communicate
//
//  Created by Nicolas Degen on 15.08.19.
//  Copyright © 2019 Kapanu AG. All rights reserved.
//

import Foundation

public struct CommunicateCaseModel: Codable {
  public struct Stage: Codable {
    public var number: Int
    public var teeth: [Tooth]
    public var upperJawGingivaId: GingivaId
    public var lowerJawGingivaId: GingivaId
    
    public struct GingivaId: Codable {
      public var value: String
      enum CodingKeys: String, CodingKey {
        case value = "Value"
      }
    }
    
    enum CodingKeys: String, CodingKey {
      case number = "Number"
      case teeth = "Teeth"
      case upperJawGingivaId = "UpperJawGingivaId"
      case lowerJawGingivaId = "LowerJawGingivaId"
    }
    
    public func getToothTransforms() -> [String: [Float]] {
      var modelTransforms = [String:[Float]]()
      for tooth in teeth {
        modelTransforms[tooth.modelId] = [Float]()
        for row in tooth.movement.value.transformation {
          modelTransforms[tooth.modelId]?.append(contentsOf: row)
        }
      }
      return modelTransforms
    }
  }
  
  public struct Tooth: Codable {
    public struct Movement: Codable {
      public struct Value: Codable {
        public var transformation: [[Float]]
        public var operationVersion: Int
        
        enum CodingKeys: String, CodingKey {
          case transformation = "Transformation"
          case operationVersion = "OperationVersion"
        }
      }
      public var value: Value
      
      enum CodingKeys: String, CodingKey {
        case value = "Value"
      }
    }
    public var type: String
    public var modelId: String
    public var movement: Movement
    public var attachments: [CommunicateCase.Attachment]
    public var unn: Int
    
    enum CodingKeys: String, CodingKey {
      case type = "$type"
      case modelId = "ModelId"
      case movement = "Movement"
      case attachments = "Attachments"
      case unn = "Unn"
    }
  }
  
  public var version: Int
  public var stages: [Stage]
  
  enum CodingKeys: String, CodingKey {
    case version = "Version"
    case stages = "Stages"
  }
}
