//
//  Copyright © 2016 Dailymotion. All rights reserved.
//

import Foundation

final class EventParser {
  
  private enum Keys {
    static let event = "event"
    static let time = "time"
    static let duration = "duration"
  }

  static func parseEvent(from: Any) -> PlayerEvent? {
    guard let message = from as? String else { return nil }
    let eventAndTime = parseEventAndTime(from: message)
    let time = parseTime(from: eventAndTime)
    let data = parseData(from: eventAndTime)

    guard let event = eventAndTime[Keys.event] else { return nil }
    
    switch (event, time, data) {
    case (let event, .some(let time), _):
      return .timeEvent(name: event, time: time)
    case (let event, .none, .some(let data)):
      return .namedEvent(name: event, data: data)
    case (let event, .none, .none):
      return .namedEvent(name: event, data: nil)
    }
  }
  
  private static func parseEventAndTime(from: String) -> [String: String] {
    let splitedEvents = from.components(separatedBy: "&").map({ $0.components(separatedBy: "=") })
    var eventAndTime: [String: String] = [:]
    for entry in splitedEvents {
      if let key = entry.first, let value = entry.last, !key.isEmpty, !value.isEmpty {
        eventAndTime[key] = value
      }
    }
    return eventAndTime
  }
  
  private static func parseTime(from eventAndTime: [String: String]) -> Double? {
    if let time = eventAndTime[Keys.time], let parsed = Double(time) {
      return parsed
    }
    if let duration = eventAndTime[Keys.duration], let parsed = Double(duration) {
      return parsed
    }
    return nil
  }
  
  private static func parseData(from event: [String: String]) -> [String: String]? {
    var sanitizedData: [String: String] = [:]
    for (key, value) in event {
      if key != Keys.event && key != Keys.time && key != Keys.duration {
        sanitizedData[key] = value.removingPercentEncoding ?? value
      }
    }
    return sanitizedData.isEmpty ? nil : sanitizedData
  }
}
