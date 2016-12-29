//
//  Copyright © 2016 Dailymotion. All rights reserved.
//

import Foundation

final class EventParser {

  static func parseEvent(from: Any) -> PlayerEvent? {
    let message = String(describing: from)
    let eventAndTime = parseEventAndTime(from: message)
    let time = parseTime(from: eventAndTime)

    guard let event = eventAndTime["event"] else { return nil }
    
    switch (event , time) {
    case (let event, .some(let time)):
      return .timeEvent(name: event, time: time)
    case (let event, .none):
      return .namedEvent(name: event)
    }
  }
  
  private static func parseEventAndTime(from: String) -> [String: String] {
    return from.components(separatedBy: "&")
      .map({ $0.components(separatedBy: "=") })
      .reduce([String: String]()) { initial, keyValue in
        var returnValue = initial
        returnValue[keyValue[0]] = keyValue[1]
        return returnValue
    }
  }
  
  private static func parseTime(from eventAndTime: [String: String]) -> Double? {
    if let timeString = eventAndTime["time"], let parsed = Double(timeString) {
      return parsed
    }
    if let durationString = eventAndTime["duration"], let parsed = Double(durationString) {
      return parsed
    }
    return nil
  }

}
