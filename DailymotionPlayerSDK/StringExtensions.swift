//
//  StringExtensions.swift
//  DailymotionPlayerSDK
//
//  Created by Rémi GUYON on 29/06/2021.
//  Copyright © 2021 Dailymotion. All rights reserved.
//

import Foundation

extension String {
  var boolValue: Bool {
    return (self as NSString).boolValue
  }

  func groups(for regexPattern: String) -> [[String]] {
    do {
      let regex = try NSRegularExpression(pattern: regexPattern)
      let matches = regex.matches(in: self, range: NSRange(startIndex..., in: self))
      return matches.map { match in
        return (0..<match.numberOfRanges).map {
          let rangeBounds = match.range(at: $0)
          guard let range = Range(rangeBounds, in: self) else {
            return ""
          }
          return String(self[range])
        }
      }
    } catch let error {
      fatalError("invalid regex: \(error.localizedDescription)")
    }
  }
}
