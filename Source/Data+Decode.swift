//
//  Data+Decode.swift
//  Communicate
//
//  Created by Nicolas Degen on 23.08.19.
//  Copyright © 2019 Kapanu AG. All rights reserved.
//

import Foundation

extension Data {
  public func decodeCommunicateCase() throws -> CommunicateCase {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .custom({ decoder -> Date in
      let container = try decoder.singleValueContainer()
      let dateStr = try container.decode(String.self)
      // possible date strings: "2019-08-07T13:38:24Z", "2019-08-07T13:38:24", "2019-08-07T13:38:24.123Z"
      let len = dateStr.count
      var date: Date? = nil
      if len == 19 {
        date = DateFormatter.iso8601withoutZ.date(from: dateStr)
      } else if len == 20 {
        date = DateFormatter.iso8601.date(from: dateStr)
      } else {
        date = DateFormatter.iso8601ThreeDecimal.date(from: dateStr)
      }
      guard let date_ = date else {
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date string \(dateStr)")
      }
      // print("DATE DECODER \(dateStr) to \(date_)")
      return date_
    })
    
    
    return try decoder.decode(CommunicateCase.self, from: self)
  }
}
