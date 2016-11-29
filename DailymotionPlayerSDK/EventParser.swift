//
//  EventParser.swift
//  DailymotionPlayerSDK
//
//  Created by Romain BIARD on 29/11/2016.
//  Copyright © 2016 Dailymotion. All rights reserved.
//

import Foundation

class EventParser {

    class func parseEvent(from: Any) -> PlayerEvent? {
        let message = String(describing: from)
        let eventAndTime = parseEventAndTime(from: message)
        let time = parseTime(from: eventAndTime)
        guard let event = eventAndTime["event"] else {
            return nil
        }
        
        switch (event , time) {
        case (let event, let time) where time != nil :
            return .timeEvent(time: time!, name: event)
        case (let event, _):
            return .namedEvent(name: event)
        }
    }
    
    private class func parseEventAndTime(from: String) -> [String: String] {
        return from.components(separatedBy: "&")
            .map({ $0.components(separatedBy: "=") })
            .reduce([String: String]()) { initial, keyValue in
                var returnValue = initial
                returnValue[keyValue[0]] = keyValue[1]
                return returnValue
        }
    }
    
    private class func parseTime(from eventAndTime: [String: String]) -> Double? {
        if let timeString = eventAndTime["time"], let parsed = Double(timeString) {
            return parsed
        }
        if let durationString = eventAndTime["duration"], let parsed = Double(durationString) {
            return parsed
        }
        return nil
    }

}
