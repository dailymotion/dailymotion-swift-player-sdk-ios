//
//  Copyright © 2016 Dailymotion. All rights reserved.
//

import XCTest
@testable import DailymotionPlayerSDK

final class EventParserTests: XCTestCase {
  
  private func parseEvent(from string: String) -> PlayerEvent {
    return EventParser.parseEvent(from: string)!
  }
    
  func testParseEventNamedEventOK() {
    let event = parseEvent(from: "event=controlschange&controls=true")
    
    switch event {
    case .namedEvent(let name):
      XCTAssertEqual(name, "controlschange")
    default:
      assertionFailure()
    }
  }
  
  func testParseEventTimeEventOK() {
    let event = parseEvent(from: "event=progress&time=19.28")
    
    switch event {
    case .timeEvent(let name, let time):
      XCTAssertEqual(name, "progress")
      XCTAssertEqual(time, 19.28)
    default:
      assertionFailure()
    }
  }
  
  func testParseEventNamedEventKO() {
    if let _ = EventParser.parseEvent(from: "event3=controlschange&controls=true") {
      assertionFailure()
    } else {
      assert(true)
    }
  }
  
  func testParseEventTimeEventKO() {
    let event = parseEvent(from: "event=progress&time3=19.28")
    
    switch event {
    case .timeEvent:
      assertionFailure()
    default:
      break
    }
  }
  
}
