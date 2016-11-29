//
//  DailymotionPlayerSDKTests.swift
//  DailymotionPlayerSDKTests
//
//  Created by Romain BIARD on 29/11/2016.
//  Copyright © 2016 Dailymotion. All rights reserved.
//

import XCTest
@testable import DailymotionPlayerSDK

class EventParserTests: XCTestCase {
    
    func testParseEventNamedEventOK() {
        guard let event =  EventParser.parseEvent(from: "event=controlschange&controls=true") else {
            assertionFailure()
            return
        }
        switch event {
        case .namedEvent(let name):
            assert(name == "controlschange")
        default:
            assertionFailure()
        }
    }
    
    func testParseEventTimeEventOK() {
        guard let event =  EventParser.parseEvent(from: "event=progress&time=19.28") else {
            assertionFailure()
            return
        }
        switch event {
        case .timeEvent(let time,let name):
            assert(name == "progress")
            assert(time == 19.28)
        default:
            assertionFailure()
        }
    }
    
    func testParseEventNamedEventKO() {
        if let _ =  EventParser.parseEvent(from: "event3=controlschange&controls=true") {
            assertionFailure()
        } else {
            assert(true)
        }
    }
    
    func testParseEventTimeEventKO() {
        guard let event =  EventParser.parseEvent(from: "event=progress&time3=19.28") else {
            assertionFailure()
            return
        }
        switch event {
        case .timeEvent:
            assertionFailure()
        default:
            break
        }
    }
    
}
