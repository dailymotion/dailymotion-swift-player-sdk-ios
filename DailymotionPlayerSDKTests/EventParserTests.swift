//
//  Copyright © 2016 Dailymotion. All rights reserved.
//

import XCTest
@testable import DailymotionPlayerSDK

final class EventParserTests: XCTestCase {
  
  private func parseEvent(from: Any) -> PlayerEvent? {
    return EventParser.parseEvent(from: from)
  }
    
  func testParseEventNamedEventOK() {
    let event = parseEvent(from: "event=controlschange")!
    
    switch event {
    case .namedEvent(let name, _):
      XCTAssertEqual(name, "controlschange")
    default:
      assertionFailure()
    }
  }
  
  func testParseEventTimeEventOK() {
    let event = parseEvent(from: "event=progress&time=19.28")!
    
    switch event {
    case .timeEvent(let name, let time):
      XCTAssertEqual(name, "progress")
      XCTAssertEqual(time, 19.28)
    default:
      assertionFailure()
    }
  }
  
  func testParseTimeWithoutKnownEventName() {
    let event = parseEvent(from: "event=toto&time=19.28")!
    
    switch event {
    case .timeEvent(_, let time):
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
    let event = parseEvent(from: "event=progress&time3=19.28")!
    
    switch event {
    case .timeEvent:
      assertionFailure()
    default:
      break
    }
  }
  

  
  func testParseAdditionalEventData() {
    let event = parseEvent(from: "event=share_requested&url=https%3A%2F%2Fwww.dailymotion.com%2Fvideo%2Fx4r5udv_midnight-sun-iceland_travel&shortUrl=https%3A%2F%2Fdai.ly%2Fx4r5udv")!
    
    switch event {
    case .namedEvent(let name, let data):
      XCTAssertEqual(name, "share_requested")
      XCTAssertNotNil(data)
      XCTAssertEqual(data?["url"], "https://www.dailymotion.com/video/x4r5udv_midnight-sun-iceland_travel")
      XCTAssertEqual(data?["shortUrl"], "https://dai.ly/x4r5udv")
    default:
      assertionFailure()
    }
  }
  
  func testParseAdditionalEventDataWithUnescapedCharacter() {
    let event = parseEvent(from: "event=videochange&videoId=x63qw0n&title=\"13h15\".+Quand+l\'Iran+a+payé+un+milliards+de+dollars+pour+avoir+10%+de+l\'uranium+enrichi+par+Eurodif")!
    
    switch event {
    case .namedEvent(let name, let data):
      XCTAssertEqual(name, "videochange")
      XCTAssertNotNil(data)
      XCTAssertEqual(data?["title"], "\"13h15\".+Quand+l\'Iran+a+payé+un+milliards+de+dollars+pour+avoir+10%+de+l\'uranium+enrichi+par+Eurodif")
      XCTAssertEqual(data?["videoId"], "x63qw0n")
    default:
      assertionFailure()
    }
  }
  
  func testParseGarbageOK() {
    let event = parseEvent(from: "foo=bar&baz=bat")
    
    XCTAssertNil(event)
  }
  
  func testParseInvalidOK() {
    let event = parseEvent(from: ["foo": "bar"])
    
    XCTAssertNil(event)
  }
  
  func testParseMalformedDataGracefully() {
    let event = parseEvent(from: "event=foo&")!
    
    switch event {
    case .namedEvent(let name, let data):
      XCTAssertEqual(name, "foo")
      XCTAssertNil(data)
    default:
      assertionFailure()
    }
  }
  
  func testCorrectErrorEvent() {
    let event = parseEvent(from: "event=error&code=CODE&title=TITLE&message=MESSAGE")!
    
    switch event {
    case .errorEvent(let error):
      XCTAssertEqual(error.code, "CODE")
      XCTAssertEqual(error.title, "TITLE")
      XCTAssertEqual(error.message, "MESSAGE")
      
    default:
      assertionFailure()
    }
  }
  
  func testErrorEventWithoutCodeFallbacksToNamedEvent() {
    let event = parseEvent(from: "event=error&title=TITLE&message=MESSAGE")!
    
    switch event {
    case .namedEvent(let name, let data):
      XCTAssertEqual(name, "error")
      XCTAssertNotNil(data)
    default:
      assertionFailure()
    }
  }
}
