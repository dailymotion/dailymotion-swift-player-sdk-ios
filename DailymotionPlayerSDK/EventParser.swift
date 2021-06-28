//
//  Copyright © 2016 Dailymotion. All rights reserved.
//

import Foundation

public enum PlayerEvent {
  
  case timeEvent(name: String, time: Double)
  case namedEvent(name : String, data: [String: String]?)
  case errorEvent(error: PlayerError)
}

struct WebPlayerEvent {
  static let videoStart = "video_start"
  static let playing = "playing"
  static let end = "end"
  static let pause = "pause"
  static let seeking = "seeking"
  static let timeUpdate = "timeupdate"
  static let durationChange = "durationchange"
  static let volumeChange = "volumechange"
  static let adLoaded = "ad_loaded"
  static let adStart = "ad_start"
  static let adEnd = "ad_end"
  static let adBufferStart = "ad_bufferStart"
  static let adBufferFinish = "ad_bufferFinish"
  static let adPlay = "ad_play"
  static let adPause = "ad_pause"
  static let adResume = "ad_resume"
  static let adTimeUpdate = "ad_timeupdate"
  static let adClick = "ad_click"
  static let presentationModeChange = "presentationmodechange"
  static let fullscreenChange = "fullscreenchange"
  static let fullscreenToggleRequested = "fullscreen_toggle_requested"
  static let menuDidShow = "menu_did_show"
  static let menuDidHide = "menu_did_hide"
  static let likeRequested = "like_requested"
  static let likeChanged = "notifyLikeChanged"
  static let watchlaterRequested = "watch_later_requested"
  static let watchLaterChanged = "notifyWatchLaterChanged"
  static let addToCollectionRequested = "add_to_collection_requested"
  static let shareRequested = "share_requested"
  static let error = "error"
  static let apiReady = "apiready"
}

struct WebPlayerParam {
  static let state = "state"
  static let mode = "mode"
  static let muted = "muted"
  static let url = "url"
  static let code = "code"
  static let pip = "picture-in-picture"
  static let inline = "inline"
  static let fullscreen = "fullscreen"
}

struct VerificationScriptInfo {
  var url: String?
  var vendorKey: String?
  var parameters: String?
}

public struct PlayerError: Error {
  public let title: String
  public let code: String
  public let message: String
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
  
  static func parseEvent(from: Any) -> PlayerEvent? {
    guard let message = from as? String else { return nil }
    
    let eventAndParameters = parseEventAndParameters(from: message)
    
    guard let event = eventAndParameters[Keys.event] else { return nil }
    
    if let time = parseTime(from: eventAndParameters) {
      return .timeEvent(name: event, time: time)
    } else if let error = parseError(from: eventAndParameters) {
      return .errorEvent(error: error)
    } else {
      return .namedEvent(name: event, data: parseData(from: eventAndParameters))
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
