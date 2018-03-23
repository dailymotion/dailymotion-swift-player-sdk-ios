//
//  DailymotionPlayerSDKUITests.swift
//  DailymotionPlayerSDKUITests
//
//  Created by Stéphane BONIFFACY on 21/03/2018.
//  Copyright © 2018 Dailymotion. All rights reserved.
//

import XCTest
import DailymotionPlayerSDK

class DailymotionPlayerSDKUITests: XCTestCase {
  
  var app: XCUIApplication!
  
    override func setUp() {
        super.setUp()
      
      app = XCUIApplication()
        // Put setup code here. This method is called before the invocation of each test method in the class.
        
        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false
        // UI tests must launch the application that they test. Doing this in setup will make sure it happens for each test method.
        app.launchArguments = ["uitesting"]
        app.launch()
        print(app.debugDescription)

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func toggleFullScreenTest() {
        // Use recording to get started writing UI tests.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
      
      let playerView = app.otherElements[DMPlayerViewController.viewIdentifier]
      
      XCTAssertNotEqual(playerView.frame.size.width, app.windows.firstMatch.frame.size.width)
      XCTAssertNotEqual(playerView.frame.size.height, app.windows.firstMatch.frame.size.height)
      
      app.buttons["Play"].tap()
      app.rotate(.pi/2, withVelocity: 2)
      
      XCTAssertEqual(playerView.frame.size.width, app.windows.firstMatch.frame.size.width)
      XCTAssertEqual(playerView.frame.size.height, app.windows.firstMatch.frame.size.height)
      
    }
    
}
