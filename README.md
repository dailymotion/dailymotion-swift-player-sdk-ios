[!WARNING] 
We no longer support this SDK for Player integration on iOS environments. 
Please use the new iOS SDK documented [here](https://developers.dailymotion.com/guides/getting-started-with-ios-sdk/).



# Dailymotion Swift Player SDK for iOS

[![Build Status](https://www.bitrise.io/app/61743b2a9a9a22b7/status.svg?token=N-WhdHZx9J3uFo8ZCqsXNw&branch=develop)](https://www.bitrise.io/app/61743b2a9a9a22b7)
[![Version](https://img.shields.io/cocoapods/v/DailymotionPlayerSDK.svg?style=flat)](http://cocoapods.org/pods/DailymotionPlayerSDK)
[![License](https://img.shields.io/cocoapods/l/DailymotionPlayerSDK.svg?style=flat)](http://cocoapods.org/pods/DailymotionPlayerSDK)
[![Swift](https://img.shields.io/badge/swift--version-4.0-blue.svg?style=flat)](http://cocoapods.org/pods/DailymotionPlayerSDK)
[![Platform](https://img.shields.io/cocoapods/p/DailymotionPlayerSDK.svg?style=flat)](http://cocoapods.org/pods/DailymotionPlayerSDK)

Our iOS SDK allows for effortless embedding of the Dailymotion video player in your iOS application using a WebView and is the same tool we used to create our flagship Dailymotion applications. It provides access to the Player API and gives you full control of the player and access to player and video data. To learn more please check out the official Dailymotion iOS developer doc [here](https://developer.dailymotion.com/player/#embed-mobile-ios).

## Requirements
- Xcode 9 and later
- Swift 4
- iOS 9+

Note: If you require an Objective-C version of the library or support for iOS < 9, use the [old version](https://github.com/dailymotion/dailymotion-player-sdk-ios) of the library.

## Installation

The preferred way is via [CocoaPods](http://cocoapods.org). To install, add the following to your Podfile:

```ruby
use_frameworks!

pod 'DailymotionPlayerSDK'
```

## User Privacy and Data Use

This SDK is using IDFA collection, you can still disable it if you really need to when instantiating `DMPlayerViewController`. (Will be asked by Apple in iTunes Connect when you will submit your app in the store)

##### Starting from iOS 14.5 :

- App Should use version 3.9.0 or newer, from this version the library will use the new `AppTrackingTransparency` framework to check for user authorisation, the app will be required to ask users for their permission to track them across apps and websites owned by other companies.

- App should add `NSUserTrackingUsageDescription` [Apple doc](https://developer.apple.com/documentation/bundleresources/information_property_list/nsusertrackingusagedescription)

- App should use request tracking authorization using `AppTrackingTransparency` to ask users for their permission [Apple doc](https://developer.apple.com/documentation/apptrackingtransparency/attrackingmanager/3547037-requesttrackingauthorization)

- If App continue using version 3.8.0 of library or older, the IDFA will not be used to track users.

## Usage

In the view controller that is going to serve videos, keep a reference to the Dailymotion player, and set your class as `delegate`:

```swift
import UIKit
import DailymotionPlayerSDK

class VideoViewController: UIViewController {

  // The player container. See setupPlayerViewController()
  @IBOutlet private var containerView: UIView!

  private lazy var playerViewController: DMPlayerViewController = {
    // If you have an OAuth token, you can pass it to the player to hook up
    // a user's view history.
    let parameters: [String: Any] = [
      "fullscreen-action": "trigger_event", // Trigger an event when the users toggles full screen mode in the player
      "sharing-action": "trigger_event" // Trigger an event to share the video to e.g. show a UIActivityViewController
    ]
    let controller = DMPlayerViewController(parameters: parameters)
    controller.delegate = self
    return controller
  }()

  override func viewDidLoad() {
    super.viewDidLoad()
    setupPlayerViewController()
  }

  // Add the player to your view. e.g. add a container on your storyboard
  // and add the player's view as subview to that
  private func setupPlayerViewController() {
    addChildViewController(playerViewController)

    let view = playerViewController.view!
    containerView.addSubview(view)
    view.translatesAutoresizingMaskIntoConstraints = false
    // Make the player's view fit our container view
    NSLayoutConstraint.activate([
      view.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
      view.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
      view.topAnchor.constraint(equalTo: containerView.topAnchor),
      view.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
    ])
  }

}

extension VideoViewController: DMPlayerViewControllerDelegate {

  // The delegate has 4 mandatory functions

  func player(_ player: DMPlayerViewController, didReceiveEvent event: PlayerEvent) {
    // Sends player events of either .namedEvent(name: String, data: [String: String]?), .timeEvent(name: String, time: Double) or .errorEvent(error: PlayerError)
  }

  func player(_ player: DMPlayerViewController, openUrl url: URL) {
    // Sent when a user taps on an ad that can display more information
  }

  func playerDidInitialize(_ player: DMPlayerViewController) {
    // Sent when the player has finished initializing
  }

  func player(_ player: DMPlayerViewController, didFailToInitializeWithError error: Error) {
    // Sent when the player failed to initialized
  }

}

```

For a full list of events, see the [player API events page](https://developer.dailymotion.com/player#player-api-events)

To playback a video, call the player's `load` method with the video's id:

```swift
func loadVideo(withId id: String) {
  playerViewController.load(videoId: id)
}
```

You can also pass some additional parameters when loading a video. For example if you want to start the video at a specific time:

```swift
func loadVideo(withId id: String) {
  let parameters = ["start": 30]
  guard
    let encoded = try? JSONEncoder().encode(parameters),
    let params = String(data: encoded, encoding: .utf8)
  else { return }

  playerViewController.load(videoId: id, params: params)
}
```

For a list of parameters, see the [player API parameters page](https://developer.dailymotion.com/player#player-parameters).

To handle events sent by the player, let's implement the event delegate method mentioned above:

```swift
func player(_ player: DMPlayerViewController, didReceiveEvent event: PlayerEvent) {
  switch event {
    case .namedEvent(let name, _) where name == "fullscreen_toggle_requested":
      toggleFullScreen()
    default:
      break
  }
}

private func toggleFullScreen() {
  // Keep track of the orientation via an isPlayerFullscreen bool
  isPlayerFullscreen = !isPlayerFullscreen
  updateDeviceOrientation()
  updatePlayerSize()
}

private func updateDeviceOrientation() {
  let orientation: UIDeviceOrientation = isPlayerFullscreen ? .landscapeLeft : .portrait
  UIDevice.current.setValue(orientation.rawValue, forKey: #keyPath(UIDevice.orientation))
}

private func updatePlayerSize() {
  if isPlayerFullscreen {
    playerHeightConstraint.constant = nextSize.height
  } else {
    // Keep track of the initial player's height, e.g. via a didSet handler in the constraint outlet
    playerHeightConstraint.constant = initialPlayerHeight
  }
}
```

See the `Example` directory for a working sample of all this in action.

## OM SDK integration
Open Measurement SDK from IAB is designed to facilitate third party viewability and verification measurement for ads served to web video and mobile app environments. See https://iabtechlab.com/standards/open-measurement-sdk/ for more details.

We have integrated the SDK in our Dailymotion Player SDK and it does more or less everything out of the box:
- Ad session management
- Ad main signals (play, buffer_start, buffer_end, pause, resume, quartiles, click)
- Device and Player volume management
- ⚠️ Basic Player state handling. NORMAL or FULLSCREEN based on player fullscreen state.<br/><br/>
It is **STRONGLY** recommended to update at all time the player state if your app has more player layout variety, such as mini-player, picture-in-picture, etc...<br/>
To do it, simply update the `playerState` property in your `DMPlayerViewController` instance: 
```swift
    player.playerState = .fullscreen
```
![image](https://user-images.githubusercontent.com/6400030/125312203-5ba0c700-e334-11eb-979f-6dd7e5d924ad.png)

## CMP Compliance
Starting version 3.8.0, the SDK is fully compatible with third-party CMP (Consent Management Platform). Check https://iabeurope.eu/cmp-list/ for more details.

No additional code is needed to enable this compatibility, when you integrate the SDK the communication with the CMP is handled automatically.

## License

DailymotionPlayerSDK is available under the MIT license. See the LICENSE file for more info.
