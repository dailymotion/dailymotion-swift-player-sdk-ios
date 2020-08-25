//
//  Copyright © 2016 Dailymotion. All rights reserved.
//

import Foundation

public enum PlayerEvent {
  
  case timeEvent(name: String, time: Double)
  case namedEvent(name : String, data: [String: String]?)
  case errorEvent(error: PlayerError)
}

public struct PlayerError: Error {
  let title: String
  let code: String
  let message: String
}

final class EventParser {
  
  private enum Keys {
    static let event = "event"
    
    enum Time {
      static let time = "time"
      static let duration = "duration"
    }
    
    enum Error {
      static let title = "title"
      static let code = "code"
      static let message = "message"
    }
  }
  
  private enum EventName: String {
    case durationchange
    case progress
    case timeupdate
    case error
  }

  static func parseEvent(from: Any) -> PlayerEvent? {
    guard let message = from as? String else { return nil }
    
    let eventAndParameters = parseEventAndParameters(from: message)

    guard let event = eventAndParameters[Keys.event] else { return nil }
    
    switch EventName(rawValue: event) {
    case .none:
      return .namedEvent(name: event, data: parseData(from: eventAndParameters))
    case .some(let eventName):
      switch eventName {
      case .durationchange, .progress, .timeupdate:
        if let time = parseTime(from: eventAndParameters) {
           return .timeEvent(name: event, time: time)
        }
        
        return .namedEvent(name: eventName.rawValue, data: nil)
      case .error:
        if let error = parseError(from: eventAndParameters) {
          return .errorEvent(error: error)
        }
        
        return .namedEvent(name: eventName.rawValue, data: nil)
      }
    }
  }
  
  private static func parseEventAndParameters(from: String) -> [String: String] {
    let splitedEvents = from.components(separatedBy: "&").map({ $0.components(separatedBy: "=") })
    var eventAndParameters: [String: String] = [:]
    for entry in splitedEvents {
      if let key = entry.first, let value = entry.last, !key.isEmpty, !value.isEmpty {
        eventAndParameters[key] = value
      }
    }
    return eventAndParameters
  }
  
  private static func parseTime(from eventAndParameters: [String: String]) -> Double? {
    if let time = eventAndParameters[Keys.Time.time], let parsed = Double(time) {
      return parsed
    }
    if let duration = eventAndParameters[Keys.Time.duration], let parsed = Double(duration) {
      return parsed
    }
    return nil
  }
  
  private static func parseData(from event: [String: String]) -> [String: String]? {
    var sanitizedData: [String: String] = [:]
    for (key, value) in event {
      if key != Keys.event && key != Keys.Time.time && key != Keys.Time.duration {
        sanitizedData[key] = value.removingPercentEncoding ?? value
      }
    }
    return sanitizedData.isEmpty ? nil : sanitizedData
  }
  
  private static func parseError(from eventAndParameters: [String: String]) -> PlayerError? {
    guard let code = eventAndParameters[Keys.Error.code] else { return nil }
    
    let title: String = eventAndParameters[Keys.Error.title] ?? ""
    let message: String = eventAndParameters[Keys.Error.message] ?? ""
    
    return PlayerError(title: title, code: code, message: message)
  }
}
